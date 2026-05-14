import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("SectionPickerPopover")
struct SectionPickerPopoverTests {
    @Test("Renders the supplied step titles")
    func renders() {
        let steps = ["Conform a struct to Tag", "Compose with @TagBuilder", "Mount", "Style"]
        let html = StaticRenderer().renderFragment(
            SectionPickerPopover(chapter: "hello", stepTitles: steps, active: 2)
        )
        for title in steps {
            #expect(html.contains(title))
        }
    }

    @Test("Highlights active step")
    func active() {
        let html = StaticRenderer().renderFragment(
            SectionPickerPopover(chapter: "hello",
                                 stepTitles: ["a", "b", "c"], active: 2)
        )
        #expect(html.contains("data-active-step=\"2\""))
    }
}
