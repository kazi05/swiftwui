import Testing
@testable import SwiftWUI

private struct Card: Tag {
    var body: some Tag {
        Div(class: "card") {
            H1("Title")
            P { "Body text" }
        }
    }
}

@Suite @MainActor struct HTMLRendererTests {
    @Test func componentIsTransparent() {
        #expect(HTMLRenderer.render(Card())
            == #"<div class="card"><h1>Title</h1><p>Body text</p></div>"#)
    }
    @Test func attributesSortedDeterministically() {
        let div = Div(id: "b", class: "a") {}
        #expect(HTMLRenderer.render(div) == #"<div class="a" id="b"></div>"#)
    }
    @Test func booleanAttributeBareName() {
        let b = Button("x", disabled: true, onClick: {})
        #expect(HTMLRenderer.render(b) == #"<button disabled type="button">x</button>"#)
    }
    @Test func voidElementNoClosingTag() {
        #expect(HTMLRenderer.render(Input(type: .text, placeholder: "hi"))
            == #"<input placeholder="hi" type="text">"#)
    }
    @Test func textAndAttributeEscaping() {
        let div = Div { Text(#"<script>alert("x")</script>"#) }
        let html = HTMLRenderer.render(div)
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
        let attr = Div(class: #"" onmouseover="evil()"#) {}
        #expect(!HTMLRenderer.render(attr).contains(#"" onmouseover=""#))
    }
    @Test func adjacentTextCoalesced() {
        let div = Div { "a"; "b" }
        #expect(HTMLRenderer.render(div) == "<div>ab</div>")
    }
    @Test func conditionalRenders() {
        struct Cond: Tag {
            let flag: Bool
            var body: some Tag { Div { if flag { P { "yes" } } } }
        }
        #expect(HTMLRenderer.render(Cond(flag: true)) == "<div><p>yes</p></div>")
        #expect(HTMLRenderer.render(Cond(flag: false)) == "<div></div>")
    }
}
