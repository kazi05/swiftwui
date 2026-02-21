import Testing
@testable import SwiftWUICore
@testable import SwiftWUIStyles
@testable import SwiftWUIHTML

@Suite("ModifiedContent Responsive Styles")
struct ModifiedContentResponsiveTests {

    @Test("ModifiedContent can store responsiveStyles")
    func storesResponsiveStyles() {
        let text = Text("Hello")
        let mc = ModifiedContent(
            content: text,
            styles: [("color", "red")],
            responsiveStyles: [("@media (max-width: 767px)", [("font-size", "16px")])]
        )
        #expect(mc.responsiveStyles.count == 1)
        #expect(mc.responsiveStyles[0].0 == "@media (max-width: 767px)")
        #expect(mc.responsiveStyles[0].1.count == 1)
        #expect(mc.responsiveStyles[0].1[0].0 == "font-size")
        #expect(mc.responsiveStyles[0].1[0].1 == "16px")
    }

    @Test("ModifiedContent defaults responsiveStyles to empty")
    func defaultsEmpty() {
        let text = Text("Hello")
        let mc = ModifiedContent(content: text, styles: [("color", "red")])
        #expect(mc.responsiveStyles.isEmpty)
    }
}

@Suite("TagNode Responsive Styles")
struct TagNodeResponsiveTests {

    @Test("Element stores responsiveStyles")
    func elementStoresResponsiveStyles() {
        let el = TagNode.Element(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "16px"]]
        )
        #expect(el.responsiveStyles.count == 1)
        #expect(el.responsiveStyles["@media (max-width: 767px)"] == ["font-size": "16px"])
    }

    @Test("Element defaults responsiveStyles to empty")
    func defaultsEmpty() {
        let el = TagNode.Element(tagName: "div")
        #expect(el.responsiveStyles.isEmpty)
    }

    @Test("Elements with different responsiveStyles are not equal")
    func equalityDiffers() {
        let a = TagNode.Element(tagName: "div", responsiveStyles: ["@media (max-width: 767px)": ["color": "red"]])
        let b = TagNode.Element(tagName: "div", responsiveStyles: [:])
        #expect(a != b)
    }
}

@Suite("Responsive Style Merging")
struct ResponsiveStyleMergingTests {

    @Test("responsiveStyles merge into TagNode element")
    func mergesResponsiveStyles() {
        let div = Div { Text("Hello") }
        let mc = ModifiedContent(
            content: div,
            responsiveStyles: [("@media (max-width: 767px)", [("font-size", "16px")])]
        )
        let nodes = mc.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.responsiveStyles["@media (max-width: 767px)"] == ["font-size": "16px"])
    }

    @Test("multiple responsiveStyles for same query merge")
    func mergesMultipleForSameQuery() {
        let div = Div { Text("Hello") }
        let mc = ModifiedContent(
            content: div,
            responsiveStyles: [
                ("@media (max-width: 767px)", [("font-size", "16px")]),
                ("@media (max-width: 767px)", [("padding", "8px")]),
            ]
        )
        let nodes = mc.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let responsive = el.responsiveStyles["@media (max-width: 767px)"]!
        #expect(responsive["font-size"] == "16px")
        #expect(responsive["padding"] == "8px")
    }

    @Test("responsiveStyles for different queries stay separate")
    func separateQueries() {
        let div = Div { Text("Hello") }
        let mc = ModifiedContent(
            content: div,
            responsiveStyles: [
                ("@media (max-width: 767px)", [("font-size", "16px")]),
                ("@media (min-width: 1024px)", [("font-size", "32px")]),
            ]
        )
        let nodes = mc.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.responsiveStyles.count == 2)
        #expect(el.responsiveStyles["@media (max-width: 767px)"] == ["font-size": "16px"])
        #expect(el.responsiveStyles["@media (min-width: 1024px)"] == ["font-size": "32px"])
    }
}
