import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML
@testable import SwiftWUIStyles

@Suite("View transitions")
struct ViewTransitionsTests {
    @Test("viewTransitionName sets the CSS property on the element")
    func setsCSSProperty() {
        let tag = Div {}.viewTransitionName("hero-1")
        let nodes = resolveTagBody(tag)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.styles["view-transition-name"] == "hero-1")
    }

    @Test("viewTransitionName composes with other style modifiers")
    func composesWithOthers() {
        let tag = Div {}
            .viewTransitionName("card-42")
            .padding(.px(16))
        let nodes = resolveTagBody(tag)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.styles["view-transition-name"] == "card-42")
        #expect(el.styles["padding"] == "16px")
    }
}
