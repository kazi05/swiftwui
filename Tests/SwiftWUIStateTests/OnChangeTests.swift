import Testing
@testable import SwiftWUICore
@testable import SwiftWUIState

@Suite("onChange Modifier")
struct OnChangeTests {
    @Test("onChange wraps content transparently")
    func onChangeWrapsContent() {
        let text = Text("Hello")
        let modified = text.onChange(of: 0) { _, _ in }
        let nodes = resolveTagBody(modified)
        #expect(nodes.count == 1)
        if case .text(let content) = nodes.first {
            #expect(content == "Hello")
        } else {
            Issue.record("Expected text node passed through")
        }
    }

    @Test("onChange is available on any Tag")
    func onChangeAvailableOnAnyTag() {
        let text = Text("Test")
        let _ = text.onChange(of: "value") { _, _ in }
        // Compiles = passes
    }
}
