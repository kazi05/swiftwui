// SSRPage.swift — Chapter 11: SSR & Hydration

import SwiftWUI

public struct SSRPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 11 — Production",
                title: "SSR & Hydration",
                lead: "StaticRenderer turns any Tag tree into an HTML string on the server. renderHTMLDocument emits a complete page with head, theme CSS, and a WASM bootstrap. Application.hydrate(on:) then re-attaches client interactivity over the pre-rendered DOM.",
                meta: [
                    ("Estimated time", "10 min"),
                    ("Difficulty", "Advanced"),
                    ("Module", "SwiftWUIRuntime"),
                ]
            )
            ScrollyTeller(steps: ssrSteps)
            ChapterFooter(prev: ("Error Handling", "/learn/errors"), next: ("PWA", "/learn/pwa"))
            HighlightOnMount()
        }
    }

    private var ssrSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Render a fragment to HTML string",
            prose: "`StaticRenderer().renderFragment(_:)` takes any `Tag` and returns an HTML string. Use this in a Vapor or Hummingbird route handler to produce partial HTML for AJAX responses or email templates.",
            code: """
            import SwiftWUIRuntime

            let renderer = StaticRenderer()
            let html = renderer.renderFragment(
              Div { H1 { Text("Hello, SSR") } }
            )
            // html == "<div><h1>Hello, SSR</h1></div>"
            """,
            preview: AnyTag(
                Div {
                    Span { Text("StaticRenderer output") }
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("<div><h1>Hello, SSR</h1></div>") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(13))
                            .foregroundColor(.css("#30d158"))
                    }
                    .style("margin-top", "8px")
                    .padding(.px(8), .px(12))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            )
        ),
        .init(
            number: 2,
            title: "Emit a full HTML document",
            prose: "`Application.renderHTMLDocument(_:)` wraps the server-rendered body in a complete HTML page including `<title>`, optional theme CSS, and a `<script>` tag that loads the WASM runtime for client take-over.",
            code: """
            let app = Application {
              Route("/") { HomePage() }
            }

            let html = app.renderHTMLDocument(SSRDocumentOptions(
              title: "My App",
              wasmJSURL: "/app.js",
              themeCSS: ThemeCSS.definitions(
                light: AppTheme.light,
                dark:  AppTheme.dark
              )
            ))
            // Serve html from Vapor route handler
            """,
            preview: AnyTag(
                Div {
                    Span { Text("<!DOCTYPE html>") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-2"))
                    Span { Text("<html><head><title>My App</title>…") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-2"))
                    Span { Text("<div id=\"app\"><!-- SSR content --></div>") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-accent"))
                }
                .padding(.px(10), .px(14))
                .backgroundColor(.token("swui-surface-2"))
                .borderRadius(.px(6))
            )
        ),
        .init(
            number: 3,
            title: "Hydrate on the client",
            prose: "`Application.hydrate(on:)` is the client-side counterpart to SSR. It mounts into the existing `#app` element and re-attaches event listeners without fully re-rendering the DOM, preserving first-paint content.",
            code: """
            // main.swift (WASM target)
            let app = Application {
              Route("/") { HomePage() }
            }
            app.hydrate(on: "app")
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("Server renders HTML") }
                            .display(.block)
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-fg-3"))
                            .fontFamily("var(--font-mono)")
                        Span { Text("WASM loads → hydrate(on: \"app\")") }
                            .display(.block)
                            .style("margin-top", "4px")
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-accent"))
                            .fontFamily("var(--font-mono)")
                        Span { Text("Event listeners attached ✓") }
                            .display(.block)
                            .style("margin-top", "4px")
                            .fontSize(.px(12))
                            .foregroundColor(.css("#30d158"))
                            .fontFamily("var(--font-mono)")
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            )
        ),
        .init(
            number: 4,
            title: "Embed initial state for hydration",
            prose: "Pass `initialState:` in `SSRDocumentOptions` to inline a JSON blob into the page as `window.__swiftwui_state`. The client can read this during hydration to skip a redundant API round-trip on first load.",
            code: """
            let options = SSRDocumentOptions(
              title: "Dashboard",
              wasmJSURL: "/app.js",
              initialState: userJSON // encoded on server
            )
            // Browser sees:
            // <script id="__swiftwui_state">{"user":"…"}</script>
            """,
            preview: AnyTag(
                Div {
                    Span { Text("<script id=\"__swiftwui_state\">") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-2"))
                    Span { Text("  {\"user\":{\"id\":42,\"name\":\"Kay\"}}") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-accent"))
                    Span { Text("</script>") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-2"))
                }
                .padding(.px(10), .px(14))
                .backgroundColor(.token("swui-surface-2"))
                .borderRadius(.px(6))
            )
        ),
    ] }
}
