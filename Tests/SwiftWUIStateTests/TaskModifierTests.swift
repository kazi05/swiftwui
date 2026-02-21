import Testing
@testable import SwiftWUICore
@testable import SwiftWUIState

@Suite("Task Modifier")
struct TaskModifierTests {
    @Test("task wraps content transparently for text nodes")
    func taskWrapsTextContent() {
        let text = Text("Hello")
        let modified = text.task { }
        let nodes = resolveTagBody(modified)
        #expect(nodes.count == 1)
        // Text nodes don't have observers (no element), so it just passes through
        if case .text(let content) = nodes.first {
            #expect(content == "Hello")
        }
    }
}
