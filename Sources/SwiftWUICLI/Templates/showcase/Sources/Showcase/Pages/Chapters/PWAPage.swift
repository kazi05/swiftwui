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
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("{\"name\": \"SwiftWUI Counter\",") }
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(11))
                            .foregroundColor(.token("swui-fg-2"))
                        Span { Text(" \"display\": \"standalone\",") }
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(11))
                            .foregroundColor(.token("swui-fg-2"))
                        Span { Text(" \"theme_color\": \"#0a84ff\"}") }
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(11))
                            .foregroundColor(.token("swui-accent"))
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
                                .fontSize(.px(11))
                                .foregroundColor(.token("swui-fg-3"))
                        }
                        .style("width", "48px")
                        .style("height", "48px")
                        .borderRadius(.px(10))
                        .backgroundColor(.token("swui-accent"))
                        .display(.flex)
                        .alignItems(.center)
                        .justifyContent(.center)
                        Div {
                            Span { Text("512x512 maskable") }
                                .fontSize(.px(11))
                                .foregroundColor(.css("#fff"))
                        }
                        .style("width", "64px")
                        .style("height", "64px")
                        .borderRadius(.px(16))
                        .backgroundColor(.token("swui-accent"))
                        .display(.flex)
                        .alignItems(.center)
                        .justifyContent(.center)
                        .style("margin-left", "12px")
                    }
                    .display(.flex)
                    .alignItems(.center)
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
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(11))
                            .foregroundColor(.token("swui-fg-2"))
                        Div {
                            Span { Text("Registration successful ✓") }
                                .fontSize(.px(13))
                                .foregroundColor(.css("#30d158"))
                        }
                        .style("margin-top", "8px")
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
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
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(11))
                            .foregroundColor(.token("swui-fg-2"))
                        Span { Text("      href=\"/manifest.webmanifest\">") }
                            .display(.block)
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(11))
                            .foregroundColor(.token("swui-accent"))
                        Div {
                            Span { Text("Install prompt available ✓") }
                                .fontSize(.px(13))
                                .foregroundColor(.css("#30d158"))
                        }
                        .style("margin-top", "8px")
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            )
        ),
    ] }
}
