import Testing
import Foundation
@testable import SwiftWUI

private struct BurstRow: Tag {
    let id: Int
    @State private var value = 0

    var body: some Tag {
        Button("\(id):\(value)") { value += 1 }
    }
}

private struct BurstFixture: Tag {
    let count: Int
    var body: some Tag {
        Div {
            ForEach(0..<count) { BurstRow(id: $0) }
        }
    }
}

/// Reproducible algorithm benchmark for the sibling-burst shape that exposed
/// the former cover scan. Wall times are reported for local comparison; the
/// asserted contract is the selected cover, not a machine-specific deadline.
// The legacy comparison deliberately spends seconds on the main actor. Keep
// it out of concurrent behavioral tests, where it can starve gesture timers.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SWIFTWUI_BENCHMARKS"] == "1"))
@MainActor struct RuntimeDirtyCoverBenchmarkTests {
    private func legacyMinimalCover(_ ids: Set<NodeIdentity>) -> [NodeIdentity] {
        var cover: [NodeIdentity] = []
        for id in ids.sorted(by: { $0.segments.count < $1.segments.count }) {
            if !cover.contains(where: { id.isSelfOrDescendant(of: $0) }) {
                cover.append(id)
            }
        }
        return cover
    }

    @Test(arguments: [50, 100, 500])
    func dirtySiblingBurst(size: Int) {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: EmptyTag(), scheduleMicrotask: { _ in })
        let parent = NodeIdentity.root.appending(.child(0))
        let ids = Set((0..<size).map { parent.appending(.keyed(NodeKey($0))) })
        let clock = ContinuousClock()

        let legacyStarted = clock.now
        var legacyCover: [NodeIdentity] = []
        for _ in 0..<100 { legacyCover = legacyMinimalCover(ids) }
        let legacyElapsed = legacyStarted.duration(to: clock.now)

        let started = clock.now
        var cover: [NodeIdentity] = []
        for _ in 0..<100 { cover = runtime.minimalCover(ids) }
        let elapsed = started.duration(to: clock.now)

        #expect(cover.count == size)
        #expect(Set(cover) == Set(legacyCover))
        print("SwiftWUI dirty-cover benchmark: siblings=\(size), iterations=100, legacy=\(legacyElapsed), ancestor-lookup=\(elapsed)")
    }

    @Test(arguments: [50, 100, 500])
    func coalescedRuntimeBurst(size: Int) {
        let backend = MockBackend()
        let scheduler = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: BurstFixture(count: size),
                              scheduleMicrotask: scheduler.schedule)
        runtime.mount()
        let buttons = findAll(backend.container, tag: "button")
        let textWritesBefore = backend.counts["setText", default: 0]
        for button in buttons { runtime.dispatch(button.events["click"]!) }

        let clock = ContinuousClock()
        let started = clock.now
        scheduler.pump()
        let elapsed = started.duration(to: clock.now)

        #expect(backend.counts["setText", default: 0] - textWritesBefore == size)
        print("SwiftWUI runtime burst benchmark: siblings=\(size), elapsed=\(elapsed)")
    }
}
