import Testing
@testable import SwiftWUI

@Suite struct InlineStyleTests {
    @Test func modifiersFlattenIntoStyleAttribute() {
        let html = HTMLRenderer.render(
            Div { Text("x") }
                .padding(.px(24))
                .display(.flex)
                .gap(.px(8))
        )
        #expect(html.contains(#"style="padding: 24px; display: flex; gap: 8px""#))
    }
    @Test func duplicatePropertyLastWins() {
        let html = HTMLRenderer.render(Div { Text("x") }.margin(.px(4)).margin(.px(8)))
        #expect(html.contains(#"style="margin: 8px""#))
        #expect(!html.contains("4px"))
    }
    @Test func rawStyleAttributeComesFirst() {
        let html = HTMLRenderer.render(
            Div { Text("x") }.attribute("style", "color: red").padding(.px(2))
        )
        #expect(html.contains(#"style="color: red; padding: 2px""#))
    }
    @Test func fallbackValidatesNameAndValue() {
        let html = HTMLRenderer.render(Div { Text("x") }.style("backdrop-filter", "blur(4px)"))
        #expect(html.contains("backdrop-filter: blur(4px)"))
        // invalid name/value paths assert in debug — not exercised here (Task 3 note)
    }
    @Test func styleValueIsAttributeEscaped() {
        let html = HTMLRenderer.render(Div { Text("x") }.fontFamily(#""Weird" font"#))
        #expect(html.contains("&quot;Weird&quot;"))      // existing choke point does the escaping
    }
    @Test func identityUnaffectedByBagStyles() {
        // bag mutation never adds identity segments: styled output is the plain
        // output plus exactly one style attribute — same tree shape otherwise
        let a = HTMLRenderer.render(Div { Text("x") })
        let b = HTMLRenderer.render(Div { Text("x") }.padding(.px(1)))
        #expect(a == "<div>x</div>")
        #expect(b == #"<div style="padding: 1px">x</div>"#)
    }
}
