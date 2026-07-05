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
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: {{NAME}} ssg --out <dir> [--static]")
            return
        }
        args.removeFirst()
        var out = "dist"
        var mode = StaticSiteMode.hydrate(wasmScriptPath: "/app/index.js")
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            case "--static": mode = .staticOnly
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate({{NAME}}App.self,
                                                   config: .init(outDir: out, mode: mode))
        print("generated \(report.pages.count) pages")
    }
}
#else
@main enum Entry {
    static func main() { {{NAME}}App.main() }
}
#endif
