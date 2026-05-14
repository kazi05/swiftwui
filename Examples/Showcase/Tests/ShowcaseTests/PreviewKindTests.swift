import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("PreviewKind")
struct PreviewKindTests {
    @Test("Live kind preserves an AnyTag")
    func live() {
        let kind = PreviewKind.live(AnyTag(Text("x")))
        switch kind {
        case .live(let tag):
            #expect(StaticRenderer().renderFragment(tag).contains("x"))
        case .screenshot:
            Issue.record("expected .live")
        }
    }

    @Test("Screenshot kind preserves the path")
    func screenshot() {
        let kind = PreviewKind.screenshot("hello-step-1.png")
        switch kind {
        case .screenshot(let path):
            #expect(path == "hello-step-1.png")
        case .live:
            Issue.record("expected .screenshot")
        }
    }
}
