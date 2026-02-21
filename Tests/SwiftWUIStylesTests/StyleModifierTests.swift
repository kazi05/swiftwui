import Testing
@testable import SwiftWUICore
@testable import SwiftWUIStyles

@Suite("CSSUnit Tests")
struct CSSUnitTests {

    @Test("px value")
    func pxValue() {
        #expect(CSSUnit.px(16).cssValue == "16px")
        #expect(CSSUnit.px(1.5).cssValue == "1.5px")
    }

    @Test("em value")
    func emValue() {
        #expect(CSSUnit.em(1).cssValue == "1em")
        #expect(CSSUnit.em(2.5).cssValue == "2.5em")
    }

    @Test("rem value")
    func remValue() {
        #expect(CSSUnit.rem(1).cssValue == "1rem")
    }

    @Test("percent value")
    func percentValue() {
        #expect(CSSUnit.percent(100).cssValue == "100%")
        #expect(CSSUnit.percent(50).cssValue == "50%")
    }

    @Test("auto value")
    func autoValue() {
        #expect(CSSUnit.auto.cssValue == "auto")
    }

    @Test("zero value")
    func zeroValue() {
        #expect(CSSUnit.zero.cssValue == "0")
    }

    @Test("viewport units")
    func viewportUnits() {
        #expect(CSSUnit.vw(100).cssValue == "100vw")
        #expect(CSSUnit.vh(50).cssValue == "50vh")
    }
}

@Suite("CSSColor Tests")
struct CSSColorTests {

    @Test("Named colors")
    func namedColors() {
        #expect(CSSColor.red.cssValue == "#ff0000")
        #expect(CSSColor.blue.cssValue == "#0000ff")
        #expect(CSSColor.white.cssValue == "#ffffff")
        #expect(CSSColor.black.cssValue == "#000000")
        #expect(CSSColor.transparent.cssValue == "transparent")
    }

    @Test("Hex color with hash")
    func hexWithHash() {
        let color = CSSColor(hex: "#ff5733")
        #expect(color.cssValue == "#ff5733")
    }

    @Test("Hex color without hash")
    func hexWithoutHash() {
        let color = CSSColor(hex: "ff5733")
        #expect(color.cssValue == "#ff5733")
    }

    @Test("RGB color")
    func rgbColor() {
        let color = CSSColor.rgb(255, 0, 128)
        #expect(color.cssValue == "rgb(255, 0, 128)")
    }

    @Test("RGBA color")
    func rgbaColor() {
        let color = CSSColor.rgba(255, 0, 128, 0.5)
        #expect(color.cssValue == "rgba(255, 0, 128, 0.5)")
    }

    @Test("HSL color")
    func hslColor() {
        let color = CSSColor.hsl(120, 50, 50)
        #expect(color.cssValue == "hsl(120, 50%, 50%)")
    }
}

@Suite("Style Modifier Tests")
struct StyleModifierTests {

    @Test("backgroundColor modifier")
    func backgroundColorModifier() {
        let text = Text("Hello")
        let modified = text.backgroundColor(.red)
        #expect(modified.styles.contains { $0 == ("background-color", "#ff0000") })
    }

    @Test("foregroundColor modifier")
    func foregroundColorModifier() {
        let text = Text("Hello")
        let modified = text.foregroundColor(.blue)
        #expect(modified.styles.contains { $0 == ("color", "#0000ff") })
    }

    @Test("padding modifier")
    func paddingModifier() {
        let text = Text("Hello")
        let modified = text.padding(.px(16))
        #expect(modified.styles.contains { $0 == ("padding", "16px") })
    }

    @Test("fontSize modifier")
    func fontSizeModifier() {
        let text = Text("Hello")
        let modified = text.fontSize(.rem(1.5))
        #expect(modified.styles.contains { $0 == ("font-size", "1.5rem") })
    }

    @Test("display modifier")
    func displayModifier() {
        let text = Text("Hello")
        let modified = text.display(.flex)
        #expect(modified.styles.contains { $0 == ("display", "flex") })
    }

    @Test("Chaining multiple style modifiers")
    func chainingStyles() {
        let text = Text("Hello")
        let modified = text
            .backgroundColor(.white)
            .foregroundColor(.black)
            .padding(.px(8))
            .borderRadius(.px(4))

        #expect(modified.styles.count == 4)
    }

    @Test("flexDirection modifier")
    func flexDirectionModifier() {
        let text = Text("Hello")
        let modified = text.flexDirection(.column)
        #expect(modified.styles.contains { $0 == ("flex-direction", "column") })
    }

    @Test("cursor modifier")
    func cursorModifier() {
        let text = Text("Hello")
        let modified = text.cursor(.pointer)
        #expect(modified.styles.contains { $0 == ("cursor", "pointer") })
    }
}

@Suite("CSS Value Enum Tests")
struct CSSValueTests {

    @Test("Display values")
    func displayValues() {
        #expect(Display.flex.rawValue == "flex")
        #expect(Display.grid.rawValue == "grid")
        #expect(Display.inlineBlock.rawValue == "inline-block")
        #expect(Display.none.rawValue == "none")
    }

    @Test("Position values")
    func positionValues() {
        #expect(Position.absolute.rawValue == "absolute")
        #expect(Position.fixed.rawValue == "fixed")
        #expect(Position.sticky.rawValue == "sticky")
    }

    @Test("FontWeight values")
    func fontWeightValues() {
        #expect(FontWeight.bold.cssValue == "bold")
        #expect(FontWeight.w600.cssValue == "600")
    }

    @Test("Cursor values")
    func cursorValues() {
        #expect(Cursor.pointer.rawValue == "pointer")
        #expect(Cursor.notAllowed.rawValue == "not-allowed")
    }
}
