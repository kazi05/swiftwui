import Foundation   // test target only — hooks live here, not in the core
import Testing
@testable import SwiftWUI

private struct Fixture: Tag {
    @State var count = 0
    @State var name = "a"
    var body: some Tag { Text("x") }
}

private let jsonEncode: SnapshotEncode = { v in
    struct AnyEncodable: Encodable {                 // slot convention: single-element array
        let base: any Encodable
        func encode(to encoder: Encoder) throws { try base.encode(to: encoder) }
    }
    guard let data = try? JSONEncoder().encode([AnyEncodable(base: v)]) else { return nil }
    return String(decoding: data, as: UTF8.self)
}
private let jsonDecode: SnapshotDecode = { json, type in
    func open<T: Decodable>(_ t: T.Type) -> (any Decodable)? {
        (try? JSONDecoder().decode([T].self, from: Data(json.utf8)))?.first
    }
    return _openExistential(type, do: open)
}

private struct SnapFixture: Tag {
    @State var count = 0
    @State var label = "initial"
    var body: some Tag { Div { Text("\(label):\(count)") } }
}

private struct OptionalSnapFixture: Tag {
    @State var filter: String? = nil
    @State var page = 0
    var body: some Tag { Div { Text("\(filter ?? "none"):\(page)") } }
}

@Suite @MainActor struct StateStoreTests {
    let id = NodeIdentity.root.appending(.type(ObjectIdentifier(Fixture.self)))

    @Test func firstLinkRegistersFreshBoxes_secondLinkGrafts() {
        let store = StateStore()
        let first = Fixture()
        store.link(first, at: id, environment: EnvironmentValues(), invalidate: {})
        first.count = 7                                   // mutate persisted state
        let second = Fixture()                            // fresh struct, fresh throwaway boxes
        store.link(second, at: id, environment: EnvironmentValues(), invalidate: {})
        #expect(second.count == 7)                        // grafted
        #expect(second.name == "a")
    }
    @Test func distinctIdentitiesDistinctState() {
        let store = StateStore()
        let otherID = NodeIdentity.root.appending(.child(1)).appending(.type(ObjectIdentifier(Fixture.self)))
        let a = Fixture(); let b = Fixture()
        store.link(a, at: id, environment: EnvironmentValues(), invalidate: {})
        store.link(b, at: otherID, environment: EnvironmentValues(), invalidate: {})
        a.count = 5
        #expect(b.count == 0)
    }
    @Test func sweepDropsUnreachableRows() {
        let store = StateStore()
        store.link(Fixture(), at: id, environment: EnvironmentValues(), invalidate: {})
        #expect(store.rowCount == 1)
        store.sweep(under: .root, reachable: [])
        #expect(store.rowCount == 0)
        let again = Fixture()
        store.link(again, at: id, environment: EnvironmentValues(), invalidate: {})         // remount = fresh state
        #expect(again.count == 0)
    }
    @Test func sweepRespectsPrefixScope() {
        let store = StateStore()
        let outside = NodeIdentity.root.appending(.child(9)).appending(.type(ObjectIdentifier(Fixture.self)))
        store.link(Fixture(), at: id, environment: EnvironmentValues(), invalidate: {})
        store.link(Fixture(), at: outside, environment: EnvironmentValues(), invalidate: {})
        store.sweep(under: NodeIdentity.root.appending(.child(9)), reachable: [])
        #expect(store.rowCount == 1)                      // only the scoped row died
    }
    @Test func invalidateReboundEachLink() {
        let store = StateStore()
        var hits: [String] = []
        let f1 = Fixture()
        store.link(f1, at: id, environment: EnvironmentValues(), invalidate: { hits.append("first") })
        let f2 = Fixture()
        store.link(f2, at: id, environment: EnvironmentValues(), invalidate: { hits.append("second") })
        f2.count = 1
        #expect(hits == ["second"])                       // old binding replaced
    }

    @Test func snapshotRoundTripRestoresState() {
        // 1. Mutate state via a live runtime, encode.
        let backend = MockBackend()
        let sched = TestScheduler()
        let r1 = Runtime(backend: backend, container: backend.container,
                         root: SnapFixture(), scheduleMicrotask: sched.schedule)
        r1.mount()
        // Reach in through the store: mutate by clicking is overkill — use the
        // encode of the INITIAL row, then hand-edit the fragment to prove decode wins.
        let rows = r1._store._encodeSnapshotRows(jsonEncode)
        #expect(rows.count == 1)
        let key = rows.keys.first!
        #expect(rows[key] == ["[0]", "[\"initial\"]"])

        // 2. Boot a second runtime seeded with edited values.
        let backend2 = MockBackend()
        let store2Runtime = Runtime(backend: backend2, container: backend2.container,
                                    root: SnapFixture(), scheduleMicrotask: { _ in })
        store2Runtime._store._pendingRows = [key: ["[42]", "[\"restored\"]"]]
        store2Runtime._store._decodeSlot = jsonDecode
        store2Runtime.mount()
        #expect(backend2.serializeHTML().contains("restored:42"))
    }

    @Test func snapshotSlotCountMismatchFallsBackToInitial() {
        // Key discovery: mount a probe, take its encoded row key.
        let backendP = MockBackend()
        let probe = Runtime(backend: backendP, container: backendP.container,
                            root: SnapFixture(), scheduleMicrotask: { _ in })
        probe.mount()
        let key = probe._store._encodeSnapshotRows(jsonEncode).keys.first!

        let backend2 = MockBackend()
        let r = Runtime(backend: backend2, container: backend2.container,
                        root: SnapFixture(), scheduleMicrotask: { _ in })
        r._store._pendingRows = [key: ["[42]"]]                  // 1 slot, fixture has 2
        r._store._decodeSlot = jsonDecode
        r.mount()
        #expect(backend2.serializeHTML().contains("initial:0"))  // fell back
        #expect(r._store._pendingRows.isEmpty)                   // consumed even on failure
    }

    @Test func nilOptionalSlotEncodesAsNullAndRestoresSiblings() {
        let backendP = MockBackend()
        let probe = Runtime(backend: backendP, container: backendP.container,
                            root: OptionalSnapFixture(), scheduleMicrotask: { _ in })
        probe.mount()
        let rows = probe._store._encodeSnapshotRows(jsonEncode)
        #expect(rows.count == 1)                                 // row NOT dropped
        let key = rows.keys.first!
        #expect(rows[key] == ["[null]", "[0]"])                  // nil → JSON null; Mirror order

        let backend2 = MockBackend()
        let r = Runtime(backend: backend2, container: backend2.container,
                        root: OptionalSnapFixture(), scheduleMicrotask: { _ in })
        r._store._pendingRows = [key: ["[\"done\"]", "[7]"]]
        r._store._decodeSlot = jsonDecode
        r.mount()
        #expect(backend2.serializeHTML().contains("done:7"))
    }

    @Test func nonEncodableSlotDropsWholeRow() {
        final class Opaque {}                                     // not Encodable
        struct MixedFixture: Tag {
            @State var n = 1
            @State var o = Opaque()
            var body: some Tag { Div { Text("\(n)") } }
        }
        let backend = MockBackend()
        let r = Runtime(backend: backend, container: backend.container,
                        root: MixedFixture(), scheduleMicrotask: { _ in })
        r.mount()
        #expect(r._store._encodeSnapshotRows(jsonEncode).isEmpty)   // whole row dropped
    }
}
