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
    @Test func mockBackendSerializesTextareaValueAsChildText() {
        let backend = MockBackend()
        let n = backend.createElement("textarea")
        backend.setProperty(n, name: "value", value: .string("a & <b>"))
        backend.insert(n, into: backend.container, before: nil)
        #expect(backend.serializeHTML() == "<textarea>a &amp; &lt;b&gt;</textarea>")
    }
    @Test func textLevelTagsRender() {
        #expect(HTMLRenderer.render(Aside { Text("x") }) == "<aside>x</aside>")
        #expect(HTMLRenderer.render(Blockquote(cite: "https://a.dev") { Text("q") })
                == "<blockquote cite=\"https://a.dev\">q</blockquote>")
        #expect(HTMLRenderer.render(Q(cite: "https://a.dev") { Text("q") })
                == "<q cite=\"https://a.dev\">q</q>")
        #expect(HTMLRenderer.render(Time(datetime: "2026-07-03") { Text("today") })
                == "<time datetime=\"2026-07-03\">today</time>")
        #expect(HTMLRenderer.render(Abbr(title: "HyperText") { Text("HT") })
                == "<abbr title=\"HyperText\">HT</abbr>")
        #expect(HTMLRenderer.render(Del(datetime: "2026-01-01") { Text("old") })
                == "<del datetime=\"2026-01-01\">old</del>")
        #expect(HTMLRenderer.render(Ins { Text("new") }) == "<ins>new</ins>")
        #expect(HTMLRenderer.render(Data(value: "42") { Text("answer") })
                == "<data value=\"42\">answer</data>")
        #expect(HTMLRenderer.render(Div { Wbr() }) == "<div><wbr></div>")
        #expect(HTMLRenderer.render(Blockquote(cite: "javascript:alert(1)") { Text("q") })
                == "<blockquote cite=\"#\">q</blockquote>")  // sanitizeURL neuters rejected scheme to "#"
    }
    @Test func tableFamilyRenders() {
        let html = HTMLRenderer.render(
            Table {
                Thead { Tr { Th(scope: "col") { Text("N") } } }
                Tbody { Tr { Td(colspan: 2) { Text("1") } } }
            })
        #expect(html == "<table><thead><tr><th scope=\"col\">N</th></tr></thead>"
                      + "<tbody><tr><td colspan=\"2\">1</td></tr></tbody></table>")
    }
    @Test func selectOptionRender() {
        let html = HTMLRenderer.render(
            Select(name: "pet") {
                Option("Cat", value: "cat", selected: true)
                Option("Dog", value: "dog")
            })
        #expect(html == "<select name=\"pet\"><option selected value=\"cat\">Cat</option>"
                      + "<option value=\"dog\">Dog</option></select>")
    }
    @Test func voidSetCoversAllVoidTagStructs() {
        // Every _HTMLVoidTag's tagName must be in HTMLRenderer.voidElements —
        // a miss means serialized output grows a bogus closing tag (T8 break).
        let voidTagNames = [Input.tagName, Img.tagName, Br.tagName, Hr.tagName,
                            Wbr.tagName, Col.tagName, Source.tagName, Track.tagName,
                            Embed.tagName, Param.tagName, Area.tagName]
        for name in voidTagNames { #expect(HTMLRenderer.voidElements.contains(name)) }
    }
    /// No production change (Tags+Table.swift already emits via `String(Double)`) —
    /// pins the format so a future refactor can't silently drop the ".0" (phase-6 item 5).
    @Test func progressAndMeterDoubleAttributes() {
        #expect(HTMLRenderer.render(Progress(value: 0.5, max: 2))
                == #"<progress max="2.0" value="0.5"></progress>"#)
        #expect(HTMLRenderer.render(Meter(value: 0.7, min: 0, max: 1))
                == #"<meter max="1.0" min="0.0" value="0.7"></meter>"#)
    }
    @Test func mediaAndInteractiveTagsRender() {
        #expect(HTMLRenderer.render(Details(open: true) { Summary { Text("t") }; P { Text("b") } })
                == "<details open><summary>t</summary><p>b</p></details>")
        #expect(HTMLRenderer.render(Video(src: "/v.mp4", controls: true) { Source(src: "/v.webm", type: "video/webm") })
                == "<video controls src=\"/v.mp4\"><source src=\"/v.webm\" type=\"video/webm\"></video>")
        #expect(HTMLRenderer.render(Noscript("Enable JS")) == "<noscript>Enable JS</noscript>")
        #expect(HTMLRenderer.render(Iframe(src: "https://x.dev", title: "demo"))
                == "<iframe src=\"https://x.dev\" title=\"demo\"></iframe>")
    }
    @Test func imgTypedAttributes() {
        let img = Img(src: "/hero.webp", alt: "Hero", width: 1200, height: 630,
                      srcset: "/hero.webp 1x, /hero@2x.webp 2x", sizes: "100vw",
                      loading: .lazy, decoding: .async)
        let html = HTMLRenderer.render(img)
        #expect(html.contains("width=\"1200\""))
        #expect(html.contains("height=\"630\""))
        #expect(html.contains("loading=\"lazy\""))
        #expect(html.contains("decoding=\"async\""))
        #expect(html.contains("srcset=\"/hero.webp 1x, /hero@2x.webp 2x\""))
        #expect(html.contains("sizes=\"100vw\""))
    }
    @Test func imgOmittedAttributesAbsent() {
        let html = HTMLRenderer.render(Img(src: "/a.png", alt: "a"))
        #expect(!html.contains("width="))
        #expect(!html.contains("height="))
        #expect(!html.contains("loading="))
        #expect(!html.contains("srcset="))
        #expect(!html.contains("sizes="))
        #expect(!html.contains("decoding="))
    }
    @Test func imgSrcsetSanitized() {
        let html = HTMLRenderer.render(Img(src: "/a.png", alt: "a", srcset: "javascript:x 1x"))
        #expect(html.contains("srcset=\"#\""))

        // A bad entry after a relative first entry must still collapse the
        // whole list — this is the list-level bypass the review found.
        let bypass = HTMLRenderer.render(Img(src: "/a.png", alt: "a", srcset: "/a.png 1x, javascript:evil() 2x"))
        #expect(bypass.contains("srcset=\"#\""))

        // A benign multi-entry list passes through unchanged.
        let benign = HTMLRenderer.render(Img(src: "/a.png", alt: "a", srcset: "/hero.webp 1x, https://cdn.example/hero@2x.webp 2x"))
        #expect(benign.contains("srcset=\"/hero.webp 1x, https://cdn.example/hero@2x.webp 2x\""))
    }
}
