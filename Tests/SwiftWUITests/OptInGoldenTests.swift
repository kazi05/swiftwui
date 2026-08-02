import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct GoldenBody: Tag {
    var body: some Tag {
        Router {
            // The hover rule is the only thing in this fixture that reaches the
            // stylesheet — without it `styles.css` is empty and a golden over it
            // proves nothing.
            Route("/") { _ in
                Div { Text("home"); Link("/about") { Text("about") } }
                    .hover { $0.style("color", "red") }
            }
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

    /// `Link` renders `A(href: externalize(dest))` — the one call a slug table
    /// rewrites. Both trees' home pages are pinned so the table-free form of that
    /// href (`/about` on en, `/ru/about` on ru) cannot move unnoticed.
    @Test func monolingualPageBytesAreStable() async throws {
        let out = tmp()
        defer { try? FileManager.default.removeItem(atPath: out) }
        _ = try await StaticSite.generate(PlainSite.self, config: config(out))
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home == """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title></title>
        <link href="https://example.com/" rel="canonical" data-swiftwui-ssg>
        <style data-swiftwui>
        .swui-3mxrxd0vfyf8r:hover { color: red }
        </style>
        </head>
        <body><div class="swui-3mxrxd0vfyf8r">home<a data-swui-link href="/about">about</a></div></body></html>
        """)
        let about = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        #expect(about == """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title></title>
        <link href="https://example.com/about" rel="canonical" data-swiftwui-ssg>
        </head>
        <body>about page</body></html>
        """)
    }

    @Test func localizedHomePageBytesAreStable() async throws {
        let out = tmp()
        defer { try? FileManager.default.removeItem(atPath: out) }
        _ = try await StaticSite.generate(PrefixSite.self, config: config(out))
        let en = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(en == """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title></title>
        <link href="https://example.com/" rel="canonical" data-swiftwui-ssg>
        <link href="https://example.com/" hreflang="en" rel="alternate" data-swiftwui-ssg>
        <link href="https://example.com/ru" hreflang="ru" rel="alternate" data-swiftwui-ssg>
        <link href="https://example.com/" hreflang="x-default" rel="alternate" data-swiftwui-ssg>
        <style data-swiftwui>
        .swui-3mxrxd0vfyf8r:hover { color: red }
        </style>
        </head>
        <body><div class="swui-3mxrxd0vfyf8r">home<a data-swui-link href="/about">about</a></div></body></html>
        """)
        let ru = try String(contentsOfFile: out + "/ru/index.html", encoding: .utf8)
        #expect(ru == """
        <!doctype html>
        <html lang="ru">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title></title>
        <link href="https://example.com/ru" rel="canonical" data-swiftwui-ssg>
        <link href="https://example.com/" hreflang="en" rel="alternate" data-swiftwui-ssg>
        <link href="https://example.com/ru" hreflang="ru" rel="alternate" data-swiftwui-ssg>
        <link href="https://example.com/" hreflang="x-default" rel="alternate" data-swiftwui-ssg>
        <style data-swiftwui>
        .swui-3mxrxd0vfyf8r:hover { color: red }
        </style>
        </head>
        <body><div class="swui-3mxrxd0vfyf8r">home<a data-swui-link href="/ru/about">about</a></div></body></html>
        """)
    }

    /// `sitemapPaths` is `.page`-only, so the `<loc>` list doubles as proof that
    /// all eight documents really are `.page` — the precondition this guard rests
    /// on. The surrounding XML carries a `lastmod` date stamp and is not pinned.
    @Test func sitemapListsEveryPageInOrder() async throws {
        // Just the URLs: the surrounding <url> element carries a lastmod stamp
        // that would fail this test tomorrow.
        func locs(_ out: String) throws -> [String] {
            try String(contentsOfFile: out + "/sitemap.xml", encoding: .utf8)
                .components(separatedBy: "<loc>").dropFirst()
                .compactMap { $0.components(separatedBy: "</loc>").first }
        }

        let plain = tmp()
        defer { try? FileManager.default.removeItem(atPath: plain) }
        let plainReport = try await StaticSite.generate(PlainSite.self, config: config(plain))
        #expect(plainReport.sitemapFiles == ["sitemap.xml"])
        let plainLocs = try locs(plain)
        #expect(plainLocs == [
            "https://example.com/",
            "https://example.com/about",
            "https://example.com/todo/1",
            "https://example.com/todo/2",
        ])

        let prefix = tmp()
        defer { try? FileManager.default.removeItem(atPath: prefix) }
        let prefixReport = try await StaticSite.generate(PrefixSite.self, config: config(prefix))
        #expect(prefixReport.sitemapFiles == ["sitemap.xml"])
        let prefixLocs = try locs(prefix)
        #expect(prefixLocs == [
            "https://example.com/",
            "https://example.com/about",
            "https://example.com/todo/1",
            "https://example.com/todo/2",
            "https://example.com/ru",
            "https://example.com/ru/about",
            "https://example.com/ru/todo/1",
            "https://example.com/ru/todo/2",
        ])
    }

    /// `cssFile: true` swaps the inline `<style>` for a link whose depth is
    /// counted from the written file, not the URL — a locale directory pushes it
    /// one level deeper.
    @Test func cssFileOutputIsStable() async throws {
        let out = tmp()
        defer { try? FileManager.default.removeItem(atPath: out) }
        var cfg = config(out)
        cfg.cssFile = true
        _ = try await StaticSite.generate(PrefixSite.self, config: cfg)
        let css = try String(contentsOfFile: out + "/styles.css", encoding: .utf8)
        #expect(css == ".swui-3mxrxd0vfyf8r:hover { color: red }")
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains(#"<link rel="stylesheet" href="styles.css">"#))
        #expect(!home.contains("<style data-swiftwui>"))
        let ruTodo = try String(contentsOfFile: out + "/ru/todo/1/index.html", encoding: .utf8)
        #expect(ruTodo.contains(#"<link rel="stylesheet" href="../../../styles.css">"#))
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
