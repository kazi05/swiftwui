import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

@Suite @MainActor struct BootDocumentTests {
    private func document() -> String {
        DocumentSerializer.render(.init(
            bodyHTML: "<main>hi</main>",
            css: ".a{color:red}",
            head: PageHead(title: "T", meta: []),
            importMapJSON: #"{"imports":{}}"#,
            wasmScriptPath: "/app/index.js",
            bootShell: BootShell(html: "<template data-swui-boot-ui><div>L</div></template>",
                                 css: ".boot{}\n" + BootCSS.text,
                                 delayMS: 300),
            bootConfig: BootConfig(wasmURL: "/app/App.wasm?v=a3f9c1e2",
                                   entryURL: "/app/index.js",
                                   sizeBytes: 9570733, delayMS: 300)))
    }

    /// Processing a modulepreload disallows every later import map in Firefox
    /// and pre-133 Chromium; the bundle's bare `@bjorn3/browser_wasi_shim`
    /// specifier resolves only through that map, so the wrong order means
    /// nothing boots at all.
    @Test func importMapPrecedesEveryModulepreload() throws {
        let html = document()
        let map = try #require(html.range(of: "<script type=\"importmap\">"))
        let firstPreload = try #require(html.range(of: "rel=\"modulepreload\""))
        #expect(map.lowerBound < firstPreload.lowerBound)
    }

    @Test func wasmPreloadComesAfterTheStylesheetAndIsLowPriority() throws {
        let html = document()
        let style = try #require(html.range(of: "<style data-swiftwui>"))
        let preload = try #require(html.range(of: "as=\"fetch\""))
        #expect(style.lowerBound < preload.lowerBound)
        #expect(html.contains("fetchpriority=\"low\""))
        #expect(html.contains("crossorigin"))
    }

    @Test func bootCSSShipsInItsOwnUnmanagedBlock() throws {
        let html = document()
        #expect(html.contains("<style data-swui-boot>"))
        // `data-swiftwui` on this block would get it adopted as the managed
        // stylesheet and overwritten on the first render pass.
        #expect(!html.contains("<style data-swui-boot data-swiftwui>"))
        #expect(html.contains("display:none!important"))
    }

    @Test func templateGoesAtTheEndOfBody() throws {
        let html = document()
        let main = try #require(html.range(of: "<main>hi</main>"))
        let template = try #require(html.range(of: "<template data-swui-boot-ui>"))
        #expect(main.upperBound <= template.lowerBound)
        #expect(html.hasSuffix("</body></html>"))
    }

    @Test func configTravelsAsEscapedDataAttributes() {
        let html = document()
        #expect(html.contains("data-swui-boot-config"))
        #expect(html.contains("data-wasm=\"/app/App.wasm?v=a3f9c1e2\""))
        #expect(html.contains("data-size=\"9570733\""))
        #expect(html.contains("data-delay=\"300\""))
    }

    @Test func noBootInputMeansNoBootOutput() {
        let html = DocumentSerializer.render(.init(bodyHTML: "<main>hi</main>",
                                                   wasmScriptPath: "/app/index.js"))
        #expect(!html.contains("data-swui-boot"))
        #expect(!html.contains("swiftwui-boot.js"))
    }

    /// The boot block is emitted even with no app stylesheet at all — without
    /// it the veil/placeholder rules are missing and both states show at once.
    @Test func bootCSSShipsWithoutAnAppStylesheet() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<main>hi</main>",
            bootShell: BootShell(html: "", css: "\n" + BootCSS.text, delayMS: 0)))
        #expect(html.contains("<style data-swui-boot>"))
        #expect(html.contains("[data-swui-boot-veil]{display:none!important}"))
    }

    /// `sizeBytes == nil` must omit the attribute entirely; the shim reads a
    /// missing `data-size` as "unknown" and shows indeterminate progress,
    /// where `data-size=""` or `"0"` would parse as a known zero.
    @Test func unknownSizeOmitsTheAttribute() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<main>hi</main>",
            bootConfig: BootConfig(wasmURL: "/app/App.wasm", entryURL: "/app/index.js",
                                   sizeBytes: nil, delayMS: 0)))
        #expect(html.contains("data-swui-boot-config"))
        #expect(!html.contains("data-size"))
    }

    /// A boot config replaces the legacy inline boot; keeping both would call
    /// `init()` twice and mount the app on top of itself.
    @Test func bootConfigReplacesTheLegacyInlineBoot() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<main>hi</main>",
            wasmScriptPath: "/app/index.js",
            bootConfig: BootConfig(wasmURL: "/app/App.wasm", entryURL: "/app/index.js",
                                   sizeBytes: 1, delayMS: 0)))
        #expect(!html.contains("await init();"))
        #expect(html.contains("src=\"/app/swiftwui-boot.js\""))
    }
}
