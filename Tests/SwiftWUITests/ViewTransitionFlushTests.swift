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
}
