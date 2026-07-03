import Testing
@testable import SwiftWUI

private struct LProbe: Tag {
    @Environment(\.routeInfo) var info
    var body: some Tag {
        Div {
            P { "at:\(info.path)" }
            Link("/inside") { Span { "in" } }
            Link("https://example.com") { Span { "out" } }
            Link("/tab", target: .blank) { Span { "tab" } }
        }
    }
}

@MainActor @Suite struct LinkTests {
    private func make() -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: LProbe(), scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func externalDetection() {
        #expect(Link<Text>.isExternal("https://x.y"))
        #expect(Link<Text>.isExternal("mailto:a@b.c"))
        #expect(Link<Text>.isExternal("//cdn.x/lib.js"))
        #expect(!Link<Text>.isExternal("/inside"))
        #expect(!Link<Text>.isExternal("/q?x=1"))
        #expect(!Link<Text>.isExternal("relative/path"))
        #expect(!Link<Text>.isExternal("justtext"))
    }
    @Test func internalLinkNavigatesOnPlainClick() {
        let (rt, backend, sched) = make()
        let anchors = findAll(backend.container, tag: "a")
        rt.dispatch(anchors[0].events["click"]!, payload: ClickEvent())
        sched.pump()
        #expect(backend.serializeHTML().contains("at:/inside"))
        #expect(backend.historyStack == ["/inside"])
    }
    @Test func modifiedClickIsNotIntercepted() {
        let (rt, backend, sched) = make()
        let anchors = findAll(backend.container, tag: "a")
        rt.dispatch(anchors[0].events["click"]!, payload: ClickEvent(metaKey: true))
        rt.dispatch(anchors[0].events["click"]!, payload: ClickEvent(button: 1))
        sched.pump()
        #expect(backend.historyStack.isEmpty)
        #expect(backend.serializeHTML().contains("at:/"))
    }
    @Test func nilPayloadCountsAsPlainClick() {
        let (rt, backend, sched) = make()
        let anchors = findAll(backend.container, tag: "a")
        rt.dispatch(anchors[0].events["click"]!)
        sched.pump()
        #expect(backend.historyStack == ["/inside"])
    }
    @Test func externalAndTargetLinksGetNoListenerNoMarker() {
        let (_, backend, _) = make()
        let anchors = findAll(backend.container, tag: "a")
        #expect(anchors.count == 3)
        #expect(anchors[0].attrs["data-swui-link"] == "")
        for a in anchors[1...] {
            #expect(a.events["click"] == nil)
            #expect(a.attrs["data-swui-link"] == nil)
        }
        #expect(anchors[2].attrs["target"] == "_blank")
    }
}
