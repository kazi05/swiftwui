import Testing
@testable import SwiftWUI

@MainActor private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

private struct LocaleReader: Tag {
    @Environment(\.locale) var locale
    @Environment(\.layoutDirection) var direction
    @Environment(\.setLocale) var setLocale
    var body: some Tag {
        Div {
            Text(locale.identifier + "/" + direction.rawValue)
            Button("switch") { setLocale(LocaleID("ar")!) }
        }
    }
}

@Suite @MainActor struct LocaleEnvironmentTests {
    private let l10n = Localization(supported: [LocaleID("en")!, LocaleID("ru")!, LocaleID("ar")!],
                                    default: LocaleID("en")!,
                                    strategy: .client)

    private func makeRuntime() -> (Runtime<MockBackend>, MockBackend, Sched) {
        let backend = MockBackend(); let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container, root: LocaleReader(),
                              scheduleMicrotask: sched.schedule, localization: l10n)
        runtime.mount(); sched.drain()
        return (runtime, backend, sched)
    }

    @Test func defaultsOutsideRuntime() {
        #expect(EnvironmentValues().locale == LocaleID("en")!)
        #expect(EnvironmentValues().layoutDirection == .leftToRight)
        #expect(EnvironmentValues().availableLocales.isEmpty)
    }

    @Test func seedsDefaultLocaleBeforeFirstPass() {
        let (runtime, backend, _) = makeRuntime()
        #expect(backend.serializeHTML().contains("en/ltr"))
        #expect(runtime._signals.defaultLocale == LocaleID("en")!)
    }

    @Test func setLocaleRerendersPersistsAndSetsLang() {
        let (runtime, backend, sched) = makeRuntime()
        runtime.setLocale(LocaleID("ar")!)
        sched.drain()
        #expect(backend.serializeHTML().contains("ar/rtl"))
        #expect(backend.documentLanguage?.lang == "ar")
        #expect(backend.documentLanguage?.dir == "rtl")
        #expect(backend.localStorage["__swiftwui.locale"] == "ar")
        #expect(backend.cookies.isEmpty)                    // .client does not write cookies
    }

    @Test func unsupportedLocaleIsANoOp() {
        let (runtime, backend, sched) = makeRuntime()
        runtime.setLocale(LocaleID("de")!)
        sched.drain()
        #expect(backend.serializeHTML().contains("en/ltr"))
        #expect(backend.localStorage["__swiftwui.locale"] == nil)
    }

    @Test func availableLocalesReachTheBody() {
        struct Switcher: Tag {
            @Environment(\.availableLocales) var locales
            var body: some Tag { Text(locales.map(\.identifier).joined(separator: ",")) }
        }
        let backend = MockBackend(); let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container, root: Switcher(),
                              scheduleMicrotask: sched.schedule, localization: l10n)
        runtime.mount(); sched.drain()
        #expect(backend.serializeHTML().contains("en,ru,ar"))
        _ = runtime
    }
}
