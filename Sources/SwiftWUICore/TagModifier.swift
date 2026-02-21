// TagModifier.swift - Reusable custom tag modifiers (like SwiftUI's ViewModifier)

/// A protocol for defining reusable tag modifications.
///
/// Use `TagModifier` to create custom modifiers that can be applied to any tag.
/// This is analogous to SwiftUI's `ViewModifier`.
///
/// ```swift
/// struct CardStyle: TagModifier {
///     func body(content: Content) -> some Tag {
///         Div { content }
///             .backgroundColor(.white)
///             .borderRadius(.px(8))
///             .padding(.px(16))
///     }
/// }
///
/// Text("Hello").modifier(CardStyle())
/// ```
public protocol TagModifier {
    associatedtype Body: Tag
    /// Applies the modifier to the given content.
    ///
    /// - Parameter content: A `Content` value representing the original tag being modified.
    /// - Returns: A new tag tree with the modification applied.
    @TagBuilder func body(content: Content) -> Body
}

/// A placeholder type representing the content being modified.
///
/// Used inside `TagModifier.body(content:)` to refer to the original tag content.
/// The actual tag nodes are resolved lazily when the modifier is rendered.
public struct Content: Tag, TagNodeConvertible {
    public typealias Body = Never

    let nodes: [TagNode]

    init(nodes: [TagNode]) {
        self.nodes = nodes
    }

    public func toTagNodes() -> [TagNode] {
        nodes
    }
}

/// A tag that applies a `TagModifier` to content.
///
/// Created by calling `.modifier(_:)` on any `Tag`.
/// You typically do not create this type directly.
public struct ModifiedTag<Modifier: TagModifier>: Tag, TagNodeConvertible {
    public typealias Body = Never

    let contentTag: AnyTag
    let tagModifier: Modifier

    init(content: AnyTag, modifier: Modifier) {
        self.contentTag = content
        self.tagModifier = modifier
    }

    public func toTagNodes() -> [TagNode] {
        // First resolve the content to nodes
        let contentNodes = resolveTagBody(contentTag)
        // Create a Content placeholder with those nodes
        let content = Content(nodes: contentNodes)
        // Apply the modifier's body
        let modifiedBody = tagModifier.body(content: content)
        // Resolve the modifier's body to nodes
        return resolveTagBody(modifiedBody)
    }
}

// MARK: - Tag Extension

extension Tag {
    /// Apply a custom `TagModifier` to this tag.
    ///
    /// Use this method to apply reusable style and structural modifications to any tag.
    ///
    /// ```swift
    /// struct HighlightModifier: TagModifier {
    ///     func body(content: Content) -> some Tag {
    ///         content.style("background-color", "yellow")
    ///     }
    /// }
    ///
    /// Text("Important").modifier(HighlightModifier())
    /// ```
    ///
    /// - Parameter modifier: The `TagModifier` to apply.
    /// - Returns: A `ModifiedTag` wrapping the original tag with the modifier applied.
    public func modifier<M: TagModifier>(_ modifier: M) -> ModifiedTag<M> {
        ModifiedTag(content: AnyTag(self), modifier: modifier)
    }
}
