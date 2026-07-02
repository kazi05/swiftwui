import Testing
@testable import SwiftWUI

@Suite @MainActor struct ApplierTests {
    func makeApplier() -> (TreeApplier<MockBackend>, MockBackend) {
        let backend = MockBackend()
        return (TreeApplier(backend: backend, container: backend.container), backend)
    }
    func elN(_ tag: String, slot: Int, children: [Node] = []) -> Node {
        .element(ElementNode(identity: NodeIdentity.root.appending(.child(slot)), tag: tag,
                             attributes: [:], listeners: [:], children: children, key: nil))
    }
    func comp(_ slot: Int, children: [Node]) -> Node {
        .component(ComponentNode(identity: NodeIdentity.root.appending(.child(slot)).appending(.type(ObjectIdentifier(Int.self))),
                                 typeName: "C", key: nil, children: children))
    }

    @Test func mountBuildsHostTree() {
        let (applier, backend) = makeApplier()
        let tree = elN("div", slot: 0, children: [.text("hi"), elN("span", slot: 1)])
        let m = applier.mount(tree, hostParent: backend.container, before: nil)
        applier.root.children = [m]; m.parent = applier.root; m.indexInParent = 0
        #expect(backend.container.children.count == 1)
        let div = backend.container.children[0]
        #expect(div.tag == "div")
        #expect(div.children[0].text == "hi")
        #expect(div.children[1].tag == "span")
    }
    @Test func componentFlattensIntoParentHost() {
        let (applier, backend) = makeApplier()
        // container > [element div, component(span, span), element div]
        let tree: [Node] = [elN("div", slot: 0),
                            comp(1, children: [elN("span", slot: 10), elN("span", slot: 11)]),
                            elN("div", slot: 2)]
        for (i, n) in tree.enumerated() {
            let m = applier.mount(n, hostParent: backend.container, before: nil)
            m.parent = applier.root; m.indexInParent = i; applier.root.children.append(m)
        }
        #expect(backend.container.children.map(\.tag) == ["div", "span", "span", "div"])
    }
    @Test func anchorSkipsComponentBoundary() {
        let (applier, backend) = makeApplier()
        let tree: [Node] = [comp(0, children: [elN("span", slot: 10), elN("span", slot: 11)]),
                            elN("div", slot: 1)]
        for (i, n) in tree.enumerated() {
            let m = applier.mount(n, hostParent: backend.container, before: nil)
            m.parent = applier.root; m.indexInParent = i; applier.root.children.append(m)
        }
        // Insert a fresh element between the two spans INSIDE the component:
        let compMounted = applier.root.children[0]
        let plan = ChildrenPlan(slots: [
            .reuse(oldIndex: 0, patches: []),
            .fresh(elN("em", slot: 12)),
            .reuse(oldIndex: 1, patches: []),
        ], removedOldIndices: [])
        applier.applyChildren(plan, on: compMounted)
        #expect(backend.container.children.map(\.tag) == ["span", "em", "span", "div"])
    }
    @Test func unmountComponentRemovesAllItsHosts() {
        let (applier, backend) = makeApplier()
        let tree: [Node] = [elN("div", slot: 0),
                            comp(1, children: [elN("span", slot: 10), elN("span", slot: 11)])]
        for (i, n) in tree.enumerated() {
            let m = applier.mount(n, hostParent: backend.container, before: nil)
            m.parent = applier.root; m.indexInParent = i; applier.root.children.append(m)
        }
        applier.unmount(applier.root.children[1])
        #expect(backend.container.children.map(\.tag) == ["div"])
    }
    @Test func reorderMovesNotRecreates() {
        let (applier, backend) = makeApplier()
        let a = elN("li", slot: 0); let b = elN("li", slot: 1)
        for (i, n) in [a, b].enumerated() {
            let m = applier.mount(n, hostParent: backend.container, before: nil)
            m.parent = applier.root; m.indexInParent = i; applier.root.children.append(m)
        }
        let createdBefore = backend.counts["createElement", default: 0]
        let hostA = backend.container.children[0]
        let plan = ChildrenPlan(slots: [
            .reuse(oldIndex: 1, patches: []),
            .reuse(oldIndex: 0, patches: []),
        ], removedOldIndices: [])
        applier.applyChildren(plan, on: applier.root)
        #expect(backend.container.children.count == 2)
        #expect(backend.container.children[1] === hostA)               // moved, not recreated
        #expect(backend.counts["createElement", default: 0] == createdBefore)
    }
    @Test func identityReorderPlanTouchesNothing() {
        let (applier, backend) = makeApplier()
        for (i, n) in [elN("li", slot: 0), elN("li", slot: 1)].enumerated() {
            let m = applier.mount(n, hostParent: backend.container, before: nil)
            m.parent = applier.root; m.indexInParent = i; applier.root.children.append(m)
        }
        let inserts = backend.counts["insert", default: 0]
        let plan = ChildrenPlan(slots: [
            .reuse(oldIndex: 0, patches: []),
            .reuse(oldIndex: 1, patches: []),
        ], removedOldIndices: [])
        applier.applyChildren(plan, on: applier.root)
        #expect(backend.counts["insert", default: 0] == inserts)       // in-order reuse = zero moves
    }
    @Test func patchEquivalentToRebuild() {
        // THE load-bearing invariant (spec §10.2): mount(old)+apply(diff) ≡ mount(new).
        let cases: [(old: Node, new: Node)] = [
            (elN("div", slot: 0, children: [.text("a")]), elN("div", slot: 0, children: [.text("b")])),
            (elN("div", slot: 0, children: [.text("a")]), elN("div", slot: 0, children: [.text("a"), elN("span", slot: 1)])),
            (comp(0, children: [elN("span", slot: 10)]), comp(0, children: [elN("span", slot: 10), elN("em", slot: 11)])),
            (elN("div", slot: 0), elN("span", slot: 0)),   // tag change → replace
        ]
        for c in cases {
            let (applier1, backend1) = makeApplier()
            let m = applier1.mount(c.old, hostParent: backend1.container, before: nil)
            m.parent = applier1.root; m.indexInParent = 0; applier1.root.children = [m]
            applier1.apply(Reconciler().diff(old: c.old, new: c.new), to: m)

            let (applier2, backend2) = makeApplier()
            let m2 = applier2.mount(c.new, hostParent: backend2.container, before: nil)
            m2.parent = applier2.root; m2.indexInParent = 0; applier2.root.children = [m2]

            #expect(backend1.serializeHTML() == backend2.serializeHTML())
        }
    }
}
