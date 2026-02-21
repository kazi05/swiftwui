import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML

@Suite("HTML Tag Tests")
struct HTMLTagTests {

    @Test("Div creates element node with correct tag name")
    func divTagName() {
        let div = Div { Text("Hello") }
        let nodes = div.toTagNodes()
        #expect(nodes.count == 1)
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "div")
        }
    }

    @Test("Div with class attribute")
    func divWithClass() {
        let div = Div(class: "container") { Text("Content") }
        let nodes = div.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.classes.contains("container"))
        }
    }

    @Test("Div with id attribute")
    func divWithId() {
        let div = Div(id: "main") { Text("Content") }
        let nodes = div.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.attributes["id"] == "main")
        }
    }

    @Test("H1 creates correct element")
    func h1Tag() {
        let h1 = H1 { "Title" }
        let nodes = h1.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "h1")
            #expect(element.children.count == 1)
        }
    }

    @Test("Button with onclick")
    func buttonWithOnclick() {
        let button = Button(onclick: { }) { "Click me" }
        let nodes = button.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "button")
            #expect(element.attributes["type"] == "button")
        }
        #expect(button.eventListeners["click"] != nil)
    }

    @Test("Input is self-closing (no children)")
    func inputSelfClosing() {
        let input = Input(type: .email, placeholder: "Enter email")
        let nodes = input.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "input")
            #expect(element.attributes["type"] == "email")
            #expect(element.attributes["placeholder"] == "Enter email")
            #expect(element.children.isEmpty)
        }
    }

    @Test("Anchor with href")
    func anchorTag() {
        let a = A(href: "https://example.com") { "Link" }
        let nodes = a.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "a")
            #expect(element.attributes["href"] == "https://example.com")
        }
    }

    @Test("Image with src and alt")
    func imageTag() {
        let img = Img(src: "photo.png", alt: "Photo")
        let nodes = img.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "img")
            #expect(element.attributes["src"] == "photo.png")
            #expect(element.attributes["alt"] == "Photo")
            #expect(element.children.isEmpty)
        }
    }

    @Test("P creates paragraph element")
    func paragraphTag() {
        let p = P { "Hello world" }
        let nodes = p.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "p")
        }
    }

    @Test("Nested tags")
    func nestedTags() {
        let div = Div(class: "wrapper") {
            H1 { "Title" }
            P { "Content" }
        }
        let nodes = div.toTagNodes()
        if case .element(let element) = nodes[0] {
            #expect(element.tagName == "div")
            #expect(element.children.count >= 1)
        }
    }
}

@Suite("Semantic Tag Tests")
struct SemanticTagTests {

    @Test("Header tag")
    func headerTag() {
        let header = Header { Text("Header") }
        let nodes = header.toTagNodes()
        if case .element(let el) = nodes[0] {
            #expect(el.tagName == "header")
        }
    }

    @Test("Nav tag")
    func navTag() {
        let nav = Nav { Text("Nav") }
        let nodes = nav.toTagNodes()
        if case .element(let el) = nodes[0] {
            #expect(el.tagName == "nav")
        }
    }

    @Test("Footer tag")
    func footerTag() {
        let footer = Footer { Text("Footer") }
        let nodes = footer.toTagNodes()
        if case .element(let el) = nodes[0] {
            #expect(el.tagName == "footer")
        }
    }
}
