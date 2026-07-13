/// `.transition(_:)` wrapper (Task 8): records `t` against every element root
/// of the wrapped content in the persistent `TransitionRegistry`. This task
/// only registers — nothing consumes the registry yet (enter/exit playback
/// lands in Tasks 9-10).
///
/// Byte-parallel with `_StyledTag`: one `.type` identity segment, content
/// resolves directly at it. The resolved nodes are then walked like
/// `applyStyleWrapper` (element roots register, component roots are
/// transparent, text is a no-op) — but unlike style declarations, a
/// transition doesn't mutate the node, so there's nothing to stash for a
/// scoped subtree pass to replay: a pass that skips this wrapper simply
/// doesn't re-register, and `TransitionRegistry.sweep` only drops ids under
/// its own pass root, leaving registrations above the pass root untouched.
public struct _TransitionTag<Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    var transition: AnyTransition
    var content: Content

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)   // canonical snapshot keys need the name (spec D7)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        let nodes = resolve(content, path: id, ctx: &ctx)
        if ctx.collectedRoutes == nil {   // collect passes never touch live registries (C1)
            for node in nodes {
                registerTransition(transition, in: node, ctx: ctx)
            }
        }
        return nodes
    }
}

private func registerTransition(_ t: AnyTransition, in node: Node, ctx: ResolveContext) {
    switch node {
    case .element(let e):
        ctx.transitions?.register(t, for: e.identity)
    case .component(let c):
        for child in c.children {
            registerTransition(t, in: child, ctx: ctx)
        }
    case .text:
        break
    }
}

extension Tag {
    public func transition(_ t: AnyTransition) -> some Tag {
        _TransitionTag(transition: t, content: self)
    }
}
