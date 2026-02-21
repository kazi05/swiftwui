// Localization.swift - Internationalization (i18n) support

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import SwiftWUIState

/// A catalog of localized strings keyed by locale and string key.
///
/// Supports locale fallback: exact locale -> base locale -> English -> key.
///
/// ```swift
/// var strings = LocalizedStringCatalog()
/// strings.add(locale: "en", key: "greeting", value: "Hello")
/// strings.add(locale: "ru", key: "greeting", value: "Привет")
/// strings.localized("greeting", locale: "ru")  // "Привет"
/// ```
public struct LocalizedStringCatalog: Sendable {
    // [locale: [key: value]]
    private var translations: [String: [String: String]]

    public init() {
        self.translations = [:]
    }

    /// Add a single localized string.
    ///
    /// - Parameters:
    ///   - locale: The locale identifier (e.g. `"en"`, `"ru"`, `"en-US"`).
    ///   - key: The string key used for lookup.
    ///   - value: The localised string value.
    public mutating func add(locale: String, key: String, value: String) {
        translations[locale, default: [:]][key] = value
    }

    /// Add all translations for a locale at once.
    ///
    /// - Parameters:
    ///   - locale: The locale identifier.
    ///   - translations: A dictionary mapping keys to localised values.
    public mutating func add(locale: String, translations dict: [String: String]) {
        for (key, value) in dict {
            translations[locale, default: [:]][key] = value
        }
    }

    /// Get a localized string for the given key and locale.
    ///
    /// Fallback order:
    /// 1. Exact locale match (e.g. `"en-US"`)
    /// 2. Base locale (e.g. `"en"` from `"en-US"`)
    /// 3. English (`"en"`)
    /// 4. The key itself
    ///
    /// - Parameters:
    ///   - key: The string key.
    ///   - locale: The desired locale identifier.
    /// - Returns: The localised string, or the key if no translation exists.
    public func localized(_ key: String, locale: String) -> String {
        // Try exact locale (e.g., "en-US")
        if let value = translations[locale]?[key] {
            return value
        }
        // Try base locale (e.g., "en" from "en-US")
        let baseLocale = String(locale.prefix(2))
        if baseLocale != locale, let value = translations[baseLocale]?[key] {
            return value
        }
        // Fallback to English
        if let value = translations["en"]?[key] {
            return value
        }
        // Return key as-is
        return key
    }

    /// All locale identifiers that have at least one translation.
    public var availableLocales: [String] {
        Array(translations.keys).sorted()
    }
}

// MARK: - Environment Integration

/// Environment key for the current locale identifier.
struct LocaleKey: EnvironmentKey {
    public static var defaultValue: String {
        #if arch(wasm32)
        return JSObject.global.navigator.object!.language.string ?? "en"
        #else
        return "en"
        #endif
    }
}

extension EnvironmentValues {
    /// The current locale identifier (e.g. `"en-US"`, `"ru"`).
    public var locale: String {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
}
