/// The only place locale prefixes exist.
///
/// The runtime's `currentPath` is always locale-free, so route matching,
/// `@RouteParam`, guards, prerender policies and redirect stubs never learn
/// about locales. Prefixes are applied at three output boundaries only:
/// history writes, `Link` hrefs, and URLs built by SSG.
public enum LocalePath {
    /// Splits a leading locale segment off a PATH — call it after
    /// `RouteURL.split`, a query string is not stripped here. Unknown segments
    /// are left alone — `/de/about` in an app that never declared `de` stays a route.
    ///
    /// Matches the segment against `supported` directly, NOT through
    /// `Localization.validated`: that one reduces the request to its primary
    /// language, so an app declaring only `["en-US"]` would accept `/en/…` and
    /// then rewrite the path under a locale the URL never named.
    public static func internalize(_ path: String, supported: [LocaleID]) -> (path: String, locale: LocaleID?) {
        let normalized = RouteURL._normalize(path)
        let body = normalized.dropFirst()                       // _normalize guarantees the leading "/"
        let head = String(body.prefix { $0 != "/" })
        guard let candidate = LocaleID(head), supported.contains(candidate) else {
            return (normalized, nil)
        }
        let rest = String(body.dropFirst(head.count))
        return (rest.isEmpty ? "/" : RouteURL._normalize(rest), candidate)
    }

    /// Adds the locale segment for every locale except the default, which
    /// lives at the site root (spec §4.2).
    public static func externalize(_ path: String, locale: LocaleID, default defaultLocale: LocaleID) -> String {
        let normalized = RouteURL._normalize(path)
        guard locale != defaultLocale else { return normalized }
        return normalized == "/" ? "/" + locale.identifier : "/" + locale.identifier + normalized
    }
}
