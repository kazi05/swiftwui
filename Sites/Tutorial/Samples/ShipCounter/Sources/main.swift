import SwiftWUI
import SwiftWUIDOM

struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
            if count >= 10 { P { "Double digits." } }
        }
    }
}

struct HomePage: Tag, Page {
    var title: String { "ShipCounter" }
    var body: some Tag {
        Main { Counter() }
    }
}

// tutorial:begin ship-static
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
// tutorial:end ship-static

struct RootApp: Tag {
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
    }
}

struct ShipCounterApp: App {
    var body: some Tag { RootApp() }
}

#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

// tutorial:begin ship-ssg
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
// tutorial:end ship-ssg
#else
@main enum Entry {
    static func main() { ShipCounterApp.main() }
}
#endif
