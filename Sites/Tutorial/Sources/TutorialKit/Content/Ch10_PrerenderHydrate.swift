/// Chapter 10 — Prerender and hydrate (Figma 13:42 + authored sections).
public enum Ch10 {
    static let ssgCode = #"""
@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: ShipCounter ssg --out <dir>")
            return
        }
        args.removeFirst()
        var out = "dist"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(ShipCounterApp.self, config: .init(
            outDir: out,
            mode: .hydrate(wasmScriptPath: "/app/index.js")))
        print("generated \(report.pages.count) pages")
    }
}
"""#
    static let staticCode = #"""
struct AboutPage: Tag, Page {
    @State var builtAt = "not prerendered"
    var title: String { "About — ShipCounter" }
    var body: some Tag {
        Main {
            H2("About")
            P { Text(builtAt) }
            Link("/") { Span { "Home" } }
        }
        .staticTask { builtAt = "prerendered at build time" }
    }
}
"""#

    public static let chapter = Chapter(
        slug: "prerender-and-hydrate", track: .ship, kicker: "CHAPTER · SHIP",
        title: "Prerender and hydrate",
        tagline: "Static HTML at build time for instant first paint; the WASM runtime hydrates it into a live app.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "ssg", kicker: "01 · SSG",
                    title: "From routes to static pages",
                    intro: "The same app renders in the browser and at build time — one codebase, two entries.",
                    steps: [
                        Step("Keep two entries in your app's entry file: wasm runs the app, native runs ssg.",
                             detail: "#if canImport(SwiftWUIStatic) selects the entry per platform. A scaffolded project calls that file Sources/Entry.swift; the sample below is a single-file app, so its entry lives in main.swift."),
                        Step("StaticSite.generate renders one page per route with a fresh native runtime."),
                        Step("Dynamic patterns need explicit paths in the config — unmatched ones are reported, not guessed."),
                        Step("Order matters: swiftwui build assembles dist first, ssg writes pages last."),
                    ],
                    panel: .terminal(title: "zsh — shipcounter", lines: [
                        TermLine(.command, "swiftwui build --out dist"),
                        TermLine(.note, "> wasm bundle -> dist/app/index.js"),
                        TermLine(.command, "swiftwui ssg --out dist"),
                        TermLine(.note, "> generated 2 pages"),
                        TermLine(.command, "swiftwui serve dist --port 9000"),
                        TermLine(.note, "> serving dist on http://localhost:9000"),
                    ])),
            Section(anchor: "hydrate", kicker: "02 · HYDRATE",
                    title: "Adopt, don’t re-render",
                    intro: "Hydration walks the prerendered DOM instead of throwing it away.",
                    steps: [
                        Step("The runtime adopts the prerendered DOM node by node."),
                        Step("Live @State ships as an application/swiftwui-state snapshot inside the page."),
                        Step("On any structural mismatch the runtime falls back to a cold render — content still works."),
                        Step("data-swui-hydrated=\"true\" on the container is the success signal — tests assert it."),
                    ],
                    panel: .code(CodePanel(file: "main.swift", code: ssgCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/ShipCounter/Sources/main.swift",
                                                           marker: "ship-ssg")))),
            Section(anchor: "static-data", kicker: "03 · STATIC DATA",
                    title: "Build-time loaders",
                    intro: "Some state should be computed once, at build time.",
                    steps: [
                        Step(".staticTask runs your async loader during prerendering.",
                             panel: .code(CodePanel(file: "AboutPage.swift", code: staticCode,
                                                    origin: .sample(path: "Sites/Tutorial/Samples/ShipCounter/Sources/main.swift",
                                                                    marker: "ship-static")))),
                        Step("The loaded @State serializes into the page and is adopted on hydrate."),
                        Step("This About page was filled at build time — no client fetch, no flash."),
                    ],
                    panel: .browser(url: "localhost:9000/about", screenshot: "screens/ship-static.png")),
        ])
}
