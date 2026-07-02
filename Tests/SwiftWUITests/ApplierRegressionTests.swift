import Testing
@testable import SwiftWUI

// Regression tests for finding C1: nested `updateChildren` plan anchors must use
// the live end-anchor threaded down from the enclosing `applyChildren` call, not
// a re-walk of shadow state whose `children`/`indexInParent` are still stale
// mid-application (spec §8.4). Reuses TestScheduler/findAll from RuntimeE2ETests.

private struct MultiRoot: Tag {
    let id: Int
    let extra: Bool
    var body: some Tag {
        Span { "s\(id)a" }
        Span { "s\(id)b" }
        if extra { Strong { "x\(id)" } }
    }
}

// Repro 1: keyed reorder moves a multi-root component WHILE its own child list
// grows in the same flush — the growing child must land inside its component's
// block, not spill outside it.
private struct HostView: Tag {
    @State var items = [1, 2]
    @State var extra = false
    var body: some Tag {
        Div {
            ForEach(items, id: \.self) { i in MultiRoot(id: i, extra: extra) }
            Button("go") { items.reverse(); extra = true }
        }
    }
}

// Repro 2: a sibling is removed WHILE another multi-root component grows —
// the anchor must not point at an already-detached (unmounted) host.
private struct HostView2: Tag {
    @State var items = [1, 2]
    @State var extra = false
    var body: some Tag {
        Div {
            ForEach(items, id: \.self) { i in MultiRoot(id: i, extra: extra) }
            Button("go") { items.removeLast(); extra = true }
        }
    }
}

@Suite @MainActor struct ApplierRegressionTests {
    @Test func movedMultiRootComponentWithGrowingChildren() {
        let (runtime, backend, sched) = makeRuntime(HostView())
        runtime.mount()
        let button = findAll(backend.container, tag: "button")[0]
        runtime.dispatch(button.events["click"]!)
        sched.pump()

        let got = backend.serializeHTML()
        let expected = HTMLRenderer.render(
            Div {
                ForEach([2, 1], id: \.self) { i in MultiRoot(id: i, extra: true) }
                Button("go") {}
            })
        #expect(got == expected, "applied: \(got)\nexpected: \(expected)")
    }

    @Test func removedSiblingWhileComponentGrows() {
        let (runtime, backend, sched) = makeRuntime(HostView2())
        runtime.mount()
        let button = findAll(backend.container, tag: "button")[0]
        runtime.dispatch(button.events["click"]!)
        sched.pump()

        let got = backend.serializeHTML()
        let expected = HTMLRenderer.render(
            Div {
                ForEach([1], id: \.self) { i in MultiRoot(id: i, extra: true) }
                Button("go") {}
            })
        #expect(got == expected, "applied: \(got)\nexpected: \(expected)")
    }

    private func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        return (runtime, backend, sched)
    }

    // M2 (phase-1 review): replaceSelf inside a reuse slot must be unreachable —
    // sameIdentity() gates every reuse, and diff() only emits replaceSelf when
    // identity/tag mismatch. Pin the two mismatch shapes as fresh+removed plans.
    @Test func mismatchProducesFreshNotReplaceSelf() {
        let r = Reconciler()
        let oldE = Node.element(ElementNode(identity: .root.appending(.child(0)), tag: "div",
                                            attributes: [:], listeners: [:], children: [], key: nil))
        let newE = Node.element(ElementNode(identity: .root.appending(.child(0)), tag: "span",
                                            attributes: [:], listeners: [:], children: [], key: nil))
        let plan = r.diffChildren(old: [oldE], new: [newE])
        // tag change at same identity → NOT a reuse slot
        guard case .fresh = plan.slots[0] else { Issue.record("expected fresh slot"); return }
        #expect(plan.removedOldIndices == [0])
    }

    @Test func textToElementProducesFreshNotReplaceSelf() {
        let r = Reconciler()
        let newE = Node.element(ElementNode(identity: .root.appending(.child(0)), tag: "div",
                                            attributes: [:], listeners: [:], children: [], key: nil))
        let plan = r.diffChildren(old: [.text("x")], new: [newE])
        guard case .fresh = plan.slots[0] else { Issue.record("expected fresh slot"); return }
        #expect(plan.removedOldIndices == [0])
    }
}
