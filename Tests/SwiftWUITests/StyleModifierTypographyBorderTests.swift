import Testing
@testable import SwiftWUI

@Suite struct StyleModifierTypographyBorderTests {
    // MARK: - Typography factories render exactly (property:value)

    @Test func fontStyleItalic() {
        #expect(StyleDeclaration.fontStyle(.italic) == StyleDeclaration(property: "font-style", value: "italic"))
    }

    @Test func textDecorationLineThrough() {
        #expect(StyleDeclaration.textDecorationLine(.lineThrough) == StyleDeclaration(property: "text-decoration-line", value: "line-through"))
    }

    @Test func textDecorationColorStyleThickness() {
        #expect(StyleDeclaration.textDecorationColor(.hex("#f00")) == StyleDeclaration(property: "text-decoration-color", value: "#f00"))
        #expect(StyleDeclaration.textDecorationStyle(.wavy) == StyleDeclaration(property: "text-decoration-style", value: "wavy"))
        #expect(StyleDeclaration.textDecorationThickness(.px(2)) == StyleDeclaration(property: "text-decoration-thickness", value: "2px"))
    }

    @Test func textIndentRenders() {
        #expect(StyleDeclaration.textIndent(.rem(1.5)) == StyleDeclaration(property: "text-indent", value: "1.5rem"))
    }

    @Test func textShadowCommaJoinsWithoutSpreadOrInset() {
        let d = StyleDeclaration.textShadow([
            Shadow(offsetX: .px(1), offsetY: .px(1)),
            Shadow(offsetX: .px(2), offsetY: .px(2), color: .white),
        ])
        #expect(d?.property == "text-shadow")
        #expect(d?.value == "1px 1px 0 #000, 2px 2px 0 #fff")
    }

    @Test func textShadowEmptyEmitsNoDeclaration() {
        #expect(StyleDeclaration.textShadow([]) == nil)
    }

    @Test func wordBreakAndOverflowWrap() {
        #expect(StyleDeclaration.wordBreak(.breakAll) == StyleDeclaration(property: "word-break", value: "break-all"))
        #expect(StyleDeclaration.overflowWrap(.breakWord) == StyleDeclaration(property: "overflow-wrap", value: "break-word"))
    }

    @Test func verticalAlignKeywordAndLength() {
        #expect(StyleDeclaration.verticalAlign(.textTop) == StyleDeclaration(property: "vertical-align", value: "text-top"))
        #expect(StyleDeclaration.verticalAlign(.length(.px(4))) == StyleDeclaration(property: "vertical-align", value: "4px"))
    }

    @Test func lineHeightCSSLengthOverload() {
        #expect(StyleDeclaration.lineHeight(.rem(1.5)) == StyleDeclaration(property: "line-height", value: "1.5rem"))
        // The pre-existing Double overload stays reachable and unambiguous.
        #expect(StyleDeclaration.lineHeight(1.5) == StyleDeclaration(property: "line-height", value: "1.5"))
    }

    @Test func listStyleTypeKeywordAndCustom() {
        #expect(StyleDeclaration.listStyleType(.lowerRoman) == StyleDeclaration(property: "list-style-type", value: "lower-roman"))
        // .custom passes a valid ident straight through (the safe path).
        #expect(StyleDeclaration.listStyleType(.custom("mydots")) == StyleDeclaration(property: "list-style-type", value: "mydots"))
    }

    @Test func textWrapBalance() {
        #expect(StyleDeclaration.textWrap(.balance) == StyleDeclaration(property: "text-wrap", value: "balance"))
    }

    @Test func fontVariantNumericTabular() {
        #expect(StyleDeclaration.fontVariantNumeric(.tabularNums) == StyleDeclaration(property: "font-variant-numeric", value: "tabular-nums"))
    }

    // MARK: - Background / border factories

    @Test func backgroundClipTextEmitsBothPrefixes() {
        #expect(StyleDeclaration.backgroundClip(.text) == [
            StyleDeclaration(property: "-webkit-background-clip", value: "text"),
            StyleDeclaration(property: "background-clip", value: "text"),
        ])
    }

    @Test func perSideBorderWidthStyleColor() {
        #expect(StyleDeclaration.borderWidth(.top, .px(2)) == StyleDeclaration(property: "border-top-width", value: "2px"))
        #expect(StyleDeclaration.borderStyle(.bottom, .dashed) == StyleDeclaration(property: "border-bottom-style", value: "dashed"))
        #expect(StyleDeclaration.borderColor(.left, .hex("#ccc")) == StyleDeclaration(property: "border-left-color", value: "#ccc"))
    }

    @Test func allSidesBorderWidthAndStyle() {
        #expect(StyleDeclaration.borderWidth(.px(1)) == StyleDeclaration(property: "border-width", value: "1px"))
        #expect(StyleDeclaration.borderStyle(.solid) == StyleDeclaration(property: "border-style", value: "solid"))
    }

    @Test func outlineOffsetWidthStyle() {
        #expect(StyleDeclaration.outlineOffset(.px(2)) == StyleDeclaration(property: "outline-offset", value: "2px"))
        #expect(StyleDeclaration.outlineWidth(.px(3)) == StyleDeclaration(property: "outline-width", value: "3px"))
        #expect(StyleDeclaration.outlineStyle(.dashed) == StyleDeclaration(property: "outline-style", value: "dashed"))
    }

    @Test func boxShadowVariadicWithInset() {
        let d = StyleDeclaration.boxShadow([
            Shadow(offsetX: .px(0), offsetY: .px(2), blur: .px(4), spread: .px(1), color: .black, inset: true),
        ])
        #expect(d?.property == "box-shadow")
        #expect(d?.value == "inset 0px 2px 4px 1px #000")
    }

    @Test func boxShadowEmptyEmitsNoDeclaration() {
        #expect(StyleDeclaration.boxShadow([]) == nil)
        // The pre-existing String overload stays reachable and unambiguous.
        #expect(StyleDeclaration.boxShadow("0 1px 2px #000").property == "box-shadow")
    }

    @Test func mixBlendModeMultiply() {
        #expect(StyleDeclaration.mixBlendMode(.multiply) == StyleDeclaration(property: "mix-blend-mode", value: "multiply"))
    }

    // MARK: - Modifier wiring through the renderer

    @Test func htmlTagTypographyModifiersEmitInlineStyle() {
        let html = HTMLRenderer.render(
            Div().fontStyle(.italic).lineHeight(.rem(1.5)).listStyleType(.lowerRoman)
        )
        #expect(html.contains("font-style: italic"))
        #expect(html.contains("line-height: 1.5rem"))
        #expect(html.contains("list-style-type: lower-roman"))
    }

    @Test func backgroundClipModifierEmitsBothPrefixes() {
        let html = HTMLRenderer.render(Div().backgroundClip(.text))
        #expect(html.contains("-webkit-background-clip: text"))
        #expect(html.contains("background-clip: text"))
    }

    @Test func perSideBorderModifiersWire() {
        let html = HTMLRenderer.render(
            Div().borderWidth(.top, .px(2)).borderColor(.left, .hex("#ccc"))
        )
        #expect(html.contains("border-top-width: 2px"))
        #expect(html.contains("border-left-color: #ccc"))
    }

    @Test func componentWrapperGetsModifier() {
        struct Card: Tag { var body: some Tag { Div { Text("hi") } } }
        let html = HTMLRenderer.render(
            Card()
                .textShadow(Shadow(offsetX: .px(1), offsetY: .px(1), color: .black))
                .mixBlendMode(.multiply)
        )
        #expect(html.contains("text-shadow: 1px 1px 0 #000"))
        #expect(html.contains("mix-blend-mode: multiply"))
    }
}
