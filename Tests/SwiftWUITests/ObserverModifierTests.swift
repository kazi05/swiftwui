import Testing
@testable import SwiftWUI

private final class Recorder {
    var sizeEvents: [SizeEvent] = []
    var visibilityStates: [Bool] = []
    var lowThresholdStates: [Bool] = []
    var highThresholdStates: [Bool] = []
    var taps = 0
}

private struct SizeFixture: Tag {
    let cap: Recorder
    var body: some Tag { Div().onSizeChange { cap.sizeEvents.append($0) } }
}
private struct VisibilityFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div().onVisibilityChange(threshold: 0.5) { cap.visibilityStates.append($0) }
    }
}
private struct TwoVisibilityThresholdsFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div()
            .onVisibilityChange(threshold: 0.25) { cap.lowThresholdStates.append($0) }
            .onVisibilityChange(threshold: 0.75) { cap.highThresholdStates.append($0) }
    }
}
private struct ObserverAndListenerFixture: Tag {
    let cap: Recorder
    var body: some Tag {
        Div()
            .onSizeChange { cap.sizeEvents.append($0) }
            .onTap { cap.taps += 1 }
    }
}
/// Outer wrapper is `section`, not `div`, so `findFirst(tag: "div")` finds
/// only the conditionally-mounted inner element (mirrors EffectTests'
/// AppearFixture pattern of using a distinct outer tag).
private struct ConditionalSizeFixture: Tag {
    let cap: Recorder
    @State var show = true
    var body: some Tag {
        Section {
            if show {
                Div().onSizeChange { cap.sizeEvents.append($0) }
            }
            Button("t") { show.toggle() }
        }
    }
}
private struct RerenderFixture: Tag {
    let cap: Recorder
    @State var count = 0
    var body: some Tag {
        Section {
            Div().onSizeChange { cap.sizeEvents.append($0) }
            Button("t") { count += 1 }
        }
    }
}

@Suite @MainActor struct ObserverModifierTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func onSizeChangeRegistersAndDeliversPayload() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(SizeFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        let id = div.observers[.size]
        #expect(id != nil)
        rt.dispatch(id!, payload: SizeEvent(width: 10, height: 20)); sched.pump()
        #expect(cap.sizeEvents == [SizeEvent(width: 10, height: 20)])
    }

    @Test func onVisibilityChangeRegistersAtThresholdAndDeliversBoolPayload() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(VisibilityFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        let id = div.observers[.visibility(threshold: 0.5)]
        #expect(id != nil)
        rt.dispatch(id!, payload: true); sched.pump()
        rt.dispatch(id!, payload: false); sched.pump()
        #expect(cap.visibilityStates == [true, false])
    }

    @Test func twoVisibilityObserversWithDifferentThresholdsCoexist() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(TwoVisibilityThresholdsFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        let low = div.observers[.visibility(threshold: 0.25)]
        let high = div.observers[.visibility(threshold: 0.75)]
        #expect(low != nil)
        #expect(high != nil)
        #expect(low != high)
        rt.dispatch(low!, payload: true); sched.pump()
        rt.dispatch(high!, payload: true); sched.pump()
        #expect(cap.lowThresholdStates == [true])
        #expect(cap.highThresholdStates == [true])
    }

    @Test func observerAndListenerCoexistOnSameElement() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(ObserverAndListenerFixture(cap: cap))
        let div = findFirst(backend.container, tag: "div")!
        let sizeID = div.observers[.size]
        let clickID = div.events["click"]
        #expect(sizeID != nil)
        #expect(clickID != nil)
        rt.dispatch(sizeID!, payload: SizeEvent(width: 1, height: 2)); sched.pump()
        rt.dispatch(clickID!); sched.pump()
        #expect(cap.sizeEvents == [SizeEvent(width: 1, height: 2)])
        #expect(cap.taps == 1)
    }

    @Test func conditionalUnmountCallsUnobserveAndClearsObservers() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(ConditionalSizeFixture(cap: cap))
        #expect(findFirst(backend.container, tag: "div") != nil)
        let unobserves = backend.counts["unobserve", default: 0]
        clickFirst(backend, rt, tag: "button", sched: sched)
        #expect(backend.counts["unobserve", default: 0] == unobserves + 1)
        #expect(findFirst(backend.container, tag: "div") == nil)
    }

    @Test func rerenderWithUnchangedObserverAddsNoExtraObserveCall() {
        let cap = Recorder()
        let (rt, backend, sched) = makeRuntime(RerenderFixture(cap: cap))
        let observes = backend.counts["observe", default: 0]
        clickFirst(backend, rt, tag: "button", sched: sched)
        #expect(backend.counts["observe", default: 0] == observes)
    }
}
