import SwiftWUI

/// `<link rel="alternate" hreflang>` for every locale that ACTUALLY produced a
/// page at this canonical path, plus `x-default`.
///
/// The set is passed in, not recomputed from `localization.supported`: with a
/// `routePaths` table a locale may not have enumerated this path, may have
/// fallen through to `notFound`, or may have collided with a sibling. Google
/// ignores an entire cluster when reciprocity breaks — including the pairs that
/// were correct — and under localized slugs hreflang is the ONLY thing linking
/// `/delivery/moscow` to `/dostavka/moscow`.
///
/// Only meaningful under `.pathPrefix`: the other strategies serve every
/// language from one URL, so there is nothing to point at.
///
/// No `siteURL`, no alternates — search engines ignore relative hreflang, so
/// they would be dead weight in the head. Same rule `CanonicalSynthesis` applies.
public enum HreflangLinks {
    public static func links(alternates: [LocaleID: String], localization: Localization,
                             siteURL: String?) -> [LinkTag] {
        guard localization.strategy.usesURLPrefix, alternates.count > 1,
              var origin = siteURL, !origin.isEmpty else { return [] }
        while origin.hasSuffix("/") { origin.removeLast() }
        // Emission order is `supported`, exactly as before this map existed —
        // re-sorting would change the bytes of every existing localized page,
        // table or no table.
        var out = localization.supported.compactMap { locale -> LinkTag? in
            guard let href = alternates[locale] else { return nil }
            return LinkTag(attributes: ["rel": "alternate", "hreflang": locale.identifier,
                                        "href": origin + href])
        }
        if let fallback = alternates[localization.default] {
            out.append(LinkTag(attributes: ["rel": "alternate", "hreflang": "x-default",
                                            "href": origin + fallback]))
        }
        return out
    }
}
