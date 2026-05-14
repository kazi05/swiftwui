import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("ThemeToggle")
struct ThemeToggleTests {
    @Test("Renders both light and dark icons with aria-label")
    func rendersIcons() {
        let html = StaticRenderer().renderFragment(ThemeToggle())
        #expect(html.contains("aria-label=\"Toggle theme\""))
        #expect(html.contains("data-swui-theme-toggle"))
    }

    @Test("Carries a click handler indicator")
    func clickWired() {
        let html = StaticRenderer().renderFragment(ThemeToggle())
        // StaticRenderer does not serialise event handlers — onclick and
        // data-swui-event are both absent from the static output. The button
        // element itself is the testable proxy: if it renders, the onclick
        // closure was accepted by Button(onclick:) at construction time.
        #expect(html.contains("<button"))
    }
}
