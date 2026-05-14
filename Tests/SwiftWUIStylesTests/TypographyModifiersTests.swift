import Testing
@testable import SwiftWUICore
@testable import SwiftWUIStyles
@testable import SwiftWUIHTML

@Suite("TypographyModifiers")
struct TypographyModifiersTests {

    @Test("fontFamily emits font-family declaration")
    func fontFamily() {
        let modified = StyleProxy().fontFamily("Helvetica, sans-serif")
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["font-family"] == "Helvetica, sans-serif")
    }

    @Test("textTransform uppercase")
    func textTransformUppercase() {
        let modified = StyleProxy().textTransform(.uppercase)
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["text-transform"] == "uppercase")
    }

    @Test("letterSpacing em")
    func letterSpacingEm() {
        let modified = StyleProxy().letterSpacing(.em(0.08))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["letter-spacing"] == "0.08em")
    }

    @Test("lineHeight unitless")
    func lineHeightUnitless() {
        let modified = StyleProxy().lineHeight(.unitless(1.5))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["line-height"] == "1.5")
    }

    @Test("lineHeight px")
    func lineHeightPx() {
        let modified = StyleProxy().lineHeight(.px(24))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["line-height"] == "24px")
    }

    @Test("whiteSpace nowrap")
    func whiteSpaceNowrap() {
        let modified = StyleProxy().whiteSpace(.nowrap)
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["white-space"] == "nowrap")
    }

    @Test("textAlign right")
    func textAlignRight() {
        let modified = StyleProxy().textAlign(.right)
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["text-align"] == "right")
    }

    @Test("textDecoration none")
    func textDecorationNone() {
        let modified = StyleProxy().textDecoration(.none)
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["text-decoration"] == "none")
    }

    @Test("textIndent px")
    func textIndentPx() {
        let modified = StyleProxy().textIndent(.px(16))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["text-indent"] == "16px")
    }
}
