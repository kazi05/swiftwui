/// Persistent per-`Runtime` store of live `.transition(_:)` wrappers, keyed
/// by the wrapped element's identity (Task 8). Populated by
/// `_TransitionTag._resolve`'s post-resolve walk; enter/exit playback
/// (Tasks 9-10) reads it via `transition(for:)`.
///
/// Unlike `AnimationValueStore`'s seen/reachable shape, a transition entry
/// persists as long as its ELEMENT survives — not just while the pass that
/// registered it re-ran. A `.transition` wrapping a custom component registers
/// element ids INSIDE that component; a subtree pass rooted at the component
/// never re-runs the wrapper (it's above the pass root), so those ids go
/// unseen — yet the elements are still live. Sweeping on "seen this pass"
/// alone would silently drop the transition after any internal state change.
/// So `sweep` drops an entry under `root` only when it was BOTH not seen this
/// pass AND no longer present in the committed tree (`stillExists`). Wrapper
/// REMOVAL is still handled: dropping the wrapper changes the element's
/// structural identity (loses the wrapper's `.type` segment), so the old id
/// vanishes from the tree and dies naturally.
@MainActor final class TransitionRegistry {
    private(set) var byIdentity: [NodeIdentity: AnyTransition] = [:]
    private var seenThisPass: Set<NodeIdentity> = []
    /// Cheap guard for the mount-path lookup (Task 9): skip the per-element
    /// dictionary probe entirely when nothing is registered.
    var isEmpty: Bool { byIdentity.isEmpty }

    func register(_ t: AnyTransition, for id: NodeIdentity) {
        seenThisPass.insert(id)
        byIdentity[id] = t
    }

    func transition(for id: NodeIdentity) -> AnyTransition? {
        byIdentity[id]
    }

    /// MUST run AFTER commit (`current` updated): `stillExists` is queried
    /// against the freshly committed tree.
    func sweep(under root: NodeIdentity, stillExists: (NodeIdentity) -> Bool) {
        for id in Array(byIdentity.keys)
        where id.isSelfOrDescendant(of: root) && !seenThisPass.contains(id) && !stillExists(id) {
            byIdentity.removeValue(forKey: id)
        }
        seenThisPass.removeAll()
    }
}
