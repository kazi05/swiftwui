import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct Plain: Tag {
    // P has no string-shorthand init (only headings and Button do), hence Text.
    var body: some Tag { Div(class: "wrap") { H1("Hello"); P { Text("Body copy") } } }
}
private struct PlainPage: Page {
    var title: String { "Hello" }
    var body: some Tag { Plain() }
}
private struct PlainApp: App {
    var body: some Tag {
        Router { Route("/") { PlainPage() } }
    }
}

@Suite @MainActor struct BootOptInGoldenTests {
    /// With no `bootUI` declared anywhere, a rendered document must contain no
    /// trace of the boot layer. This is the whole opt-in guarantee; it is
    /// asserted on substrings rather than a full golden so later tasks can add
    /// unrelated head content without churning it.
    @Test func documentCarriesNoBootMarkupByDefault() async throws {
        let page = try await StaticSite.render(PlainApp.self, path: "/",
                                               config: .init(outDir: "/tmp/unused",
                                                             mode: .hydrate(wasmScriptPath: "/app/index.js")))
        for marker in ["data-swui-boot", "swiftwui-boot.js", "data-swui-boot-ui",
                       "data-swui-boot-veil", "swui-boot-progress"] {
            #expect(!page.html.contains(marker), "unexpected boot marker '\(marker)' in default output")
        }
    }
}
