import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("StepNavButtons")
struct StepNavButtonsTests {
    @Test("Renders two buttons with prev/next labels")
    func renders() {
        let html = StaticRenderer().renderFragment(StepNavButtons(total: 4, current: 2))
        #expect(html.contains("← Prev step") || html.contains("&larr; Prev step"))
        #expect(html.contains("Next step →") || html.contains("Next step &rarr;"))
    }

    @Test("Shows current/total chip")
    func chip() {
        let html = StaticRenderer().renderFragment(StepNavButtons(total: 5, current: 3))
        #expect(html.contains("Step 3 / 5"))
    }
}
