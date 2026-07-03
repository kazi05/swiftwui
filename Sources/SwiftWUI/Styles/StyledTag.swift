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
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        var ruleClasses: [String] = []
        for r in rules {
            ruleClasses.append(ctx.registry.registerAnonymous(pseudo: r.pseudo, media: r.media,
                                                              declarations: r.declarations))
        }
        var nodes = resolve(content, path: id, ctx: &ctx)
        for i in nodes.indices {
            // A component root won't see this wrapper again on a scoped subtree
            // pass (that re-resolves the row's tag directly, skipping back up
            // through `_resolve` here) — stash the transform for replay there.
            if case .component(let c) = nodes[i] {
                ctx.store.setStyleWrapper((declarations, ruleClasses), at: c.identity)
            }
            applyStyleWrapper(declarations: declarations, classes: ruleClasses, to: &nodes[i])
        }
        return nodes
    }
}

/// Element roots get the styles; component roots are transparent (descend);
/// text roots are a documented no-op (debug assert to surface it).
/// `mergeStyleText` is last-wins across `base + new`, so a wrapper declaration
/// overrides the element's own same-property declaration (spec's "outer wins").
/// The base is a pre-joined string, so a duplicate property appears twice in
/// the attribute — CSS itself applies last-wins, which matches the spec.
///
/// Free function (not a `_StyledTag<Content>` static member) so both the
/// wrapper's own `_resolve` and `Runtime.subtreePass`'s replay path (which has
/// no `Content` type in hand) can call it.
func applyStyleWrapper(declarations: [StyleDeclaration], classes: [String], to node: inout Node) {
    switch node {
    case .element(var e):
        if !declarations.isEmpty {
            e.attributes["style"] = _AttributeBag.mergeStyleText(
                base: e.attributes["style"], declarations)
        }
        for cls in classes {
            let existing = e.attributes["class"]
            e.attributes["class"] = existing.map { $0.isEmpty ? cls : $0 + " " + cls } ?? cls
        }
        node = .element(e)
    case .component(var c):
        for i in c.children.indices {
            applyStyleWrapper(declarations: declarations, classes: classes, to: &c.children[i])
        }
        node = .component(c)
    case .text:
        assertionFailure("style modifier applied to a text root is a no-op")
    }
}
