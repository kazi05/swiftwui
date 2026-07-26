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
            print("usage: {{NAME}} ssg --out <dir> [--static] [--path <path>] [--no-prerender]")
            return
        }
        args.removeFirst()
        var out = "dist"
        var mode = StaticSiteMode.hydrate(wasmScriptPath: "/app/index.js")
        var onlyPath: String? = nil
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
            case "--no-prerender": prerenderEnabled = false
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        if let onlyPath {
            let page = try await StaticSite.render({{NAME}}App.self, path: onlyPath,
                                                   config: .init(outDir: out, mode: mode,
                                                                 prerenderEnabled: prerenderEnabled))
            switch page.outcome {
            case .page:
                try StaticSite.writeDocument(page.html, path: onlyPath, outDir: out)
                print("rendered \(onlyPath)")
            case .redirect(let target, _): print("\(onlyPath) redirects to \(target); nothing written")
            case .notFound: print("\(onlyPath) matched no route; nothing written")
            case .error(let m): print("render failed: \(m)"); return
            }
            return
        }
        let report = try await StaticSite.generate({{NAME}}App.self,
                                                   config: .init(outDir: out, mode: mode,
                                                                 prerenderEnabled: prerenderEnabled))
        print("generated \(report.pages.count) pages")
    }
}
#else
@main enum Entry {
    static func main() { {{NAME}}App.main() }
}
#endif
