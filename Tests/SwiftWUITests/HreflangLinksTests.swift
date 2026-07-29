import Testing
import SwiftWUI
@testable import SwiftWUIStatic

@Suite struct HreflangLinksTests {
    private let l10n = Localization(supported: [LocaleID("en")!, LocaleID("ru")!],
                                    default: LocaleID("en")!, strategy: .pathPrefix())

    /// Search engines ignore relative hreflang, so a site with no `siteURL`
    /// gets NO alternates — not a set of relative ones that look fine in the
    /// markup and do nothing.
    @Test func withoutASiteURLThereAreNoAlternates() {
        #expect(HreflangLinks.links(internalPath: "/about", localization: l10n, siteURL: nil).isEmpty)
        #expect(HreflangLinks.links(internalPath: "/about", localization: l10n, siteURL: "").isEmpty)
    }

    /// `x-default` is where a visitor whose language matches nothing lands: the
    /// DEFAULT locale, which under `.pathPrefix` lives at the unprefixed URL.
    @Test func xDefaultPointsAtTheDefaultLocale() {
        let links = HreflangLinks.links(internalPath: "/about", localization: l10n,
                                        siteURL: "https://example.com/")
        func href(_ hreflang: String) -> String? {
            links.first { $0.attributes["hreflang"] == hreflang }?.attributes["href"]
        }
        #expect(href("x-default") == "https://example.com/about")
        #expect(href("en") == "https://example.com/about")
        #expect(href("ru") == "https://example.com/ru/about")
        #expect(links.count == 3)
        #expect(links.allSatisfy { $0.attributes["rel"] == "alternate" })
    }
}
