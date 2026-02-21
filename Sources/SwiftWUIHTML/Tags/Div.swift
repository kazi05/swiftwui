// Div.swift - HTML <div> element

import SwiftWUICore

/// Represents an HTML `<div>` element.
public struct Div: HTMLTag, TagNodeConvertible {
    public static let tagName = "div"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

    public init(
        class className: String? = nil,
        id: String? = nil,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let className { self.classes.append(className) }
        if let id { self.attributes["id"] = id }
    }
}
