import Observation

struct CompositeKey: Hashable { let base: AnyHashable; let index: Int }

public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let data: Data
    let id: KeyPath<Data.Element, ID>
    /// Per-item content closures run inside their own tracking window bound to
    /// the nearest enclosing component (phase 3): @Observable reads here DO
    /// invalidate. Reads inside nested escaping closures that run later
    /// (e.g. Button actions) are writes-side and intentionally untracked.
    let content: (Data.Element) -> Content

    public init(_ data: Data, id: KeyPath<Data.Element, ID>,
                @TagBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.id = id; self.content = content
    }

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        var out: [Node] = []
        var seen = Set<NodeKey>()
        let ownerID = ctx.owner
        let inv = ctx.invalidate
        // A primitive root has no enclosing component to install a generation.
        // Lazily give that root the same stale-callback protection.
        let observationToken: _ObservationTrackingToken
        if let current = ctx.ownerObservationToken {
            observationToken = current
        } else {
            observationToken = ctx.store.beginObservation(at: ownerID)
            ctx.ownerObservationToken = observationToken
        }
        let box = _InvalidateBox(token: observationToken, fire: { inv(ownerID) })
        for item in data {
            let key = NodeKey(item[keyPath: id])
            assert(seen.insert(key).inserted, "ForEach: duplicate id \(item[keyPath: id])")
            let built = withObservationTracking {
                content(item)
            } onChange: {
                MainActor.assumeIsolated { box.fireIfCurrent() }
            }
            var nodes = resolve(built, path: path.appending(.keyed(key)), ctx: &ctx)
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
