import Testing
@testable import SwiftWUI

private struct WrappedLeaf: Tag {
    var body: some Tag {
        Div(class: "wrapped") { Text("hi") }
            .transition(.opacity)
    }
}
private struct PlainLeaf: Tag {
    var body: some Tag {
        Div(class: "plain") { Text("hi") }
    }
}
private struct ConditionalWrapped: Tag {
    @State var show = true
    var body: some Tag {
        Div {
            if show {
                Div(class: "cond") { Text("hi") }
                    .transition(.opacity)
            }
            Button("toggle") { show.toggle() }
        }
    }
}

private struct TransInner: Tag {
    @State var m = 0
    var body: some Tag {
        Div(class: "trans-inner") {
            Text("m=\(m)")
            Button("innerBump") { m += 1 }
        }
    }
}
private struct TransScopedFixture: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "trans-outer") {
            TransInner()
            Button("outerBump") { n += 1 }
        }
        .transition(.opacity)
    }
}

@Suite @MainActor struct TransitionRegistrationTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func registersWrappedElementIdentity() {
        let (runtime, _, _) = makeRuntime(WrappedLeaf())
        let div = findElement(runtime._current!, where: { $0.attributes["class"] == "wrapped" })!
        #expect(runtime._transitionRegistry.transition(for: div.identity) != nil)
    }

    @Test func unwrappedElementNotRegistered() {
        let (runtime, _, _) = makeRuntime(PlainLeaf())
        let div = findElement(runtime._current!, where: { $0.attributes["class"] == "plain" })!
        #expect(runtime._transitionRegistry.transition(for: div.identity) == nil)
        #expect(runtime._transitionRegistry.byIdentity.isEmpty)
    }

    @Test func sweepDropsAfterConditionalRemovesWrapper() {
        let (runtime, backend, sched) = makeRuntime(ConditionalWrapped())
        #expect(runtime._transitionRegistry.byIdentity.count == 1)
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(runtime._transitionRegistry.byIdentity.isEmpty)
    }

    /// Spec's scoped ≡ full invariant, applied to registration: a wrapper
    /// ABOVE the pass root (wraps the outer element; the inner dirty write
    /// is a descendant component) must keep its registration untouched by a
    /// subtree pass that never re-runs it. A wrapper effectively BELOW the
    /// pass root (the pass root's own body re-resolves and re-hits the
    /// wrapper along the way, since a write to the wrapping component's own
    /// state is itself the dirty write) must re-assert identically.
    @Test func scopedEqualsFull() {
        let schedA = TestScheduler(), schedB = TestScheduler()
        let backA = MockBackend(), backB = MockBackend()
        let scoped = Runtime(backend: backA, container: backA.container,
                             root: TransScopedFixture(), scheduleMicrotask: schedA.schedule)
        let full = Runtime(backend: backB, container: backB.container,
                           root: TransScopedFixture(), scheduleMicrotask: schedB.schedule)
        full._forceFullPasses = true
        scoped.mount(); full.mount()
        #expect(Set(scoped._transitionRegistry.byIdentity.keys) == Set(full._transitionRegistry.byIdentity.keys))
        #expect(!scoped._transitionRegistry.byIdentity.isEmpty)

        func dispatchTag(_ tag: String) {
            let bA = findAll(backA.container, tag: "button").first(where: { $0.children.first?.text == tag })!
            let bB = findAll(backB.container, tag: "button").first(where: { $0.children.first?.text == tag })!
            scoped.dispatch(bA.events["click"]!)
            full.dispatch(bB.events["click"]!)
            schedA.pump(); schedB.pump()
            #expect(Set(scoped._transitionRegistry.byIdentity.keys) == Set(full._transitionRegistry.byIdentity.keys))
            #expect(!scoped._transitionRegistry.byIdentity.isEmpty)
        }
        dispatchTag("outerBump")     // wrapper below the pass root — re-asserted
        dispatchTag("innerBump")     // wrapper above the pass root — untouched, must persist
        dispatchTag("outerBump")
    }
}

@Suite struct AnyTransitionTests {
    @Test func identityIsEmpty() {
        #expect(AnyTransition.identity == AnyTransition.active([]))
    }

    @Test func activeSetsBothPhases() {
        let t = AnyTransition.active([.opacity(0)])
        #expect(t == AnyTransition.opacity)
    }

    @Test func combinedUnionsBothPhaseLists() {
        let a = AnyTransition.opacity
        let b = AnyTransition.scale(0.5)
        let c = a.combined(with: b)
        #expect(c == AnyTransition.active([.opacity(0), StyleDeclaration(property: "scale", value: "0.5")]))
    }

    @Test func combinedPrefersSelfAnimationFallingBackToOther() {
        let a = AnyTransition.opacity.animation(.linear(duration: 1))
        let b = AnyTransition.opacity
        #expect(a.combined(with: b).animation == .linear(duration: 1))
        #expect(b.combined(with: a).animation == .linear(duration: 1))
    }

    @Test func asymmetricTakesInsertionInsertionAndRemovalRemoval() {
        let t = AnyTransition.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        #expect(t == AnyTransition(insertionActive: [StyleDeclaration(property: "translate", value: "-100% 0")],
                                    removalActive: [StyleDeclaration(property: "translate", value: "100% 0")],
                                    animation: nil))
    }

    @Test func slideIsAsymmetricLeadingTrailing() {
        #expect(AnyTransition.slide == AnyTransition.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
    }

    @Test func animationOverrideLastCallWins() {
        let t = AnyTransition.opacity.animation(.linear(duration: 1)).animation(.easeIn(duration: 2))
        #expect(t.animation == .easeIn(duration: 2))
    }

    @Test func moveEdgeValues() {
        #expect(AnyTransition.move(edge: .leading) == AnyTransition.active([StyleDeclaration(property: "translate", value: "-100% 0")]))
        #expect(AnyTransition.move(edge: .trailing) == AnyTransition.active([StyleDeclaration(property: "translate", value: "100% 0")]))
        #expect(AnyTransition.move(edge: .top) == AnyTransition.active([StyleDeclaration(property: "translate", value: "0 -100%")]))
        #expect(AnyTransition.move(edge: .bottom) == AnyTransition.active([StyleDeclaration(property: "translate", value: "0 100%")]))
    }

    @Test func offsetValue() {
        #expect(AnyTransition.offset(x: 10, y: -5) == AnyTransition.active([StyleDeclaration(property: "translate", value: "10px -5px")]))
    }

    @Test func scaleValue() {
        #expect(AnyTransition.scale() == AnyTransition.active([StyleDeclaration(property: "scale", value: "0")]))
        #expect(AnyTransition.scale(0.5) == AnyTransition.active([StyleDeclaration(property: "scale", value: "0.5")]))
    }
}
