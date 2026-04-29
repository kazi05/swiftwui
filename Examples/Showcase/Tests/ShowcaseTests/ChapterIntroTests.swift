import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("ChapterIntro")
struct ChapterIntroTests {
    @Test func rendersAllSlots() {
        let html = StaticRenderer().renderFragment(
            ChapterIntro(
                part: "Chapter 1 — Essentials",
                title: "Hello, SwiftWUI",
                lead: "Build your first declarative view.",
                meta: [("Estimated time", "5 min"), ("Difficulty", "Beginner")]
            )
        )
        #expect(html.contains("Chapter 1"))
        #expect(html.contains("Hello, SwiftWUI"))
        #expect(html.contains("Build your first"))
        #expect(html.contains("Estimated time"))
        #expect(html.contains("5 min"))
        #expect(html.contains("data-swui-chapter-intro"))
    }
}
