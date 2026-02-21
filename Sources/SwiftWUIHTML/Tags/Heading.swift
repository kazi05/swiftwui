// Heading.swift - HTML heading elements (h1-h6)

import SwiftWUICore

/// Represents an HTML `<h1>` element.
public struct H1: HTMLTag, TagNodeConvertible {
    public static let tagName = "h1"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

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

/// Represents an HTML `<h2>` element.
public struct H2: HTMLTag, TagNodeConvertible {
    public static let tagName = "h2"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

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

/// Represents an HTML `<h3>` element.
public struct H3: HTMLTag, TagNodeConvertible {
    public static let tagName = "h3"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

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

/// Represents an HTML `<h4>` element.
public struct H4: HTMLTag, TagNodeConvertible {
    public static let tagName = "h4"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

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

/// Represents an HTML `<h5>` element.
public struct H5: HTMLTag, TagNodeConvertible {
    public static let tagName = "h5"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

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

/// Represents an HTML `<h6>` element.
public struct H6: HTMLTag, TagNodeConvertible {
    public static let tagName = "h6"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

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
