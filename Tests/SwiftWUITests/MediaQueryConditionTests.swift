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
