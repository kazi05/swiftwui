@resultBuilder
public enum TagBuilder {
    public static func buildExpression<T: Tag>(_ tag: T) -> T { tag }
    public static func buildExpression(_ text: String) -> Text { Text(text) }
    public static func buildBlock() -> EmptyTag { EmptyTag() }
    public static func buildBlock<T: Tag>(_ tag: T) -> T { tag }
    public static func buildBlock<each T: Tag>(_ tags: repeat each T) -> TupleTag<repeat each T> {
        TupleTag(repeat each tags)
    }
    public static func buildOptional<T: Tag>(_ tag: T?) -> T? { tag }
    public static func buildEither<F: Tag, S: Tag>(first tag: F) -> ConditionalTag<F, S> { .first(tag) }
    public static func buildEither<F: Tag, S: Tag>(second tag: S) -> ConditionalTag<F, S> { .second(tag) }
    public static func buildArray<T: Tag>(_ tags: [T]) -> [T] { tags }
    public static func buildLimitedAvailability<T: Tag>(_ tag: T) -> AnyTag { AnyTag(tag) }
}
