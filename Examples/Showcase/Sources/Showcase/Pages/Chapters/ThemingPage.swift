// ThemingPage.swift — Chapter 8: Theming

import SwiftWUI

public struct ThemingPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 8 — Production",
                title: "Theming",
                lead: "SwiftWUI themes are typed token bags emitted as CSS custom properties. Define a light struct and a dark struct conforming to the Theme protocol, call ThemeCSS.definitions, and inject the CSS into your document head.",
                meta: [
                    ("Estimated time", "8 min"),
                    ("Difficulty", "Intermediate"),
                    ("Module", "SwiftWUIStyles"),
                ]
            )
            ScrollyTeller(steps: themingSteps)
            ChapterFooter(prev: ("Async & Resources", "/learn/async"), next: ("Accessibility", "/learn/a11y"))
            HighlightOnMount()
        }
    }

    private var themingSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Define a Theme conformance",
            prose: "Conform a struct to `Theme` and provide a `tokens` dictionary. Keys are CSS custom property names without the `--` prefix; values are any valid CSS value string.",
            code: """
            struct AppTheme: Theme {
              let tokens: [String: String]

              static let light = AppTheme(tokens: [
                "background": "#ffffff",
                "foreground": "#111111",
                "accent":     "#0066ff",
              ])
              static let dark = AppTheme(tokens: [
                "background": "#0a0a0a",
                "foreground": "#f5f5f5",
                "accent":     "#3b82f6",
              ])
            }
            """,
            highlightLines: [1, 2],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Span { Text("tokens: [String: String]") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-fg-2"))
                        Div {
                            Span { Text("--background: #ffffff") }
                                .display(.block)
                                .fontFamily("var(--font-mono)")
                                .fontSize(.px(12))
                                .foregroundColor(.css("#30d158"))
                            Span { Text("--accent: #0066ff") }
                                .display(.block)
                                .fontFamily("var(--font-mono)")
                                .fontSize(.px(12))
                                .foregroundColor(.css("#0066ff"))
                        }
                        .style("margin-top", "6px")
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            ))
        ),
        .init(
            number: 2,
            title: "Generate CSS with ThemeCSS",
            prose: "`ThemeCSS.definitions(light:dark:)` produces a `:root` block, a `prefers-color-scheme: dark` media query, and explicit `[data-theme=\"light\"]` / `[data-theme=\"dark\"]` attribute selectors.",
            code: """
            let css = ThemeCSS.definitions(
              light: AppTheme.light,
              dark:  AppTheme.dark
            )
            // css is a String — inject into <style> in index.html
            """,
            highlightLines: [1, 2, 3],
            preview: .live(AnyTag(
                Div {
                    Span { Text(":root { --background: #fff; … }") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-2"))
                    Span { Text("@media (prefers-color-scheme: dark) { … }") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-2"))
                    Span { Text("[data-theme=\"dark\"] { … }") }
                        .display(.block)
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-accent"))
                }
                .padding(.px(10), .px(14))
                .backgroundColor(.token("swui-surface-2"))
                .borderRadius(.px(6))
            ))
        ),
        .init(
            number: 3,
            title: "Force a theme via data-theme",
            prose: "Set the `data-theme` attribute on the `<html>` element to `\"dark\"` or `\"light\"` to override the OS preference. The explicit `[data-theme]` selectors win by CSS specificity without needing JavaScript priority tricks.",
            code: """
            // Force dark mode regardless of OS setting:
            Button(onclick: {
              // set document.documentElement.dataset.theme = "dark"
            }) {
              Text("Switch to Dark")
            }
            """,
            highlightLines: [3],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Div {
                            Span { Text("Light theme") }
                                .fontSize(.px(13))
                                .foregroundColor(.css("#111"))
                        }
                        .padding(.px(8), .px(14))
                        .backgroundColor(.css("#fff"))
                        .border(.px(1), .solid, .css("#e0e0e0"))
                        .borderRadius(.px(6))
                        Div {
                            Span { Text("Dark theme") }
                                .fontSize(.px(13))
                                .foregroundColor(.css("#f5f5f5"))
                        }
                        .padding(.px(8), .px(14))
                        .backgroundColor(.css("#0a0a0a"))
                        .border(.px(1), .solid, .css("#333"))
                        .borderRadius(.px(6))
                        .style("margin-top", "8px")
                    }
                }
            ))
        ),
        .init(
            number: 4,
            title: "Register a named palette",
            prose: "`ThemeCSS.definitions(named:theme:)` registers any extra palette under a `[data-theme=\"name\"]` selector. Use this for high-contrast, sepia, or brand-specific themes beyond the standard light/dark pair.",
            code: """
            let sepia = AppTheme(tokens: [
              "background": "#f8f0e3",
              "foreground": "#5c4033",
              "accent":     "#a0522d",
            ])
            let css = ThemeCSS.definitions(named: "sepia", theme: sepia)
            // [data-theme="sepia"] { --background: #f8f0e3; … }
            """,
            highlightLines: [6],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Span { Text("data-theme=\"sepia\"") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.css("#a0522d"))
                        Div {
                            Span { Text("Warm reading palette") }
                                .fontSize(.px(14))
                                .foregroundColor(.css("#5c4033"))
                        }
                        .style("margin-top", "6px")
                    }
                    .padding(.px(10), .px(14))
                    .backgroundColor(.css("#f8f0e3"))
                    .borderRadius(.px(6))
                    .border(.px(1), .solid, .css("#d4b896"))
                }
            ))
        ),
    ] }
}
