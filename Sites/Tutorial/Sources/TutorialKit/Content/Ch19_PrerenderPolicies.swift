/// Chapter 19 — Prerender on your terms. Pinned to Samples/Tour.
public enum Ch19 {
    static let routesCode = #"""
        Router(notFound: { Main { H1("404"); Link("/") { Span { "Back to the tour" } } } }) {
            Route("/") { TourIndex() }
            Route("/responsive") { ResponsiveDemo() }
            Route("/bindings") { BindingsDemo() }
            Route("/dropzone") { DropZoneDemo() }
            Route("/motion") { MotionDemo() }

            // Client-only: a signed-in dashboard has nothing to prerender.
            Route("/data") { DataDemo() }
                .prerender(.never)

            // Dynamic pattern: `.build` alone would yield nothing, so the
            // route enumerates its own paths. `.allowingOnDemand()` lets a
            // render server fill in products added after the build.
            Route("/product/:id") { ProductPage() }
                .prerender(.paths { await Catalog.allSlugs() }
                             .allowingOnDemand()
                             .revalidate(.seconds(3600)))
        }
        .pageTransition(.fade)
"""#

    static let headCode = #"""
struct ProductPage: Tag {
    @RouteParam("id") var id: String?
    @State private var product: Product?

    var body: some Tag {
        Main(class: "tour") {
            if let product {
                H1(product.name)
                P { Text(product.blurb) }
                P { Text("$\(product.priceUSD)") }
            } else {
                P { "Loading…" }
            }
            Link("/") { Span { "Back to the tour" } }
        }
        .staticTask { product = await Catalog.load(slug: id ?? "") }
        .pageMeta(title: product.map { "\($0.name) — SwiftWUI Tour" },
                  meta: product.map { [.description($0.blurb)] },
                  structuredData: product.map { [Self.productJSONLD($0)] })
    }

    static func productJSONLD(_ p: Product) -> String {
        """
        {"@context":"https://schema.org","@type":"Product",\
        "name":"\(p.name)","description":"\(p.blurb)",\
        "offers":{"@type":"Offer","price":"\(p.priceUSD)","priceCurrency":"USD"}}
        """
    }
}
"""#

    static let configCode = #"""
        let report = try await StaticSite.generate(TourApp.self, config: .init(
            outDir: out,
            mode: mode,
            siteURL: "https://tour.swiftwui.dev",   // canonical links + sitemap.xml
            defaultPrerender: .build,               // for routes that say nothing
            prerenderEnabled: prerenderEnabled))
        print("generated \(report.pages.count) pages, \(report.sitemapFiles.count) sitemap file(s)")
        print("left to a render server: \(report.onDemandPatterns)")
"""#

    static let killSwitchCode = #"""
        var prerenderEnabled = PrerenderSwitch.enabled(
            fromEnvironment: ProcessInfo.processInfo.environment[PrerenderSwitch.environmentKey])
"""#

    public static let chapter = Chapter(
        slug: "prerender-policies", track: .ship, kicker: "CHAPTER · SHIP",
        title: "Prerender on your terms",
        tagline: "Decide per route what gets built, what waits for a server, and what never renders at all.",
        minutes: 25, kind: .chapter,
        sections: [
            Section(anchor: "policy-per-route", kicker: "01 · POLICY",
                    title: "A policy per route",
                    intro: "The previous chapter prerendered everything it could reach. Real sites want finer control: a marketing page belongs in the build, a private dashboard never does, and a catalogue of ten thousand products belongs somewhere in between.",
                    steps: [
                        Step("Attach a policy with Route.prerender(_:).",
                             detail: "Four starting points: .never, .build, .onDemand, and .paths { … }."),
                        Step(".never keeps a route out of the build entirely.",
                             detail: "The shell still ships, so the route works the moment the runtime boots."),
                        Step("A dynamic pattern needs a path list — .build alone produces nothing for it.",
                             detail: "Either .paths { … } on the route or StaticSiteConfig.paths."),
                        Step("Chain .allowingOnDemand() to let a render server fill in what the build missed."),
                        Step("Chain .revalidate(_:) to give a rendered page a shelf life."),
                    ],
                    panel: .code(CodePanel(file: "TourApp.swift", code: routesCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/TourApp.swift",
                                                           marker: "tour-routes")))),
            Section(anchor: "policy-resolution", kicker: "02 · RESOLUTION",
                    title: "Most specific wins",
                    intro: "Three places can declare a policy. They resolve in one fixed order, and saying nothing anywhere is still a valid answer.",
                    steps: [
                        Step("Route.prerender beats App.prerender beats StaticSiteConfig.defaultPrerender."),
                        Step("nil at every level falls back to the pre-policy behaviour.",
                             detail: "Static patterns build; dynamic patterns build only from an explicit path list."),
                        Step("allowingOnDemand is an instance method, never a leading dot.",
                             detail: "Prerender.onDemand is a static property with the same base name — in leading-dot position the property always wins."),
                        Step("Routes the build deliberately skipped come back in report.onDemandPatterns.",
                             detail: "Those are decisions, not failures — skippedPatterns is the list worth reading twice."),
                    ],
                    panel: .code(CodePanel(file: "TourApp.swift", code: configCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/TourApp.swift",
                                                           marker: "tour-ssg-config")))),
            Section(anchor: "policy-killswitch", kicker: "03 · KILL SWITCH",
                    title: "One switch that beats every policy",
                    intro: "Prerendering is the first thing you want to turn off when a build starts failing at 2 a.m. That switch is a separate axis from policy, and it fails closed.",
                    steps: [
                        Step("StaticSiteConfig.prerenderEnabled = false renders nothing; the shell still ships."),
                        Step("Read it from SWIFTWUI_PRERENDER with PrerenderSwitch.enabled(fromEnvironment:)."),
                        Step("Unset means on. Only 1, true, on and yes mean on.",
                             detail: "Every other non-empty value — including a typo — turns prerendering off. That is deliberate."),
                        Step("The switch beats every policy, including an explicit .build."),
                    ],
                    panel: .terminal(title: "zsh — tour", lines: [
                        TermLine(.command, "swiftwui ssg --out dist"),
                        TermLine(.note, "> generated 7 pages, 1 sitemap file(s)"),
                        TermLine(.command, "SWIFTWUI_PRERENDER=off swiftwui ssg --out dist"),
                        TermLine(.note, "> generated 0 pages, 0 sitemap file(s)"),
                        TermLine(.command, "swiftwui ssg --out dist --path /product/nimbus-7"),
                        TermLine(.output, "rendered /product/nimbus-7"),
                    ])),
            Section(anchor: "policy-head", kicker: "04 · HEAD",
                    title: "A head computed from data",
                    intro: "Page.title is snapshotted before your state exists. A title that depends on a build-time loader needs a modifier that runs inside the route subtree instead.",
                    steps: [
                        Step("@RouteParam reads the matched capture without threading params through initializers.",
                             detail: "It is nil when the capture is absent or fails to parse."),
                        Step(".staticTask awaits a loader during the build and skips it on a hydrated boot."),
                        Step(".pageMeta applies after the state graft and re-applies on every pass the loader triggers.",
                             detail: "nil parameters inherit; an explicit value replaces."),
                        Step("structuredData emits JSON-LD through the same escaping the hydration snapshot uses."),
                        Step("Two .pageMeta calls in one subtree: the deepest one wins, and a debug build says so."),
                    ],
                    panel: .code(CodePanel(file: "Prerender.swift", code: headCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/Prerender.swift",
                                                           marker: "tour-pagemeta")))),
            Section(anchor: "policy-discovery", kicker: "05 · DISCOVERY",
                    title: "Canonicals, sitemaps, and one page at a time",
                    intro: "Set siteURL and two things a search engine cares about appear on their own.",
                    steps: [
                        Step("A page that declares no canonical gets one synthesized; an explicit one is never overwritten."),
                        Step("sitemap.xml lists only .page outcomes — redirects and 404s stay out.",
                             detail: "Past 45,000 URLs it chunks into sitemap-N.xml behind an index."),
                        Step("StaticSite.render(_:path:config:) renders exactly one path and returns an outcome.",
                             detail: ".page, .redirect, .notFound or .error — a server maps those to status codes."),
                        Step("render(path:) is policy-blind on purpose: it renders what you asked for.",
                             detail: "Only generate()'s automatic enumeration consults .prerender. The kill switch still applies."),
                    ],
                    panel: .code(CodePanel(file: "TourApp.swift", code: killSwitchCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/Tour/Sources/TourApp.swift",
                                                           marker: "tour-killswitch")))),
        ],
        quiz: Quiz(questions: [
            Question(prompt: "A route is declared Route(\"/docs/:page\") { … }.prerender(.build) and the config lists no paths. What does the build produce for it?",
                     options: ["Nothing — .build has no paths to expand a dynamic pattern with",
                               "One page per matching file on disk",
                               "A single page at /docs/:page",
                               "An error that fails the build"],
                     correctIndex: 0,
                     explanation: ".build says \"render me at build time\" but a dynamic pattern still needs a path list. Pair it with .paths { … } or StaticSiteConfig.paths; the pattern is reported in skippedPatterns instead."),
            Question(prompt: "SWIFTWUI_PRERENDER is set to the string \"yeah\". What happens?",
                     options: ["Prerendering is off — only 1, true, on and yes mean on",
                               "Prerendering is on — any non-empty value enables it",
                               "The build fails with an invalid-value error",
                               "The variable is ignored and per-route policy decides"],
                     correctIndex: 0,
                     explanation: "The switch is fail-closed: unset means on, the four accepted spellings mean on, and anything else — including a typo — turns prerendering off rather than silently guessing."),
            Question(prompt: "A route's title is computed from data loaded by .staticTask. Why does Page.title show the placeholder?",
                     options: ["Router snapshots Page.title before @State is grafted and before any loader runs",
                               "Page.title is only read on the client, never during SSG",
                               "The loader runs after the HTML is written to disk",
                               "Page.title cannot contain interpolated values"],
                     correctIndex: 0,
                     explanation: "That snapshot order is exactly why .pageMeta exists: it lives inside the route subtree, so it resolves after the graft and re-resolves on every pass a build task triggers."),
        ]))
}
