// TupleTag.swift - Groups multiple tags together

/// Groups multiple tags into a single tag value.
/// Created automatically by `@TagBuilder` when multiple tags are in a block.
///
/// Generic over a parameter pack of `Child` types so each TupleTag
/// instance keeps the static type of every member. Compared to the
/// previous `[any Tag]` storage this removes one existential
/// allocation per child per render and lets the compiler specialise
/// `toTagNodes()` per concrete tuple shape — useful in WASM where
/// existential dispatch has no inline cache.
///
/// Tradeoff: a deeply varied app produces many distinct
/// `TupleTag<...>` instantiations, slightly increasing binary size.
/// The render-time saving more than compensates for typical app
/// sizes.
public struct TupleTag<each Child: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never

    /// Pack tuple holding the children in their static types.
    public let children: (repeat each Child)

    public init(_ children: repeat each Child) {
        self.children = (repeat each children)
    }

    public func toTagNodes() -> [TagNode] {
        var nodes: [TagNode] = []
        // `repeat` here expands once per pack member at compile time.
        // Each iteration gets a statically-typed `child`, so the cast
        // and the recursive `resolveTagBody` call specialise rather
        // than going through the existential PWT lookup.
        repeat appendNodes(of: each children, to: &nodes)
        return nodes
    }

    @inline(__always)
    private func appendNodes<C: Tag>(of child: C, to nodes: inout [TagNode]) {
        if let convertible = child as? TagNodeConvertible {
            nodes.append(contentsOf: convertible.toTagNodes())
        } else {
            nodes.append(contentsOf: resolveTagBody(child))
        }
    }
}
