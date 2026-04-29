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
                    .style("color", "var(--swui-accent)")
                    .style("font-size", "10px")
                    .style("font-weight", "600")
                    .style("letter-spacing", "0.08em")
                    .style("text-transform", "uppercase")
                    .style("margin", "0 0 8px")
                H1 { Text(title) }
                    .style("font-family", "var(--font-display)")
                    .style("font-size", "32px")
                    .style("font-weight", "700")
                    .style("letter-spacing", "-0.02em")
                    .style("margin", "0 0 12px")
                    .style("color", "var(--swui-fg)")
                P { Text(lead) }
                    .style("font-size", "15px")
                    .style("color", "var(--swui-fg-2)")
                    .style("line-height", "1.55")
                    .style("max-width", "640px")
                    .style("margin", "0 0 18px")
                metaRow
            }
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "40px \(Layout.pageHorizontalPadding) 24px")
        }
        .style("border-bottom", "1px solid var(--swui-border)")
        .attribute("data-swui-chapter-intro", "true")
    }

    private var metaRow: some Tag {
        Div {
            ForEach(metaItems) { item in
                Span {
                    Text("\(item.label): ")
                    Span { Text(item.value) }
                        .style("color", "var(--swui-fg)")
                        .style("font-weight", "600")
                }
                .style("color", "var(--swui-fg-3)")
                .style("font-size", "11px")
                .style("margin-right", "20px")
            }
        }
        .style("display", "flex")
        .style("flex-wrap", "wrap")
        .style("gap", "0")
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
