import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("ChapterPickerPopover")
struct ChapterPickerPopoverTests {
    @Test("Lists 12 chapters grouped in 3 sections")
    func listsAll() {
        let html = StaticRenderer().renderFragment(ChapterPickerPopover(active: "hello"))
        #expect(html.contains("Essentials"))
        #expect(html.contains("Building UI"))
        #expect(html.contains("Production"))
        for c in ChapterRegistry.all {
            // Check path rather than title: titles with "&" are HTML-escaped
            // to "&amp;" in the output, making a literal title match fail.
            #expect(html.contains(c.path), "missing chapter: \(c.title)")
        }
    }

    @Test("Marks the active chapter")
    func marksActive() {
        let html = StaticRenderer().renderFragment(ChapterPickerPopover(active: "state"))
        #expect(html.contains("data-active=\"state\""))
    }
}
