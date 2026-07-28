import Testing
@testable import SwiftWUI

@MainActor private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

private let hello = LocalizedText(key: "hello") { locale in
    switch locale.language {
    case "en": return "Hello"
    case "ru": return "Привет"
    default: return nil
    }
}

private struct Sinks: Tag {
    var body: some Tag {
        Div {
            Text(hello)
            Button(hello) {}
            Img(src: "/a.png", alt: hello)
            Input(placeholder: hello)
            Textarea(text: .constant(""), placeholder: hello)
            P { Text("x") }.attribute("title", hello)
        }
    }
}

@Suite @MainActor struct LocalizedSinksTests {
    private func render(_ locale: String) -> String {
        let backend = MockBackend(); let sched = Sched()
        let l10n = Localization(supported: [LocaleID("en")!, LocaleID("ru")!],
                                default: LocaleID("en")!, strategy: .client)
        let runtime = Runtime(backend: backend, container: backend.container, root: Sinks(),
                              scheduleMicrotask: sched.schedule, localization: l10n)
        runtime.mount(); sched.drain()
        runtime.setLocale(LocaleID(locale)!); sched.drain()
        let html = backend.serializeHTML()
        _ = runtime
        return html
    }

    @Test func textAndAttributesFollowTheLocale() {
        let ru = render("ru")
        #expect(ru.contains("Привет"))
        #expect(ru.contains(#"alt="Привет""#))
        #expect(ru.contains(#"placeholder="Привет""#))
        #expect(ru.contains(#"title="Привет""#))
        #expect(!ru.contains("Hello"))
    }

    @Test func attributeAppearsExactlyOnce() {
        let ru = render("ru")
        let occurrences = ru.components(separatedBy: "alt=").count - 1
        #expect(occurrences == 1)
    }

    @Test func missingTranslationFallsBackToDefault() {
        let backend = MockBackend(); let sched = Sched()
        let l10n = Localization(supported: [LocaleID("en")!, LocaleID("de")!],
                                default: LocaleID("en")!, strategy: .client)
        let runtime = Runtime(backend: backend, container: backend.container, root: Sinks(),
                              scheduleMicrotask: sched.schedule, localization: l10n)
        runtime.mount(); sched.drain()
        runtime.setLocale(LocaleID("de")!); sched.drain()
        #expect(backend.serializeHTML().contains("Hello"))
        _ = runtime
    }

    // `Text(String)` must keep its exact old behaviour: no locale lookup, and
    // `content` still readable as the literal that was passed in.
    @Test func plainTextIsUntouched() {
        #expect(Text("hello").content == "hello")
        let backend = MockBackend(); let sched = Sched()
        let l10n = Localization(supported: [LocaleID("en")!, LocaleID("ru")!],
                                default: LocaleID("en")!, strategy: .client)
        struct Plain: Tag { var body: some Tag { Div { Text("hello") } } }
        let runtime = Runtime(backend: backend, container: backend.container, root: Plain(),
                              scheduleMicrotask: sched.schedule, localization: l10n)
        runtime.mount(); sched.drain()
        runtime.setLocale(LocaleID("ru")!); sched.drain()
        #expect(backend.serializeHTML().contains("hello"))
        _ = runtime
    }

    // Pins `markDirty(.root)` in `Runtime.setLocale`. `Greeter.body` reads NO
    // environment value, so Observation alone never invalidates it — the locale
    // read happens in `Text._resolve`, outside the tracking window that
    // `Resolver.swift:97-102` opens around `tag.body`. Delete the root
    // invalidation and this is the test that goes red.
    @Test func localeSwitchRerendersABodyThatReadsNoEnvironment() {
        struct Greeter: Tag { var body: some Tag { Text(hello) } }
        let backend = MockBackend(); let sched = Sched()
        let l10n = Localization(supported: [LocaleID("en")!, LocaleID("ru")!],
                                default: LocaleID("en")!, strategy: .client)
        let runtime = Runtime(backend: backend, container: backend.container, root: Greeter(),
                              scheduleMicrotask: sched.schedule, localization: l10n)
        runtime.mount(); sched.drain()
        #expect(backend.serializeHTML().contains("Hello"))
        runtime.setLocale(LocaleID("ru")!); sched.drain()
        #expect(backend.serializeHTML().contains("Привет"))
        _ = runtime
    }

    @Test func pageTitleFollowsTheLocale() {
        struct Titled: Tag {
            var body: some Tag { P { Text("x") }.pageMeta(title: hello, links: [.canonical("/c")]) }
        }
        let backend = MockBackend(); let sched = Sched()
        let l10n = Localization(supported: [LocaleID("en")!, LocaleID("ru")!],
                                default: LocaleID("en")!, strategy: .client)
        let runtime = Runtime(backend: backend, container: backend.container, root: Titled(),
                              scheduleMicrotask: sched.schedule, localization: l10n)
        runtime.mount(); sched.drain()
        #expect(backend.title == "Hello")
        #expect(backend.links.contains { $0.attributes["href"] == "/c" })
        runtime.setLocale(LocaleID("ru")!); sched.drain()
        #expect(backend.title == "Привет")
        _ = runtime
    }

    // A localized value reaching an attribute goes through the same escaping
    // choke point as a plain one — it is a value in the bag, never raw markup.
    @Test func localizedAttributeValuesAreEscaped() {
        let nasty = LocalizedText(key: "nasty") { _ in #"" onload="x"# }
        struct Hostile: Tag {
            let text: LocalizedText
            var body: some Tag { Img(src: "/a.png", alt: text) }
        }
        let backend = MockBackend(); let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container, root: Hostile(text: nasty),
                              scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        // The whole payload stays inside one quoted value; nothing breaks out.
        #expect(backend.serializeHTML().contains(#"alt="&quot; onload=&quot;x""#))
        _ = runtime
    }
}
