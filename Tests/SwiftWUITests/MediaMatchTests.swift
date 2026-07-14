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
