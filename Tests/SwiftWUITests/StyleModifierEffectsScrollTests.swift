import Testing
@testable import SwiftWUI

@Suite struct StyleModifierEffectsScrollTests {
    // MARK: - Effects / motion factories render exactly (property:value)

    @Test func backdropFilterSpaceJoins() {
        let d = StyleDeclaration.backdropFilter([.blur(.px(10))])
        #expect(d == StyleDeclaration(property: "backdrop-filter", value: "blur(10px)"))
    }

    @Test func backdropFilterEmptyEmitsNoDeclaration() {
        #expect(StyleDeclaration.backdropFilter([]) == nil)
    }

    @Test func clipPathCircle() {
        #expect(StyleDeclaration.clipPath(.circle()) == StyleDeclaration(property: "clip-path", value: "circle(50% at 50% 50%)"))
    }

    @Test func clipPathPolygon() {
        let d = StyleDeclaration.clipPath(.polygon([
            UnitPoint(x: 0, y: 0), UnitPoint(x: 1, y: 0), UnitPoint(x: 0.5, y: 1),
        ]))
        #expect(d == StyleDeclaration(property: "clip-path", value: "polygon(0% 0%, 100% 0%, 50% 100%)"))
    }

    @Test func clipPathInsetWithRound() {
        let d = StyleDeclaration.clipPath(.inset(.px(10), .px(20), .px(10), .px(20), round: .px(4)))
        #expect(d == StyleDeclaration(property: "clip-path", value: "inset(10px 20px 10px 20px round 4px)"))
    }

    @Test func clipPathCustomSafeValuePassesThrough() {
        let d = StyleDeclaration.clipPath(.custom("url(#clip)"))
        #expect(d == StyleDeclaration(property: "clip-path", value: "url(#clip)"))
    }

    @Test func transitionLabeledOverload() {
        let d = StyleDeclaration.transition(property: "opacity", duration: .s(0.2), timingFunction: .easeInOut, delay: .s(0))
        #expect(d == StyleDeclaration(property: "transition", value: "opacity 0.2s ease-in-out 0s"))
    }

    @Test func transitionDurationAndTimingFunction() {
        #expect(StyleDeclaration.transitionDuration(.ms(150)) == StyleDeclaration(property: "transition-duration", value: "150ms"))
        #expect(StyleDeclaration.transitionTimingFunction(.easeOut) == StyleDeclaration(property: "transition-timing-function", value: "ease-out"))
    }

    // MARK: - Interactivity / misc factories

    @Test func touchActionPanY() {
        #expect(StyleDeclaration.touchAction(.panY) == StyleDeclaration(property: "touch-action", value: "pan-y"))
    }

    @Test func scrollBehaviorSmooth() {
        #expect(StyleDeclaration.scrollBehavior(.smooth) == StyleDeclaration(property: "scroll-behavior", value: "smooth"))
    }

    @Test func scrollSnapTypeNoneAndAxisStrictness() {
        #expect(StyleDeclaration.scrollSnapType(.none) == StyleDeclaration(property: "scroll-snap-type", value: "none"))
        #expect(StyleDeclaration.scrollSnapType(ScrollSnapType(axis: .x, strictness: .mandatory)) == StyleDeclaration(property: "scroll-snap-type", value: "x mandatory"))
        #expect(StyleDeclaration.scrollSnapType(ScrollSnapType(axis: .y)) == StyleDeclaration(property: "scroll-snap-type", value: "y"))
    }

    @Test func scrollSnapAlignStart() {
        #expect(StyleDeclaration.scrollSnapAlign(.start) == StyleDeclaration(property: "scroll-snap-align", value: "start"))
    }

    @Test func scrollPaddingShorthandAndPerSide() {
        #expect(StyleDeclaration.scrollPadding(.px(8)) == StyleDeclaration(property: "scroll-padding", value: "8px"))
        #expect(StyleDeclaration.scrollPadding(.top, .px(8)) == StyleDeclaration(property: "scroll-padding-top", value: "8px"))
    }

    @Test func overscrollBehaviorAndAxes() {
        #expect(StyleDeclaration.overscrollBehavior(.contain) == StyleDeclaration(property: "overscroll-behavior", value: "contain"))
        #expect(StyleDeclaration.overscrollBehaviorX(.contain) == StyleDeclaration(property: "overscroll-behavior-x", value: "contain"))
        #expect(StyleDeclaration.overscrollBehaviorY(.none) == StyleDeclaration(property: "overscroll-behavior-y", value: "none"))
    }

    @Test func resizeBoth() {
        #expect(StyleDeclaration.resize(.both) == StyleDeclaration(property: "resize", value: "both"))
    }

    @Test func appearanceEmitsBothPrefixes() {
        #expect(StyleDeclaration.appearance(.none) == [
            StyleDeclaration(property: "-webkit-appearance", value: "none"),
            StyleDeclaration(property: "appearance", value: "none"),
        ])
    }

    @Test func accentColorRenders() {
        #expect(StyleDeclaration.accentColor(.hex("#09f")) == StyleDeclaration(property: "accent-color", value: "#09f"))
    }

    @Test func listStylePositionInside() {
        #expect(StyleDeclaration.listStylePosition(.inside) == StyleDeclaration(property: "list-style-position", value: "inside"))
    }

    @Test func borderCollapseCollapse() {
        #expect(StyleDeclaration.borderCollapse(.collapse) == StyleDeclaration(property: "border-collapse", value: "collapse"))
    }

    @Test func tableLayoutFixed() {
        #expect(StyleDeclaration.tableLayout(.fixed) == StyleDeclaration(property: "table-layout", value: "fixed"))
    }

    @Test func colorSchemeHintLightDark() {
        #expect(StyleDeclaration.colorSchemeHint(.lightDark) == StyleDeclaration(property: "color-scheme", value: "light dark"))
    }

    @Test func breakInsideAvoidAndBetween() {
        #expect(StyleDeclaration.breakInside(.avoid) == StyleDeclaration(property: "break-inside", value: "avoid"))
        #expect(StyleDeclaration.breakBefore(.always) == StyleDeclaration(property: "break-before", value: "always"))
        #expect(StyleDeclaration.breakAfter(.avoidPage) == StyleDeclaration(property: "break-after", value: "avoid-page"))
    }

    // MARK: - Modifier wiring through the renderer

    @Test func htmlTagEffectsModifiersEmitInlineStyle() {
        let html = HTMLRenderer.render(
            Div()
                .backdropFilter(.blur(.px(10)))
                .clipPath(.circle())
                .transition(property: "opacity", duration: .s(0.2), timingFunction: .easeInOut, delay: .s(0))
        )
        #expect(html.contains("backdrop-filter: blur(10px)"))
        #expect(html.contains("clip-path: circle(50% at 50% 50%)"))
        #expect(html.contains("transition: opacity 0.2s ease-in-out 0s"))
    }

    @Test func appearanceModifierEmitsBothPrefixes() {
        let html = HTMLRenderer.render(Div().appearance(.none))
        #expect(html.contains("-webkit-appearance: none"))
        #expect(html.contains("appearance: none"))
    }

    @Test func componentWrapperGetsModifier() {
        struct Card: Tag { var body: some Tag { Div { Text("hi") } } }
        let html = HTMLRenderer.render(
            Card()
                .touchAction(.panY)
                .accentColor(.hex("#09f"))
                .colorSchemeHint(.lightDark)
        )
        #expect(html.contains("touch-action: pan-y"))
        #expect(html.contains("accent-color: #09f"))
        #expect(html.contains("color-scheme: light dark"))
    }
}
