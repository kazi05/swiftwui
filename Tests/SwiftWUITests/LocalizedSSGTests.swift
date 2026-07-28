import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private let title = LocalizedText(key: "t") { locale in
    switch locale.language {
    case "en": return "Home"
    case "ru": return "Главная"
    default: return nil
    }
}

/// The `Link` is load-bearing: it is the only in-document URL the strategies
/// are allowed to disagree about, and SSG + locale seeding + `Link` is exactly
/// the combination this task introduced.
private struct SiteBody: Tag {
    var body: some Tag {
        Router {
            Route("/") { _ in Text(title) }
            Route("/about") { _ in Div { Text(title); Link("/about") { Text("self") } } }
        }
    }
}

private struct PrefixSite: App {
    init() {}
    var body: some Tag { SiteBody() }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix())
    }
}

private struct NegotiatedSite: App {
    init() {}
    var body: some Tag { SiteBody() }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .negotiated)
    }
}

@Suite @MainActor struct LocalizedSSGTests {
    private func outDir() -> String {
        NSTemporaryDirectory() + "swiftwui-ssg-" + UUID().uuidString
    }

    @Test func pathPrefixWritesOneTreePerLocale() async throws {
        let out = outDir()
        let config = StaticSiteConfig(outDir: out, mode: .staticOnly, siteURL: "https://example.com")
        let report = try await StaticSite.generate(PrefixSite.self, config: config)
        #expect(report.locales.map(\.identifier) == ["en", "ru"])

        let en = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        let ru = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)
        #expect(en.contains("Home"))
        #expect(ru.contains("Главная"))
        #expect(ru.contains(#"<html lang="ru""#))
        #expect(ru.contains(#"hreflang="en""#) && ru.contains(#"hreflang="x-default""#))
        // Attributes are emitted in sorted order, so href precedes rel.
        #expect(ru.contains(#"<link href="https://example.com/ru/about" rel="canonical""#))
        #expect(en.contains(#"<link href="https://example.com/about" rel="canonical""#))
        // The alternates are absolute and point at the OTHER locale's URL.
        #expect(ru.contains(#"<link href="https://example.com/about" hreflang="en" rel="alternate""#))
        #expect(ru.contains(#"<link href="https://example.com/ru/about" hreflang="ru" rel="alternate""#))
        // Every URL in the document agrees with the folder it was written to.
        #expect(ru.contains(#"href="/ru/about""#))
        #expect(en.contains(#"href="/about""#))
    }

    @Test func negotiatedKeepsCleanUrlsInsidePerLocaleFolders() async throws {
        let out = outDir()
        let config = StaticSiteConfig(outDir: out, mode: .staticOnly, siteURL: "https://example.com")
        let report = try await StaticSite.generate(NegotiatedSite.self, config: config)
        let ru = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)
        #expect(ru.contains("Главная"))
        #expect(ru.contains(#"<html lang="ru""#))
        #expect(!ru.contains("hreflang"))                       // one URL — nothing to point at
        #expect(ru.contains(#"<link href="https://example.com/about" rel="canonical""#))
        // The whole point of the strategy: the folder says "ru", the hrefs don't.
        #expect(ru.contains(#"href="/about""#))
        #expect(!ru.contains(#"href="/ru/about""#))
        #expect(report.pages.contains("/about"))
        #expect(!report.pages.contains("/ru/about"))
        let descriptor = try String(contentsOfFile: out + "/swiftwui-site.json", encoding: .utf8)
        #expect(descriptor.contains("\"negotiated\""))
    }

    @Test func rtlLocaleGetsDirAttribute() async throws {
        struct RTLSite: App {
            init() {}
            // A Router is what enumeration collects paths from — an app without
            // one generates no pages at all.
            var body: some Tag { Router { Route("/") { Text("x") } } }
            static var localization: Localization? {
                Localization(supported: [LocaleID("en")!, LocaleID("ar")!], default: LocaleID("en")!,
                             strategy: .pathPrefix())
            }
        }
        let out = outDir()
        let config = StaticSiteConfig(outDir: out, mode: .staticOnly)
        _ = try await StaticSite.generate(RTLSite.self, config: config)
        let ar = try String(contentsOfFile: out + "/ar/index.html", encoding: .utf8)
        #expect(ar.contains(#"dir="rtl""#))
    }

    /// The boot compares the snapshot's path to `location.pathname` literally,
    /// so a prefixed page must record the prefixed path — otherwise hydration
    /// discards the whole snapshot and re-runs every loader.
    @Test func snapshotPathCarriesThePrefix() async throws {
        let out = outDir()
        let report = try await StaticSite.generate(PrefixSite.self, config: StaticSiteConfig(
            outDir: out, mode: .hydrate(wasmScriptPath: "/app.js")))
        let ru = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)
        #expect(ru.contains(#""path":"\/ru\/about""#))
        let en = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        #expect(en.contains(#""path":"\/about""#))
        #expect(report.writtenFiles.contains("ru/about/index.html"))
        #expect(report.writtenFiles.contains("about/index.html"))
    }

    /// styles.css lives at the dist root, so the href has to count the REAL
    /// directory depth of the written file — which a prefixed or foldered
    /// locale pushes one level deeper than the URL suggests.
    @Test func cssHrefCountsTheLocaleDirectory() async throws {
        let out = outDir()
        _ = try await StaticSite.generate(PrefixSite.self, config: StaticSiteConfig(
            outDir: out, mode: .staticOnly, cssFile: true))
        let en = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        let ru = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)
        #expect(en.contains(#"<link rel="stylesheet" href="../styles.css">"#))
        #expect(ru.contains(#"<link rel="stylesheet" href="../../styles.css">"#))

        let neg = outDir()
        _ = try await StaticSite.generate(NegotiatedSite.self, config: StaticSiteConfig(
            outDir: neg, mode: .staticOnly, cssFile: true))
        // .negotiated gives EVERY locale a folder, the default one included.
        let negEn = try String(contentsOfFile: neg + "/en/about/index.html", encoding: .utf8)
        #expect(negEn.contains(#"<link rel="stylesheet" href="../../styles.css">"#))
    }

    @Test func clientStrategyWritesOneTreeInTheDefaultLocale() async throws {
        struct ClientSite: App {
            init() {}
            var body: some Tag { SiteBody() }
            static var localization: Localization? {
                Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                             strategy: .client)
            }
        }
        let out = outDir()
        let report = try await StaticSite.generate(ClientSite.self, config: StaticSiteConfig(
            outDir: out, mode: .staticOnly))
        #expect(report.locales.map(\.identifier) == ["en"])
        let en = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        #expect(en.contains("Home") && en.contains(#"<html lang="en""#))
        #expect(!FileManager.default.fileExists(atPath: out + "/ru/about/index.html"))
        #expect(!en.contains("hreflang"))
    }

    /// The stub is a URL a browser follows, so it must not drop a Russian
    /// visitor into the English site.
    @Test func redirectStubKeepsTheLocalePrefix() async throws {
        struct GuardedSite: App {
            init() {}
            var body: some Tag {
                Router {
                    Route("/") { Text("home") }
                    Route("/admin", guard: { .redirect("/") }) { Text("secret") }
                }
            }
            static var localization: Localization? {
                Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                             strategy: .pathPrefix())
            }
        }
        let out = outDir()
        let report = try await StaticSite.generate(GuardedSite.self, config: StaticSiteConfig(
            outDir: out, mode: .staticOnly))
        #expect(report.redirects["/ru/admin"] == "/ru")
        #expect(report.redirects["/admin"] == "/")
        let ru = try String(contentsOfFile: out + "/ru/admin/index.html", encoding: .utf8)
        #expect(ru.contains("url=/ru"))
    }

    @Test func renderTakesALocale() async throws {
        let config = StaticSiteConfig(outDir: outDir(), mode: .staticOnly)
        let page = try await StaticSite.render(PrefixSite.self, path: "/about", config: config,
                                               locale: LocaleID("ru")!)
        #expect(page.html.contains("Главная"))
    }
}
