struct CompositeKey: Hashable { let base: AnyHashable; let index: Int }

public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let data: Data
    let id: KeyPath<Data.Element, ID>
    /// KNOWN LIMITATION (phase 2): `content` runs during ForEach's own _resolve,
    /// OUTSIDE the parent component's withObservationTracking window. @Observable
    /// properties read directly inside this closure are NOT tracked — mutations
    /// will not invalidate. Wrap rows in a component (reads inside its `body` are
    /// tracked) until phase 3 threads tracking through primitive resolution.
    let content: (Data.Element) -> Content

    public init(_ data: Data, id: KeyPath<Data.Element, ID>,
                @TagBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.id = id; self.content = content
    }

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        var out: [Node] = []
        var seen = Set<NodeKey>()
        for item in data {
            let key = NodeKey(item[keyPath: id])
            assert(seen.insert(key).inserted, "ForEach: duplicate id \(item[keyPath: id])")
            var nodes = resolve(content(item), path: path.appending(.keyed(key)), ctx: &ctx)
            for i in nodes.indices {
                nodes[i].key = nodes.count == 1
                    ? key
                    : NodeKey(CompositeKey(base: AnyHashable(item[keyPath: id]), index: i))
            }
            out += nodes
        }
        return out
    }
}

extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @TagBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

extension ForEach where Data == Range<Int>, ID == Int {
    public init(_ data: Range<Int>, @TagBuilder content: @escaping (Int) -> Content) {
        self.init(data, id: \.self, content: content)
    }
}
