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
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("tokens: [String: String]") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-2)")
                        Div {
                            Span { Text("--background: #ffffff") }
                                .style("display", "block")
                                .style("font-family", "var(--font-mono)")
                                .style("font-size", "12px")
                                .style("color", "#30d158")
                            Span { Text("--accent: #0066ff") }
                                .style("display", "block")
                                .style("font-family", "var(--font-mono)")
                                .style("font-size", "12px")
                                .style("color", "#0066ff")
                        }
                        .style("margin-top", "6px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
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
            preview: AnyTag(
                Div {
                    Span { Text(":root { --background: #fff; … }") }
                        .style("display", "block")
                        .style("font-family", "var(--font-mono)")
                        .style("font-size", "11px")
                        .style("color", "var(--swui-fg-2)")
                    Span { Text("@media (prefers-color-scheme: dark) { … }") }
                        .style("display", "block")
                        .style("font-family", "var(--font-mono)")
                        .style("font-size", "11px")
                        .style("color", "var(--swui-fg-2)")
                    Span { Text("[data-theme=\"dark\"] { … }") }
                        .style("display", "block")
                        .style("font-family", "var(--font-mono)")
                        .style("font-size", "11px")
                        .style("color", "var(--swui-accent)")
                }
                .style("padding", "10px 14px")
                .style("background", "var(--swui-surface-2)")
                .style("border-radius", "6px")
            )
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
            preview: AnyTag(
                Div {
                    Div {
                        Div {
                            Span { Text("Light theme") }
                                .style("font-size", "13px")
                                .style("color", "#111")
                        }
                        .style("padding", "8px 14px")
                        .style("background", "#fff")
                        .style("border", "1px solid #e0e0e0")
                        .style("border-radius", "6px")
                        Div {
                            Span { Text("Dark theme") }
                                .style("font-size", "13px")
                                .style("color", "#f5f5f5")
                        }
                        .style("padding", "8px 14px")
                        .style("background", "#0a0a0a")
                        .style("border", "1px solid #333")
                        .style("border-radius", "6px")
                        .style("margin-top", "8px")
                    }
                }
            )
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
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("data-theme=\"sepia\"") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "12px")
                            .style("color", "#a0522d")
                        Div {
                            Span { Text("Warm reading palette") }
                                .style("font-size", "14px")
                                .style("color", "#5c4033")
                        }
                        .style("margin-top", "6px")
                    }
                    .style("padding", "10px 14px")
                    .style("background", "#f8f0e3")
                    .style("border-radius", "6px")
                    .style("border", "1px solid #d4b896")
                }
            )
        ),
    ] }
}
