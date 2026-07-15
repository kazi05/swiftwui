import Testing
@testable import SwiftWUI

@Suite struct StyleModifierLogicalFontTests {
    // MARK: - Logical box factories render exactly (property:value)

    @Test func logicalMarginPaddingInsetSizes() {
        #expect(StyleDeclaration.marginInlineStart(.px(8)) == StyleDeclaration(property: "margin-inline-start", value: "8px"))
        #expect(StyleDeclaration.marginBlockEnd(.px(4)) == StyleDeclaration(property: "margin-block-end", value: "4px"))
        #expect(StyleDeclaration.paddingInlineEnd(.px(2)) == StyleDeclaration(property: "padding-inline-end", value: "2px"))
        #expect(StyleDeclaration.insetBlockEnd(.px(0)) == StyleDeclaration(property: "inset-block-end", value: "0px"))
        #expect(StyleDeclaration.minInlineSize(.rem(10)) == StyleDeclaration(property: "min-inline-size", value: "10rem"))
        #expect(StyleDeclaration.maxBlockSize(.percent(50)) == StyleDeclaration(property: "max-block-size", value: "50%"))
    }

    // MARK: - Display / flow factories

    @Test func floatClearIsolation() {
        #expect(StyleDeclaration.float(.inlineStart) == StyleDeclaration(property: "float", value: "inline-start"))
        #expect(StyleDeclaration.clear(.both) == StyleDeclaration(property: "clear", value: "both"))
        #expect(StyleDeclaration.isolation(.isolate) == StyleDeclaration(property: "isolation", value: "isolate"))
    }

    // MARK: - Font / text factories

    @Test func fontVariantStretchOptical() {
        #expect(StyleDeclaration.fontVariant(.smallCaps) == StyleDeclaration(property: "font-variant", value: "small-caps"))
        #expect(StyleDeclaration.fontStretch(.ultraCondensed) == StyleDeclaration(property: "font-stretch", value: "ultra-condensed"))
        #expect(StyleDeclaration.fontOpticalSizing(.none) == StyleDeclaration(property: "font-optical-sizing", value: "none"))
    }

    @Test func fontSmoothingAntialiasedEmitsOnlyWebkit() {
        #expect(StyleDeclaration.fontSmoothing(.antialiased) == [
            StyleDeclaration(property: "-webkit-font-smoothing", value: "antialiased"),
        ])
    }

    @Test func fontSmoothingAutoEmitsBoth() {
        #expect(StyleDeclaration.fontSmoothing(.auto) == [
            StyleDeclaration(property: "-webkit-font-smoothing", value: "auto"),
            StyleDeclaration(property: "font-smooth", value: "auto"),
        ])
    }

    @Test func textAlignLastAndUnderlineOffset() {
        #expect(StyleDeclaration.textAlignLast(.justify) == StyleDeclaration(property: "text-align-last", value: "justify"))
        #expect(StyleDeclaration.textUnderlineOffset(.px(3)) == StyleDeclaration(property: "text-underline-offset", value: "3px"))
    }

    @Test func wordSpacingRenders() {
        #expect(StyleDeclaration.wordSpacing(.px(5)) == StyleDeclaration(property: "word-spacing", value: "5px"))
    }

    @Test func hyphensAndDirection() {
        #expect(StyleDeclaration.hyphens(.auto) == StyleDeclaration(property: "hyphens", value: "auto"))
        #expect(StyleDeclaration.direction(.rtl) == StyleDeclaration(property: "direction", value: "rtl"))
    }

    @Test func caretColorAutoAndColor() {
        #expect(StyleDeclaration.caretColor(.auto) == StyleDeclaration(property: "caret-color", value: "auto"))
        #expect(StyleDeclaration.caretColor(.color(.hex("#f00"))) == StyleDeclaration(property: "caret-color", value: "#f00"))
    }

    @Test func textStrokeWidthAndColor() {
        #expect(StyleDeclaration.textStroke(TextStroke(width: .px(1), color: .black)) == StyleDeclaration(property: "-webkit-text-stroke", value: "1px #000"))
    }

    // MARK: - Background / border factories

    @Test func backgroundAttachmentOriginBlendMode() {
        #expect(StyleDeclaration.backgroundAttachment(.fixed) == StyleDeclaration(property: "background-attachment", value: "fixed"))
        #expect(StyleDeclaration.backgroundOrigin(.contentBox) == StyleDeclaration(property: "background-origin", value: "content-box"))
        #expect(StyleDeclaration.backgroundBlendMode(.multiply) == StyleDeclaration(property: "background-blend-mode", value: "multiply"))
    }

    @Test func backgroundPositionAndSize() {
        #expect(StyleDeclaration.backgroundPosition(.center) == StyleDeclaration(property: "background-position", value: "center"))
        #expect(StyleDeclaration.backgroundSize(.cover) == StyleDeclaration(property: "background-size", value: "cover"))
    }

    @Test func outlineColorRenders() {
        #expect(StyleDeclaration.outlineColor(.hex("#ccc")) == StyleDeclaration(property: "outline-color", value: "#ccc"))
    }

    @Test func borderSpacingOneAndTwoValues() {
        #expect(StyleDeclaration.borderSpacing(.px(4)) == StyleDeclaration(property: "border-spacing", value: "4px"))
        #expect(StyleDeclaration.borderSpacing(.px(4), .px(8)) == StyleDeclaration(property: "border-spacing", value: "4px 8px"))
    }

    // MARK: - Modifier wiring through the renderer

    @Test func htmlTagLogicalAndFontModifiersEmitInlineStyle() {
        let html = HTMLRenderer.render(
            Div().marginInlineStart(.px(8)).float(.inlineStart).fontStretch(.ultraCondensed)
        )
        #expect(html.contains("margin-inline-start: 8px"))
        #expect(html.contains("float: inline-start"))
        #expect(html.contains("font-stretch: ultra-condensed"))
    }

    @Test func fontSmoothingModifierEmitsOnlyWebkitForAntialiased() {
        let html = HTMLRenderer.render(Div().fontSmoothing(.antialiased))
        #expect(html.contains("-webkit-font-smoothing: antialiased"))
        #expect(!html.contains("font-smooth: "))
    }

    @Test func componentWrapperGetsModifier() {
        struct Card: Tag { var body: some Tag { Div { Text("hi") } } }
        let html = HTMLRenderer.render(
            Card()
                .textStroke(TextStroke(width: .px(1), color: .black))
                .backgroundAttachment(.fixed)
        )
        #expect(html.contains("-webkit-text-stroke: 1px #000"))
        #expect(html.contains("background-attachment: fixed"))
    }
}
