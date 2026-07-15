import Testing
@testable import SwiftWUI

/// `.css` rendering for the new/extended CSS value types.
@Suite struct CSSValueExpansionTests {
    @Test func lengthNewUnits() {
        #expect(CSSLength.ch(3).css == "3ch")
        #expect(CSSLength.vmin(50).css == "50vmin")
        #expect(CSSLength.vmax(50).css == "50vmax")
        #expect(CSSLength.dvh(100).css == "100dvh")
        #expect(CSSLength.svh(100).css == "100svh")
        #expect(CSSLength.lvh(100).css == "100lvh")
        #expect(CSSLength.dvw(100).css == "100dvw")
        #expect(CSSLength.svw(100).css == "100svw")
        #expect(CSSLength.lvw(100).css == "100lvw")
        #expect(CSSLength.minContent.css == "min-content")
        #expect(CSSLength.maxContent.css == "max-content")
        #expect(CSSLength.fitContent(.px(200)).css == "fit-content(200px)")
        #expect(CSSLength.fitContent(.percent(50)).css == "fit-content(50%)")
    }

    @Test func overflowClip() {
        #expect(Overflow.clip.css == "clip")
    }

    @Test func displayNewCases() {
        #expect(Display.inlineGrid.css == "inline-grid")
        #expect(Display.table.css == "table")
        #expect(Display.tableCell.css == "table-cell")
        #expect(Display.tableRowGroup.css == "table-row-group")
        #expect(Display.listItem.css == "list-item")
        #expect(Display.flowRoot.css == "flow-root")
    }

    @Test func cursorNewCases() {
        #expect(Cursor.crosshair.css == "crosshair")
        #expect(Cursor.grabbing.css == "grabbing")
        #expect(Cursor.zoomIn.css == "zoom-in")
        #expect(Cursor.contextMenu.css == "context-menu")
        #expect(Cursor.colResize.css == "col-resize")
        #expect(Cursor.neswResize.css == "nesw-resize")
        #expect(Cursor.none.css == "none")
    }

    @Test func aspectRatio() {
        #expect(AspectRatio.ratio(16, 9).css == "16 / 9")     // no ".0"
        #expect(AspectRatio.ratio(1, 1).css == "1 / 1")
        #expect(AspectRatio.auto.css == "auto")
    }

    @Test func gridLine() {
        #expect(GridLine.auto.css == "auto")
        #expect(GridLine.line(3).css == "3")
        #expect(GridLine.name("header").css == "header")
        #expect(GridLine.span(2).css == "span 2")
        // fallback: `.name("2bad").css` returns "auto" in release, but traps via
        // assertionFailure in debug (this run). Assert the guard predicate that drives it.
        #expect(!CSSSanitize.isValidIdent("2bad"))
    }

    @Test func objectAndBackgroundPosition() {
        #expect(ObjectPosition.center.css == "50% 50%")
        #expect(ObjectPosition(x: .px(10), y: .percent(0)).css == "10px 0%")
        #expect(BackgroundPosition.topLeft.css == "left top")
        #expect(BackgroundPosition.center.css == "center")
        #expect(BackgroundPosition.custom(x: .px(10), y: .px(20)).css == "10px 20px")
    }

    @Test func backgroundSize() {
        #expect(BackgroundSize.cover.css == "cover")
        #expect(BackgroundSize.custom(width: .px(100), height: .px(50)).css == "100px 50px")
        #expect(BackgroundSize.custom(width: .px(100), height: nil).css == "100px")
    }

    @Test func borderRadius() {
        #expect(BorderRadius(all: .px(8)).css == "8px 8px 8px 8px")
        #expect(BorderRadius(topLeft: .px(4), topRight: .px(8)).css == "4px 8px 0 0")
    }

    @Test func alignJustifyEnums() {
        #expect(JustifyItems.flexStart.css == "flex-start")
        #expect(JustifyItems.selfEnd.css == "self-end")
        #expect(JustifySelf.auto.css == "auto")
        #expect(AlignContent.spaceBetween.css == "space-between")
    }

    @Test func angleDurationTiming() {
        #expect(CSSAngle.deg(45).css == "45deg")
        #expect(CSSAngle.turn(0.5).css == "0.5turn")
        #expect(CSSDuration.s(0.2).css == "0.2s")
        #expect(CSSDuration.ms(200).css == "200ms")
        #expect(TimingFunction.easeInOut.css == "ease-in-out")
        #expect(TimingFunction.cubicBezier(0.4, 0, 0.2, 1).css == "cubic-bezier(0.4, 0, 0.2, 1)")
        #expect(TimingFunction.steps(4, .end).css == "steps(4, end)")
        #expect(TimingFunction.steps(2, .jumpStart).css == "steps(2, jump-start)")
    }

    @Test func blendMode() {
        #expect(BlendMode.colorDodge.css == "color-dodge")
        #expect(BlendMode.hardLight.css == "hard-light")
    }

    @Test func shadowBoxVsText() {
        let s = Shadow(offsetX: .px(0), offsetY: .px(2), blur: .px(4),
                       spread: .px(1), color: .hex("#000"), inset: true)
        #expect(s.boxShadowCSS == "inset 0px 2px 4px 1px #000")
        #expect(s.textShadowCSS == "0px 2px 4px #000")
    }

    @Test func filterFunctions() {
        #expect(FilterFunction.blur(.px(4)).css == "blur(4px)")
        #expect(FilterFunction.brightness(1.2).css == "brightness(1.2)")
        #expect(FilterFunction.hueRotate(.deg(90)).css == "hue-rotate(90deg)")
        #expect(FilterFunction.dropShadow(x: .zero, y: .px(2), blur: .px(4), color: .hex("#000")).css
                == "drop-shadow(0 2px 4px #000)")
        #expect(FilterFunction.url("#id").css == "url(#id)")
    }

    @Test func transformFunctions() {
        #expect(TransformFunction.translateX(.percent(-50)).css == "translateX(-50%)")
        #expect(TransformFunction.translate(x: .px(10), y: .px(20)).css == "translate(10px, 20px)")
        #expect(TransformFunction.rotate(.deg(45)).css == "rotate(45deg)")
        #expect(TransformFunction.scale(x: 1.5, y: 2).css == "scale(1.5, 2)")
        #expect(TransformFunction.matrix(1, 0, 0, 1, 10, 20).css == "matrix(1, 0, 0, 1, 10, 20)")
    }

    @Test func gradients() {
        let linear = CSSBackgroundImage.linearGradient(
            angle: .deg(45),
            stops: [.colorAt(.hex("#fff"), .percent(0)), .colorAt(.hex("#000"), .percent(100))])
        #expect(linear.css == "linear-gradient(45deg, #fff 0%, #000 100%)")

        let noAngle = CSSBackgroundImage.linearGradient(
            stops: [.color(.hex("#fff")), .color(.hex("#000"))])
        #expect(noAngle.css == "linear-gradient(#fff, #000)")

        let radial = CSSBackgroundImage.radialGradient(
            shape: "circle", at: "center",
            stops: [.color(.hex("#fff")), .color(.hex("#000"))])
        #expect(radial.css == "radial-gradient(circle at center, #fff, #000)")

        let layered = CSSBackgroundImage.layered([
            .linearGradient(stops: [.color(.hex("#fff")), .color(.hex("#000"))]),
            .url("bg.png"),
        ])
        #expect(layered.css == "linear-gradient(#fff, #000), url(bg.png)")
    }

    @Test func gradientSubfieldSanitizeGuard() {
        // Safe sub-fields render; unsafe ones would trap in debug (assert-in-debug),
        // dropping to a safe fallback in release. Assert the guard predicate + safe path.
        #expect(CSSBackgroundImage.url("bg.png").css == "url(bg.png)")
        #expect(!CSSSanitize.isSafeValue("x} body { display:none"))
    }
}
