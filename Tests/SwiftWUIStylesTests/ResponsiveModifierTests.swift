import Testing
@testable import SwiftWUICore
@testable import SwiftWUIStyles
@testable import SwiftWUIHTML

@Suite("StyleProxy Tests")
struct StyleProxyTests {

    @Test("StyleProxy produces a single proxy element node")
    func producesProxyElement() {
        let proxy = StyleProxy()
        let nodes = proxy.toTagNodes()
        #expect(nodes.count == 1)
        if case .element(let el) = nodes[0] {
            #expect(el.tagName == "__proxy__")
            #expect(el.styles.isEmpty)
        } else {
            Issue.record("Expected element node")
        }
    }

    @Test("StyleProxy with modifiers collects styles")
    func collectsStyles() {
        let modified = StyleProxy()
            .fontSize(.px(16))
            .padding(.px(8))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.styles["font-size"] == "16px")
        #expect(el.styles["padding"] == "8px")
    }

    @Test("StyleProxy with chained modifiers collects all styles")
    func chainsModifiers() {
        let modified = StyleProxy()
            .backgroundColor(CSSColor(hex: "#1a1a1a"))
            .foregroundColor(.white)
            .display(.flex)
            .borderRadius(.px(8))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.styles.count == 4)
        #expect(el.styles["background-color"] == "#1a1a1a")
        #expect(el.styles["color"] == "#ffffff")
        #expect(el.styles["display"] == "flex")
        #expect(el.styles["border-radius"] == "8px")
    }
}

@Suite("ResponsiveModifier Tests")
struct ResponsiveModifierTests {

    @Test(".media() on Tag stores responsive styles")
    func mediaOnTag() {
        let div = Div { Text("Hello") }
        let modified = div.media(.compact) {
            $0.fontSize(.px(16))
        }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let query = MediaQuery.compact.cssString
        #expect(el.responsiveStyles[query] != nil)
        #expect(el.responsiveStyles[query]!["font-size"] == "16px")
    }

    @Test(".media() on ModifiedContent chains correctly")
    func mediaOnModifiedContent() {
        let div = Div { Text("Hello") }
        let modified = div
            .padding(.px(32))
            .media(.compact) {
                $0.padding(.px(16))
                  .fontSize(.px(14))
            }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        // Inline style
        #expect(el.styles["padding"] == "32px")
        // Responsive styles
        let query = MediaQuery.compact.cssString
        #expect(el.responsiveStyles[query]!["padding"] == "16px")
        #expect(el.responsiveStyles[query]!["font-size"] == "14px")
    }

    @Test("Multiple .media() calls for different breakpoints")
    func multipleBreakpoints() {
        let div = Div { Text("Hello") }
        let modified = div
            .fontSize(.px(24))
            .media(.compact) { $0.fontSize(.px(16)) }
            .media(.expanded) { $0.fontSize(.px(32)) }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.responsiveStyles.count == 2)
        #expect(el.responsiveStyles[MediaQuery.compact.cssString]!["font-size"] == "16px")
        #expect(el.responsiveStyles[MediaQuery.expanded.cssString]!["font-size"] == "32px")
    }

    @Test(".media() with custom breakpoint")
    func customBreakpoint() {
        let div = Div { Text("Hello") }
        let modified = div.media(.maxWidth(.px(480))) {
            $0.display(.none)
        }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let query = MediaQuery.maxWidth(.px(480)).cssString
        #expect(el.responsiveStyles[query]!["display"] == "none")
    }

    @Test(".media() with .style() fallback works")
    func styleFallback() {
        let div = Div { Text("Hello") }
        let modified = div.media(.compact) {
            $0.style("gap", "12px")
        }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let query = MediaQuery.compact.cssString
        #expect(el.responsiveStyles[query]!["gap"] == "12px")
    }

    @Test(".media() with colorScheme dark")
    func darkMode() {
        let div = Div { Text("Hello") }
        let modified = div.media(.colorScheme(.dark)) {
            $0.backgroundColor(CSSColor(hex: "#1a1a1a"))
        }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let query = MediaQuery.colorScheme(.dark).cssString
        #expect(el.responsiveStyles[query]!["background-color"] == "#1a1a1a")
    }
}
