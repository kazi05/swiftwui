import Foundation
import Testing
@testable import SwiftWUI

private struct Counter: Tag {
    @State var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("+") { count += 1 }
            if count >= 3 { P { "big" } }
        }
    }
}
private struct TwoCounters: Tag {
    var body: some Tag {
        Counter()
        Counter()
    }
}
private struct Toggle: Tag {
    @State var on = true
    var body: some Tag {
        Div {
            if on { Counter() } else { P { "off" } }
            Button("t") { on.toggle() }
        }
    }
}
private struct Item: Identifiable { let id: Int }
private struct KeyedList: Tag {
    @State var items = [Item(id: 1), Item(id: 2)]
    var body: some Tag {
        Div {
            ForEach(items) { _ in Counter() }
            Button("rev") { items.reverse() }
        }
    }
}

/// Manual microtask pump: collects scheduled closures; pump() drains them.
@MainActor final class TestScheduler {
    private var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func pump() { while !queue.isEmpty { queue.removeFirst()() } }
}

@MainActor
func findFirst(_ node: MockNode, tag: String) -> MockNode? {
    if node.tag == tag { return node }
    for c in node.children { if let f = findFirst(c, tag: tag) { return f } }
    return nil
}
@MainActor
func findAll(_ node: MockNode, tag: String) -> [MockNode] {
    var out: [MockNode] = []
    if node.tag == tag { out.append(node) }
    for c in node.children { out += findAll(c, tag: tag) }
    return out
}
@MainActor
func clickFirst<Backend: RendererBackend>(_ backend: MockBackend, _ runtime: Runtime<Backend>,
                tag: String, index: Int = 0, sched: TestScheduler) where Backend.HostNode == MockNode {
    let buttons = findAll(backend.container, tag: tag)
    runtime.dispatch(buttons[index].events["click"]!)
    sched.pump()
}

@Suite @MainActor struct RuntimeE2ETests {
    func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount()
        return (runtime, backend, sched)
    }

    @Test func counterClickUpdatesText() {
        let (runtime, backend, sched) = makeRuntime(Counter())
        #expect(backend.serializeHTML().contains("Count: 0"))
        clickFirst(backend, runtime, tag: "button", sched: sched)
        #expect(backend.serializeHTML().contains("Count: 1"))
        #expect(!backend.serializeHTML().contains("Count: 0"))
    }
    @Test func normalUpdateHasZeroListenerChurn() {
        let (runtime, backend, sched) = makeRuntime(Counter())
        let sets = backend.counts["setEventListener", default: 0]
        let removes = backend.counts["removeEventListener", default: 0]
        clickFirst(backend, runtime, tag: "button", sched: sched)
        #expect(backend.counts["setEventListener", default: 0] == sets)      // spec §8.5
        #expect(backend.counts["removeEventListener", default: 0] == removes)
    }
    @Test func coalescedWritesOneRender() {
        let (runtime, backend, sched) = makeRuntime(Counter())
        let button = findFirst(backend.container, tag: "button")!
        let setTextsBefore = backend.counts["setText", default: 0]
        runtime.dispatch(button.events["click"]!)
        runtime.dispatch(button.events["click"]!)     // second write before pump
        sched.pump()                                  // ONE flush
        #expect(backend.serializeHTML().contains("Count: 2"))
        // Two coalesced writes → exactly one render pass, not two.
        #expect(backend.counts["setText", default: 0] - setTextsBefore == 1)
    }
    @Test func siblingCountersIndependent() {
        let (runtime, backend, sched) = makeRuntime(TwoCounters())
        clickFirst(backend, runtime, tag: "button", index: 0, sched: sched)
        clickFirst(backend, runtime, tag: "button", index: 0, sched: sched)
        let html = backend.serializeHTML()
        #expect(html.contains("Count: 2"))
        #expect(html.contains("Count: 0"))            // second counter untouched
    }
    @Test func branchToggleResetsState() {
        let (runtime, backend, sched) = makeRuntime(Toggle())
        clickFirst(backend, runtime, tag: "button", index: 0, sched: sched)   // Counter's +
        #expect(backend.serializeHTML().contains("Count: 1"))
        // toggle off (last button is "t"), then back on:
        var buttons = findAll(backend.container, tag: "button")
        runtime.dispatch(buttons.last!.events["click"]!); sched.pump()
        #expect(backend.serializeHTML().contains("off"))
        buttons = findAll(backend.container, tag: "button")
        runtime.dispatch(buttons.last!.events["click"]!); sched.pump()
        #expect(backend.serializeHTML().contains("Count: 0"))                 // reset (SwiftUI parity)
    }
    @Test func forEachReorderPreservesPerItemState() {
        let (runtime, backend, sched) = makeRuntime(KeyedList())
        clickFirst(backend, runtime, tag: "button", index: 0, sched: sched)   // first item's counter → 1
        let before = backend.serializeHTML()
        #expect(before.range(of: "Count: 1")!.lowerBound < before.range(of: "Count: 0")!.lowerBound)
        let buttons = findAll(backend.container, tag: "button")
        runtime.dispatch(buttons.last!.events["click"]!); sched.pump()        // reverse
        let html = backend.serializeHTML()
        #expect(html.range(of: "Count: 0")!.lowerBound < html.range(of: "Count: 1")!.lowerBound)  // state moved WITH the item
    }
    @Test func conditionalAppearanceMountsNewSubtree() {
        let (runtime, backend, sched) = makeRuntime(Counter())
        for _ in 0..<3 { clickFirst(backend, runtime, tag: "button", sched: sched) }
        #expect(backend.serializeHTML().contains("<p>big</p>"))
    }
}
