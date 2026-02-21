// Select.swift - HTML select/option elements

import SwiftWUICore

/// Represents an HTML `<select>` element.
public struct Select: HTMLTag, TagNodeConvertible {
    public static let tagName = "select"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

    public init(
        name: String? = nil,
        disabled: Bool = false,
        multiple: Bool = false,
        onchange: EventHandler? = nil,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let name { self.attributes["name"] = name }
        if disabled { self.attributes["disabled"] = "true" }
        if multiple { self.attributes["multiple"] = "true" }
        if let onchange { self.eventListeners["change"] = onchange }
    }
}

/// Represents an HTML `<option>` element.
public struct Option: HTMLTag, TagNodeConvertible {
    public static let tagName = "option"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

    public init(
        value: String? = nil,
        selected: Bool = false,
        disabled: Bool = false,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let value { self.attributes["value"] = value }
        if selected { self.attributes["selected"] = "true" }
        if disabled { self.attributes["disabled"] = "true" }
    }
}
