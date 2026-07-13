import Testing
@testable import SwiftWUI

private struct OpacityBlock: Tag {
    @State var opacity: Double = 0.5
    var body: some Tag {
        Div(class: "op").style("opacity", cssNumber(opacity))
        Button("+") { withAnimation(.linear(duration: 1)) { opacity = 1 } }
    }
}

private struct PlainOpacityBlock: Tag {
    @State var opacity: Double = 0.5
    var body: some Tag {
        Div(class: "op2").style("opacity", cssNumber(opacity))
        Button("+") { opacity = 1 }
    }
}

private struct TwoPropBlock: Tag {
    @State var opacity: Double = 0.5
    @State var left: Double = 0
    var body: some Tag {
        Div(class: "two")
            .style("opacity", cssNumber(opacity))
            .style("left", cssNumber(left) + "px")
        Button("+") { opacity = 1; left = 100 }
    }
}

private struct ForeverBlock: Tag {
    @State var opacity: Double = 0.5
    var body: some Tag {
        Div(class: "forever").style("opacity", cssNumber(opacity))
        Button("+") { opacity = 1 }
    }
}

private struct RetargetBlock: Tag {
    @State var opacity: Double = 0
    var body: some Tag {
        Div(class: "retarget").style("opacity", cssNumber(opacity))
        Button("+") { withAnimation(.linear(duration: 1)) { opacity += 1 } }
    }
}

private struct AttrBlock: Tag {
    @State var flag = false
    var body: some Tag {
        Div(id: flag ? "a" : "b", class: "attrblock") {
            Text(flag ? "yes" : "no")
        }
        Button("+") { withAnimation(.linear(duration: 1)) { flag.toggle() } }
    }
}

@Suite @MainActor struct AnimationEngineTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func withAnimationEmitsAnimateWithFinalWrite() {
        let (runtime, backend, sched) = makeRuntime(OpacityBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        let div = findFirst(backend.container, tag: "div")!
        #expect(div.style["opacity"] == "1")   // model final write always happens
        #expect(backend.animations.count == 1)
        let expected = AnimationRequest(property: "opacity", from: "-0.5", to: "0", mode: .additive,
                                        timing: ResolvedTiming(durationMs: 1000, easing: "linear",
                                                               delayMs: 0, iterations: 1, autoreverses: false))
        #expect(backend.animations[0].request == expected)
    }

    @Test func plainWriteEmitsNoAnimate() {
        let (runtime, backend, sched) = makeRuntime(PlainOpacityBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.counts["animate"] == nil)
    }

    @Test func completionFiresAfterAllSettle() {
        let (runtime, backend, sched) = makeRuntime(TwoPropBlock())
        let button = findFirst(backend.container, tag: "button")!
        var completed = false
        withAnimation(completion: { completed = true }) {
            runtime.dispatch(button.events["click"]!)
        }
        sched.pump()
        #expect(!completed)
        #expect(backend.animations.count == 2)
        backend.settleAnimation(at: 0)
        #expect(!completed)
        backend.settleAnimation(at: 1)
        sched.pump()
        #expect(completed)
    }

    @Test func repeatForeverExcludedFromGroup() {
        let (runtime, backend, sched) = makeRuntime(ForeverBlock())
        let button = findFirst(backend.container, tag: "button")!
        var completed = false
        withAnimation(.linear(duration: 1).repeatForever(), completion: { completed = true }) {
            runtime.dispatch(button.events["click"]!)
        }
        sched.pump()   // one pump: the completion's own arm-time microtask drains in the same loop
        #expect(completed)
        #expect(backend.animations.count == 1)
    }

    @Test func retargetReplacesRegistryEntry() {
        let (runtime, backend, sched) = makeRuntime(RetargetBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(runtime._animationRegistry.running.count == 1)
        #expect(backend.animations.count == 2)
    }

    @Test func nonStyleChangesNeverAnimate() {
        let (runtime, backend, sched) = makeRuntime(AttrBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.counts["animate"] == nil)
    }
}
