import Testing
@testable import SwiftWUI

private struct PrefixApp: Tag {
    var body: some Tag {
        Router {
            Route("/") { _ in Link("/about") { Text("about") } }
            Route("/about") { _ in Text("about page") }
        }
    }
}

@Suite @MainActor struct LocalePathTests {
    private let supported = [LocaleID("en")!, LocaleID("ru")!]

    private func make(initialPath: String)
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let l10n = Localization(supported: supported, default: LocaleID("en")!,
                                strategy: .pathPrefix(detection: .urlOnly))
        let runtime = Runtime(backend: backend, container: backend.container, root: PrefixApp(),
                              initialPath: initialPath, scheduleMicrotask: sched.schedule,
                              localization: l10n)
        runtime.mount(); sched.pump()
        return (runtime, backend, sched)
    }

    @Test func internalizeStripsKnownPrefixOnly() {
        #expect(LocalePath.internalize("/ru/about", supported: supported).path == "/about")
        #expect(LocalePath.internalize("/ru/about", supported: supported).locale == LocaleID("ru")!)
        #expect(LocalePath.internalize("/ru", supported: supported).path == "/")
        #expect(LocalePath.internalize("/about", supported: supported).locale == nil)
        #expect(LocalePath.internalize("/de/about", supported: supported).path == "/de/about")
        #expect(LocalePath.internalize("/rutabaga", supported: supported).path == "/rutabaga")
    }

    /// `internalize` matches the segment against `supported` EXACTLY, never
    /// through `Localization.validated` — that one reduces a tag to its primary
    /// language in both directions, so an `["en"]` app would answer `/en-US/…`
    /// and then rewrite the URL to a locale the visitor never asked for, and an
    /// `["en-US"]` app would adopt `/en/…`, a locale it never declared.
    @Test func internalizeMatchesTheSegmentExactly() {
        let regional = [LocaleID("en-US")!]
        #expect(LocalePath.internalize("/en/about", supported: regional).path == "/en/about")
        #expect(LocalePath.internalize("/en/about", supported: regional).locale == nil)
        #expect(LocalePath.internalize("/en-US/about", supported: regional).locale == LocaleID("en-US")!)

        let plain = [LocaleID("en")!]
        #expect(LocalePath.internalize("/en-US/about", supported: plain).path == "/en-US/about")
        #expect(LocalePath.internalize("/en-US/about", supported: plain).locale == nil)
        // The validator this must never be routed through, for contrast.
        #expect(Localization(supported: plain, default: plain[0]).validated("en-US") == plain[0])
    }

    @Test func externalizeAddsPrefixExceptForDefault() {
        let en = LocaleID("en")!, ru = LocaleID("ru")!
        #expect(LocalePath.externalize("/about", locale: en, default: en) == "/about")
        #expect(LocalePath.externalize("/about", locale: ru, default: en) == "/ru/about")
        #expect(LocalePath.externalize("/", locale: ru, default: en) == "/ru")
        #expect(LocalePath.externalize("/", locale: en, default: en) == "/")
    }

    @Test func runtimeKeepsInternalPathAndPushesExternal() {
        let (runtime, backend, sched) = make(initialPath: "/ru")
        #expect(runtime._locationPath == "/")                       // prefix stripped for routing
        #expect(runtime._signals.locale == LocaleID("ru")!)         // and seeded as the locale

        runtime.navigate(to: "/about")
        sched.pump()
        #expect(runtime._locationPath == "/about")
        #expect(backend.historyStack.last == "/ru/about")           // prefix re-applied on output
        #expect(backend.serializeHTML().contains("about page"))
        _ = runtime
    }

    @Test func linkHrefCarriesThePrefix() {
        let (runtime, backend, _) = make(initialPath: "/ru")
        #expect(backend.serializeHTML().contains(#"href="/ru/about""#))
        _ = runtime
    }

    @Test func popstateAdoptsTheUrlLocale() {
        let (runtime, backend, sched) = make(initialPath: "/")
        runtime.handlePopState(url: "/ru/about")
        sched.pump()
        #expect(runtime._locationPath == "/about")
        #expect(runtime._signals.locale == LocaleID("ru")!)
        #expect(backend.documentLanguage?.lang == "ru")
        // Back to an unprefixed entry restores the DEFAULT locale — it must not
        // leave a Russian page sitting at an English URL.
        runtime.handlePopState(url: "/")
        sched.pump()
        #expect(runtime._signals.locale == LocaleID("en")!)
        #expect(backend.documentLanguage?.lang == "en")
        _ = runtime
    }

    @Test func setLocaleRealignsTheUrlKeepingTheQuery() {
        let (runtime, backend, sched) = make(initialPath: "/ru/about?x=1")
        runtime.setLocale(LocaleID("en")!)
        sched.pump()
        #expect(backend.replacedStates.last == "/about?x=1")
        #expect(runtime._locationPath == "/about")      // routing never saw either prefix
    }
}
