import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("ChapterFooter")
struct ChapterFooterTests {
    @Test func rendersBothLinks() {
        let html = StaticRenderer().renderFragment(
            ChapterFooter(prev: ("Previous", "/learn/p"), next: ("Next", "/learn/n"))
        )
        #expect(html.contains("Previous"))
        #expect(html.contains("Next"))
        #expect(html.contains("/learn/p"))
        #expect(html.contains("/learn/n"))
        #expect(html.contains("data-swui-chapter-footer"))
    }

    @Test func handlesNilPrev() {
        let html = StaticRenderer().renderFragment(
            ChapterFooter(prev: nil, next: ("State & Bindings", "/learn/state"))
        )
        #expect(html.contains("State"))
        #expect(html.contains("/learn/state"))
        #expect(!html.contains("/learn/p"))   // no leftover from previous test
    }
}
