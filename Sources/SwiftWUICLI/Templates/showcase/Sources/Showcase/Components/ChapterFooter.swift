// ChapterFooter.swift — prev/next link bar at the bottom of every chapter.

import SwiftWUI

public struct ChapterFooter: Tag {
    public let prev: (label: String, href: String)?
    public let next: (label: String, href: String)?

    public init(prev: (String, String)?, next: (String, String)?) {
        self.prev = prev
        self.next = next
    }

    public var body: some Tag {
        Div {
            Div {
                prevLink
                Div { EmptyTag() }.style("flex", "1")
                nextLink
            }
            .style("display", "flex")
            .style("align-items", "center")
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "32px \(Layout.pageHorizontalPadding)")
        }
        .style("border-top", "1px solid var(--swui-border)")
        .style("background", "var(--swui-surface)")
        .attribute("data-swui-chapter-footer", "true")
    }

    private var prevLink: some Tag {
        Div {
            if let prev {
                A(href: prev.href) { Text("← \(prev.label)") }
                    .style("color", "var(--swui-accent)")
                    .style("font-size", "13px")
                    .style("font-weight", "500")
                    .style("text-decoration", "none")
            } else {
                Span { EmptyTag() }
            }
        }
    }

    private var nextLink: some Tag {
        Div {
            if let next {
                Div {
                    P { Text("UP NEXT") }
                        .style("font-size", "10px")
                        .style("color", "var(--swui-fg-3)")
                        .style("text-transform", "uppercase")
                        .style("letter-spacing", "0.06em")
                        .style("margin", "0 0 4px")
                    A(href: next.href) { Text("\(next.label) →") }
                        .style("color", "var(--swui-accent)")
                        .style("font-size", "13px")
                        .style("font-weight", "600")
                        .style("text-decoration", "none")
                }
                .style("text-align", "right")
            } else {
                Span { EmptyTag() }
            }
        }
    }
}
