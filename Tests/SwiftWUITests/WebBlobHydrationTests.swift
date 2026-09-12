import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

// Internal names are stable across the native/WASM binaries used for hydration.
struct BlobHydrationPreview: Tag {
    @State var preview: WebObjectURL? = nil
    @State var blob: WebBlob? = nil
    @State var status = "No attachment"
    var body: some Tag { Span { Text(status) } }
}

struct BlobHydrationComposer: Tag {
    @State var draft = "Initial draft"
    var body: some Tag {
        Div {
            P { Text(draft) }
            Button("Edit") { draft = "Restored draft" }
            BlobHydrationPreview()
        }
    }
}

@Suite @MainActor struct WebBlobHydrationTests {
    // A fake Codable conformance on the resources, or moving transient state
    // into the parent's row, would change the snapshot and break restoration.
    @Test func transientChildDoesNotDiscardSerializableParentDuringHydration() throws {
        let server = MockBackend()
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: server, container: server.container,
                              root: BlobHydrationComposer(),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        clickFirst(server, runtime, tag: "button", sched: scheduler)
        let rows = runtime._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
        #expect(rows.count == 1)
        #expect(Array(rows.values) == [["[\"Restored draft\"]"]])
        #expect(rows.keys.allSatisfy { !$0.contains("BlobHydrationPreview") })

        let browser = MockBackend()
        parseHTMLSubset(server.serializeHTML(), into: browser)
        let adopting = AdoptingBackend(base: browser, container: browser.container)
        let client = Runtime(backend: adopting, container: browser.container,
                             root: BlobHydrationComposer(), scheduleMicrotask: { _ in })
        client._store._pendingRows = rows
        client._store._decodeSlot = { json, type in
            func decode<T: Decodable>(_ type: T.Type) -> (any Decodable)? {
                (try? JSONDecoder().decode([T].self, from: Foundation.Data(json.utf8)))?.first
            }
            return _openExistential(type, do: decode)
        }
        client.mount()
        #expect(adopting.finishAdoption())
        #expect(browser.counts["createElement"] == nil)
        #expect(browser.serializeHTML().contains("Restored draft"))
        #expect(browser.serializeHTML().contains("No attachment"))
        #expect(client._store._pendingRows.isEmpty)
    }
}
