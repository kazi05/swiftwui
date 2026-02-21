// Tag.swift - Core protocol for all SwiftWUI elements

/// The fundamental protocol for building web UI trees in SwiftWUI.
/// Analogous to SwiftUI's `View` protocol.
///
/// Conform to `Tag` to create custom components:
/// ```swift
/// struct MyComponent: Tag {
///     var body: some Tag {
///         Div { Text("Hello") }
///     }
/// }
/// ```
public protocol Tag {
    associatedtype Body: Tag
    @TagBuilder var body: Body { get }
}

// MARK: - Primitive Tags (body = Never)

/// Primitive tags (HTML elements) have `Never` as their body type
/// since they render directly to DOM nodes.
extension Tag where Body == Never {
    public var body: Never {
        fatalError("Primitive tags do not have a body. This should never be called.")
    }
}

extension Never: Tag {
    public typealias Body = Never
}

// MARK: - Optional Tag Conformance

extension Optional: Tag where Wrapped: Tag {
    public typealias Body = Never

    public var body: Never {
        fatalError("Optional<Tag> is a primitive composition type.")
    }
}
