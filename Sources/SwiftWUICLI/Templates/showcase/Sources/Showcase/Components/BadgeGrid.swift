// BadgeGrid.swift — "What's Inside" mini-grid for non-chapter features.

import SwiftWUI

public struct BadgeGrid: Tag {
    public struct Item: Identifiable, Sendable {
        public let title: String
        public let description: String
        public var id: String { title }
        public init(title: String, description: String) {
            self.title = title
            self.description = description
        }
    }

    let items: [Item]

    public init(items: [Item]) { self.items = items }

    public var body: some Tag {
        Div {
            ForEach(items) { item in
                Div {
                    H4 { Text(item.title) }
                        .fontSize(.px(12))
                        .fontWeight(.w600)
                        .marginBottom(.px(4))
                        .foregroundColor(.token("swui-fg"))
                    P { Text(item.description) }
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-3"))
                        .lineHeight(.unitless(1.3))
                        .margin(.zero)
                }
                .backgroundColor(.token("swui-surface"))
                .border(.px(1), .solid, .token("swui-border"))
                .style("border-radius", "var(--radius-sm)")
                .padding(.px(12), .px(14))
            }
        }
        .display(.grid)
        .gridTemplateColumns("repeat(auto-fit, minmax(200px, 1fr))")
        .gap(.px(10))
        .attribute("data-swui-badgegrid", "true")
    }
}
