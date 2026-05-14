import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("TutorialTopBar")
struct TutorialTopBarTests {
    @Test("Renders 'Develop in Swift' wordmark with accent on 'Tutorials'")
    func wordmark() {
        let html = StaticRenderer().renderFragment(
            TutorialTopBar(currentChapter: "hello",
                           stepTitles: ["a", "b"],
                           currentStep: 1)
        )
        #expect(html.contains("Develop in Swift"))
        #expect(html.contains("Tutorials"))
        #expect(html.contains("var(--swui-accent)"))    // accent color used somewhere on the wordmark
    }

    @Test("Shows N of M pagination chip")
    func pagination() {
        let html = StaticRenderer().renderFragment(
            TutorialTopBar(currentChapter: "hello",
                           stepTitles: ["a", "b", "c", "d"],
                           currentStep: 3)
        )
        #expect(html.contains("3 of 4"))
    }

    @Test("Mounts theme toggle")
    func themeToggle() {
        let html = StaticRenderer().renderFragment(
            TutorialTopBar(currentChapter: "hello",
                           stepTitles: ["a"],
                           currentStep: 1)
        )
        #expect(html.contains("data-swui-theme-toggle"))
    }
}
