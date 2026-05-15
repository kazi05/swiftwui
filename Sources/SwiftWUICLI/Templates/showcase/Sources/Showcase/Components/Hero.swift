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
                        .marginBottom(.px(12))
                    H1 { Text(headline) }
                        .fontFamily("var(--font-display)")
                        .fontSize(.px(48))
                        .fontWeight(.w700)
                        .letterSpacing(.em(-0.02))
                        .lineHeight(.unitless(1.05))
                        .marginBottom(.px(16))
                    P { Text(subhead) }
                        .foregroundColor(.token("swui-fg-2"))
                        .fontSize(.px(17))
                        .lineHeight(.unitless(1.5))
                        .maxWidth(.px(520))
                        .marginBottom(.px(24))
                    Div {
                        A(href: primaryCTA.href) { Text(primaryCTA.label) }
                            .backgroundColor(.token("swui-fg"))
                            .foregroundColor(.token("swui-bg"))
                            .padding(.px(10), .px(22))
                            .style("border-radius", "var(--radius-pill)")
                            .textDecoration(.none)
                            .fontWeight(.w500)
                        A(href: ghostCTA.href) { Text(ghostCTA.label) }
                            .border(.px(1), .solid, .token("swui-border-strong"))
                            .foregroundColor(.token("swui-fg"))
                            .padding(.px(10), .px(22))
                            .style("border-radius", "var(--radius-pill)")
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
            .margin(.zero, .auto)
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
            .style("border-bottom", "1px solid rgba(255, 255, 255, 0.08)")
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
        .backgroundColor(.token("swui-code-bg"))
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
            .backgroundColor(.css("#5e5e5e"))
    }
}
