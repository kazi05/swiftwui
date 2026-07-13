/// `.animation(_:value:)` wrapper (anim spec §4.3): scoped implicit animation.
/// Byte-parallel with `_StyledTag._resolve` (one `.type` identity segment,
/// content resolves directly at it). Compares `value` against the previous
/// resolve's value for this identity via `AnimationValueStore` (seeded on
/// `ResolveContext` by the runtime) and, only when it changed, overrides
/// `ctx.transaction` for its subtree.
///
/// The override lives for exactly ONE pass — it is never stashed/replayed
/// (deliberately the opposite of `RetainedComponent.styleWrappers`). A later
/// pass that dirties a descendant without touching `value` must not re-fire
/// the wrapper's animation; a stale replayed override would reintroduce
/// SwiftUI's banned valueless-`.animation` behavior.
public struct _AnimationTag<V: Equatable, Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    var animation: Animation?
    var value: V
    var content: Content

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)   // canonical snapshot keys need the name (spec D7)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        let saved = ctx.transaction
        defer { ctx.transaction = saved }
        if ctx.collectedRoutes == nil,      // collect passes never touch live stores (C1 — Resolver.swift:55)
           let store = ctx.animationValues,
           store.changed(id: id, newValue: value, isEqual: { ($0 as? V) == ($1 as? V) }) {
            ctx.transaction = Transaction(animation: animation)   // nearest-wins; one pass only (anim spec §4.3)
        }
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    /// Animates any state-driven style/attribute change under `self` whenever
    /// `value` changes, using `animation` (or suppresses the ambient
    /// `withAnimation` transaction for this subtree when `animation` is nil).
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some Tag {
        _AnimationTag(animation: animation, value: value, content: self)
    }
}
