import Testing
@testable import SwiftWUI

@Suite struct MediaQueryConditionTests {
    @Test func heightAndOrientation() {
        #expect(MediaQuery.minHeight(.px(500)).condition == "(min-height: 500px)")
        #expect(MediaQuery.maxHeight(.px(500)).condition == "(max-height: 500px)")
        #expect(MediaQuery.orientation(.portrait).condition == "(orientation: portrait)")
        #expect(MediaQuery.orientation(.landscape).condition == "(orientation: landscape)")
    }
    @Test func combinatorsParenthesizeOperands() {
        #expect(MediaQuery.and(.minWidth(.px(768)), .maxWidth(.px(1023))).condition
                == "((min-width: 768px) and (max-width: 1023px))")
        #expect(MediaQuery.or(.minWidth(.px(400)), .orientation(.portrait)).condition
                == "((min-width: 400px) or (orientation: portrait))")
        #expect(MediaQuery.not(.minWidth(.px(768))).condition == "(not (min-width: 768px))")
    }
    @Test func combinatorsNestValidly() {
        // The v1 bug: nested and/or emitted unparenthesized, invalid CSS.
        let q = MediaQuery.and(.or(.minWidth(.px(400)), .orientation(.portrait)), .maxWidth(.px(900)))
        #expect(q.condition == "(((min-width: 400px) or (orientation: portrait)) and (max-width: 900px))")
    }
}

@Suite struct BreakpointTests {
    @Test func scaleAndComparable() {
        #expect(Breakpoint.sm.minWidthPx == 640)
        #expect(Breakpoint.md.minWidthPx == 768)
        #expect(Breakpoint.lg.minWidthPx == 1024)
        #expect(Breakpoint.xl.minWidthPx == 1280)
        #expect(Breakpoint.sm < Breakpoint.md)
        #expect(Breakpoint.allCases.count == 4)
    }
    @Test func upIsMinWidth() {
        #expect(MediaQuery.up(.md).condition == "(min-width: 768px)")
    }
    @Test func downIsMaxWidthBelowBreakpoint() {
        // -0.02px avoids exact-boundary overlap with .up; formatting of the
        // fractional part is not asserted exactly.
        #expect(MediaQuery.down(.md).condition.hasPrefix("(max-width: 767"))
    }
}
