import Testing
import SwiftWUI
@testable import TutorialKit

@Suite struct ThemeTests {
    @Test @MainActor func stylesheetRegistersAllContractClasses() {
        struct Probe: SwiftWUI.Tag { var body: some SwiftWUI.Tag { Div { Text("x") } } }
        let backend = MockBackend()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Probe(), scheduleMicrotask: { $0() },
                         globalStyles: TutorialStyles.rules,
                         themes: TutorialApp.themes)   // :root + the two named themes
        rt.mount()
        let css = rt._registryText
        // :root theme block carries every token family: paper, graphite, ink,
        // accent, status, code, page width
        for token in ["--paper", "--graphite", "--hairline", "--ink-3", "--accent",
                      "--ok", "--err", "--focus", "--code-str", "--w-page"] {
            #expect(css.contains(token), "missing \(token)")
        }
        // Load-bearing selectors. Stateful surfaces are base + exactly one skin,
        // so both halves of a pair have to be registered.
        for cls in ["tut-content", "tut-hero", "tut-panel", "tut-section-body",
                    "tut-rail", "tut-rail-fill", "tut-step-badge", "tut-step-badge-active",
                    "tut-card-dark", "tut-panel-bar", "tut-lang-chip",
                    "tut-option", "tut-option-rest", "tut-option-selected",
                    "tut-option-correct", "tut-option-wrong",
                    "tut-menu", "tut-menu-open", "tut-theme-toggle", "tok-kw"] {
            #expect(css.contains(".\(cls)"), "missing rule .\(cls)")
        }
        #expect(css.contains("sticky"))                          // chapter bar + panel bar
        #expect(css.contains("max-width: var(--w-page)"))
        #expect(css.contains("--w-page: 1280px"))
        // The glass panel bar is a real translucent layer, not a flat fill.
        #expect(css.contains(".tut-panel-bar { position: sticky"))
        #expect(css.contains("backdrop-filter: blur(14px)"))
        // One focus ring, on :focus-visible — never a colour swap on :focus.
        #expect(css.contains(":focus-visible { outline-width: 2px"))
        // Dark mode: the media block AND the manual [data-theme] override.
        #expect(css.contains("@media (prefers-color-scheme: dark)"))
        #expect(css.contains("[data-theme=\"dark\"]"))
        #expect(css.contains("[data-theme=\"light\"]"))
        // Mobile-first cascade: the breakpoint steps are min-width.
        #expect(css.contains("@media (min-width: 768px)"))
        // The fake mac-window chrome is gone and stays gone.
        #expect(!css.contains(".tut-dot"))
        #expect(!css.contains(".tut-chrome"))
    }
}
