// CodeAndPreview.swift — single step in a chapter scrolly-teller.

import SwiftWUI

public struct CodeAndPreview: Tag {
    let stepNumber: Int
    let title: String
    let prose: String
    let code: String
    let preview: AnyTag
    let showInlinePreview: Bool

    public init(stepNumber: Int, title: String, prose: String, code: String,
                preview: AnyTag, showInlinePreview: Bool = true) {
        self.stepNumber = stepNumber
        self.title = title
        self.prose = prose
        self.code = code
        self.preview = preview
        self.showInlinePreview = showInlinePreview
    }

    public var body: some Tag {
        Div {
            Span { Text("STEP \(stepNumber)") }
                .display(.inlineBlock)
                .backgroundColor(.token("swui-surface-2"))
                .foregroundColor(.token("swui-fg-3"))
                .fontSize(.px(10))
                .fontWeight(.w600)
                .padding(.px(2), .px(8))
                .style("border-radius", "var(--radius-sm)")
                .marginBottom(.px(10))
            H3 { Text(title) }
                .fontSize(.px(20))
                .fontWeight(.w600)
                .marginBottom(.px(8))
                .foregroundColor(.token("swui-fg"))
            P { Text(prose) }
                .foregroundColor(.token("swui-fg-2"))
                .fontSize(.px(14))
                .lineHeight(.unitless(1.55))
                .marginBottom(.px(14))
                .maxWidth(.px(560))
            Pre {
                Code { Text(code) }
                    .attribute("class", "language-swift")
            }
            .backgroundColor(.token("swui-code-bg"))
            .foregroundColor(.token("swui-code-fg"))
            .style("border-radius", "var(--radius-sm)")
            .padding(.px(12), .px(14))
            .fontFamily("var(--font-mono)")
            .fontSize(.px(12))
            .marginBottom(.px(16))
            .overflowX(.auto)
            if showInlinePreview {
                Div { preview }
                    .border(.px(1), .solid, .token("swui-border"))
                    .style("border-radius", "var(--radius-sm)")
                    .padding(.px(16))
                    .backgroundColor(.token("swui-surface"))
                    .attribute("data-mobile-preview", "true")
            }
        }
        .backgroundColor(.token("swui-surface"))
        .border(.px(1), .solid, .token("swui-border"))
        .style("border-radius", "var(--radius-md)")
        .padding(.px(20), .px(22))
        .style("min-height", Layout.scrollyStepMinHeight)
        .attribute("data-scrolly-step", "\(stepNumber)")
    }
}
