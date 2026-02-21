// EmptyTag.swift - Represents an empty tag (no content)

/// A tag that produces no content.
/// Used as the default for empty `@TagBuilder` blocks.
public struct EmptyTag: Tag, Sendable {
    public typealias Body = Never

    public init() {}
}
