import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct GoldenBody: Tag {
    var body: some Tag {
        Router {
            Route("/") { _ in Div { Text("home"); Link("/about") { Text("about") } } }
            Route("/about") { _ in Text("about page") }
            Route("/todo/:id") { p in Text("todo " + (p["id"] ?? "")) }
        }
    }
}

/// Monolingual: the path every existing project is on.
private struct PlainSite: App {
    init() {}
    var body: some Tag { GoldenBody() }
}

/// Localized but table-free: the path this feature must not disturb.
private struct PrefixSite: App {
    init() {}
    var body: some Tag { GoldenBody() }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!],
                     default: LocaleID("en")!, strategy: .pathPrefix())
    }
}

@Suite @MainActor struct OptInGoldenTests {
    private func tmp() -> String {
        NSTemporaryDirectory() + "swiftwui-golden-\(UUID().uuidString)"
    }

    private func config(_ out: String) -> StaticSiteConfig {
        StaticSiteConfig(outDir: out, mode: .staticOnly,
                         paths: ["/todo/1", "/todo/2"],
                         siteURL: "https://example.com")
    }

    @Test func monolingualWrittenFileOrderIsStable() async throws {
        let out = tmp()
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(PlainSite.self, config: config(out))
        #expect(report.writtenFiles == [
            "index.html",
            "about/index.html",
            "todo/1/index.html",
            "todo/2/index.html",
        ])
    }

    @Test func localizedWrittenFileOrderIsStable() async throws {
        let out = tmp()
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(PrefixSite.self, config: config(out))
        #expect(report.writtenFiles == [
            "index.html",
            "about/index.html",
            "todo/1/index.html",
            "todo/2/index.html",
            "ru/index.html",
            "ru/about/index.html",
            "ru/todo/1/index.html",
            "ru/todo/2/index.html",
        ])
    }

    @Test func localizedAboutPageBytesAreStable() async throws {
        let out = tmp()
        defer { try? FileManager.default.removeItem(atPath: out) }
        _ = try await StaticSite.generate(PrefixSite.self, config: config(out))
        let html = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)
        #expect(html == """
        <!doctype html>
        <html lang="ru">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title></title>
        <link href="https://example.com/ru/about" rel="canonical" data-swiftwui-ssg>
        <link href="https://example.com/about" hreflang="en" rel="alternate" data-swiftwui-ssg>
        <link href="https://example.com/ru/about" hreflang="ru" rel="alternate" data-swiftwui-ssg>
        <link href="https://example.com/about" hreflang="x-default" rel="alternate" data-swiftwui-ssg>
        </head>
        <body>about page</body></html>
        """)
    }
}
