import Foundation
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
private struct Loud: Page {
    var title: String { "L" }
    var bootUI: BootUI { .overlay(after: .ms(120)) { Spin() } }
    var body: some Tag { Div { Text("loud") } }
}
/// `App.bootUI` left at its `.none` default while one page opts in — the shape
/// the app-level `boot-shell` answer cannot see, so only the per-document
/// resolution in `renderTree` can produce it.
private struct QuietApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { Home() }
            Route("/loud") { Loud() }
        }
    }
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
    /// A directory that does not exist, unique per call: `BootStamp.read` scans
    /// `<outDir>/app` off the real filesystem, so a fixed path under /tmp makes
    /// "no wasm here" a property of the machine rather than of the test.
    private var config: StaticSiteConfig {
        .init(outDir: NSTemporaryDirectory() + "swiftwui-nowasm-" + UUID().uuidString,
              mode: .hydrate(wasmScriptPath: "/app/index.js"))
    }
    /// No wasm exists under that directory, so anything asserting on the boot
    /// CONFIG (rather than the shell) has to inject a stamp — without one the
    /// config is deliberately not emitted at all.
    private var stampedConfig: StaticSiteConfig {
        var cfg = config
        cfg.bootStamp = BootStamp(sizeBytes: 9570733, version: "a3f9c1e2", fileName: "App.wasm")
        return cfg
    }

    @Test func appLevelOverlayReachesTheDocument() async throws {
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: stampedConfig)
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

    /// No `dist/app/*.wasm` exists under that outDir. A guessed wasm name would
    /// 404 inside the shim, which fails closed and shows the failure UI — a dead
    /// page. So no config at all is emitted, the legacy inline boot takes over,
    /// and the build still succeeds.
    @Test func missingWasmFallsBackToTheLegacyBoot() async throws {
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: config)
        #expect(page.outcome == .page)
        #expect(!page.html.contains("data-swui-boot-config"))
        #expect(!page.html.contains("?v="))
        #expect(!page.html.contains("data-size="))
        #expect(page.html.contains("import { init }"))
    }

    /// An injected stamp names the wasm the build actually produced — and is the
    /// only path that ever ships `?v=`/`data-size`, since the disk read is the
    /// fallback for a bare `swift run App ssg`.
    @Test func injectedStampNamesTheWasmAndItsSize() async throws {
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: stampedConfig)
        #expect(page.html.contains("data-wasm=\"/app/App.wasm?v=a3f9c1e2\""))
        #expect(page.html.contains("data-size=\"9570733\""))
    }

    /// The shim ships next to the entry script, so a project serving its bundle
    /// from anywhere but `/app/` must not get a hardcoded `/app/swiftwui-boot.js`
    /// — that is a 404 on the shim and a page that never boots behind the veil.
    ///
    /// Both entry names are exercised because the derivation must key on the
    /// entry's DIRECTORY: matching the filename `index.js` sends every renamed
    /// entry back to `/app/`, reintroducing the same 404 through another input.
    @Test(arguments: ["/static/bundle/index.js", "/static/bundle/main.js"])
    func shimAndWasmFollowTheEntryScriptOutOfApp(entry: String) async throws {
        var cfg = StaticSiteConfig(outDir: "/tmp/unused", mode: .hydrate(wasmScriptPath: entry))
        cfg.bootStamp = BootStamp(sizeBytes: 12, version: "deadbeef", fileName: "App.wasm")
        let page = try await StaticSite.render(SiteApp.self, path: "/", config: cfg)
        #expect(page.html.contains("src=\"/static/bundle/swiftwui-boot.js\""))
        #expect(page.html.contains("<link rel=\"modulepreload\" href=\"/static/bundle/swiftwui-boot.js\">"))
        #expect(page.html.contains("data-wasm=\"/static/bundle/App.wasm?v=deadbeef\""))
        #expect(page.html.contains("data-entry=\"\(entry)\""))
        #expect(!page.html.contains("/app/"))
    }

    /// The inverse of `pageLevelNoneSuppressesIt`, and the shape the SPA answer
    /// reports as "no boot UI": an app that declares none, one page that does.
    /// That page must get the whole apparatus — shell, stylesheet and shim.
    @Test func aPageOverlayStandsOnItsOwnWithoutAnAppLevelOne() async throws {
        let page = try await StaticSite.render(QuietApp.self, path: "/loud", config: stampedConfig)
        #expect(page.html.contains("<template data-swui-boot-ui>"))
        #expect(page.html.contains("class=\"spin\""))
        #expect(page.html.contains("<style data-swui-boot>"))
        #expect(page.html.contains("data-swui-boot-config"))
        #expect(page.html.contains("data-delay=\"120\""), "the PAGE's delay, not the app's default")
    }

    /// …and it stays that page's, so the opt-in does not leak site-wide.
    @Test func theRestOfThatAppStaysCold() async throws {
        let page = try await StaticSite.render(QuietApp.self, path: "/", config: stampedConfig)
        #expect(page.html.contains("home"))
        #expect(!page.html.contains("data-swui-boot"))
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
