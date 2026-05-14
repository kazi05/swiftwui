import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("SiteChrome")
struct SiteChromeTests {
    @Test func rendersNavbarFooterAndContent() {
        struct Stub: SwiftWUI.Tag { var body: some SwiftWUI.Tag { Text("inner-body-marker") } }
        let html = StaticRenderer().renderFragment(SiteChrome { Stub() })
        #expect(html.contains("data-swui-topbar"))   // TutorialTopBar replaced navbar
        #expect(html.contains("data-swui-footer"))
        #expect(html.contains("Develop in Swift"))   // TutorialTopBar wordmark
        #expect(html.contains("inner-body-marker"))
    }

    @Test func toggleButtonHasAriaLabel() {
        struct Stub: SwiftWUI.Tag { var body: some SwiftWUI.Tag { Text("x") } }
        let html = StaticRenderer().renderFragment(SiteChrome { Stub() })
        #expect(html.contains("aria-label="))
    }
}
