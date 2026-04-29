import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRuntime

/// Element fixture for renderer-protocol tests. Plain `Tag` conformance plus
/// a `TagNodeConvertible` shortcut that emits a single named element so we
/// can write tree assertions without pulling SwiftWUIHTML into the test
/// dependencies.
private struct Block: SwiftWUICore.Tag, SwiftWUICore.TagNodeConvertible {
    typealias Body = Never
    let label: String
    func toTagNodes() -> [TagNode] {
        [.element(TagNode.Element(
            tagName: "div",
            attributes: ["data-label": label]
        ))]
    }
}

@Suite("Renderer protocol")
struct RendererProtocolTests {
    @Test("TestRenderer records the initial tree from render()")
    func recordsInitialTree() {
        let r = TestRenderer()
        r.render(Block(label: "alpha"))
        #expect(r.renderedTrees.count == 1)
        #expect(r.patches.isEmpty)
    }

    @Test("TestRenderer emits a patch when update() differs from render()")
    func emitsPatchOnDiff() {
        let r = TestRenderer()
        r.render(Block(label: "alpha"))
        r.update(Block(label: "beta"))
        #expect(r.renderedTrees.count == 2)
        #expect(r.patches.count == 1)
    }

    @Test("TestRenderer suppresses no-op updates")
    func noPatchWhenIdentical() {
        let r = TestRenderer()
        r.render(Block(label: "alpha"))
        r.update(Block(label: "alpha"))
        #expect(r.patches.isEmpty)
    }

    @Test("TestRenderer captures animation context per update")
    func capturesAnimation() {
        let r = TestRenderer()
        r.render(Block(label: "a"))
        r.update(Block(label: "b"), animation: nil)
        r.update(Block(label: "c"), animation: .easeInOut(duration: 0.25))
        #expect(r.patches.count == 2)
        #expect(r.animations.count == 2)
        #expect(r.animations[0] == nil)
        #expect(r.animations[1] != nil)
    }

    @Test("TestRenderer.reset clears all recorded state")
    func resetClears() {
        let r = TestRenderer()
        r.render(Block(label: "a"))
        r.update(Block(label: "b"))
        r.reset()
        #expect(r.renderedTrees.isEmpty)
        #expect(r.patches.isEmpty)
        #expect(r.latestTree == nil)
    }

    @Test("DOMRenderer (via stub) and TestRenderer satisfy the same Renderer protocol")
    func sameProtocolSatisfaction() {
        // Compile-time check: both can stand in for a generic R: Renderer.
        func acceptAny<R: Renderer>(_ renderer: R) {
            renderer.render(Block(label: "x"))
        }
        let test = TestRenderer()
        acceptAny(test)
        #expect(test.renderedTrees.count == 1)
    }
}
