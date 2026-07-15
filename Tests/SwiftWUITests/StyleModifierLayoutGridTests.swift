import Testing
@testable import SwiftWUI

@Suite struct StyleModifierLayoutGridTests {
    // MARK: - Sizing / box factories render exactly (property:value)

    @Test func inlineSizeRenders() {
        #expect(StyleDeclaration.inlineSize(.px(200)) == StyleDeclaration(property: "inline-size", value: "200px"))
        #expect(StyleDeclaration.blockSize(.percent(50)) == StyleDeclaration(property: "block-size", value: "50%"))
    }

    @Test func insetShorthand() {
        #expect(StyleDeclaration.inset(.zero) == StyleDeclaration(property: "inset", value: "0"))
    }

    @Test func logicalMarginAndPadding() {
        #expect(StyleDeclaration.marginInline(.px(8)) == StyleDeclaration(property: "margin-inline", value: "8px"))
        #expect(StyleDeclaration.marginBlock(.px(8)) == StyleDeclaration(property: "margin-block", value: "8px"))
        #expect(StyleDeclaration.paddingInline(.px(8)) == StyleDeclaration(property: "padding-inline", value: "8px"))
        #expect(StyleDeclaration.paddingBlock(.px(8)) == StyleDeclaration(property: "padding-block", value: "8px"))
    }

    @Test func gapLonghandsAndTwoAxisShorthand() {
        #expect(StyleDeclaration.rowGap(.px(8)) == StyleDeclaration(property: "row-gap", value: "8px"))
        #expect(StyleDeclaration.columnGap(.px(16)) == StyleDeclaration(property: "column-gap", value: "16px"))
        // gap(row:column:) → "row column"; labeled overload, no clash with gap(_:).
        #expect(StyleDeclaration.gap(row: .px(8), column: .px(16)) == StyleDeclaration(property: "gap", value: "8px 16px"))
    }

    @Test func orderIsInteger() {
        #expect(StyleDeclaration.order(2) == StyleDeclaration(property: "order", value: "2"))
    }

    // MARK: - Flex / grid alignment (dedicated enums)

    @Test func justifyItemsSelfStart() {
        #expect(StyleDeclaration.justifyItems(.selfStart) == StyleDeclaration(property: "justify-items", value: "self-start"))
    }

    @Test func justifySelfRenders() {
        #expect(StyleDeclaration.justifySelf(.center) == StyleDeclaration(property: "justify-self", value: "center"))
    }

    @Test func alignContentSpaceBetween() {
        #expect(StyleDeclaration.alignContent(.spaceBetween) == StyleDeclaration(property: "align-content", value: "space-between"))
    }

    @Test func placeContentComposesAlignThenJustify() {
        // "align justify" order; justify axis is JustifyContent, never AlignItems.
        #expect(StyleDeclaration.placeContent(.center, .start) == StyleDeclaration(property: "place-content", value: "center start"))
    }

    @Test func placeItemsComposesAlignThenJustify() {
        #expect(StyleDeclaration.placeItems(.stretch, .center) == StyleDeclaration(property: "place-items", value: "stretch center"))
    }

    // MARK: - Grid item placement (reuse GridLine / GridAutoFlow)

    @Test func gridAutoFlowTwoKeyword() {
        #expect(GridAutoFlow.rowDense.css == "row dense")
        #expect(StyleDeclaration.gridAutoFlow(.rowDense) == StyleDeclaration(property: "grid-auto-flow", value: "row dense"))
        #expect(StyleDeclaration.gridAutoFlow(.columnDense).value == "column dense")
    }

    @Test func gridLineStartVariants() {
        // GridLine self-renders: span(n) → "span N", name(ident) → the ident.
        #expect(StyleDeclaration.gridColumnStart(.span(2)) == StyleDeclaration(property: "grid-column-start", value: "span 2"))
        #expect(StyleDeclaration.gridColumnStart(.name("hdr")) == StyleDeclaration(property: "grid-column-start", value: "hdr"))
        #expect(StyleDeclaration.gridColumnEnd(.line(4)).value == "4")
        #expect(StyleDeclaration.gridRowStart(.auto).value == "auto")
        #expect(StyleDeclaration.gridRowEnd(.span(3)).value == "span 3")
    }

    @Test func gridColumnAndRowShorthand() {
        // Single line → just "start"; with end → "start / end".
        #expect(StyleDeclaration.gridColumn(.line(1), .line(3)) == StyleDeclaration(property: "grid-column", value: "1 / 3"))
        #expect(StyleDeclaration.gridColumn(.span(2)) == StyleDeclaration(property: "grid-column", value: "span 2"))
        #expect(StyleDeclaration.gridRow(.line(2), .line(4)) == StyleDeclaration(property: "grid-row", value: "2 / 4"))
        #expect(StyleDeclaration.gridRow(.name("side")) == StyleDeclaration(property: "grid-row", value: "side"))
    }

    // MARK: - Raw String inputs: sanitize + safe-path rendering

    @Test func gridTemplateAreasSafeValueRenders() {
        let areas = "\"hd hd\" \"sb mn\""
        #expect(CSSSanitize.isSafeValue(areas))   // guard predicate, not the trap path
        #expect(StyleDeclaration.gridTemplateAreas(areas) == StyleDeclaration(property: "grid-template-areas", value: areas))
    }

    @Test func gridTemplateAreasRejectsUnsafeValue() {
        // Assert the guard predicate that gates the assert-and-drop (not the trap itself).
        #expect(!CSSSanitize.isSafeValue("a } body{color:red"))
    }

    @Test func gridAreaValidIdentRenders() {
        #expect(CSSSanitize.isValidIdent("header"))   // guard predicate
        #expect(StyleDeclaration.gridArea("header") == StyleDeclaration(property: "grid-area", value: "header"))
    }

    @Test func gridAreaRejectsInvalidIdent() {
        // Assert the guard predicate that gates the assert-and-drop (not the trap itself).
        #expect(!CSSSanitize.isValidIdent("1header"))
    }

    // MARK: - Modifier wiring through the renderer (Tag / _StyledTag / HTMLTag paths)

    @Test func htmlTagModifierEmitsInlineStyle() {
        let html = HTMLRenderer.render(
            Div().gap(row: .px(8), column: .px(16)).order(2).gridColumn(.line(1), .line(3))
        )
        #expect(html.contains("gap: 8px 16px"))
        #expect(html.contains("order: 2"))
        #expect(html.contains("grid-column: 1 / 3"))
    }

    @Test func componentWrapperGetsModifier() {
        struct Card: Tag { var body: some Tag { Div { Text("hi") } } }
        let html = HTMLRenderer.render(
            Card().placeItems(.stretch, .center).justifyItems(.selfStart)
        )
        #expect(html.contains("place-items: stretch center"))
        #expect(html.contains("justify-items: self-start"))
    }
}
