// ChapterCard.swift — thumbnail card on the home grid.

import SwiftWUI

public struct ChapterCard: Tag {
    let number: Int
    let title: String
    let subtitle: String
    let codeTeaser: String
    let href: String

    public init(number: Int, title: String, subtitle: String, codeTeaser: String, href: String) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.codeTeaser = codeTeaser
        self.href = href
    }

    public var body: some Tag {
        A(href: href) {
            Div {
                Div { Text(codeTeaser) }
                    .style("font-family", "var(--font-mono)")
                    .style("font-size", "11px")
                    .style("color", "#884400")
                    .style("padding", "0 16px")
                    .style("display", "flex")
                    .style("align-items", "center")
                    .style("justify-content", "center")
                    .style("height", "90px")
                    .style("background", "linear-gradient(135deg, #fff5e8, #ffe4cc)")
                Div {
                    P { Text("CHAPTER \(number)") }
                        .style("font-size", "10px")
                        .style("color", "var(--swui-fg-3)")
                        .style("letter-spacing", "0.06em")
                        .style("margin", "0 0 4px")
                    H3 { Text(title) }
                        .style("font-size", "16px")
                        .style("font-weight", "600")
                        .style("margin", "0 0 6px")
                        .style("color", "var(--swui-fg)")
                    P { Text(subtitle) }
                        .style("font-size", "13px")
                        .style("color", "var(--swui-fg-3)")
                        .style("line-height", "1.4")
                        .style("margin", "0")
                }
                .style("padding", "14px 16px 18px")
            }
            .style("background", "var(--swui-surface)")
            .style("border", "1px solid var(--swui-border)")
            .style("border-radius", "var(--radius-md)")
            .style("overflow", "hidden")
            .attribute("data-swui-chapter-card", "true")
        }
        .style("text-decoration", "none")
        .style("color", "inherit")
        .style("display", "block")
    }
}
