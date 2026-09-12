import Foundation
import SwiftWUI

public enum StaticSiteMode: Sendable {
    case hydrate(wasmScriptPath: String)
    case staticOnly
}

/// Search-engine validation is deliberately opt-in. A private dashboard may
/// legitimately have no public origin, title, or crawlable link graph.
public enum SearchIndexing: Sendable, Equatable {
    case `private`
    /// Treat the generated documents as public, indexable pages and fail the
    /// build when their crawl contract is incomplete.
    case indexed
}

/// The status code used for a generated redirect. `308` is the default for
/// permanent URL migrations because it preserves a non-GET method at hosts
/// that receive one; preview only serves GET/HEAD, but the deployment contract
/// must not silently weaken at the edge.
public enum StaticRedirectStatus: Int, Sendable, Equatable {
    case found = 302
    case movedPermanently = 301
    case permanentRedirect = 308
}

public struct StaticRedirect: Sendable, Equatable {
    public var from: String
    public var to: String
    public var status: StaticRedirectStatus
    public init(from: String, to: String, status: StaticRedirectStatus = .permanentRedirect) {
        self.from = from; self.to = to; self.status = status
    }
}

public enum TrailingSlashPolicy: String, Sendable, Equatable {
    case preserve, always, never
}

/// Whether an unmatched clean URL falls back to the SPA shell or is a real
/// HTTP 404. Indexed static sites default to `.notFound`; private apps retain
/// the historical SPA fallback unless they opt out.
public enum StaticFallbackPolicy: String, Sendable, Equatable {
    case spa, notFound
}

/// Edge behavior written to `swiftwui-delivery.json`. The file is consumed by
/// `swiftwui serve` and translated to a small nginx include by the toolchain;
/// it avoids meta-refresh being the only representation of a URL migration.
public struct StaticDeliveryConfig: Sendable, Equatable {
    public var redirects: [StaticRedirect]
    public var trailingSlash: TrailingSlashPolicy
    /// nil selects `.notFound` for `.indexed` and `.spa` for private apps.
    public var fallback: StaticFallbackPolicy?
    public init(redirects: [StaticRedirect] = [], trailingSlash: TrailingSlashPolicy = .preserve,
                fallback: StaticFallbackPolicy? = nil) {
        self.redirects = redirects; self.trailingSlash = trailingSlash; self.fallback = fallback
    }
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
    /// Byte length and version token of the wasm the documents will name.
    /// Injected rather than derived per page: hashing a 9.6 MB binary costs
    /// ~2.5 s in an -Onone build, and `swiftwui ssg` runs the project binary
    /// without -c. An injected stamp wins over reading from disk; nil falls back
    /// to `BootStamp.read(outDir:)`, and no wasm there means no boot config is
    /// emitted at all — the document takes the legacy inline boot.
    public var bootStamp: BootStamp?
    /// Private is the compatibility default. Public sites opt in to build-time
    /// checks for metadata, canonical URLs, JSON-LD and local crawl links.
    public var indexing: SearchIndexing
    /// Host-visible redirect and URL-normalization rules.
    public var delivery: StaticDeliveryConfig
    /// Hydrated sites may defer the one shared client runtime. This affects
    /// start time, not module byte size; `.staticOnly` ignores it.
    public var activation: BootActivation
    /// Required by visible/interaction policies to select the activation
    /// target. The boot shim treats a missing target as a safe eager fallback.
    public var activationSelector: String?
    /// App-owned ES module loaded before hydration, for example a BridgeJS
    /// wrapper which installs globals consumed by generated bindings.
    public var interopScriptURL: String?

    public init(outDir: String, mode: StaticSiteMode, paths: [String] = [], cssFile: Bool = false,
                importMapJSON: String? = #"{"imports":{"@bjorn3/browser_wasi_shim":"/vendor/wasi-shim/index.js"}}"#,
                siteURL: String? = nil,
                defaultPrerender: Prerender? = nil,
                prerenderEnabled: Bool = true,
                synthesizeCanonical: Bool = true,
                bootStamp: BootStamp? = nil,
                indexing: SearchIndexing = .private,
                delivery: StaticDeliveryConfig = .init(),
                activation: BootActivation = .eager,
                activationSelector: String? = nil,
                interopScriptURL: String? = nil) {
        self.outDir = outDir
        self.mode = mode
        self.paths = paths
        self.cssFile = cssFile
        self.importMapJSON = importMapJSON
        self.siteURL = siteURL
        self.defaultPrerender = defaultPrerender
        self.prerenderEnabled = prerenderEnabled
        self.synthesizeCanonical = synthesizeCanonical
        self.bootStamp = bootStamp
        self.indexing = indexing
        self.delivery = delivery
        self.activation = activation
        self.activationSelector = activationSelector
        self.interopScriptURL = interopScriptURL
    }
}

public enum StaticSiteError: Error, CustomStringConvertible {
    case buildTaskOverflow(page: String, iterations: Int)
    case io(path: String, underlying: String)
    /// A `routePaths` table that cannot work. Every one of these produces a
    /// green build and a broken site, so the build stops instead (spec §4).
    case invalidLocalizedRoutes([String])
    /// Two rendered documents claim one output file. Its own case, not a
    /// `routePaths` diagnostic: the commonest cause is a table, but a build
    /// task calling `setLocale` reaches it with no table anywhere, and an app
    /// that declares none must not be told its table is invalid.
    case outputFileCollision(file: String, first: String, second: String)
    /// Boot UI that cannot work. It is rendered once, natively, at build time,
    /// so `@State`, `.task` and event handlers inside it are inert — and every
    /// one of those produces a green build and a dead loader (boot spec §5.6).
    case bootUIUnsupported([String])
    case invalidSearchIndexing([String])
    case invalidDelivery([String])
    case unavailableDelayedActivation
    public var description: String {
        switch self {
        case .buildTaskOverflow(let page, let iterations):
            return "StaticSite: page '\(page)' never quiesced after \(iterations) build-task iterations"
        case .io(let path, let underlying):
            return "StaticSite: failed writing '\(path)': \(underlying)"
        case .invalidLocalizedRoutes(let problems):
            return "StaticSite: invalid routePaths:\n  - " + problems.joined(separator: "\n  - ")
        case .outputFileCollision(let file, let first, let second):
            return "StaticSite: \(first) and \(second) both write '\(file)' — one would silently "
                + "overwrite the other. Either two locales resolve to the same URL (a routePaths "
                + "slug spelled like another locale's path), or the page moved its own locale with "
                + "setLocale during the build."
        case .bootUIUnsupported(let problems):
            return "StaticSite: boot UI cannot do this — it is rendered once, natively, at build "
                + "time:\n  - " + problems.joined(separator: "\n  - ")
        case .invalidSearchIndexing(let problems):
            return "StaticSite: public indexing contract is incomplete:\n  - "
                + problems.joined(separator: "\n  - ")
        case .invalidDelivery(let problems):
            return "StaticSite: invalid delivery contract:\n  - " + problems.joined(separator: "\n  - ")
        case .unavailableDelayedActivation:
            return "StaticSite: delayed activation requires a stamped WASM bundle; run 'swiftwui build' before 'swiftwui ssg' or provide bootStamp"
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
    /// Locales rendered (empty when the app declares no localization).
    public var locales: [LocaleID] = []
    /// Pages whose Router fell through. Written and served, but `noindex`.
    public var notFoundPages: [String] = []
    /// Output files actually written, relative to outDir.
    public var writtenFiles: [String] = []
    /// Redirect status by source path. `redirects` remains for source
    /// compatibility with callers that only need the target.
    public var redirectStatuses: [String: Int] = [:]
    /// The host-neutral deployment contract, when one was written.
    public var deliveryManifest: String?
}

/// One rendered page (spec §7). `outcome` is what a server maps to a status.
public struct RenderedPage: Sendable {
    public var html: String
    public var css: String
    public var head: PageHead?
    public var outcome: Outcome
    /// Browser-visible path of this document — the locale prefix included, and
    /// the same string its canonical, snapshot and `Link` hrefs agree on.
    /// `generate()` writes and reports under this rather than re-deriving it,
    /// because the locale a page SETTLES on need not be the one it was asked
    /// for (a `.staticTask` may call `setLocale`).
    /// No default on purpose: every construction site must say where its
    /// document goes, or a forgotten one silently writes to the site root.
    public var path: String
    /// Output folder for this document, relative to outDir: `.negotiated`'s
    /// locale directory, "" under every other strategy.
    public var subdir: String

    public enum Outcome: Sendable, Equatable {
        case page
        /// The runtime settled on a different location (guard redirect). The
        /// value is the browser-visible target — locale prefix included.
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
    ///
    /// This is a manual primitive: it renders whatever `path` you name and
    /// does NOT consult that route's `.prerender` policy (`.never` included)
    /// — only `generate()`'s automatic enumeration does that. It does honour
    /// `config.prerenderEnabled`, the operational kill-switch.
    ///
    /// `path` is the INTERNAL, locale-free path — the same one routing sees.
    /// `locale` picks the language; nil (or a locale the app never declared)
    /// renders in the app's default.
    @MainActor
    public static func render<A: App>(_ app: A.Type, path: String, config: StaticSiteConfig,
                                      locale: LocaleID? = nil) async throws -> RenderedPage {
        // The kill-switch stays unconditional and first: it is the documented
        // operational escape hatch, and a bad table must not be able to block
        // the one flag that turns prerendering off.
        guard config.prerenderEnabled else {
            return RenderedPage(html: "", css: "", head: nil,
                                outcome: .error("prerendering disabled (kill-switch)"),
                                path: path, subdir: "")
        }
        // `render` never goes through `generate()`, so it validates too — the
        // table-only half only: there is no probe here and therefore no route
        // set, and no alternates map for V13 to protect.
        try StaticSite.validateLocalizedRoutes(A.self, collected: nil, config: config)
        let session = WebSession(transport: URLSessionTransport())
        WebSession.bootstrap(session)
        return try await renderPage(A.self, path: path, config: config, session: session, locale: locale)
    }

    /// A browser-visible request path → the canonical path routing expects,
    /// plus the locale that URL identified.
    ///
    /// The inverse of the output boundary, exposed because callers outside the
    /// framework need it: `swiftwui ssg --path /o-nas` has the localized path,
    /// while `render(path:locale:)` wants the canonical one. Identity for apps
    /// that declare no localization, and it never throws — an unroutable path
    /// is `render`'s `.notFound` to report, not this function's.
    @MainActor
    public static func resolve<A: App>(_ app: A.Type, requestPath: String)
        -> (path: String, locale: LocaleID?) {
        // A request path carries a query, and an operator pasting a URL hands
        // over a fragment too. Routing wants neither: `render` would take
        // "/o-nas?tab=2" as a route to match and find nothing.
        let head = String(requestPath.prefix { $0 != "?" && $0 != "#" })
        guard let l10n = A.localization, l10n.strategy.usesURLPrefix else {
            return (RouteURL._normalize(head), nil)
        }
        return LocalePath.internalize(head, supported: l10n.supported, routes: l10n.routePaths)
    }

    /// Renders the app-level boot shell for the SPA path — what `<App> boot-shell`
    /// prints for the CLI to splice into the author's `index.html`.
    ///
    /// Locale-independent, and no page is resolved: a SPA `index.html` is ONE
    /// document serving every route and every locale, so there is nothing to
    /// key a per-page or per-locale shell on and the app's default locale wins.
    /// The prerendered path is the one that gets a shell per (path, locale) —
    /// see `renderTree`.
    @MainActor public static func renderBootShell<A: App>(_ app: A.Type) -> BootShellPayload {
        guard let content = A.bootUI._content else {
            // .none — the CLI reads the empty html and skips the splice entirely.
            return BootShellPayload(html: "", css: "", delayMS: A.bootUI._delayMS)
        }
        // Same construction `renderTree` uses, minus the per-path parts.
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: A().body, initialPath: "/",
                              scheduleMicrotask: { $0() },
                              globalStyles: A.globalStyles, themes: A.themes,
                              fontFaces: A.fontFaces, localization: A.localization)
        runtime._effects._buildMode = true
        runtime._disableViewTransitions = true    // a build reads the tree as settled truth
        // `_renderBootShell` renders against the environment the last full pass
        // stashed, so it needs a pass to have run: without `mount()` it asserts
        // in debug and ships a signal-less environment in release.
        runtime.mount()
        let rendered = runtime._renderBootShell(content)
        // Printed, never fatal — the one place the probe deliberately does NOT
        // fail. `BootShellRunner` runs this subcommand with `streamOutput: false`
        // and already reads a non-zero exit as "this project predates boot UI":
        // exiting non-zero here would print the wrong remedy and then silently
        // build WITHOUT the boot UI, deleting the feature to report a nit about
        // it. Visible when an author runs `<App> boot-shell` directly; the hard
        // gate on the same declaration is `generate()`.
        _ = reportBootFindings(runtime._bootFindings + rendered.findings)
        return BootShellPayload(html: rendered.html, css: rendered.css,
                                delayMS: A.bootUI._delayMS)
    }
}

/// `BootShell` plus the wire tag. Separate type so the tag cannot leak into the
/// in-process carrier.
public struct BootShellPayload: Encodable {
    public var html: String, css: String, delayMS: Int
    enum CodingKeys: String, CodingKey { case html, css, delayMS, tag = "swiftwui-boot-shell" }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(html, forKey: .html); try c.encode(css, forKey: .css)
        try c.encode(delayMS, forKey: .delayMS); try c.encode(1, forKey: .tag)
    }
}

public enum StaticSite {
    /// Build-task loop's cap (spec §6, D5). The loop checks this right after
    /// incrementing, so it always fails at exactly `buildTaskIterationCap + 1`
    /// — generate()'s error reconstruction derives its count from here rather
    /// than a second hardcoded literal, so the two can't drift apart.
    private static let buildTaskIterationCap = 10

    /// Mirrors `DistLayout.reservedNames`: a localized slug becomes a top-level
    /// directory in dist/, and the toolchain's own collision check only ever
    /// scans `public/`. SwiftWUIStatic cannot import SwiftWUIToolchain (the
    /// same seam `LocaleNegotiation` sits on), so the list is duplicated and
    /// `ReservedNameDriftTests` is what keeps the two copies equal.
    static let reservedDistNames: Set<String> =
        ["app", "vendor", "index.html", "styles.css", "__swiftwui", "sw-assets.js",
         "nginx.conf", "swiftwui-site.json", "swiftwui-delivery.json", "swiftwui-redirects.conf", "swiftwui-assets-manifest.json", "swiftwui-build-report.json"]

    /// The one gate on `routePaths`. `_validate` is a reporting pass by design
    /// — the table is built during `static let` initialization, where a trap
    /// kills the process before any diagnostic prints — so this is where a
    /// report becomes a failed build.
    ///
    /// `collected == nil` runs the table-only half: that is `render`, which has
    /// no probe and therefore no route set.
    static func validateLocalizedRoutes<A: App>(_ app: A.Type, collected: [_CollectedRoute]?,
                                                config: StaticSiteConfig) throws {
        // Everything about this feature is inert without a table — an app that
        // declares none must not gain a single new way to fail its build.
        guard let l10n = A.localization, !l10n.routePaths.isEmpty else { return }
        var problems = l10n.routePaths._validate(localization: l10n)
        if let collected {
            problems += l10n.routePaths._validate(against: collected, siteURL: config.siteURL,
                                                  reservedNames: reservedDistNames)
        }
        guard problems.isEmpty else { throw StaticSiteError.invalidLocalizedRoutes(problems) }
    }

    /// Renders one page per enumerated path (spec §5): a fresh native
    /// Runtime<MockBackend> per page — guards, redirects, effects and state
    /// behave exactly as in the browser.
    @MainActor
    public static func generate<A: App>(_ app: A.Type,
                                        config: StaticSiteConfig) async throws -> StaticSiteReport {
        let deliveryProblems = config.delivery.redirects.compactMap { redirect -> String? in
            guard StaticDeliveryManifest.isLocalPath(redirect.from),
                  StaticDeliveryManifest.isLocalPath(redirect.to) else {
                return "redirect '\(redirect.from)' → '\(redirect.to)' must use local absolute paths without query or fragment"
            }
            return nil
        }
        guard deliveryProblems.isEmpty else { throw StaticSiteError.invalidDelivery(deliveryProblems) }
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
        // Before the providers run: a table this build can never honour should
        // not cost the author a round trip to whatever `.paths` talks to.
        try validateLocalizedRoutes(A.self, collected: collected, config: config)
        var pagePaths: [String] = []
        var skipped: [String] = []
        var onDemand: [String] = []
        var providerUnmatched: [String] = []
        var claimed = Set<String>()

        // SSG input often comes from a copied browser URL. Fragments never
        // reach a server, while a query still reaches the runtime but identifies
        // the same output document. Keep those two concerns separate.
        func withoutFragment(_ input: String) -> String {
            String(input.prefix { $0 != "#" })
        }
        func documentPath(_ input: String) -> String {
            let head = String(withoutFragment(input).prefix { $0 != "?" })
            return RouteURL._normalize(head)
        }

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
                var addedAny = false
                for input in produced {
                    let path = withoutFragment(input)
                    guard !claimed.contains(RouteURL._normalize(path)) else { continue }
                    guard pattern.match(documentPath(path)) != nil else { providerUnmatched.append(input); continue }
                    pagePaths.append(path)
                    claimed.insert(RouteURL._normalize(path))
                    addedAny = true
                }
                if policy?._onDemandEnabled == true { onDemand.append(pattern.raw) }
                // Empty or fully-claimed provider output must still land in a
                // report bucket — otherwise a build meant to emit thousands of
                // pages that emits zero gives no signal (final-review #5).
                else if !addedAny { skipped.append(pattern.raw) }
                continue
            }
            if pattern.isStatic {
                pagePaths.append(pattern.raw)
                claimed.insert(RouteURL._normalize(pattern.raw))   // M3: static pattern claims its exact path
            } else {
                let matching = config.paths.map(withoutFragment).filter {
                    pattern.match(documentPath($0)) != nil && !claimed.contains(RouteURL._normalize($0))
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
        let unmatched = config.paths.filter { !claimed.contains(RouteURL._normalize(withoutFragment($0))) } + providerUnmatched   // M2
        // The second half of the gate, and it has to be here: `config.paths`
        // entries AND `.paths` provider output both land in `pagePaths`, and
        // the providers only just ran. Inert without a table.
        let slugPaths = A.localization?.routePaths._validate(enumerated: pagePaths) ?? []
        guard slugPaths.isEmpty else { throw StaticSiteError.invalidLocalizedRoutes(slugPaths) }

        // --- render each page ---
        var report = StaticSiteReport(pages: [], redirects: [:], skippedPatterns: skipped,
                                      unmatchedPaths: unmatched, onDemandPatterns: onDemand)
        // cssFile mode: union at PAGE-TEXT granularity — registry text is not
        // guaranteed line-per-rule (media blocks), so we dedup whole page
        // registries in first-seen order. Overlap duplicates rules, which is
        // harmless (CSS is idempotent) — optimize only if it ever matters.
        var cssUnion: [String] = []
        var cssSeen = Set<String>()
        // `claim` is who asked for this document — the page and the locale, not
        // the URL it landed on. The write loop keys the collision check on it.
        var documents: [(path: String, subdir: String, html: String, claim: String)] = []
        var indexedDocuments: [(path: String, head: PageHead?, html: String)] = []
        var sitemapPaths: [String] = []   // .page only — .notFound stays out (review finding)

        let localization = A.localization
        let renderLocales: [LocaleID] = {
            guard let localization else { return [] }
            return localization.strategy.isPerLocaleOutput ? localization.supported : [localization.default]
        }()
        report.locales = renderLocales

        // Every page is rendered BEFORE any document is assembled: a page's
        // hreflang set must name the URLs its siblings actually produced, and
        // under a `routePaths` table that is not derivable from the path alone.
        // The whole site's bodies are therefore live at once — as `documents`
        // already was; stream both to disk if a build ever outgrows memory.
        var trees: [(tree: RenderedTree, canonical: String, claim: String)] = []
        for locale in (renderLocales.isEmpty ? [nil] : renderLocales.map { Optional($0) }) {
            for path in pagePaths {
                let tree = try await renderTree(A.self, path: path, config: config,
                                                session: session, locale: locale)
                let canonical = documentPath(path)
                // Who ASKED for this document, which is the identity the write
                // loop's collision check keys on. Query first, THEN normalize:
                // `_normalize` only strips a trailing slash at the very end of
                // the string, so "/a/?x=1" would otherwise claim "/a/" while
                // "/a?x=2" claims "/a" — two spellings of one page that write
                // one file. Query-stripped at all because query-variant pages
                // are ONE page and deliberately collapse into one output.
                // The asked-for locale, not the SETTLED one: a page that settles
                // elsewhere (a `.staticTask` calling `setLocale`) lands on
                // another locale's file and must still be told apart from the
                // page that legitimately owns it.
                let claim = "'" + documentPath(path) + "'"
                    + (locale.map { " in \($0.identifier)" } ?? "")
                trees.append((tree, canonical, claim))
            }
        }

        // Boot-UI authoring probe (boot spec §5.6), before a single document is
        // written: a build that is about to fail must not leave half a site on
        // disk. Reported for the whole build at once rather than per page — an
        // app-level overlay produces the same finding on every one of them.
        let bootErrors = reportBootFindings(trees.flatMap { $0.tree.bootFindings })
        guard bootErrors.isEmpty else { throw StaticSiteError.bootUIUnsupported(bootErrors) }

        // Only pages that actually rendered may be advertised as alternates: a
        // locale that never enumerated this path, fell through to notFound or
        // redirected away has no URL to point at, and one broken member makes a
        // search engine drop the entire cluster.
        var alternates: [String: [LocaleID: String]] = [:]
        for (tree, canonical, _) in trees {
            guard case .page = tree.outcome else { continue }
            alternates[canonical, default: [:]][tree.renderLocale] = tree.externalPath
        }

        // Once for the whole build, not once per page, and only if some document
        // will name the wasm: hashing a multi-megabyte binary is ~2.5 s in the
        // -Onone binary `swiftwui ssg` actually runs, and a project that never
        // opts into a boot UI must not pay it.
        let stamp = (trees.contains { $0.tree.bootShell != nil } || config.activation != .eager)
            ? (config.bootStamp ?? BootStamp.read(outDir: config.outDir)) : nil
        if case .hydrate = config.mode, config.activation != .eager, stamp == nil {
            throw StaticSiteError.unavailableDelayedActivation
        }
        for (tree, canonical, claim) in trees {
            let rendered = serialize(A.self, tree, alternates: alternates[canonical] ?? [:],
                                     config: config, stamp: stamp)
            // Where this document goes and what its URL is were both decided
            // by the render, from the locale it actually settled on. Never
            // re-derived here: a `.staticTask` calling `setLocale` would put
            // the file and its canonical in different languages.
            let outputPath = rendered.path
            let subdir = rendered.subdir
            switch rendered.outcome {
            case .redirect(let target, let permanent):
                report.redirects[outputPath] = target
                report.redirectStatuses[outputPath] = permanent
                    ? StaticRedirectStatus.permanentRedirect.rawValue : StaticRedirectStatus.found.rawValue
                documents.append((outputPath, subdir, redirectStub(to: target), claim))
            case .error:
                // generate() keeps its existing throwing contract; only the
                // server (Phase B) treats a render failure as a 503. The cap
                // (not a re-guessed literal) reproduces the same iteration
                // count renderTree's own guard failed at (review finding 1).
                throw StaticSiteError.buildTaskOverflow(page: canonical,
                                                        iterations: buildTaskIterationCap + 1)
            case .notFound, .page:
                // Deduplicated: .negotiated renders the same URL once per
                // locale, and one URL must appear once in the report and
                // once in the sitemap.
                if !report.pages.contains(outputPath) { report.pages.append(outputPath) }
                if case .page = rendered.outcome, !sitemapPaths.contains(outputPath) {
                    sitemapPaths.append(outputPath)
                }
                if case .notFound = rendered.outcome, !report.notFoundPages.contains(outputPath) {
                    report.notFoundPages.append(outputPath)
                }
                if case .page = rendered.outcome {
                    indexedDocuments.append((outputPath, rendered.head, rendered.html))
                }
                if config.cssFile, !rendered.css.isEmpty, cssSeen.insert(rendered.css).inserted {
                    cssUnion.append(rendered.css)
                }
                documents.append((outputPath, subdir, rendered.html, claim))
            }
        }

        // --- migration stubs ---
        // Adding a slug RETIRES the prefix form, and that URL is already
        // indexed, linked and bookmarked — including the bare `/ru`, which no
        // build ever writes once the home page is slugged. Stubs stay out of
        // report.pages and out of the sitemap: a redirect is not a page, the
        // same rule the guard-redirect branch above follows. Inert without a
        // table, and silent under the kill-switch — "render nothing" must not
        // start writing redirects to pages this build did not produce.
        if let localization, config.prerenderEnabled {
            let rendered = Set(pagePaths.map(RouteURL._normalize))
            for (canonical, retired, current) in localization.routePaths
                ._retiredPrefixPaths(default: localization.default)
            // A page this build did not render has no URL to send anyone to:
            // under `.prerender(.never)` or an on-demand-only pattern the stub
            // would redirect into a 404.
            where rendered.contains(canonical) && !report.pages.contains(retired) {
                report.redirects[retired] = current
                report.redirectStatuses[retired] = StaticRedirectStatus.permanentRedirect.rawValue
                documents.append((retired, "", redirectStub(to: current),
                                  "the retired-prefix stub '\(retired)'"))
            }
        }

        // Explicit deployment redirects are rendered as a no-JS fallback as
        // well as exported below. This makes local file previews useful while
        // keeping search engines and real hosts on HTTP redirects.
        if config.prerenderEnabled {
            for redirect in config.delivery.redirects {
                let from = StaticDeliveryManifest.normalize(redirect.from)
                let to = StaticDeliveryManifest.normalize(redirect.to)
                guard from != to else { continue }
                report.redirects[from] = to
                report.redirectStatuses[from] = redirect.status.rawValue
                documents.append((from, "", redirectStub(to: to),
                                  "the configured redirect '\(from)'"))
            }
        }

        if config.indexing == .indexed {
            let problems = searchIndexingProblems(documents: indexedDocuments,
                                                  redirects: report.redirects,
                                                  config: config)
            guard problems.isEmpty else { throw StaticSiteError.invalidSearchIndexing(problems) }
        }

        // --- write files ---
        // Under prefixes a collision here was structurally impossible: every
        // non-default locale was namespaced by its prefix. A slug removes that
        // namespace, so two pages can now claim one file — last write winning,
        // silently, which is how a whole language cluster disappears. Keyed on
        // the CLAIM, not on the file alone, so query-variant pages (one page,
        // one claim) keep collapsing into one output exactly as they do today.
        //
        // A whole pass before the first write, like the two validation gates
        // above: a rejected build must leave `dist/` as it found it, not
        // half-rewritten up to the offending page.
        var claimedFiles: [String: String] = [:]     // output file → the page that claimed it
        for (path, subdir, _, claim) in documents {
            let file = outputFile(path: path, subdir: subdir)
            if let owner = claimedFiles[file], owner != claim {
                throw StaticSiteError.outputFileCollision(file: file, first: owner, second: claim)
            }
            claimedFiles[file] = claim
        }
        for (path, subdir, html, _) in documents {
            try writeDocument(html, path: path, outDir: config.outDir, subdir: subdir)
            report.writtenFiles.append(outputFile(path: path, subdir: subdir))
        }
        try SiteDescriptor.write(localization: localization, outDir: config.outDir)
        let deliveryRedirects = report.redirects.keys.sorted().compactMap { from -> StaticRedirect? in
            guard let to = report.redirects[from], let raw = report.redirectStatuses[from],
                  let status = StaticRedirectStatus(rawValue: raw) else { return nil }
            return StaticRedirect(from: from, to: to, status: status)
        }
        let fallback = config.delivery.fallback ?? (config.indexing == .indexed ? .notFound : .spa)
        if !deliveryRedirects.isEmpty || config.delivery.trailingSlash != .preserve || fallback == .notFound {
            try StaticDeliveryManifest.write(redirects: deliveryRedirects, routes: report.pages,
                                             trailingSlash: config.delivery.trailingSlash,
                                             fallback: fallback,
                                             outDir: config.outDir)
            report.deliveryManifest = StaticDeliveryManifest.fileName
            report.writtenFiles.append(StaticDeliveryManifest.fileName)
        }
        if config.cssFile {
            let cssPath = config.outDir + "/styles.css"
            do { try cssUnion.joined(separator: "\n").write(toFile: cssPath, atomically: true, encoding: .utf8) }
            catch { throw StaticSiteError.io(path: cssPath, underlying: "\(error)") }
        }
        if let siteURL = config.siteURL, !siteURL.isEmpty, !sitemapPaths.isEmpty {
            let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
            for (name, xml) in Sitemap.documents(paths: sitemapPaths, siteURL: siteURL,
                                                 lastmod: String(stamp)) {
                let p = config.outDir + "/" + name
                do { try xml.write(toFile: p, atomically: true, encoding: .utf8) }
                catch { throw StaticSiteError.io(path: p, underlying: "\(error)") }
                report.sitemapFiles.append(name)
            }
        } else if config.siteURL == nil || config.siteURL?.isEmpty == true {
            print("SwiftWUI SSG: no siteURL in StaticSiteConfig — sitemap.xml not generated")
        }
        return report
    }

    /// Writes one document to `<outDir>/<subdir>/<path>/index.html`. Query
    /// strings are stripped — query-variant pages collapse to one output
    /// (documented).
    ///
    /// `subdir` is what lets the output folder and the URL disagree: under
    /// `.negotiated` the document at `/about` is written to `<outDir>/ru/about`
    /// while every URL inside it stays clean, and the edge picks the folder.
    public static func writeDocument(_ html: String, path: String, outDir: String,
                                     subdir: String = "") throws {
        let documentPath = RouteURL._normalize(String(path.prefix { $0 != "?" && $0 != "#" }))
        guard StaticDeliveryManifest.isLocalPath(documentPath) else {
            throw StaticSiteError.io(path: path,
                                     underlying: "refusing to write an unsafe static document path")
        }
        let relative = outputFile(path: path, subdir: subdir)
        let requested = outDir + "/" + relative
        let lexicalRoot = URL(fileURLWithPath: outDir, isDirectory: true).standardizedFileURL
        let lexicalDestination = URL(fileURLWithPath: requested).standardizedFileURL
        guard contains(lexicalDestination, in: lexicalRoot) else {
            throw StaticSiteError.io(path: requested,
                                     underlying: "refusing to write outside the static output directory")
        }
        do {
            try FileManager.default.createDirectory(at: lexicalRoot, withIntermediateDirectories: true)
        } catch {
            throw StaticSiteError.io(path: lexicalRoot.path, underlying: "\(error)")
        }
        let root = lexicalRoot.resolvingSymlinksInPath()
        let destination = resolvingExistingAncestors(of: lexicalDestination)
        guard contains(destination, in: root) else {
            throw StaticSiteError.io(path: requested,
                                     underlying: "refusing to write outside the static output directory")
        }
        let dir = destination.deletingLastPathComponent().path
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            // Resolve again after directory creation. This also catches an
            // existing in-tree symlink whose target is outside `outDir`.
            let resolved = URL(fileURLWithPath: requested)
                .standardizedFileURL.resolvingSymlinksInPath()
            guard contains(resolved, in: root) else {
                throw StaticSiteError.io(path: requested,
                                         underlying: "refusing to write through a symlink outside the static output directory")
            }
            try html.write(toFile: resolved.path, atomically: true, encoding: .utf8)
        } catch {
            if let siteError = error as? StaticSiteError { throw siteError }
            throw StaticSiteError.io(path: dir + "/index.html", underlying: "\(error)")
        }
    }

    private static func contains(_ candidate: URL, in root: URL) -> Bool {
        let rootPath = root.path
        let candidatePath = candidate.path
        return candidatePath == rootPath || rootPath == "/" || candidatePath.hasPrefix(rootPath + "/")
    }

    /// `URL.resolvingSymlinksInPath()` may leave an intermediate symlink alone
    /// when the final file does not exist yet. Resolve the deepest existing
    /// ancestor first, then append the still-missing suffix lexically.
    private static func resolvingExistingAncestors(of url: URL) -> URL {
        var existing = url.standardizedFileURL
        var suffix: [String] = []
        while !FileManager.default.fileExists(atPath: existing.path) {
            let parent = existing.deletingLastPathComponent()
            guard parent.path != existing.path else { break }
            suffix.append(existing.lastPathComponent)
            existing = parent
        }
        var resolved = existing.resolvingSymlinksInPath()
        for component in suffix.reversed() {
            resolved.appendPathComponent(component)
        }
        return resolved.standardizedFileURL
    }

    /// The one place "which folder" and "which URL" are joined into a path on
    /// disk, relative to outDir. Query strings and fragments are stripped here,
    /// so every caller agrees on where a copied browser URL collapses to.
    static func outputFile(path: String, subdir: String) -> String {
        let clean = RouteURL._normalize(String(path.prefix { $0 != "?" && $0 != "#" }))
        let dir = clean == "/" ? "" : String(clean.dropFirst())
        return ([subdir, dir].filter { !$0.isEmpty } + ["index.html"]).joined(separator: "/")
    }

    /// Meta-refresh stub for guard-redirected pages (spec D4).
    static func redirectStub(to target: String) -> String {
        "<!doctype html>\n<meta http-equiv=\"refresh\" content=\"0; url="
            + HTMLEscaping.text(target) + "\">\n"
    }

    /// Validate the subset of SEO signals SwiftWUI can prove from generated
    /// output. Search Console crawl/render data remains an environment check;
    /// this catches broken deployment inputs before an artifact is published.
    private static func searchIndexingProblems(documents: [(path: String, head: PageHead?, html: String)],
                                               redirects: [String: String],
                                               config: StaticSiteConfig) -> [String] {
        guard let origin = normalizedOrigin(config.siteURL) else {
            return ["indexed sites require an absolute http(s) siteURL (for example https://example.com)"]
        }
        // Browser hrefs commonly percent-encode Unicode while route tables use
        // readable literals. Routing decodes each segment after splitting, so
        // compare the same identity here. Keeping an array preserves segment
        // boundaries: `/a%2Fb` must not become the two-segment route `/a/b`.
        let known = Set(documents.map { routeIdentity($0.path) })
            .union(redirects.keys.map(routeIdentity))
        var problems: [String] = []
        for document in documents {
            let path = RouteURL._normalize(document.path)
            let label = "\(path):"
            let head = document.head
            if head?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                problems.append("\(label) missing a non-empty <title>")
            }
            let description = head?.meta.first {
                $0.attributes["name"]?.lowercased() == "description"
            }?.attributes["content"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if description?.isEmpty != false {
                problems.append("\(label) missing a non-empty meta description")
            }
            let expectedCanonical = origin + path
            let canonical = canonicalHref(in: document.html)
            if canonical != expectedCanonical {
                problems.append("\(label) canonical must be \(expectedCanonical), got \(canonical ?? "none")")
            }
            for block in head?.structuredData ?? [] {
                guard let data = block.data(using: .utf8),
                      (try? JSONSerialization.jsonObject(with: data)) != nil else {
                    problems.append("\(label) contains invalid JSON-LD")
                    continue
                }
            }
            for href in localHrefs(in: document.html) {
                let target = routeIdentity(String(href.prefix { $0 != "?" && $0 != "#" }))
                if !known.contains(target) {
                    problems.append("\(label) internal link \(href) has no generated page or redirect")
                }
            }
        }
        return problems
    }

    private static func routeIdentity(_ path: String) -> [String] {
        RouteURL._normalize(path).split(separator: "/").map {
            let raw = String($0)
            return raw.removingPercentEncoding ?? raw
        }
    }

    private static func normalizedOrigin(_ siteURL: String?) -> String? {
        guard let siteURL, let url = URL(string: siteURL),
              (url.scheme == "https" || url.scheme == "http"), url.host != nil,
              url.path.isEmpty || url.path == "/", url.query == nil, url.fragment == nil else { return nil }
        return siteURL.hasSuffix("/") ? String(siteURL.dropLast()) : siteURL
    }

    private static func canonicalHref(in html: String) -> String? {
        capture(#"<link[^>]*\brel="canonical"[^>]*\bhref="([^"]+)"|<link[^>]*\bhref="([^"]+)"[^>]*\brel="canonical""#, in: html)
            .compactMap { $0.first(where: { !$0.isEmpty }) }
            .map(decodedHTMLAttribute).first
    }

    private static func localHrefs(in html: String) -> [String] {
        capture(#"<a\b[^>]*\bhref="([^"]+)""#, in: html).compactMap { $0.first }
            .map(decodedHTMLAttribute)
            .filter { $0.hasPrefix("/") && !$0.hasPrefix("//") }
    }

    /// Captures run over serialized HTML, so compare the parsed attribute
    /// value rather than its source representation. Decode exactly the five
    /// entities emitted by `HTMLEscaping.text`; `&amp;` stays last to preserve
    /// one HTML-parser pass for source such as `&amp;lt;`.
    private static func decodedHTMLAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func capture(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<match.numberOfRanges).compactMap { index -> String? in
                let range = match.range(at: index)
                guard range.location != NSNotFound, let swift = Range(range, in: text) else { return nil }
                return String(text[swift])
            }
        }
    }

    /// "styles.css" for the root page, "../../styles.css" for /todo/1/index.html, etc.
    /// (root-absolute "/styles.css" breaks subdirectory deploys — final-review carry item.)
    static func cssHref(forPageFile relPath: String) -> String {
        let dirDepth = relPath.split(separator: "/").dropLast().count
        return String(repeating: "../", count: dirDepth) + "styles.css"
    }

    /// What one render resolved, before any document exists. Split out of
    /// `renderPage` so a caller can render every page of a cluster first and
    /// only then assemble the documents, with the sibling set in hand.
    ///
    /// `body == nil` is a render that produced no document at all — an error, a
    /// redirect, or no matched tree. `serialize` passes those outcomes straight
    /// through, and `body` is the ONLY field that says so: every other value a
    /// document needs is either non-optional here or derived inside `serialize`.
    /// A second defaulted field coupled to `body` would let a new construction
    /// site forget it and silently serialize an empty page.
    private struct RenderedTree {
        var body: String?
        var css: String
        var head: PageHead?
        var snapshot: String? = nil
        var outcome: RenderedPage.Outcome
        var externalPath: String
        var subdir: String
        /// The locale the page SETTLED on. Always meaningful — the runtime has
        /// one from the moment it is constructed — so no default and no
        /// optionality to mistake for "no document".
        var renderLocale: LocaleID
        var wasmPath: String? = nil
        /// The boot UI this document resolved, already rendered against its own
        /// runtime's environment. nil = this document declared none.
        var bootShell: BootShell? = nil
        /// Authoring findings for this document's boot UI (`BootProbe`).
        /// `generate()` reports and fails on them; `render(path:)` drops them —
        /// it is the per-REQUEST on-demand entry too, and an authoring nit is
        /// not something to re-print or 500 on once per request.
        var bootFindings: [BootProbe.Finding] = []
    }

    /// Writes `BootProbe` findings to stderr, deduped in first-seen order, and
    /// returns the error messages among them.
    ///
    /// stderr and a return value, NEVER `assert`: `swiftwui build` defaults to
    /// `-c release`, where assertions are stripped — a probe that only asserted
    /// would advertise a guarantee it does not provide in the one configuration
    /// authors ship.
    private static func reportBootFindings(_ findings: [BootProbe.Finding]) -> [String] {
        var seen: Set<String> = []
        var errors: [String] = []
        var text = ""
        for f in findings where seen.insert(f.message).inserted {
            text += (f.isError ? "error: " : "warning: ") + f.message + "\n"
            if f.isError { errors.append(f.message) }
        }
        if !text.isEmpty { FileHandle.standardError.write(Data(text.utf8)) }
        return errors
    }

    /// One page, rendered and assembled on its own — what `render` is.
    ///
    /// The alternates map is EMPTY on purpose: a page rendered in isolation has
    /// no verified siblings, and inventing them from `supported` is exactly the
    /// broken cluster this task removed. A caller that wants alternates has to
    /// render the cluster, which is what `generate` does.
    @MainActor
    private static func renderPage<A: App>(_ app: A.Type, path: String, config: StaticSiteConfig,
                                           session: WebSession, locale: LocaleID? = nil) async throws
        -> RenderedPage {
        let tree = try await renderTree(A.self, path: path, config: config,
                                        session: session, locale: locale)
        // Only a document that ships a shell names the wasm, and this path is
        // per-REQUEST for an on-demand server: without the guard every request
        // to a boot-less site would hash a multi-megabyte binary. A server that
        // does ship one should inject `config.bootStamp` and skip the read too.
        let stamp = tree.bootShell == nil
            ? nil : (config.bootStamp ?? BootStamp.read(outDir: config.outDir))
        return serialize(A.self, tree, alternates: [:], config: config, stamp: stamp)
    }

    @MainActor
    private static func renderTree<A: App>(_ app: A.Type, path: String, config: StaticSiteConfig,
                                           session: WebSession, locale: LocaleID? = nil) async throws
        -> RenderedTree {
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
        let localization = A.localization
        // Fragments never reach a server. Queries do reach it, but identify
        // variants of one static document, so routing/output/canonical use only
        // the path while the runtime still receives the query at boot.
        let fragmentless = String(path.prefix { $0 != "#" })
        let requestedPath = RouteURL._normalize(fragmentless.firstIndex(of: "?")
            .map { String(fragmentless[..<$0]) } ?? fragmentless)
        let querySuffix = fragmentless.firstIndex(of: "?")
            .map { String(fragmentless[$0...]) } ?? ""
        let target: LocaleID? = {
            guard let localization else { return nil }
            guard let locale, localization.supported.contains(locale) else { return localization.default }
            return locale
        }()
        // Seeding the signal directly would not survive `mount()`: it re-runs
        // the whole boot detection chain (`_resolveInitialLocale`) and would
        // reset every page to the default locale. Feed the runtime the same
        // INPUTS the browser gets instead, and let it resolve them itself.
        //   .pathPrefix — the locale is in the URL, so boot from the external path.
        //   .negotiated — the edge announces the locale in the served <html lang>.
        // `routes:` is what keeps the SSG's URLs and the runtime's agreeing: the
        // browser boots at the slug and `mount()` would otherwise `replaceState`
        // away from the prefix form this build had written into the snapshot.
        let bootPath: String = {
            guard let target, let localization, localization.strategy.usesURLPrefix else { return path }
            return LocalePath.externalize(requestedPath, locale: target, default: localization.default,
                                          routes: localization.routePaths) + querySuffix
        }()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: A().body, initialPath: bootPath,
                              scheduleMicrotask: { queue.append($0) },
                              globalStyles: A.globalStyles, themes: A.themes, fontFaces: A.fontFaces,
                              localization: localization)
        if let target, let localization, !localization.strategy.usesURLPrefix {
            runtime._servedLanguage = target.identifier
        }
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
                return RenderedTree(body: nil, css: "", head: nil,
                                    // Normalized, so this reads the same as the
                                    // `StaticSiteError` generate() throws for it
                                    // and as the path the report keys on.
                                    outcome: .error("page '\(RouteURL._normalize(path))' never quiesced after \(iterations) build-task iterations"),
                                    externalPath: path, subdir: "",
                                    renderLocale: runtime._signals.locale)
            }
            pump()                                 // state writes → re-render → possibly new tasks
        }

        // Redirect detection: the runtime settled on a different location.
        // _locationPath is query-stripped by Runtime; compare like-for-like or
        // query paths misclassify as self-redirect stubs (infinite refresh).
        let settled = runtime._locationPath
        // Internal route path → browser-visible path, the same mapping
        // `Runtime._externalPath` applies to history and `Link` hrefs. Identity
        // for monolingual apps and prefix-less strategies, so their output is
        // byte-for-byte what it was before this existed.
        // The locale the page SETTLED on — not the one it was asked for: a
        // `.staticTask` may call `setLocale`, and the file, the canonical, the
        // snapshot and the stylesheet href must all follow the same one.
        let renderLocale = runtime._signals.locale
        func externalize(_ internalPath: String) -> String {
            guard let localization, localization.strategy.usesURLPrefix else { return internalPath }
            return LocalePath.externalize(internalPath, locale: renderLocale, default: localization.default,
                                          routes: localization.routePaths)
        }
        // `.negotiated` keeps the URL clean and puts the locale in the output
        // folder instead; every other strategy has one folder per URL.
        let subdir: String = {
            guard let localization, case .negotiated = localization.strategy else { return "" }
            return renderLocale.identifier
        }()
        // What the browser will show in the address bar for this document — and
        // therefore what the snapshot must record: the hydration boot compares
        // it to `location.pathname` byte-for-byte. Built from the REQUESTED
        // path, not `settled`: on a redirect those differ, and the stub is
        // written at the URL that was asked for, not at the one it points to.
        let externalPath = externalize(RouteURL._normalize(requestedPath))
        if settled != RouteURL._normalize(requestedPath) {
            // The stub's target is a URL a browser will follow, so it carries
            // the prefix: a guard redirect out of /ru/admin must not drop the
            // visitor into the English site.
            return RenderedTree(body: nil, css: "", head: nil,
                                outcome: .redirect(to: externalize(settled), permanent: false),
                                externalPath: externalPath, subdir: subdir,
                                renderLocale: renderLocale)
        }

        guard case .component(let rootComponent)? = runtime._currentTree else {
            return RenderedTree(body: nil, css: runtime._registryText, head: nil, outcome: .notFound,
                                externalPath: externalPath, subdir: subdir,
                                renderLocale: renderLocale)
        }
        let body = HTMLRenderer._render(rootComponent.children)
        // Per (path, locale): this loop already builds one Runtime per pair, and
        // a boot overlay may read the catalog, so the shell is rendered HERE and
        // not once in generate() — `_renderBootShell` renders against the
        // environment the last full pass stashed, which is this document's.
        // Read `_bootUI` only now, after the build-task drain above: on a pass
        // where a guard redirects, the Router `continue`s and may match a later
        // route, so `_bootUI` momentarily describes that fallback.
        //
        // The type is written out rather than left to member lookup: `_bootUI`
        // is a `BootUI?`, so `.none` here would resolve to `Optional.none` —
        // nil, silently, with only a warning.
        var bootShell: BootShell? = nil
        var bootShellFindings: [BootProbe.Finding] = []
        let declared = runtime._bootUI ?? BootUI.inherit
        let effective = declared._isInherit ? A.bootUI : declared
        if case .hydrate = config.mode, let content = effective._content {
            let rendered = runtime._renderBootShell(content)
            bootShell = BootShell(html: rendered.html, css: rendered.css,
                                  delayMS: effective._delayMS)
            bootShellFindings = rendered.findings
        }
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
            snapshot = SnapshotJSON.assemble(version: 1, path: externalPath, rows: rows, tasks: tasks)
        }
        // Read after the drain, like `_bootUI` above: `_bootFindings` is stashed
        // by every full pass, so the last one is the tree this document ships.
        let bootFindings = runtime._bootFindings + bootShellFindings
        var wasmPath: String? = nil
        if case .hydrate(let p) = config.mode { wasmPath = p }
        // A Router fallthrough to notFound still resolves real content (its
        // notFound: closure, or nothing if the app declared none) — render it
        // like any other page and only flag the outcome (review finding 2).
        let outcome: RenderedPage.Outcome = runtime._routeMatched ? .page : .notFound
        return RenderedTree(body: body, css: css, head: runtime._pageHead, snapshot: snapshot,
                            outcome: outcome, externalPath: externalPath, subdir: subdir,
                            renderLocale: renderLocale, wasmPath: wasmPath, bootShell: bootShell,
                            bootFindings: bootFindings)
    }

    /// Assembles the document. `alternates` is the verified sibling set — the
    /// external URLs a caller actually produced for this canonical path, keyed
    /// by the locale that produced them.
    @MainActor
    private static func serialize<A: App>(_ app: A.Type, _ tree: RenderedTree,
                                          alternates: [LocaleID: String],
                                          config: StaticSiteConfig,
                                          stamp: BootStamp?) -> RenderedPage {
        // No document was rendered — the outcome IS the result, and wrapping it
        // in one would invent a page the runtime never produced.
        guard let body = tree.body else {
            return RenderedPage(html: "", css: tree.css, head: tree.head, outcome: tree.outcome,
                                path: tree.externalPath, subdir: tree.subdir)
        }
        let localization = A.localization
        // Kept apart from the app's own head: these describe the URL, not the
        // page, so the client — which can recompute neither — must not sweep
        // them on the first hydrated commit (DocumentSerializer emits them under
        // `data-swiftwui-ssg`).
        var appHead = tree.head
        var prerenderedLinks: [LinkTag] = []
        var prerenderedMeta: [MetaTag] = []
        if case .page = tree.outcome {
            if let canonical = CanonicalSynthesis.synthesized(for: appHead, path: tree.externalPath,
                                                              siteURL: config.siteURL,
                                                              enabled: config.synthesizeCanonical) {
                prerenderedLinks.append(canonical)
            }
            if let localization {
                // A page that declared no head at all still needs its alternates —
                // hreflang is a property of the URL set, not of the page's metadata.
                prerenderedLinks += HreflangLinks.links(alternates: alternates,
                                                        localization: localization, siteURL: config.siteURL)
            }
        } else {
            // Only a Router fall-through gets this far — every other non-.page
            // outcome left `body` nil and returned above. It renders real
            // content at HTTP 200, so without this it ships a self-canonical
            // and a reciprocal alternate, and Google is free to swap the empty
            // page in as that language's version of a real one. `.error` would
            // deserve the same treatment for the same reason, so the branch is
            // deliberately the catch-all rather than `case .notFound`.
            prerenderedMeta.append(MetaTag(attributes: ["name": "robots", "content": "noindex"]))
            // The app's OWN canonical is the same hazard and is NOT covered by
            // the gate above. `.pageMeta` writes `ctx.pageHeadPatch` from
            // wherever it sits — a site-wide one ABOVE the Router included —
            // and `commitRouteEffects` folds it over an empty baseline when no
            // route matched, so a fall-through's head is non-nil and carries
            // those links. `noindex` + `canonical` is a conflicting pair, and
            // the canonical names a REAL URL that would inherit the noindex.
            // Title, description and the rest stay: they cost nothing on a 404.
            appHead?.links.removeAll {
                $0.attributes["rel"] == "canonical"
                    || ($0.attributes["rel"] == "alternate" && $0.attributes["hreflang"] != nil)
            }
        }
        // `RenderedPage.head` stays the full set — callers read it as "what this
        // page's head contains", and that is unchanged by where the markers go.
        // It is built from the same `appHead` the document got, so a caller
        // (an on-demand server) never sees a canonical the document dropped.
        var head = appHead
        if !prerenderedLinks.isEmpty {
            var merged = head ?? PageHead(title: "", meta: [], links: [])
            merged.links += prerenderedLinks
            head = merged
        }
        let importMap: String? = tree.wasmPath != nil ? config.importMapJSON : nil
        var bootConfig: BootConfig? = nil
        // No stamp, no config: without a read wasm there is no name to put in
        // `data-wasm`, and a guessed one ("app.wasm" is never a real product
        // name) 404s inside the shim, which fails closed and shows the failure
        // UI — a dead page, not a degrade. Dropping the config instead hands the
        // document to `DocumentSerializer`'s legacy inline boot and it loads
        // normally; the shell's `<template>`/`<style>` ride along inert, since
        // nothing ever sets `data-swui-boot` on <html> to trigger them.
        if let entry = tree.wasmPath, let stamp, tree.bootShell != nil || config.activation != .eager {
            // The bundle — entry, wasm and the copied shim — is one directory,
            // so take the entry's OWN directory. Matching on "index.js" would
            // send every renamed entry back to a hardcoded "/app/", which is the
            // 404-behind-the-veil this carries `shimURL` to avoid.
            let dir = entry.lastIndex(of: "/").map { String(entry[...$0]) } ?? "/app/"
            bootConfig = BootConfig(wasmURL: dir + stamp.fileName + "?v=" + stamp.version,
                                    entryURL: entry,
                                    shimURL: dir + "swiftwui-boot.js",
                                    sizeBytes: stamp.sizeBytes,
                                    delayMS: tree.bootShell?.delayMS ?? 300,
                                    activation: config.activation,
                                    activationSelector: config.activationSelector)
        }
        let doc = DocumentSerializer.render(.init(
            bodyHTML: body,
            css: config.cssFile ? nil : tree.css,
            // The stylesheet href is relative to the output FILE, not to the URL
            // — the very file the write loop derives from the same two values.
            cssHref: config.cssFile ? cssHref(forPageFile: outputFile(path: tree.externalPath,
                                                                     subdir: tree.subdir)) : nil,
            head: appHead,
            prerenderedLinks: prerenderedLinks,
            prerenderedMeta: prerenderedMeta,
            snapshotJSON: tree.snapshot,
            importMapJSON: importMap,
            wasmScriptPath: tree.wasmPath,
            bootShell: tree.bootShell,
            bootConfig: bootConfig,
            interopScriptURL: tree.wasmPath == nil ? nil : config.interopScriptURL,
            lang: localization == nil ? "en" : tree.renderLocale.identifier,
            dir: localization != nil && tree.renderLocale.isRTL ? "rtl" : nil))
        return RenderedPage(html: doc, css: tree.css, head: head, outcome: tree.outcome,
                            path: tree.externalPath, subdir: tree.subdir)
    }
}

/// Adds `<link rel="canonical">` when a page declares none (spec §5.2).
/// Across tens of thousands of generated pages "the author remembered" is not
/// a property that holds, and query-decorated inbound links otherwise serve the
/// same body with no canonical signal.
public enum CanonicalSynthesis {
    /// The canonical this page is missing, or nil when none is warranted.
    public static func synthesized(for head: PageHead?, path: String,
                                   siteURL: String?, enabled: Bool) -> LinkTag? {
        // No origin, no synthesis: a relative canonical buys little, and sites
        // that predate this feature set no siteURL — their output must not move.
        guard enabled, let siteURL, !siteURL.isEmpty else { return nil }
        let declared = head?.links ?? []
        if declared.contains(where: { $0.attributes["rel"] == "canonical" }) { return nil }
        var origin = siteURL
        while origin.hasSuffix("/") { origin.removeLast() }
        return .canonical(origin + RouteURL._normalize(path))
    }
    public static func apply(to head: PageHead?, path: String,
                             siteURL: String?, enabled: Bool) -> PageHead? {
        guard let link = synthesized(for: head, path: path, siteURL: siteURL,
                                     enabled: enabled) else { return head }
        var out = head ?? PageHead(title: "", meta: [], links: [])
        out.links.append(link)
        return out
    }
}
