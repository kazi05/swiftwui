// ModifiedContent.swift - Wraps a tag with style/attribute modifications

/// Wraps a tag with additional styles, classes, or attributes applied via modifier methods.
///
/// Created by calling modifier methods like `.backgroundColor()`, `.padding()`, `.class()`.
///
/// ```swift
/// Div { Text("Hello") }
///     .backgroundColor(.red)  // returns ModifiedContent<Div, ...>
///     .padding(.px(16))       // returns ModifiedContent<ModifiedContent<Div, ...>, ...>
/// ```
public struct ModifiedContent<Content: Tag>: Tag {
    public typealias Body = Never

    public let content: Content
    public var styles: [(String, String)]
    public var classes: [String]
    public var attributes: [(String, String)]

    public init(
        content: Content,
        styles: [(String, String)] = [],
        classes: [String] = [],
        attributes: [(String, String)] = []
    ) {
        self.content = content
        self.styles = styles
        self.classes = classes
        self.attributes = attributes
    }
}

// MARK: - Base Tag Modifiers

extension Tag {
    /// Add an inline CSS style property.
    public func style(_ property: String, _ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [(property, value)])
    }

    /// Add a CSS class name.
    public func `class`(_ name: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, classes: [name])
    }

    /// Add an HTML attribute.
    public func attribute(_ name: String, _ value: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, attributes: [(name, value)])
    }
}

// MARK: - Chaining on ModifiedContent

extension ModifiedContent {
    /// Add another inline CSS style property.
    public func style(_ property: String, _ value: String) -> ModifiedContent<Content> {
        var copy = self
        copy.styles.append((property, value))
        return copy
    }

    /// Add another CSS class name.
    public func `class`(_ name: String) -> ModifiedContent<Content> {
        var copy = self
        copy.classes.append(name)
        return copy
    }

    /// Add another HTML attribute.
    public func attribute(_ name: String, _ value: String) -> ModifiedContent<Content> {
        var copy = self
        copy.attributes.append((name, value))
        return copy
    }
}
