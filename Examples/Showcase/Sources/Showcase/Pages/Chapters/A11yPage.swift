// A11yPage.swift — Chapter 9: Accessibility

import SwiftWUI

public struct A11yPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 9 — Production",
                title: "Accessibility",
                lead: "Accessible apps reach every user. SwiftWUI provides .aria() modifiers for labels, roles, and live regions, semantic layout tags (Header, Nav, Main, Footer), and .accessibilityLabel for paired elements.",
                meta: [
                    ("Estimated time", "8 min"),
                    ("Difficulty", "Intermediate"),
                    ("Module", "SwiftWUIHTML"),
                ]
            )
            ScrollyTeller(steps: a11ySteps)
            ChapterFooter(prev: ("Theming", "/learn/theming"), next: ("Error Handling", "/learn/errors"))
            HighlightOnMount()
        }
    }

    private var a11ySteps: [ScrollyTeller.Step] { [
        .init(
            number: 1,
            title: "Label elements with .aria(label:)",
            prose: "`.aria(label: \"Close\")` sets `aria-label` on any element. Screen readers announce this label instead of inner text, so icon-only buttons become understandable without a visible caption.",
            code: """
            Button(onclick: close) {
              Text("×")
            }
            .aria(label: "Close dialog")
            .aria(role: .button)
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("aria-label=\"Close dialog\"") }
                            .style("font-family", "var(--font-mono)")
                            .style("font-size", "12px")
                            .style("color", "var(--swui-fg-3)")
                        Span { Text("×") }
                            .style("display", "inline-block")
                            .style("margin-top", "8px")
                            .style("width", "28px")
                            .style("height", "28px")
                            .style("line-height", "28px")
                            .style("text-align", "center")
                            .style("border", "1px solid var(--swui-border)")
                            .style("border-radius", "6px")
                            .style("font-size", "16px")
                            .style("color", "var(--swui-fg)")
                            .style("cursor", "pointer")
                    }
                }
            )
        ),
        .init(
            number: 2,
            title: "Assign ARIA roles explicitly",
            prose: "`.aria(role: .button)` adds `role=\"button\"` to any element. Use this when a `Div` or `Span` is styled to look interactive — it ensures assistive technology treats it correctly without rewriting the markup.",
            code: """
            Div { Text("Save") }
              .style("cursor", "pointer")
              .aria(role: .button)
              .aria(label: "Save document")
            """,
            preview: AnyTag(
                Div {
                    Div { Text("Save") }
                        .style("cursor", "pointer")
                        .style("display", "inline-block")
                        .style("padding", "7px 16px")
                        .style("background", "var(--swui-surface-2)")
                        .style("border", "1px solid var(--swui-border)")
                        .style("border-radius", "6px")
                        .style("font-size", "13px")
                        .style("color", "var(--swui-fg)")
                }
            )
        ),
        .init(
            number: 3,
            title: "Use semantic layout tags",
            prose: "Replace generic `Div` wrappers with `Header`, `Nav`, `Main`, and `Footer` to give the browser and screen readers a navigable landmark map. These tags render identically but carry implicit ARIA landmark roles.",
            code: """
            Header { SiteNav() }
            Main  {
              H1  { Text("Dashboard") }
              Article { /* content */ }
            }
            Footer { Text("© 2025") }
            """,
            preview: AnyTag(
                Div {
                    Div {
                        Span { Text("header (role=banner)") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("background", "var(--swui-surface-2)")
                            .style("font-size", "12px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-fg-3)")
                        Span { Text("main (role=main)") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("font-size", "12px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-accent)")
                        Span { Text("footer (role=contentinfo)") }
                            .style("display", "block")
                            .style("padding", "5px 10px")
                            .style("background", "var(--swui-surface-2)")
                            .style("font-size", "12px")
                            .style("font-family", "var(--font-mono)")
                            .style("color", "var(--swui-fg-3)")
                    }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "6px")
                    .style("overflow", "hidden")
                }
            )
        ),
        .init(
            number: 4,
            title: "Announce live updates with aria-live",
            prose: "`.aria(live: .polite)` tells screen readers to announce the element's text when it changes without interrupting the current speech. Use `.assertive` for critical alerts that should pre-empt other announcements.",
            code: """
            P { Text(statusMessage) }
              .aria(live: .polite)
              .aria(busy: isLoading)
            """,
            preview: AnyTag(
                Div {
                    Span { Text("aria-live=\"polite\"") }
                        .style("font-family", "var(--font-mono)")
                        .style("font-size", "12px")
                        .style("color", "var(--swui-fg-3)")
                    Div {
                        Span { Text("3 items saved successfully") }
                            .style("font-size", "14px")
                            .style("color", "#30d158")
                            .style("font-weight", "500")
                    }
                    .style("margin-top", "6px")
                    .style("padding", "8px 12px")
                    .style("background", "var(--swui-surface-2)")
                    .style("border-radius", "6px")
                }
            )
        ),
    ] }
}
