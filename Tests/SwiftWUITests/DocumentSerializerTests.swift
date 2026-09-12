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
        <body><h1>Hi</h1></body></html>
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
        #expect(html.contains(#"<script type="module">import { init } from "\/app.js"; await window.__swiftwui_interop_ready; await init();</script>"#))
        let headEnd = html.range(of: "</head>")!.lowerBound
        #expect(html[..<headEnd].contains("<script type=\"module\""))   // boot script lives in head, not body
        let mapRange = html.range(of: "<script type=\"importmap\">")!
        let moduleRange = html.range(of: "<script type=\"module\">import")!
        #expect(mapRange.lowerBound < moduleRange.lowerBound)   // import map must precede the module script
    }

    @Test func delayedBootDoesNotPreloadAndWaitsForInterop() {
        let config = BootConfig(wasmURL: "/app/App.wasm?v=abc", entryURL: "/app/index.js",
                                shimURL: "/app/swiftwui-boot.js", sizeBytes: 12, delayMS: 300,
                                activation: .visible, activationSelector: "#app")
        let html = DocumentSerializer.render(.init(bodyHTML: "<main id=\"app\"></main>",
                                                    bootConfig: config,
                                                    interopScriptURL: "/app/bridge.js"))
        #expect(html.contains("data-activation=\"visible\""))
        #expect(html.contains("data-activation-selector=\"#app\""))
        #expect(html.contains(#"Promise.race([import("\/app\/bridge.js")"#))
        #expect(!html.contains("rel=\"modulepreload\""))
        #expect(!html.contains("as=\"fetch\""))
    }

    @Test func legacyHydrationBoundsInteropReadiness() throws {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<main></main>",
            wasmScriptPath: "/app/index.js",
            interopScriptURL: "/interop/index.js"
        ))

        let readiness = try #require(html.range(of: "window.__swiftwui_interop_ready=Promise.race"))
        let hydration = try #require(html.range(of: "await window.__swiftwui_interop_ready; await init()"))
        #expect(readiness.lowerBound < hydration.lowerBound)
        #expect(html.contains("JavaScript interop initialization timed out"))
        #expect(html.contains("30000"))
        #expect(html.contains("finally(()=>clearTimeout(__swuiInteropTimer))"))
        #expect(html.contains("console.error('SwiftWUI interop failed:',error)"))
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
    @Test func rendersManagedLinks() {
        let head = PageHead(title: "T", meta: [], links: [
            .icon("/favicon.svg", type: "image/svg+xml"),
            .preload("/f.woff2", as: .font),
        ])
        let html = DocumentSerializer.render(.init(bodyHTML: "<p>x</p>", head: head))
        #expect(html.contains("<link as=\"font\" crossorigin=\"anonymous\" href=\"/f.woff2\" rel=\"preload\" data-swiftwui>"))
        #expect(html.contains("<link href=\"/favicon.svg\" rel=\"icon\" type=\"image/svg+xml\" data-swiftwui>"))
    }
    @Test func linkHrefIsSanitizedInDocument() {
        let head = PageHead(title: "T", meta: [], links: [.icon("javascript:alert(1)")])
        let html = DocumentSerializer.render(.init(bodyHTML: "", head: head))
        #expect(html.contains("href=\"#\""))
        #expect(!html.contains("javascript:"))
    }
    @Test func assembleIsDeterministic() {
        let a = SnapshotJSON.assemble(version: 1, path: "/", rows: ["b": ["[1]"], "a": ["[2]"]], tasks: ["z", "y"])
        #expect(a == "{\"v\":1,\"path\":\"\\/\",\"rows\":{\"a\":[[2]],\"b\":[[1]]},\"tasks\":[\"y\",\"z\"]}")
    }
    @Test func structuredDataIsEmittedThroughScriptJSON() {
        let payload = #"{"n":"</script><img src=x onerror=alert(1)>"}"#
        let head = PageHead(title: "t", meta: [], links: [], structuredData: [payload])
        let doc = DocumentSerializer.render(.init(bodyHTML: "<p>x</p>", head: head))
        #expect(doc.contains(#"<script type="application/ld+json" data-swiftwui>"#))
        #expect(!doc.contains("</script><img"))        // breakout neutralized
        // Strengthened over the brief's version (whose closing assertion was
        // `doc.contains(x) || doc.contains(x)` — the same check OR'd with
        // itself, always true regardless of escaping). Assert the breakout was
        // actually TRANSFORMED by scriptJSON, not merely absent for some
        // unrelated reason (e.g. the field being dropped).
        #expect(doc.contains(HTMLEscaping.scriptJSON(payload)))
    }
}
