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
        let (runtime, _, sched) = make(initialPath: "/")
        runtime.handlePopState(url: "/ru/about")
        sched.pump()
        #expect(runtime._locationPath == "/about")
        #expect(runtime._signals.locale == LocaleID("ru")!)
        _ = runtime
    }
}
