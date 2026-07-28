/// CLDR cardinal plural categories. Public because generated code switches on it.
public enum _PluralCategory: Hashable {
    case zero, one, two, few, many, other
}

/// A string whose language is decided at resolve time, not at construction.
///
/// `L10n.foo(...)` returns this, never `String`: `Text` and localized attributes
/// resolve it inside `_resolve`, where `ctx.environment.locale` is known.
/// Not `Sendable` by design — the whole render pipeline is `@MainActor`.
public struct LocalizedText {
    public let key: String
    let render: (LocaleID) -> String?

    public init(key: String, render: @escaping (LocaleID) -> String?) {
        self.key = key
        self.render = render
    }

    /// Resolution order: the requested locale, then `fallback` (the app's
    /// default locale, supplied by the runtime), then the key itself. A key
    /// missing from one catalog therefore degrades to the default language
    /// instead of disappearing.
    public func resolved(for locale: LocaleID, fallback: LocaleID? = nil) -> String {
        if let s = render(locale) { return s }
        if let fallback, let s = render(fallback) { return s }
        return key
    }

    /// A literal that needs no catalog entry — for mixing raw strings into
    /// APIs that take `LocalizedText`.
    public static func verbatim(_ value: String) -> LocalizedText {
        LocalizedText(key: value) { _ in value }
    }
}
