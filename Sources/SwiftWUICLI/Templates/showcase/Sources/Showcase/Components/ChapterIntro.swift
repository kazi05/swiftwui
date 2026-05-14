// ChapterIntro.swift — eyebrow + headline + lead + meta-row at the top
// of every chapter page.

import SwiftWUI

public struct ChapterIntro: Tag {
    let part: String
    let title: String
    let lead: String
    let meta: [(label: String, value: String)]

    public init(part: String, title: String, lead: String, meta: [(String, String)]) {
        self.part = part
        self.title = title
        self.lead = lead
        self.meta = meta
    }

    public var body: some Tag {
        Div {
            Div {
                P { Text(part) }
                    .foregroundColor(.token("swui-accent"))
                    .fontSize(.px(10))
                    .fontWeight(.w600)
                    .letterSpacing(.em(0.08))
                    .textTransform(.uppercase)
                    .marginBottom(.px(8))
                H1 { Text(title) }
                    .fontFamily("var(--font-display)")
                    .fontSize(.px(32))
                    .fontWeight(.w700)
                    .letterSpacing(.em(-0.02))
                    .marginBottom(.px(12))
                    .foregroundColor(.token("swui-fg"))
                P { Text(lead) }
                    .fontSize(.px(15))
                    .foregroundColor(.token("swui-fg-2"))
                    .lineHeight(.unitless(1.55))
                    .maxWidth(.px(640))
                    .marginBottom(.px(18))
                metaRow
            }
            .style("max-width", Layout.maxContentWidth)
            .margin(.zero, .auto)
            .style("padding", "40px \(Layout.pageHorizontalPadding) 24px")
        }
        .borderBottom(width: .px(1), style: .solid, color: .token("swui-border"))
        .attribute("data-swui-chapter-intro", "true")
    }

    private var metaRow: some Tag {
        Div {
            ForEach(metaItems) { item in
                Span {
                    Text("\(item.label): ")
                    Span { Text(item.value) }
                        .foregroundColor(.token("swui-fg"))
                        .fontWeight(.w600)
                }
                .foregroundColor(.token("swui-fg-3"))
                .fontSize(.px(11))
                .marginRight(.px(20))
            }
        }
        .display(.flex)
        .flexWrap(.wrap)
        .gap(.zero)
    }

    private var metaItems: [MetaItem] {
        meta.map { MetaItem(id: $0.label, label: $0.label, value: $0.value) }
    }

    fileprivate struct MetaItem: Identifiable {
        let id: String
        let label: String
        let value: String
    }
}
