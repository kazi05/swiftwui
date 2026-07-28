/// Implemented by the generated `L10n` enum.
public protocol LocalizationCatalog {
    static var supportedLocales: [LocaleID] { get }
}

/// How locale is carried between the URL, the server and the client.
public enum LocaleStrategy: Hashable {
    /// Should a locale other than the URL's be allowed to win at boot?
    public enum Detection: Hashable { case full, urlOnly }

    /// `/about/` (default locale) and `/ru/about/`. SSG renders one tree per locale.
    case pathPrefix(detection: Detection = .full)
    /// Clean URLs, one output folder per locale, the edge picks the folder.
    case negotiated
    /// Clean URLs, a single output tree in the default locale, the client switches.
    case client

    /// True when paths carry a locale segment.
    public var usesURLPrefix: Bool {
        if case .pathPrefix = self { return true }
        return false
    }

    /// True when SSG must render the whole page set once per locale.
    public var isPerLocaleOutput: Bool {
        switch self {
        case .pathPrefix, .negotiated: return true
        case .client: return false
        }
    }

    /// True when a boot-time source other than the URL may select the locale.
    public var allowsClientDetection: Bool {
        switch self {
        case .pathPrefix(let d): return d == .full
        case .negotiated, .client: return true
        }
    }
}

/// The app's localization declaration. `nil` (the default) keeps every
/// localization branch inert — monolingual apps pay nothing.
public struct Localization {
    public let supported: [LocaleID]
    public let `default`: LocaleID
    public let strategy: LocaleStrategy

    public init(supported: [LocaleID], default defaultLocale: LocaleID,
                strategy: LocaleStrategy = .pathPrefix()) {
        assert(supported.contains(defaultLocale),
               "Localization default '\(defaultLocale)' is not in supported \(supported)")
        self.supported = supported
        self.default = supported.contains(defaultLocale) ? defaultLocale : (supported.first ?? defaultLocale)
        self.strategy = strategy
    }

    public init<C: LocalizationCatalog>(catalog: C.Type, default defaultLocale: LocaleID,
                                        strategy: LocaleStrategy = .pathPrefix()) {
        self.init(supported: C.supportedLocales, default: defaultLocale, strategy: strategy)
    }

    /// The one validator every untrusted locale string passes through:
    /// exact tag, then primary language, then nil.
    public func validated(_ raw: String?) -> LocaleID? {
        guard let raw, let parsed = LocaleID(raw) else { return nil }
        if supported.contains(parsed) { return parsed }
        return supported.first { $0.identifier == parsed.language }
    }
}
