import Testing
import SwiftWUICore
import SwiftWUIState
@testable import SwiftWUIRuntime

/// Regression tests for the critical finding: `@State` in a nested component
/// was destroyed on every re-render because storage lived in the struct
/// instance and only the route-root tag survived. `RenderContext` gives every
/// component a structural identity so its `@State` persists across renders.
@Suite("Nested @State identity")
struct NestedStateIdentityTests {

    /// A leaf component that bumps its own `@State` each time its body is
    /// evaluated. If storage persists, the value climbs 1, 2, 3, …; if it is
    /// recreated each render, it sticks at 1.
    struct Counter: SwiftWUICore.Tag {
        @State var count = 0
        var body: some SwiftWUICore.Tag {
            count += 1
            return Text("count:\(count)")
        }
    }

    /// A parent that reconstructs a *new* Counter on every body evaluation —
    /// the exact shape that reset nested state before the fix.
    struct Parent: SwiftWUICore.Tag {
        var body: some SwiftWUICore.Tag { Counter() }
    }

    /// Two sibling counters of the same type; each must get its own storage.
    struct Pair: SwiftWUICore.Tag {
        var body: some SwiftWUICore.Tag {
            Counter()
            Counter()
        }
    }

    private func texts(in node: TagNode) -> [String] {
        switch node {
        case .text(let t): return [t]
        case .element(let e): return e.children.flatMap { texts(in: $0) }
        case .fragment(let cs): return cs.flatMap { texts(in: $0) }
        }
    }

    @Test("nested @State persists across re-renders")
    func nestedPersists() {
        let r = TestRenderer()
        r.render(Parent())
        r.update(Parent())
        r.update(Parent())
        let seen = r.renderedTrees.flatMap { texts(in: $0) }
        #expect(seen == ["count:1", "count:2", "count:3"])
    }

    @Test("sibling components of the same type keep independent state")
    func siblingsIndependent() {
        let r = TestRenderer()
        r.render(Pair())
        r.update(Pair())
        // Each render: both counters advance independently → [1,1] then [2,2].
        let firstPass = texts(in: r.renderedTrees[0])
        let secondPass = texts(in: r.renderedTrees[1])
        #expect(firstPass == ["count:1", "count:1"])
        #expect(secondPass == ["count:2", "count:2"])
    }
}
