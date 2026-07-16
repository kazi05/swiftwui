import Testing
@testable import SwiftWUI

private struct TaskCard: DragPayload, Equatable { let id: Int; let pad: String? = nil }

private final class Recorder {
    var targeted: [Bool] = []
    var received: [TaskCard] = []
}
private struct BoardFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div(class: "zone")
            .dropDestination(for: TaskCard.self) { cards, _ in
                cap.received += cards; return true
            } isTargeted: { cap.targeted.append($0) }
    }
}

private struct CustomTypeCard: DragPayload, Equatable {
    let id: Int
    static var dragContentType: String { "application/X-Custom" }
}
private final class CustomRecorder {
    var targeted: [Bool] = []
    var received: [CustomTypeCard] = []
}
private struct CustomBoardFixture: Tag {
    let cap: CustomRecorder
    var body: some Tag {
        Div(class: "zone")
            .dropDestination(for: CustomTypeCard.self) { cards, _ in
                cap.received += cards; return true
            } isTargeted: { cap.targeted.append($0) }
    }
}

@Suite @MainActor struct TypedDropDestinationTests {
    private func mount() -> (Runtime<MockBackend>, MockBackend, TestScheduler, Recorder) {
        let cap = Recorder()
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: BoardFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched, cap)
    }
    @Test func acceptsAttributeIsContentType() {
        let (_, backend, _, _) = mount()
        #expect(findFirst(backend.container, tag: "div")!
            .attrs["data-swui-drop-accepts"] == "application/x-swiftwui.taskcard")
    }
    @Test func targetsOnlyMatchingType() {
        let (rt, backend, sched, cap) = mount()
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["dragenter"]!,
                    payload: DragEvent(types: ["application/x-swiftwui.taskcard"]))
        rt.dispatch(div.events["dragenter"]!, payload: DragEvent(types: ["text/plain"]))
        sched.pump()
        #expect(cap.targeted == [true])
    }
    @Test func dropDecodesPayload() {
        let (rt, backend, sched, cap) = mount()
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["drop"]!, payload: DropEvent(
            strings: ["application/x-swiftwui.taskcard": #"{"id":9}"#]))
        sched.pump()
        #expect(cap.received == [TaskCard(id: 9)])
        #expect(cap.targeted.last == false)
    }
    @Test func malformedAndOversizedBodiesIgnored() {
        let (rt, backend, sched, cap) = mount()
        let div = findFirst(backend.container, tag: "div")!
        rt.dispatch(div.events["drop"]!, payload: DropEvent(
            strings: ["application/x-swiftwui.taskcard": "not json"]))
        // Valid JSON, over the 1 MiB cap — must be rejected by the byte-cap
        // guard specifically, not because it fails to parse.
        let bomb = "{\"id\":1,\"pad\":\"" + String(repeating: "x", count: 1_048_600) + "\"}"
        rt.dispatch(div.events["drop"]!, payload: DropEvent(
            strings: ["application/x-swiftwui.taskcard": bomb]))
        rt.dispatch(div.events["drop"]!, payload: DropEvent(strings: ["text/plain": "hi"]))
        sched.pump()
        #expect(cap.received.isEmpty)
    }
    @Test func mixedCaseContentTypeNormalizedToLowercase() {
        let cap = CustomRecorder()
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: CustomBoardFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.attrs["data-swui-drop-accepts"] == "application/x-custom")
        rt.dispatch(div.events["dragenter"]!,
                    payload: DragEvent(types: ["application/x-custom"]))
        sched.pump()
        #expect(cap.targeted == [true])
        rt.dispatch(div.events["drop"]!, payload: DropEvent(
            strings: ["application/x-custom": #"{"id":1}"#]))
        sched.pump()
        #expect(cap.received == [CustomTypeCard(id: 1)])
    }
}
