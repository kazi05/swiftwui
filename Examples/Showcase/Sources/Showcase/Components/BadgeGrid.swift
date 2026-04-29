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
                        .style("font-size", "12px")
                        .style("font-weight", "600")
                        .style("margin", "0 0 4px")
                        .style("color", "var(--swui-fg)")
                    P { Text(item.description) }
                        .style("font-size", "11px")
                        .style("color", "var(--swui-fg-3)")
                        .style("line-height", "1.3")
                        .style("margin", "0")
                }
                .style("background", "var(--swui-surface)")
                .style("border", "1px solid var(--swui-border)")
                .style("border-radius", "var(--radius-sm)")
                .style("padding", "12px 14px")
            }
        }
        .style("display", "grid")
        .style("grid-template-columns", "repeat(auto-fit, minmax(200px, 1fr))")
        .style("gap", "10px")
        .attribute("data-swui-badgegrid", "true")
    }
}
