import Testing
@testable import SwiftWUI

private struct TaskCard: DragPayload, Equatable { let id: Int }

private final class Recorder { var dragged: [Bool] = [] }
private struct SourceFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div(class: "card").draggable(TaskCard(id: 3)) { cap.dragged.append($0) }
    }
}

@Suite @MainActor struct DraggableModifierTests {
    @Test func attributesSerialized() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: SourceFixture(cap: Recorder()),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        let html = backend.serializeHTML()
        #expect(html.contains("draggable=\"true\""))
        #expect(html.contains("data-swui-drag-type=\"application/x-swiftwui.taskcard\""))
        #expect(html.contains("data-swui-drag=\"{&quot;id&quot;:3}\""))
    }
    @Test func isDraggedLifecycle() {
        let cap = Recorder()
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: SourceFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["dragstart"]!, payload: DragEvent())
        rt.dispatch(div.events["dragend"]!, payload: DragEvent())
        sched.pump()
        #expect(cap.dragged == [true, false])
    }
    @Test func dragstartListenerAlwaysPresent() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Div().draggable("plain text"),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.events["dragstart"] != nil)
        #expect(div.attrs["data-swui-drag-type"] == "text/plain")
        #expect(div.attrs["data-swui-drag"] == "plain text")
    }
}
