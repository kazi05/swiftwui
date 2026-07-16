import Testing
@testable import SwiftWUI

private final class Recorder {
    var renders = 0
}
private struct OverlayFixture: Tag {
    let cap: Recorder
    @Environment(\.dragSession) private var session
    var body: some Tag {
        cap.renders += 1
        return Div(class: session.isActive ? "overlay-on" : "overlay-off") {
            P { session.hasFiles ? "files" : "none" }
        }
    }
}

@Suite @MainActor struct DragSessionEnvironmentTests {
    @Test func defaultIsNone() {
        #expect(DragSessionInfo.none.isActive == false)
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: OverlayFixture(cap: Recorder()), scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        #expect(findFirst(backend.container, tag: "div")!.attrs["class"] == "overlay-off")
    }
    @Test func writerFlipsAndRerenders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: OverlayFixture(cap: Recorder()), scheduleMicrotask: sched.schedule)
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
        let cap = Recorder()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: OverlayFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        let info = DragSessionInfo(isActive: true, hasFiles: false, types: ["text/plain"])
        backend.environmentWriter?.setDragSession(info)
        sched.pump()
        let renders = cap.renders
        backend.environmentWriter?.setDragSession(info)   // bubbling child enter
        sched.pump()
        #expect(cap.renders == renders)   // equal value → guard suppresses body re-evaluation
        // sanity: a genuinely different value DOES re-evaluate body (counter has teeth)
        backend.environmentWriter?.setDragSession(.none)
        sched.pump()
        #expect(cap.renders == renders + 1)
    }
}
