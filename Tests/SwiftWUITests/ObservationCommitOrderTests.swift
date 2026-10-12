#if compiler(>=6.4)
import Observation
import Testing
@testable import SwiftWUI

// Under the synchronous scheduler `{ $0() }` the willSet fallback (Swift 6.3, macOS 26 and
// older) renders one write behind, so these tests pin only the SE-0506 `.didSet` path.

@Observable private final class CommitOrderModel {
    var count = 0
    var label = "a"
    var flag = false
    var items: [Int] = []
}

@MainActor private final class CommitOrderTally {
    nonisolated deinit { }
    var counts: [Int] = []
}

private struct CommitOrderBody: Tag {
    let model: CommitOrderModel
    var body: some Tag {
        Div {
            Text("count=\(model.count)")
            Button("+") { model.count += 1 }
        }
    }
}

private struct CommitOrderForEach: Tag {
    let model: CommitOrderModel
    var body: some Tag {
        Div {
            ForEach(0..<1) { _ in Text("label=\(model.label)") }
        }
    }
}

private struct CommitOrderModifier: TagModifier {
    let model: CommitOrderModel
    func body(content: Content) -> some Tag {
        Div { Text("flag=\(model.flag)"); content }
    }
}

private struct CommitOrderModifierHost: Tag {
    let model: CommitOrderModel
    var body: some Tag { Span { Text("x") }.modifier(CommitOrderModifier(model: model)) }
}

private struct CommitOrderScroll: Tag {
    let model: CommitOrderModel
    var body: some Tag {
        ScrollReader(container: .window) { _ in
            Div { Text("items=\(model.items.count)") }
        }
    }
}

private struct CommitOrderTwoWrites: Tag {
    let model: CommitOrderModel
    let tally: CommitOrderTally
    var body: some Tag {
        // Stops reading after five renders, so a re-entrant loop fails the test instead of hanging it.
        let count = tally.counts.count < 5 ? model.count : -1
        tally.counts.append(count)
        return Div {
            Text("count=\(count)")
            Button("twice") { model.count = 1; model.count = 2 }
        }
    }
}

@Suite @MainActor struct ObservationCommitOrderTests {
    @Test @available(macOS 27, *) func immediateSchedulerRendersTheCommittedBody() {
        let model = CommitOrderModel()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: CommitOrderBody(model: model), scheduleMicrotask: { $0() })
        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        #expect(backend.serializeHTML().contains("count=1"), "\(backend.serializeHTML())")
        model.count = 5
        #expect(backend.serializeHTML().contains("count=5"), "\(backend.serializeHTML())")
    }

    @Test @available(macOS 27, *) func immediateSchedulerRendersTheCommittedForEachRow() {
        let model = CommitOrderModel()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: CommitOrderForEach(model: model), scheduleMicrotask: { $0() })
        runtime.mount()
        model.label = "b"
        #expect(backend.serializeHTML().contains("label=b"), "\(backend.serializeHTML())")
    }

    @Test @available(macOS 27, *) func immediateSchedulerRendersTheCommittedModifier() {
        let model = CommitOrderModel()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: CommitOrderModifierHost(model: model), scheduleMicrotask: { $0() })
        runtime.mount()
        model.flag = true
        #expect(backend.serializeHTML().contains("flag=true"), "\(backend.serializeHTML())")
    }

    @Test @available(macOS 27, *) func immediateSchedulerRendersAnInPlaceAppendInScrollReader() {
        let model = CommitOrderModel()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: CommitOrderScroll(model: model), scheduleMicrotask: { $0() })
        runtime.mount()
        model.items.append(1)
        #expect(backend.serializeHTML().contains("items=1"), "\(backend.serializeHTML())")
    }

    @Test @available(macOS 27, *) func immediateSchedulerRendersTheLastOfTwoWrites() {
        let model = CommitOrderModel()
        let tally = CommitOrderTally()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: CommitOrderTwoWrites(model: model, tally: tally),
                              scheduleMicrotask: { $0() })
        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        #expect(backend.serializeHTML().contains("count=2"), "\(backend.serializeHTML())")
        #expect(tally.counts == [0, 1, 2])
    }
}
#endif
