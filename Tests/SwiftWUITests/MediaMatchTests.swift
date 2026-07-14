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
}
