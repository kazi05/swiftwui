import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct TopRoutesApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { Text("home") }
            Route("/account") { Text("private") }.prerender(.never)
            Route("/routes/:from/:to") { p in Text("\(p["from"] ?? "")→\(p["to"] ?? "")") }
                .prerender(.paths { ["/routes/mcx/mow", "/routes/led/mow"] }.allowingOnDemand())
            Route("/tail/:id") { p in Text(p["id"] ?? "") }
                .prerender(.onDemand)
        }
    }
}

private func tmpDir() -> String {
    let d = NSTemporaryDirectory() + "swui-ssg-\(UUID().uuidString)"
    try! FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true)
    return d
}

@Suite @MainActor struct PrerenderGenerateTests {
    @Test func providerPathsAreRendered() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(TopRoutesApp.self,
                                                   config: .init(outDir: out, mode: .staticOnly))
        #expect(report.pages.contains("/routes/mcx/mow"))
        #expect(report.pages.contains("/routes/led/mow"))
        let html = try String(contentsOfFile: out + "/routes/mcx/mow/index.html", encoding: .utf8)
        #expect(html.contains("mcx→mow"))
    }

    @Test func neverRouteProducesNoFile() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(TopRoutesApp.self,
                                                   config: .init(outDir: out, mode: .staticOnly))
        #expect(!report.pages.contains("/account"))
        #expect(!FileManager.default.fileExists(atPath: out + "/account/index.html"))
    }

    @Test func onDemandOnlyPatternIsReportedNotSkipped() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(TopRoutesApp.self,
                                                   config: .init(outDir: out, mode: .staticOnly))
        #expect(report.onDemandPatterns.contains("/tail/:id"))
        #expect(!report.skippedPatterns.contains("/tail/:id"))
    }

    @Test func killSwitchRendersNothing() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(
            TopRoutesApp.self,
            config: .init(outDir: out, mode: .staticOnly, prerenderEnabled: false))
        #expect(report.pages.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: out + "/index.html"))
    }

    @Test func killSwitchBeatsExplicitRoutePolicy() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(
            TopRoutesApp.self,
            config: .init(outDir: out, mode: .staticOnly, prerenderEnabled: false))
        #expect(!report.pages.contains("/routes/mcx/mow"))
    }

    @Test func appDefaultNeverStillLetsRouteOptIn() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(AppNeverApp.self,
                                                   config: .init(outDir: out, mode: .staticOnly))
        #expect(report.pages == ["/opted-in"])
    }

    @Test func providerPathNotMatchingPatternGoesToUnmatched() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(MismatchedProviderApp.self,
                                                   config: .init(outDir: out, mode: .staticOnly))
        #expect(report.pages == ["/routes/mcx/mow"])
        #expect(!report.pages.contains("/oops"))
        #expect(report.unmatchedPaths.contains("/oops"))
    }

    // final-review #1: render() is a manual primitive independent of generate(),
    // so the kill-switch has to be re-verified against it directly.
    @Test func killSwitchBlocksRenderPath() async throws {
        let page = try await StaticSite.render(TopRoutesApp.self, path: "/",
                                               config: .init(outDir: tmpDir(), mode: .staticOnly,
                                                             prerenderEnabled: false))
        guard case .error = page.outcome else {
            Issue.record("expected .error, got \(page.outcome)")
            return
        }
        #expect(page.html.isEmpty)
    }

    // final-review #5: a paths{} provider that yields nothing usable (empty,
    // or every produced path already claimed) must still surface in a report
    // bucket — otherwise a build meant to emit thousands of pages that emits
    // zero gives no signal.
    @Test func emptyProviderOutputIsReportedAsSkipped() async throws {
        let out = tmpDir()
        let report = try await StaticSite.generate(EmptyProviderApp.self,
                                                   config: .init(outDir: out, mode: .staticOnly))
        #expect(report.skippedPatterns.contains("/items/:id"))
        #expect(report.pages.isEmpty)
    }

    // final-review #3: the headline feature (data-driven <head> via @RouteParam
    // + .staticTask + .pageMeta on a provider-enumerated route) has to reach
    // the actual written file, not just the pure CanonicalSynthesis function.
    @Test func providerRouteWiresDataDrivenTitleAndCanonicalIntoWrittenHTML() async throws {
        let out = tmpDir()
        _ = try await StaticSite.generate(ProviderMetaApp.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://x.test"))
        let html = try String(contentsOfFile: out + "/items/42/index.html", encoding: .utf8)
        #expect(html.contains("<title>Item 42 — 100 ₽</title>"))
        #expect(html.contains("<link href=\"https://x.test/items/42\" rel=\"canonical\" data-swiftwui>"))
    }
}

private struct EmptyProviderApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/items/:id") { Text("item") }
                .prerender(.paths { [] })
        }
    }
}

private struct ItemMetaPage: Tag {
    @RouteParam("id") var id: String?
    @State private var price: Int? = nil
    var body: some Tag {
        P { Text("item") }
            .staticTask { price = 100 }
            .pageMeta(title: price.map { "Item \(id ?? "?") — \($0) ₽" })
    }
}

private struct ProviderMetaApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/items/:id") { ItemMetaPage() }
                .prerender(.paths { ["/items/42"] })
        }
    }
}

private struct MismatchedProviderApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/routes/:from/:to") { p in Text("\(p["from"] ?? "")→\(p["to"] ?? "")") }
                .prerender(.paths { ["/routes/mcx/mow", "/oops"] })
        }
    }
}

private struct AppNeverApp: App {
    init() {}
    static var prerender: Prerender? { .never }
    var body: some Tag {
        Router {
            Route("/") { Text("home") }                          // inherits .never
            Route("/opted-in") { Text("yes") }.prerender(.build)
        }
    }
}
