// EventAttribute.swift - Event-related types and helpers

import SwiftWUICore

/// Common DOM event names.
public enum EventName: String, Sendable {
    case click
    case input
    case change
    case submit
    case focus
    case blur
    case keydown
    case keyup
    case keypress
    case mouseenter
    case mouseleave
    case mouseover
    case mouseout
    case mousedown
    case mouseup
    case scroll
    case resize
    case load
    case unload
}

/// Convenience extensions for adding event listeners to HTML tags.
extension HTMLTag {
    /// Add an event listener for the given event name.
    public func on(_ event: EventName, handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.eventListeners[event.rawValue] = handler
        return copy
    }

    /// Add a click event listener.
    public func onClick(_ handler: @escaping EventHandler) -> Self {
        on(.click, handler: handler)
    }
}
