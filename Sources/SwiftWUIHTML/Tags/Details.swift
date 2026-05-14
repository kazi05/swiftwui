// Details.swift - HTML <details> element

import SwiftWUICore

/// Represents an HTML `<details>` element. The first `<summary>` child
/// acts as the disclosure trigger; subsequent children appear when open.
public struct Details: HTMLTag, TagNodeConvertible {
    public static let tagName = "details"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        open: Bool = false,
        class className: String? = nil,
        id: String? = nil,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if open { self.attributes["open"] = "true" }
        if let className { self.classes.append(className) }
        if let id { self.attributes["id"] = id }
    }
}
