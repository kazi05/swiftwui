import Testing
import SwiftWUI
@testable import SwiftWUIStatic

@Suite struct HreflangLinksTests {
    private let en = LocaleID("en")!, ru = LocaleID("ru")!
    private var l10n: Localization {
        Localization(supported: [en, ru], default: en, strategy: .pathPrefix())
    }

    /// Search engines ignore relative hreflang, so a site with no `siteURL`
    /// gets NO alternates — not a set of relative ones that look fine in the
    /// markup and do nothing.
    @Test func withoutASiteURLThereAreNoAlternates() {
        let written = [en: "/about", ru: "/ru/about"]
        #expect(HreflangLinks.links(alternates: written, localization: l10n, siteURL: nil).isEmpty)
        #expect(HreflangLinks.links(alternates: written, localization: l10n, siteURL: "").isEmpty)
    }

    /// `x-default` is where a visitor whose language matches nothing lands: the
    /// DEFAULT locale, which under `.pathPrefix` lives at the unprefixed URL.
    @Test func xDefaultPointsAtTheDefaultLocale() {
        let links = HreflangLinks.links(alternates: [en: "/about", ru: "/ru/about"],
                                        localization: l10n, siteURL: "https://example.com/")
        func href(_ hreflang: String) -> String? {
            links.first { $0.attributes["hreflang"] == hreflang }?.attributes["href"]
        }
        #expect(href("x-default") == "https://example.com/about")
        #expect(href("en") == "https://example.com/about")
        #expect(href("ru") == "https://example.com/ru/about")
        #expect(links.count == 3)
        #expect(links.allSatisfy { $0.attributes["rel"] == "alternate" })
    }

    /// The hrefs are whatever was written — nothing here recomputes a path.
    @Test func hrefsAreTheURLsThatWereWritten() {
        let links = HreflangLinks.links(alternates: [en: "/delivery/moscow", ru: "/dostavka/moscow"],
                                        localization: l10n, siteURL: "https://example.com")
        #expect(links.map { $0.attributes["href"]! } == [
            "https://example.com/delivery/moscow",
            "https://example.com/dostavka/moscow",
            "https://example.com/delivery/moscow",     // x-default
        ])
    }

    /// A locale that produced no page at this path is not advertised — and a
    /// cluster of one is no cluster, so it is dropped whole. Half a cluster
    /// invalidates the other half in Google's eyes.
    @Test func aLocaleThatProducedNothingIsNotAdvertised() {
        #expect(HreflangLinks.links(alternates: [en: "/about"], localization: l10n,
                                    siteURL: "https://example.com").isEmpty)
        let three = Localization(supported: [en, ru, LocaleID("de")!], default: en,
                                 strategy: .pathPrefix())
        let links = HreflangLinks.links(alternates: [en: "/about", ru: "/ru/about"],
                                        localization: three, siteURL: "https://example.com")
        #expect(links.compactMap { $0.attributes["hreflang"] } == ["en", "ru", "x-default"])
    }

    /// Emission order is `supported`, never the map's own ordering — the bytes
    /// of every already-published page depend on it.
    @Test func emissionOrderFollowsSupported() {
        let reversed = Localization(supported: [ru, en], default: en, strategy: .pathPrefix())
        let links = HreflangLinks.links(alternates: [en: "/about", ru: "/ru/about"],
                                        localization: reversed, siteURL: "https://example.com")
        #expect(links.compactMap { $0.attributes["hreflang"] } == ["ru", "en", "x-default"])
    }

    /// `.negotiated` and `.client` serve every language from one URL: there is
    /// no sibling URL to point at, whatever the map says.
    @Test func nonPrefixStrategiesGetNothing() {
        let negotiated = Localization(supported: [en, ru], default: en, strategy: .negotiated)
        #expect(HreflangLinks.links(alternates: [en: "/about", ru: "/about"],
                                    localization: negotiated, siteURL: "https://example.com").isEmpty)
    }
}
