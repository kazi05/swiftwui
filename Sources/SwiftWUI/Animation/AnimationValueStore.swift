/// Per-runtime store backing `.animation(_:value:)` wrappers (anim spec §4.3):
/// remembers the last-seen `value` for each `_AnimationTag` identity so its
/// `_resolve` can detect a change DURING resolve — not `EffectStore.onChange`,
/// which fires post-commit and would be one pass too late for a resolve-time
/// transaction override.
///
/// First sighting of an id stores the value and reports no change (mount
/// never animates). The override `changed()` drives is deliberately never
/// stashed/replayed here (unlike `RetainedComponent.styleWrappers`) — callers
/// must apply it for exactly the one pass that observed the change.
@MainActor
final class AnimationValueStore {
    private var values: [NodeIdentity: Any] = [:]
    private var seenThisPass: Set<NodeIdentity> = []

    /// Compares `newValue` against the stored value for `id` (if any), then
    /// unconditionally overwrites the stored value with `newValue`.
    /// Returns `true` only when a prior value existed and differed.
    func changed(id: NodeIdentity, newValue: Any, isEqual: (Any, Any) -> Bool) -> Bool {
        seenThisPass.insert(id)
        defer { values[id] = newValue }
        guard let old = values[id] else { return false }
        return !isEqual(old, newValue)
    }

    /// Mirrors `ListenerRegistry.sweep(under:keep:)`'s shape: an id under
    /// `root` that this pass's `changed()` calls didn't touch (and isn't in
    /// `reachable`) is no longer part of the resolved tree — drop its row.
    func sweep(under root: NodeIdentity, reachable: Set<NodeIdentity>) {
        for id in Array(values.keys)
        where id.isSelfOrDescendant(of: root) && !seenThisPass.contains(id) && !reachable.contains(id) {
            values.removeValue(forKey: id)
        }
        seenThisPass.removeAll()
    }
}
