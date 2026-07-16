import Testing
@testable import SwiftWUI

private struct OverlayFixture: Tag {
    @Environment(\.dragSession) private var session
    var body: some Tag {
        Div(class: session.isActive ? "overlay-on" : "overlay-off") {
            P { session.hasFiles ? "files" : "none" }
        }
    }
}

@Suite @MainActor struct DragSessionEnvironmentTests {
    @Test func defaultIsNone() {
        #expect(DragSessionInfo.none.isActive == false)
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: OverlayFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        #expect(findFirst(backend.container, tag: "div")!.attrs["class"] == "overlay-off")
    }
    @Test func writerFlipsAndRerenders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: OverlayFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        backend.environmentWriter?.setDragSession(
            DragSessionInfo(isActive: true, hasFiles: true, types: ["Files"]))
        sched.pump()
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.attrs["class"] == "overlay-on")
        backend.environmentWriter?.setDragSession(.none)
        sched.pump()
        #expect(div.attrs["class"] == "overlay-off")
    }
    @Test func equalWritesDoNotInvalidate() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: OverlayFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        let info = DragSessionInfo(isActive: true, hasFiles: false, types: ["text/plain"])
        backend.environmentWriter?.setDragSession(info)
        sched.pump()
        let renders = backend.counts["setAttribute", default: 0]
        backend.environmentWriter?.setDragSession(info)   // bubbling child enter
        sched.pump()
        #expect(backend.counts["setAttribute", default: 0] == renders)
    }
}
