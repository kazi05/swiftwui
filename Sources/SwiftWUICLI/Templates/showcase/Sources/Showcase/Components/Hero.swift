// Hero.swift — split hero with code-frame on the right.

import SwiftWUI

public struct Hero: Tag {
    let eyebrow: String
    let headline: String
    let subhead: String
    let primaryCTA: (label: String, href: String)
    let ghostCTA: (label: String, href: String)
    let code: String

    public init(eyebrow: String, headline: String, subhead: String,
                primaryCTA: (String, String), ghostCTA: (String, String),
                code: String) {
        self.eyebrow = eyebrow
        self.headline = headline
        self.subhead = subhead
        self.primaryCTA = primaryCTA
        self.ghostCTA = ghostCTA
        self.code = code
    }

    public var body: some Tag {
        Div {
            Div {
                Div {
                    P { Text(eyebrow) }
                        .style("color", "var(--swui-accent)")
                        .style("font-size", "11px")
                        .style("font-weight", "600")
                        .style("letter-spacing", "0.08em")
                        .style("text-transform", "uppercase")
                        .style("margin", "0 0 12px")
                    H1 { Text(headline) }
                        .style("font-family", "var(--font-display)")
                        .style("font-size", "48px")
                        .style("font-weight", "700")
                        .style("letter-spacing", "-0.02em")
                        .style("line-height", "1.05")
                        .style("margin", "0 0 16px")
                    P { Text(subhead) }
                        .style("color", "var(--swui-fg-2)")
                        .style("font-size", "17px")
                        .style("line-height", "1.5")
                        .style("max-width", "520px")
                        .style("margin", "0 0 24px")
                    Div {
                        A(href: primaryCTA.href) { Text(primaryCTA.label) }
                            .style("background", "var(--swui-fg)")
                            .style("color", "var(--swui-bg)")
                            .style("padding", "10px 22px")
                            .style("border-radius", "22px")
                            .style("text-decoration", "none")
                            .style("font-weight", "500")
                        A(href: ghostCTA.href) { Text(ghostCTA.label) }
                            .style("border", "1px solid var(--swui-border-strong)")
                            .style("color", "var(--swui-fg)")
                            .style("padding", "10px 22px")
                            .style("border-radius", "22px")
                            .style("text-decoration", "none")
                            .style("font-weight", "500")
                    }
                    .style("display", "flex")
                    .style("gap", "10px")
                }
                CodeFrame(code: code)
            }
            .style("display", "grid")
            .style("grid-template-columns", "1fr 1fr")
            .style("gap", "48px")
            .style("align-items", "center")
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "64px \(Layout.pageHorizontalPadding)")
        }
        .style("background", "linear-gradient(180deg, var(--swui-surface-2) 0%, var(--swui-bg) 100%)")
        .attribute("data-swui-hero", "true")
    }
}

struct CodeFrame: Tag {
    let code: String

    var body: some Tag {
        Div {
            Div {
                dot
                dot
                dot
            }
            .style("display", "flex")
            .style("gap", "5px")
            .style("padding", "12px 14px")
            .style("border-bottom", "1px solid #2a2a2c")
            Pre {
                Code { Text(code) }
                    .attribute("class", "language-swift")
            }
            .style("margin", "0")
            .style("padding", "16px")
            .style("font-size", "13px")
            .style("color", "var(--swui-code-fg)")
            .style("font-family", "var(--font-mono)")
            .style("overflow-x", "auto")
        }
        .style("background", "var(--swui-code-bg)")
        .style("border-radius", "var(--radius-md)")
        .style("box-shadow", "0 20px 50px rgba(0,0,0,0.15)")
        .style("overflow", "hidden")
        .attribute("data-swui-codeframe", "true")
    }

    private var dot: some Tag {
        Div { EmptyTag() }
            .style("width", "9px")
            .style("height", "9px")
            .style("border-radius", "50%")
            .style("background", "#5e5e5e")
    }
}
