import Testing
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import SwiftWUI
@testable import SwiftWUIStatic

struct ViewportMetricsSnapshotFixture: Tag {
    @State var metrics: VisualViewportMetrics? = nil
    @State var note = "preserved"
    var body: some Tag { Span { Text(note) } }
}

@Suite @MainActor struct ViewportMetricsHydrationTests {
    @Test func optionalMetricsAndSiblingStateRoundTripTogether() throws {
        let value = VisualViewportMetrics(width: 390, height: 500, offsetTop: 20,
            offsetLeft: 4, scale: 1.5, layoutViewportHeight: 844)
        for expected: VisualViewportMetrics? in [nil, value] {
            let server = MockBackend(); let scheduler = TestScheduler()
            let runtime = Runtime(backend: server, container: server.container,
                root: ViewportMetricsSnapshotFixture(metrics: expected), scheduleMicrotask: scheduler.schedule)
            runtime._effects._buildMode = true
            runtime.mount()
            let rows = runtime._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
            #expect(rows.count == 1)
            let row = try #require(rows.values.first)
            #expect(row.count == 2)
            let decoded = try JSONDecoder().decode([VisualViewportMetrics?].self, from: Data(row[0].utf8))
            #expect(decoded == [expected])
            #expect(row[1] == "[\"preserved\"]")
            let browser = MockBackend()
            parseHTMLSubset(server.serializeHTML(), into: browser)
            let adopting = AdoptingBackend(base: browser, container: browser.container)
            let client = Runtime(backend: adopting, container: browser.container,
                root: ViewportMetricsSnapshotFixture(), scheduleMicrotask: scheduler.schedule)
            client._store._pendingRows = rows
            client._store._decodeSlot = { json, type in
                func decode<T: Decodable>(_ type: T.Type) -> (any Decodable)? {
                    (try? JSONDecoder().decode([T].self, from: Data(json.utf8)))?.first
                }
                return _openExistential(type, do: decode)
            }
            client._deferViewportEffectsUntilAdoption()
            client.mount()
            #expect(adopting.finishAdoption())
            client._acceptViewportEffectsAdoption(); scheduler.pump()
            #expect(client._store._pendingRows.isEmpty)
            let restoredRows = client._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
            #expect(Set(restoredRows.keys) == Set(rows.keys))
            let restoredRow = try #require(restoredRows.values.first)
            #expect(restoredRow.count == 2)
            let restored = try JSONDecoder().decode([VisualViewportMetrics?].self,
                                                     from: Data(restoredRow[0].utf8))
            #expect(restored == [expected])
            #expect(restoredRow[1] == "[\"preserved\"]")
        }
    }
}

private struct ViewportSnapshotUpdateFixture: Tag {
    @State private var metrics: VisualViewportMetrics? = nil
    var body: some Tag {
        P { Text(String(metrics?.height ?? 0)) }.onVisualViewportChange { metrics = $0 }
    }
}

extension ViewportMetricsHydrationTests {
    @Test func sourceSnapshotChangesStateOnlyAfterSuccessfulAdoption() {
        let base = MockBackend(); let scheduler = TestScheduler()
        base.visualViewportSnapshot = .init(width: 360, height: 480, offsetTop: 4,
            offsetLeft: 0, scale: 1, layoutViewportHeight: 800)
        let server = Runtime(backend: base, container: base.container,
            root: ViewportSnapshotUpdateFixture(), scheduleMicrotask: scheduler.schedule)
        server._effects._buildMode = true
        server.mount(); scheduler.pump()
        #expect(base.serializeHTML() == "<p>0.0</p>")
        let adopting = AdoptingBackend(base: base, container: base.container)
        let client = Runtime(backend: adopting, container: base.container,
            root: ViewportSnapshotUpdateFixture(), scheduleMicrotask: scheduler.schedule)
        client._deferViewportEffectsUntilAdoption()
        client.mount(); scheduler.pump()
        #expect(base.serializeHTML() == "<p>0.0</p>")
        #expect(base.counts["beginVisualViewportObservation"] == nil)
        #expect(adopting.finishAdoption())
        client._acceptViewportEffectsAdoption(); scheduler.pump()
        #expect(base.serializeHTML() == "<p>480.0</p>")
        #expect(base.counts["beginVisualViewportObservation"] == 1)
    }
}
