import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIToolchain

@Suite struct LocaleNegotiationTests {
    private let site = LocaleNegotiation.Site(strategy: "negotiated",
                                              locales: ["en", "ru", "de"],
                                              defaultLocale: "en")

    @Test func parsesQualityOrder() {
        #expect(LocaleNegotiation.parseAcceptLanguage("de;q=0.5,ru;q=0.9,en;q=0.1") == ["ru", "de", "en"])
        #expect(LocaleNegotiation.parseAcceptLanguage("ru-RU,ru;q=0.9,en;q=0.8") == ["ru-RU", "ru", "en"])
        #expect(LocaleNegotiation.parseAcceptLanguage("").isEmpty)
        #expect(LocaleNegotiation.parseAcceptLanguage("*") == [])
    }

    @Test func cookieBeatsHeader() {
        #expect(LocaleNegotiation.pick(cookie: "swiftwui_locale=de", acceptLanguage: "ru", site: site) == "de")
        #expect(LocaleNegotiation.pick(cookie: "other=1; swiftwui_locale=ru", acceptLanguage: "de", site: site) == "ru")
    }

    @Test func headerFallsBackToPrimarySubtagThenDefault() {
        #expect(LocaleNegotiation.pick(cookie: nil, acceptLanguage: "ru-RU,en;q=0.8", site: site) == "ru")
        #expect(LocaleNegotiation.pick(cookie: nil, acceptLanguage: "fr,it;q=0.8", site: site) == "en")
        #expect(LocaleNegotiation.pick(cookie: nil, acceptLanguage: nil, site: site) == "en")
    }

    @Test func hostileValuesAreRejected() {
        #expect(LocaleNegotiation.pick(cookie: "swiftwui_locale=../etc", acceptLanguage: nil, site: site) == "en")
        #expect(LocaleNegotiation.pick(cookie: nil, acceptLanguage: "../ru", site: site) == "en")
    }

    @Test func matchesCoreResolution() {
        // Drift guard: the toolchain matcher (used by the local server) and the
        // core matcher (used in the browser) must agree — Package.swift keeps
        // SwiftWUIToolchain free of a SwiftWUI dependency, so this is the seam.
        let localization = Localization(supported: [LocaleID("en")!, LocaleID("ru")!, LocaleID("de")!],
                                        default: LocaleID("en")!, strategy: .client)
        for preferred in [["ru-RU", "en"], ["fr"], ["de-AT", "ru"], []] {
            let core = LocaleResolution.initial(.init(preferred: preferred), localization: localization)
            let header = preferred.isEmpty ? nil : preferred.joined(separator: ",")
            let tool = LocaleNegotiation.pick(cookie: nil, acceptLanguage: header, site: site)
            #expect(core.identifier == tool, "mismatch for \(preferred)")
        }
    }

    @Test func serverServesTheNegotiatedFolder() throws {
        let root = NSTemporaryDirectory() + "swiftwui-serve-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: root) }
        for (locale, body) in ["en": "Home", "ru": "Главная"] {
            let dir = root + "/\(locale)/about"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try "<html>\(body)</html>".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
            try "<html>\(body)-root</html>".write(toFile: root + "/\(locale)/index.html",
                                                  atomically: true, encoding: .utf8)
        }
        try "wasm".write(toFile: root + "/main.wasm", atomically: true, encoding: .utf8)
        let handler = StaticFiles.handler(urlPrefix: "/", root: root, localeSite: site)

        let ru = handler(HTTPRequest(method: "GET", path: "/about",
                                     headers: ["accept-language": "ru"]))
        #expect(String(decoding: ru!.body, as: UTF8.self).contains("Главная"))
        #expect(ru?.headers["Vary"] == "Accept-Language, Cookie")

        let en = handler(HTTPRequest(method: "GET", path: "/about", headers: [:]))
        #expect(String(decoding: en!.body, as: UTF8.self).contains("Home"))

        // The cookie outranks the header here too — same rule as the edge.
        let cookie = handler(HTTPRequest(method: "GET", path: "/about",
                                         headers: ["accept-language": "ru", "cookie": "swiftwui_locale=en"]))
        #expect(String(decoding: cookie!.body, as: UTF8.self).contains("Home"))

        // Root-level assets are never locale-prefixed.
        let asset = handler(HTTPRequest(method: "GET", path: "/main.wasm",
                                        headers: ["accept-language": "ru"]))
        #expect(asset != nil)

        // A non-localized site keeps today's behaviour: no folder lookup, no Vary.
        let plain = StaticFiles.handler(urlPrefix: "/", root: root)
        #expect(plain(HTTPRequest(method: "GET", path: "/about", headers: ["accept-language": "ru"])) == nil)
    }

    /// The dev server and the generated nginx.conf must resolve the same four
    /// candidates in the same order. Verified against a live nginx run; these
    /// are the cases where a plausible implementation drifts — a build leaves a
    /// root SPA shell in dist, and the shell must never shadow the prerendered
    /// per-locale document at `/` or at an unknown route.
    @Test func devServerMatchesTheGeneratedTryFilesOrder() throws {
        let root = NSTemporaryDirectory() + "swiftwui-parity-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: root) }
        let fm = FileManager.default
        for locale in ["en", "ru"] {
            try fm.createDirectory(atPath: root + "/\(locale)/about", withIntermediateDirectories: true)
            try "\(locale)-home".write(toFile: root + "/\(locale)/index.html", atomically: true, encoding: .utf8)
            try "\(locale)-about".write(toFile: root + "/\(locale)/about/index.html", atomically: true, encoding: .utf8)
        }
        try "SPA-SHELL".write(toFile: root + "/index.html", atomically: true, encoding: .utf8)   // `swiftwui build` writes this
        try "WASM".write(toFile: root + "/main.wasm", atomically: true, encoding: .utf8)
        let handler = StaticFiles.handler(urlPrefix: "/", root: root, spaFallback: true, localeSite: site)
        func body(_ path: String) -> String {
            String(decoding: handler(HTTPRequest(method: "GET", path: path,
                                                 headers: ["accept-language": "ru"]))?.body ?? [], as: UTF8.self)
        }
        #expect(body("/") == "ru-home")            // NOT the root shell
        #expect(body("/about") == "ru-about")
        #expect(body("/nope") == "ru-home")        // SPA fallback, in the negotiated locale
        #expect(body("/main.wasm") == "WASM")      // root-level asset, never prefixed
    }

    @Test func nginxConfCarriesTheNegotiationBlock() throws {
        let dist = NSTemporaryDirectory() + "swiftwui-nginx-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try FileManager.default.createDirectory(atPath: dist, withIntermediateDirectories: true)
        try ReleaseArtifacts.writeNginxConf(distDir: dist, site: site)
        let conf = try String(contentsOfFile: dist + "/nginx.conf", encoding: .utf8)
        #expect(conf.contains("$swui_locale"))
        #expect(conf.contains("Vary"))
        #expect(conf.contains("try_files $uri /$swui_locale$uri/index.html"))
        // `map` is only legal in the http block — never inside `server { }`.
        #expect(conf.range(of: "map $http_cookie")!.upperBound < conf.range(of: "server {")!.lowerBound)
        // nginx map regexes are first-match: every "first tag in the header" rule
        // must precede every "somewhere after a comma" rule, or `ru,en;q=0.8`
        // negotiates en and the edge disagrees with `pick`.
        #expect(conf.range(of: #""~*^\s*de""#)!.upperBound < conf.range(of: #""~*,\s*en""#)!.lowerBound)

        try ReleaseArtifacts.writeNginxConf(distDir: dist, site: nil)
        let plain = try String(contentsOfFile: dist + "/nginx.conf", encoding: .utf8)
        #expect(!plain.contains("$swui_locale"))
        #expect(!plain.contains("map "))
    }

    /// A site that is not `.negotiated` must get byte-for-byte the config it got
    /// before this task — the file is deployed, a regression breaks live sites.
    /// The two anchors are the only new machinery, so both are pinned: nothing
    /// left over, and no blank line where the maps anchor stood.
    @Test func nonNegotiatedConfIsUnchanged() throws {
        let dist = NSTemporaryDirectory() + "swiftwui-nginx-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try FileManager.default.createDirectory(atPath: dist, withIntermediateDirectories: true)
        try ReleaseArtifacts.writeNginxConf(distDir: dist)
        let byDefault = try String(contentsOfFile: dist + "/nginx.conf", encoding: .utf8)
        for site in [nil, LocaleNegotiation.Site(strategy: "pathPrefix", locales: ["en", "ru"], defaultLocale: "en")] {
            try ReleaseArtifacts.writeNginxConf(distDir: dist, site: site)
            #expect(try String(contentsOfFile: dist + "/nginx.conf", encoding: .utf8) == byDefault)
        }
        #expect(!byDefault.contains("__SWIFTWUI"))
        #expect(byDefault.contains("include it from your nginx.conf http block).\nserver {"))
        #expect(byDefault.contains("""
            # SPA fallback; `swiftwui ssg` per-route prerenders are served via $uri/.
                location / { try_files $uri $uri/ /index.html; }
            }
            """))
    }

    @Test func readsTheDescriptorTask11Writes() throws {
        let dist = NSTemporaryDirectory() + "swiftwui-desc-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try FileManager.default.createDirectory(atPath: dist, withIntermediateDirectories: true)
        #expect(LocaleNegotiation.read(distDir: dist) == nil)          // no descriptor → not localized
        try #"{"localization":{"strategy":"negotiated","locales":["en","ru"],"default":"en"}}"#
            .write(toFile: dist + "/" + LocaleNegotiation.descriptorName, atomically: true, encoding: .utf8)
        let site = LocaleNegotiation.read(distDir: dist)
        #expect(site == LocaleNegotiation.Site(strategy: "negotiated", locales: ["en", "ru"], defaultLocale: "en"))
        #expect(site?.isNegotiated == true)
    }
}
