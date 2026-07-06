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
                         themes: [TutorialTheme.definition])
        rt.mount()
        let css = rt._registryText
        // :root theme block carries every token
        for token in ["--page-bg", "--dark-bg", "--accent", "--code-string", "--border-light"] {
            #expect(css.contains(token), "missing \(token)")
        }
        // spot-check load-bearing selectors incl. sticky + breakpoint collapse
        for cls in ["tut-content", "tut-hero", "tut-panel", "tut-section-body",
                    "tut-option-selected", "tut-menu-open", "tok-kw", "tut-card-dark"] {
            #expect(css.contains(".\(cls)"), "missing rule .\(cls)")
        }
        #expect(css.contains("sticky"))
        #expect(css.contains("max-width: 1080px"))
    }
}
