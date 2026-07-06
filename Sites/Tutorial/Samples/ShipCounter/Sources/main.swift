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

    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.hex("#ffffff"))
            p.color(.hex("#1c1917"))
            p.fontFamily("system-ui, -apple-system, 'Segoe UI', sans-serif")
        }
        Rule(element: "main") { p in
            p.display(.flex)
            p.flexDirection(.column)
            p.alignItems(.center)
            p.padding(.top, .px(56))
        }
        // `.counter` is the pre-existing class on Counter's wrapping Div — referenced
        // here, not added (Counter is byte-pinned to Ch04.counterCode).
        Rule(class: "counter") { p in
            p.display(.flex)
            p.flexWrap(.wrap)
            p.justifyContent(.center)
            p.alignItems(.center)
            p.style("gap", "20px 12px")
        }
        // width:100% forces h1 onto its own line in the wrap container above,
        // leaving the two buttons to share the next line as a row.
        Rule(element: "h1") { p in
            p.fontSize(.px(32))
            p.fontWeight(.bold)
            p.letterSpacing(.px(-0.5))
            p.style("width", "100%")
            p.textAlign(.center)
        }
        // ponytail: Counter's two Button calls are byte-pinned with no class hook,
        // so +/- can't be styled differently from pure CSS — both get one look.
        Rule(element: "button") { p in
            p.width(.px(44))
            p.height(.px(44))
            p.borderRadius(.px(10))
            p.fontSize(.px(18))
            p.fontWeight(.custom(500))
            p.background(.hex("#d9552f"))
            p.color(.hex("#fffaf5"))
            p.border(.zero, .none, .transparent)
            p.cursor(.pointer)
        }
        Rule(element: "h2") { p in
            p.fontSize(.px(22))
            p.fontWeight(.bold)
        }
        Rule(element: "a") { p in
            p.color(.hex("#57534e"))
            p.textDecoration(.none)
        }
        Rule(element: "p") { p in
            p.fontSize(.px(15))
            p.color(.hex("#57534e"))
        }
    }
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
