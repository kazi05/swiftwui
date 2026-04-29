import Testing
@testable import SwiftWUICore

@Suite("ErrorBoundary")
struct ErrorBoundaryTests {
    enum Boom: Error { case stuff }

    @Test("non-throwing content renders its tags")
    func happyPath() {
        let boundary = ErrorBoundary(fallback: { _ in Text("fallback") }) {
            Text("ok")
        }
        let nodes = boundary.toTagNodes()
        #expect(nodes.count == 1)
        guard case .text(let s) = nodes.first else {
            Issue.record("expected text node")
            return
        }
        #expect(s == "ok")
    }

    @Test("throwing content renders the fallback")
    func errorPath() {
        let boundary = ErrorBoundary(fallback: { error in
            Text("caught: \(error)")
        }) { () throws -> any SwiftWUICore.Tag in
            throw Boom.stuff
        }
        let nodes = boundary.toTagNodes()
        guard case .text(let s) = nodes.first else {
            Issue.record("expected text node")
            return
        }
        #expect(s.contains("caught"))
    }

    @Test("onError callback fires before the fallback renders")
    func onErrorCalled() {
        final class Box: @unchecked Sendable { var captured: Error? }
        let box = Box()
        let boundary = ErrorBoundary(
            fallback: { _ in Text("fb") },
            onError: { box.captured = $0 }
        ) { () throws -> any SwiftWUICore.Tag in
            throw Boom.stuff
        }
        _ = boundary.toTagNodes()
        #expect(box.captured != nil)
    }
}
