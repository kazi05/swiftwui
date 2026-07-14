import Testing
@testable import SwiftWUI

@Suite @MainActor struct MediaBackendSeamTests {
    @Test func mockRecordsAndFires() {
        let backend = MockBackend()
        backend.mediaMatches["(max-width: 600px)"] = true
        var last: Bool? = nil
        let initial = backend.observeMediaQuery("(max-width: 600px)") { last = $0 }
        #expect(initial == true)
        #expect(last == nil)                              // no change yet
        backend.simulateMediaChange("(max-width: 600px)", matches: false)
        #expect(last == false)
    }
    @Test func defaultSeamReturnsFalse() {
        // A backend that doesn't override the seam yields the SSR default.
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        #expect(adopting.observeMediaQuery("(min-width: 9999px)") { _ in } == false)
    }
}

@Suite @MainActor struct MediaMatchStoreTests {
    @Test func dedupsRegistrationPerCondition() {
        var registered: [String] = []
        var sinks: [String: (Bool) -> Void] = [:]
        let store = MediaMatchStore(observe: { cond, cb in
            registered.append(cond); sinks[cond] = cb; return false
        })
        #expect(store.matches("(max-width: 600px)") == false)
        #expect(store.matches("(max-width: 600px)") == false)   // second read, no re-register
        #expect(registered == ["(max-width: 600px)"])
        // a listener flip surfaces on the next read
        sinks["(max-width: 600px)"]?(true)
        #expect(store.matches("(max-width: 600px)") == true)
    }
    @Test func proxyDefaultsFalseWithoutStore() {
        #expect(MediaProxy(store: nil).matches(.maxWidth(.px(600))) == false)
        #expect(EnvironmentValues().media.matches(.maxWidth(.px(600))) == false)
    }
    @Test @MainActor func adoptingBackendForwardsMediaObservation() {
        let base = MockBackend()
        base.mediaMatches["(min-width: 700px)"] = true
        let adopting = AdoptingBackend(base: base, container: base.container)
        #expect(adopting.observeMediaQuery("(min-width: 700px)") { _ in } == true)   // forwarded to base, not default false
        #expect(base.mediaObservers["(min-width: 700px)"] != nil)                     // registered on base
    }
}

@MainActor private final class RC { var n = 0 }

private struct Responsive_Nav: Tag {
    let counter: RC
    @Environment(\.media) var media
    var body: some Tag {
        counter.n += 1
        return media.matches(.maxWidth(.px(600))) ? Div { Text("mobile") } : Div { Text("desktop") }
    }
}

@Suite @MainActor struct MediaMatchReactiveTests {
    private final class Sched {
        var q: [() -> Void] = []
        func schedule(_ f: @escaping () -> Void) { q.append(f) }
        func drain() { while !q.isEmpty { q.removeFirst()() } }
    }

    @Test func branchSwapsOnMediaFlipWithoutSpuriousRender() {
        let backend = MockBackend(); let sched = Sched()
        let counter = RC()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Responsive_Nav(counter: counter), scheduleMicrotask: sched.schedule)
        rt.mount(); sched.drain()
        // SSR/initial default is false → desktop branch, exactly one body eval.
        #expect(backend.serializeHTML().contains("desktop"))
        #expect(counter.n == 1)                              // no mutation-during-eval re-render

        backend.simulateMediaChange("(max-width: 600px)", matches: true)
        sched.drain()
        #expect(backend.serializeHTML().contains("mobile"))
        #expect(counter.n == 2)
        _ = rt   // keep alive — store closure captures [weak backend]
    }
}
