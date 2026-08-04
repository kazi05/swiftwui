/// A single property's animation, produced by `AnimationPlanner` or built
/// directly by transitions (Task 9) — the payload a `RendererBackend.animate`
/// call drives (anim spec §6).
public struct AnimationRequest: Equatable {
    public enum Mode: Equatable {
        case additive
        case replace
    }

    public var property: String
    /// nil = implicit (current presentation state).
    public var from: String?
    /// nil = implicit (current presentation state).
    public var to: String?
    /// `additive`: `from` is the delta value, `to` is the zero delta
    /// (composite "add" — the final style value is set directly, the
    /// animation only supplies the transient offset from it).
    public var mode: Mode
    public var timing: ResolvedTiming

    public init(property: String, from: String?, to: String?, mode: Mode, timing: ResolvedTiming) {
        self.property = property
        self.from = from
        self.to = to
        self.mode = mode
        self.timing = timing
    }
}

/// Opaque handle to a running backend animation; backends subclass to attach
/// their own bookkeeping (e.g. the underlying `Animation` JS object).
open class AnimationToken {
    nonisolated deinit { }
    public init() {}
}

/// Reported once, exactly once, per animation via the `onSettle` callback
/// passed to `RendererBackend.animate`.
public struct AnimationSettle: Equatable {
    public enum Reason: Equatable {
        case finished
        case cancelled
        case forced
    }

    public var reason: Reason

    public init(reason: Reason) {
        self.reason = reason
    }
}
