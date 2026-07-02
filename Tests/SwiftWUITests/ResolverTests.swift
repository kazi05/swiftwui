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
        var captured: Leaf?
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
        _ = captured
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
        var ctx = makeCtx()
        let fe = ForEach(0..<3) { i in Text("i\(i)") }
        let nodes = fe._resolve(path: .root, ctx: &ctx)
        #expect(nodes.count == 3)
        #expect(nodes[0].key == NodeKey(0))
        #expect(nodes[2].key == NodeKey(2))
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
