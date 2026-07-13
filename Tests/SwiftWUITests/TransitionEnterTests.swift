import Testing
@testable import SwiftWUI

private struct EnterAnimatesBlock: Tag {
    @State var flag = false
    var body: some Tag {
        if flag { Div(class: "enter").transition(.opacity) }
        Button("+") { withAnimation(.linear(duration: 1)) { flag = true } }
    }
}

private struct NoTransactionBlock: Tag {
    @State var flag = false
    var body: some Tag {
        if flag { Div(class: "notxn").transition(.opacity) }
        Button("+") { flag = true }   // plain write — no withAnimation
    }
}

private struct OwnAnimationBlock: Tag {
    @State var flag = false
    var body: some Tag {
        if flag { Div(class: "own").transition(.opacity.animation(.easeOut(duration: 0.2))) }
        Button("+") { flag = true }   // plain toggle — transition's own animation still plays
    }
}

private struct ColdMountBlock: Tag {
    @State var flag = true
    var body: some Tag {
        if flag { Div(class: "cold").transition(.opacity.animation(.linear(duration: 1))) }
    }
}

private struct SuppressOnceBlock: Tag {
    @State var a = false
    @State var b = false
    var body: some Tag {
        if a { Div(class: "a").transition(.opacity.animation(.linear(duration: 1))) }
        if b { Div(class: "b").transition(.opacity.animation(.linear(duration: 1))) }
        Button("a+") { a = true }
        Button("b+") { b = true }
    }
}

private struct CombinedBlock: Tag {
    @State var flag = false
    var body: some Tag {
        if flag { Div(class: "combined").transition(.opacity.combined(with: .offset(y: 20))) }
        Button("+") { withAnimation(.linear(duration: 1)) { flag = true } }
    }
}

@Suite @MainActor struct TransitionEnterTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func enterAnimatesFromActiveToImplicit() {
        let (runtime, backend, sched) = makeRuntime(EnterAnimatesBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.count == 1)
        let request = backend.animations[0].request
        #expect(request.property == "opacity")
        #expect(request.from == "0")
        #expect(request.to == nil)
        #expect(request.mode == .replace)
    }

    @Test func noTransactionNoEnter() {
        let (runtime, backend, sched) = makeRuntime(NoTransactionBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.isEmpty)
    }

    @Test func transitionOwnAnimationAlwaysPlays() {
        let (runtime, backend, sched) = makeRuntime(OwnAnimationBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.count == 1)
        #expect(backend.animations[0].request.timing == Animation.easeOut(duration: 0.2).resolved())
    }

    @Test func coldMountNeverEnters() {
        let (_, backend, _) = makeRuntime(ColdMountBlock())
        #expect(backend.animations.isEmpty)
    }

    @Test func suppressOnceFlagSuppressesExactlyOnePass() {
        let (runtime, backend, sched) = makeRuntime(SuppressOnceBlock())
        runtime._suppressTransitionsOnce = true
        let buttons = findAll(backend.container, tag: "button")
        runtime.dispatch(buttons[0].events["click"]!)   // "a+" — suppressed, flag consumed
        sched.pump()
        #expect(backend.animations.isEmpty)
        runtime.dispatch(buttons[1].events["click"]!)   // "b+" — flag no longer set, animates
        sched.pump()
        #expect(backend.animations.count == 1)
    }

    @Test func emptyFlushConsumesSuppressFlagWithoutLeaking() {
        let (runtime, backend, sched) = makeRuntime(EnterAnimatesBlock())
        runtime._suppressTransitionsOnce = true
        runtime.flush()   // nothing dirty — must still consume the flag
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)   // real flush inside withAnimation
        sched.pump()
        #expect(backend.animations.count == 1)   // flag did NOT leak into this pass
    }

    @Test func combinedTransitionEmitsOneAnimatePerProperty() {
        let (runtime, backend, sched) = makeRuntime(CombinedBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.count == 2)
        let properties = Set(backend.animations.map { $0.request.property })
        #expect(properties == ["opacity", "translate"])
        let opacity = backend.animations.first { $0.request.property == "opacity" }!.request
        #expect(opacity.from == "0")
        let translate = backend.animations.first { $0.request.property == "translate" }!.request
        #expect(translate.from == "0px 20px")
    }
}
