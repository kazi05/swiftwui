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
    @Test func sameBundleTwoElementsOneRule() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Span { Text("a") }.style(CardStyle()); Span { Text("b") }.style(CardStyle()) }
        )
        #expect(css.split(separator: "\n").count == 1)
    }
}
