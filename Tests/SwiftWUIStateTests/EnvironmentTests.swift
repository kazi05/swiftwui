import Testing
import SwiftWUICore
@testable import SwiftWUIState

private struct ColorKey: EnvironmentKey {
    static let defaultValue: String = "default"
}

extension EnvironmentValues {
    fileprivate var color: String {
        get { self[ColorKey.self] }
        set { self[ColorKey.self] = newValue }
    }
}

/// Tag fixture that emits the current `\.color` environment value as text.
private struct ColorReader: SwiftWUICore.Tag, SwiftWUICore.TagNodeConvertible {
    typealias Body = Never
    func toTagNodes() -> [TagNode] {
        // Read through the task-local environment view that
        // `.environment(_:_:)` mutates for its subtree.
        let value = EnvironmentValues.current.color
        return [.text(value)]
    }
}

@Suite("Environment", .serialized)
struct EnvironmentTests {
    @Test("default value flows when no .environment is applied")
    func defaultValue() {
        let nodes = ColorReader().toTagNodes()
        guard case .text(let s) = nodes.first else {
            Issue.record("expected text node")
            return
        }
        #expect(s == "default")
    }

    @Test(".environment overrides for descendants")
    func overrideForDescendants() {
        let tree = ColorReader().environment(\.color, "red")
        let nodes = tree.toTagNodes()
        guard case .text(let s) = nodes.first else {
            Issue.record("expected text node")
            return
        }
        #expect(s == "red")
    }

    @Test(".environment scope is bounded — siblings outside see the default")
    func scopeIsBounded() {
        // Inside the override block, the reader sees "red".
        // After the call returns, a freshly-resolved reader sees "default".
        let inside = ColorReader().environment(\.color, "red").toTagNodes()
        let outside = ColorReader().toTagNodes()
        guard case .text(let a) = inside.first, case .text(let b) = outside.first else {
            Issue.record("expected text nodes")
            return
        }
        #expect(a == "red")
        #expect(b == "default")
    }
}
