import Testing
@testable import SwiftWUI

private struct Fixture: Tag {
    @State var count = 0
    @State var name = "a"
    var body: some Tag { Text("x") }
}

@Suite @MainActor struct StateStoreTests {
    let id = NodeIdentity.root.appending(.type(ObjectIdentifier(Fixture.self)))

    @Test func firstLinkRegistersFreshBoxes_secondLinkGrafts() {
        let store = StateStore()
        let first = Fixture()
        store.link(first, at: id, invalidate: {})
        first.count = 7                                   // mutate persisted state
        let second = Fixture()                            // fresh struct, fresh throwaway boxes
        store.link(second, at: id, invalidate: {})
        #expect(second.count == 7)                        // grafted
        #expect(second.name == "a")
    }
    @Test func distinctIdentitiesDistinctState() {
        let store = StateStore()
        let otherID = NodeIdentity.root.appending(.child(1)).appending(.type(ObjectIdentifier(Fixture.self)))
        let a = Fixture(); let b = Fixture()
        store.link(a, at: id, invalidate: {})
        store.link(b, at: otherID, invalidate: {})
        a.count = 5
        #expect(b.count == 0)
    }
    @Test func sweepDropsUnreachableRows() {
        let store = StateStore()
        store.link(Fixture(), at: id, invalidate: {})
        #expect(store.rowCount == 1)
        store.sweep(under: .root, reachable: [])
        #expect(store.rowCount == 0)
        let again = Fixture()
        store.link(again, at: id, invalidate: {})         // remount = fresh state
        #expect(again.count == 0)
    }
    @Test func sweepRespectsPrefixScope() {
        let store = StateStore()
        let outside = NodeIdentity.root.appending(.child(9)).appending(.type(ObjectIdentifier(Fixture.self)))
        store.link(Fixture(), at: id, invalidate: {})
        store.link(Fixture(), at: outside, invalidate: {})
        store.sweep(under: NodeIdentity.root.appending(.child(9)), reachable: [])
        #expect(store.rowCount == 1)                      // only the scoped row died
    }
    @Test func invalidateReboundEachLink() {
        let store = StateStore()
        var hits: [String] = []
        let f1 = Fixture()
        store.link(f1, at: id, invalidate: { hits.append("first") })
        let f2 = Fixture()
        store.link(f2, at: id, invalidate: { hits.append("second") })
        f2.count = 1
        #expect(hits == ["second"])                       // old binding replaced
    }
}
