import SwiftWUI
import SwiftWUIDOM
import Observation

// MARK: TCA-style core — State, Action, reducer, Store. No external package:
// pointfree TCA does not build on wasm; this is the same shape on SwiftWUI reactivity.

struct AppState: Equatable {
    var count = 0
}

enum AppAction {
    case increment
    case decrement
}

func appReducer(_ state: inout AppState, _ action: AppAction) {
    switch action {
    case .increment: state.count += 1
    case .decrement: state.count -= 1
    }
}

@Observable final class Store {
    private(set) var state = AppState()
    func send(_ action: AppAction) { appReducer(&state, action) }
}

private struct StoreKey: EnvironmentKey { static let defaultValue = Store() }
extension EnvironmentValues {
    var store: Store { get { self[StoreKey.self] } set { self[StoreKey.self] = newValue } }
}

// MARK: Views — read state, send actions.

struct CounterView: Tag {
    @Environment(\.store) var store
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(store.state.count)")
            Button("−") { store.send(.decrement) }
            Button("+") { store.send(.increment) }
        }
    }
}

struct HomePage: Tag, Page {
    var title: String { "{{NAME}}" }
    var body: some Tag {
        Main {
            H1("{{NAME}}")
            CounterView()
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
    @State var store = Store()
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
        .environment(\.store, store)
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
        guard args.first == "ssg" else {
            print("usage: {{NAME}} ssg --out <dir> [--static] [--path <path>] [--locale <tag>] [--no-prerender]")
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
