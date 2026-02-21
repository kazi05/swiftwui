// Input.swift - HTML <input> element (self-closing)

import SwiftWUICore

/// Represents an HTML `<input>` element.
/// This is a self-closing tag with no children.
public struct Input: HTMLTag, TagNodeConvertible {
    public static let tagName = "input"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]
    public var observers: [WebObserver] = []

    public init(
        type: InputType = .text,
        placeholder: String? = nil,
        value: String? = nil,
        name: String? = nil,
        disabled: Bool = false,
        oninput: EventHandler? = nil
    ) {
        self.attributes = ["type": type.rawValue]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = []

        if let placeholder { self.attributes["placeholder"] = placeholder }
        if let value { self.attributes["value"] = value }
        if let name { self.attributes["name"] = name }
        if disabled { self.attributes["disabled"] = "true" }
        if let oninput { self.eventListeners["input"] = oninput }
    }
}
