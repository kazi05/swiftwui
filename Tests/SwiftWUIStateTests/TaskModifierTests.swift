import Testing
import SwiftWUICore
@testable import SwiftWUIState

/// Minimal element-producing tag fixture for unit tests that need observers
/// (Text nodes don't carry an element struct, so they cannot host observers).
private struct StubElement: SwiftWUICore.Tag, SwiftWUICore.TagNodeConvertible {
    typealias Body = Never
    func toTagNodes() -> [TagNode] {
        [.element(TagNode.Element(tagName: "div"))]
    }
}

@Suite("Task Modifier", .serialized)
struct TaskModifierTests {
    @Test("task wraps content transparently for text nodes")
    func taskWrapsTextContent() {
        let text = Text("Hello")
        let modified = text.task { }
        let nodes = resolveTagBody(modified)
        #expect(nodes.count == 1)
        // Text nodes don't have observers (no element), so it just passes through
        if case .text(let content) = nodes.first {
            #expect(content == "Hello")
        }
    }

    @Test("task attaches a mount lifecycle observer to the first element")
    func taskAttachesMountObserver() {
        let tag = StubElement().task { }
        let nodes = tag.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let mountObservers = el.observers.compactMap { obs -> EventListenerID? in
            if case .lifecycle(let event, let id) = obs, event == .mount { return id }
            return nil
        }
        #expect(mountObservers.count == 1)
    }

    @Test("task lifecycle callback ID is stable across re-renders at same call site")
    func taskHasStableCallbackIDAcrossRenders() {
        // Reset registry to ensure deterministic identity comparisons.
        EventHandlerRegistry.clear()
        func render() -> EventListenerID? {
            let tag = StubElement().task { }
            let nodes = tag.toTagNodes()
            guard case .element(let el) = nodes.first else { return nil }
            for obs in el.observers {
                if case .lifecycle(let event, let id) = obs, event == .mount {
                    return id
                }
            }
            return nil
        }
        let id1 = render()
        let id2 = render()
        let id3 = render()
        #expect(id1 != nil)
        #expect(id1 == id2)
        #expect(id2 == id3)
    }

    @Test("task at distinct call sites gets distinct callback IDs")
    func taskCallSitesHaveDistinctIDs() {
        EventHandlerRegistry.clear()
        func site1() -> EventListenerID? {
            let tag = StubElement().task { }
            let nodes = tag.toTagNodes()
            if case .element(let el) = nodes.first {
                for obs in el.observers {
                    if case .lifecycle(_, let id) = obs { return id }
                }
            }
            return nil
        }
        func site2() -> EventListenerID? {
            let tag = StubElement().task { }
            let nodes = tag.toTagNodes()
            if case .element(let el) = nodes.first {
                for obs in el.observers {
                    if case .lifecycle(_, let id) = obs { return id }
                }
            }
            return nil
        }
        #expect(site1() != site2())
    }
}
