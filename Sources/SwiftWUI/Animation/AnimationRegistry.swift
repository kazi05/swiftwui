/// Bookkeeping for in-flight backend animations, keyed by (element identity,
/// property) — lets a later write to the same property retarget instead of
/// stacking indefinitely (anim spec §6.2), and lets unmount cancel every
/// animation under a subtree (Task 10).
@MainActor final class AnimationRegistry {
    struct Key: Hashable {
        let identity: NodeIdentity
        let property: String
    }
    struct Running {
        let token: AnimationToken
        let timing: ResolvedTiming
        let to: String?
    }

    private(set) var running: [Key: Running] = [:]

    func track(_ key: Key, _ r: Running) {
        running[key] = r
    }

    func remove(_ key: Key) {
        running[key] = nil
    }

    /// Cancels (via `backend`) and drops every entry whose identity is `root`
    /// or a descendant of it — used when a subtree unmounts (Task 10).
    func cancelAll(under root: NodeIdentity, using backend: (AnimationToken) -> Void) {
        for (key, r) in running where key.identity.isSelfOrDescendant(of: root) {
            backend(r.token)
            running[key] = nil
        }
    }
}

/// Per-flush context threaded into `TreeApplier.apply` (anim spec §6): which
/// element identities have an active `Transaction` in effect, whether
/// animations are globally suppressed (Task 13), and whether this pass should
/// skip enter/exit transitions (Task 9 — cold mount and similar).
struct AnimationPassContext {
    var transactions: [NodeIdentity: Transaction]
    var reduceMotion: Bool
    var suppressTransitions: Bool
    /// The transaction that caused this pass (Task 9 §3.4): the drained
    /// `.root` override for a renderPass, or the subtree pass's own cover-id
    /// transaction. Driving-animation fallback for a fresh mount whose
    /// element has no per-identity entry in `transactions` (e.g. a plain
    /// `Div` with no other animated writes this pass).
    var defaultTransaction: Transaction?
}
