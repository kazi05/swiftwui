import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRuntime

@Suite("StyleSheetManager Tests")
struct StyleSheetManagerTests {

    @Test("ensureClass returns deterministic class name")
    func deterministic() {
        let manager = StyleSheetManager()
        let a = manager.ensureClass(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        let b = manager.ensureClass(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        #expect(a == b)
        #expect(a.hasPrefix("swui-r"))
    }

    @Test("ensureClass returns different names for different inputs")
    func different() {
        let manager = StyleSheetManager()
        let a = manager.ensureClass(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        let b = manager.ensureClass(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "24px"])
        #expect(a != b)
    }

    @Test("cssRuleText generates correct CSS with !important")
    func cssRuleText() {
        let manager = StyleSheetManager()
        let rule = manager.cssRuleText(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        #expect(rule.contains("@media (max-width: 767px)"))
        #expect(rule.contains("font-size: 16px !important;"))
        #expect(rule.contains("swui-r"))
    }

    @Test("ensureClass deduplicates — second call returns same class without re-registration")
    func deduplication() {
        let manager = StyleSheetManager()
        let first = manager.ensureClass(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        let second = manager.ensureClass(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        #expect(first == second)
    }

    @Test("cssRuleText sorts declarations alphabetically")
    func sortedDeclarations() {
        let manager = StyleSheetManager()
        let rule = manager.cssRuleText(
            mediaQuery: "@media (max-width: 767px)",
            styles: ["padding": "8px", "font-size": "16px", "color": "red"]
        )
        // Check alphabetical order: color, font-size, padding
        let colorPos = rule.range(of: "color:")!.lowerBound
        let fontPos = rule.range(of: "font-size:")!.lowerBound
        let paddingPos = rule.range(of: "padding:")!.lowerBound
        #expect(colorPos < fontPos)
        #expect(fontPos < paddingPos)
    }
}
