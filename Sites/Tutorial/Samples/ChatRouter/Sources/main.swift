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
