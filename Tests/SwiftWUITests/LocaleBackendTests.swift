import Testing
@testable import SwiftWUI

@Suite @MainActor struct LocaleBackendTests {
    @Test func mockRecordsLanguageAndCookies() {
        let backend = MockBackend()
        backend.setDocumentLanguage("ru", dir: "rtl")
        #expect(backend.documentLanguage?.lang == "ru")
        #expect(backend.documentLanguage?.dir == "rtl")

        backend.writeCookie("swiftwui_locale", value: "ru", maxAgeDays: 365, secure: false)
        #expect(backend.readCookie("swiftwui_locale") == "ru")
        #expect(backend.readCookie("nope") == nil)
    }

    @Test func mockPreferredLanguagesAreScriptable() {
        let backend = MockBackend()
        #expect(backend.preferredLanguages().isEmpty)
        backend.preferred = ["ru-RU", "en"]
        #expect(backend.preferredLanguages() == ["ru-RU", "en"])
    }

    @Test func adoptingBackendForwardsLocaleSurface() {
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        base.preferred = ["de"]
        adopting.setDocumentLanguage("de", dir: nil)
        adopting.writeCookie("swiftwui_locale", value: "de", maxAgeDays: 1, secure: true)
        #expect(base.documentLanguage?.lang == "de")
        #expect(base.cookies["swiftwui_locale"] == "de")
        #expect(adopting.readCookie("swiftwui_locale") == "de")
        #expect(adopting.preferredLanguages() == ["de"])
    }
}
