/// Wrapper path (spec §6): style modifiers on non-HTML tags. One `.type`
/// identity segment per wrapper CHAIN (consecutive modifiers collapse).
/// Declarations apply to every top-level element root of the resolved
/// content, appended AFTER the element's own styles (outer wins).
public struct _StyledTag<Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    var content: Content
    var declarations: [StyleDeclaration]
    var rules: [PendingStyleRule]

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        // Byte-parallel with the effect wrappers (_AppearEffect etc.): one `.type`
        // segment, content resolves directly at it — no extra `.child(0)`.
        _TypeNameRegistry.register(Self.self)   // canonical snapshot keys need the name (spec D7)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        var ruleClasses: [String] = []
        for r in rules {
            if let kf = r.keyframes { ctx.registry.registerRaw(kf.ruleText) }
            if let raw = r.rawText { ctx.registry.registerRaw(raw); continue }
            ruleClasses.append(ctx.registry.registerAnonymous(pseudo: r.pseudo, media: r.media,
                                                              container: r.container,
                                                              declarations: r.declarations))
        }
        var nodes = resolve(content, path: id, ctx: &ctx)
        let store = ctx.store
        let pass = ctx.pass
        for i in nodes.indices {
            // A component root won't see this wrapper again on a scoped subtree
            // pass (that re-resolves the row's tag directly, skipping back up
            // through `_resolve` here) — stash the transform for replay there.
            // The apply walk may descend through MULTIPLE component identities
            // (a pass-through component whose body is exactly another
            // component, e.g. `Middle().padding(…)` where `Middle.body ==
            // Inner()`) — stash at every one of them, not just the top-level
            // root, so a later scoped pass of the inner row alone still finds
            // its wrapper on replay (CRITICAL 1).
            applyStyleWrapper(declarations: declarations, classes: ruleClasses, to: &nodes[i]) { compId in
                store.setStyleWrapper(at: compId, pass: pass, declarations: declarations, classes: ruleClasses)
            }
        }
        return nodes
    }
}

/// Element roots get the styles; component roots are transparent (descend);
/// text roots are a documented no-op (debug assert to surface it — only for a
/// TOP-LEVEL text root, i.e. the wrapped content's own root is text; a text
/// SIBLING found while descending through a component root, e.g. a component
/// whose body is `Text(…); Span { … }`, is silently skipped — IMPORTANT 3).
/// `OrderedStyle.merge`/`set` is last-wins per property, so a wrapper
/// declaration overrides the element's own same-property declaration in
/// place (spec's "outer wins") — the property appears exactly once.
///
/// Free function (not a `_StyledTag<Content>` static member) so both the
/// wrapper's own `_resolve` and `Runtime.subtreePass`'s replay path (which has
/// no `Content` type in hand) can call it.
///
/// `stash` fires for every `.component` identity the walk descends through
/// (not just the top-level root) — a pass-through component (whose body is
/// exactly another component) needs its own stash entry too, so a later
/// scoped pass of THAT inner row alone can still replay the wrapper
/// (CRITICAL 1). `isTopLevel` gates the `.text` assert: only the top-level
/// call sites (the wrapper's own root nodes) should trip it.
func applyStyleWrapper(declarations: [StyleDeclaration], classes: [String], to node: inout Node,
                       stash: ((NodeIdentity) -> Void)? = nil, isTopLevel: Bool = true) {
    switch node {
    case .element(var e):
        e.style.merge(declarations)
        for cls in classes {
            let existing = e.attributes["class"]
            e.attributes["class"] = existing.map { $0.isEmpty ? cls : $0 + " " + cls } ?? cls
        }
        node = .element(e)
    case .component(var c):
        stash?(c.identity)
        for i in c.children.indices {
            applyStyleWrapper(declarations: declarations, classes: classes, to: &c.children[i],
                              stash: stash, isTopLevel: false)
        }
        node = .component(c)
    case .text:
        if isTopLevel {
            assertionFailure("style modifier applied to a text root is a no-op")
        }
    }
}
