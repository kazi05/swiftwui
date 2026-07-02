import Testing
@testable import SwiftWUI

/// Body-evaluation counter: explicit `return` disables the builder transform,
/// so plain statements are allowed before it.
private final class Counters { var byLabel: [String: Int] = [:]
                               func bump(_ l: String) { byLabel[l, default: 0] += 1 } }

private struct LeafCounter: Tag {
    let label: String
    let counters: Counters
    @State var n = 0
    var body: some Tag {
        counters.bump(label)
        return Div(class: label) {
            P { "\(label): \(n)" }
            Button("+") { n += 1 }
        }
    }
}
private struct TwoLeaves: Tag {
    let counters: Counters
    var body: some Tag {
        counters.bump("parent")
        return Div {
            LeafCounter(label: "a", counters: counters)
            LeafCounter(label: "b", counters: counters)
        }
    }
}

@MainActor @Suite struct ScopedInvalidationTests {
    @Test func dirtyLeafRerendersOnlyItself() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TwoLeaves(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(counters.byLabel == ["parent": 1, "a": 1, "b": 1])

        let buttons = findAll(backend.container, tag: "button")
        rt.dispatch(buttons[0].events["click"]!)              // leaf a
        sched.pump()
        #expect(counters.byLabel == ["parent": 1, "a": 2, "b": 1])   // b and parent untouched
        #expect(findAll(backend.container, tag: "p")[0].children[0].text == "a: 1")
    }

    @Test func coalescedDirtSiblingsBothRerenderOnce() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TwoLeaves(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        let buttons = findAll(backend.container, tag: "button")
        rt.dispatch(buttons[0].events["click"]!)
        rt.dispatch(buttons[1].events["click"]!)
        sched.pump()                                          // ONE flush, two survivors
        #expect(counters.byLabel == ["parent": 1, "a": 2, "b": 2])
    }

    @Test func dirtyParentCoversDirtyChild() {
        // parent + child dirty in same flush → minimal cover = parent only
        let ids: Set<NodeIdentity> = {
            let p = NodeIdentity.root.appending(.type(ObjectIdentifier(TwoLeaves.self)))
            let c = p.appending(.child(0)).appending(.type(ObjectIdentifier(LeafCounter.self)))
            return [p, c]
        }()
        let backend = MockBackend()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TwoLeaves(counters: Counters()), scheduleMicrotask: { _ in })
        #expect(rt.minimalCover(ids).count == 1)
    }

    @Test func removedComponentDirtIsSkipped() {
        // toggle removes a subtree; a stale dirty id for it must be a no-op
        struct Host: Tag {
            @State var on = true
            var body: some Tag {
                Div {
                    if on { P { "on" } }
                    Button("t") { on.toggle() }
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Host(), scheduleMicrotask: sched.schedule)
        rt.mount()
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, tag: "p") == nil)   // no crash, subtree gone
    }
}
