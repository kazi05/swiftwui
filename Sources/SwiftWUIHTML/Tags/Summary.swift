// Summary.swift - HTML <summary> element

import SwiftWUICore

/// Represents an HTML `<summary>` element. Used as the first child of a
/// `<details>` to provide the visible label/disclosure control.
public struct Summary: HTMLTag, TagNodeConvertible {
    public static let tagName = "summary"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

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
