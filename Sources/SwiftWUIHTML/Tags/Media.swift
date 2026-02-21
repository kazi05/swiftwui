// Media.swift - HTML media elements (video, audio, source)

import SwiftWUICore

/// Represents an HTML `<video>` element.
public struct Video: HTMLTag, TagNodeConvertible {
    public static let tagName = "video"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        src: String? = nil,
        controls: Bool = false,
        autoplay: Bool = false,
        loop: Bool = false,
        muted: Bool = false,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let src { self.attributes["src"] = src }
        if controls { self.attributes["controls"] = "true" }
        if autoplay { self.attributes["autoplay"] = "true" }
        if loop { self.attributes["loop"] = "true" }
        if muted { self.attributes["muted"] = "true" }
    }
}

/// Represents an HTML `<audio>` element.
public struct Audio: HTMLTag, TagNodeConvertible {
    public static let tagName = "audio"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        src: String? = nil,
        controls: Bool = false,
        autoplay: Bool = false,
        loop: Bool = false,
        muted: Bool = false,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let src { self.attributes["src"] = src }
        if controls { self.attributes["controls"] = "true" }
        if autoplay { self.attributes["autoplay"] = "true" }
        if loop { self.attributes["loop"] = "true" }
        if muted { self.attributes["muted"] = "true" }
    }
}

/// Represents an HTML `<source>` element.
/// This is a self-closing tag with no children.
public struct Source: HTMLTag, TagNodeConvertible {
    public static let tagName = "source"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        src: String,
        type: String? = nil
    ) {
        self.attributes = ["src": src]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = []

        if let type { self.attributes["type"] = type }
    }
}
