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
            highlightLines: [4],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Span { Text("aria-label=\"Close dialog\"") }
                            .fontFamily("var(--font-mono)")
                            .fontSize(.px(12))
                            .foregroundColor(.token("swui-fg-3"))
                        Span { Text("×") }
                            .display(.inlineBlock)
                            .style("margin-top", "8px")
                            .style("width", "28px")
                            .style("height", "28px")
                            .style("line-height", "28px")
                            .style("text-align", "center")
                            .border(.px(1), .solid, .token("swui-border"))
                            .borderRadius(.px(6))
                            .fontSize(.px(16))
                            .foregroundColor(.token("swui-fg"))
                            .cursor(.pointer)
                    }
                }
            ))
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
            highlightLines: [3],
            preview: .live(AnyTag(
                Div {
                    Div { Text("Save") }
                        .cursor(.pointer)
                        .display(.inlineBlock)
                        .padding(.px(7), .px(16))
                        .backgroundColor(.token("swui-surface-2"))
                        .border(.px(1), .solid, .token("swui-border"))
                        .borderRadius(.px(6))
                        .fontSize(.px(13))
                        .foregroundColor(.token("swui-fg"))
                }
            ))
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
            highlightLines: [1, 2, 6],
            preview: .live(AnyTag(
                Div {
                    Div {
                        Span { Text("header (role=banner)") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .backgroundColor(.token("swui-surface-2"))
                            .fontSize(.px(12))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-fg-3"))
                        Span { Text("main (role=main)") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .fontSize(.px(12))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-accent"))
                        Span { Text("footer (role=contentinfo)") }
                            .display(.block)
                            .padding(.px(5), .px(10))
                            .backgroundColor(.token("swui-surface-2"))
                            .fontSize(.px(12))
                            .fontFamily("var(--font-mono)")
                            .foregroundColor(.token("swui-fg-3"))
                    }
                    .border(.px(1), .solid, .token("swui-border"))
                    .borderRadius(.px(6))
                    .overflow(.hidden)
                }
            ))
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
            highlightLines: [2],
            preview: .live(AnyTag(
                Div {
                    Span { Text("aria-live=\"polite\"") }
                        .fontFamily("var(--font-mono)")
                        .fontSize(.px(12))
                        .foregroundColor(.token("swui-fg-3"))
                    Div {
                        Span { Text("3 items saved successfully") }
                            .fontSize(.px(14))
                            .foregroundColor(.css("#30d158"))
                            .fontWeight(.w500)
                    }
                    .style("margin-top", "6px")
                    .padding(.px(8), .px(12))
                    .backgroundColor(.token("swui-surface-2"))
                    .borderRadius(.px(6))
                }
            ))
        ),
    ] }
}
