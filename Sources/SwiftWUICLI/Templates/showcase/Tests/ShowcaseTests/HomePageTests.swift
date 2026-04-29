import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("HomePage")
struct HomePageTests {
    @Test func rendersHeroAndAllChapterCards() {
        let html = StaticRenderer().renderFragment(HomePage())
        #expect(html.contains("data-swui-hero"))
        #expect(html.contains("CHAPTER 1"))
        #expect(html.contains("CHAPTER 12"))
        #expect(html.contains("Container Queries"))
        #expect(html.contains("data-swui-navbar"))
        #expect(html.contains("data-swui-footer"))
    }

    @Test func rendersAllThreeParts() {
        let html = StaticRenderer().renderFragment(HomePage())
        #expect(html.contains("Part 1"))
        #expect(html.contains("Part 2"))
        #expect(html.contains("Part 3"))
    }
}
