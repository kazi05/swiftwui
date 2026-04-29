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
                .style("display", "inline-block")
                .style("background", "var(--swui-surface-2)")
                .style("color", "var(--swui-fg-3)")
                .style("font-size", "10px")
                .style("font-weight", "600")
                .style("padding", "2px 8px")
                .style("border-radius", "var(--radius-sm)")
                .style("margin-bottom", "10px")
            H3 { Text(title) }
                .style("font-size", "20px")
                .style("font-weight", "600")
                .style("margin", "0 0 8px")
                .style("color", "var(--swui-fg)")
            P { Text(prose) }
                .style("color", "var(--swui-fg-2)")
                .style("font-size", "14px")
                .style("line-height", "1.55")
                .style("margin", "0 0 14px")
                .style("max-width", "560px")
            Pre {
                Code { Text(code) }
                    .attribute("class", "language-swift")
            }
            .style("background", "var(--swui-code-bg)")
            .style("color", "var(--swui-code-fg)")
            .style("border-radius", "var(--radius-sm)")
            .style("padding", "12px 14px")
            .style("font-family", "var(--font-mono)")
            .style("font-size", "12px")
            .style("margin", "0 0 16px")
            .style("overflow-x", "auto")
            if showInlinePreview {
                Div { preview }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "var(--radius-sm)")
                    .style("padding", "16px")
                    .style("background", "var(--swui-surface)")
                    .attribute("data-mobile-preview", "true")
            }
        }
        .style("background", "var(--swui-surface)")
        .style("border", "1px solid var(--swui-border)")
        .style("border-radius", "var(--radius-md)")
        .style("padding", "20px 22px")
        .style("min-height", Layout.scrollyStepMinHeight)
        .attribute("data-scrolly-step", "\(stepNumber)")
    }
}
