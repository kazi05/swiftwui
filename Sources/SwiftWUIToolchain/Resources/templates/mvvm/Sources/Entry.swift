import SwiftWUI
import SwiftWUIDOM
import Observation

// MARK: ViewModel — owns state and intent; views below contain zero logic.

@Observable final class CounterViewModel {
    private(set) var count = 0
    func increment() { count += 1 }
    func decrement() { count -= 1 }
}

private struct CounterVMKey: EnvironmentKey { static let defaultValue = CounterViewModel() }
extension EnvironmentValues {
    var counterVM: CounterViewModel {
        get { self[CounterVMKey.self] } set { self[CounterVMKey.self] = newValue }
    }
}

// MARK: Views

struct CounterView: Tag {
    @Environment(\.counterVM) var vm
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(vm.count)")
            Button("−") { vm.decrement() }
            Button("+") { vm.increment() }
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
    @State var vm = CounterViewModel()
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
        .environment(\.counterVM, vm)
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
