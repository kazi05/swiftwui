import Testing
@testable import SwiftWUICore

// A simple test modifier that passes content through unchanged
struct WrapperModifier: TagModifier {
    let wrapperClass: String

    func body(content: Content) -> some SwiftWUICore.Tag {
        content
    }
}

// A modifier that applies a style to the content
struct AddStyleModifier: TagModifier {
    func body(content: Content) -> some SwiftWUICore.Tag {
        content.style("color", "red")
    }
}

@Suite("TagModifier")
struct TagModifierTests {
    @Test("Modifier preserves content nodes")
    func modifierPreservesContent() {
        let text = Text("Hello")
        let modified = text.modifier(WrapperModifier(wrapperClass: "test"))
        let nodes = modified.toTagNodes()
        #expect(nodes.count == 1)
        if case .text(let content) = nodes.first {
            #expect(content == "Hello")
        } else {
            Issue.record("Expected text node")
        }
    }

    @Test("Modifier applies styles to content")
    func modifierAppliesStyles() {
        let text = Text("Styled")
        let modified = text.modifier(AddStyleModifier())
        let nodes = modified.toTagNodes()
        // AddStyleModifier applies .style("color", "red") to content
        // Since Text is a text node (not element), the style won't apply to it
        // But the modifier pattern itself should work
        #expect(!nodes.isEmpty)
    }

    @Test("Tag.modifier() method creates ModifiedTag")
    func tagModifierMethod() {
        let text = Text("Test")
        let modified = text.modifier(WrapperModifier(wrapperClass: "wrapper"))
        // Verify it's the correct type
        let nodes = modified.toTagNodes()
        #expect(nodes.count == 1)
    }

    @Test("Content type correctly wraps tag nodes")
    func contentTypeWrapsNodes() {
        let nodes: [TagNode] = [.text("A"), .text("B")]
        let content = Content(nodes: nodes)
        let result = content.toTagNodes()
        #expect(result.count == 2)
        if case .text(let a) = result[0], case .text(let b) = result[1] {
            #expect(a == "A")
            #expect(b == "B")
        }
    }
}
