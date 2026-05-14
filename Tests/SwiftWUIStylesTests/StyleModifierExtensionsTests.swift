import Testing
@testable import SwiftWUICore
@testable import SwiftWUIStyles
@testable import SwiftWUIHTML

@Suite("StyleModifier extensions")
struct StyleModifierExtensionsTests {

    @Test("backdropFilter passes through string")
    func backdropFilter() {
        let modified = StyleProxy().backdropFilter("saturate(180%) blur(20px)")
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["backdrop-filter"] == "saturate(180%) blur(20px)")
    }

    @Test("cursor pointer")
    func cursorPointer() {
        let modified = StyleProxy().cursor(.pointer)
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["cursor"] == "pointer")
    }

    @Test("boxShadow css")
    func boxShadow() {
        let modified = StyleProxy().boxShadow("0 1px 3px rgba(0,0,0,.10)")
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["box-shadow"] == "0 1px 3px rgba(0,0,0,.10)")
    }

    @Test("borderTop width style color")
    func borderTop() {
        let modified = StyleProxy().borderTop(width: .px(1), style: .solid, color: .css("#000"))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["border-top"] == "1px solid #000")
    }

    @Test("borderLeft accent token")
    func borderLeft() {
        let modified = StyleProxy().borderLeft(width: .px(3), style: .solid, color: .token("swui-accent"))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node"); return
        }
        #expect(el.styles["border-left"] == "3px solid var(--swui-accent)")
    }
}
