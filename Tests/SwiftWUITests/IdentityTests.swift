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
