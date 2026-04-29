// HomePage.swift — landing page for the SwiftWUI {{project_name}}.

import SwiftWUI

public struct HomePage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            Hero(
                eyebrow: "Build with SwiftWUI",
                headline: "Real Swift. Right in the browser.",
                subhead: "A declarative web framework that compiles to WebAssembly. State, routing, SSR — all the Swift you already know.",
                primaryCTA: ("Get started", "/learn/hello"),
                ghostCTA: ("View on GitHub", "https://github.com/AkhtarGadique/SwiftWUI"),
                code: heroCode
            )
            chapterSection(
                eyebrow: "Part 1 — Essentials",
                title: "Get to know SwiftWUI",
                description: "Three chapters covering tags, state, and modifiers.",
                cards: [
                    .init(number: 1, title: "Hello, SwiftWUI",   subtitle: "Build your first declarative view.",        codeTeaser: "struct ContentView: Tag { … }",         href: "/learn/hello"),
                    .init(number: 2, title: "State & Bindings",  subtitle: "Reactive data with @State.",               codeTeaser: "@State var count = 0",                  href: "/learn/state"),
                    .init(number: 3, title: "Modifiers",         subtitle: "Style views with chained modifiers.",      codeTeaser: ".padding(.px(16)).fontSize(.px(20))",   href: "/learn/modifiers"),
                ]
            )
            chapterSection(
                eyebrow: "Part 2 — Building UI",
                title: "Compose your interface",
                description: "Lists, forms, routing, and async data.",
                cards: [
                    .init(number: 4, title: "Lists & ForEach",   subtitle: "Keyed reconciliation that preserves state.",  codeTeaser: "ForEach(items) { item in … }",          href: "/learn/lists"),
                    .init(number: 5, title: "Forms & Inputs",    subtitle: "Typed Slider, Stepper, Picker.",              codeTeaser: "Slider(value: $temp, in: 0...100)",     href: "/learn/forms"),
                    .init(number: 6, title: "Routing & Guards",  subtitle: "Routes, params, authentication.",            codeTeaser: "Route(\"/admin\", guard: …) { … }",     href: "/learn/routing"),
                    .init(number: 7, title: "Async & Resources", subtitle: "Fetch with .task and async/await.",          codeTeaser: ".task { items = await fetch() }",       href: "/learn/async"),
                ]
            )
            chapterSection(
                eyebrow: "Part 3 — Production",
                title: "Ship to the web",
                description: "Theming, accessibility, error handling, SSR, PWA.",
                cards: [
                    .init(number: 8,  title: "Theming",        subtitle: "Light + dark via CSS custom properties.",   codeTeaser: "ThemeCSS.definitions(light:dark:)",   href: "/learn/theming"),
                    .init(number: 9,  title: "Accessibility",  subtitle: "ARIA modifiers and semantic landmarks.",     codeTeaser: ".aria(label: \"Close\")",            href: "/learn/a11y"),
                    .init(number: 10, title: "Error Handling", subtitle: "Catch render errors with ErrorBoundary.",   codeTeaser: "ErrorBoundary { … }",                 href: "/learn/errors"),
                    .init(number: 11, title: "SSR & Hydration",subtitle: "Render on the server, hydrate on client.", codeTeaser: "Application.hydrate(on: \"app\")",   href: "/learn/ssr"),
                    .init(number: 12, title: "PWA",            subtitle: "Web App Manifest + Service Worker.",         codeTeaser: "WebAppManifest(name: …)",            href: "/learn/pwa"),
                ]
            )
            whatsInsideSection
            HighlightOnMount()
        }
    }

    fileprivate struct CardSpec: Identifiable {
        let number: Int
        let title: String
        let subtitle: String
        let codeTeaser: String
        let href: String
        var id: Int { number }
    }

    private func chapterSection(eyebrow: String, title: String, description: String, cards: [CardSpec]) -> some Tag {
        Div {
            Div {
                P { Text(eyebrow) }
                    .style("color", "var(--swui-accent)")
                    .style("font-size", "11px")
                    .style("font-weight", "600")
                    .style("letter-spacing", "0.08em")
                    .style("text-transform", "uppercase")
                    .style("margin", "0 0 8px")
                H2 { Text(title) }
                    .style("font-family", "var(--font-display)")
                    .style("font-size", "28px")
                    .style("font-weight", "600")
                    .style("margin", "0 0 4px")
                    .style("color", "var(--swui-fg)")
                P { Text(description) }
                    .style("font-size", "14px")
                    .style("color", "var(--swui-fg-3)")
                    .style("margin", "0 0 24px")
                Div {
                    cardGrid(cards: cards)
                }
                .style("display", "grid")
                .style("grid-template-columns", "repeat(auto-fit, minmax(240px, 1fr))")
                .style("gap", "16px")
            }
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "48px \(Layout.pageHorizontalPadding)")
        }
    }

    private func cardGrid(cards: [CardSpec]) -> some Tag {
        Div {
            ForEach(cards) { card in
                ChapterCard(
                    number: card.number,
                    title: card.title,
                    subtitle: card.subtitle,
                    codeTeaser: card.codeTeaser,
                    href: card.href
                )
            }
        }
    }

    private var whatsInsideSection: some Tag {
        Div {
            Div {
                P { Text("What's Inside") }
                    .style("color", "var(--swui-accent)")
                    .style("font-size", "11px")
                    .style("font-weight", "600")
                    .style("letter-spacing", "0.08em")
                    .style("text-transform", "uppercase")
                    .style("margin", "0 0 8px")
                H2 { Text("Production-ready features") }
                    .style("font-family", "var(--font-display)")
                    .style("font-size", "24px")
                    .style("margin", "0 0 4px")
                P { Text("Available in the framework — covered briefly in chapters or in the README.") }
                    .style("font-size", "14px")
                    .style("color", "var(--swui-fg-3)")
                    .style("margin", "0 0 16px")
                BadgeGrid(items: [
                    .init(title: "Container Queries",  description: "Component-level responsive styles"),
                    .init(title: "Anchor Positioning", description: "Type-safe popover positioning"),
                    .init(title: "Parameter Packs",    description: "Zero-cost variadic tag tuples"),
                    .init(title: "Hot Reload",         description: "Sub-second iteration in dev"),
                    .init(title: "Brotli + SRI",       description: "Compressed, integrity-checked builds"),
                    .init(title: "TestRenderer",       description: "Native unit tests, no browser"),
                    .init(title: "QueryParam",         description: "URL-driven state with @QueryParam"),
                    .init(title: "Doctor command",     description: "Toolchain health check"),
                ])
            }
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "32px \(Layout.pageHorizontalPadding) 64px")
        }
    }

    private var heroCode: String {
        """
        struct Counter: Tag {
          @State var count = 0
          var body: some Tag {
            Button(onclick: { count += 1 }) {
              Text("Tapped \\(count)")
            }
          }
        }
        """
    }
}

