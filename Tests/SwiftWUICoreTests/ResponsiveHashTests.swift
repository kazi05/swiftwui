import Testing
@testable import SwiftWUICore

@Suite("Responsive Hash Tests")
struct ResponsiveHashTests {

    @Test("Same input produces same hash")
    func deterministic() {
        let a = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        let b = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        #expect(a == b)
    }

    @Test("Different inputs produce different hashes")
    func differs() {
        let a = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        let b = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "24px"])
        #expect(a != b)
    }

    @Test("Class name starts with swui-r prefix")
    func prefix() {
        let name = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        #expect(name.hasPrefix("swui-r"))
    }

    @Test("Style order does not affect hash")
    func orderIndependent() {
        let a = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px", "padding": "8px"])
        let b = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["padding": "8px", "font-size": "16px"])
        #expect(a == b)
    }

    @Test("responsiveClassNames produces correct set")
    func classNamesSet() {
        let styles: [String: [String: String]] = [
            "@media (max-width: 767px)": ["font-size": "16px"],
            "@media (min-width: 1024px)": ["font-size": "32px"],
        ]
        let names = responsiveClassNames(for: styles)
        #expect(names.count == 2)
        #expect(names.allSatisfy { $0.hasPrefix("swui-r") })
    }

    @Test("Empty responsive styles produces empty set")
    func emptyStyles() {
        let names = responsiveClassNames(for: [:])
        #expect(names.isEmpty)
    }
}
