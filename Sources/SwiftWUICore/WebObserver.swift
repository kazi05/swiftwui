/// Represents a JavaScript observer to be attached to a DOM element.
/// Stored in TagNode.Element and managed by DOMRenderer.
public enum WebObserver: Equatable, Sendable {
    /// IntersectionObserver — fires when element enters/exits viewport.
    case intersection(threshold: Double, callbackID: EventListenerID)
    /// ResizeObserver — fires when element size changes.
    case resize(callbackID: EventListenerID)
    /// MutationObserver — fires on DOM subtree changes.
    case mutation(options: MutationOptions, callbackID: EventListenerID)
    /// Lifecycle event — mount/unmount hooks.
    case lifecycle(event: LifecycleEvent, callbackID: EventListenerID)
}

/// Configuration for MutationObserver.
public struct MutationOptions: Equatable, Sendable {
    public var childList: Bool
    public var attributes: Bool
    public var subtree: Bool

    public init(childList: Bool = false, attributes: Bool = false, subtree: Bool = false) {
        self.childList = childList
        self.attributes = attributes
        self.subtree = subtree
    }
}

/// Lifecycle events for DOM elements.
public enum LifecycleEvent: Equatable, Sendable {
    case mount
    case unmount
}
