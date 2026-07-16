import Observation

// `ColorScheme` (light/dark) already exists at Styles/MediaQuery.swift — reused
// here rather than redeclared (would be an ambiguous-type-lookup compile error).

/// Browser-derived reactive environment values (phase-8 spec, shared mechanism).
/// One instance per Runtime; env keys are computed over this REFERENCE, so the
/// read happens lazily during body eval and is Observation-tracked — a write
/// invalidates exactly the reader components via the same path as @Observable
/// models. Read-site constraint: reads outside the component `body` (primitive
/// _resolve, event handlers, .task closures) are NOT tracked.
@MainActor @Observable
public final class EnvironmentSignals {
    public private(set) var colorScheme: ColorScheme = .light
    public private(set) var isOnline: Bool = true
    /// A new service-worker version is installed and waiting (PWA spec 2026-07-12).
    public private(set) var appUpdateAvailable: Bool = false
    /// `prefers-reduced-motion: reduce` (anim spec §9). `false` outside a live
    /// runtime (native/SSG) — zero behavior change for non-reduced users.
    public private(set) var reduceMotion: Bool = false
    /// Window-level drag state (DnD spec §3.4). Equality-guarded: repeated
    /// identical writes (child dragenters bubble to window) don't invalidate.
    public private(set) var dragSession: DragSessionInfo = .none
    public init() {}

    func _setColorScheme(_ v: ColorScheme) { colorScheme = v }
    func _setOnline(_ v: Bool) { isOnline = v }
    func _setAppUpdateAvailable(_ v: Bool) { appUpdateAvailable = v }
    func _setReduceMotion(_ v: Bool) { reduceMotion = v }
    func _setDragSession(_ v: DragSessionInfo) { if dragSession != v { dragSession = v } }

    /// Cross-module write surface: setters stay core-private; backends receive
    /// closures via `RendererBackend.beginEnvironmentObservation`.
    ///
    /// Recipe for adding a new signal: (1) add a `private(set) var` + `_setX`
    /// setter above, (2) add a `setX` field here + wire it in `writer` below,
    /// (3) add a computed key in `EnvironmentValues` (Environment.swift) reading
    /// `_signals?.x ?? <default>`, (4) backend wires the real source in
    /// `beginEnvironmentObservation` (DOMBackend.swift) — initial synchronous
    /// read + retained change-listener calling the writer closure.
    public struct Writer {
        public let setColorScheme: (ColorScheme) -> Void
        public let setOnline: (Bool) -> Void
        public let setAppUpdateAvailable: (Bool) -> Void
        public let setReduceMotion: (Bool) -> Void
        public let setDragSession: (DragSessionInfo) -> Void
    }
    var writer: Writer {
        Writer(setColorScheme: { [weak self] in self?._setColorScheme($0) },
               setOnline: { [weak self] in self?._setOnline($0) },
               setAppUpdateAvailable: { [weak self] in self?._setAppUpdateAvailable($0) },
               setReduceMotion: { [weak self] in self?._setReduceMotion($0) },
               setDragSession: { [weak self] in self?._setDragSession($0) })
    }
}

struct _SignalsKey: EnvironmentKey {
    static let defaultValue: EnvironmentSignals? = nil
}

extension EnvironmentValues {
    var _signals: EnvironmentSignals? {
        get { self[_SignalsKey.self] }
        set { self[_SignalsKey.self] = newValue }
    }
    /// System color-scheme preference. `.light` outside a live runtime (native/SSG).
    public var colorScheme: ColorScheme { _signals?.colorScheme ?? .light }
    /// `navigator.onLine`. `true` outside a live runtime.
    public var isOnline: Bool { _signals?.isOnline ?? true }
    /// True when a new app version is downloaded and waiting; pair with
    /// `\.reloadToUpdate` to offer a reload. `false` outside a live runtime.
    public var appUpdateAvailable: Bool { _signals?.appUpdateAvailable ?? false }
    /// `prefers-reduced-motion: reduce` (anim spec §9). Gates the animation
    /// engine automatically (Runtime reads this into `AnimationPassContext`).
    /// Any decorative `@keyframes` registered directly through Styled/keyframes
    /// (not the withAnimation/.transition engine) should be authored inside
    /// `@media (prefers-reduced-motion: no-preference) { ... }` — the engine
    /// gate doesn't reach hand-written CSS keyframes. `false` outside a live runtime.
    public var accessibilityReduceMotion: Bool { _signals?.reduceMotion ?? false }
    /// Live drag-over-window state — build overlay "drop anywhere" zones the
    /// moment files enter the window. `.none` outside a live runtime.
    public var dragSession: DragSessionInfo { _signals?.dragSession ?? .none }
}
