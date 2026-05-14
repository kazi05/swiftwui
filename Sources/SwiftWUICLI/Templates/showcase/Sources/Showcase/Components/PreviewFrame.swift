// PreviewFrame.swift — browser-window chrome wrapping a step's preview content.

import SwiftWUI

public struct PreviewFrame: Tag {
    public let kind: PreviewKind
    public let label: String

    public init(kind: PreviewKind, label: String = "localhost:8080") {
        self.kind = kind
        self.label = label
    }

    public var body: some Tag {
        Div {
            // Window chrome
            Div {
                Div { EmptyTag() }
                    .backgroundColor(.css("#ff5f57"))
                    .width(.px(12))
                    .height(.px(12))
                    .borderRadius(.percent(50))
                Div { EmptyTag() }
                    .backgroundColor(.css("#ffbd2e"))
                    .width(.px(12))
                    .height(.px(12))
                    .borderRadius(.percent(50))
                Div { EmptyTag() }
                    .backgroundColor(.css("#28c840"))
                    .width(.px(12))
                    .height(.px(12))
                    .borderRadius(.percent(50))
                Div { EmptyTag() }.style("flex", "1")
                Span { Text(label) }
                    .fontFamily("var(--font-mono)")
                    .fontSize(.px(11))
                    .foregroundColor(.token("swui-fg-3"))
                Div { EmptyTag() }.style("flex", "1")
            }
            .display(.flex)
            .alignItems(.center)
            .gap(.px(6))
            .padding(.px(8), .px(12))
            .backgroundColor(.token("swui-surface"))
            .borderBottom(.px(1), .solid, .token("swui-border"))

            // Body
            Div {
                bodyContent
            }
            .padding(.px(20))
        }
        .backgroundColor(.token("swui-bg"))
        .border(.px(1), .solid, .token("swui-border"))
        .borderRadius(.px(10))
        .overflow(.hidden)
        .attribute("data-swui-preview-pane", "true")
    }

    @TagBuilder private var bodyContent: some Tag {
        switch kind {
        case .live(let tag):
            tag
        case .screenshot(let path):
            Img(src: "/snapshots/\(path)", alt: "Preview screenshot")
                .maxWidth(.percent(100))
                .display(.block)
        }
    }
}
