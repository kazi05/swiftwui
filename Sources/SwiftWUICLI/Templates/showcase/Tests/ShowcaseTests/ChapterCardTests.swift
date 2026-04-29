import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("ChapterCard")
struct ChapterCardTests {
    @Test func rendersNumberTitleSubtitleTeaserHref() {
        let html = StaticRenderer().renderFragment(
            ChapterCard(
                number: 2,
                title: "State & Bindings",
                subtitle: "Reactive data with @State.",
                codeTeaser: "@State var count = 0",
                href: "/learn/state"
            )
        )
        #expect(html.contains("CHAPTER 2"))
        #expect(html.contains("State"))                // Title (entity-encoded amp acceptable)
        #expect(html.contains("@State var count"))
        #expect(html.contains("href=\"/learn/state\""))
        #expect(html.contains("Reactive data with"))
    }
}
