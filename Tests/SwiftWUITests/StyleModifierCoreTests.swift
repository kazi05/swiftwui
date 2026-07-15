import Testing
@testable import SwiftWUI

@Suite struct StyleModifierCoreTests {
    // MARK: - Factories render exactly (property:value)

    @Test func overflowXWithClip() {
        let d = StyleDeclaration.overflowX(.clip)
        #expect(d.property == "overflow-x")
        #expect(d.value == "clip")
        #expect(StyleDeclaration.overflowY(.scroll) == StyleDeclaration(property: "overflow-y", value: "scroll"))
    }

    @Test func objectFitScaleDown() {
        #expect(StyleDeclaration.objectFit(.scaleDown) == StyleDeclaration(property: "object-fit", value: "scale-down"))
    }

    @Test func objectPositionKeyword() {
        #expect(StyleDeclaration.objectPosition(.center) == StyleDeclaration(property: "object-position", value: "50% 50%"))
    }

    @Test func aspectRatioRendersViaCssNumber() {
        #expect(StyleDeclaration.aspectRatio(.ratio(16, 9)) == StyleDeclaration(property: "aspect-ratio", value: "16 / 9"))
        #expect(StyleDeclaration.aspectRatio(.auto).value == "auto")
    }

    @Test func visibilityHidden() {
        #expect(StyleDeclaration.visibility(.hidden) == StyleDeclaration(property: "visibility", value: "hidden"))
    }

    @Test func whiteSpacePreWrap() {
        #expect(StyleDeclaration.whiteSpace(.preWrap) == StyleDeclaration(property: "white-space", value: "pre-wrap"))
    }

    @Test func textTransformUppercase() {
        #expect(StyleDeclaration.textTransform(.uppercase) == StyleDeclaration(property: "text-transform", value: "uppercase"))
    }

    @Test func textOverflowEllipsis() {
        #expect(StyleDeclaration.textOverflow(.ellipsis) == StyleDeclaration(property: "text-overflow", value: "ellipsis"))
    }

    @Test func lineClampEmitsFiveDeclarationsInOrder() {
        let decls = StyleDeclaration.lineClamp(3)
        #expect(decls == [
            StyleDeclaration(property: "display", value: "-webkit-box"),
            StyleDeclaration(property: "-webkit-box-orient", value: "vertical"),
            StyleDeclaration(property: "overflow", value: "hidden"),
            StyleDeclaration(property: "-webkit-line-clamp", value: "3"),
            StyleDeclaration(property: "line-clamp", value: "3"),
        ])
    }

    @Test func backgroundColorIsDistinctProperty() {
        // NOT the `background` shorthand.
        #expect(StyleDeclaration.backgroundColor(.hex("#1a1a2e")) == StyleDeclaration(property: "background-color", value: "#1a1a2e"))
        #expect(StyleDeclaration.background(.hex("#1a1a2e")).property == "background")
    }

    @Test func backgroundImageGradient() {
        let d = StyleDeclaration.backgroundImage(.linearGradient(angle: .deg(90), stops: [.color(.white), .color(.black)]))
        #expect(d.property == "background-image")
        #expect(d.value == "linear-gradient(90deg, #fff, #000)")
    }

    @Test func backgroundRepeatBacktickedRepeat() {
        // `repeat` case is backticked (Swift keyword) but its css string is "repeat".
        #expect(BackgroundRepeat.repeat.css == "repeat")
        #expect(StyleDeclaration.backgroundRepeat(.repeat) == StyleDeclaration(property: "background-repeat", value: "repeat"))
        #expect(StyleDeclaration.backgroundRepeat(.noRepeat).value == "no-repeat")
    }

    @Test func perSideBorder() {
        #expect(StyleDeclaration.border(.top) == StyleDeclaration(property: "border-top", value: "1px solid currentColor"))
        #expect(StyleDeclaration.border(.left, width: .px(2), style: .dashed, color: .hex("#ccc"))
                == StyleDeclaration(property: "border-left", value: "2px dashed #ccc"))
    }

    @Test func perCornerBorderRadius() {
        let r = BorderRadius(topLeft: .px(4), topRight: .px(8), bottomRight: .px(12), bottomLeft: .px(16))
        #expect(StyleDeclaration.borderRadius(r) == StyleDeclaration(property: "border-radius", value: "4px 8px 12px 16px"))
    }

    @Test func filterMultiFunction() {
        let d = StyleDeclaration.filter([.blur(.px(4)), .brightness(0.8)])
        #expect(d?.property == "filter")
        #expect(d?.value == "blur(4px) brightness(0.8)")
    }

    @Test func transformWithPercentTranslate() {
        let d = StyleDeclaration.transform([.translateX(.percent(-50))])
        #expect(d?.property == "transform")
        #expect(d?.value == "translateX(-50%)")
    }

    @Test func emptyVariadicEmitsNoDeclaration() {
        // Guard predicate (not the assertion path): empty function list → nil.
        #expect(StyleDeclaration.filter([]) == nil)
        #expect(StyleDeclaration.transform([]) == nil)
    }

    @Test func pointerEventsNone() {
        #expect(StyleDeclaration.pointerEvents(.none) == StyleDeclaration(property: "pointer-events", value: "none"))
    }

    @Test func pointerEventsCamelCaseVerbatim() {
        // SVG-heritage camelCase css keywords render verbatim.
        #expect(PointerEvents.visiblePainted.css == "visiblePainted")
        #expect(PointerEvents.visibleStroke.css == "visibleStroke")
    }

    @Test func userSelectNone() {
        #expect(StyleDeclaration.userSelect(.none) == StyleDeclaration(property: "user-select", value: "none"))
    }

    // MARK: - Modifier wiring through the renderer (Tag → _StyledTag / HTMLTag paths)

    @Test func htmlTagModifierEmitsInlineStyle() {
        let html = HTMLRenderer.render(Div().objectFit(.cover).aspectRatio(16, 9))
        #expect(html.contains("object-fit: cover"))
        #expect(html.contains("aspect-ratio: 16 / 9"))
    }

    @Test func lineClampModifierEmitsAllFive() {
        let html = HTMLRenderer.render(Div().lineClamp(2))
        #expect(html.contains("display: -webkit-box"))
        #expect(html.contains("-webkit-box-orient: vertical"))
        #expect(html.contains("overflow: hidden"))
        #expect(html.contains("-webkit-line-clamp: 2"))
        #expect(html.contains("line-clamp: 2"))
    }

    @Test func variadicFilterModifierWires() {
        let html = HTMLRenderer.render(Div().filter(.blur(.px(4)), .grayscale(1)))
        #expect(html.contains("filter: blur(4px) grayscale(1)"))
    }

    @Test func componentWrapperGetsModifier() {
        struct Card: Tag { var body: some Tag { Div { Text("hi") } } }
        let html = HTMLRenderer.render(Card().userSelect(.none).pointerEvents(.none))
        #expect(html.contains("user-select: none"))
        #expect(html.contains("pointer-events: none"))
    }
}
