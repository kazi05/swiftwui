import Foundation

/// Server-side locale negotiation for `.negotiated` sites.
///
/// Deliberately duplicated from core's matcher (~15 lines): `SwiftWUIToolchain`
/// must not depend on `SwiftWUI`. `LocaleNegotiationTests.matchesCoreResolution`
/// is the drift guard.
public enum LocaleNegotiation {
    // Sendable: the handler closure is `@Sendable` and the server runs one
    // thread per connection.
    public struct Site: Equatable, Sendable {
        public let strategy: String
        public let locales: [String]
        public let defaultLocale: String
        public init(strategy: String, locales: [String], defaultLocale: String) {
            self.strategy = strategy
            self.locales = locales
            self.defaultLocale = defaultLocale
        }
        public var isNegotiated: Bool { strategy == "negotiated" }
    }

    public static let descriptorName = "swiftwui-site.json"
    public static let cookieName = "swiftwui_locale"

    public static func read(distDir: String) -> Site? {
        guard let data = FileManager.default.contents(atPath: distDir + "/" + descriptorName),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let l10n = root["localization"] as? [String: Any],
              let strategy = l10n["strategy"] as? String,
              let locales = l10n["locales"] as? [String],
              let fallback = l10n["default"] as? String
        else { return nil }
        return Site(strategy: strategy, locales: locales, defaultLocale: fallback)
    }

    /// Tags in descending `q`, ties broken by document order. `*` is dropped.
    public static func parseAcceptLanguage(_ header: String) -> [String] {
        var scored: [(tag: String, q: Double, index: Int)] = []
        for (index, piece) in header.split(separator: ",").enumerated() {
            let parts = piece.split(separator: ";")
            let tag = parts[0].trimmingCharacters(in: .whitespaces)
            guard !tag.isEmpty, tag != "*" else { continue }
            var q = 1.0
            for parameter in parts.dropFirst() {
                let p = parameter.trimmingCharacters(in: .whitespaces)
                if p.hasPrefix("q="), let value = Double(p.dropFirst(2)) { q = value }
            }
            scored.append((tag, q, index))
        }
        return scored.sorted { $0.q == $1.q ? $0.index < $1.index : $0.q > $1.q }.map(\.tag)
    }

    /// Exact tag, then primary subtag. Anything not in `supported` is nil —
    /// the same validation rule the runtime applies before touching a path.
    public static func match(_ tag: String, supported: [String]) -> String? {
        guard tag.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { return nil }
        if supported.contains(tag) { return tag }
        let primary = String(tag.split(separator: "-")[0]).lowercased()
        return supported.first { $0.lowercased() == primary }
    }

    public static func pick(cookie: String?, acceptLanguage: String?, site: Site) -> String {
        if let cookie {
            for pair in cookie.split(separator: ";") {
                let trimmed = pair.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix(cookieName + "=") else { continue }
                let value = String(trimmed.dropFirst(cookieName.count + 1))
                if let matched = match(value, supported: site.locales) { return matched }
            }
        }
        for tag in parseAcceptLanguage(acceptLanguage ?? "") {
            if let matched = match(tag, supported: site.locales) { return matched }
        }
        return site.defaultLocale
    }

    /// Locales longest first, declaration order breaking ties (`sorted` is not
    /// stable, and this feeds a generated file that must not churn between
    /// runs). Regex alternation takes the FIRST match, so a site supporting
    /// both `en` and `en-GB` must offer `en-GB` first or every `en-GB` request
    /// lands in the `en` folder.
    static func regexOrdered(_ locales: [String]) -> [String] {
        locales.enumerated()
            .sorted { $0.element.count == $1.element.count ? $0.offset < $1.offset
                                                          : $0.element.count > $1.element.count }
            .map(\.element)
    }
}
