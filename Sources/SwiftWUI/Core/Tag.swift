@MainActor
public protocol Tag {
    associatedtype Body: Tag
    @TagBuilder var body: Body { get }
}

extension Never: Tag {
    public typealias Body = Never
    public var body: Never { fatalError("unreachable") }
}

extension Tag where Body == Never {
    public var body: Never { fatalError("\(Self.self) is a primitive and has no body") }
}

/// Internal seam: the ONE recursion entry point for leaf types (spec §3.1, trap T3).
public protocol _PrimitiveTag: Tag where Body == Never {
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node]
}
