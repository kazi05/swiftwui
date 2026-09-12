import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic
@testable import SwiftWUIToolchain

private struct IndexedDeliveryPage: Tag, Page {
    var title: String { "Delivery" }
    var meta: [MetaTag] { [.description("A crawlable delivery fixture")] }
    var body: some Tag { Div { Link("/about") { Text("about") } } }
}

private struct IndexedDeliveryApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { IndexedDeliveryPage() }
            Route("/about") { IndexedDeliveryPage() }
        }
    }
}

private struct EscapedURLPage: Tag, Page {
    let link: String
    var title: String { "Escaped URL" }
    var meta: [MetaTag] { [.description("A page whose URL contains an HTML attribute delimiter")] }
    var body: some Tag { Link(link) { Text("destination") } }
}

private struct EscapedURLApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { EscapedURLPage(link: "/r&d") }
            Route("/r&d") { EscapedURLPage(link: "/") }
        }
    }
}

private struct PercentEncodedURLApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { EscapedURLPage(link: "/caf%C3%A9") }
            Route("/café") { EscapedURLPage(link: "/") }
        }
    }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@Suite @MainActor struct StaticDeliveryTests {
    private func out() -> String { NSTemporaryDirectory() + "swiftwui-delivery-" + UUID().uuidString }

    @Test func indexedBuildWritesValidatedManifestAndRedirectFallback() async throws {
        let dir = out(); defer { try? FileManager.default.removeItem(atPath: dir) }
        let report = try await StaticSite.generate(IndexedDeliveryApp.self, config: .init(
            outDir: dir, mode: .staticOnly, siteURL: "https://example.com", indexing: .indexed,
            delivery: .init(redirects: [.init(from: "/old", to: "/about", status: .movedPermanently)],
                            trailingSlash: .never)))
        #expect(report.redirectStatuses["/old"] == 301)
        #expect(report.deliveryManifest == StaticDeliveryManifest.fileName)
        let manifest = try String(contentsOfFile: dir + "/" + StaticDeliveryManifest.fileName, encoding: .utf8)
        #expect(manifest.contains(#""trailingSlash":"never""#))
        #expect(manifest.contains(#""status":301"#))
        let html = try String(contentsOfFile: dir + "/index.html", encoding: .utf8)
        #expect(!html.contains("type=\"module\""))
    }

    @Test func privateBuildRemainsValidWithoutPublicMetadata() async throws {
        let dir = out(); defer { try? FileManager.default.removeItem(atPath: dir) }
        _ = try await StaticSite.generate(IndexedDeliveryApp.self,
                                          config: .init(outDir: dir, mode: .staticOnly))
    }

    @Test func publicBuildReportsMissingDescriptionAndOrigin() async throws {
        let dir = out(); defer { try? FileManager.default.removeItem(atPath: dir) }
        await #expect(throws: StaticSiteError.self) {
            try await StaticSite.generate(IndexedDeliveryApp.self,
                                          config: .init(outDir: dir, mode: .staticOnly, indexing: .indexed))
        }
    }

    @Test func indexedValidationDecodesEscapedCanonicalAndLinks() async throws {
        let dir = out(); defer { try? FileManager.default.removeItem(atPath: dir) }
        let report = try await StaticSite.generate(EscapedURLApp.self, config: .init(
            outDir: dir, mode: .staticOnly, siteURL: "https://example.com", indexing: .indexed
        ))

        #expect(report.pages.contains("/r&d"))
    }

    @Test func indexedValidationMatchesPercentEncodedUnicodeByRouteSegment() async throws {
        let dir = out(); defer { try? FileManager.default.removeItem(atPath: dir) }
        let report = try await StaticSite.generate(PercentEncodedURLApp.self, config: .init(
            outDir: dir, mode: .staticOnly, siteURL: "https://example.com", indexing: .indexed
        ))

        #expect(report.pages.contains("/café"))
    }

    @Test func previewReturnsManifestRedirectAndCanonicalSlashRedirect() async throws {
        let dir = out(); defer { try? FileManager.default.removeItem(atPath: dir) }
        try FileManager.default.createDirectory(atPath: dir + "/about", withIntermediateDirectories: true)
        try "about".write(toFile: dir + "/about/index.html", atomically: true, encoding: .utf8)
        try "not found".write(toFile: dir + "/404.html", atomically: true, encoding: .utf8)
        let delivery = StaticDelivery(trailingSlash: .never, fallback: .notFound,
                                      redirects: [.init(from: "/old", to: "/about", status: 301)],
                                      routes: ["/about"])
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir, spaFallback: true,
                                                                delivery: delivery)])
        try server.start(port: 0); defer { server.stop() }
        let old = try await response(port: server.boundPort, path: "/old")
        #expect(old.status == 301 && old.location == "/about")
        let slash = try await response(port: server.boundPort, path: "/about/")
        #expect(slash.status == 308 && slash.location == "/about")
        let known = try await response(port: server.boundPort, path: "/about")
        #expect(known.status == 200 && known.body == "about")
        let missing = try await response(port: server.boundPort, path: "/missing")
        #expect(missing.status == 404 && missing.body == "not found")
    }

    @Test func redirectPathsCannotEscapeTheOutputDirectory() async throws {
        let base = out(); defer { try? FileManager.default.removeItem(atPath: base) }
        let dist = base + "/dist"
        let escaped = base + "/escaped/index.html"

        await #expect(throws: StaticSiteError.self) {
            try await StaticSite.generate(IndexedDeliveryApp.self, config: .init(
                outDir: dist, mode: .staticOnly,
                delivery: .init(redirects: [.init(from: "/../escaped", to: "/about")])
            ))
        }
        #expect(!FileManager.default.fileExists(atPath: escaped))
    }

    @Test func writeDocumentRejectsSymlinkedOutputDirectory() throws {
        let base = out(); defer { try? FileManager.default.removeItem(atPath: base) }
        let dist = base + "/dist"
        let outside = base + "/outside"
        try FileManager.default.createDirectory(atPath: dist, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: dist + "/jump", withDestinationPath: outside)

        #expect(throws: StaticSiteError.self) {
            try StaticSite.writeDocument("escaped", path: "/jump", outDir: dist)
        }
        #expect(!FileManager.default.fileExists(atPath: outside + "/index.html"))
    }

    @Test func writeDocumentRejectsEncodedTraversalPath() throws {
        let base = out(); defer { try? FileManager.default.removeItem(atPath: base) }

        #expect(throws: StaticSiteError.self) {
            try StaticSite.writeDocument("unreachable", path: "/%2e%2e%2fescape", outDir: base)
        }
        #expect(!FileManager.default.fileExists(atPath: base + "/%2e%2e%2fescape/index.html"))
    }

    @Test func previewRejectsEncodedDotSegmentsAndSeparators() throws {
        let dir = out(); defer { try? FileManager.default.removeItem(atPath: dir) }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let unsafePaths = ["/%2e%2e/escape", "/..%2fescape", "/%2E%2E%5Cescape"]

        for path in unsafePaths {
            let json = """
            {"version":1,"trailingSlash":"preserve","fallback":"spa","redirects":[{"from":"\(path)","to":"/about","status":308}],"routes":[]}
            """
            try json.write(toFile: dir + "/" + StaticDelivery.descriptorName,
                           atomically: true, encoding: .utf8)
            #expect(StaticDelivery.read(distDir: dir) == nil)
        }
    }

    private func response(port: UInt16, path: String) async throws -> (status: Int, location: String?, body: String) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        request.httpMethod = "GET"
        let delegate = NoRedirectDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        let (data, response) = try await session.data(for: request)
        let http = try #require(response as? HTTPURLResponse)
        return (http.statusCode, http.value(forHTTPHeaderField: "Location"), String(decoding: data, as: UTF8.self))
    }
}
