// PWAPage.swift — Chapter 12: PWA

import SwiftWUI

public struct PWAPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 12 — Production",
                title: "PWA",
                lead: "Progressive Web Apps install to home screens, work offline, and behave like native apps. SwiftWUI's Browser module provides WebAppManifest for typed manifest generation and ServiceWorker.register for one-call worker installation.",
                meta: [
                    ("Estimated time", "10 min"),
                    ("Difficulty", "Advanced"),
                    ("Module", "SwiftWUIBrowser"),
                ]
            )
            ScrollyTeller(steps: pwaSteps)
            ChapterFooter(prev: ("SSR & Hydration", "/learn/ssr"), next: nil)
            HighlightOnMount()
        }
    }

    private var pwaSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Build a WebAppManifest value",
            prose: "`WebAppManifest` is a typed Swift struct. Set `name`, `shortName`, `display`, `themeColor`, and `icons`. Call `.json()` to produce the `manifest.webmanifest` content — hand-rolled JSON, no Foundation dependency.",
            code: """
            let manifest = WebAppManifest(
              name:            "SwiftWUI Counter",
              shortName:       "Counter",
              startURL:        "/",
              display:         .standalone,
              themeColor:      "#0a84ff",
              backgroundColor: "#ffffff"
            )
            let json = manifest.json()
            // Serve at /manifest.webmanifest
            """,
            preview: AnyTag(
                Div {
                    Span { Text("manifest.webmanifest") }
                        .style("font-size", "12px")
                        .style("color", "var(--swui-fg-3)")
                    Div {
                        Span { Text("{\"name\": \"SwiftWUI Counter\",") }
                            .style("display", "block")
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "11px")
                            .style("color", "var(--swui-fg-2)")
                        Span { Text(" \"display\": \"standalone\",") }
                            .style("display", "block")
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "11px")
                            .style("color", "var(--swui-fg-2)")
                        Span { Text(" \"theme_color\": \"#0a84ff\"}") }
                            .style("display", "block")
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "11px")
                            .style("color", "var(--swui-accent)")
                    }
                    .style("margin-top", "8px")
                    .style("padding", "8px 12px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
        ),
        .init(
            number: 2,
            title: "Declare icons with purpose",
            prose: "The `Icon` nested struct captures `src`, `sizes`, `type`, and optional `purpose`. Supply a maskable icon so the OS can apply its safe-zone crop without clipping your logo on rounded home-screen tiles.",
            code: """
            WebAppManifest(
              name: "My App",
              icons: [
                .init(src: "/icon-192.png",
                      sizes: "192x192",
                      type:  "image/png"),
                .init(src: "/icon-512.png",
                      sizes: "512x512",
                      type:  "image/png",
                      purpose: .maskable),
              ]
            )
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Div {
                            Span { Text("192x192") }
                                .style("font-size", "11px")
                                .style("color", "var(--swui-fg-3)")
                        }
                        .style("width", "48px")
                        .style("height", "48px")
                        .style("border-radius", "10px")
                        .style("background", "var(--swui-accent)")
                        .style("display", "flex")
                        .style("align-items", "center")
                        .style("justify-content", "center")
                        Div {
                            Span { Text("512x512 maskable") }
                                .style("font-size", "11px")
                                .style("color", "#fff")
                        }
                        .style("width", "64px")
                        .style("height", "64px")
                        .style("border-radius", "16px")
                        .style("background", "var(--swui-accent)")
                        .style("display", "flex")
                        .style("align-items", "center")
                        .style("justify-content", "center")
                        .style("margin-left", "12px")
                    }
                    .style("display", "flex")
                    .style("align-items", "center")
                }
            )
        ),
        .init(
            number: 3,
            title: "Register the service worker",
            prose: "`ServiceWorker.register(at:)` wraps the browser's `navigator.serviceWorker.register()` API. It is a no-op in non-WASM builds and on insecure contexts, so the same call is safe in both server-rendered and client code.",
            code: """
            // In your WASM main.swift, after app.mount():
            ServiceWorker.register(at: "/sw.js")

            // With explicit scope:
            ServiceWorker.register(at: "/sw.js", scope: "/app/")
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("navigator.serviceWorker.register(\"/sw.js\")") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "11px")
                            .style("color", "var(--swui-fg-2)")
                        Div {
                            Span { Text("Registration successful ✓") }
                                .style("font-size", "13px")
                                .style("color", "#30d158")
                        }
                        .style("margin-top", "8px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
        ),
        .init(
            number: 4,
            title: "Link the manifest in the HTML head",
            prose: "The browser only reads the manifest if `<link rel=\"manifest\" href=\"/manifest.webmanifest\">` is present in the document head. Add this to `SSRDocumentOptions.stylesheets` or hand-write it into your `index.html` template.",
            code: """
            let options = SSRDocumentOptions(
              title: "My App",
              stylesheets: [
                .url("/styles.css"),
              ],
              wasmJSURL: "/app.js"
            )
            // Also add to index.html <head>:
            // <link rel="manifest" href="/manifest.webmanifest">
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("<link rel=\"manifest\"") }
                            .style("display", "block")
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "11px")
                            .style("color", "var(--swui-fg-2)")
                        Span { Text("      href=\"/manifest.webmanifest\">") }
                            .style("display", "block")
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "11px")
                            .style("color", "var(--swui-accent)")
                        Div {
                            Span { Text("Install prompt available ✓") }
                                .style("font-size", "13px")
                                .style("color", "#30d158")
                        }
                        .style("margin-top", "8px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
        ),
    ] }
}
