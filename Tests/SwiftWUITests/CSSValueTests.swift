import Testing
@testable import SwiftWUI

@Suite struct CSSValueTests {
    @Test func lengthRendering() {
        #expect(CSSLength.px(24).css == "24px")
        #expect(CSSLength.px(1.5).css == "1.5px")
        #expect(CSSLength.rem(2).css == "2rem")
        #expect(CSSLength.percent(50).css == "50%")
        #expect(CSSLength.auto.css == "auto")
        #expect(CSSLength.zero.css == "0")
    }
    @Test func colorRendering() {
        #expect(CSSColor.hex("#1a1a2e").css == "#1a1a2e")
        #expect(CSSColor.hex("#abc").css == "#abc")
        #expect(CSSColor.rgb(255, 0, 128).css == "rgb(255, 0, 128)")
        #expect(CSSColor.rgba(0, 0, 0, 0.5).css == "rgba(0, 0, 0, 0.5)")
        #expect(CSSColor.white.css == "#fff")
        #expect(CSSColor.current.css == "currentColor")
        #expect(CSSColor.variable("accent").css == "var(--accent)")
    }
    @Test func enumRendering() {
        #expect(Display.inlineBlock.css == "inline-block")
        #expect(JustifyContent.spaceBetween.css == "space-between")
        #expect(FontWeight.custom(600).css == "600")
        #expect(TextDecoration.lineThrough.css == "line-through")
        #expect(Outline.none.css == "none")
    }
    @Test func declarationFactories() {
        #expect(StyleDeclaration.margin(.top, .px(44)) == StyleDeclaration(property: "margin-top", value: "44px"))
        #expect(StyleDeclaration.padding(vertical: .px(4), horizontal: .px(8)).value == "4px 8px")
        #expect(StyleDeclaration.border(.px(1), .solid, .hex("#ccc")).value == "1px solid #ccc")
        #expect(StyleDeclaration.zIndex(10).value == "10")
    }
    @Test func sanitize() {
        #expect(CSSSanitize.isValidIdent("accent-2"))
        #expect(!CSSSanitize.isValidIdent("2col"))
        #expect(!CSSSanitize.isValidIdent(".field"))
        #expect(!CSSSanitize.isValidIdent("a b"))
        #expect(CSSSanitize.isSafeValue("blur(4px)"))
        #expect(!CSSSanitize.isSafeValue("red } body { display: none"))
        #expect(!CSSSanitize.isSafeValue("a\u{0}b"))
    }
}
