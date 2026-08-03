import SwiftWUI
import SwiftWUIDOM

struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
        }
    }
}

struct HomePage: Tag, Page {
    var title: String { "{{NAME}}" }
    var body: some Tag {
        Main {
            H1("{{NAME}}")
            Counter()
            Link("/about") { Span { "About" } }
        }
    }
}

struct AboutPage: Tag, Page {
    @State var builtAt = "not prerendered"
    var title: String { "About — {{NAME}}" }
    var body: some Tag {
        Main {
            H2("About")
            P { Text(builtAt) }
            Link("/") { Span { "Home" } }
        }
        .staticTask { builtAt = "prerendered at build time" }
    }
}

struct RootApp: Tag {
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
    }
}

struct {{NAME}}App: App {
    var body: some Tag { RootApp() }
}

#if canImport(SwiftWUIStatic)
import Foundation
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        if args.first == "boot-shell" {
            // One tagged line on stdout. The CLI identifies the answer by this
            // key, not by exit status — an older project prints usage and
            // returns 0, which is indistinguishable otherwise.
            let shell = StaticSite.renderBootShell({{NAME}}App.self)
            let data = try JSONEncoder().encode(shell)
            print(String(data: data, encoding: .utf8)!)
            return
        }
        guard args.first == "ssg" else {
            print("usage: {{NAME}} ssg --out <dir> [--static] [--path <path>] [--locale <tag>] [--no-prerender]")
            print("       {{NAME}} boot-shell")
            return
        }
        args.removeFirst()
        var out = "dist"
        var mode = StaticSiteMode.hydrate(wasmScriptPath: "/app/index.js")
        var onlyPath: String? = nil
        var localeTag: String? = nil
        var prerenderEnabled = PrerenderSwitch.enabled(
            fromEnvironment: ProcessInfo.processInfo.environment[PrerenderSwitch.environmentKey])
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            case "--static": mode = .staticOnly
            case "--path":
                guard i + 1 < args.count else { print("--path needs a value"); return }
                i += 1; onlyPath = args[i]
            case "--locale":
                guard i + 1 < args.count else { print("--locale needs a value"); return }
                i += 1; localeTag = args[i]
            case "--no-prerender": prerenderEnabled = false
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        // Fill in your site's origin — it is what buys absolute canonical URLs,
        // hreflang alternates and sitemap.xml. Left nil, canonicals stay relative
        // and no sitemap is written; a localized `routePaths` table refuses to
        // build without it.
        let siteURL: String? = nil          // e.g. "https://example.com"
        let config = StaticSiteConfig(outDir: out, mode: mode, siteURL: siteURL,
                                      prerenderEnabled: prerenderEnabled)
        if let onlyPath {
            // A localized path — a slug or a locale prefix — resolves to the
            // canonical path the router expects, plus the locale it identified.
            // An explicit --locale wins.
            let resolved = StaticSite.resolve({{NAME}}App.self, requestPath: onlyPath)
            let locale = localeTag.flatMap(LocaleID.init) ?? resolved.locale
            let page = try await StaticSite.render({{NAME}}App.self, path: resolved.path,
                                                   config: config, locale: locale)
            switch page.outcome {
            case .page:
                // `page.path`/`page.subdir`, not `onlyPath`: the render decides
                // where the document goes, and in a localized app they differ.
                try StaticSite.writeDocument(page.html, path: page.path, outDir: out,
                                             subdir: page.subdir)
                print("rendered \(onlyPath)")
            case .redirect(let target, _): print("\(onlyPath) redirects to \(target); nothing written")
            case .notFound: print("\(onlyPath) matched no route; nothing written")
            case .error(let m): print("render failed: \(m)"); return
            }
            return
        }
        let report = try await StaticSite.generate({{NAME}}App.self, config: config)
        print("generated \(report.pages.count) pages")
    }
}
#else
@main enum Entry {
    static func main() { {{NAME}}App.main() }
}
#endif
