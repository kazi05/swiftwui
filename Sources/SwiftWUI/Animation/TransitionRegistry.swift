/// Persistent per-`Runtime` store of live `.transition(_:)` wrappers, keyed
/// by the wrapped element's identity (Task 8). Populated by
/// `_TransitionTag._resolve`'s post-resolve walk; enter/exit playback
/// (Tasks 9-10) reads it via `transition(for:)`.
///
/// Mirrors `AnimationValueStore`'s seen/keep shape: `register` marks the id
/// seen this pass; `sweep` drops any id under `root` that neither this
/// pass's registrations nor `keep` still account for.
@MainActor final class TransitionRegistry {
    private(set) var byIdentity: [NodeIdentity: AnyTransition] = [:]
    private var seenThisPass: Set<NodeIdentity> = []

    func register(_ t: AnyTransition, for id: NodeIdentity) {
        seenThisPass.insert(id)
        byIdentity[id] = t
    }

    func transition(for id: NodeIdentity) -> AnyTransition? {
        byIdentity[id]
    }

    func sweep(under root: NodeIdentity, keep: Set<NodeIdentity>) {
        for id in Array(byIdentity.keys)
        where id.isSelfOrDescendant(of: root) && !seenThisPass.contains(id) && !keep.contains(id) {
            byIdentity.removeValue(forKey: id)
        }
        seenThisPass.removeAll()
    }
}
