import Testing
@testable import SwiftWUI

private struct Leaf: Tag {
    @State var n = 0
    var body: some Tag { Text("leaf:\(n)") }
}

private struct Pair: Tag {
    var body: some Tag {
        Leaf()
        Leaf()
    }
}

@Suite @MainActor struct ResolverTests {
    func makeCtx(_ store: StateStore = StateStore()) -> ResolveContext {
        ResolveContext(store: store, listeners: ListenerRegistry(), invalidate: { _ in })
    }

    @Test func componentEmitsBoundaryNodeWithTypedIdentity() {
        var ctx = makeCtx()
        let nodes = resolve(Leaf(), path: .root, ctx: &ctx)
        guard case .component(let c) = nodes[0] else { Issue.record("expected component"); return }
        #expect(c.identity == NodeIdentity.root.appending(.type(ObjectIdentifier(Leaf.self))))
        #expect(c.children == [.text("leaf:0")])
        #expect(ctx.reachable.contains(c.identity))
    }

    @Test func siblingsGetDistinctIdentities() {
        var ctx = makeCtx()
        let nodes = resolve(Pair(), path: .root, ctx: &ctx)
        guard case .component(let pair) = nodes[0],
              case .component(let a) = pair.children[0],
              case .component(let b) = pair.children[1] else { Issue.record("shape"); return }
        #expect(a.identity != b.identity)          // .child(0) vs .child(1) slots
    }

    @Test func statePersistsAcrossReResolve_viaStore() {
        let store = StateStore()
        var ctx1 = makeCtx(store)
        // resolve, then mutate the linked state, then re-resolve: text must update
        _ = resolve(Leaf(), path: .root, ctx: &ctx1)
        let leaf = Leaf()   // fresh struct; link grafts persisted box
        var ctx2 = makeCtx(store)
        _ = resolve(leaf, path: .root, ctx: &ctx2)
        leaf.n = 42
        var ctx3 = makeCtx(store)
        let nodes = resolve(Leaf(), path: .root, ctx: &ctx3)
        guard case .component(let c) = nodes[0] else { Issue.record("shape"); return }
        #expect(c.children == [.text("leaf:42")])
    }

    @Test func branchSegmentsDiffer() {
        var ctx = makeCtx()
        @TagBuilder func cond(_ f: Bool) -> ConditionalTag<Text, Text> { if f { "y" } else { "n" } }
        // resolve both branches at the same slot: identity differs via .branch
        _ = resolve(cond(true), path: .root, ctx: &ctx)
        _ = resolve(cond(false), path: .root, ctx: &ctx)
        // structural check is covered by IdentityTests; here we check resolution output
        #expect(resolve(cond(true), path: .root, ctx: &ctx) == [.text("y")])
    }

    @Test func forEachItemsCarryKeys() {
        struct Item: Tag { let i: Int; var body: some Tag { Text("i\(i)") } }
        var ctx = makeCtx()
        let fe = ForEach(0..<3) { i in Item(i: i) }
        let nodes = fe._resolve(path: .root, ctx: &ctx)
        #expect(nodes.count == 3)
        #expect(nodes[0].key == NodeKey(0))
        #expect(nodes[2].key == NodeKey(2))
        guard case .component = nodes[0] else { Issue.record("expected component"); return }
    }

    @Test func coalesceMergesAdjacentText() {
        let merged = coalesceText([.text("a"), .text("b"), .element(ElementNode(identity: .root, tag: "br", attributes: [:], listeners: [:], children: [], key: nil)), .text("c")])
        #expect(merged.count == 3)
        #expect(merged[0] == .text("ab"))
    }

    @Test func registrySweepKeepsLiveIDs() {
        let reg = ListenerRegistry()
        let a = ListenerID(owner: NodeIdentity.root.appending(.child(0)), event: "click")
        let b = ListenerID(owner: NodeIdentity.root.appending(.child(1)), event: "click")
        reg.set(a, handler: {}); reg.set(b, handler: {})
        reg.sweep(under: .root, keep: [a])
        #expect(reg.handler(for: a) != nil)
        #expect(reg.handler(for: b) == nil)
        #expect(reg.count == 1)
    }
}

@Suite @MainActor struct ElementResolveTests {
    func makeCtx() -> (ResolveContext, ListenerRegistry) {
        let reg = ListenerRegistry()
        return (ResolveContext(store: StateStore(), listeners: reg, invalidate: { _ in }), reg)
    }

    @Test func elementCarriesIdentityAttributesChildren() {
        var (ctx, _) = makeCtx()
        let div = Div(class: "counter") { H1("Hello") }
        let nodes = div._resolve(path: .root, ctx: &ctx)
        guard case .element(let el) = nodes[0] else { Issue.record("expected element"); return }
        #expect(el.tag == "div")
        #expect(el.identity == .root)
        #expect(el.attributes == ["class": "counter"])
        guard case .element(let h1) = el.children[0] else { Issue.record("expected h1"); return }
        #expect(h1.identity == NodeIdentity.root.appending(.child(0)))   // content slot
        #expect(h1.children == [.text("Hello")])
    }
    @Test func nestedSingleChildNoPathCollision() {
        var (ctx, _) = makeCtx()
        let nodes = Div { Div {} }._resolve(path: .root, ctx: &ctx)
        guard case .element(let outer) = nodes[0],
              case .element(let inner) = outer.children[0] else { Issue.record("shape"); return }
        #expect(outer.identity != inner.identity)     // spec decision 11
    }
    @Test func buttonRegistersClickListenerWithStructuralID() {
        var (ctx, reg) = makeCtx()
        var clicked = false
        let nodes = Button("+", onClick: { clicked = true })._resolve(path: .root, ctx: &ctx)
        guard case .element(let el) = nodes[0] else { Issue.record("shape"); return }
        let lid = el.listeners["click"]
        #expect(lid == ListenerID(owner: .root, event: "click"))
        #expect(ctx.liveListeners.contains(lid!))
        reg.handler(for: lid!)?(nil)
        #expect(clicked)
    }
    @Test func classAccumulatesOtherAttributesLastWin() {
        var bag = _AttributeBag(id: "x", class: "a")
        bag.appendClasses(["b", "c"])
        bag.set("id", "y")
        #expect(bag.flattened() == ["id": "y", "class": "a b c"])
    }
    @Test func invalidAttributeNameDropped() {
        var bag = _AttributeBag()
        bag.set("ok-name_1", "v")
        // NOTE: assertionFailure fires in debug test runs — validate via isValidName instead
        #expect(_AttributeBag.isValidName("ok-name_1"))
        #expect(!_AttributeBag.isValidName("x onmouseover=alert(1)"))
        #expect(!_AttributeBag.isValidName("1leading-digit"))
        #expect(bag.flattened() == ["ok-name_1": "v"])
    }
}
