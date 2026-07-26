import Testing
@testable import SwiftWUI

private struct VTCounter: Tag {
    @State var count = 0
    var body: some Tag {
        Div {
            Button("bump") { count += 1 }
            Span { Text("\(count)") }
        }
    }
}

@Suite @MainActor struct ViewTransitionFlushTests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func plainWriteNeverStartsATransition() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        let button = findFirst(backend.container, tag: "button")!
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.viewTransitions.isEmpty)
    }

    @Test func withViewTransitionArmsExactlyOneTransition() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
        #expect(backend.viewTransitions[0].direction == nil)
        #expect(backend.viewTransitions[0].durationMS == 220)
        #expect(backend.serializeHTML().contains("<span>1</span>"))   // DOM still committed
    }

    @Test func emptyBodyArmsNothing() {
        let (_, backend, sched) = makeRuntime(VTCounter())
        withViewTransition(.fade) { }
        sched.pump()
        #expect(backend.viewTransitions.isEmpty)
    }

    @Test func writeDuringCaptureWindowDefersToTheFollowUpFlush() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        backend.deferViewTransition = true
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(runtime._viewTransitionInFlight)
        runtime.dispatch(button.events["click"]!)          // arrives inside the window
        sched.pump()
        #expect(backend.serializeHTML().contains("<span>0</span>"))   // nothing committed yet
        backend.runPendingViewTransition()                  // browser calls the update callback
        sched.pump()
        #expect(backend.serializeHTML().contains("<span>2</span>"))   // both writes landed
        #expect(backend.viewTransitions.count == 1)          // the second write armed nothing
    }

    @Test func droppedUpdateCallbackDoesNotFreezeTheRenderer() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        backend.deferViewTransition = true
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        // A write arrives WHILE the update callback is still outstanding, so
        // this flush must actually hit the `vtInFlight` guard branch — that's
        // the branch under test (fix round 1, Finding 2: the original test let
        // `_forceClearViewTransitionForTests()` run first, so the guard branch
        // was never exercised and could regress silently).
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(backend.serializeHTML().contains("<span>0</span>"))   // nothing committed yet
        backend.dropPendingViewTransition()                 // document torn down mid-window
        backend.deferViewTransition = false
        // The watchdog is a DOM-backend concern; on the native side the guard
        // must at least not wedge `scheduled`, so a later write still renders
        // once the flag is cleared by the next delivered callback.
        runtime._forceClearViewTransitionForTests()
        runtime.dispatch(button.events["click"]!)
        sched.pump()
        #expect(!backend.serializeHTML().contains("<span>0</span>"))
    }

    @Test func updateCalledTwiceCommitsOnce() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        backend.deferViewTransition = true
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        let update = backend._heldViewTransitionUpdate!
        update(); update()
        sched.pump()
        #expect(backend.serializeHTML().contains("<span>1</span>"))
    }

    @Test func noArmingWhileDragging() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        runtime._signals.writer.setDragSession(DragSessionInfo(isActive: true, hasFiles: false, types: []))
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(backend.viewTransitions.isEmpty)
        #expect(backend.serializeHTML().contains("<span>1</span>"))   // still rendered
    }

    @Test func redirectInsideTheCallbackLandsAndNeverPaintsTheIntermediatePage() {
        // A guard redirect calls navigate(replace: true) from commitRouteEffects,
        // which now runs INSIDE the update callback with vtInFlight still true.
        // It must reach the DOM via the deferred tail flush, and the skipped
        // page must never appear.
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: RedirectingApp(), initialPath: "/",
                              scheduleMicrotask: sched.schedule)
        runtime.mount()
        runtime.navigate(to: "/admin", transition: .fade)
        sched.pump()
        #expect(runtime._locationPath == "/login")
        let html = backend.serializeHTML()
        #expect(html.contains("login"))
        #expect(!html.contains("admin"))          // the skipped page never painted
        #expect(!runtime._viewTransitionInFlight)
    }

    @Test func reduceMotionSkipsTransitionUnlessOptedOut() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        runtime._signals.writer.setReduceMotion(true)
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(backend.viewTransitions.isEmpty)
        withViewTransition(.fade.respectsReducedMotion(false)) {
            runtime.dispatch(button.events["click"]!)
        }
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
    }

    @Test func buildModeNeverArms() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        runtime._disableViewTransitions = true
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(backend.viewTransitions.isEmpty)
    }

    // Regression (fix round 1, Finding 1): an enclosing ambient scope must not
    // clobber a navigation's own arm. `navigate`'s resolved transition carries
    // a duration the ambient `.fade` default (220ms) doesn't, so a passing
    // `durationMS` assertion proves the NAVIGATION's PageTransition landed —
    // not just that `direction` survived.
    @Test func navigationArmWinsOverEnclosingAmbientScope() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        withViewTransition(.fade) {
            runtime.navigate(to: "/x", transition: .fade.duration(.ms(500)))
        }
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
        #expect(backend.viewTransitions[0].direction == .push)
        #expect(backend.viewTransitions[0].durationMS == 500)
    }

    // Guard: with no navigation in the mix, plain ambient arming still works
    // exactly as before (this is also covered by
    // `withViewTransitionArmsExactlyOneTransition`, kept here as an explicit
    // guard next to the navigation-wins fix so the two behaviors read
    // side-by-side).
    @Test func ambientScopeStillArmsWithNoDirectionWhenNothingNavigates() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
        #expect(backend.viewTransitions[0].direction == nil)
    }

    // Guard: two ambient (non-navigation) arms in the same flush still
    // last-wins — the navigation-wins fix must not make the FIRST arm sticky.
    @Test func twoAmbientScopesInOneFlushLastWins() {
        let (runtime, backend, sched) = makeRuntime(VTCounter())
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        withViewTransition(.fade.duration(.ms(500))) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(backend.viewTransitions.count == 1)
        #expect(backend.viewTransitions[0].durationMS == 500)
    }

    @Test func performViewTransitionForwardsThroughAdoptingBackend() {
        // Mirrors AppUpdateTests.reloadToUpdateForwardsThroughAdoptingBackend.
        // `RendererBackend`'s protocol extension supplies a default
        // `performViewTransition` that just calls `update()` inline — deleting
        // `AdoptingBackend`'s override compiles and every other suite stays
        // green, but it would silently disable view transitions on every
        // prerendered+hydrated app while `swiftwui dev` (cold-mounted, no
        // AdoptingBackend) keeps animating. Nothing else exercised this
        // forwarding path.
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        let sched = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: VTCounter(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let button = findFirst(base.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(base.viewTransitions.count == 1)
    }

    @Test func transitionFlushCreatesNoExitGhost() {
        let (runtime, backend, sched) = makeRuntime(VTExiting())
        let button = findFirst(backend.container, tag: "button")!
        withViewTransition(.fade) { runtime.dispatch(button.events["click"]!) }
        sched.pump()
        #expect(runtime._exitingCount == 0)
        #expect(findFirst(backend.container, tag: "span") == nil)
    }
}

private struct RedirectingApp: Tag {
    var body: some Tag {
        Router {
            Route("/") { Div { Text("home") } }
            Route("/admin", guard: { .redirect("/login") }) { Div { H1("admin") } }
            Route("/login") { Div { H1("login") } }
        }
    }
}

// Own driving animation (`.animation(...)` on the transition itself), not a
// bare `.transition(.opacity)`: a plain write with no ambient `withAnimation`
// and no self-driving animation never reaches TreeApplier.beginExit's work
// collection at all (see `unanimatedRemoveIsInstant` in TransitionExitTests.swift
// — an unanimated remove is instant), so it can't exercise the
// `suppressTransitions` guard this test is about.
private struct VTExiting: Tag {
    @State var show = true
    var body: some Tag {
        Div {
            Button("toggle") { show.toggle() }
            if show { Span { Text("bye") }.transition(.opacity.animation(.linear(duration: 1))) }
        }
    }
}
