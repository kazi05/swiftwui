import Testing
import SwiftWUICore
@testable import SwiftWUIState

private func textNode(_ s: String) -> TagNode { .text(s) }

private struct Marker: SwiftWUICore.Tag, SwiftWUICore.TagNodeConvertible {
    typealias Body = Never
    let text: String
    func toTagNodes() -> [TagNode] { [textNode(text)] }
}

@Suite("AsyncBoundary")
struct AsyncBoundaryTests {
    @Test("idle resource renders the loading subtree")
    func idleRendersLoading() {
        let r = AsyncResource<String>()
        let boundary = AsyncBoundary(resource: r) {
            Marker(text: "loading")
        } error: { _ in
            Marker(text: "error")
        } success: { value in
            Marker(text: value)
        }
        let nodes = boundary.toTagNodes()
        guard case .text(let s) = nodes.first else {
            Issue.record("expected text"); return
        }
        #expect(s == "loading")
    }

    @Test("success resource renders the success subtree with the value")
    func successRendersValue() {
        let r = AsyncResource<String>("hello")
        let boundary = AsyncBoundary(resource: r) {
            Marker(text: "loading")
        } error: { _ in
            Marker(text: "error")
        } success: { v in
            Marker(text: v)
        }
        let nodes = boundary.toTagNodes()
        guard case .text(let s) = nodes.first else {
            Issue.record("expected text"); return
        }
        #expect(s == "hello")
    }

    @Test("failure resource renders the error subtree")
    func failureRendersError() async {
        struct Boom: Error {}
        let r = AsyncResource<String>()
        r.load { throw Boom() }
        for _ in 0..<10 {
            if r.error != nil { break }
            await Task.yield()
        }
        let boundary = AsyncBoundary(resource: r) {
            Marker(text: "loading")
        } error: { _ in
            Marker(text: "error")
        } success: { v in
            Marker(text: v)
        }
        let nodes = boundary.toTagNodes()
        guard case .text(let s) = nodes.first else {
            Issue.record("expected text"); return
        }
        #expect(s == "error")
    }
}
