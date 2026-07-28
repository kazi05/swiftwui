/// `setLocale(LocaleID("ru")!)` — runtime-provided; a no-op by default so
/// HTMLRenderer and unit tests need no wiring.
public struct SetLocaleAction {
    let handler: (LocaleID) -> Void
    public init(handler: @escaping (LocaleID) -> Void) { self.handler = handler }
    public func callAsFunction(_ locale: LocaleID) { handler(locale) }
}

private struct SetLocaleKey: EnvironmentKey {
    static let defaultValue = SetLocaleAction { _ in }
}
private struct AvailableLocalesKey: EnvironmentKey {
    static let defaultValue: [LocaleID] = []
}

extension EnvironmentValues {
    /// The active locale. Reading this inside `body` IS Observation-tracked,
    /// but locale switches re-render everything anyway (`markDirty(.root)`).
    public var locale: LocaleID { _signals?.locale ?? LocaleID("en")! }

    /// Writing direction of the active locale — drives `<html dir>` and any
    /// direction-sensitive styling.
    public var layoutDirection: LayoutDirection { locale.direction }

    /// Every declared locale, in catalog order — enough to build a switcher
    /// without importing the generated `L10n`.
    public var availableLocales: [LocaleID] {
        get { self[AvailableLocalesKey.self] }
        set { self[AvailableLocalesKey.self] = newValue }
    }

    public var setLocale: SetLocaleAction {
        get { self[SetLocaleKey.self] }
        set { self[SetLocaleKey.self] = newValue }
    }
}

private struct ExternalizePathKey: EnvironmentKey {
    static let defaultValue: (String) -> String = { $0 }
}

extension EnvironmentValues {
    /// Runtime-provided mapping from an internal route path to the URL the
    /// browser should show. Identity unless the strategy uses prefixes.
    public var _externalizePath: (String) -> String {
        get { self[ExternalizePathKey.self] }
        set { self[ExternalizePathKey.self] = newValue }
    }
}
