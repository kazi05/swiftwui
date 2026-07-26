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
}

public enum StaticSite {
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
        var claimed = Set<String>()
        for route in collected {
            let pattern = route.pattern
            if pattern.isStatic {
                pagePaths.append(pattern.raw)
                claimed.insert(RouteURL._normalize(pattern.raw))   // M3: static pattern claims its exact path
            } else {
                let matching = config.paths.filter {
                    pattern.match($0) != nil && !claimed.contains(RouteURL._normalize($0))
                }
                if matching.isEmpty { skipped.append(pattern.raw) }
                else {
                    pagePaths.append(contentsOf: matching)
                    claimed.formUnion(matching.map(RouteURL._normalize))   // first-match-wins, like the Router
                }
            }
        }
        let unmatched = config.paths.filter { !claimed.contains(RouteURL._normalize($0)) }   // M2

        // --- render each page ---
        var report = StaticSiteReport(pages: [], redirects: [:], skippedPatterns: skipped,
                                      unmatchedPaths: unmatched)
        // cssFile mode: union at PAGE-TEXT granularity — registry text is not
        // guaranteed line-per-rule (media blocks), so we dedup whole page
        // registries in first-seen order. Overlap duplicates rules, which is
        // harmless (CSS is idempotent) — optimize only if it ever matters.
        var cssUnion: [String] = []
        var cssSeen = Set<String>()
        var documents: [(path: String, html: String)] = []

        for path in pagePaths {
            let (html, css, redirect) = try await renderPage(A.self, path: path, config: config, session: session)
            if let redirect {
                report.redirects[path] = redirect
                documents.append((path, redirectStub(to: redirect)))
                continue
            }
            report.pages.append(path)
            if config.cssFile, !css.isEmpty, cssSeen.insert(css).inserted {
                cssUnion.append(css)
            }
            documents.append((path, html))
        }

        // --- write files ---
        let fm = FileManager.default
        for (path, html) in documents {
            // Query strings (e.g. "/todo?f=active") are not distinct SSG
            // outputs — strip to the path for the directory (documented
            // limitation: query-variant pages collapse to one output).
            let cleanPath = path.firstIndex(of: "?").map { String(path[..<$0]) } ?? path
            let dir = cleanPath == "/" ? config.outDir : config.outDir + cleanPath
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try html.write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
            } catch {
                throw StaticSiteError.io(path: dir + "/index.html", underlying: "\(error)")
            }
        }
        if config.cssFile {
            let cssPath = config.outDir + "/styles.css"
            do { try cssUnion.joined(separator: "\n").write(toFile: cssPath, atomically: true, encoding: .utf8) }
            catch { throw StaticSiteError.io(path: cssPath, underlying: "\(error)") }
        }
        return report
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
        -> (html: String, css: String, redirect: String?) {
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
            guard iterations <= 10 else {
                throw StaticSiteError.buildTaskOverflow(page: path, iterations: iterations)
            }
            pump()                                 // state writes → re-render → possibly new tasks
        }

        // Redirect detection: the runtime settled on a different location.
        // _locationPath is query-stripped by Runtime; compare like-for-like or
        // query paths misclassify as self-redirect stubs (infinite refresh).
        let settled = runtime._locationPath
        let requestedPath = path.firstIndex(of: "?").map { String(path[..<$0]) } ?? path
        if settled != RouteURL._normalize(requestedPath) {
            return ("", "", settled)
        }

        guard case .component(let rootComponent)? = runtime._currentTree else {
            return ("", runtime._registryText, nil)     // empty page (no route matched)
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
        let doc = DocumentSerializer.render(.init(
            bodyHTML: body,
            css: config.cssFile ? nil : css,
            cssHref: config.cssFile ? cssHref(forPageFile: relFile) : nil,
            head: runtime._pageHead,
            snapshotJSON: snapshot,
            importMapJSON: importMap,
            wasmScriptPath: wasmPath))
        return (doc, css, nil)
    }
}
