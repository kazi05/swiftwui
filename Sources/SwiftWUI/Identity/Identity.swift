public struct NodeKey: Hashable {
    public let base: AnyHashable
    public init(_ base: some Hashable) { self.base = AnyHashable(base) }
}

public enum IdentitySegment: Hashable {
    case child(Int)
    case branch(Bool)
    case keyed(NodeKey)
    case type(ObjectIdentifier)
}

public struct NodeIdentity: Hashable {
    public private(set) var segments: [IdentitySegment]
    init(segments: [IdentitySegment]) { self.segments = segments }
    public static let root = NodeIdentity(segments: [])
    public func appending(_ s: IdentitySegment) -> NodeIdentity {
        var c = self; c.segments.append(s); return c
    }
    public func isSelfOrDescendant(of p: NodeIdentity) -> Bool {
        segments.count >= p.segments.count
            && segments.prefix(p.segments.count).elementsEqual(p.segments)
    }

    /// Expected O(depth) ancestor membership check used by dirty-cover
    /// selection. The first removal pays the array's copy-on-write cost; later
    /// removals mutate the same unique buffer instead of rebuilding every
    /// prefix or scanning the growing cover.
    func hasStrictAncestor(in candidates: Set<NodeIdentity>) -> Bool {
        var ancestor = self
        while !ancestor.segments.isEmpty {
            ancestor.segments.removeLast()
            if candidates.contains(ancestor) { return true }
        }
        return false
    }

    func isSelfOrDescendant(ofAny candidates: Set<NodeIdentity>) -> Bool {
        candidates.contains(self) || hasStrictAncestor(in: candidates)
    }
}
