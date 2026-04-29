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
        #expect(css.contains("@media (prefers-color-scheme: dark) { :root:not([data-theme=\"light\"]) { --bg: #000; } }"))
        #expect(css.contains("[data-theme=\"light\"] { --bg: #fff; }"))
        #expect(css.contains("[data-theme=\"dark\"] { --bg: #000; }"))
    }

    @Test("ThemeCSS dark media query uses :not([data-theme=\"light\"]) for specificity precedence")
    func darkMediaQuerySpecificity() {
        let light = TestTheme(tokens: ["color": "#fff"])
        let dark = TestTheme(tokens: ["color": "#000"])
        let css = ThemeCSS.definitions(light: light, dark: dark)

        // The dark media-query rule must use :root:not([data-theme="light"]) so that
        // a user-pinned light theme wins by specificity (0-1-1 vs 0-1-0) rather than
        // by source order alone. A plain :root selector would share specificity 0-0-1
        // with [data-theme="light"] and let source order decide the winner.
        #expect(css.contains(":root:not([data-theme=\"light\"])"))
        // The generated CSS must NOT use the bare :root form inside the media query.
        #expect(!css.contains("@media (prefers-color-scheme: dark) { :root {"))
    }

    @Test("ThemeCSS.definitions(named:theme:) scopes to a custom data-theme selector")
    func namedDefinitions() {
        let highContrast = TestTheme(tokens: ["bg": "#000", "fg": "#fff"])
        let css = ThemeCSS.definitions(named: "high-contrast", theme: highContrast)
        #expect(css == "[data-theme=\"high-contrast\"] { --bg: #000; --fg: #fff; }")
    }
}
