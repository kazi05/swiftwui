import Testing
import SwiftWUICore
import SwiftWUIState
@testable import SwiftWUIRuntime

/// `.task` registered its mount handler under a call-site-only identity
/// (`#filePath:#line:#column`), so two instances of the same component (e.g.
/// rows in a ForEach) shared one identity: fire-time lookup returned whichever
/// closure registered last, and every row ran the last instance's work. Scoping
/// the identity by structural path gives each instance its own handler.
@Suite("task instance identity")
struct TaskIdentityTests {

    /// Minimal primitive element so `.task` (which attaches to the first element
    /// node) has something to bind to, without importing the HTML module.
    struct El: SwiftWUICore.Tag, TagNodeConvertible {
        typealias Body = Never
        func toTagNodes() -> [TagNode] { [.element(.init(tagName: "div"))] }
    }

    struct Row: SwiftWUICore.Tag {
        let n: Int
        var body: some SwiftWUICore.Tag {
            El().task { _ = n }
        }
    }

    struct List: SwiftWUICore.Tag {
        var body: some SwiftWUICore.Tag {
            Row(n: 1)
            Row(n: 2)
        }
    }

    private func lifecycleIDs(in node: TagNode) -> [String] {
        switch node {
        case .text:
            return []
        case .element(let e):
            let own = e.observers.compactMap { obs -> String? in
                if case .lifecycle(_, let cb) = obs { return cb.id }
                return nil
            }
            return own + e.children.flatMap { lifecycleIDs(in: $0) }
        case .fragment(let cs):
            return cs.flatMap { lifecycleIDs(in: $0) }
        }
    }

    @Test("two instances register distinct .task mount handlers")
    func distinctTaskIdentity() {
        let r = TestRenderer()
        r.render(List())
        guard let tree = r.latestTree else {
            Issue.record("no tree rendered")
            return
        }
        let ids = lifecycleIDs(in: tree)
        #expect(ids.count == 2)
        #expect(Set(ids).count == 2)
    }
}
