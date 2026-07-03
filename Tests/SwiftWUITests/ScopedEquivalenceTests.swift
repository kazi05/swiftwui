import Testing
import Observation
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
/// ForEach, conditionals, sibling components with independent state — plus
/// styles: inline declarations, an element hover rule, a Styled component
/// with a dynamic (@State-driven) rule, a wrapper-styled component, an
/// environment writer/reader, an @Observable model, and an effect wrapper.
@Observable private final class PropModel { var flag = false }

private struct PropEnvKey: EnvironmentKey { static let defaultValue = "-" }
extension EnvironmentValues {
    fileprivate var propTag: String { get { self[PropEnvKey.self] } set { self[PropEnvKey.self] = newValue } }
}

private struct PropLeaf: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "leaf") {
            P { "n=\(n)" }
            Button("+") { n += 1 }
            if n % 3 == 1 { Span { "mod" } }
        }
        .padding(.px(4))                                   // inline style in the fixture
    }
}
private struct PropStyled: Tag, Styled {
    @State var hot = false
    @RulesBuilder var styles: [Rule] {
        Rule(class: "row") { $0.gap(.px(2)) }
        if hot { Rule(class: "row") { $0.gap(.px(20)) } }   // dynamic rule
    }
    var body: some Tag {
        Div(class: "row") {
            Button("heat") { hot.toggle() }
                .hover { $0.opacity(0.7) }                  // element rule
        }
    }
}
private struct PropObserved: Tag {
    let model: PropModel
    @Environment(\.propTag) var tag
    var body: some Tag {
        Div {
            Text(model.flag ? "on-\(tag)" : "off-\(tag)")
            Button("flip") { model.flag.toggle() }
        }
        .onAppear {}                                        // effect wrapper in the mix
    }
}
// Opaque boundary → the outer `.margin` sees `some Tag`, not `_StyledTag`, so
// wrappers stack (`_StyledTag<_StyledTag<PropObserved>>`) instead of collapsing.
private func propCard<T: Tag>(_ t: T) -> some Tag { t.padding(.px(2)) }

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
    let model = PropModel()
    var body: some Tag {
        Div {
            PropLeaf()
            PropStyled()
            propCard(PropObserved(model: model)).margin(.px(1)).hover { $0.opacity(0.9) }  // nested wrappers + rule classes
            if showList { PropList() }
            Button("toggle") { showList.toggle() }
        }
        .environment(\.propTag, "e")                        // environment writer
    }
}

@MainActor @Suite struct ScopedEquivalenceTests {
    /// Spec §2.4: a scoped pass must be byte-identical to a full pass.
    @Test(arguments: 0..<20) func scopedEqualsFull(seed: Int) throws {
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
            try #require(buttonsA.count == buttonsB.count)
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
            #expect(scoped._registryText == full._registryText,
                    "stylesheet diverged at seed \(seed)")
        }
    }
}

// @testable access helper: expose store/listeners counts for the invariant.
// Runtime's `store`/`listeners` are private; this reads via the `_store` and
// `_listenerCount` internal accessors declared on Runtime.
@MainActor private func scopedStore(_ rt: Runtime<MockBackend>) -> StateStore { rt._store }
