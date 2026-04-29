// TaskModifier.swift - .task modifier for running async work on mount

import SwiftWUICore

/// A tag wrapper that runs an async task when the element appears.
///
/// The mount handler is registered under a stable `identity` derived from
/// the `.task(_:)` call site (`#filePath:#line:#column`). This keeps the
/// resulting `EventListenerID` constant across re-renders so the reconciler
/// recognises the lifecycle observer as unchanged and does not re-fire the
/// mount callback every time the tag tree is rebuilt.
public struct TaskTag<Content: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let action: @Sendable () async -> Void
    private let identity: String

    public init(
        content: Content,
        action: @escaping @Sendable () async -> Void,
        identity: String
    ) {
        self.content = content
        self.action = action
        self.identity = identity
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
            let id = EventHandlerRegistry.register(
                {
                    #if canImport(JavaScriptKit)
                    Task { await taskAction() }
                    #endif
                },
                identity: identity
            )
            el.observers.append(.lifecycle(event: .mount, callbackID: id))
            nodes[0] = .element(el)
        }

        return nodes
    }
}

extension Tag {
    /// Run an async task when this element appears in the DOM.
    ///
    /// The handler fires once per element instance; subsequent re-renders at the
    /// same source location reuse the same handler identity and do not re-fire.
    public func task(
        _ action: @escaping @Sendable () async -> Void,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> TaskTag<Self> {
        TaskTag(
            content: self,
            action: action,
            identity: "task:\(file):\(line):\(column)"
        )
    }
}
