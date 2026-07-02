import Testing
@testable import SwiftWUI

private func el(_ tag: String, id: NodeIdentity = .root, attrs: [String: String] = [:],
                listeners: [String: ListenerID] = [:], children: [Node] = [], key: NodeKey? = nil) -> Node {
    .element(ElementNode(identity: id, tag: tag, attributes: attrs,
                         listeners: listeners, children: children, key: key))
}

@Suite struct ReconcilerTests {
    let r = Reconciler()

    @Test func identicalNodesNoPatches() {
        let n = el("div", attrs: ["class": "a"], children: [.text("x")])
        #expect(r.diff(old: n, new: n).isEmpty)
    }
    @Test func textChange() {
        #expect(r.diff(old: .text("a"), new: .text("b")) == [.setText("b")])
    }
    @Test func kindMismatchReplaces() {
        #expect(r.diff(old: .text("a"), new: el("div")) == [.replaceSelf(with: el("div"))])
    }
    @Test func attributeAddChangeRemove() {
        let old = el("div", attrs: ["a": "1", "b": "2"])
        let new = el("div", attrs: ["b": "3", "c": "4"])
        #expect(r.diff(old: old, new: new) == [
            .setAttribute(name: "b", value: "3"),
            .setAttribute(name: "c", value: "4"),
            .removeAttribute(name: "a"),
        ])
    }
    @Test func stableListenerIDNoPatch() {
        let lid = ListenerID(owner: NodeIdentity.root.appending(.child(0)), event: "click")
        let old = el("button", listeners: ["click": lid])
        let new = el("button", listeners: ["click": lid])
        #expect(r.diff(old: old, new: new).isEmpty)      // no churn — spec §8.5
    }
    @Test func tagChangeReplaces() {
        let new = el("span")
        #expect(r.diff(old: el("div"), new: new) == [.replaceSelf(with: new)])
    }
    @Test func identityChangeReplaces() {
        let idA = NodeIdentity.root.appending(.branch(true))
        let idB = NodeIdentity.root.appending(.branch(false))
        let new = el("div", id: idB)
        #expect(r.diff(old: el("div", id: idA), new: new) == [.replaceSelf(with: new)])
    }
    @Test func componentIdentityChangeReplaces() {
        let a = Node.component(ComponentNode(identity: NodeIdentity.root.appending(.child(0)), typeName: "A", key: nil, children: []))
        let b = Node.component(ComponentNode(identity: NodeIdentity.root.appending(.child(1)), typeName: "B", key: nil, children: []))
        #expect(r.diff(old: a, new: b) == [.replaceSelf(with: b)])
    }
    @Test(.disabled("needs Task 10")) func childTextChangeProducesNestedPlan() {
        let old = el("div", children: [.text("a")])
        let new = el("div", children: [.text("b")])
        let patches = r.diff(old: old, new: new)
        guard case .updateChildren(let plan) = patches.first else { Issue.record("expected plan"); return }
        #expect(plan.slots == [.reuse(oldIndex: 0, patches: [.setText("b")])])
        #expect(plan.removedOldIndices.isEmpty)
    }
}
