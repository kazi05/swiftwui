import Foundation
import SwiftWUI

public enum StaticSiteMode: Sendable {
    case hydrate(wasmScriptPath: String)
    case staticOnly
}

public struct StaticSiteConfig: Sendable {
    public var outDir: String
    public var mode: StaticSiteMode
    public var paths: [String]
    public var cssFile: Bool
    /// JSON for a <script type="importmap"> emitted before the wasm module script
    /// (hydrate mode only). Default matches the swiftwui CLI dist layout; nil = no map.
    public var importMapJSON: String?
    /// Absolute site origin, e.g. "https://example.com". Required for sitemap
    /// generation and for absolute canonical synthesis; nil = relative canonicals,
    /// no sitemap (spec §5.2, §10).
    public var siteURL: String?
    /// Site-wide policy for routes and apps that declare none (spec §4.3).
    public var defaultPrerender: Prerender?
    /// Kill-switch. false = render nothing; the shell still ships.
    public var prerenderEnabled: Bool
    /// Synthesize <link rel="canonical"> when a page sets none (spec §5.2).
    public var synthesizeCanonical: Bool

    public init(outDir: String, mode: StaticSiteMode, paths: [String] = [], cssFile: Bool = false,
                importMapJSON: String? = #"{"imports":{"@bjorn3/browser_wasi_shim":"/vendor/wasi-shim/index.js"}}"#,
                siteURL: String? = nil,
                defaultPrerender: Prerender? = nil,
                prerenderEnabled: Bool = true,
                synthesizeCanonical: Bool = true) {
        self.outDir = outDir
        self.mode = mode
        self.paths = paths
        self.cssFile = cssFile
        self.importMapJSON = importMapJSON
        self.siteURL = siteURL
        self.defaultPrerender = defaultPrerender
        self.prerenderEnabled = prerenderEnabled
        self.synthesizeCanonical = synthesizeCanonical
    }
}

public enum StaticSiteError: Error, CustomStringConvertible {
    case buildTaskOverflow(page: String, iterations: Int)
    case io(path: String, underlying: String)
    public var description: String {
        switch self {
        case .buildTaskOverflow(let page, let iterations):
            return "StaticSite: page '\(page)' never quiesced after \(iterations) build-task iterations"
        case .io(let path, let underlying):
            return "StaticSite: failed writing '\(path)': \(underlying)"
        }
    }
}

public struct StaticSiteReport {
    public var pages: [String]                    // generated page paths
    public var redirects: [String: String]        // page → target (stub emitted)
    public var skippedPatterns: [String]          // dynamic patterns with no explicit path
    /// config.paths entries no pattern claimed — typos or dead config (final-review M2).
    public var unmatchedPaths: [String] = []
    /// Patterns deliberately left to a render server (spec §4.4) — NOT mistakes.
    public var onDemandPatterns: [String] = []
    /// sitemap.xml + any sitemap-N.xml chunks written (spec §10). Empty when
    /// config.siteURL is nil.
    public var sitemapFiles: [String] = []
}

/// One rendered page (spec §7). `outcome` is what a server maps to a status.
public struct RenderedPage: Sendable {
    public var html: String
    public var css: String
    public var head: PageHead?
    public var outcome: Outcome

    public enum Outcome: Sendable, Equatable {
        case page
        /// The runtime settled on a different location (guard redirect).
        case redirect(to: String, permanent: Bool)
        /// No route matched, or the Router fell through to notFound.
        case notFound
        /// Render failed — TRANSIENT. Never map this to 404: repeated 404s
        /// deindex a URL, and an upstream outage is routine at scale.
        case error(String)
    }
}

extension StaticSite {
    /// Renders exactly one path. `generate()` is built on this, and so is any
    /// server or worker that renders on demand.
    @MainActor
    public static func render<A: App>(_ app: A.Type, path: String,
                                      config: StaticSiteConfig) async throws -> RenderedPage {
        let session = WebSession(transport: URLSessionTransport())
        WebSession.bootstrap(session)
        return try await renderPage(A.self, path: path, config: config, session: session)
    }
}

public enum StaticSite {
    /// Build-task loop's cap (spec §6, D5). The loop checks this right after
    /// incrementing, so it always fails at exactly `buildTaskIterationCap + 1`
    /// — generate()'s error reconstruction derives its count from here rather
    /// than a second hardcoded literal, so the two can't drift apart.
    private static let buildTaskIterationCap = 10

    /// Renders one page per enumerated path (spec §5): a fresh native
    /// Runtime<MockBackend> per page — guards, redirects, effects and state
    /// behave exactly as in the browser.
    @MainActor
    public static func generate<A: App>(_ app: A.Type,
                                        config: StaticSiteConfig) async throws -> StaticSiteReport {
        let session = WebSession(transport: URLSessionTransport())
        WebSession.bootstrap(session)

        // --- enumerate ---
        let probeBackend = MockBackend()
        let probe = Runtime(backend: probeBackend, container: probeBackend.container,
                            root: A().body, scheduleMicrotask: { $0() },
                            globalStyles: A.globalStyles, themes: A.themes, fontFaces: A.fontFaces)
        probe._webSession = session
        probe._effects._buildMode = true      // enumeration must not run "/"'s effects for real
        probe.mount()
        let collected = probe._collectRoutes()
        var pagePaths: [String] = []
        var skipped: [String] = []
        var onDemand: [String] = []
        var providerUnmatched: [String] = []
        var claimed = Set<String>()

        for route in collected {
            let pattern = route.pattern
            let policy = PrerenderResolution.effective(route: route.prerender,
                                                       app: A.prerender,
                                                       config: config.defaultPrerender)
            // Kill-switch and .never both mean "produce nothing for this pattern".
            guard config.prerenderEnabled else { skipped.append(pattern.raw); continue }
            if let policy, !policy._buildEnabled, policy._pathProvider == nil {
                if policy._onDemandEnabled { onDemand.append(pattern.raw) }
                else { skipped.append(pattern.raw) }
                continue
            }
            if let provider = policy?._pathProvider {
                let produced = try await provider()
                for path in produced where !claimed.contains(RouteURL._normalize(path)) {
                    guard pattern.match(path) != nil else { providerUnmatched.append(path); continue }
                    pagePaths.append(path)
                    claimed.insert(RouteURL._normalize(path))
                }
                if policy?._onDemandEnabled == true { onDemand.append(pattern.raw) }
                continue
            }
            if pattern.isStatic {
                pagePaths.append(pattern.raw)
                claimed.insert(RouteURL._normalize(pattern.raw))   // M3: static pattern claims its exact path
            } else {
                let matching = config.paths.filter {
                    pattern.match($0) != nil && !claimed.contains(RouteURL._normalize($0))
                }
                if matching.isEmpty {
                    if policy?._onDemandEnabled == true { onDemand.append(pattern.raw) }
                    else { skipped.append(pattern.raw) }
                } else {
                    pagePaths.append(contentsOf: matching)
                    claimed.formUnion(matching.map(RouteURL._normalize))   // first-match-wins, like the Router
                }
            }
        }
        let unmatched = config.paths.filter { !claimed.contains(RouteURL._normalize($0)) } + providerUnmatched   // M2

        // --- render each page ---
        var report = StaticSiteReport(pages: [], redirects: [:], skippedPatterns: skipped,
                                      unmatchedPaths: unmatched, onDemandPatterns: onDemand)
        // cssFile mode: union at PAGE-TEXT granularity — registry text is not
        // guaranteed line-per-rule (media blocks), so we dedup whole page
        // registries in first-seen order. Overlap duplicates rules, which is
        // harmless (CSS is idempotent) — optimize only if it ever matters.
        var cssUnion: [String] = []
        var cssSeen = Set<String>()
        var documents: [(path: String, html: String)] = []

        for path in pagePaths {
            let rendered = try await renderPage(A.self, path: path, config: config, session: session)
            switch rendered.outcome {
            case .redirect(let target, _):
                report.redirects[path] = target
                documents.append((path, redirectStub(to: target)))
            case .error:
                // generate() keeps its existing throwing contract; only the
                // server (Phase B) treats a render failure as a 503. The cap
                // (not a re-guessed literal) reproduces the same iteration
                // count renderPage's own guard failed at (review finding 1).
                throw StaticSiteError.buildTaskOverflow(page: path, iterations: buildTaskIterationCap + 1)
            case .notFound, .page:
                report.pages.append(path)
                if config.cssFile, !rendered.css.isEmpty, cssSeen.insert(rendered.css).inserted {
                    cssUnion.append(rendered.css)
                }
                documents.append((path, rendered.html))
            }
        }

        // --- write files ---
        for (path, html) in documents {
            try writeDocument(html, path: path, outDir: config.outDir)
        }
        if config.cssFile {
            let cssPath = config.outDir + "/styles.css"
            do { try cssUnion.joined(separator: "\n").write(toFile: cssPath, atomically: true, encoding: .utf8) }
            catch { throw StaticSiteError.io(path: cssPath, underlying: "\(error)") }
        }
        if let siteURL = config.siteURL, !report.pages.isEmpty {
            let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
            for (name, xml) in Sitemap.documents(paths: report.pages, siteURL: siteURL,
                                                 lastmod: String(stamp)) {
                let p = config.outDir + "/" + name
                do { try xml.write(toFile: p, atomically: true, encoding: .utf8) }
                catch { throw StaticSiteError.io(path: p, underlying: "\(error)") }
                report.sitemapFiles.append(name)
            }
        } else if config.siteURL == nil {
            print("SwiftWUI SSG: no siteURL in StaticSiteConfig — sitemap.xml not generated")
        }
        return report
    }

    /// Writes one document to `<outDir>/<path>/index.html`. Query strings are
    /// stripped — query-variant pages collapse to one output (documented).
    public static func writeDocument(_ html: String, path: String, outDir: String) throws {
        let cleanPath = path.firstIndex(of: "?").map { String(path[..<$0]) } ?? path
        let dir = cleanPath == "/" ? outDir : outDir + cleanPath
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try html.write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        } catch {
            throw StaticSiteError.io(path: dir + "/index.html", underlying: "\(error)")
        }
    }

    /// Meta-refresh stub for guard-redirected pages (spec D4).
    static func redirectStub(to target: String) -> String {
        "<!doctype html>\n<meta http-equiv=\"refresh\" content=\"0; url="
            + HTMLEscaping.text(target) + "\">\n"
    }

    /// "styles.css" for the root page, "../../styles.css" for /todo/1/index.html, etc.
    /// (root-absolute "/styles.css" breaks subdirectory deploys — final-review carry item.)
    static func cssHref(forPageFile relPath: String) -> String {
        let dirDepth = relPath.split(separator: "/").dropLast().count
        return String(repeating: "../", count: dirDepth) + "styles.css"
    }

    @MainActor
    private static func renderPage<A: App>(_ app: A.Type, path: String,
                                           config: StaticSiteConfig, session: WebSession) async throws
        -> RenderedPage {
        // Immediate-drain scheduler: microtasks run synchronously in order.
        var queue: [() -> Void] = []
        var draining = false
        func pump() {
            guard !draining else { return }
            draining = true
            while !queue.isEmpty { queue.removeFirst()() }
            draining = false
        }
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: A().body, initialPath: path,
                              scheduleMicrotask: { queue.append($0) },
                              globalStyles: A.globalStyles, themes: A.themes, fontFaces: A.fontFaces)
        runtime._webSession = session
        runtime._effects._buildMode = true
        runtime._disableViewTransitions = true    // a build reads the tree as settled truth
        runtime.mount()
        pump()                                     // guards/redirect hops settle here

        // Build-task loop (spec §6, D5): cap mirrors the redirect-hop cap.
        var iterations = 0
        while true {
            let hadPending = await runtime._effects._drainBuildTasks(store: runtime._store)
            if !hadPending { break }
            iterations += 1
            guard iterations <= buildTaskIterationCap else {
                return RenderedPage(html: "", css: "", head: nil,
                                    outcome: .error("page '\(path)' never quiesced after \(iterations) build-task iterations"))
            }
            pump()                                 // state writes → re-render → possibly new tasks
        }

        // Redirect detection: the runtime settled on a different location.
        // _locationPath is query-stripped by Runtime; compare like-for-like or
        // query paths misclassify as self-redirect stubs (infinite refresh).
        let settled = runtime._locationPath
        let requestedPath = path.firstIndex(of: "?").map { String(path[..<$0]) } ?? path
        if settled != RouteURL._normalize(requestedPath) {
            return RenderedPage(html: "", css: "", head: nil,
                                outcome: .redirect(to: settled, permanent: false))
        }

        guard case .component(let rootComponent)? = runtime._currentTree else {
            return RenderedPage(html: "", css: runtime._registryText, head: nil, outcome: .notFound)
        }
        let body = HTMLRenderer._render(rootComponent.children)
        let css = runtime._registryText
        var snapshot: String? = nil
        if case .hydrate = config.mode {
            let rows = runtime._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
            // A completed .build task whose state row didn't make the snapshot
            // (non-Encodable value → whole-row drop, or an unkeyable identity)
            // must not be listed in "tasks" — the hydrated client would then
            // skip the loader and silently keep the initial value (spec §7).
            // Real write attribution (phase-6 I3): a task's key is kept only if
            // every identity it wrote during the drain survived encoding.
            let encoded = Set(rows.keys)   // canonical strings of rows that made the snapshot
            let tasks = runtime._effects._completedBuildKeys.filter { key in
                let writes = runtime._effects._buildWrites[key] ?? []
                let ok = writes.isSubset(of: encoded)   // every written row survived encoding
                #if DEBUG
                if !ok {
                    print("SwiftWUI SSG: loader result at '\(key)' not serializable — client will re-run it (make the @State type Codable to ship it in the snapshot)")
                }
                #endif
                return ok
            }
            snapshot = SnapshotJSON.assemble(version: 1, path: settled, rows: rows, tasks: tasks)
        }
        var wasmPath: String? = nil
        if case .hydrate(let p) = config.mode { wasmPath = p }
        let importMap: String? = wasmPath != nil ? config.importMapJSON : nil
        // Same relative path the write loop derives its output file from
        // (requestedPath is already query-stripped, see above).
        let relFile = requestedPath == "/" ? "index.html" : String(requestedPath.dropFirst()) + "/index.html"
        let head = CanonicalSynthesis.apply(to: runtime._pageHead,
                                            path: requestedPath,
                                            siteURL: config.siteURL,
                                            enabled: config.synthesizeCanonical)
        let doc = DocumentSerializer.render(.init(
            bodyHTML: body,
            css: config.cssFile ? nil : css,
            cssHref: config.cssFile ? cssHref(forPageFile: relFile) : nil,
            head: head,
            snapshotJSON: snapshot,
            importMapJSON: importMap,
            wasmScriptPath: wasmPath))
        // A Router fallthrough to notFound still resolves real content (its
        // notFound: closure, or nothing if the app declared none) — render it
        // like any other page and only flag the outcome (review finding 2).
        let outcome: RenderedPage.Outcome = runtime._routeMatched ? .page : .notFound
        return RenderedPage(html: doc, css: css, head: head, outcome: outcome)
    }
}

/// Adds `<link rel="canonical">` when a page declares none (spec §5.2).
/// Across tens of thousands of generated pages "the author remembered" is not
/// a property that holds, and query-decorated inbound links otherwise serve the
/// same body with no canonical signal.
public enum CanonicalSynthesis {
    public static func apply(to head: PageHead?, path: String,
                             siteURL: String?, enabled: Bool) -> PageHead? {
        // No origin, no synthesis: a relative canonical buys little, and sites
        // that predate this feature set no siteURL — their output must not move.
        guard enabled, let siteURL, !siteURL.isEmpty else { return head }
        var out = head ?? PageHead(title: "", meta: [], links: [])
        if out.links.contains(where: { $0.attributes["rel"] == "canonical" }) { return out }
        var origin = siteURL
        while origin.hasSuffix("/") { origin.removeLast() }
        out.links.append(.canonical(origin + RouteURL._normalize(path)))
        return out
    }
}
