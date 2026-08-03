/// The only place a locale is added to, or read out of, a URL. Prefixes and
/// localized slugs both live here and nowhere else.
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
    ///
    /// With a table, three steps in order: a localized slug wins, then a
    /// DECLARED canonical pattern starting with a literal (locale-free by
    /// definition — otherwise `Route("/de/history")` has its first segment
    /// eaten by the split below), then the prefix. The suffix is cut before
    /// matching and reattached after, so `internalize` is the exact inverse of
    /// `externalize` on every step, not just the fall-through one.
    public static func internalize(_ path: String, supported: [LocaleID],
                                   routes: LocalizedRoutes = .none) -> (path: String, locale: LocaleID?) {
        if !routes.isEmpty {
            let (head, suffix) = _splitSuffix(path)
            if let hit = routes._canonicalPath(for: head) { return (hit.path + suffix, hit.locale) }
            if routes._declaresCanonical(head) { return (RouteURL._normalize(head) + suffix, nil) }
        }
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
    /// lives at the site root (spec §4.2) — unless `routes` gives this path a
    /// slug for `locale`, in which case the slug replaces the prefix entirely.
    public static func externalize(_ path: String, locale: LocaleID, default defaultLocale: LocaleID,
                                   routes: LocalizedRoutes = .none) -> String {
        // Empty table: not one extra operation, and not one changed byte.
        guard !routes.isEmpty else { return prefixed(path, locale: locale, default: defaultLocale) }
        let (head, suffix) = _splitSuffix(path)
        if let slug = routes._localizedPath(for: head, locale: locale) { return slug + suffix }
        return prefixed(head, locale: locale, default: defaultLocale) + suffix
    }

    private static func prefixed(_ path: String, locale: LocaleID, default defaultLocale: LocaleID) -> String {
        let normalized = RouteURL._normalize(path)
        guard locale != defaultLocale else { return normalized }
        return normalized == "/" ? "/" + locale.identifier : "/" + locale.identifier + normalized
    }

    /// Splits at the first "?" or "#". NOT `RouteURL.split`, which discards the
    /// fragment — `Link` hands its whole destination to `externalize`
    /// (Link.swift:30) and a dropped "#top" is a silently broken anchor.
    static func _splitSuffix(_ path: String) -> (head: String, suffix: String) {
        guard let cut = path.firstIndex(where: { $0 == "?" || $0 == "#" }) else { return (path, "") }
        return (String(path[..<cut]), String(path[cut...]))
    }
}
