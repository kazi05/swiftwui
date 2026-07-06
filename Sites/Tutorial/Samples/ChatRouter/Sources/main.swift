import SwiftWUI
import SwiftWUIDOM

// tutorial:begin chat-links
struct NavBar: Tag {
    var body: some Tag {
        Nav(class: "bar") {
            Link("/") { Span { "Home" } }
            Link("/chat") { Span { "Chat" } }
            Link("/docs/routing") { Span { "Docs" } }
        }
    }
}
// tutorial:end chat-links

struct Home: Tag, Page {
    var title: String { "Home — ChatRouter" }
    var body: some Tag {
        Main { NavBar(); H1("Home"); P { "A tiny three-route app." } }
    }
}

struct Chat: Tag, Page {
    @State private var messages = ["Welcome to the chat."]
    @State private var draft = ""
    var title: String { "Chat — ChatRouter" }
    var body: some Tag {
        Main {
            NavBar()
            H1("Chat")
            Ul(class: "log") {
                ForEach(Array(messages.enumerated()), id: \.offset) { item in
                    Li { Text(item.element) }
                }
            }
            Input(type: .text, value: $draft)
            Button("Send") {
                let text = draft
                if !text.isEmpty { messages.append(text); draft = "" }
            }
        }
    }
}

struct DocPage: Tag, Page {
    let slug: String
    var title: String { "\(slug) — Docs" }
    var body: some Tag {
        Main {
            NavBar()
            H1("Docs: \(slug)")
            P { "Route parameters arrive as typed captures — same page Tag, different data." }
        }
    }
}

// tutorial:begin chat-routes
struct ChatApp: App {
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { Home() }
            Route("/chat") { Chat() }
            Route("/docs/:page") { params in
                DocPage(slug: params["page"] ?? "intro")
            }
        }
    }
}
// tutorial:end chat-routes

extension ChatApp {
    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.hex("#faf9f7"))
            p.color(.hex("#1c1917"))
            p.fontFamily("system-ui, -apple-system, 'Segoe UI', sans-serif")
        }
        // flex-wrap + width:100% on nav/h1/.log forces each onto its own line;
        // Input/Button (not full-width) share the trailing line as a row.
        Rule(element: "main") { p in
            p.display(.flex)
            p.flexWrap(.wrap)
            p.justifyContent(.center)
            p.alignItems(.center)
            p.gap(.px(16))
            p.maxWidth(.px(480))
            p.margin(vertical: .zero, horizontal: .auto)
            p.padding(.px(24))
            p.boxSizing(.borderBox)
        }
        Rule(element: "nav") { p in
            p.display(.flex)
            p.gap(.px(20))
            p.style("width", "100%")
            p.justifyContent(.center)
        }
        Rule(element: "a") { p in
            p.fontSize(.px(14))
            p.fontWeight(.custom(500))
            p.color(.hex("#57534e"))
            p.textDecoration(.none)
        }
        Rule(element: "h1") { p in
            p.fontSize(.px(24))
            p.fontWeight(.bold)
            p.style("width", "100%")
            p.textAlign(.center)
        }
        Rule(class: "log") { p in
            p.style("list-style", "none")
            p.style("padding-left", "0")
            p.style("width", "100%")
        }
        Rule(element: "li") { p in
            p.background(.white)
            p.padding(.px(12))
            p.borderRadius(.px(10))
            p.border(.px(1), .solid, .hex("#e7e5e0"))
            p.fontSize(.px(14))
            p.margin(.bottom, .px(8))
        }
        Rule(element: "input") { p in
            p.flexGrow(1)
            p.borderRadius(.px(8))
            p.border(.px(1), .solid, .hex("#e7e5e0"))
            p.padding(.px(10))
        }
        Rule(element: "button") { p in
            p.background(.hex("#d9552f"))
            p.color(.hex("#fffaf5"))
            p.borderRadius(.px(8))
            p.padding(vertical: .px(10), horizontal: .px(16))
            p.border(.zero, .none, .transparent)
            p.cursor(.pointer)
        }
    }
}

#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: ChatRouter ssg --out <dir> [--static]")
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
        let report = try await StaticSite.generate(ChatApp.self,
                                                   config: .init(outDir: out, mode: mode))
        print("generated \(report.pages.count) pages")
    }
}
#else
@main enum Entry {
    static func main() { ChatApp.main() }
}
#endif
