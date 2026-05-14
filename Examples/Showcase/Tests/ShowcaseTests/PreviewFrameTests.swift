import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("PreviewFrame")
struct PreviewFrameTests {
    @Test("Renders three traffic-light dots and address bar")
    func chromeRendered() {
        let html = StaticRenderer().renderFragment(
            PreviewFrame(kind: .live(AnyTag(Text("ok"))), label: "localhost:8080")
        )
        #expect(html.contains("#ff5f57"))   // red dot
        #expect(html.contains("#ffbd2e"))   // yellow dot
        #expect(html.contains("#28c840"))   // green dot
        #expect(html.contains("localhost:8080"))
    }

    @Test("Live preview body renders the supplied tag")
    func liveTag() {
        let html = StaticRenderer().renderFragment(
            PreviewFrame(kind: .live(AnyTag(Text("INNER"))), label: "")
        )
        #expect(html.contains("INNER"))
    }

    @Test("Screenshot preview emits img with snapshots path")
    func screenshot() {
        let html = StaticRenderer().renderFragment(
            PreviewFrame(kind: .screenshot("hello-step-2.png"), label: "")
        )
        #expect(html.contains("src=\"/snapshots/hello-step-2.png\""))
        #expect(html.contains("alt="))
    }
}
