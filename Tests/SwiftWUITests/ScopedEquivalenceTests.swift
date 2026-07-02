import Testing
@testable import SwiftWUI

/// Deterministic PRNG so failures reproduce by seed.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Fixture exercising every structural feature: nested components, keyed
/// ForEach, conditionals, sibling components with independent state.
private struct PropLeaf: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "leaf") {
            P { "n=\(n)" }
            Button("+") { n += 1 }
            if n % 3 == 1 { Span { "mod" } }
        }
    }
}
private struct PropList: Tag {
    @State var items = [1, 2, 3]
    var body: some Tag {
        Div(class: "list") {
            ForEach(items, id: \.self) { _ in PropLeaf() }
            Button("rot") { if let f = items.first { items = Array(items.dropFirst()) + [f] } }
            Button("add") { items.append((items.max() ?? 0) + 1) }
        }
    }
}
private struct PropRoot: Tag {
    @State var showList = true
    var body: some Tag {
        Div {
            PropLeaf()
            if showList { PropList() }
            Button("toggle") { showList.toggle() }
        }
    }
}

@MainActor @Suite struct ScopedEquivalenceTests {
    /// Spec §2.4: a scoped pass must be byte-identical to a full pass.
    @Test(arguments: 0..<20) func scopedEqualsFull(seed: Int) {
        let schedA = TestScheduler(), schedB = TestScheduler()
        let backA = MockBackend(), backB = MockBackend()
        let scoped = Runtime(backend: backA, container: backA.container,
                             root: PropRoot(), scheduleMicrotask: schedA.schedule)
        let full = Runtime(backend: backB, container: backB.container,
                           root: PropRoot(), scheduleMicrotask: schedB.schedule)
        full._forceFullPasses = true
        scoped.mount(); full.mount()

        var rng = SplitMix64(state: UInt64(seed) &+ 1)
        for _ in 0..<25 {
            // identical random event sequence against both runtimes
            let buttonsA = findAll(backA.container, tag: "button")
            let buttonsB = findAll(backB.container, tag: "button")
            #expect(buttonsA.count == buttonsB.count)
            guard !buttonsA.isEmpty else { break }
            let pick = Int(rng.next() % UInt64(buttonsA.count))
            // occasionally batch two dispatches into one flush (coalescing path)
            let batch = rng.next() % 4 == 0 && buttonsA.count > 1
            scoped.dispatch(buttonsA[pick].events["click"]!)
            full.dispatch(buttonsB[pick].events["click"]!)
            if batch {
                let second = (pick + 1) % buttonsA.count
                scoped.dispatch(buttonsA[second].events["click"]!)
                full.dispatch(buttonsB[second].events["click"]!)
            }
            schedA.pump(); schedB.pump()

            #expect(backA.serializeHTML() == backB.serializeHTML(),
                    "diverged at seed \(seed)")
            #expect(scopedStore(scoped).rowCount == scopedStore(full).rowCount)
            #expect(scoped._current == full._current, "current trees diverged at seed \(seed)")
            #expect(scoped._listenerCount == full._listenerCount)
        }
    }
}

// @testable access helper: expose store/listeners counts for the invariant.
// Runtime's `store`/`listeners` are private; this reads via the `_store` and
// `_listenerCount` internal accessors declared on Runtime.
@MainActor private func scopedStore(_ rt: Runtime<MockBackend>) -> StateStore { rt._store }
