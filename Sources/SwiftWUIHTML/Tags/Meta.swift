// Meta.swift - HTML head/meta elements (link, script, style, meta)

import SwiftWUICore

/// Represents an HTML `<link>` element.
/// Renamed to HTMLLink to avoid collision with Swift's standard library.
public struct HTMLLink: HTMLTag, TagNodeConvertible {
    public static let tagName = "link"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        rel: String,
        href: String,
        type: String? = nil
    ) {
        self.attributes = ["rel": rel, "href": href]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = []

        if let type { self.attributes["type"] = type }
    }
}

/// Represents an HTML `<script>` element.
public struct Script: HTMLTag, TagNodeConvertible {
    public static let tagName = "script"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        src: String? = nil,
        type: String? = nil,
        async: Bool = false,
        defer: Bool = false,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if let src { self.attributes["src"] = src }
        if let type { self.attributes["type"] = type }
        if async { self.attributes["async"] = "true" }
        if `defer` { self.attributes["defer"] = "true" }
    }
}

/// Represents an HTML `<style>` element.
/// Renamed to HTMLStyle to avoid collision with Swift's standard library.
public struct HTMLStyle: HTMLTag, TagNodeConvertible {
    public static let tagName = "style"

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

/// Represents an HTML `<meta>` element.
/// Renamed to HTMLMeta to avoid potential naming conflicts.
/// This is a self-closing tag with no children.
public struct HTMLMeta: HTMLTag, TagNodeConvertible {
    public static let tagName = "meta"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        name: String? = nil,
        content: String? = nil,
        charset: String? = nil,
        httpEquiv: String? = nil
    ) {
        self.attributes = [:]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = []

        if let name { self.attributes["name"] = name }
        if let content { self.attributes["content"] = content }
        if let charset { self.attributes["charset"] = charset }
        if let httpEquiv { self.attributes["http-equiv"] = httpEquiv }
    }
}
