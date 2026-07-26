/// A CSS `@keyframes` block as a value (keyframes spec §2). Unlike `FontFace`
/// and `ThemeDefinition` there is no `App.keyframes` array: the block is
/// attached at the use site by `.animation(_:duration:…)`, which registers it
/// through `StyleRegistry.registerRaw` during resolve (spec §4). A value that
/// no `.animation` call references emits no CSS.
///
/// The emitted name always carries a hash suffix — `@keyframes` is last-wins by
/// name and `StyleRegistry` sorts by hash, so two values sharing an explicit
/// name would otherwise produce a nondeterministic winner (spec §3).
public struct Keyframes: Equatable {
    struct Stop: Equatable {
        let key: String        // "from" / "to" / "50%"
        let body: String       // already serialized + sanitized by StyleRegistry.body
    }
    let name: String?
    let stops: [Stop]

    public init(_ name: String? = nil, _ build: (inout KeyframeStops) -> Void) {
        var collector = KeyframeStops()
        build(&collector)
        // The name is the only new CSS sink: it lands raw in the at-rule
        // prelude with no downstream sanitize step, exactly like the @container
        // prelude. Validate-and-drop is therefore the injection guard, and it
        // must hold in release — no assert, which would also make the
        // regression test untestable under debug (same reasoning as
        // Tag._styledContainer in StyleModifiers+Tag.swift).
        self.name = name.flatMap { CSSSanitize.isValidIdent($0) ? $0 : nil }
        self.stops = collector.stops
    }

    var isEmpty: Bool { stops.isEmpty }

    /// Declaration order is preserved: CSS accepts any stop order, and keeping
    /// the authored order makes the hash stable and the output readable.
    private var stopsText: String {
        stops.map { "\($0.key) { \($0.body) }" }.joined(separator: " ")
    }

    /// Stable across builds (FNV-1a over the serialized stops) so SSG output is
    /// deterministic; identical bodies collapse to one registered block.
    var cssName: String {
        (name ?? "swui-kf") + "-" + String(StyleRegistry.fnv1a(stopsText), radix: 36)
    }

    var ruleText: String { "@keyframes \(cssName) { \(stopsText) }" }
}

/// Stop collector for the `Keyframes` builder. `from`/`to` emit the CSS
/// keywords rather than `0%`/`100%`: both forms are valid and behave
/// identically, and the hash identifies the text, so the two spellings are
/// deliberately distinct values (spec §3).
public struct KeyframeStops {
    fileprivate var stops: [Keyframes.Stop] = []

    private mutating func add(_ key: String, _ build: (inout StyleProxy) -> Void) {
        var proxy = StyleProxy()
        build(&proxy)
        assert(proxy.pseudoBlocks.isEmpty && proxy.mediaBlocks.isEmpty && proxy.containerBlocks.isEmpty,
               "pseudo/media/container blocks are not supported inside a keyframe stop")
        guard !proxy.declarations.isEmpty else { return }   // empty stop — nothing to emit
        stops.append(.init(key: key, body: StyleRegistry.body(proxy.declarations)))
    }

    public mutating func from(_ build: (inout StyleProxy) -> Void) { add("from", build) }
    public mutating func to(_ build: (inout StyleProxy) -> Void) { add("to", build) }
    /// `percent` is clamped to 0…100 and machine-formatted — no user string
    /// reaches the stop key. NaN is not ordered by `min`/`max` (both propagate
    /// it), so it is special-cased before the clamp — otherwise it would reach
    /// `cssNumber` and emit an invalid `nan%` selector that browsers drop.
    public mutating func at(_ percent: Double, _ build: (inout StyleProxy) -> Void) {
        let clamped = percent.isNaN ? 0 : min(max(percent, 0), 100)
        add(cssNumber(clamped) + "%", build)
    }
}

/// `animation-iteration-count`.
public enum AnimationIterations: Equatable, CSSValueConvertible {
    case count(Int)
    case infinite
    public var css: String {
        switch self {
        case .count(let n): return String(max(n, 0))
        case .infinite: return "infinite"
        }
    }
}

/// `animation-direction`.
public enum AnimationDirection: String, CSSValueConvertible {
    case normal, reverse, alternate
    case alternateReverse = "alternate-reverse"
    public var css: String { rawValue }
}

/// `animation-fill-mode`.
public enum AnimationFillMode: String, CSSValueConvertible {
    case none, forwards, backwards, both
    public var css: String { rawValue }
}

/// Builds the gated rule the three `.animation(_:duration:…)` paths share.
/// Returns nil for empty keyframes — nothing to register, nothing to apply.
///
/// The animation lands in a registered rule rather than an inline declaration
/// so it can sit inside `@media (prefers-reduced-motion: no-preference)`
/// (spec §5). CSS can only *enable* under a condition, hence `no-preference`
/// rather than `reduce`. The `@keyframes` definition itself is never wrapped:
/// an unreferenced definition is inert, and wrapping it would break a
/// hand-written `.style("animation", …)` naming the same keyframes.
func _animationRule(_ keyframes: Keyframes, duration: CSSDuration,
                    timingFunction: TimingFunction, delay: CSSDuration,
                    iterations: AnimationIterations, direction: AnimationDirection,
                    fillMode: AnimationFillMode,
                    respectsReducedMotion: Bool) -> PendingStyleRule? {
    guard !keyframes.isEmpty else { return nil }
    let declaration = StyleDeclaration.animation(
        name: keyframes.cssName, duration: duration, timingFunction: timingFunction,
        delay: delay, iterations: iterations, direction: direction, fillMode: fillMode)
    return PendingStyleRule(
        pseudo: nil,
        media: respectsReducedMotion ? "(prefers-reduced-motion: no-preference)" : nil,
        keyframes: keyframes,
        declarations: [declaration])
}
