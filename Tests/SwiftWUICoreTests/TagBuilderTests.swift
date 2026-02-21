import Testing
@testable import SwiftWUICore

@Suite("Tag Protocol Tests")
struct TagProtocolTests {

    @Test("EmptyTag creates empty node list")
    func emptyTag() {
        let tag = EmptyTag()
        let nodes = tag.toTagNodes()
        #expect(nodes.isEmpty)
    }

    @Test("Text creates text node")
    func textNode() {
        let text = Text("Hello")
        let nodes = text.toTagNodes()
        #expect(nodes.count == 1)
        if case .text(let content) = nodes[0] {
            #expect(content == "Hello")
        } else {
            Issue.record("Expected text node")
        }
    }

    @Test("Text supports string interpolation")
    func textInterpolation() {
        let count = 42
        let text = Text("Count: \(count)")
        let nodes = text.toTagNodes()
        if case .text(let content) = nodes[0] {
            #expect(content == "Count: 42")
        }
    }
}

@Suite("TagBuilder Tests")
struct TagBuilderTests {

    @Test("TagBuilder with single tag")
    func singleTag() {
        @TagBuilder
        var content: some SwiftWUICore.Tag {
            Text("Hello")
        }
        let nodes = resolveTagBody(content)
        #expect(nodes.count == 1)
    }

    @Test("TagBuilder with multiple tags")
    func multipleTags() {
        @TagBuilder
        var content: some SwiftWUICore.Tag {
            Text("First")
            Text("Second")
            Text("Third")
        }
        let nodes = resolveTagBody(content)
        #expect(nodes.count == 3)
    }

    @Test("TagBuilder with string literals")
    func stringLiterals() {
        @TagBuilder
        var content: some SwiftWUICore.Tag {
            "Hello"
            "World"
        }
        let nodes = resolveTagBody(content)
        #expect(nodes.count == 2)
        if case .text(let first) = nodes[0] {
            #expect(first == "Hello")
        }
    }

    @Test("TagBuilder with empty block")
    func emptyBlock() {
        @TagBuilder
        var content: some SwiftWUICore.Tag {
            EmptyTag()
        }
        let nodes = resolveTagBody(content)
        #expect(nodes.isEmpty)
    }
}

@Suite("AnyTag Tests")
struct AnyTagTests {

    @Test("AnyTag wraps text")
    func wrapText() {
        let any = AnyTag(Text("Wrapped"))
        let nodes = resolveTagBody(any)
        #expect(nodes.count == 1)
        if case .text(let content) = nodes[0] {
            #expect(content == "Wrapped")
        }
    }
}

@Suite("TagNode Tests")
struct TagNodeTests {

    @Test("TagNode element equality")
    func elementEquality() {
        let a = TagNode.element(.init(tagName: "div", children: [.text("Hi")]))
        let b = TagNode.element(.init(tagName: "div", children: [.text("Hi")]))
        #expect(a == b)
    }

    @Test("TagNode text equality")
    func textEquality() {
        #expect(TagNode.text("Hello") == TagNode.text("Hello"))
        #expect(TagNode.text("Hello") != TagNode.text("World"))
    }
}

@Suite("ModifiedContent Tests")
struct ModifiedContentTests {

    @Test("Style modifier adds style")
    func styleModifier() {
        let text = Text("Hello")
        let modified = text.style("color", "red")
        #expect(modified.styles.contains { $0.0 == "color" && $0.1 == "red" })
    }

    @Test("Class modifier adds class")
    func classModifier() {
        let text = Text("Hello")
        let modified = text.class("highlight")
        #expect(modified.classes == ["highlight"])
    }

    @Test("Chaining modifiers")
    func chainingModifiers() {
        let text = Text("Hello")
        let modified = text
            .style("color", "red")
            .style("font-size", "16px")
            .class("bold")
        #expect(modified.styles.count == 2)
        #expect(modified.classes == ["bold"])
    }
}
