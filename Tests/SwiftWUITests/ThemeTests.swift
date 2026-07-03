import Testing
@testable import SwiftWUI

extension ColorToken { fileprivate static let accent = ColorToken("accent") }
extension LengthToken { fileprivate static let pad = LengthToken("pad") }

@Suite struct ThemeTests {
    @Test func tokenRendering() {
        #expect(CSSColor.token(.accent).css == "var(--accent)")
        #expect(CSSLength.token(.pad).css == "var(--pad)")
        #expect(StyleDeclaration.color(.token(.accent)).value == "var(--accent)")
    }
    @Test func themeRuleText() {
        let light = ThemeDefinition { t in
            t.set(ColorToken.accent, .hex("#e94560"))
            t.set(LengthToken.pad, .px(8))
        }
        #expect(light.ruleText == ":root { --accent: #e94560; --pad: 8px }")
        let dark = ThemeDefinition(name: "dark") { t in
            t.set(ColorToken.accent, .hex("#16213e"))
        }
        #expect(dark.ruleText == #"[data-theme="dark"] { --accent: #16213e }"#)
    }
    @Test func runtimeEmitsThemesAndSwitches() {
        struct Root: Tag {
            @Environment(\.setTheme) var setTheme
            var body: some Tag { Div { Button("dark") { setTheme("dark") } } }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule,
                         themes: [ThemeDefinition { $0.set(ColorToken.accent, .hex("#e94560")) },
                                  ThemeDefinition(name: "dark") { $0.set(ColorToken.accent, .hex("#16213e")) }])
        rt.mount()
        #expect(backend.stylesheetText?.contains(":root { --accent: #e94560 }") == true)
        #expect(backend.stylesheetText?.contains(#"[data-theme="dark"]"#) == true)
        // switch via the environment action wired through the button
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        #expect(backend.container.attrs["data-theme"] == "dark")
        rt.setTheme(nil)
        #expect(backend.container.attrs["data-theme"] == nil)
    }
}
