import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("Hero")
struct HeroTests {
    @Test func rendersAllSlots() {
        let html = StaticRenderer().renderFragment(
            Hero(
                eyebrow: "Build with SwiftWUI",
                headline: "Real Swift. Right in the browser.",
                subhead: "A declarative web framework that compiles to WebAssembly.",
                primaryCTA: ("Get started", "/learn/hello"),
                ghostCTA: ("View on GitHub", "https://github.com/AkhtarGadique/SwiftWUI"),
                code: "struct Counter: Tag {}"
            )
        )
        #expect(html.contains("Build with SwiftWUI"))
        #expect(html.contains("Real Swift"))
        #expect(html.contains("Get started"))
        #expect(html.contains("View on GitHub"))
        #expect(html.contains("struct Counter"))
        #expect(html.contains("data-swui-hero"))
        #expect(html.contains("data-swui-codeframe"))
    }
}
