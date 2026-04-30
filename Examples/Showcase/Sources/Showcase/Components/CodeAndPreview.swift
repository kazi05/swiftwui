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
                .style("background", "var(--swui-surface-2)")
                .foregroundColor(.token("swui-fg-3"))
                .fontSize(.px(10))
                .fontWeight(.w600)
                .padding(.px(2), .px(8))
                .style("border-radius", "var(--radius-sm)")
                .marginBottom(.px(10))
            H3 { Text(title) }
                .fontSize(.px(20))
                .fontWeight(.w600)
                .style("margin", "0 0 8px")
                .foregroundColor(.token("swui-fg"))
            P { Text(prose) }
                .foregroundColor(.token("swui-fg-2"))
                .fontSize(.px(14))
                .style("line-height", "1.55")
                .style("margin", "0 0 14px")
                .maxWidth(.px(560))
            Pre {
                Code { Text(code) }
                    .attribute("class", "language-swift")
            }
            .style("background", "var(--swui-code-bg)")
            .foregroundColor(.token("swui-code-fg"))
            .style("border-radius", "var(--radius-sm)")
            .padding(.px(12), .px(14))
            .fontFamily("var(--font-mono)")
            .fontSize(.px(12))
            .style("margin", "0 0 16px")
            .overflowX(.auto)
            if showInlinePreview {
                Div { preview }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "var(--radius-sm)")
                    .padding(.px(16))
                    .style("background", "var(--swui-surface)")
                    .attribute("data-mobile-preview", "true")
            }
        }
        .style("background", "var(--swui-surface)")
        .style("border", "1px solid var(--swui-border)")
        .style("border-radius", "var(--radius-md)")
        .padding(.px(20), .px(22))
        .style("min-height", Layout.scrollyStepMinHeight)
        .attribute("data-scrolly-step", "\(stepNumber)")
    }
}
