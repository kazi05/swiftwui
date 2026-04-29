import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRouter
@testable import SwiftWUIRuntime

private struct Hello: SwiftWUICore.Tag, SwiftWUICore.TagNodeConvertible {
    typealias Body = Never
    func toTagNodes() -> [TagNode] {
        [.element(TagNode.Element(tagName: "h1", children: [.text("Hello SSR")]))]
    }
}

@Suite("SSR document assembly")
struct SSRTests {
    @Test("renderHTMLDocument emits a full HTML document with title")
    func emitsTitle() {
        let app = Application { Route("/") { Hello() } }
        let html = app.renderHTMLDocument(SSRDocumentOptions(title: "My App"))
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<title>My App</title>"))
        #expect(html.contains("<div id=\"app\">"))
    }

    @Test("renderHTMLDocument inlines the rendered route body")
    func includesBody() {
        let app = Application { Route("/") { Hello() } }
        let html = app.renderHTMLDocument(SSRDocumentOptions(title: "x"))
        #expect(html.contains("<h1"))
        #expect(html.contains("Hello SSR"))
    }

    @Test("renderHTMLDocument injects theme CSS when provided")
    func includesThemeCSS() {
        let app = Application { Route("/") { Hello() } }
        let html = app.renderHTMLDocument(SSRDocumentOptions(
            title: "x",
            themeCSS: ":root { --bg: #fff; }"
        ))
        #expect(html.contains(":root { --bg: #fff; }"))
        #expect(html.contains("<style>"))
    }

    @Test("renderHTMLDocument adds the WASM bootstrap script when wasmJSURL is set")
    func bootstrapScript() {
        let app = Application { Route("/") { Hello() } }
        let html = app.renderHTMLDocument(SSRDocumentOptions(
            title: "x",
            wasmJSURL: "/Counter.js"
        ))
        #expect(html.contains("import { init } from \"/Counter.js\""))
        #expect(html.contains("init();"))
    }

    @Test("renderHTMLDocument escapes special characters in the title")
    func escapesTitle() {
        let app = Application { Route("/") { Hello() } }
        let html = app.renderHTMLDocument(SSRDocumentOptions(title: "<dangerous> & \"unsafe\""))
        #expect(html.contains("&lt;dangerous&gt; &amp; &quot;unsafe&quot;"))
        // Make sure raw `<dangerous>` did NOT leak.
        #expect(!html.contains("<dangerous>"))
    }

    @Test("renderHTMLDocument embeds initialState JSON when present")
    func includesInitialState() {
        let app = Application { Route("/") { Hello() } }
        let html = app.renderHTMLDocument(SSRDocumentOptions(
            title: "x",
            initialState: "{\"count\":42}"
        ))
        #expect(html.contains("id=\"__swiftwui_state\""))
        #expect(html.contains("{\"count\":42}"))
    }
}
