import Testing
@testable import SwiftWUICore
@testable import SwiftWUIStyles

@Suite("MediaQuery Tests")
struct MediaQueryTests {

    // MARK: - cssString output

    @Test("minWidth produces correct CSS")
    func minWidth() {
        let mq = MediaQuery.minWidth(.px(768))
        #expect(mq.cssString == "@media (min-width: 768px)")
    }

    @Test("maxWidth produces correct CSS")
    func maxWidth() {
        let mq = MediaQuery.maxWidth(.px(767))
        #expect(mq.cssString == "@media (max-width: 767px)")
    }

    @Test("minHeight produces correct CSS")
    func minHeight() {
        let mq = MediaQuery.minHeight(.vh(50))
        #expect(mq.cssString == "@media (min-height: 50vh)")
    }

    @Test("maxHeight produces correct CSS")
    func maxHeight() {
        let mq = MediaQuery.maxHeight(.px(600))
        #expect(mq.cssString == "@media (max-height: 600px)")
    }

    @Test("colorScheme dark produces correct CSS")
    func colorSchemeDark() {
        let mq = MediaQuery.colorScheme(.dark)
        #expect(mq.cssString == "@media (prefers-color-scheme: dark)")
    }

    @Test("colorScheme light produces correct CSS")
    func colorSchemeLight() {
        let mq = MediaQuery.colorScheme(.light)
        #expect(mq.cssString == "@media (prefers-color-scheme: light)")
    }

    @Test("prefersReducedMotion produces correct CSS")
    func prefersReducedMotion() {
        let mq = MediaQuery.prefersReducedMotion
        #expect(mq.cssString == "@media (prefers-reduced-motion: reduce)")
    }

    @Test("and combinator produces correct CSS")
    func andCombinator() {
        let mq = MediaQuery.and(.minWidth(.px(768)), .maxWidth(.px(1023)))
        #expect(mq.cssString == "@media (min-width: 768px) and (max-width: 1023px)")
    }

    @Test("or combinator produces correct CSS")
    func orCombinator() {
        let mq = MediaQuery.or(.maxWidth(.px(480)), .minWidth(.px(1200)))
        #expect(mq.cssString == "@media (max-width: 480px), (min-width: 1200px)")
    }

    @Test("not combinator produces correct CSS")
    func notCombinator() {
        let mq = MediaQuery.not(.prefersReducedMotion)
        #expect(mq.cssString == "@media not (prefers-reduced-motion: reduce)")
    }

    // MARK: - Predefined breakpoints

    @Test("compact breakpoint")
    func compactBreakpoint() {
        #expect(MediaQuery.compact.cssString == "@media (max-width: 767px)")
    }

    @Test("regular breakpoint")
    func regularBreakpoint() {
        #expect(MediaQuery.regular.cssString == "@media (min-width: 768px) and (max-width: 1023px)")
    }

    @Test("expanded breakpoint")
    func expandedBreakpoint() {
        #expect(MediaQuery.expanded.cssString == "@media (min-width: 1024px)")
    }

    // MARK: - Hashable conformance

    @Test("MediaQuery is Hashable — equal values hash equally")
    func hashable() {
        let a = MediaQuery.minWidth(.px(768))
        let b = MediaQuery.minWidth(.px(768))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("MediaQuery is Hashable — different values differ")
    func hashableDiffers() {
        let a = MediaQuery.minWidth(.px(768))
        let b = MediaQuery.minWidth(.px(1024))
        #expect(a != b)
    }
}
