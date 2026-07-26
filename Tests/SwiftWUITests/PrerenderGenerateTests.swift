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
