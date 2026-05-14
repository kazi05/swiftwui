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
                Div { EmptyTag() }.flex(1)
                nextLink
            }
            .display(.flex)
            .alignItems(.center)
            .style("max-width", Layout.maxContentWidth)
            .margin(.zero, .auto)
            .style("padding", "32px \(Layout.pageHorizontalPadding)")
        }
        .borderTop(width: .px(1), style: .solid, color: .token("swui-border"))
        .backgroundColor(.token("swui-surface"))
        .attribute("data-swui-chapter-footer", "true")
    }

    private var prevLink: some Tag {
        Div {
            if let prev {
                A(href: prev.href) { Text("← \(prev.label)") }
                    .foregroundColor(.token("swui-accent"))
                    .fontSize(.px(13))
                    .fontWeight(.w500)
                    .textDecoration(.none)
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
                        .fontSize(.px(10))
                        .foregroundColor(.token("swui-fg-3"))
                        .textTransform(.uppercase)
                        .letterSpacing(.em(0.06))
                        .marginBottom(.px(4))
                    A(href: next.href) { Text("\(next.label) →") }
                        .foregroundColor(.token("swui-accent"))
                        .fontSize(.px(13))
                        .fontWeight(.w600)
                        .textDecoration(.none)
                }
                .textAlign(.right)
            } else {
                Span { EmptyTag() }
            }
        }
    }
}
