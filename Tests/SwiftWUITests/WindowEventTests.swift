import Testing
@testable import SwiftWUI

private final class Recorder {
    var scrollEvents: [ScrollEvent] = []
    var resizeEvents: [SizeEvent] = []
}

private struct ScrollFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onWindowScroll { cap.scrollEvents.append($0) } }
}
private struct ResizeFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onWindowResize { cap.resizeEvents.append($0) } }
}
private struct NoWindowModifierFixture: Tag {
    var body: some Tag { Div() }
}
private struct TwoSubscribersFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Section {
            Div(class: "a").onWindowScroll { cap.scrollEvents.append($0) }
            Div(class: "b").onWindowResize { cap.resizeEvents.append($0) }
        }
    }
}
private struct ConditionalScrollFixture: Tag {
    let cap: Recorder
    @State var show = true
    var body: some Tag {
        Section {
            if show {
                Div().onWindowScroll { cap.scrollEvents.append($0) }
            }
            Button("t") { show.toggle() }
        }
    }
}

@Suite @MainActor struct WindowEventTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func onWindowScrollBeginsObservationLazily() {
        let cap = Recorder()
        let (_, backend, _) = makeRuntime(ScrollFixture(cap: cap))
        #expect(backend.windowEventSink != nil)
    }

    @Test func mountWithoutWindowModifierLeavesSinkNil() {
        let (_, backend, _) = makeRuntime(NoWindowModifierFixture())
        #expect(backend.windowEventSink == nil)
    }

    @Test func scrollDispatchDeliversPayloadAndIgnoresResize() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(ScrollFixture(cap: cap))
        _ = rt   // keep the runtime alive — sink closures capture it weakly
        backend.windowEventSink!(.scroll, ScrollEvent(x: 0, y: 42))
        sched.pump()
        #expect(cap.scrollEvents == [ScrollEvent(x: 0, y: 42)])
        backend.windowEventSink!(.resize, SizeEvent(width: 100, height: 200))
        sched.pump()
        #expect(cap.scrollEvents == [ScrollEvent(x: 0, y: 42)])   // resize did not hit the scroll subscriber
    }

    @Test func onWindowResizeDeliversPayload() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(ResizeFixture(cap: cap))
        _ = rt   // keep the runtime alive — sink closures capture it weakly
        backend.windowEventSink!(.resize, SizeEvent(width: 320, height: 480))
        sched.pump()
        #expect(cap.resizeEvents == [SizeEvent(width: 320, height: 480)])
    }

    @Test func twoSubscribersOnDifferentSubtreesRoutedByKind() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(TwoSubscribersFixture(cap: cap))
        _ = rt   // keep the runtime alive — sink closures capture it weakly
        backend.windowEventSink!(.scroll, ScrollEvent(x: 1, y: 2))
        backend.windowEventSink!(.resize, SizeEvent(width: 3, height: 4))
        sched.pump()
        #expect(cap.scrollEvents == [ScrollEvent(x: 1, y: 2)])
        #expect(cap.resizeEvents == [SizeEvent(width: 3, height: 4)])
    }

    @Test func conditionalUnmountStopsFurtherDispatch() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(ConditionalScrollFixture(cap: cap))
        backend.windowEventSink!(.scroll, ScrollEvent(x: 0, y: 1))
        sched.pump()
        #expect(cap.scrollEvents == [ScrollEvent(x: 0, y: 1)])

        clickFirst(backend, rt, tag: "button", sched: sched)   // flips `show` off, sweeps the effect
        #expect(findFirst(backend.container, tag: "div") == nil)

        backend.windowEventSink!(.scroll, ScrollEvent(x: 0, y: 2))
        sched.pump()
        #expect(cap.scrollEvents == [ScrollEvent(x: 0, y: 1)])   // unchanged — subscriber unsubscribed
    }
}
