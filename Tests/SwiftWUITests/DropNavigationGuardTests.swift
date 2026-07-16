import Testing
@testable import SwiftWUI

private struct GuardFixture: Tag {
    @State var showGuard = true
    var body: some Tag {
        Div {
            Button("toggle", onClick: { showGuard.toggle() })
            if showGuard { Div(class: "guarded").preventsAccidentalDropNavigation() }
        }
    }
}

private struct GuardPlusUnrelatedStateFixture: Tag {
    @State var showGuard = true
    @State var counter = 0
    var body: some Tag {
        Div {
            Button("bump", onClick: { counter += 1 })
            if showGuard { Div(class: "guarded").preventsAccidentalDropNavigation() }
        }
    }
}

@Suite @MainActor struct DropNavigationGuardTests {
    @Test func guardFollowsMountLifecycle() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: GuardFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.dropNavigationGuard == true)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(backend.dropNavigationGuard == false)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(backend.dropNavigationGuard == true)
    }

    /// An implementation that calls `setDropNavigationGuard` on every reconcile
    /// (not just 0↔some transitions) would also pass `guardFollowsMountLifecycle`.
    /// Pin the transition-only contract directly: a re-render that leaves the
    /// guard mounted (some→some) must not re-invoke the backend callback.
    @Test func guardOnlyFiresOnEmptinessTransition() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: GuardPlusUnrelatedStateFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.counts["setDropNavigationGuard"] == 1)
        #expect(backend.dropNavigationGuard == true)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(backend.counts["setDropNavigationGuard"] == 1)
        #expect(backend.dropNavigationGuard == true)
    }

    @Test func cancelAllTearsDownDropGuard() {
        let store = EffectStore()
        var recorded: [Bool] = []
        store._onDropGuardChange = { recorded.append($0) }
        let id = NodeIdentity.root.appending(.child(0))
        _ = store.reconcile([.dropGuard(id: id)], under: .root)
        #expect(recorded == [true])
        store._cancelAll()
        #expect(recorded == [true, false])
        store._cancelAll()
        #expect(recorded == [true, false])
    }
}
