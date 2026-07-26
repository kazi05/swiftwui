import Testing
@testable import SwiftWUI

@Suite @MainActor struct ViewTransitionCSSTests {
    @Test func validNameBecomesAnInlineDeclaration() {
        let d = StyleDeclaration.viewTransitionName("hero")
        #expect(d?.property == "view-transition-name")
        #expect(d?.value == "hero")
    }

    @Test func reservedAndInvalidNamesAreDropped() {
        #expect(StyleDeclaration.viewTransitionName("root") == nil)        // the document element's own name
        #expect(StyleDeclaration.viewTransitionName("-ua-thing") == nil)   // UA-reserved prefix
        #expect(StyleDeclaration.viewTransitionName("has spaces") == nil)
        #expect(StyleDeclaration.viewTransitionName("x; color: red") == nil)
    }

    @Test func namespaceQualifiesAndValidatesItsPrefix() {
        let ns = TransitionNamespace("hotels")
        #expect(StyleDeclaration.viewTransitionName(ns.qualify("42"))?.value == "hotels-42")
        let bad = TransitionNamespace("not an ident")
        #expect(bad.qualify("42") == "42")      // prefix dropped once, at init
    }

    @Test func modifierEmitsInlineNamesOnBothSurfaces() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: MatchedFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let div = findFirst(backend.container, tag: "div")!
        let span = findFirst(backend.container, tag: "span")!
        #expect(transitionName(div) == "card")
        #expect(transitionName(span) == "label")
    }

    @Test func slidePresetRegistersGroupTimingOldNewAndPopVariants() {
        let registry = StyleRegistry()
        PageTransition.slide().register(into: registry)
        let css = registry.text
        #expect(css.contains("::view-transition-group(*)"))
        #expect(css.contains("animation-duration: 220ms"))
        #expect(css.contains("::view-transition-old(root)"))
        #expect(css.contains("::view-transition-new(root)"))
        #expect(css.contains("[data-swui-nav=\"pop\"]"))
        #expect(css.contains("@media (prefers-reduced-motion: no-preference)"))
        #expect(css.contains("@media (prefers-reduced-motion: reduce)"))
        #expect(css.contains("mix-blend-mode: plus-lighter"))
    }

    @Test func groupRulesNeverSetAnimationName() {
        let registry = StyleRegistry()
        PageTransition.slide().register(into: registry)
        PageTransition.fade.register(into: registry)
        for line in registry.text.split(separator: "\n") where line.contains("view-transition-group") {
            // The reduced-motion kill switch is the ONE sanctioned exception —
            // and only the `prefers-reduced-motion: reduce` line, not any
            // group-timing line, may contain it.
            if line.contains("prefers-reduced-motion: reduce"), line.contains("animation: none") { continue }
            #expect(!line.contains("animation-name"))
            #expect(!line.contains("animation:"))
        }
    }

    @Test func reducedMotionWrapperOnlyWhenRespected() {
        let opted = StyleRegistry()
        PageTransition.slide().respectsReducedMotion(false).register(into: opted)
        #expect(!opted.text.contains("prefers-reduced-motion: no-preference"))
        let respecting = StyleRegistry()
        PageTransition.slide().register(into: respecting)
        #expect(respecting.text.contains("prefers-reduced-motion: no-preference"))
    }

    @Test func optedOutTransitionNeverEmitsTheReduceKillSwitch() {
        // The opt-out's whole point is to keep animating under reduced
        // motion — the kill switch would silently defeat it.
        let registry = StyleRegistry()
        PageTransition.slide().respectsReducedMotion(false).register(into: registry)
        #expect(!registry.text.contains("animation: none"))
        #expect(!registry.text.contains("prefers-reduced-motion: reduce"))
    }

    @Test func reduceKillSwitchIsScopedToItsOwnPresetAttribute() {
        // Not the bare `[data-swui-vt]` presence check — that would also
        // match (and kill) a sibling opted-out preset's own selector.
        let t = PageTransition.slide()
        let registry = StyleRegistry()
        t.register(into: registry)
        let scoped = "html[data-swui-vt=\"\(t.cssAttributeValue)\"]::view-transition-group(*) { animation: none }"
        #expect(registry.text.contains("@media (prefers-reduced-motion: reduce) { \(scoped) }"))
    }

    @Test func mountWithoutArmingRegistersNoViewTransitionRule() {
        struct PlainRoot: Tag { var body: some Tag { Div { Text("x") } } }
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: PlainRoot(), scheduleMicrotask: sched.schedule)
        runtime.mount()   // no `withViewTransition` / transition ever armed
        #expect(!runtime._registryText.contains("::view-transition"))
    }

    @Test func attributeValueSeparatesConfigurationsAndDedupes() {
        let a = PageTransition.slide()
        let b = PageTransition.slide().duration(.ms(400))
        #expect(a.cssAttributeValue != b.cssAttributeValue)
        let registry = StyleRegistry()
        a.register(into: registry)
        let versionAfterFirst = registry.version
        a.register(into: registry)
        #expect(registry.version == versionAfterFirst)     // identical text dedupes
    }

    @Test func contentFitEmitsObjectFitOnOldAndNewNeverOnTheGroup() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ContentFitFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let css = runtime._registryText
        #expect(css.contains("::view-transition-old(hero) { object-fit: none }"))
        #expect(css.contains("::view-transition-new(hero) { object-fit: none }"))
        #expect(!css.contains("::view-transition-group(hero)"))
    }

    @Test func customTransitionRegistersItsKeyframes() {
        let out = Keyframes("vt-out") { $0.to { $0.opacity(0) } }
        let into = Keyframes("vt-in") { $0.from { $0.opacity(0) } }
        let registry = StyleRegistry()
        PageTransition.custom(old: out, new: into).register(into: registry)
        #expect(registry.text.contains("@keyframes \(out.cssName)"))
        #expect(registry.text.contains("@keyframes \(into.cssName)"))
        #expect(registry.text.contains(out.cssName))
    }

    @Test func duplicateNamesWarnButDoNotTrap() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: DuplicateNames(), scheduleMicrotask: sched.schedule)
        runtime.mount()                     // must not trap under debug
        #expect(findFirst(backend.container, tag: "div") != nil)
    }

    @Test func zoomRulesTargetOldAndNewNeverTheGroup() {
        let registry = StyleRegistry()
        PageTransition.zoom(sourceID: "card-7").register(into: registry)
        let css = registry.text
        #expect(css.contains("::view-transition-old(card-7)"))
        #expect(css.contains("::view-transition-new(card-7)"))
        #expect(css.contains("border-radius"))
        for line in css.split(separator: "\n") where line.contains("view-transition-group") {
            guard !line.contains("animation: none") else { continue }
            #expect(!line.contains("animation-name"))
        }
    }

    @Test func sugarResolvesToTheSameNameOnBothSides() {
        let ns = TransitionNamespace("hotels")
        let backend = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ZoomSugarFixture(namespace: ns), scheduleMicrotask: sched.schedule)
        runtime.mount()
        let source = findFirst(backend.container, tag: "article")!
        #expect(transitionName(source) == "hotels-7")
    }
}

private func transitionName(_ node: MockNode) -> String? {
    node.style.entries.first { $0.property == "view-transition-name" }?.value
}

private struct MatchedFixture: Tag {
    var body: some Tag {
        // `Span` has no text-convenience init (unlike H1/Button); `{ "hi" }`
        // goes through `TagBuilder.buildExpression(String) -> Text`.
        Div {
            Span { "hi" }.matchedTransition(id: "label")
        }
        .matchedTransition(id: "card")
    }
}

private struct ContentFitFixture: Tag {
    var body: some Tag {
        // `contentFit`'s type is `TransitionContentFit?`, so a bare `.none`
        // resolves to `Optional.none` (nil) rather than the `.none` case —
        // spell out the type to actually pass the case.
        Section { Text("hero") }.matchedTransition(id: "hero", contentFit: TransitionContentFit.none)
    }
}

private struct DuplicateNames: Tag {
    var body: some Tag {
        Div {
            Span { "a" }.matchedTransition(id: "dup")
            Span { "b" }.matchedTransition(id: "dup")
        }
    }
}

private struct ZoomSugarFixture: Tag {
    let namespace: TransitionNamespace
    var body: some Tag {
        Article { Text("card") }.matchedTransitionSource(id: "7", in: namespace)
    }
}
