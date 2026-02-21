// TagBuilder.swift - Result builder for composing tag trees

/// A result builder that enables declarative syntax for composing tags.
///
/// ```swift
/// @TagBuilder
/// var body: some Tag {
///     Div {
///         H1 { "Title" }
///         P { "Content" }
///     }
/// }
/// ```
@resultBuilder
public struct TagBuilder {

    // MARK: - Single Expression

    public static func buildBlock() -> EmptyTag {
        EmptyTag()
    }

    public static func buildBlock<T: Tag>(_ component: T) -> T {
        component
    }

    // MARK: - Multiple Components (using parameter packs)

    public static func buildBlock<each T: Tag>(_ components: repeat each T) -> TupleTag {
        var children: [any Tag] = []
        repeat children.append(each components)
        return TupleTag(children: children)
    }

    // MARK: - Conditional Content

    public static func buildEither<TrueContent: Tag, FalseContent: Tag>(
        first component: TrueContent
    ) -> ConditionalTag<TrueContent, FalseContent> {
        .trueContent(component)
    }

    public static func buildEither<TrueContent: Tag, FalseContent: Tag>(
        second component: FalseContent
    ) -> ConditionalTag<TrueContent, FalseContent> {
        .falseContent(component)
    }

    // MARK: - Optional Content

    public static func buildOptional<T: Tag>(_ component: T?) -> T? {
        component
    }

    // MARK: - Expressions

    /// Allows string literals to be used directly in `@TagBuilder` blocks.
    public static func buildExpression(_ string: String) -> Text {
        Text(string)
    }

    /// Passthrough for any `Tag` conforming type.
    public static func buildExpression<T: Tag>(_ tag: T) -> T {
        tag
    }

    // MARK: - Limited Availability

    public static func buildLimitedAvailability<T: Tag>(_ component: T) -> AnyTag {
        AnyTag(component)
    }

    // MARK: - Array Support

    public static func buildArray<T: Tag>(_ components: [T]) -> [T] {
        components
    }
}

// MARK: - Array Tag Conformance

extension Array: Tag where Element: Tag {
    public typealias Body = Never

    public var body: Never {
        fatalError("Array<Tag> is a primitive composition type.")
    }
}
