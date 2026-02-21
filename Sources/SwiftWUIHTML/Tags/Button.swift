// Button.swift - HTML <button> element

import SwiftWUICore

/// Represents an HTML `<button>` element.
public struct Button: HTMLTag, TagNodeConvertible {
    public static let tagName = "button"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        type: ButtonType = .button,
        disabled: Bool = false,
        onclick: EventHandler? = nil,
        @TagBuilder content: () -> some Tag = { EmptyTag() }
    ) {
        self.attributes = ["type": type.rawValue]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = [AnyTag(content())]

        if disabled { self.attributes["disabled"] = "true" }
        if let onclick { self.eventListeners["click"] = onclick }
    }
}
