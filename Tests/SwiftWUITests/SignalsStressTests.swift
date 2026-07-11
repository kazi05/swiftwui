import Testing
@testable import SwiftWUI

@MainActor
private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

@MainActor private final class Tally { var bodies = 0 }

private struct StressReader: Tag {
    let tally: Tally
    @Environment(\.colorScheme) var scheme
    var body: some Tag {
        tally.bodies += 1
        return Span { Text(scheme == .dark ? "d" : "l") }
    }
}
private struct StressRoot: Tag {
    let tally: Tally
    var body: some Tag {
        Div {
            ForEach(0..<50, id: \.self) { _ in StressReader(tally: tally) }
        }
    }
}

@Suite @MainActor struct SignalsStressTests {

    @Test func fiftyReadersAllUpdate_flipsCoalesce() {
        let tally = Tally()
        let backend = MockBackend()
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: StressRoot(tally: tally), scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        #expect(tally.bodies == 50)

        // 10 rapid flips BEFORE the microtask drains → coalesced into one flush.
        let writer = backend.environmentWriter!
        for i in 0..<10 { writer.setColorScheme(i % 2 == 0 ? .dark : .light) }
        sched.drain()
        #expect(backend.serializeHTML().contains("l"))     // final value wins
        // One coalesced re-render of the 50 readers, not 10×50.
        #expect(tally.bodies == 100)
        _ = runtime
    }

    @Test func storageAndSignalsInterleaved() {
        struct Mixed: Tag {
            @Environment(\.colorScheme) var scheme
            @AppStorage("n") var n = 0
            var body: some Tag { Text("\(scheme == .dark ? "d" : "l"):\(n)") }
        }
        let backend = MockBackend(); let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Mixed(), scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        backend.environmentWriter!.setColorScheme(.dark)
        backend.simulateExternalStorageChange(kind: .local, key: "n", value: "7")
        sched.drain()
        #expect(backend.serializeHTML().contains("d:7"))
        _ = runtime
    }
}
