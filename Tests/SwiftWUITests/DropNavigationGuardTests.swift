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
}
