// TupleTag.swift - Groups multiple tags together

/// Groups multiple tags into a single tag value.
/// Created automatically by `@TagBuilder` when multiple tags are in a block.
public struct TupleTag: Tag {
    public typealias Body = Never

    public let children: [any Tag]

    public init(children: [any Tag]) {
        self.children = children
    }
}

extension TupleTag: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        children.flatMap { child -> [TagNode] in
            if let convertible = child as? TagNodeConvertible {
                return convertible.toTagNodes()
            }
            return resolveTagBody(child)
        }
    }
}
