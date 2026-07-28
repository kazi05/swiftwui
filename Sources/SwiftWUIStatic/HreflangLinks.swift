import SwiftWUI

/// `<link rel="alternate" hreflang>` for every locale plus `x-default`.
/// Only meaningful under `.pathPrefix`: the other strategies serve every
/// language from one URL, so there is nothing to point at.
///
/// No `siteURL`, no alternates — search engines ignore relative hreflang, so
/// they would be dead weight in the head. Same rule `CanonicalSynthesis` applies.
public enum HreflangLinks {
    public static func links(internalPath: String, localization: Localization,
                             siteURL: String?) -> [LinkTag] {
        guard localization.strategy.usesURLPrefix, localization.supported.count > 1,
              var origin = siteURL, !origin.isEmpty else { return [] }
        while origin.hasSuffix("/") { origin.removeLast() }
        func href(_ locale: LocaleID) -> String {
            origin + LocalePath.externalize(internalPath, locale: locale, default: localization.default)
        }
        var out = localization.supported.map { locale in
            LinkTag(attributes: ["rel": "alternate", "hreflang": locale.identifier, "href": href(locale)])
        }
        out.append(LinkTag(attributes: ["rel": "alternate", "hreflang": "x-default",
                                        "href": href(localization.default)]))
        return out
    }
}
