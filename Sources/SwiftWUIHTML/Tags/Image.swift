// Image.swift - HTML <img> element (self-closing)

import SwiftWUICore

/// Represents an HTML `<img>` element.
/// This is a self-closing tag with no children.
public struct Img: HTMLTag, TagNodeConvertible {
    public static let tagName = "img"

    public var attributes: [String: String]
    public var eventListeners: [String: EventHandler]
    public var styles: [String: String]
    public var classes: [String]
    public var children: [AnyTag]

    public init(
        src: String,
        alt: String = "",
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.attributes = ["src": src, "alt": alt]
        self.eventListeners = [:]
        self.styles = [:]
        self.classes = []
        self.children = []

        if let width { self.attributes["width"] = String(width) }
        if let height { self.attributes["height"] = String(height) }
    }
}
