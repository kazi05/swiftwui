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

private struct ColorBlock: Tag {
    @State var color = "red"
    var body: some Tag {
        Div(class: "color").style("background-color", color)
        Button("next") { withAnimation(.linear(duration: 1)) { color = color == "red" ? "blue" : "green" } }
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

// A `repeatForever` property animation on an element that is then structurally
// removed WITHOUT a transition: unmount must cancel it or its WAAPI object +
// registry entry leak forever (item 3).
private struct ForeverUnmountBlock: Tag {
    @State var show = true
    @State var w = 10
    var body: some Tag {
        if show { Div(class: "forever-el").style("width", "\(w)px") }   // no .transition
        Button("grow") { withAnimation(.linear(duration: 1).repeatForever()) { w = 100 } }
        Button("hide") { show = false }   // plain structural remove
    }
}

// An element carrying a `.transition` AND a withAnimation property animation on
// ITSELF (not a descendant): exercises the cancel-enter self-case at exit (4c).
private struct SelfExitAnimBlock: Tag {
    @State var show = true
    @State var w = 10
    var body: some Tag {
        if show { Div(class: "sea").style("width", "\(w)px").transition(.opacity) }
        Button("grow") { w = 100 }                                              // wrapped by outer withAnimation(A)
        Button("hide") { withAnimation(.linear(duration: 1)) { show = false } } // transaction B
    }
}

// Plain-handler color block (no per-button withAnimation) so the outer
// transaction fully owns the write — for the cross-flush retarget test (4d).
private struct RetargetColorBlock: Tag {
    @State var color = "red"
    var body: some Tag {
        Div(class: "xcolor").style("background-color", color)
        Button("next") { color = color == "red" ? "blue" : "green" }
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

    @Test func additiveRetargetOldSettleKeepsNewEntry() {
        let (runtime, backend, sched) = makeRuntime(RetargetBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!); sched.pump()   // opacity 0→1 (token0)
        runtime.dispatch(button.events["click"]!); sched.pump()   // opacity 1→2 (token1, additive: no cancel)
        #expect(backend.animations.count == 2)
        #expect(runtime._animationRegistry.running.count == 1)
        backend.settleAnimation(at: 0)   // OLD settles first — must NOT evict the newer entry
        #expect(runtime._animationRegistry.running.count == 1)
        backend.settleAnimation(at: 1)   // NEW settles — its own entry gone
        #expect(runtime._animationRegistry.running.count == 0)
    }

    @Test func replaceRetargetCancelsOld() {
        let (runtime, backend, sched) = makeRuntime(ColorBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!); sched.pump()   // red→blue (replace)
        #expect(backend.animations[0].request.mode == .replace)
        runtime.dispatch(button.events["click"]!); sched.pump()   // blue→green (replace → cancels old)
        #expect(backend.counts["cancelAnimation"] == 1)
        #expect(backend.animations.count == 2)
        #expect(runtime._animationRegistry.running.count == 1)   // old evicted, new tracked
    }

    @Test func noOpBackendNoEntryCompletionStillFires() {
        let (runtime, backend, sched) = makeRuntime(PlainOpacityBlock())
        backend.animateReturnsNil = true
        let button = findFirst(backend.container, tag: "button")!
        var completed = false
        withAnimation(.linear(duration: 1), completion: { completed = true }) {
            runtime.dispatch(button.events["click"]!)
        }
        sched.pump()
        #expect(runtime._animationRegistry.running.isEmpty)
        #expect(completed)
    }

    // Item 3: a `repeatForever` property animation on a structurally-removed
    // element (no transition) is cancelled at unmount — no leaked registry entry.
    @Test func repeatForeverPropertyAnimationCancelledOnUnmount() {
        let (runtime, backend, sched) = makeRuntime(ForeverUnmountBlock())
        let buttons = findAll(backend.container, tag: "button")
        let grow = buttons.first { $0.children.first?.text == "grow" }!
        let hide = buttons.first { $0.children.first?.text == "hide" }!
        runtime.dispatch(grow.events["click"]!); sched.pump()
        #expect(runtime._animationRegistry.running.contains { $0.key.property == "width" })
        let cancelsBefore = backend.counts["cancelAnimation", default: 0]
        runtime.dispatch(hide.events["click"]!); sched.pump()   // structural remove, no transition
        #expect(backend.counts["cancelAnimation", default: 0] == cancelsBefore + 1)
        #expect(!runtime._animationRegistry.running.contains { $0.key.property == "width" })
    }

    // 4c: exiting an element that has an in-flight withAnimation property
    // animation on ITSELF cancels that animation (cancel-enter self-case), and
    // the property animation's own transaction completion still fires once.
    @Test func exitCancelsSelfPropertyAnimationCompletionFiresOnce() {
        let (runtime, backend, sched) = makeRuntime(SelfExitAnimBlock())
        let buttons = findAll(backend.container, tag: "button")
        let grow = buttons.first { $0.children.first?.text == "grow" }!
        let hide = buttons.first { $0.children.first?.text == "hide" }!
        var completedA = 0
        withAnimation(.linear(duration: 1), completion: { completedA += 1 }) {
            runtime.dispatch(grow.events["click"]!)   // width grows under transaction A
        }
        sched.pump()
        #expect(backend.animations.contains { $0.request.property == "width" })
        #expect(completedA == 0)
        let cancelsBefore = backend.counts["cancelAnimation", default: 0]

        runtime.dispatch(hide.events["click"]!); sched.pump()   // exit the SAME element (txn B)
        #expect(backend.counts["cancelAnimation", default: 0] > cancelsBefore)   // self width cancelled
        #expect(completedA == 1)                                                 // A settled exactly once
        #expect(runtime._exitingCount == 1)
    }

    // 4d: a second flush retargets the same property in REPLACE mode before the
    // first transaction's animation settles → the old token is cancelled and the
    // first transaction's completion fires exactly once.
    @Test func crossFlushReplaceRetargetCompletionFiresOnce() {
        let (runtime, backend, sched) = makeRuntime(RetargetColorBlock())
        let button = findFirst(backend.container, tag: "button")!
        var completedA = 0
        withAnimation(.linear(duration: 1), completion: { completedA += 1 }) {
            runtime.dispatch(button.events["click"]!)   // red→blue, replace, group A
        }
        sched.pump()
        #expect(backend.animations.count == 1)
        #expect(backend.animations[0].request.mode == .replace)
        #expect(completedA == 0)
        let cancelsBefore = backend.counts["cancelAnimation", default: 0]

        withAnimation(.linear(duration: 1)) {
            runtime.dispatch(button.events["click"]!)   // blue→green, replace, transaction B (no completion)
        }
        sched.pump()
        #expect(backend.counts["cancelAnimation", default: 0] == cancelsBefore + 1)   // old token cancelled
        #expect(completedA == 1)                                                       // A fires exactly once
    }
}
