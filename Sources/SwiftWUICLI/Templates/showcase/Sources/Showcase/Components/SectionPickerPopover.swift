// SectionPickerPopover.swift — lists current chapter's scrolly steps.

import SwiftWUI

public struct SectionPickerPopover: Tag {
    public let chapter: String
    public let stepTitles: [String]
    public let active: Int    // 1-indexed

    public init(chapter: String, stepTitles: [String], active: Int) {
        self.chapter = chapter
        self.stepTitles = stepTitles
        self.active = active
    }

    private struct StepRow: Identifiable {
        let id: Int           // 1-indexed step number doubles as identity
        let title: String
    }

    public var body: some Tag {
        let rows = stepTitles.enumerated().map { idx, title in
            StepRow(id: idx + 1, title: title)
        }

        return Div {
            ForEach(rows) { row in
                Div {
                    Text("\(row.id)  \(row.title)")
                }
                .display(.block)
                .padding(.px(8), .px(12))
                .borderRadius(.px(6))
                .fontSize(.px(13))
                .foregroundColor(.token(row.id == active ? "swui-accent" : "swui-fg-2"))
                .backgroundColor(row.id == active ? .token("swui-surface-2") : .transparent)
                .cursor(.pointer)
                .attribute("data-step", "\(row.id)")
            }
        }
        .display(.flex)
        .flexDirection(.column)
        .gap(.px(2))
        .padding(.px(8))
        .backgroundColor(.token("swui-surface"))
        .border(.px(1), .solid, .token("swui-border"))
        .borderRadius(.px(10))
        .boxShadow("0 16px 40px rgba(0,0,0,.35)")
        .minWidth(.px(240))
        .attribute("data-swui-popover", "section")
        .attribute("data-chapter", chapter)
        .attribute("data-active-step", "\(active)")
    }
}
