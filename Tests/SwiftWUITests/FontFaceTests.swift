import Testing
@testable import SwiftWUI

@Suite struct FontFaceTests {
    @Test func fullRuleText() {
        let f = FontFace(family: "Inter", src: "/fonts/Inter.woff2", format: .woff2,
                         weight: 400...700, style: .normal, display: .swap)
        #expect(f.ruleText == "@font-face { font-family: \"Inter\"; src: url(\"/fonts/Inter.woff2\") format(\"woff2\"); font-weight: 400 700; font-style: normal; font-display: swap }")
    }

    @Test func singleWeightAndDefaults() {
        let f = FontFace(family: "Mono", src: "/m.woff2", weight: 500)
        #expect(f.ruleText.contains("font-weight: 500"))
        #expect(f.ruleText.contains("font-display: swap"))
        #expect(!f.ruleText.contains("format("))
        let noWeight = FontFace(family: "Mono", src: "/m.woff2")
        #expect(!noWeight.ruleText.contains("font-weight"))
    }

    @Test func escapingAndSanitizing() {
        let evil = FontFace(family: "x\") } body { background: url(\"p", src: "javascript:alert(1)")
        #expect(evil.ruleText.contains("url(\"#\")"))                 // sanitizeURL dropped the scheme
        #expect(!evil.ruleText.contains("x\") }"))                    // quote escaped, no breakout
        #expect(evil.ruleText.contains("font-family: \"x\\\") } body { background: url(\\\"p\""))
    }

    @Test func mountRegistersFontFaces() {
        let mock = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: mock, container: mock.container, root: Div(),
                              scheduleMicrotask: sched.schedule,
                              fontFaces: [FontFace(family: "Inter", src: "/i.woff2")])
        runtime.mount()
        sched.pump()
        #expect(mock.stylesheetText?.contains("@font-face") == true)
        #expect(mock.stylesheetText?.contains("\"Inter\"") == true)
    }
}
