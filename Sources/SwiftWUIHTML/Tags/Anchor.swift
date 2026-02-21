// Anchor.swift - HTML <a> element

import SwiftWUICore

/// Represents an HTML `<a>` (anchor) element.
public struct A: HTMLTag, TagNodeConvertible {
    public static let tagName = "a"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        href: String? = nil,
        target: Target? = nil,
        rel: String? = nil,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let href { self.attributes["href"] = href }
        if let target { self.attributes["target"] = target.htmlValue }
        if let rel { self.attributes["rel"] = rel }
    }
}
