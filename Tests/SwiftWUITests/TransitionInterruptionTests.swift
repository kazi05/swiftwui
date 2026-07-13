import Testing
@testable import SwiftWUI

// Bidirectional interruption (Task 11, anim spec §7.5): re-inserting a
// still-exiting identity adopts its ghost back (no duplicate, no snap), and
// removing an identity mid-enter cancels the enter and exits from the current
// presentation. Runtime-level tests reuse `findFirst`/`findAll`/`TestScheduler`.

private struct AdoptBlock: Tag {
    @State var show = true
    var body: some Tag {
        if show { Div(class: "gone").transition(.opacity) }
        Button("t") { withAnimation(.linear(duration: 1)) { show.toggle() } }
    }
}

private struct EnterThenExitBlock: Tag {
    @State var show = false
    var body: some Tag {
        if show { Div(class: "gone").transition(.opacity) }
        Button("t") { withAnimation(.linear(duration: 1)) { show.toggle() } }
    }
}

private struct NestedPropBlock: Tag {
    @State var show = true
    @State var w = 10
    var body: some Tag {
        if show {
            Div(class: "root") {
                Span(class: "inner").style("width", "\(w)px")
            }.transition(.opacity)
        }
        Button("grow") { withAnimation(.linear(duration: 1)) { w = 100 } }
        Button("hide") { withAnimation(.linear(duration: 1)) { show = false } }
    }
}

private struct CounterInBranch: Tag {
    @State var n = 0
    var body: some Tag {
        H1("n=\(n)")
        Button("inc") { n += 1 }
    }
}
private struct AdoptStateBlock: Tag {
    @State var show = true
    var body: some Tag {
        if show { Div(class: "wrap") { CounterInBranch() }.transition(.opacity) }
        Button("t") { withAnimation(.linear(duration: 1)) { show.toggle() } }
    }
}

/// Deterministic LCG for the toggle-spam interleaving (fixed seed, no wall clock).
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Suite @MainActor struct TransitionInterruptionTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    private func button(_ backend: MockBackend, _ label: String) -> MockNode {
        findAll(backend.container, tag: "button").first { $0.children.first?.text == label }!
    }

    @Test func toggleBackMidExitAdoptsGhost() {
        let (runtime, backend, sched) = makeRuntime(AdoptBlock())
        let t = findFirst(backend.container, tag: "button")!

        runtime.dispatch(t.events["click"]!); sched.pump()   // off → exit starts (ghost)
        #expect(runtime._exitingCount == 1)
        let ghost = findFirst(backend.container, tag: "div")!
        #expect(ghost.attrs["inert"] == "")

        let cancelsBefore = backend.counts["cancelAnimation", default: 0]
        let animsBefore = backend.animations.count
        runtime.dispatch(t.events["click"]!); sched.pump()   // on BEFORE settle → adopt ghost

        // No duplicate host: exactly one "gone" div, still the same MockNode.
        #expect(findAll(backend.container, tag: "div").count == 1)
        #expect(backend.serializeHTML().components(separatedBy: "class=\"gone\"").count - 1 == 1)
        #expect(ghost.attrs["inert"] == nil)                              // inert removed
        #expect(backend.counts["cancelAnimation", default: 0] == cancelsBefore + 1)  // exit cancelled
        #expect(backend.animations.count == animsBefore + 1)             // enter animate recorded
        #expect(backend.animations.last!.request.from == "0")            // enter active→identity
        #expect(runtime._exitingCount == 0)
    }

    @Test func removalMidEnterCancelsAndExitsFromCurrent() {
        let (runtime, backend, sched) = makeRuntime(EnterThenExitBlock())
        let t = findFirst(backend.container, tag: "button")!

        runtime.dispatch(t.events["click"]!); sched.pump()   // on → enter animation
        #expect(backend.animations.count == 1)
        #expect(backend.animations[0].request.from == "0")   // enter active→identity, not yet settled

        let cancelsBefore = backend.counts["cancelAnimation", default: 0]
        runtime.dispatch(t.events["click"]!); sched.pump()   // off BEFORE enter settle

        // The in-flight enter under the exiting subtree is cancelled; the exit
        // then requests from the current presentation (implicit `from`).
        #expect(backend.counts["cancelAnimation", default: 0] == cancelsBefore + 1)
        let exit = backend.animations.last!.request
        #expect(exit.from == nil)
        #expect(exit.to == "0")
        #expect(runtime._exitingCount == 1)
    }

    @Test func adoptedSubtreeStateIsFresh() {
        let (runtime, backend, sched) = makeRuntime(AdoptStateBlock())

        runtime.dispatch(button(backend, "inc").events["click"]!); sched.pump()
        runtime.dispatch(button(backend, "inc").events["click"]!); sched.pump()
        #expect(findFirst(backend.container, tag: "h1")!.children.first!.text == "n=2")

        runtime.dispatch(button(backend, "t").events["click"]!); sched.pump()   // off → exit
        #expect(runtime._exitingCount == 1)
        runtime.dispatch(button(backend, "t").events["click"]!); sched.pump()   // on mid-exit → adopt

        // @State was swept at exit-start → the adopted subtree restarts fresh.
        #expect(findAll(backend.container, tag: "h1").count == 1)               // no duplicate
        #expect(findFirst(backend.container, tag: "h1")!.children.first!.text == "n=0")
        #expect(runtime._exitingCount == 0)

        // The adopted subtree is fully live: listeners + componentIndex + state
        // slot all survived the round trip (the nil-first ordering never let
        // finishExit tear the ghost down).
        runtime.dispatch(button(backend, "inc").events["click"]!); sched.pump()
        #expect(findFirst(backend.container, tag: "h1")!.children.first!.text == "n=1")
    }

    @Test func toggleSpamIsStable() {
        let (runtime, backend, sched) = makeRuntime(AdoptBlock())
        var rng = SeededRNG(seed: 0xC0FFEE)

        for _ in 0..<5 {
            runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
            sched.pump()
            // Interleave a random settle of some recorded animation.
            if Bool.random(using: &rng), !backend.animations.isEmpty {
                backend.settleAnimation(at: Int.random(in: 0..<backend.animations.count, using: &rng))
                sched.pump()
            }
        }
        // Drain: settle everything still in flight, let deferred exits finish.
        for i in backend.animations.indices { backend.settleAnimation(at: i) }
        sched.pump()

        #expect(runtime._exitingCount == 0)                       // no leaked ghosts at rest
        // 5 toggles from `show = true` → final state hidden, deterministically.
        #expect(findAll(backend.container, tag: "div").isEmpty)
    }

    // A `withAnimation` property animation on a NESTED element under the exit
    // root must be cancelled when the root exits (cancelAll prefix match).
    @Test func descendantPropertyAnimationCancelledOnExit() {
        let (runtime, backend, sched) = makeRuntime(NestedPropBlock())
        runtime.dispatch(button(backend, "grow").events["click"]!); sched.pump()
        #expect(backend.animations.contains { $0.request.property == "width" })
        let cancelsBefore = backend.counts["cancelAnimation", default: 0]

        runtime.dispatch(button(backend, "hide").events["click"]!); sched.pump()
        #expect(backend.counts["cancelAnimation", default: 0] == cancelsBefore + 1)  // nested width cancelled
        #expect(runtime._exitingCount == 1)
    }

    // Async-race guard (anim spec §7.5), driven at the applier level: a token
    // from a SUPERSEDED record settling late must not finish the record that now
    // holds the key. MockBackend settles synchronously, so we simulate the race
    // by finishing rec1 while its token T1 is still unsettled, then let T1's
    // late settle land after rec2 exists.
    @Test func straySettleFromSupersededRecordIgnored() {
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let registry = TransitionRegistry()
        applier.transitionsRef = registry
        let id = NodeIdentity.root.appending(.child(0))
        registry.register(.opacity.animation(.linear(duration: 1)), for: id)
        func el() -> Node {
            .element(ElementNode(identity: id, tag: "div", attributes: [:],
                                 listeners: [:], observers: [:], children: [], key: nil))
        }
        func mountRoot() -> MountedNode<MockNode> {
            let m = applier.mount(el(), hostParent: backend.container, before: nil)
            m.parent = applier.root; m.indexInParent = 0; applier.root.children = [m]
            return m
        }
        // suppressTransitions keeps mounts enter-free (so the only recorded
        // animations are the two exits) while exits still fire.
        applier.animationPass = AnimationPassContext(transactions: [:], reduceMotion: false,
                                                     suppressTransitions: true, defaultTransaction: nil)

        // rec1 / T1 = animations[0], then supersede rec1 WITHOUT cancelling T1.
        #expect(applier.beginExit(mountRoot(), node: el()))
        applier.finishExit(id)

        // rec2 / T2 = animations[1] at the SAME key.
        #expect(applier.beginExit(mountRoot(), node: el()))
        #expect(applier.exiting[id] != nil)

        backend.settleAnimation(at: 0)                 // T1's late settle — stray, must no-op
        #expect(applier.exiting[id] != nil)            // rec2's ghost survives
        backend.settleAnimation(at: 1)                 // T2 — rec2's own token finishes it
        #expect(applier.exiting[id] == nil)
        applier.animationPass = nil
    }
}
