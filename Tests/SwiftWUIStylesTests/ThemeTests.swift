import Testing
@testable import SwiftWUIStyles

private struct TestTheme: Theme {
    let tokens: [String: String]
}

@Suite("Theme tokens")
struct ThemeTests {
    @Test("CSSColor.token expands to var(--name)")
    func tokenExpansion() {
        let color = CSSColor.token("background")
        #expect(color.cssValue == "var(--background)")
    }

    @Test("Theme.cssDeclarations emits sorted, dash-prefixed declarations")
    func declarationsAreSorted() {
        let theme = TestTheme(tokens: [
            "foreground": "#111",
            "background": "#fff",
            "accent": "#0066ff",
        ])
        // Alphabetical: accent, background, foreground.
        #expect(theme.cssDeclarations == "--accent: #0066ff; --background: #fff; --foreground: #111;")
    }

    @Test("ThemeCSS.definitions(light:dark:) emits root + dark media query + explicit selectors")
    func pairedDefinitions() {
        let light = TestTheme(tokens: ["bg": "#fff"])
        let dark = TestTheme(tokens: ["bg": "#000"])
        let css = ThemeCSS.definitions(light: light, dark: dark)

        #expect(css.contains(":root { --bg: #fff; }"))
        #expect(css.contains("@media (prefers-color-scheme: dark) { :root { --bg: #000; } }"))
        #expect(css.contains("[data-theme=\"light\"] { --bg: #fff; }"))
        #expect(css.contains("[data-theme=\"dark\"] { --bg: #000; }"))
    }

    @Test("ThemeCSS.definitions(named:theme:) scopes to a custom data-theme selector")
    func namedDefinitions() {
        let highContrast = TestTheme(tokens: ["bg": "#000", "fg": "#fff"])
        let css = ThemeCSS.definitions(named: "high-contrast", theme: highContrast)
        #expect(css == "[data-theme=\"high-contrast\"] { --bg: #000; --fg: #fff; }")
    }
}
