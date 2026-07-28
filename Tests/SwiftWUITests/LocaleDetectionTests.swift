import Testing
@testable import SwiftWUI

@MainActor private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

private struct Show: Tag {
    @Environment(\.locale) var locale
    var body: some Tag { Text(locale.identifier) }
}

@Suite @MainActor struct LocaleDetectionTests {
    private let supported = [LocaleID("en")!, LocaleID("ru")!, LocaleID("de")!]
    private func l10n(_ strategy: LocaleStrategy) -> Localization {
        Localization(supported: supported, default: LocaleID("en")!, strategy: strategy)
    }

    private func boot(_ strategy: LocaleStrategy?, path: String = "/",
                      persisted: String? = nil, preferred: [String] = [],
                      servedLang: String? = nil, secureContext: Bool = false) -> (Runtime<MockBackend>, MockBackend) {
        let backend = MockBackend(); let sched = Sched()
        if let persisted { backend.localStorage["__swiftwui.locale"] = persisted }
        backend.preferred = preferred
        let runtime = Runtime(backend: backend, container: backend.container, root: Show(),
                              initialPath: path, scheduleMicrotask: sched.schedule,
                              localization: strategy.map(l10n))
        runtime._servedLanguage = servedLang
        runtime._isSecureContext = secureContext
        runtime.mount(); sched.drain()
        return (runtime, backend)
    }

    @Test func urlOnlyIgnoresEverythingElse() {
        let (runtime, backend) = boot(.pathPrefix(detection: .urlOnly), path: "/ru",
                                      persisted: "de", preferred: ["de"])
        #expect(runtime._signals.locale == LocaleID("ru")!)
        #expect(backend.replacedStates.isEmpty)
    }

    @Test func fullChainPrefersPersistedOverNavigator() {
        let (runtime, _) = boot(.client, persisted: "de", preferred: ["ru"])
        #expect(runtime._signals.locale == LocaleID("de")!)
    }

    @Test func navigatorMatchesByPrimarySubtag() {
        let (runtime, _) = boot(.client, preferred: ["ru-RU", "en"])
        #expect(runtime._signals.locale == LocaleID("ru")!)
    }

    @Test func hostileValuesFallBackToDefault() {
        let (runtime, _) = boot(.client, persisted: "../etc/passwd", preferred: ["<script>"])
        #expect(runtime._signals.locale == LocaleID("en")!)
    }

    @Test func fullChainAlignsTheUrlWhenItDisagrees() {
        let (runtime, backend) = boot(.pathPrefix(detection: .full), path: "/about",
                                      persisted: "ru")
        #expect(runtime._signals.locale == LocaleID("ru")!)
        #expect(backend.replacedStates.last == "/ru/about")
        #expect(backend.documentLanguage?.lang == "ru")
        #expect(backend.serializeHTML().contains("ru"))
    }

    @Test func negotiatedTrustsTheServedDocumentFirst() {
        let (runtime, backend) = boot(.negotiated, preferred: ["ru"], servedLang: "de")
        #expect(runtime._signals.locale == LocaleID("de")!)
        #expect(backend.replacedStates.isEmpty)          // clean URLs are never rewritten
        #expect(backend.cookies.isEmpty)                 // nothing to correct, nothing to write
    }

    /// A document served as a region variant of a declared locale is already
    /// right — no redundant Set-Cookie on every load.
    @Test func negotiatedWritesNoCookieForARegionVariantOfTheServedLocale() {
        let (runtime, backend) = boot(.negotiated, servedLang: "de-DE")
        #expect(runtime._signals.locale == LocaleID("de")!)
        #expect(backend.cookies.isEmpty)
    }

    @Test func negotiatedPersistedChoiceWritesTheCookie() {
        let (runtime, backend) = boot(.negotiated, persisted: "ru", servedLang: "en")
        #expect(runtime._signals.locale == LocaleID("ru")!)
        #expect(backend.cookies["swiftwui_locale"] == "ru")
    }

    /// The cookie the edge reads back is the whole point of `.negotiated`, so
    /// its attributes are part of the contract, not an implementation detail:
    /// `Secure` on https and a year of TTL (Task 6 review carry).
    @Test func negotiatedCookieIsSecureAndYearLongOnHTTPS() {
        let (_, backend) = boot(.negotiated, persisted: "ru", servedLang: "en", secureContext: true)
        #expect(backend.cookieWrites.count == 1)
        #expect(backend.cookieWrites.last?.name == "swiftwui_locale")
        #expect(backend.cookieWrites.last?.secure == true)
        #expect(backend.cookieWrites.last?.maxAgeDays == 365)
    }

    // MARK: storage-vs-URL precedence (Task 9 carry)

    /// A prefix in the URL is either a link somebody deliberately shared or a
    /// history entry this runtime wrote — an origin-writable store must not
    /// bounce the visitor out of it.
    @Test func anExplicitPrefixBeatsStoredAndNavigatorLocales() {
        let (runtime, backend) = boot(.pathPrefix(detection: .full), path: "/ru/about",
                                      persisted: "de", preferred: ["de"])
        #expect(runtime._signals.locale == LocaleID("ru")!)
        #expect(backend.replacedStates.isEmpty)          // URL and locale already agree
        #expect(backend.documentLanguage?.lang == "ru")
    }

    /// Back to an unprefixed entry means the default locale (Task 9); the
    /// persisted value has to follow, or the next reload resurrects the old one.
    @Test func backThenReloadKeepsTheUrlsLocale() {
        let (runtime, backend) = boot(.pathPrefix(detection: .full), path: "/ru/about",
                                      persisted: "ru")
        runtime.handlePopState(url: "/about")
        #expect(runtime._signals.locale == LocaleID("en")!)
        #expect(backend.localStorage["__swiftwui.locale"] == "en")

        let (reloaded, reloadedBackend) = boot(.pathPrefix(detection: .full), path: "/about",
                                               persisted: backend.localStorage["__swiftwui.locale"])
        #expect(reloaded._signals.locale == LocaleID("en")!)
        #expect(reloadedBackend.replacedStates.isEmpty)
    }

    /// The gate is only observable on an unprefixed path: with a prefix present
    /// the chain returns before it would have read anything anyway.
    @Test func urlOnlyReadsNoClientSources() {
        let (runtime, backend) = boot(.pathPrefix(detection: .urlOnly), path: "/about",
                                      persisted: "ru", preferred: ["de"])
        #expect(runtime._signals.locale == LocaleID("en")!)
        #expect(backend.counts["storageRead"] == nil)
        #expect(backend.counts["preferredLanguages"] == nil)
        #expect(backend.replacedStates.isEmpty)
    }

    @Test func navigatorAloneAlignsTheUrl() {
        let (runtime, backend) = boot(.pathPrefix(detection: .full), path: "/about",
                                      preferred: ["ru-RU"])
        #expect(runtime._signals.locale == LocaleID("ru")!)
        #expect(backend.replacedStates.last == "/ru/about")
    }

    @Test func bootAlignmentKeepsTheQueryString() {
        let (_, backend) = boot(.pathPrefix(detection: .full), path: "/about?q=1", persisted: "ru")
        #expect(backend.replacedStates.last == "/ru/about?q=1")
    }

    /// Detection never persists: only an explicit choice (`setLocale`) and a
    /// history entry the runtime itself wrote (`handlePopState`) do.
    @Test func detectionDoesNotPersistOrWriteACookie() {
        let (_, backend) = boot(.client, preferred: ["de"])
        #expect(backend.localStorage["__swiftwui.locale"] == nil)
        #expect(backend.cookies.isEmpty)
    }

    @Test func negotiatedFallsBackToNavigatorWithoutAServedLanguage() {
        let (runtime, _) = boot(.negotiated, preferred: ["de"])
        #expect(runtime._signals.locale == LocaleID("de")!)
    }

    @Test func monolingualBootTouchesNothing() {
        let (_, backend) = boot(nil, persisted: "ru", preferred: ["ru"])
        #expect(backend.documentLanguage == nil)
        #expect(backend.counts["preferredLanguages"] == nil)
        #expect(backend.counts["storageRead"] == nil)
        #expect(backend.replacedStates.isEmpty)
        #expect(backend.cookies.isEmpty)
    }
}
