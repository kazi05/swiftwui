// TaskModifier.swift - .task modifier for running async work on mount

import SwiftWUICore

/// A tag wrapper that runs an async task when the element appears.
public struct TaskTag<Content: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let action: @Sendable () async -> Void

    public init(content: Content, action: @escaping @Sendable () async -> Void) {
        self.content = content
        self.action = action
    }

    public func toTagNodes() -> [TagNode] {
        var nodes: [TagNode]
        if let convertible = content as? TagNodeConvertible {
            nodes = convertible.toTagNodes()
        } else {
            nodes = resolveTagBody(content)
        }

        // Mark the first element node with a lifecycle mount observer
        if case .element(var el) = nodes.first {
            let taskAction = action
            let id = EventHandlerRegistry.register {
                #if canImport(JavaScriptKit)
                Task { await taskAction() }
                #endif
            }
            el.observers.append(.lifecycle(event: .mount, callbackID: id))
            nodes[0] = .element(el)
        }

        return nodes
    }
}

extension Tag {
    /// Run an async task when this element appears in the DOM.
    public func task(_ action: @escaping @Sendable () async -> Void) -> TaskTag<Self> {
        TaskTag(content: self, action: action)
    }
}
