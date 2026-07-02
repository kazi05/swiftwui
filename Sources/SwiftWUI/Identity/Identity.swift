public struct NodeKey: Hashable, @unchecked Sendable {
    public let base: AnyHashable
    public init(_ base: some Hashable) { self.base = AnyHashable(base) }
}

public enum IdentitySegment: Hashable, Sendable {
    case child(Int)
    case branch(Bool)
    case keyed(NodeKey)
    case type(ObjectIdentifier)
}

public struct NodeIdentity: Hashable, Sendable {
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
}
