// Textarea.swift - HTML <textarea> element

import SwiftWUICore

/// Represents an HTML `<textarea>` element.
public struct Textarea: HTMLTag, TagNodeConvertible {
    public static let tagName = "textarea"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        name: String? = nil,
        placeholder: String? = nil,
        rows: Int? = nil,
        cols: Int? = nil,
        disabled: Bool = false,
        oninput: EventHandler? = nil,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let name { self.attributes["name"] = name }
        if let placeholder { self.attributes["placeholder"] = placeholder }
        if let rows { self.attributes["rows"] = String(rows) }
        if let cols { self.attributes["cols"] = String(cols) }
        if disabled { self.attributes["disabled"] = "true" }
        if let oninput { self.eventListeners["input"] = oninput }
    }
}
