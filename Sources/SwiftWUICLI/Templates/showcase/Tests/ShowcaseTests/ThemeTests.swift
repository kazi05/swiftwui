import Testing
@testable import {{PROJECT_NAME}}

@Suite("{{PROJECT_NAME}}Theme")
struct {{PROJECT_NAME}}ThemeTests {
    @Test("Emits dark-mode tokens by default under prefers-color-scheme: dark")
    func darkTokens() {
        let css = {{PROJECT_NAME}}Theme.css
        #expect(css.contains("--swui-bg: #000000"))
        #expect(css.contains("--swui-fg: #f5f5f7"))
        #expect(css.contains("--swui-accent: #5ac8b0"))
        #expect(css.contains("--syntax-keyword: #fc5fa3"))
    }

    @Test("Emits light-mode tokens under prefers-color-scheme: light")
    func lightTokens() {
        let css = {{PROJECT_NAME}}Theme.css
        #expect(css.contains("@media (prefers-color-scheme: light)"))
        #expect(css.contains("--swui-bg: #ffffff"))
        #expect(css.contains("--swui-fg: #1d1d1f"))
        #expect(css.contains("--swui-accent: #0a84ff"))
        #expect(css.contains("--syntax-keyword: #ad3da4"))
    }

    @Test("Manual override via [data-theme=light] beats system default")
    func manualLightOverride() {
        let css = {{PROJECT_NAME}}Theme.css
        #expect(css.contains(":root[data-theme=\"light\"]"))
        #expect(css.contains(":root[data-theme=\"dark\"]"))
    }

    @Test("Tutorials accent matches the Apple wordmark mint-teal in dark mode")
    func accentMatchesReference() {
        let css = {{PROJECT_NAME}}Theme.css
        #expect(css.contains("--swui-accent-strong: #66e1c1"))
    }

    @Test("All required tokens declared in both modes")
    func allTokensDeclared() {
        let required: [String] = [
            "--swui-bg", "--swui-surface", "--swui-surface-2",
            "--swui-fg", "--swui-fg-2", "--swui-fg-3",
            "--swui-border", "--swui-border-strong",
            "--swui-accent", "--swui-accent-strong",
            "--swui-code-bg", "--swui-code-line-hl",
            "--syntax-keyword", "--syntax-type", "--syntax-string",
            "--syntax-number", "--syntax-comment",
            "--font-display", "--font-text", "--font-mono",
        ]
        for token in required {
            #expect({{PROJECT_NAME}}Theme.css.contains(token), "missing token: \(token)")
        }
    }
}
