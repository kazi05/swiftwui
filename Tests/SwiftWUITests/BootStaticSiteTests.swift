import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

/// Localized on purpose, and shared by both apps below: rendered without a
/// catalog it falls back to "en", which is what the monolingual cases assert.
private let bootLoading = LocalizedText(key: "boot.loading") { locale in
    switch locale.language {
    case "en": return "Loading"
    case "ru": return "Загрузка"
    default: return nil
    }
}

private struct Spin: Tag { var body: some Tag { Div(class: "spin") { Text(bootLoading) } } }
private struct Home: Page { var title: String { "H" }; var body: some Tag { Div { Text("home") } } }
private struct Quiet: Page {
    var title: String { "Q" }
    var bootUI: BootUI { .none }
    var body: some Tag { Div { Text("quiet") } }
}
private struct SiteApp: App {
    init() {}
    static var bootUI: BootUI { .overlay(after: .ms(250)) { Spin() } }
    var body: some Tag {
        Router {
            Route("/") { Home() }
            Route("/quiet") { Quiet() }
        }
    }
}

@Suite @MainActor struct BootStaticSiteTests {
    private var config: StaticSiteConfig {
        .init(outDir: "/tmp/unused", mode: .hydrate(wasmScriptPath: "/app/index.js"))
    }

    @Test func appLevelOverlayReachesTheDocument() async throws {
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: config)
        #expect(page.html.contains("<template data-swui-boot-ui>"))
        #expect(page.html.contains("class=\"spin\""))
        #expect(page.html.contains("data-delay=\"250\""))
    }

    @Test func pageLevelNoneSuppressesIt() async throws {
        let page = try await StaticSite.render(SiteApp.self, path: "/quiet", config: config)
        // `serialize` returns html: "" for every non-.page outcome, which would
        // make the negation below a vacuous pass.
        #expect(page.html.contains("quiet"))
        #expect(!page.html.contains("data-swui-boot-ui"))
    }

    @Test func missingWasmDegradesWithoutFailing() async throws {
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: config)
        // No dist/app/*.wasm exists for /tmp/unused, so no version and no size.
        #expect(!page.html.contains("?v="))
        #expect(!page.html.contains("data-size="))
        #expect(page.html.contains("data-swui-boot-config"))
    }

    /// An injected stamp names the wasm the build actually produced — and is the
    /// only path that ever ships `?v=`/`data-size`, since the disk read is the
    /// fallback for a bare `swift run App ssg`.
    @Test func injectedStampNamesTheWasmAndItsSize() async throws {
        var cfg = config
        cfg.bootStamp = BootStamp(sizeBytes: 9570733, version: "a3f9c1e2", fileName: "App.wasm")
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: cfg)
        #expect(page.html.contains("data-wasm=\"/app/App.wasm?v=a3f9c1e2\""))
        #expect(page.html.contains("data-size=\"9570733\""))
    }

    /// The shim ships next to the entry script, so a project serving its bundle
    /// from anywhere but `/app/` must not get a hardcoded `/app/swiftwui-boot.js`
    /// — that is a 404 on the shim and a page that never boots behind the veil.
    @Test func shimAndWasmFollowTheEntryScriptOutOfApp() async throws {
        var cfg = StaticSiteConfig(outDir: "/tmp/unused",
                                   mode: .hydrate(wasmScriptPath: "/static/bundle/index.js"))
        cfg.bootStamp = BootStamp(sizeBytes: 12, version: "deadbeef", fileName: "App.wasm")
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: cfg)
        #expect(page.html.contains("src=\"/static/bundle/swiftwui-boot.js\""))
        #expect(page.html.contains("<link rel=\"modulepreload\" href=\"/static/bundle/swiftwui-boot.js\">"))
        #expect(page.html.contains("data-wasm=\"/static/bundle/App.wasm?v=deadbeef\""))
        #expect(!page.html.contains("/app/"))
    }

    /// `.staticOnly` ships no wasm at all, so a boot UI it would never use must
    /// not reach the document.
    @Test func staticOnlyModeShipsNoBootUI() async throws {
        let page = try await StaticSite.render(SiteApp.self, path: "/",
                                               config: .init(outDir: "/tmp/unused", mode: .staticOnly))
        #expect(page.outcome == .page)
        #expect(!page.html.contains("data-swui-boot"))
    }
}

// MARK: - Localization

private struct L10nHome: Page {
    var title: String { "H" }
    var body: some Tag { Div { Text("home") } }
}
private struct LocalizedBootApp: App {
    init() {}
    static var bootUI: BootUI { .overlay { Spin() } }
    static var localization: Localization? {
        Localization(supported: [LocaleID("en")!, LocaleID("ru")!], default: LocaleID("en")!,
                     strategy: .pathPrefix())
    }
    var body: some Tag { Router { Route("/") { L10nHome() } } }
}

@Suite @MainActor struct BootStaticSiteLocalizationTests {
    /// The test the whole `_renderBootShell` design exists for: a shell rendered
    /// through a throwaway context falls back to "en" and would ship English
    /// into every `/ru/` document.
    @Test func overlayTextIsLocalizedPerDocument() async throws {
        let cfg = StaticSiteConfig(outDir: "/tmp/unused",
                                   mode: .hydrate(wasmScriptPath: "/app/index.js"),
                                   siteURL: "https://example.com")
        let ru = try await StaticSite.render(LocalizedBootApp.self, path: "/",
                                             config: cfg, locale: LocaleID("ru")!)
        #expect(ru.html.contains("Загрузка"))
        #expect(!ru.html.contains(">Loading<"))
        let en = try await StaticSite.render(LocalizedBootApp.self, path: "/", config: cfg)
        #expect(en.html.contains("Loading"))
    }
}
