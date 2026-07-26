import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

@Suite struct CanonicalSynthesisTests {
    @Test func absoluteWhenSiteURLSet() {
        let head = PageHead(title: "t", meta: [], links: [])
        let out = CanonicalSynthesis.apply(to: head, path: "/routes/mcx/mow",
                                           siteURL: "https://x.test", enabled: true)
        #expect(out?.links.first?.attributes["href"] == "https://x.test/routes/mcx/mow")
    }

    @Test func trailingSlashOnSiteURLDoesNotDouble() {
        let out = CanonicalSynthesis.apply(to: PageHead(title: "", meta: [], links: []),
                                           path: "/a", siteURL: "https://x.test/", enabled: true)
        #expect(out?.links.first?.attributes["href"] == "https://x.test/a")
    }

    // No siteURL → no synthesis at all. Existing sites set none, and their
    // output must not change (Global Constraints: StaticSiteTests unchanged).
    @Test func noSiteURLMeansNoCanonical() {
        let out = CanonicalSynthesis.apply(to: PageHead(title: "", meta: [], links: []),
                                           path: "/a/", siteURL: nil, enabled: true)
        #expect(out?.links.isEmpty == true)
    }

    @Test func explicitCanonicalWins() {
        let head = PageHead(title: "", meta: [], links: [.canonical("https://mine.test/x")])
        let out = CanonicalSynthesis.apply(to: head, path: "/a",
                                           siteURL: "https://x.test", enabled: true)
        #expect(out?.links.count == 1)
        #expect(out?.links.first?.attributes["href"] == "https://mine.test/x")
    }

    @Test func disabledSynthesisLeavesHeadAlone() {
        let head = PageHead(title: "", meta: [], links: [])
        let out = CanonicalSynthesis.apply(to: head, path: "/a",
                                           siteURL: "https://x.test", enabled: false)
        #expect(out?.links.isEmpty == true)
    }

    @Test func nilHeadGainsOnlyTheCanonical() {
        let out = CanonicalSynthesis.apply(to: nil, path: "/a",
                                           siteURL: "https://x.test", enabled: true)
        #expect(out?.title == "")
        #expect(out?.links.count == 1)
    }
}
