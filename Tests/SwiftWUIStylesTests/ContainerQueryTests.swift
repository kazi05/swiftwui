import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML
@testable import SwiftWUIStyles

@Suite("Container queries")
struct ContainerQueryTests {
    @Test("ContainerQuery emits @container with named context")
    func namedQuery() {
        let q = ContainerQuery.minWidth("sidebar", .px(400))
        #expect(q.cssString == "@container sidebar (min-width: 400px)")
    }

    @Test("ContainerQuery without a name targets the nearest container")
    func anonymousQuery() {
        let q = ContainerQuery.maxWidth(.px(600))
        #expect(q.cssString == "@container (max-width: 600px)")
    }

    @Test("ContainerQuery combinators compose")
    func combinators() {
        let q = ContainerQuery.and(
            .minWidth(.px(300)),
            .maxWidth(.px(800))
        )
        #expect(q.cssString.contains("(min-width: 300px) and (max-width: 800px)"))
    }

    @Test(".container(_:apply:) stores the query as a responsive style key")
    func containerModifierAttachesToTagNode() {
        let tag = Div { "x" }.container(.minWidth(.px(500))) { proxy in
            proxy.fontSize(.px(20))
        }
        let nodes = resolveTagBody(tag)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        let key = "@container (min-width: 500px)"
        #expect(el.responsiveStyles[key] != nil)
        #expect(el.responsiveStyles[key]?["font-size"] == "20px")
    }

    @Test(".anchorName and .positionAnchor produce CSS Anchor Positioning style props")
    func anchorPositioning() {
        let tag = Div { "x" }
            .anchorName("--menu")
            .positionAnchor("--target")
        let nodes = resolveTagBody(tag)
        guard case .element(let el) = nodes.first else {
            Issue.record("expected element"); return
        }
        #expect(el.styles["anchor-name"] == "--menu")
        #expect(el.styles["position-anchor"] == "--target")
    }
}
