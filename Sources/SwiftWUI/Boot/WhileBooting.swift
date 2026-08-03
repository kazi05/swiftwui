/// Content that is hidden until wasm is live, paired with a placeholder shown
/// in its place during boot. `BootCSS`'s veil rule is `display:none`, so the
/// real subtree is not on screen at all while booting — the placeholder is the
/// only thing visible, and it is replaced (not uncovered) once the runtime
/// takes over.
///
/// A `_PrimitiveTag` decorator, the same shape `_StyledTag` and
/// `_SortableDecorator` already use.
///
/// IDENTITY CONTRACT — the reason this is not a plain `TagModifier` body:
/// `content` resolves at `id.appending(.child(0))` in BOTH renders. The
/// placeholder resolves at a `.keyed` segment, and only in the build render, so
/// it can never shift `content`'s sibling index. Only behaviour forks here;
/// tree shape never does. The precedent is `.staticTask`, which compiles to the
/// same wrapper everywhere and forks at runtime on `EffectStore._buildMode`.
public struct _WhileBootingTag<Content: Tag, Placeholder: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let content: Content
    let placeholder: Placeholder

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        var contentNodes = resolve(content, path: id.appending(.child(0)), ctx: &ctx)
        guard ctx.isBuildRender else { return contentNodes }
        for i in contentNodes.indices { applyVeil(to: &contentNodes[i]) }
        let placeholderNodes = resolve(_BootTemplate(content: placeholder),
                                       path: id.appending(.keyed(NodeKey("swui-boot"))),
                                       ctx: &ctx)
        return placeholderNodes + contentNodes
    }
}

/// Stamps `data-swui-boot-veil` on every element root of the wrapped content.
/// Component roots are transparent (descend); a text root cannot carry an
/// attribute and is left visible — asserted in debug so the author sees it.
@MainActor func applyVeil(to node: inout Node, isTopLevel: Bool = true) {
    switch node {
    case .element(var e):
        e.attributes["data-swui-boot-veil"] = ""
        node = .element(e)
    case .component(var c):
        for i in c.children.indices { applyVeil(to: &c.children[i], isTopLevel: false) }
        node = .component(c)
    case .text:
        if isTopLevel {
            assertionFailure(".whileBooting on a text root cannot veil it — wrap it in an element")
        }
    }
}

extension Tag {
    /// Show `placeholder` in this tag's place until the wasm runtime is live.
    ///
    /// Only meaningful on a prerendered page: with no prerender there is no
    /// real subtree to stand in for, and only `App`/`Page` overlays apply.
    /// The placeholder is build-time markup — no `@State`, no handlers, no
    /// `.pageMeta` (a `.pageMeta` inside it resolves after its ancestor's and
    /// clobbers the page head, in the build render only).
    public func whileBooting<P: Tag>(@TagBuilder _ placeholder: () -> P)
        -> _WhileBootingTag<Self, P> {
        _WhileBootingTag(content: self, placeholder: placeholder())
    }
}
