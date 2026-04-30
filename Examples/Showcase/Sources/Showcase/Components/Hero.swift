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
                        .foregroundColor(.token("swui-accent"))
                        .fontSize(.px(11))
                        .fontWeight(.w600)
                        .letterSpacing(.em(0.08))
                        .textTransform(.uppercase)
                        .style("margin", "0 0 12px")
                    H1 { Text(headline) }
                        .fontFamily("var(--font-display)")
                        .fontSize(.px(48))
                        .fontWeight(.w700)
                        .letterSpacing(.em(-0.02))
                        .style("line-height", "1.05")
                        .style("margin", "0 0 16px")
                    P { Text(subhead) }
                        .foregroundColor(.token("swui-fg-2"))
                        .fontSize(.px(17))
                        .style("line-height", "1.5")
                        .maxWidth(.px(520))
                        .style("margin", "0 0 24px")
                    Div {
                        A(href: primaryCTA.href) { Text(primaryCTA.label) }
                            .style("background", "var(--swui-fg)")
                            .foregroundColor(.token("swui-bg"))
                            .padding(.px(10), .px(22))
                            .borderRadius(.px(22))
                            .textDecoration(.none)
                            .fontWeight(.w500)
                        A(href: ghostCTA.href) { Text(ghostCTA.label) }
                            .style("border", "1px solid var(--swui-border-strong)")
                            .foregroundColor(.token("swui-fg"))
                            .padding(.px(10), .px(22))
                            .borderRadius(.px(22))
                            .textDecoration(.none)
                            .fontWeight(.w500)
                    }
                    .display(.flex)
                    .gap(.px(10))
                }
                CodeFrame(code: code)
            }
            .display(.grid)
            .gridTemplateColumns("1fr 1fr")
            .gap(.px(48))
            .alignItems(.center)
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
            .display(.flex)
            .gap(.px(5))
            .padding(.px(12), .px(14))
            .borderBottom(.px(1), .solid, .init(hex: "2a2a2c"))
            Pre {
                Code { Text(code) }
                    .attribute("class", "language-swift")
            }
            .margin(.zero)
            .padding(.px(16))
            .fontSize(.px(13))
            .foregroundColor(.token("swui-code-fg"))
            .fontFamily("var(--font-mono)")
            .overflowX(.auto)
        }
        .style("background", "var(--swui-code-bg)")
        .style("border-radius", "var(--radius-md)")
        .boxShadow("0 20px 50px rgba(0,0,0,0.15)")
        .overflow(.hidden)
        .attribute("data-swui-codeframe", "true")
    }

    private var dot: some Tag {
        Div { EmptyTag() }
            .width(.px(9))
            .height(.px(9))
            .borderRadius(.percent(50))
            .style("background", "#5e5e5e")
    }
}
