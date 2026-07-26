import Foundation
import SwiftWUI

/// Policy resolution, most specific first (spec §4.3):
/// `Route.prerender ?? App.prerender ?? StaticSiteConfig.defaultPrerender`.
/// nil = nobody declared anything → phase-5 behaviour (static patterns build,
/// dynamic patterns build only for `config.paths` entries).
public enum PrerenderResolution {
    public static func effective(route: Prerender?, app: Prerender?,
                                 config: Prerender?) -> Prerender? {
        route ?? app ?? config
    }
}

/// Operational kill-switch (spec §4.3). FAIL-CLOSED: an operator reaching for
/// `SWIFTWUI_PRERENDER=off` mid-incident must never get the opposite of what
/// they meant, and the safe direction is "off" — the site still works as an SPA.
public enum PrerenderSwitch {
    public static let environmentKey = "SWIFTWUI_PRERENDER"

    public static func enabled(fromEnvironment raw: String?) -> Bool {
        guard let raw else { return true }                       // unset → prerender
        let v = raw.trimmingCharacters(in: .whitespaces).lowercased()
        switch v {
        case "1", "true", "on", "yes": return true
        default: return false
        }
    }
}
