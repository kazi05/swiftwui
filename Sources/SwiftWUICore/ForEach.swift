// ForEach.swift - Iteration over collections

/// Creates tags from a collection of identifiable data.
///
/// ```swift
/// ForEach(items) { item in
///     Li { Text(item.name) }
/// }
/// ```
///
/// Each rendered element is tagged with the item's `id` (stringified) so
/// `Reconciler` can match elements across renders and physically move DOM
/// nodes on reorder rather than rewrite their content. This preserves
/// focus, scroll position, in-flight CSS animations, and any state bound
/// to the underlying DOM node.
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

extension ForEach: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        data.flatMap { item -> [TagNode] in
            let key = String(describing: item.id)
            let body = content(item)
            let nodes: [TagNode]
            if let convertible = body as? TagNodeConvertible {
                nodes = convertible.toTagNodes()
            } else {
                nodes = resolveTagBody(body)
            }
            // Stamp the key on the FIRST element node that the iteration
            // produced. If the closure emits multiple elements per item
            // (Group / TupleTag), only the first carries the key — the
            // others trail it positionally. This matches SwiftUI's idiom
            // that ForEach bodies are conceptually one element per item.
            return nodes.enumerated().map { index, node in
                guard index == 0, case .element(var el) = node else { return node }
                el.key = key
                return .element(el)
            }
        }
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
