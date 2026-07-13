import Testing
@testable import SwiftWUI

// Exit orchestration (Task 10, anim spec §7.3): inert ghosts, deferred removal,
// replaceSelf dual-fire, parent-unmount force-finish. Runtime-level tests reuse
// `findFirst`/`findAll`/`TestScheduler` from RuntimeE2ETests.

private struct ExitDeferBlock: Tag {
    @State var show = true
    var body: some Tag {
        if show { Div(class: "gone").transition(.opacity) }
        Button("t") { withAnimation(.linear(duration: 1)) { show = false } }
    }
}

private struct InstantBlock: Tag {
    @State var show = true
    var body: some Tag {
        if show { Div(class: "gone").transition(.opacity) }   // no own animation
        Button("t") { show = false }                          // plain — no ambient transaction
    }
}

private struct NoTransitionBlock: Tag {
    @State var show = true
    var body: some Tag {
        if show { Div(class: "plain") { P { "x" } } }         // no .transition at all
        Button("t") { withAnimation(.linear(duration: 1)) { show = false } }
    }
}

private struct ParentExitBlock: Tag {
    @State var outer = true
    @State var inner = true
    var body: some Tag {
        if outer {
            Div(class: "parent") {
                if inner { Div(class: "child").transition(.opacity) }
            }
        }
        Button("inner") { withAnimation(.linear(duration: 1)) { inner = false } }
        Button("outer") { outer = false }
    }
}

private struct MoveBlock: Tag {
    @State var items = [1, 2]
    @State var showGhost = true
    var body: some Tag {
        Div {
            if showGhost { Span(class: "ghost").transition(.opacity) }
            ForEach(items, id: \.self) { i in P { "\(i)" } }
        }
        Button("hide") { withAnimation(.linear(duration: 1)) { showGhost = false } }
        Button("rev") { items.reverse() }
    }
}

private struct ReExitBlock: Tag {
    @State var show = true
    var body: some Tag {
        if show { Div(class: "gone").transition(.opacity.animation(.linear(duration: 1))) }
        Button("t") { show.toggle() }
    }
}

private final class FireBox { var fired = false }
private struct DisappearBlock: Tag {
    @State var show = true
    let box: FireBox
    var body: some Tag {
        if show {
            Div(class: "gone")
                .onDisappear { box.fired = true }
                .transition(.opacity.animation(.linear(duration: 1)))
        }
        Button("t") { show = false }   // plain — the transition's own animation drives the exit
    }
}

@Suite @MainActor struct TransitionExitTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func exitDefersRemovalUntilSettle() {
        let (runtime, backend, sched) = makeRuntime(ExitDeferBlock())
        let button = findFirst(backend.container, tag: "button")!
        let removesBefore = backend.counts["remove", default: 0]
        runtime.dispatch(button.events["click"]!)
        sched.pump()

        // Ghost kept in the DOM, marked inert, one identity→active exit animation.
        let ghost = findFirst(backend.container, tag: "div")
        #expect(ghost != nil)
        #expect(ghost?.attrs["inert"] == "")
        #expect(backend.animations.count == 1)
        let request = backend.animations[0].request
        #expect(request.property == "opacity")
        #expect(request.from == nil)     // implicit current presentation
        #expect(request.to == "0")       // .opacity active value
        #expect(request.mode == .replace)
        #expect(backend.counts["remove", default: 0] == removesBefore)   // NOT removed yet
        #expect(runtime._exitingCount == 1)

        backend.settleAnimation(at: 0)   // exit completes → ghost torn out
        #expect(findFirst(backend.container, tag: "div") == nil)
        #expect(backend.counts["remove", default: 0] == removesBefore + 1)
        #expect(runtime._exitingCount == 0)
    }

    @Test func unanimatedRemoveIsInstant() {
        let (runtime, backend, sched) = makeRuntime(InstantBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.isEmpty)                        // transition without animation
        #expect(findFirst(backend.container, tag: "div") == nil)   // removed synchronously
        #expect(runtime._exitingCount == 0)
    }

    @Test func exitWithoutTransitionUnchanged() {
        let (runtime, backend, sched) = makeRuntime(NoTransitionBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.animations.isEmpty)                        // no transition → no exit machinery
        #expect(backend.counts["cancelAnimation"] == nil)
        #expect(findFirst(backend.container, tag: "div") == nil)   // removed this flush
        #expect(runtime._exitingCount == 0)

        // Byte-identical to a second, transition-free run of the same scenario:
        // the exit path adds zero backend churn when nothing is registered.
        let (base, baseBackend, baseSched) = makeRuntime(NoTransitionBlock())
        base.dispatch(findFirst(baseBackend.container, tag: "button")!.events["click"]!)
        baseSched.pump()
        #expect(backend.counts == baseBackend.counts)
    }

    @Test func parentUnmountForceFinishesChildExit() {
        let (runtime, backend, sched) = makeRuntime(ParentExitBlock())
        let buttons = findAll(backend.container, tag: "button")

        runtime.dispatch(buttons[0].events["click"]!)   // "inner" — child begins exit
        sched.pump()
        #expect(backend.animations.count == 1)
        #expect(findAll(backend.container, tag: "div").count == 2)   // parent + child ghost
        #expect(runtime._exitingCount == 1)

        let cancelsBefore = backend.counts["cancelAnimation", default: 0]
        runtime.dispatch(buttons[1].events["click"]!)   // "outer" — parent removed mid child-exit
        sched.pump()
        #expect(findAll(backend.container, tag: "div").isEmpty)      // both gone
        #expect(backend.counts["cancelAnimation", default: 0] == cancelsBefore + 1)
        #expect(runtime._exitingCount == 0)

        backend.settleAnimation(at: 0)   // late settle on the cancelled anim: no-op, no crash
        #expect(runtime._exitingCount == 0)
    }

    @Test func replaceSelfFiresExitAndEnterSimultaneously() {
        // Driven at the applier level (the deterministic replaceSelf path,
        // ApplierTests precedent): same-identity tag swap with a registered
        // transition on both old and new.
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let registry = TransitionRegistry()
        applier.transitionsRef = registry
        let id = NodeIdentity.root.appending(.child(0))
        registry.register(.opacity.animation(.linear(duration: 1)), for: id)
        func el(_ tag: String) -> Node {
            .element(ElementNode(identity: id, tag: tag, attributes: [:],
                                 listeners: [:], observers: [:], children: [], key: nil))
        }
        let m = applier.mount(el("div"), hostParent: backend.container, before: nil)
        m.parent = applier.root; m.indexInParent = 0; applier.root.children = [m]

        applier.animationPass = AnimationPassContext(transactions: [:], reduceMotion: false,
                                                     suppressTransitions: false, defaultTransaction: nil)
        applier.apply([.replaceSelf(with: el("span"))], to: m)
        applier.animationPass = nil

        // Both halves fired; new node sits BEFORE the old ghost in DOM order.
        #expect(backend.animations.count == 2)
        #expect(backend.container.children.map(\.tag) == ["span", "div"])
        let enter = backend.animations.first { $0.request.to == nil }!.request
        #expect(enter.from == "0")        // active→identity
        let exit = backend.animations.first { $0.request.from == nil }!.request
        #expect(exit.to == "0")           // identity→active
        #expect(applier.exiting.count == 1)

        let exitIdx = backend.animations.firstIndex { $0.request.from == nil }!
        backend.settleAnimation(at: exitIdx)
        #expect(backend.container.children.map(\.tag) == ["span"])   // ghost torn out
        #expect(applier.exiting.isEmpty)
    }

    @Test func moveAroundGhostDoesNotCrash() {
        let (runtime, backend, sched) = makeRuntime(MoveBlock())
        let buttons = findAll(backend.container, tag: "button")

        runtime.dispatch(buttons[0].events["click"]!)   // "hide" — span becomes a ghost among the P's
        sched.pump()
        #expect(findFirst(backend.container, tag: "span") != nil)
        #expect(runtime._exitingCount == 1)

        runtime.dispatch(buttons[1].events["click"]!)   // "rev" — keyed reorder around the ghost
        sched.pump()
        #expect(findFirst(backend.container, tag: "span") != nil)   // ghost survived the reorder
        let ps = findAll(backend.container, tag: "p").compactMap { $0.children.first?.text }
        #expect(ps == ["2", "1"])
        #expect(runtime._exitingCount == 1)

        backend.settleAnimation(at: 0)
        #expect(findFirst(backend.container, tag: "span") == nil)
        #expect(runtime._exitingCount == 0)
    }

    @Test func onDisappearFiresAtExitStart() {
        let box = FireBox()
        let (runtime, backend, sched) = makeRuntime(DisappearBlock(box: box))
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(box.fired)                                         // fired on the removal pass...
        #expect(findFirst(backend.container, tag: "div") != nil)   // ...while the ghost is still exiting
        #expect(backend.animations.count == 1)
        #expect(runtime._exitingCount == 1)
    }

    @Test func sameIdentityReExitCleansStaleGhost() {
        let (runtime, backend, sched) = makeRuntime(ReExitBlock())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!); sched.pump()   // off → exit 1 (ghost)
        #expect(runtime._exitingCount == 1)
        runtime.dispatch(button.events["click"]!); sched.pump()   // on → duplicate mounts (pre-Task-11)
        runtime.dispatch(button.events["click"]!); sched.pump()   // off → exit 2 force-finishes the stale ghost
        for i in backend.animations.indices { backend.settleAnimation(at: i) }
        sched.pump()
        #expect(findAll(backend.container, tag: "div").isEmpty)   // no leaked corpse
        #expect(!backend.serializeHTML().contains("gone"))
        #expect(runtime._exitingCount == 0)
    }
}
