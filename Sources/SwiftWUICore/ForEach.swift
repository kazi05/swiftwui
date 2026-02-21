// ForEach.swift - Iteration over collections

/// Creates tags from a collection of identifiable data.
///
/// ```swift
/// ForEach(items) { item in
///     Li { Text(item.name) }
/// }
/// ```
public struct ForEach<Data: RandomAccessCollection, Content: Tag>: Tag
    where Data.Element: Identifiable
{
    public typealias Body = Never

    public let data: Data
    public let content: (Data.Element) -> Content

    public init(
        _ data: Data,
        @TagBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
    }
}

/// Overload for collections with `id` key path (non-Identifiable elements).
extension ForEach where Data.Element: Identifiable {
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, Data.Element.ID>,
        @TagBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
    }
}
