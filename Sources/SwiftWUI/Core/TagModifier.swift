import Observation

/// SwiftUI's ViewModifier, for Tags. The modifier's `body` composes wrapper
/// structure around a `Content` placeholder; `@State`/`@Environment` declared
/// on the modifier work exactly as in a component (spec 2026-07-12 §2.1).
public protocol TagModifier {
    associatedtype Body: Tag
    typealias Content = _ModifierContent<Self>
    @TagBuilder @MainActor func body(content: Content) -> Body
}

/// Placeholder for the wrapped content inside a modifier body. Resolves the
/// original content at the placeholder's structural position — using `content`
/// more than once in a body duplicates identity (documented limitation, same
/// as SwiftUI).
public struct _ModifierContent<M: TagModifier>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let content: AnyTag
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        resolve(content, path: path, ctx: &ctx)
    }
}

public struct ModifiedTag<C: Tag, M: TagModifier>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let content: C
    let modifier: M

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.reachable.insert(id)
        ctx.store.retain(AnyTag(self), at: id, environment: ctx.environment,
                         scopeClass: ctx.scopeClass, visibilityRoots: ctx.visibilityRoots)
        let inv = ctx.invalidate
        if ctx.collectedRoutes == nil {          // same guard as component resolve (C1)
            ctx.store.link(modifier, at: id, environment: ctx.environment,
                           invalidate: { inv(id) })
        }
        let box = _InvalidateBox(fire: { inv(id) })
        let savedOwner = ctx.owner
        ctx.owner = id
        defer { ctx.owner = savedOwner }
        // Unlike a component boundary, ctx.scopeClass is deliberately preserved:
        // modifier-wrapped content keeps the caller's Styled scope.
        let body = withObservationTracking {
            modifier.body(content: _ModifierContent(content: AnyTag(content)))
        } onChange: {
            MainActor.assumeIsolated { box.fire() }
        }
        let children = resolve(body, path: id.appending(.child(0)), ctx: &ctx)
        return [.component(ComponentNode(identity: id,
                                         typeName: String(describing: Self.self),
                                         key: nil,
                                         children: children))]
    }
}

extension Tag {
    public func modifier<M: TagModifier>(_ m: M) -> ModifiedTag<Self, M> {
        ModifiedTag(content: self, modifier: m)
    }
}
