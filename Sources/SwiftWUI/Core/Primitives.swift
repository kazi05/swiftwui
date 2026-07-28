public struct EmptyTag: Tag, _PrimitiveTag {
    public typealias Body = Never
    public init() {}
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] { [] }
}

public struct Text: Tag, _PrimitiveTag {
    public typealias Body = Never
    public var content: String
    let localized: LocalizedText?
    public init(_ content: String) { self.content = content; self.localized = nil }
    /// Resolution is deferred to `_resolve`, where the locale is known.
    public init(_ localized: LocalizedText) {
        self.content = localized.key
        self.localized = localized
    }
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        guard let localized else { return [.text(content)] }
        return [.text(localized.resolved(for: ctx.environment.locale,
                                         fallback: ctx.environment._signals?.defaultLocale))]
    }
}

public struct TupleTag<each C: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let content: (repeat each C)
    public init(_ content: repeat each C) { self.content = (repeat each content) }
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        var out: [Node] = []
        var i = 0
        for tag in repeat each content {
            out += resolve(tag, path: path.appending(.child(i)), ctx: &ctx)
            i += 1
        }
        return out
    }
}

public enum ConditionalTag<First: Tag, Second: Tag>: Tag, _PrimitiveTag {
    case first(First)
    case second(Second)
    public typealias Body = Never
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        switch self {
        case .first(let t):  return resolve(t, path: path.appending(.branch(true)), ctx: &ctx)
        case .second(let t): return resolve(t, path: path.appending(.branch(false)), ctx: &ctx)
        }
    }
}

extension Optional: Tag where Wrapped: Tag { public typealias Body = Never }
extension Optional: _PrimitiveTag where Wrapped: Tag {
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        switch self {
        case .some(let t): return resolve(t, path: path.appending(.branch(true)), ctx: &ctx)
        case .none: return []
        }
    }
}

extension Array: Tag where Element: Tag { public typealias Body = Never }
extension Array: _PrimitiveTag where Element: Tag {
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        var out: [Node] = []
        for (i, tag) in enumerated() {
            out += resolve(tag, path: path.appending(.child(i)), ctx: &ctx)
        }
        return out
    }
}

public struct AnyTag: Tag, _PrimitiveTag {
    public typealias Body = Never
    let base: any Tag
    public init(_ tag: any Tag) {
        if let already = tag as? AnyTag { self = already } else { base = tag }
    }
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        // Transparent: contributes no segment itself; a wrapped component still
        // adds its .type segment inside resolve() (spec §5 table).
        resolve(base, path: path, ctx: &ctx)   // existential is opened implicitly (SE-0352)
    }
}
