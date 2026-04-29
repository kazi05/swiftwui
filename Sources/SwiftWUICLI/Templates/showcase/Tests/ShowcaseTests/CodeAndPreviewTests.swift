import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("CodeAndPreview")
struct CodeAndPreviewTests {
    @Test func rendersStepNumberTitleProseCode() {
        let html = StaticRenderer().renderFragment(
            CodeAndPreview(
                stepNumber: 1,
                title: "Add reactive storage",
                prose: "Mark a property @State.",
                code: "@State var count = 0",
                preview: AnyTag(Div { Text("preview-marker") }),
                showInlinePreview: false
            )
        )
        #expect(html.contains("STEP 1"))
        #expect(html.contains("Add reactive storage"))
        #expect(html.contains("@State var count"))
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("Mark a property"))
        #expect(!html.contains("preview-marker"))   // showInlinePreview=false hides the preview
    }

    @Test func showsPreviewOnMobileWhenRequested() {
        let html = StaticRenderer().renderFragment(
            CodeAndPreview(
                stepNumber: 2,
                title: "T2", prose: "P2", code: "code2",
                preview: AnyTag(Div { Text("MOBILE-PREVIEW-CANARY") }),
                showInlinePreview: true
            )
        )
        #expect(html.contains("MOBILE-PREVIEW-CANARY"))
        #expect(html.contains("data-mobile-preview"))
    }
}
