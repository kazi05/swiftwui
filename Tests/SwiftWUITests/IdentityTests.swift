import Testing
@testable import SwiftWUI

@Suite struct IdentityTests {
    @Test func appendingBuildsPath() {
        let id = NodeIdentity.root.appending(.child(0)).appending(.branch(true))
        #expect(id.segments == [.child(0), .branch(true)])
    }
    @Test func prefixTest() {
        let parent = NodeIdentity.root.appending(.child(1))
        let child = parent.appending(.type(ObjectIdentifier(Int.self)))
        #expect(child.isSelfOrDescendant(of: parent))
        #expect(parent.isSelfOrDescendant(of: parent))
        #expect(!parent.isSelfOrDescendant(of: child))
        #expect(!NodeIdentity.root.appending(.child(2)).isSelfOrDescendant(of: parent))
    }
    @Test func distinctSegmentsDistinctIdentity() {
        #expect(NodeIdentity.root.appending(.branch(true)) != NodeIdentity.root.appending(.branch(false)))
        #expect(NodeIdentity.root.appending(.keyed(NodeKey("a"))) != NodeIdentity.root.appending(.keyed(NodeKey("b"))))
    }
    @Test func nodeKeyAccessor() {
        var n = Node.element(ElementNode(identity: .root, tag: "div", attributes: [:], listeners: [:], children: [], key: nil))
        n.key = NodeKey(7)
        #expect(n.key == NodeKey(7))
        var t = Node.text("x")
        t.key = NodeKey(1)          // no-op on text
        #expect(t.key == nil)
    }
}

private struct CanonFixture: Tag { var body: some Tag { Div { Text("x") } } }

@Test func canonicalStringGrammar() {
    _TypeNameRegistry.register(CanonFixture.self)
    let id = NodeIdentity.root
        .appending(.child(0))
        .appending(.type(ObjectIdentifier(CanonFixture.self)))
        .appending(.branch(true))
        .appending(.keyed(NodeKey("a/b%c")))
    #expect(id._canonicalString == "c0/t\(String(reflecting: CanonFixture.self))/b1/ka%2Fb%25c")
}
@Test func canonicalStringNilForUnregisteredType() {
    struct NeverResolved {}
    let id = NodeIdentity.root.appending(.type(ObjectIdentifier(NeverResolved.self)))
    #expect(id._canonicalString == nil)
}
// Distinct from CanonFixture (never registered manually) so this test actually
// exercises the Resolver's registration line rather than piggybacking on the
// grammar test's manual `_TypeNameRegistry.register` call above (review M2).
private struct ResolveOnlyFixture: Tag { var body: some Tag { Div { Text("x") } } }

@Test func resolveRegistersComponentTypeNames() {
    var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(), invalidate: { _ in })
    _ = resolve(ResolveOnlyFixture(), path: .root, ctx: &ctx)
    let id = NodeIdentity.root.appending(.type(ObjectIdentifier(ResolveOnlyFixture.self)))
    #expect(id._canonicalString?.hasPrefix("t") == true)
}

// Pins review C1: every `.type`-minting primitive wrapper (not just the
// Resolver's component boundary) must register its own type name, or a
// component nested under one is unrepresentable in the canonical snapshot.
private struct WrappedFixture: Tag { var body: some Tag { Div { Text("x") } } }

@Test func componentUnderWrapperIsFullyRegistered() {
    var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(), invalidate: { _ in })
    _ = resolve(WrappedFixture().task { }, path: .root, ctx: &ctx)
    #expect(!ctx.reachable.isEmpty)
    for id in ctx.reachable {
        #expect(id._canonicalString != nil)
    }
}
