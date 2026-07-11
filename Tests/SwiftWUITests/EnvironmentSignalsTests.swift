import Testing
@testable import SwiftWUI

@MainActor
private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

@MainActor private final class RenderCounter { var n = 0 }

private struct SchemeReader: Tag {
    let counter: RenderCounter
    @Environment(\.colorScheme) var scheme
    var body: some Tag {
        counter.n += 1
        return Div { Text(scheme == .dark ? "dark" : "light") }
    }
}

private struct Bystander: Tag {
    let counter: RenderCounter
    @State var n = 0
    var body: some Tag {
        counter.n += 1
        return Text("bystander")
    }
}

private struct SignalsRoot: Tag {
    let reader: RenderCounter
    let bystander: RenderCounter
    var body: some Tag {
        Div {
            SchemeReader(counter: reader)
            Bystander(counter: bystander)
        }
    }
}

@Suite @MainActor struct EnvironmentSignalsTests {

    private func makeRuntime(reader: RenderCounter, bystander: RenderCounter)
        -> (Runtime<MockBackend>, MockBackend, Sched) {
        let backend = MockBackend()
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SignalsRoot(reader: reader, bystander: bystander),
                              scheduleMicrotask: sched.schedule)
        runtime.mount()
        sched.drain()
        return (runtime, backend, sched)
    }

    @Test func defaultsOutsideRuntime() {
        #expect(EnvironmentValues().colorScheme == .light)
        #expect(EnvironmentValues().isOnline == true)
    }

    @Test func mountHandsWriterToBackend() {
        let (_, backend, _) = makeRuntime(reader: RenderCounter(), bystander: RenderCounter())
        #expect(backend.environmentWriter != nil)
        #expect(backend.counts["beginEnvironmentObservation"] == 1)
    }

    @Test func colorSchemeFlipRerendersOnlyReaders() {
        let reader = RenderCounter(); let bystander = RenderCounter()
        let (runtime, backend, sched) = makeRuntime(reader: reader, bystander: bystander)
        #expect(backend.serializeHTML().contains("light"))
        #expect(reader.n == 1); #expect(bystander.n == 1)

        backend.environmentWriter!.setColorScheme(.dark)
        sched.drain()
        #expect(backend.serializeHTML().contains("dark"))
        #expect(reader.n == 2)
        #expect(bystander.n == 1)   // non-reader untouched — precision claim of the spec
        _ = runtime   // keep alive — EnvironmentSignals.writer captures [weak self]
    }

    @Test func initialValueSeededBeforeFirstPass() {
        // Backend sets values inside beginEnvironmentObservation → first VDOM
        // already reflects them (hydration-correction leg). Simulate with a
        // backend subclass? No — MockBackend records; drive via a pre-mount writer:
        let backend = MockBackend()
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SignalsRoot(reader: RenderCounter(), bystander: RenderCounter()),
                              scheduleMicrotask: sched.schedule)
        // beginEnvironmentObservation runs first inside mount(); DOMBackend
        // writes initial values there. Emulate by setting through the runtime's
        // signals BEFORE renderPass — mount() order guarantees this window:
        runtime._signals._setColorScheme(.dark)
        runtime.mount()
        sched.drain()
        #expect(backend.serializeHTML().contains("dark"))
    }

    @Test func isOnlineFlip() {
        struct OnlineReader: Tag {
            @Environment(\.isOnline) var online
            var body: some Tag { Text(online ? "on" : "off") }
        }
        let backend = MockBackend(); let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: OnlineReader(), scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        #expect(backend.serializeHTML().contains("on"))
        backend.environmentWriter!.setOnline(false)
        sched.drain()
        #expect(backend.serializeHTML().contains("off"))
        _ = runtime   // keep alive
    }

    @Test func adoptingBackendForwards() {
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting.beginEnvironmentObservation(EnvironmentSignals().writer)
        #expect(base.environmentWriter != nil)
    }
}
