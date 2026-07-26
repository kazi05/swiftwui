import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic
@testable import SwiftWUIToolchain

@Suite struct SitemapTests {
    @Test func singleFileBelowThreshold() {
        let docs = Sitemap.documents(paths: ["/", "/about"], siteURL: "https://x.test",
                                     lastmod: "2026-07-26")
        #expect(docs.count == 1)
        #expect(docs[0].name == "sitemap.xml")
        #expect(docs[0].xml.contains("<loc>https://x.test/</loc>"))
        #expect(docs[0].xml.contains("<loc>https://x.test/about</loc>"))
        #expect(docs[0].xml.contains("<lastmod>2026-07-26</lastmod>"))
    }

    @Test func indexFanOutAboveThreshold() {
        let paths = (0..<5).map { "/p\($0)" }
        let docs = Sitemap.documents(paths: paths, siteURL: "https://x.test",
                                     lastmod: "2026-07-26", maxPerFile: 2)
        #expect(docs.count == 4)                                  // index + 3 chunks
        #expect(docs[0].name == "sitemap.xml")
        #expect(docs[0].xml.contains("<sitemapindex"))
        #expect(docs[0].xml.contains("<loc>https://x.test/sitemap-1.xml</loc>"))
        #expect(docs[3].name == "sitemap-3.xml")
    }

    @Test func urlsAreXMLEscaped() {
        let docs = Sitemap.documents(paths: ["/a&b"], siteURL: "https://x.test",
                                     lastmod: "2026-07-26")
        #expect(docs[0].xml.contains("/a&amp;b"))
        #expect(!docs[0].xml.contains("/a&b</loc>"))
    }

    @Test func trailingSlashOnSiteURLDoesNotDouble() {
        let docs = Sitemap.documents(paths: ["/a"], siteURL: "https://x.test/",
                                     lastmod: "2026-07-26")
        #expect(docs[0].xml.contains("<loc>https://x.test/a</loc>"))
    }
}

/// A static route whose guard redirects to itself never actually navigates
/// (Runtime.navigate no-ops when target == currentPath), so `renderPage`
/// settles on the SAME path it was asked to render while `_routeMatched` is
/// false — outcome `.notFound`, landing in `report.pages` (pre-existing
/// behavior, spec-preserved) but NOT a redirect. Confirms `generate()`'s
/// sitemap step must filter outcome, not just consume `report.pages` as-is.
private struct SelfRedirectApp: App {
    init() {}
    var body: some Tag {
        Router(notFound: { P { Text("nope") } }) {
            Route("/") { P { Text("home") } }
            Route("/blocked", guard: { .redirect("/blocked") }) { P { Text("secret") } }
        }
    }
}

@Suite @MainActor struct SitemapExcludesNotFoundTests {
    @Test func notFoundPageIsExcludedFromSitemapButKeptInReportPages() async throws {
        let out = NSTemporaryDirectory() + "swui-sitemap-notfound-\(UUID().uuidString)"
        let report = try await StaticSite.generate(SelfRedirectApp.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://x.test"))
        #expect(report.pages.contains("/blocked"))          // pre-existing behavior, unchanged
        #expect(report.redirects.isEmpty)                   // not a redirect — the leak this pins
        let sitemap = try String(contentsOfFile: out + "/sitemap.xml", encoding: .utf8)
        #expect(sitemap.contains("<loc>https://x.test/</loc>"))
        #expect(!sitemap.contains("/blocked"))
    }
}

@Suite struct RobotsConventionTests {
    @Test func robotsTxtFromPublicReachesDist() throws {
        let fm = FileManager.default
        let root = NSTemporaryDirectory() + "swui-robots-\(UUID().uuidString)"
        try fm.createDirectory(atPath: root + "/public", withIntermediateDirectories: true)
        try "User-agent: *\nAllow: /\n".write(toFile: root + "/public/robots.txt",
                                              atomically: true, encoding: .utf8)
        let out = root + "/dist"
        try fm.createDirectory(atPath: out, withIntermediateDirectories: true)
        try DistLayout.copyPublic(projectDir: root, outDir: out)      // WasmBuild.swift:79
        #expect(fm.fileExists(atPath: out + "/robots.txt"))
    }
}
