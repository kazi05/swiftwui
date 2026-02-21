// Form.swift - HTML <form> element

import SwiftWUICore

/// Represents an HTML `<form>` element.
public struct Form: HTMLTag, TagNodeConvertible {
    public static let tagName = "form"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

    public init(
        action: String? = nil,
        method: FormMethod? = nil,
        onsubmit: EventHandler? = nil,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let action { self.attributes["action"] = action }
        if let method { self.attributes["method"] = method.rawValue }
        if let onsubmit { self.eventListeners["submit"] = onsubmit }
    }
}
