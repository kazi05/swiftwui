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
    public init() {}

    func _setColorScheme(_ v: ColorScheme) { colorScheme = v }
    func _setOnline(_ v: Bool) { isOnline = v }

    /// Cross-module write surface: setters stay core-private; backends receive
    /// closures via `RendererBackend.beginEnvironmentObservation`.
    public struct Writer {
        public let setColorScheme: (ColorScheme) -> Void
        public let setOnline: (Bool) -> Void
    }
    var writer: Writer {
        Writer(setColorScheme: { [weak self] in self?._setColorScheme($0) },
               setOnline: { [weak self] in self?._setOnline($0) })
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
}
