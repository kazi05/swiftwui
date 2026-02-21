// Text.swift - Text node representation

/// Represents a text node in the DOM.
/// Can be used directly or created implicitly from string literals in `@TagBuilder`.
///
/// ```swift
/// Div {
///     Text("Hello, World!")
///     "Or like this"  // implicitly converted to Text
/// }
/// ```
public struct Text: Tag, Sendable {
    public typealias Body = Never

    public let content: String

    public init(_ content: String) {
        self.content = content
    }
}

extension Text: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.content = value
    }
}

extension Text: ExpressibleByStringInterpolation {}
