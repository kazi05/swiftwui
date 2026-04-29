// CodeBlock.swift - HTML <pre> and <code> elements for source-code blocks.

import SwiftWUICore

/// Represents an HTML `<pre>` element — a preformatted text block that
/// preserves whitespace and line breaks. Typically wraps a `Code` child
/// for syntax-highlightable source listings.
public struct Pre: HTMLTag, TagNodeConvertible {
    public static let tagName = "pre"

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

/// Represents an HTML `<code>` element — inline source code. Inside a
/// `Pre` becomes the syntax-highlightable target for highlight.js when
/// given a `language-<lang>` class.
public struct Code: HTMLTag, TagNodeConvertible {
    public static let tagName = "code"

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
