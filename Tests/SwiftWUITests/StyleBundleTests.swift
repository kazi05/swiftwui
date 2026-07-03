import Testing
@testable import SwiftWUI

private struct CardStyle: Style {
    func build(_ s: inout StyleProxy) {
        s.padding(.px(24))
        s.borderRadius(.px(12))
        s.hover { $0.boxShadow("0 4px 16px rgba(0,0,0,.12)") }
    }
}
private struct PlainCard: Tag {
    var body: some Tag { Div(class: "card") { Text("hi") } }
}
private struct MediaStyle: Style {
    func build(_ s: inout StyleProxy) {
        s.padding(.px(4))
        s.media(.maxWidth(.px(600))) { $0.display(.none) }
    }
}

@Suite struct StyleBundleTests {
    @Test func bundleOnHTMLTag() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(Div { Text("x") }.style(CardStyle()))
        #expect(html.contains("padding: 24px; border-radius: 12px"))
        #expect(css.contains(":hover { box-shadow: 0 4px 16px rgba(0,0,0,.12) }"))
    }
    @Test func bundleOnComponent() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(PlainCard().style(CardStyle()))
        #expect(html.contains("padding: 24px"))
        #expect(css.contains(":hover"))
        #expect(html.contains("swui-"))          // rule class landed on the root element
    }
    @Test func bundleMediaBlockOnHTMLTag() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(Div { Text("x") }.style(MediaStyle()))
        #expect(css.contains("@media (max-width: 600px)"))
        #expect(css.contains("display: none"))
    }
    @Test func bundleMediaBlockOnComponent() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(PlainCard().style(MediaStyle()))
        #expect(css.contains("@media (max-width: 600px)"))
        #expect(css.contains("display: none"))
    }
    @Test func sameBundleTwoElementsOneRule() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Span { Text("a") }.style(CardStyle()); Span { Text("b") }.style(CardStyle()) }
        )
        #expect(css.split(separator: "\n").count == 1)
    }
}
