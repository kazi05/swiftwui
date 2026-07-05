import Testing
import SwiftWUI
@testable import SwiftWUIStatic

@Suite @MainActor struct DocumentSerializerTests {
    @Test func staticModeGolden() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<h1>Hi</h1>",
            css: ".a{color:red}",
            head: PageHead(title: "T & Co", meta: [.description("d")])))
        #expect(html == """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>T &amp; Co</title>
        <meta content="d" name="description" data-swiftwui>
        <style data-swiftwui>
        .a{color:red}
        </style>
        </head>
        <body><h1>Hi</h1></body>
        </html>

        """)
        #expect(!html.contains("importmap"))   // static mode: no wasm bundle, no import map
    }
    @Test func hydrateModeIncludesSnapshotAndBootScript() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<div></div>",
            snapshotJSON: "{\"v\":1}",
            importMapJSON: #"{"imports":{"@bjorn3/browser_wasi_shim":"/vendor/wasi-shim/index.js"}}"#,
            wasmScriptPath: "/app.js"))
        #expect(html.contains("<script type=\"application/swiftwui-state\" data-swiftwui>{\"v\":1}</script>"))
        #expect(html.contains(#"<script type="importmap">{"imports":{"@bjorn3/browser_wasi_shim":"/vendor/wasi-shim/index.js"}}</script>"#))
        #expect(html.contains("<script type=\"module\" src=\"/app.js\"></script>"))
        let headEnd = html.range(of: "</head>")!.lowerBound
        #expect(html[..<headEnd].contains("<script type=\"module\""))   // boot script lives in head, not body
        let mapRange = html.range(of: "<script type=\"importmap\">")!
        let moduleRange = html.range(of: "<script type=\"module\"")!
        #expect(mapRange.lowerBound < moduleRange.lowerBound)   // import map must precede the module script
    }
    @Test func bodyContainsExactlyTheFragmentForAdoption() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<div class=\"x\">a</div>",
            snapshotJSON: "{\"v\":1}", wasmScriptPath: "/app.js"))
        #expect(html.contains("<body><div class=\"x\">a</div></body>"))   // no whitespace/script inside body
        let headEnd = html.range(of: "</head>")!.lowerBound
        #expect(html[..<headEnd].contains("<script type=\"module\""))     // boot script lives in head
    }
    @Test func explicitViewportSuppressesDefault() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "",
            head: PageHead(title: "t", meta: [.viewport("width=500")])))
        #expect(html.contains("content=\"width=500\""))
        #expect(!html.contains("initial-scale=1"))
    }
    @Test func snapshotSlotEscapesScriptBreakout() {
        // A string state value containing "</script>" must not break out (D7).
        let slot = SnapshotJSON.encodeSlot("</script><script>alert(1)</script>")
        #expect(slot != nil)
        #expect(!slot!.contains("</script"))               // JSONEncoder's \/ escaping
        let doc = SnapshotJSON.assemble(version: 1, path: "/x",
                                        rows: ["c0/tA.B": [slot!]], tasks: ["c0/tA.B"])
        #expect(!doc.contains("</script"))
        #expect(doc.contains("\"v\":1"))
    }
    @Test func doubleEscapedScriptStateCannotDesyncDocument() {
        let slot = SnapshotJSON.encodeSlot("<!--<script")!
        let doc = DocumentSerializer.render(.init(
            bodyHTML: "<div>after</div>",
            snapshotJSON: SnapshotJSON.assemble(version: 1, path: "/x",
                                                rows: ["k": [slot]], tasks: [])))
        #expect(!doc.contains("<!--<script"))          // raw sequence never ships
        #expect(doc.contains("<div>after</div>"))      // body survives
    }
    @Test func assembleIsDeterministic() {
        let a = SnapshotJSON.assemble(version: 1, path: "/", rows: ["b": ["[1]"], "a": ["[2]"]], tasks: ["z", "y"])
        #expect(a == "{\"v\":1,\"path\":\"\\/\",\"rows\":{\"a\":[[2]],\"b\":[[1]]},\"tasks\":[\"y\",\"z\"]}")
    }
}
