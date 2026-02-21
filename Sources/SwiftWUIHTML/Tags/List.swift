// List.swift - HTML list elements (ul, ol, li)

import SwiftWUICore

/// Represents an HTML `<ul>` (unordered list) element.
public struct Ul: HTMLTag, TagNodeConvertible {
    public static let tagName = "ul"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]
    }
}

/// Represents an HTML `<ol>` (ordered list) element.
public struct Ol: HTMLTag, TagNodeConvertible {
    public static let tagName = "ol"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]
    }
}

/// Represents an HTML `<li>` (list item) element.
public struct Li: HTMLTag, TagNodeConvertible {
    public static let tagName = "li"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]
    }
}
