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
    ///
    /// The positive anchor is load-bearing: `serialize` returns `html: ""` for
    /// every non-`.page` outcome, which would turn all five negations into
    /// vacuous passes. Tasks 6, 7 and 12 edit exactly the code deciding whether
    /// a document is produced at all, so the guard proves the document exists
    /// before asserting what is not in it.
    @Test func documentCarriesNoBootMarkupByDefault() async throws {
        let modes: [StaticSiteMode] = [.hydrate(wasmScriptPath: "/app/index.js"), .staticOnly]
        for mode in modes {
            let page = try await StaticSite.render(PlainApp.self, path: "/",
                                                   config: .init(outDir: "/tmp/unused", mode: mode))
            #expect(page.outcome == .page, "expected a rendered page in \(mode) mode")
            #expect(page.html.contains("<p>Body copy</p>"), "body missing in \(mode) mode")
            for marker in ["data-swui-boot", "swiftwui-boot.js", "data-swui-boot-ui",
                           "data-swui-boot-veil", "swui-boot-progress"] {
                #expect(!page.html.contains(marker),
                        "unexpected boot marker '\(marker)' in default \(mode) output")
            }
        }
    }
}
