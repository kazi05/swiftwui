import Testing
@testable import SwiftWUI

private final class Capture { var generic: [GenericEvent] = []; var voids = 0 }

private struct PayloadFixture: Tag {
    let cap: Capture
    var body: some Tag {
        Div {
            Input(type: .text)
                .on(.input) { cap.generic.append($0) }
            Button("b") { cap.voids += 1 }
        }
    }
}

@MainActor @Suite struct EventPayloadTests {
    @Test func typedHandlerReceivesPayload() {
        var bag = _AttributeBag()
        var got: [InputEvent] = []
        bag.addHandler(.input, payload: InputEvent.self) { got.append($0) }
        bag.handlers[0].action(InputEvent(value: "hi"))
        #expect(got.map(\.value) == ["hi"])
    }

    // NOTE (no test): payload type mismatch → assertionFailure in debug, drop in
    // release (spec §11). assertionFailure is untestable from Swift Testing in a
    // debug build (it traps the process) — the contract is pinned by this comment
    // and the guard in _AttributeBag.addHandler(payload:).

    @Test func voidHandlersStillWork() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let cap = Capture()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: PayloadFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        let button = findFirst(backend.container, tag: "button")!
        rt.dispatch(button.events["click"]!)                 // no payload
        #expect(cap.voids == 1)
    }

    @Test func onEscapeHatchWrapsAnyPayloadIntoGenericEvent() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let cap = Capture()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: PayloadFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        let input = findFirst(backend.container, tag: "input")!
        rt.dispatch(input.events["input"]!, payload: InputEvent(value: "abc"))
        #expect(cap.generic.count == 1)
        #expect(cap.generic[0].type == "input")
        #expect(cap.generic[0].targetValue == "abc")
    }
}
