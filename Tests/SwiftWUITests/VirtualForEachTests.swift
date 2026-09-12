import Testing
@testable import SwiftWUI

private struct VirtualItem: Identifiable {
    let id: Int
}

@Suite @MainActor struct VirtualForEachTests {
    private func makeRuntime()
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let list = VirtualForEach((0..<100).map(VirtualItem.init),
                                  rowHeight: 10, viewportHeight: 30,
                                  overscan: 1, initialItemCount: 8,
                                  accessibilityLabel: "Results") { item in
            Span { Text("row-\(item.id)") }
        }
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: list, scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        return (runtime, backend, scheduler)
    }

    @Test func initialFallbackRendersConfiguredLeadingRows() {
        let (_, backend, _) = makeRuntime()
        let html = backend.serializeHTML()

        #expect(html.contains("row-0"))
        #expect(html.contains("row-7"))
        #expect(!html.contains("row-8"))
        #expect(html.contains("aria-label=\"Results\""))
    }

    @Test func scrollKeepsOnlyVisibleRowsAndOverscanWithStableKeys() {
        let (runtime, backend, scheduler) = makeRuntime()
        let scrollport = findFirst(backend.container, tag: "div")!

        runtime.dispatch(scrollport.events["scroll"]!, payload: ScrollEvent(x: 0, y: 50))
        scheduler.pump()

        let html = backend.serializeHTML()
        #expect(!html.contains("row-0"))
        #expect(html.contains("row-4"))
        #expect(html.contains("row-8"))
        #expect(!html.contains("row-9"))
        #expect(findAll(backend.container, tag: "span").count == 5)
    }

    @Test func completeModeKeepsEveryRowForSmallAccessibleCollections() {
        let html = HTMLRenderer.render(
            VirtualForEach((0..<12).map(VirtualItem.init),
                           rowHeight: 10, viewportHeight: 30,
                           mode: .complete) { item in
                Span { Text("row-\(item.id)") }
            }
        )

        #expect(html.contains("row-0"))
        #expect(html.contains("row-11"))
    }
}
