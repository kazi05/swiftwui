/// The boot-time locale decision (spec §3.3). Every input is untrusted — a URL
/// prefix comes from a link somebody else wrote, `localStorage` is writable by
/// any script that ever ran on the origin, `navigator.languages` is
/// user-controlled — so nothing reaches `<html lang>`, a path or a cookie
/// unchecked. The persisted value, the served language and every preferred tag
/// pass `Localization.validated`, which fails closed; the URL prefix is matched
/// against `supported` EXACTLY, by `LocalePath`, because reducing it to its
/// primary language would let `/en/…` be accepted by an app that declares only
/// `en-US` and then rewrite the path under a locale the URL never named.
public enum LocaleResolution {
    public struct Inputs {
        /// The locale the URL EXPLICITLY named, nil when the path carried no
        /// prefix. Not "the locale currently in effect": under `.pathPrefix` the
        /// default locale lives at the site root, so "no prefix" and "the prefix
        /// says the default locale" reach this type as nil and non-nil and are
        /// resolved differently — the first admits detection, the second doesn't.
        public var urlLocale: LocaleID?
        public var servedLang: String?
        public var persisted: String?
        public var preferred: [String]

        public init(urlLocale: LocaleID? = nil, servedLang: String? = nil,
                    persisted: String? = nil, preferred: [String] = []) {
            self.urlLocale = urlLocale
            self.servedLang = servedLang
            self.persisted = persisted
            self.preferred = preferred
        }
    }

    public static func initial(_ inputs: Inputs, localization: Localization) -> LocaleID {
        switch localization.strategy {
        case .pathPrefix(let detection):
            // An explicit prefix wins over storage and navigator under BOTH
            // detection modes: it is either a link somebody deliberately shared
            // or a history entry this runtime wrote itself, and letting an
            // origin-writable store bounce the visitor out of it would break
            // every shared per-locale URL. `.full` still buys detection where
            // the URL says nothing — the unprefixed default-locale root.
            // The `supported` re-check is defence in depth: `Inputs` is public,
            // and an unsupported value falls through to the chain, never out.
            if let url = inputs.urlLocale, localization.supported.contains(url) { return url }
            guard detection == .full else { return localization.default }
            return clientChain(inputs, localization: localization) ?? localization.default

        case .negotiated:
            // The edge already negotiated `Accept-Language` and said so in
            // `<html lang>`; re-running navigator detection on top of that would
            // flip the page on every load whenever the two disagree. Only an
            // explicit stored choice overrides the served document — and when it
            // does, the caller writes the cookie so the next request is served
            // right. Navigator is the last resort for a document that declared
            // no language at all (a dev server, a hand-written shell).
            return localization.validated(inputs.persisted)
                ?? localization.validated(inputs.servedLang)
                ?? firstSupported(inputs.preferred, localization: localization)
                ?? localization.default

        case .client:
            return clientChain(inputs, localization: localization) ?? localization.default
        }
    }

    /// Stored choice first, then the browser's language list.
    private static func clientChain(_ inputs: Inputs, localization: Localization) -> LocaleID? {
        localization.validated(inputs.persisted)
            ?? firstSupported(inputs.preferred, localization: localization)
    }

    private static func firstSupported(_ tags: [String], localization: Localization) -> LocaleID? {
        for tag in tags {
            if let match = localization.validated(tag) { return match }
        }
        return nil
    }
}
