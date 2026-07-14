import Testing
@testable import SwiftWUI

// prefers-reduced-motion (Task 13, anim spec §9): signal + env key + engine
// gating. The engine's reduceMotion branches (Task 7 style-diff, Task 9 enter,
// Task 10 exit) already exist — this wires the real signal and exercises them.

// Plain write — no nested withAnimation of its own, so a completion-bearing
// withAnimation wrapped around dispatch (below) supplies both the animation
// and the group (mirrors AnimationEngineTests.noOpBackendNoEntryCompletionStillFires;
// a self-animating handler would shadow the outer transaction, per §4.1).
private struct PlainOpacityBlock: Tag {
    @State var opacity: Double = 0.5
    var body: some Tag {
        Div(class: "op").style("opacity", cssNumber(opacity))
        Button("+") { opacity = 1 }
    }
}

private struct TwoStepBlock: Tag {
    @State var opacity: Double = 0.5
    @State var left: Double = 0
    var body: some Tag {
        Div(class: "op")
            .style("opacity", cssNumber(opacity))
            .style("left", cssNumber(left) + "px")
        Button("a") { withAnimation(.linear(duration: 1)) { opacity = 1 } }
        Button("b") { withAnimation(.linear(duration: 1)) { left = 100 } }
    }
}

private struct EnterBlock: Tag {
    @State var flag = false
    var body: some Tag {
        if flag { Div(class: "enter").transition(.opacity) }
        Button("+") { withAnimation(.linear(duration: 1)) { flag = true } }
    }
}

private struct ExitBlock: Tag {
    @State var show = true
    var body: some Tag {
        if show { Div(class: "gone").transition(.opacity) }
        Button("t") { withAnimation(.linear(duration: 1)) { show = false } }
    }
}

@MainActor private final class RenderCounter { var n = 0 }

private struct MotionReader: Tag {
    let counter: RenderCounter
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some Tag {
        counter.n += 1
        return Div { Text(reduceMotion ? "reduced" : "full") }
    }
}

@Suite @MainActor struct ReducedMotionTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func styleChangeSkipsAnimateButCompletes() {
        let (runtime, backend, sched) = makeRuntime(PlainOpacityBlock())
        backend.environmentWriter!.setReduceMotion(true)
        let button = findFirst(backend.container, tag: "button")!
        var completed = false
        withAnimation(.linear(duration: 1), completion: { completed = true }) {
            runtime.dispatch(button.events["click"]!)
        }
        sched.pump()
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.style["opacity"] == "1")   // final value still written
        #expect(backend.animations.isEmpty)    // zero animate calls
        #expect(completed)                     // register()+settle() still fired
    }

    @Test func transitionsMountAndRemoveInstantly() {
        let (runtime, backend, sched) = makeRuntime(EnterBlock())
        backend.environmentWriter!.setReduceMotion(true)
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.isEmpty)
        #expect(findFirst(backend.container, tag: "div") != nil)   // mounted, no ghost machinery
        #expect(runtime._exitingCount == 0)

        let (runtime2, backend2, sched2) = makeRuntime(ExitBlock())
        backend2.environmentWriter!.setReduceMotion(true)
        let button2 = findFirst(backend2.container, tag: "button")!
        runtime2.dispatch(button2.events["click"]!)
        sched2.pump()
        #expect(backend2.animations.isEmpty)
        #expect(findFirst(backend2.container, tag: "div") == nil)   // removed synchronously
        #expect(runtime2._exitingCount == 0)
    }

    @Test func envKeyReadableAndTracked() {
        let reader = RenderCounter()
        let (runtime, backend, sched) = makeRuntime(MotionReader(counter: reader))
        #expect(backend.serializeHTML().contains("full"))
        #expect(reader.n == 1)

        backend.environmentWriter!.setReduceMotion(true)
        sched.pump()
        #expect(backend.serializeHTML().contains("reduced"))
        #expect(reader.n == 2)
        _ = runtime   // keep alive — EnvironmentSignals.writer captures [weak self]
    }

    @Test func toggleMidSessionGatesNextAnimation() {
        let (runtime, backend, sched) = makeRuntime(TwoStepBlock())
        let buttons = findAll(backend.container, tag: "button")
        runtime.dispatch(buttons[0].events["click"]!)   // first opacity write — reduceMotion off
        sched.pump()
        #expect(backend.animations.count == 1)   // plays normally while off

        backend.environmentWriter!.setReduceMotion(true)
        runtime.dispatch(buttons[1].events["click"]!)   // second write — reduceMotion now on
        sched.pump()
        #expect(backend.animations.count == 1)   // no NEW animate call; count unchanged
    }
}
