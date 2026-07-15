import Testing
@testable import SwiftWUI

@Suite struct StyleModifierMotionMiscTests {
    // MARK: - Motion / 3D factories

    @Test func transformStyleAndBackface() {
        #expect(StyleDeclaration.transformStyle(.preserve3d) == StyleDeclaration(property: "transform-style", value: "preserve-3d"))
        #expect(StyleDeclaration.transformStyle(.flat) == StyleDeclaration(property: "transform-style", value: "flat"))
        #expect(StyleDeclaration.backfaceVisibility(.hidden) == StyleDeclaration(property: "backface-visibility", value: "hidden"))
    }

    @Test func perspectiveRenders() {
        #expect(StyleDeclaration.perspective(.px(800)) == StyleDeclaration(property: "perspective", value: "800px"))
    }

    @Test func willChangeMultiHintCommaJoined() {
        #expect(StyleDeclaration.willChange([.scrollPosition, .property("transform")]) ==
            StyleDeclaration(property: "will-change", value: "scroll-position, transform"))
        #expect(StyleDeclaration.willChange([.property("transform")]) ==
            StyleDeclaration(property: "will-change", value: "transform"))
        #expect(StyleDeclaration.willChange([.auto, .contents]) ==
            StyleDeclaration(property: "will-change", value: "auto, contents"))
        // Empty variadic → no declaration.
        #expect(StyleDeclaration.willChange([]) == nil)
        // The `.property` guard predicate accepts a plain ident.
        #expect(CSSSanitize.isValidIdent("transform"))
    }

    @Test func transitionDelayRenders() {
        #expect(StyleDeclaration.transitionDelay(.ms(150)) == StyleDeclaration(property: "transition-delay", value: "150ms"))
    }

    // MARK: - Layout perf / scroll / flex factories

    @Test func contentVisibilityRenders() {
        #expect(StyleDeclaration.contentVisibility(.auto) == StyleDeclaration(property: "content-visibility", value: "auto"))
    }

    @Test func containIntrinsicSizeOneAndTwoValues() {
        #expect(StyleDeclaration.containIntrinsicSize(.px(300)) == StyleDeclaration(property: "contain-intrinsic-size", value: "300px"))
        #expect(StyleDeclaration.containIntrinsicSize(.px(300), .px(200)) == StyleDeclaration(property: "contain-intrinsic-size", value: "300px 200px"))
    }

    @Test func scrollSnapStopAndMargin() {
        #expect(StyleDeclaration.scrollSnapStop(.always) == StyleDeclaration(property: "scroll-snap-stop", value: "always"))
        #expect(StyleDeclaration.scrollMargin(.px(8)) == StyleDeclaration(property: "scroll-margin", value: "8px"))
        #expect(StyleDeclaration.scrollMargin(.top, .px(12)) == StyleDeclaration(property: "scroll-margin-top", value: "12px"))
    }

    @Test func placeSelfComposesAlignJustify() {
        #expect(StyleDeclaration.placeSelf(.center, .start) == StyleDeclaration(property: "place-self", value: "center start"))
    }

    @Test func flexShorthandAndConvenience() {
        #expect(StyleDeclaration.flex(.grow(1)) == StyleDeclaration(property: "flex", value: "1 1 0"))
        #expect(StyleDeclaration.flex(.grow(2, shrink: 0, basis: .percent(50))) == StyleDeclaration(property: "flex", value: "2 0 50%"))
        #expect(StyleDeclaration.flex(.none) == StyleDeclaration(property: "flex", value: "none"))
        #expect(StyleDeclaration.flex(1) == StyleDeclaration(property: "flex", value: "1"))
    }

    @Test func flexFlowComposesDirectionWrap() {
        #expect(StyleDeclaration.flexFlow(.row, .wrap) == StyleDeclaration(property: "flex-flow", value: "row wrap"))
    }

    // MARK: - Misc / multicol / SVG / counters factories

    @Test func contentSafeValuePasses() {
        #expect(StyleDeclaration.content("\"→\"") == StyleDeclaration(property: "content", value: "\"→\""))
        // The guard predicate accepts a user-quoted string.
        #expect(CSSSanitize.isSafeValue("\"→\""))
    }

    @Test func columnCountAndWidth() {
        #expect(StyleDeclaration.columnCount(3) == StyleDeclaration(property: "column-count", value: "3"))
        #expect(StyleDeclaration.columnWidth(.rem(12)) == StyleDeclaration(property: "column-width", value: "12rem"))
    }

    @Test func scrollbarWidthAndColor() {
        #expect(StyleDeclaration.scrollbarWidth(.thin) == StyleDeclaration(property: "scrollbar-width", value: "thin"))
        #expect(StyleDeclaration.scrollbarColor(.hex("#333"), .hex("#eee")) == StyleDeclaration(property: "scrollbar-color", value: "#333 #eee"))
    }

    @Test func tapHighlightColorRenders() {
        #expect(StyleDeclaration.tapHighlightColor(.hex("#00000000")) == StyleDeclaration(property: "-webkit-tap-highlight-color", value: "#00000000"))
    }

    @Test func fillStrokeAndStrokeWidth() {
        #expect(StyleDeclaration.fill(.hex("#f00")) == StyleDeclaration(property: "fill", value: "#f00"))
        #expect(StyleDeclaration.stroke(.black) == StyleDeclaration(property: "stroke", value: "#000"))
        #expect(StyleDeclaration.strokeWidth(.px(2)) == StyleDeclaration(property: "stroke-width", value: "2px"))
    }

    @Test func counterActionsJoinNameValue() {
        #expect(StyleDeclaration.counterReset([CounterAction("section", 0), CounterAction("item", 1)]) ==
            StyleDeclaration(property: "counter-reset", value: "section 0 item 1"))
        #expect(StyleDeclaration.counterIncrement([CounterAction("item")]) ==
            StyleDeclaration(property: "counter-increment", value: "item 0"))
        #expect(StyleDeclaration.counterSet([CounterAction("page", 3)]) ==
            StyleDeclaration(property: "counter-set", value: "page 3"))
        // Empty variadic → no declaration.
        #expect(StyleDeclaration.counterReset([]) == nil)
        // The name guard predicate accepts a plain ident.
        #expect(CSSSanitize.isValidIdent("section"))
    }

    // MARK: - Modifier wiring through the renderer

    @Test func htmlTagMotionAndFlexModifiersEmitInlineStyle() {
        let html = HTMLRenderer.render(
            Div()
                .transformStyle(.preserve3d)
                .perspective(.px(800))
                .flex(1)
                .flexFlow(.row, .wrap)
        )
        #expect(html.contains("transform-style: preserve-3d"))
        #expect(html.contains("perspective: 800px"))
        #expect(html.contains("flex: 1"))
        #expect(html.contains("flex-flow: row wrap"))
    }

    @Test func htmlTagCounterAndWillChangeModifiers() {
        let html = HTMLRenderer.render(
            Div()
                .counterReset(CounterAction("section", 0), CounterAction("item", 1))
                .willChange(.property("transform"), .scrollPosition)
        )
        #expect(html.contains("counter-reset: section 0 item 1"))
        #expect(html.contains("will-change: transform, scroll-position"))
    }

    @Test func componentWrapperGetsModifier() {
        struct Card: Tag { var body: some Tag { Div { Text("hi") } } }
        let html = HTMLRenderer.render(
            Card()
                .fill(.hex("#f00"))
                .strokeWidth(.px(2))
                .placeSelf(.center, .start)
        )
        #expect(html.contains("fill: #f00"))
        #expect(html.contains("stroke-width: 2px"))
        #expect(html.contains("place-self: center start"))
    }
}
