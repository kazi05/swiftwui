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
                    .fontFamily("var(--font-mono)")
                    .fontSize(.px(11))
                    .foregroundColor(.token("swui-accent"))
                    .padding(.zero, .px(16))
                    .display(.flex)
                    .alignItems(.center)
                    .justifyContent(.center)
                    .height(.px(90))
                    .style("background", "linear-gradient(135deg, var(--swui-surface), var(--swui-surface-2))")
                Div {
                    P { Text("CHAPTER \(number)") }
                        .fontSize(.px(10))
                        .foregroundColor(.token("swui-fg-3"))
                        .letterSpacing(.em(0.06))
                        .marginBottom(.px(4))
                    H3 { Text(title) }
                        .fontSize(.px(16))
                        .fontWeight(.w600)
                        .marginBottom(.px(6))
                        .foregroundColor(.token("swui-fg"))
                    P { Text(subtitle) }
                        .fontSize(.px(13))
                        .foregroundColor(.token("swui-fg-3"))
                        .lineHeight(.unitless(1.4))
                        .margin(.zero)
                }
                .padding(.px(14), .px(16))
                .style("padding-bottom", "18px")
            }
            .backgroundColor(.token("swui-surface"))
            .border(.px(1), .solid, .token("swui-border"))
            .style("border-radius", "var(--radius-md)")
            .overflow(.hidden)
            .attribute("data-swui-chapter-card", "true")
        }
        .textDecoration(.none)
        .foregroundColor(.inherit)
        .display(.block)
    }
}
