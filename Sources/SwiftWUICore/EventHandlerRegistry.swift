// EventHandlerRegistry.swift - Global registry for event handler closures

import Foundation

/// Global registry mapping EventListenerIDs to their closures.
///
/// When a Tag tree is converted to TagNodes, event handler closures are
/// stored here with unique IDs. The DOMRenderer looks up closures by ID
/// when attaching event listeners to real DOM elements.
///
/// This registry is cleared at the start of each render cycle and repopulated
/// during Tag → TagNode conversion.
public enum EventHandlerRegistry {
    nonisolated(unsafe) private static var handlers: [String: @Sendable () -> Void] = [:]

    /// Register a handler and return a unique EventListenerID.
    public static func register(_ handler: @escaping @Sendable () -> Void) -> EventListenerID {
        let id = UUID().uuidString
        handlers[id] = handler
        return EventListenerID(id)
    }

    /// Look up a handler by its ID.
    public static func handler(for id: EventListenerID) -> (@Sendable () -> Void)? {
        handlers[id.id]
    }

    /// Clear all registered handlers. Called at the start of each render cycle.
    public static func clear() {
        handlers.removeAll()
    }
}
