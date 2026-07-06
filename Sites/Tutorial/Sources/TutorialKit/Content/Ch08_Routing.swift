/// Chapter 8 — Route between pages (Figma 12:34 + authored sections).
public enum Ch08 {
    static let routesCode = #"""
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
"""#
    static let linksCode = #"""
struct NavBar: Tag {
    var body: some Tag {
        Nav(class: "bar") {
            Link("/") { Span { "Home" } }
            Link("/chat") { Span { "Chat" } }
            Link("/docs/routing") { Span { "Docs" } }
        }
    }
}
"""#

    public static let chapter = Chapter(
        slug: "route-between-pages", track: .routing, kicker: "CHAPTER · ROUTING",
        title: "Route between pages",
        tagline: "Declare routes as data, render a Tag per path, and let the framework drive browser history.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "router", kicker: "01 · ROUTER",
                    title: "Declare your routes",
                    intro: "Routes are data: a pattern, an optional guard, and content.",
                    steps: [
                        Step("Router is just a Tag — declare it in your App body."),
                        Step("Route maps a pattern to content; first match wins in declaration order."),
                        Step("Dynamic segments capture values: Route(\"/docs/:page\") { params in … }."),
                        Step("notFound content renders when nothing matches."),
                    ],
                    panel: .code(CodePanel(file: "App.swift", code: routesCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/ChatRouter/Sources/main.swift",
                                                           marker: "chat-routes")))),
            Section(anchor: "navigation", kicker: "02 · NAVIGATION",
                    title: "Links and programmatic navigation",
                    intro: "Navigation is interception, not page loads.",
                    steps: [
                        Step("Link(\"/chat\") renders an <a> and intercepts the click into SPA navigation."),
                        Step("Cmd-click and middle-click fall through to the browser — new tabs still work."),
                        Step("Programmatic: read @Environment(\\.navigate), then navigate(\"/chat\") or navigate(path, replace: true)."),
                        Step("External URLs render as plain anchors — the browser handles them."),
                    ],
                    panel: .code(CodePanel(file: "NavBar.swift", code: linksCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/ChatRouter/Sources/main.swift",
                                                           marker: "chat-links")))),
            Section(anchor: "identity", kicker: "03 · STATE & IDENTITY",
                    title: "Identity across navigation",
                    intro: "Route identity decides which state survives a URL change.",
                    steps: [
                        Step("Matched content is keyed by its route pattern in the tree."),
                        Step("Param-only changes (/docs/intro → /docs/api) keep the page’s @State."),
                        Step("Switching routes tears state down — a fresh page starts clean."),
                    ],
                    panel: .browser(url: "localhost:8080/chat", screenshot: "screens/chat-router.png")),
        ])
}
