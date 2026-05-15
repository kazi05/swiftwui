import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("HelloPage")
struct HelloPageTests {
    @Test func rendersFourStepsAndChapterChrome() {
        let html = StaticRenderer().renderFragment(HelloPage())
        #expect(html.contains("Hello, SwiftWUI"))
        #expect(html.contains("Chapter 1"))
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("Application(page:") || html.contains("Application {"))
        #expect(html.contains("data-swui-topbar"))   // SiteChrome's TutorialTopBar
        #expect(html.contains("data-swui-chapter-footer"))
    }
}
