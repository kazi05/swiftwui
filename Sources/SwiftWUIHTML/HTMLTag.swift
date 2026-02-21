// HTMLTag.swift - Base protocol for all HTML element tags

import SwiftWUICore

/// Closure type for event handlers on HTML elements.
public typealias EventHandler = @Sendable () -> Void

/// Base protocol for all HTML element tags.
/// Conforming types represent concrete HTML elements (div, span, p, etc.)
/// and render directly to DOM nodes (Body == Never).
public protocol HTMLTag: Tag where Body == Never {
    /// The HTML tag name (e.g., "div", "span", "p").
    static var tagName: String { get }

    /// HTML attributes (e.g., id, class, href).
    var attributes: [String: String] { get set }

    /// Event listeners keyed by event name (e.g., "click", "input").
    var eventListeners: [String: EventHandler] { get set }

    /// Inline CSS styles keyed by property name.
    var styles: [String: String] { get set }

    /// CSS class names.
    var classes: [String] { get set }

    /// Child tags wrapped in AnyTag.
    var children: [AnyTag] { get set }
}

// MARK: - TagNodeConvertible Conformance

extension HTMLTag {
    public func toTagNodes() -> [TagNode] {
        // Convert children to TagNodes
        let childNodes = children.flatMap { child -> [TagNode] in
            if let convertible = child as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(child)
        }

        // Register event handlers in the global registry and get unique IDs
        var listenerIDs: [String: EventListenerID] = [:]
        for (event, handler) in eventListeners {
            listenerIDs[event] = EventHandlerRegistry.register(handler)
        }

        let element = TagNode.Element(
            tagName: Self.tagName,
            attributes: attributes,
            styles: styles,
            classes: classes,
            eventListeners: listenerIDs,
            children: childNodes
        )

        return [.element(element)]
    }
}
