// ConditionalTag.swift - Represents if/else branching in tag builders

/// Represents the result of an `if/else` statement inside a `@TagBuilder`.
public enum ConditionalTag<TrueContent: Tag, FalseContent: Tag>: Tag {
    public typealias Body = Never

    case trueContent(TrueContent)
    case falseContent(FalseContent)
}
