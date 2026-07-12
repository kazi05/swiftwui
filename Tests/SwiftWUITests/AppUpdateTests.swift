import Testing
@testable import SwiftWUI

@Suite @MainActor struct AppUpdateTests {
    final class Sched {
        var q: [() -> Void] = []
        func schedule(_ f: @escaping () -> Void) { q.append(f) }
        func drain() { while !q.isEmpty { q.removeFirst()() } }
    }
    final class Capture { var fn: (() -> Void)? }

    struct UpdateProbe: Tag {
        @Environment(\.appUpdateAvailable) var updateAvailable
        @Environment(\.reloadToUpdate) var reload
        let cap: Capture
        var body: some Tag {
            cap.fn = reload   // explicit return below disables the builder transform
            return Div(class: updateAvailable ? "update" : "idle")
        }
    }

    private func makeRuntime(cap: Capture) -> (Runtime<MockBackend>, MockBackend, Sched) {
        let backend = MockBackend()
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: UpdateProbe(cap: cap),
                              scheduleMicrotask: sched.schedule)
        runtime.mount()
        sched.drain()
        return (runtime, backend, sched)
    }

    @Test func defaultsOutsideRuntime() {
        #expect(EnvironmentValues().appUpdateAvailable == false)
        EnvironmentValues().reloadToUpdate()   // no-op default must not crash
    }

    @Test func updateSignalRerendersReaders() {
        let cap = Capture()
        let (runtime, backend, sched) = makeRuntime(cap: cap)
        #expect(backend.serializeHTML().contains("idle"))
        backend.environmentWriter!.setAppUpdateAvailable(true)
        sched.drain()
        #expect(backend.serializeHTML().contains("update"))
        _ = runtime   // writer captures [weak self]
    }

    @Test func reloadToUpdateRoutesToBackend() {
        let cap = Capture()
        let (runtime, backend, _) = makeRuntime(cap: cap)
        cap.fn!()
        #expect(backend.reloadForUpdateCount == 1)
        #expect(backend.counts["reloadForUpdate"] == 1)
        _ = runtime
    }

    @Test func reloadToUpdateForwardsThroughAdoptingBackend() {
        let cap = Capture()
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        let sched = Sched()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: UpdateProbe(cap: cap),
                              scheduleMicrotask: sched.schedule)
        runtime.mount()
        sched.drain()
        cap.fn!()
        #expect(base.reloadForUpdateCount == 1)
        _ = runtime
    }
}
