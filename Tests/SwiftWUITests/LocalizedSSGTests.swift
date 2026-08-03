import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic
@testable import SwiftWUIToolchain

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

/// A guard cannot be handed the locale — its closure takes no arguments — so it
/// captures the value the surrounding `body` read, which is the render's own.
private struct PartialClusterSite: App {
    init() {}
    var body: some Tag { GuardedBody() }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix())
    }
}

private struct GuardedBody: Tag {
    @Environment(\.locale) var locale
    var body: some Tag {
        Router {
            Route("/") { _ in Text(title) }
            Route("/ru-only", guard: { [locale] in
                locale.language == "ru" ? .allow : .redirect("/")
            }) { _ in Text("только по-русски") }
        }
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

    /// The `.page` filter, end to end: English guard-redirects out of
    /// `/ru-only`, so the Russian page is the whole cluster and advertises no
    /// alternates. Delete the filter in `generate` and the redirect stub's URL
    /// is advertised as an English sibling — which is precisely the broken
    /// reciprocity that makes Google drop a cluster whole.
    @Test func aLocaleThatRedirectedOutIsNotAdvertised() async throws {
        let out = outDir()
        let report = try await StaticSite.generate(PartialClusterSite.self, config: StaticSiteConfig(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
        #expect(report.redirects["/ru-only"] == "/")
        let ru = try String(contentsOfFile: out + "/ru/ru-only/index.html", encoding: .utf8)
        #expect(ru.contains("только по-русски"))
        #expect(!ru.contains("hreflang"))
        // Not vacuous: the page whose cluster IS complete still gets its set.
        let ruHome = try String(contentsOfFile: out + "/ru/index.html", encoding: .utf8)
        #expect(ruHome.contains(#"<link href="https://example.com/" hreflang="en" rel="alternate""#))
    }

    @Test func renderTakesALocale() async throws {
        let config = StaticSiteConfig(outDir: outDir(), mode: .staticOnly)
        let page = try await StaticSite.render(PrefixSite.self, path: "/about", config: config,
                                               locale: LocaleID("ru")!)
        #expect(page.html.contains("Главная"))
    }
}

private struct SlugSite: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { _ in Text("home") }
            Route("/about") { _ in Text("about") }
        }
    }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix(),
                     routePaths: LocalizedRoutes { LocalizedRoute("/about", ["ru": "/o-nas"]) })
    }
}

/// With a slug table, hreflang is the ONLY thing tying `/about` to `/o-nas` —
/// they share no substring — so every one of these is load-bearing.
@Suite @MainActor struct LocalizedSlugSSGTests {
    private func build(mode: StaticSiteMode = .staticOnly) async throws
        -> (dir: String, report: StaticSiteReport) {
        let out = NSTemporaryDirectory() + "swiftwui-slug-\(UUID().uuidString)"
        let report = try await StaticSite.generate(SlugSite.self, config: .init(
            outDir: out, mode: mode, siteURL: "https://example.com"))
        return (out, report)
    }

    @Test func slugPageIsWrittenFlatAndPrefixPageIsNot() async throws {
        let (dir, report) = try await build()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(FileManager.default.fileExists(atPath: dir + "/o-nas/index.html"))
        #expect(FileManager.default.fileExists(atPath: dir + "/about/index.html"))
        // The prefix form no longer holds the PAGE — it holds the migration
        // stub that retires it (`MigrationStubTests`), which is a redirect and
        // not a page: it stays out of `report.pages` below.
        let retired = try String(contentsOfFile: dir + "/ru/about/index.html", encoding: .utf8)
        #expect(retired.contains(#"http-equiv="refresh""#) && !retired.contains("about"))
        // The report and the sitemap name the slug, not the prefix form.
        #expect(report.pages.contains("/o-nas"))
        #expect(!report.pages.contains("/ru/about"))
        // The untabled path still gets its prefix.
        #expect(report.writtenFiles.contains("ru/index.html"))
    }

    @Test func alternatesPointAtTheSlugAndAreReciprocal() async throws {
        let (dir, _) = try await build()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let en = try String(contentsOfFile: dir + "/about/index.html", encoding: .utf8)
        let ru = try String(contentsOfFile: dir + "/o-nas/index.html", encoding: .utf8)
        // Attributes are emitted in sorted order, so href precedes hreflang.
        #expect(en.contains(#"<link href="https://example.com/o-nas" hreflang="ru" rel="alternate""#))
        #expect(ru.contains(#"<link href="https://example.com/about" hreflang="en" rel="alternate""#))
        #expect(en.contains(#"<link href="https://example.com/about" hreflang="en" rel="alternate""#))
        #expect(ru.contains(#"<link href="https://example.com/about" hreflang="x-default" rel="alternate""#))
    }

    @Test func canonicalIsSelfReferencing() async throws {
        let (dir, _) = try await build()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let ru = try String(contentsOfFile: dir + "/o-nas/index.html", encoding: .utf8)
        #expect(ru.contains(#"<link href="https://example.com/o-nas" rel="canonical""#))
    }

    /// The build's URL and the runtime's must be the same string: the boot
    /// compares the snapshot path to `location.pathname` byte-for-byte, and
    /// `mount()` `replaceState`s to the slug. A prefix-form snapshot here would
    /// be discarded on every visit and every loader re-run.
    @Test func snapshotPathIsTheSlug() async throws {
        let (dir, _) = try await build(mode: .hydrate(wasmScriptPath: "/app.js"))
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let ru = try String(contentsOfFile: dir + "/o-nas/index.html", encoding: .utf8)
        #expect(ru.contains(#""path":"\/o-nas""#))
    }
}

private struct SluggedHomeSite: App {
    init() {}
    var body: some Tag { Router { Route("/") { _ in Text("home") } } }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix(),
                     routePaths: LocalizedRoutes { LocalizedRoute("/", ["ru": "/glavnaya"]) })
    }
}

/// Two locales, one file. `ru`'s slug for `/x` is spelled `/de/about` — a URL
/// that under prefixes belonged to `de` and to nothing else. Every table
/// validation passes: the slug is no Route, overlaps no other pattern and
/// enumerates nothing. What it does instead is claim `de`'s boot path, so the
/// `de` request for `/about` internalizes through it, settles in `ru`, and both
/// locales' `/about` end up writing `ru/about/index.html`. The prefix namespace
/// that made this impossible is the very thing a slug removes.
private struct CollidingSlugSite: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/about") { _ in Text("about") }
            Route("/x") { _ in Text("x") }
        }
    }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!, LocaleID("de")!],
                     default: LocaleID("en")!, strategy: .pathPrefix(),
                     routePaths: LocalizedRoutes { LocalizedRoute("/x", ["ru": "/de/about"]) })
    }
}

/// `/ru/about` is a real page here — a Route of that exact name, kept reachable
/// by the table's own second entry (`internalize` step 2). The stub for the
/// FIRST entry would land on it, so the `report.pages` guard is what stops the
/// migration aid from eating the page it was meant to help.
private struct RetiredPathIsARealPageSite: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/about") { _ in Text("about") }
            Route("/ru/about") { _ in Text("about the ru site") }
        }
    }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix(),
                     routePaths: LocalizedRoutes {
                         LocalizedRoute("/about", ["ru": "/o-nas"])
                         LocalizedRoute("/ru/about", ["ru": "/pro-ru"])
                     })
    }
}

/// No table anywhere: a build task moves the page's own locale, so BOTH locales
/// render `/about` into `ru/about/index.html` and the English URL is never
/// written at all. A guard redirect is how this site says "Russian only"
/// (`PartialClusterSite` above); `setLocale` mid-build just loses a page.
private struct SetLocaleDuringBuildSite: App {
    init() {}
    var body: some Tag { ForcedLocaleBody() }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix())
    }
}

private struct ForcedLocaleBody: Tag {
    @Environment(\.setLocale) var setLocale
    var body: some Tag {
        Router {
            Route("/about") { [setLocale] _ in
                Div { Text("about") }.staticTask { setLocale(LocaleID("ru")!) }
            }
        }
    }
}

@Suite @MainActor struct MigrationStubTests {
    @Test func retiredPrefixPathGetsAStub() async throws {
        let out = NSTemporaryDirectory() + "swiftwui-stub-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(SlugSite.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
        let stub = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)
        #expect(stub.contains("url=/o-nas"))
        #expect(report.redirects["/ru/about"] == "/o-nas")
        // A redirect is not a page: neither the report nor the sitemap may
        // advertise a URL whose only content is a meta-refresh.
        #expect(!report.pages.contains("/ru/about"))
        let sitemap = try String(contentsOfFile: out + "/sitemap.xml", encoding: .utf8)
        #expect(!sitemap.contains("/ru/about"))
    }

    @Test func bareLocaleRootGetsAStubWhenTheHomeIsSlugged() async throws {
        let out = NSTemporaryDirectory() + "swiftwui-stub-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        _ = try await StaticSite.generate(SluggedHomeSite.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
        let stub = try String(contentsOfFile: out + "/ru/index.html", encoding: .utf8)
        #expect(stub.contains("url=/glavnaya"))
    }

    @Test func twoPagesClaimingOneOutputFileFailTheBuild() async {
        let out = NSTemporaryDirectory() + "swiftwui-stub-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        do {
            _ = try await StaticSite.generate(CollidingSlugSite.self, config: .init(
                outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
            Issue.record("expected StaticSiteError, build succeeded")
        } catch let error as StaticSiteError {
            // Named by the build INPUTS — the page and the locale that was
            // asked for. Naming only the file would leave the author with a
            // path no line of their site declares.
            #expect(error.description.contains("ru/about/index.html"))
            #expect(error.description.contains("'/about' in de"))
            #expect(error.description.contains("'/about' in ru"))
        } catch {
            Issue.record("expected StaticSiteError, got \(error)")
        }
    }

    /// A table-free app must not gain a new way to fail — but two documents
    /// writing one file is a lost page whatever caused it, so this one fails
    /// with its OWN error rather than being told its (absent) table is invalid.
    @Test func aBuildTaskThatMovesItsLocaleCollidesWithTheRealPage() async {
        let out = NSTemporaryDirectory() + "swiftwui-stub-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        do {
            _ = try await StaticSite.generate(SetLocaleDuringBuildSite.self, config: .init(
                outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
            Issue.record("expected StaticSiteError, build succeeded")
        } catch let error as StaticSiteError {
            #expect(error.description.contains("ru/about/index.html"))
            #expect(error.description.contains("setLocale"))
            #expect(!error.description.contains("invalid routePaths"))
        } catch {
            Issue.record("expected StaticSiteError, got \(error)")
        }
    }

    /// The `report.pages` guard: the retired URL is a page in its own right,
    /// so it keeps its content and gains no redirect.
    @Test func aRetiredPathThatIsARealPageKeepsIt() async throws {
        let out = NSTemporaryDirectory() + "swiftwui-stub-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(RetiredPathIsARealPageSite.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com"))
        let page = try String(contentsOfFile: out + "/ru/about/index.html", encoding: .utf8)
        #expect(page.contains("about the ru site"))
        #expect(!page.contains("http-equiv=\"refresh\""))
        #expect(report.redirects["/ru/about"] == nil)
        // Not vacuous: the entry whose retired URL is free still gets its stub.
        #expect(report.redirects["/ru/ru/about"] == "/pro-ru")
    }

    /// The kill-switch renders nothing, so it must not write redirects to pages
    /// this build never produced either.
    @Test func theKillSwitchEmitsNoStubs() async throws {
        let out = NSTemporaryDirectory() + "swiftwui-stub-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(SlugSite.self, config: .init(
            outDir: out, mode: .staticOnly, siteURL: "https://example.com",
            prerenderEnabled: false))
        #expect(report.redirects.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: out + "/ru/about/index.html"))
    }

    /// The deliberate collapse the check must not touch: two query variants are
    /// ONE page and have always written one file (StaticSite.outputFile strips
    /// the query). A check keyed on the output file alone would reject this.
    @Test func queryVariantsStillCollapseIntoOneFile() async throws {
        struct TodoApp: App {
            init() {}
            var body: some Tag {
                Router { Route("/todo/:id") { p in Text("todo " + (p["id"] ?? "")) } }
            }
        }
        let out = NSTemporaryDirectory() + "swiftwui-stub-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: out) }
        let report = try await StaticSite.generate(TodoApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1?tab=all", "/todo/1?tab=done"]))
        #expect(report.writtenFiles == ["todo/1/index.html", "todo/1/index.html"])
    }
}

private func l10n(_ strategy: LocaleStrategy = .pathPrefix(),
                  @LocalizedRoutesBuilder _ table: () -> [LocalizedRoutes.Entry]) -> Localization {
    Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                 strategy: strategy, routePaths: LocalizedRoutes(table))
}

/// The canonical is misspelled, so no `Route` ever claims the entry (V8).
private struct OrphanEntrySite: App {
    init() {}
    var body: some Tag { Router { Route("/about") { _ in Text("about") } } }
    static var localization: Localization? {
        l10n { LocalizedRoute("/abuot", ["ru": "/o-nas"]) }
    }
}

/// The slug is spelled as a real `Route`, which `internalize` then rewrites
/// away before routing sees it (V7).
private struct ShadowingSlugSite: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/blog") { _ in Text("blog") }
            Route("/novosti") { _ in Text("news") }
        }
    }
    static var localization: Localization? {
        l10n { LocalizedRoute("/blog", ["ru": "/novosti"]) }
    }
}

/// A table under a strategy that never reads it (V1, from the table-only pass).
private struct NegotiatedWithTableSite: App {
    init() {}
    var body: some Tag { Router { Route("/about") { _ in Text("about") } } }
    static var localization: Localization? {
        l10n(.negotiated) { LocalizedRoute("/about", ["ru": "/o-nas"]) }
    }
}

/// The slug's first segment is a top-level dist/ directory (V14).
private struct ReservedSlugSite: App {
    init() {}
    var body: some Tag { Router { Route("/about") { _ in Text("about") } } }
    static var localization: Localization? {
        l10n { LocalizedRoute("/about", ["ru": "/vendor"]) }
    }
}

/// `config.paths` names the ru slug instead of the canonical path, and the
/// parametric route happily claims it. `internalize` then reports locale `ru`
/// for it whatever locale the build asked for.
private struct EnumeratedSlugSite: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/about") { _ in Text("about") }
            Route("/:page") { p in Text(p["page"] ?? "") }
        }
    }
    static var localization: Localization? {
        l10n { LocalizedRoute("/about", ["ru": "/o-nas"]) }
    }
}

/// No literal `/about` route — the entry names one concrete path of `/:page`.
private struct ParametricRouteSite: App {
    init() {}
    var body: some Tag { Router { Route("/:page") { p in Text(p["page"] ?? "") } } }
    static var localization: Localization? {
        l10n { LocalizedRoute("/about", ["ru": "/o-nas"]) }
    }
}

@Suite @MainActor struct LocalizedRoutesBuildValidationTests {
    private func out() -> String { NSTemporaryDirectory() + "swiftwui-v-\(UUID().uuidString)" }

    /// Asserts the build fails AND that the diagnostic names the offender —
    /// a validation whose message does not say which entry is wrong sends the
    /// author hunting through the whole table.
    private func expectRejection<A: App>(_ app: A.Type, containing needle: String,
                                         paths: [String] = [],
                                         siteURL: String? = "https://example.com") async {
        let dir = out()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        do {
            _ = try await StaticSite.generate(app, config: .init(
                outDir: dir, mode: .staticOnly, paths: paths, siteURL: siteURL))
            Issue.record("expected StaticSiteError, build succeeded")
        } catch let error as StaticSiteError {
            #expect(error.description.contains(needle))
        } catch {
            Issue.record("expected StaticSiteError, got \(error)")
        }
    }

    @Test func orphanEntryIsRejected() async {
        await expectRejection(OrphanEntrySite.self, containing: "/abuot")
    }

    /// Asserts V7's own wording, not just `/novosti`: `Route("/novosti")` is
    /// static and auto-enumerated, so the enumerated-path check reports that
    /// same string and a green test would survive deleting V7's route half.
    @Test func slugShadowingARealRouteIsRejected() async {
        await expectRejection(ShadowingSlugSite.self,
                              containing: "declares slug '/novosti' for 'ru', which is also a real Route pattern")
    }

    /// V8 matches, it does not compare strings: an entry naming one concrete
    /// path of a parametric route is a working configuration (spec §4).
    @Test func aTableOverAParametricRouteValidatesClean() async throws {
        let dir = out()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let report = try await StaticSite.generate(ParametricRouteSite.self, config: .init(
            outDir: dir, mode: .staticOnly, paths: ["/about"], siteURL: "https://example.com"))
        #expect(report.pages.sorted() == ["/about", "/o-nas"])
    }

    @Test func tableUnderNegotiatedIsRejected() async {
        await expectRejection(NegotiatedWithTableSite.self, containing: ".pathPrefix")
    }

    @Test func slugOnAReservedDistNameIsRejected() async {
        await expectRejection(ReservedSlugSite.self, containing: "reserved dist name")
    }

    /// V13. Without an origin a slug site emits neither canonical nor hreflang,
    /// and `/about` ↔ `/o-nas` share no substring for a crawler to pair up.
    @Test func aTableWithoutASiteURLIsRejected() async {
        await expectRejection(SlugSite.self, containing: "siteURL", siteURL: nil)
        await expectRejection(SlugSite.self, containing: "siteURL", siteURL: "")
    }

    /// Enumerating the slug itself is last-write-wins on the locale key: both
    /// renders of `/o-nas` report locale `ru`, so the cluster collapses to one
    /// entry and hreflang vanishes from every page of it.
    @Test func enumeratingALocalizedSlugIsRejected() async {
        await expectRejection(EnumeratedSlugSite.self, containing: "/o-nas",
                              paths: ["/o-nas"])
    }

    /// `render` is a separate public entry point (`ssg --path`, any render
    /// server) and never goes through `generate`.
    @Test func renderRunsTheTableOnlyValidations() async {
        let dir = out()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        await #expect(throws: StaticSiteError.self) {
            _ = try await StaticSite.render(NegotiatedWithTableSite.self, path: "/about",
                                            config: .init(outDir: dir, mode: .staticOnly))
        }
    }

    /// The kill-switch is unconditional and outranks the gate: it is the
    /// documented operational escape hatch, and a bad table must not be able to
    /// block the one flag that turns prerendering off.
    @Test func theKillSwitchOutranksValidation() async throws {
        let dir = out()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let page = try await StaticSite.render(NegotiatedWithTableSite.self, path: "/about",
                                               config: .init(outDir: dir, mode: .staticOnly,
                                                             prerenderEnabled: false))
        #expect(page.outcome == .error("prerendering disabled (kill-switch)"))
    }

    /// …and only the table-only half: with no probe there is no route set, so
    /// the orphan `render` cannot see is not a reason to refuse the page.
    @Test func renderDoesNotRunTheRouteSetValidations() async throws {
        let dir = out()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let page = try await StaticSite.render(OrphanEntrySite.self, path: "/about",
                                               config: .init(outDir: dir, mode: .staticOnly))
        #expect(page.outcome == .page)
    }

    /// The whole feature is opt-in: a localized app that declares no table must
    /// not gain a single new way to fail, V13 above all — every project that
    /// predates this ships without a `siteURL`.
    @Test func aTableFreeAppIsUntouchedWithoutASiteURL() async throws {
        let dir = out()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let report = try await StaticSite.generate(PrefixSite.self, config: .init(
            outDir: dir, mode: .staticOnly))
        #expect(!report.pages.isEmpty)
    }
}

/// `StaticSite.reservedDistNames` is a hand-copy of `DistLayout.reservedNames`
/// — SwiftWUIStatic cannot import the toolchain. This is the only thing
/// stopping the two from drifting.
@Suite struct ReservedNameDriftTests {
    @Test func staticMirrorsToolchain() {
        #expect(StaticSite.reservedDistNames == DistLayout.reservedNames)
    }
}

/// Declares no localization at all — the shape every project that predates
/// this feature has, and the one `resolve` must leave alone.
private struct MonolingualSite: App {
    init() {}
    var body: some Tag { SiteBody() }
}

@Suite @MainActor struct ResolveTests {
    @Test func slugResolvesToCanonicalPathAndLocale() {
        let r = StaticSite.resolve(SlugSite.self, requestPath: "/o-nas")
        #expect(r.path == "/about")
        #expect(r.locale == LocaleID("ru")!)
    }

    @Test func prefixResolvesToo() {
        let r = StaticSite.resolve(SlugSite.self, requestPath: "/ru/contact")
        #expect(r.path == "/contact")
        #expect(r.locale == LocaleID("ru")!)
    }

    @Test func canonicalPathResolvesToItselfWithNoLocale() {
        let r = StaticSite.resolve(SlugSite.self, requestPath: "/about")
        #expect(r.path == "/about")
        #expect(r.locale == nil)
    }

    @Test func monolingualAppIsIdentity() {
        let r = StaticSite.resolve(MonolingualSite.self, requestPath: "/ghost")
        #expect(r.path == "/ghost")
        #expect(r.locale == nil)
    }

    @Test func queryIsStrippedFromTheResolvedPath() {
        let r = StaticSite.resolve(SlugSite.self, requestPath: "/o-nas?tab=2")
        #expect(r.path == "/about")
    }

    /// A fragment never reaches a server, but an operator pasting a URL into
    /// `ssg --path` hands one straight through. `render` would take "/o-nas#top"
    /// as a route to match and find nothing.
    @Test func fragmentIsStrippedToo() {
        let r = StaticSite.resolve(SlugSite.self, requestPath: "/o-nas#top")
        #expect(r.path == "/about")
        #expect(r.locale == LocaleID("ru")!)
    }
}
