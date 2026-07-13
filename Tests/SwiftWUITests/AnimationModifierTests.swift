import Testing
@testable import SwiftWUI

private struct AnimBasic: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "wrap") {
            Text("\(n)")
            Button("+") { n += 1 }
        }
        .animation(.spring(duration: 1), value: n)
    }
}

private struct AnimSibling: Tag {
    @State var n = 0
    @State var flag = false
    var body: some Tag {
        Div(class: "wrap2") {
            Text("\(n)")
            Button("flip") { flag.toggle() }   // unrelated write — n never changes
        }
        .animation(.spring(duration: 1), value: n)
    }
}

private struct AnimNearest: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "outer") {
            Div(class: "inner") {
                Text("\(n)")
            }
            .animation(.spring(duration: 1), value: n)
            Button("+") { withAnimation(.linear(duration: 1)) { n += 1 } }
        }
    }
}

private struct AnimNilSuppress: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "wrap3") {
            Text("\(n)")
            Button("+") { withAnimation(.spring(duration: 1)) { n += 1 } }
        }
        .animation(nil, value: n)
    }
}

private struct AnimInnerState: Tag {
    @State var m = 0
    var body: some Tag {
        Div(class: "inner-state") {
            Text("m=\(m)")
            Button("innerBump") { m += 1 }
        }
    }
}
private struct AnimScopedFixture: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "scoped-outer") {
            AnimInnerState()
            Button("outerBump") { n += 1 }
        }
        .animation(.spring(duration: 1), value: n)
    }
}

@Suite @MainActor struct AnimationModifierTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func firesOnlyWhenValueChanges() {
        let (runtime, backend, sched) = makeRuntime(AnimBasic())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        let div = findElement(runtime._current!, where: { $0.attributes["class"] == "wrap" })!
        #expect(runtime._lastEffectiveTransactions[div.identity]?.animation == .spring(duration: 1))
    }

    @Test func unchangedValueUnrelatedWriteDoesNotAnimate() {
        let (runtime, backend, sched) = makeRuntime(AnimSibling())
        let button = findFirst(backend.container, tag: "button")!   // "flip" — doesn't touch n
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(runtime._lastEffectiveTransactions.isEmpty)
    }

    @Test func overridesAmbientNearestWins() {
        let (runtime, backend, sched) = makeRuntime(AnimNearest())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        let outer = findElement(runtime._current!, where: { $0.attributes["class"] == "outer" })!
        let inner = findElement(runtime._current!, where: { $0.attributes["class"] == "inner" })!
        #expect(runtime._lastEffectiveTransactions[outer.identity]?.animation == .linear(duration: 1))
        #expect(runtime._lastEffectiveTransactions[inner.identity]?.animation == .spring(duration: 1))
    }

    @Test func nilAnimationSuppresses() {
        let (runtime, backend, sched) = makeRuntime(AnimNilSuppress())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        let div = findElement(runtime._current!, where: { $0.attributes["class"] == "wrap3" })!
        let entry = runtime._lastEffectiveTransactions[div.identity]
        #expect(entry != nil)
        #expect(entry?.animation == nil)
    }

    @Test func scopedEqualsFull() {
        let schedA = TestScheduler(), schedB = TestScheduler()
        let backA = MockBackend(), backB = MockBackend()
        let scoped = Runtime(backend: backA, container: backA.container,
                             root: AnimScopedFixture(), scheduleMicrotask: schedA.schedule)
        let full = Runtime(backend: backB, container: backB.container,
                           root: AnimScopedFixture(), scheduleMicrotask: schedB.schedule)
        full._forceFullPasses = true
        scoped.mount(); full.mount()

        func dispatchTag(_ tag: String) {
            let bA = findAll(backA.container, tag: "button").first(where: { $0.children.first?.text == tag })!
            let bB = findAll(backB.container, tag: "button").first(where: { $0.children.first?.text == tag })!
            scoped.dispatch(bA.events["click"]!)
            full.dispatch(bB.events["click"]!)
            schedA.pump(); schedB.pump()
            #expect(scoped._lastEffectiveTransactions.mapValues { $0.animation }
                    == full._lastEffectiveTransactions.mapValues { $0.animation })
        }
        dispatchTag("outerBump")     // fires the wrapper (value change)
        dispatchTag("innerBump")     // descendant-only write, must not fire in either
        dispatchTag("outerBump")     // fires again — not stale
    }

    @Test func staleOverrideMustNotFire() {
        let (runtime, backend, sched) = makeRuntime(AnimScopedFixture())
        let outerButton = findAll(backend.container, tag: "button").first(where: { $0.children.first?.text == "outerBump" })!
        let innerButton = findAll(backend.container, tag: "button").first(where: { $0.children.first?.text == "innerBump" })!
        runtime.dispatch(outerButton.events["click"]!)   // pass N: value changes, animates
        sched.pump()
        #expect(!runtime._lastEffectiveTransactions.isEmpty)

        runtime.dispatch(innerButton.events["click"]!)   // pass N+1: descendant-only write
        sched.pump()
        #expect(runtime._lastEffectiveTransactions.isEmpty)
    }
}
