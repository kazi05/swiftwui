// ChapterPickerPopover.swift — three-column grouped chapter list.

import SwiftWUI

public struct ChapterPickerPopover: Tag {
    public let active: String

    public init(active: String) { self.active = active }

    private struct GroupRow: Identifiable {
        let id: String           // group name doubles as identity
        let chapters: [ChapterInfo]
    }

    public var body: some Tag {
        let rows = ChapterRegistry.grouped().map {
            GroupRow(id: $0.group, chapters: $0.chapters)
        }

        return Div {
            ForEach(rows) { row in
                Div {
                    P { Text(row.id) }
                        .fontSize(.px(11))
                        .fontWeight(.w600)
                        .textTransform(.uppercase)
                        .letterSpacing(.em(0.06))
                        .foregroundColor(.token("swui-fg-3"))
                        .marginBottom(.px(8))
                    ForEach(row.chapters) { chapter in
                        A(href: chapter.path) {
                            Text("\(chapter.number) · \(chapter.title)")
                        }
                        .display(.block)
                        .padding(.px(6), .px(10))
                        .borderRadius(.px(6))
                        .fontSize(.px(13))
                        .foregroundColor(.token(chapter.id == active ? "swui-accent" : "swui-fg-2"))
                        .backgroundColor(chapter.id == active ? .token("swui-surface-2") : .transparent)
                        .textDecoration(.none)
                        .attribute("data-active", chapter.id == active ? chapter.id : "")
                    }
                }
                .minWidth(.px(180))
            }
        }
        .display(.grid)
        .gridTemplateColumns("repeat(3, 1fr)")
        .gap(.px(24))
        .padding(.px(16))
        .backgroundColor(.token("swui-surface"))
        .border(.px(1), .solid, .token("swui-border"))
        .borderRadius(.px(10))
        .boxShadow("0 16px 40px rgba(0,0,0,.35)")
        .attribute("data-swui-popover", "chapter")
    }
}
