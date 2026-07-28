import Testing
@testable import SwiftWUI

@Suite struct LocalizedTextTests {
    private let text = LocalizedText(key: "greeting") { locale in
        switch locale.identifier {
        case "en": return "Hello"
        case "ru": return "Привет"
        default: break
        }
        switch locale.language {
        case "en": return "Hello"
        case "ru": return "Привет"
        default: return nil
        }
    }

    @Test func exactTagWins() {
        #expect(text.resolved(for: LocaleID("ru")!) == "Привет")
    }

    @Test func regionalVariantFallsToLanguage() {
        #expect(text.resolved(for: LocaleID("en-GB")!) == "Hello")
    }

    @Test func unknownLocaleUsesFallbackThenKey() {
        #expect(text.resolved(for: LocaleID("de")!, fallback: LocaleID("en")!) == "Hello")
        #expect(text.resolved(for: LocaleID("de")!) == "greeting")
        #expect(text.resolved(for: LocaleID("de")!, fallback: LocaleID("fr")!) == "greeting")
    }

    @Test func verbatimIgnoresLocale() {
        #expect(LocalizedText.verbatim("42").resolved(for: LocaleID("ru")!) == "42")
    }

    @Test func localizationValidatesAgainstSupported() {
        let l = Localization(supported: [LocaleID("en")!, LocaleID("ru")!],
                             default: LocaleID("en")!)
        #expect(l.validated("ru") == LocaleID("ru")!)
        #expect(l.validated("de") == nil)
        #expect(l.validated("../ru") == nil)
        #expect(l.validated(nil) == nil)
        #expect(l.validated("ru-RU") == LocaleID("ru")!)   // regional request maps to a supported language
    }

    @Test func strategyFlags() {
        #expect(LocaleStrategy.pathPrefix().usesURLPrefix)
        #expect(!LocaleStrategy.negotiated.usesURLPrefix)
        #expect(LocaleStrategy.negotiated.isPerLocaleOutput)
        #expect(!LocaleStrategy.client.isPerLocaleOutput)
    }
}
