import Testing
@testable import Showcase

@Suite("ShowcaseTheme")
struct ShowcaseThemeTests {
    @Test func light_definesAllRequiredTokens() {
        let tokens = ShowcaseTheme.light.tokens
        for key in ShowcaseTheme.requiredTokens {
            #expect(tokens[key] != nil, "missing light token: \(key)")
        }
    }

    @Test func dark_definesAllRequiredTokens() {
        let tokens = ShowcaseTheme.dark.tokens
        for key in ShowcaseTheme.requiredTokens {
            #expect(tokens[key] != nil, "missing dark token: \(key)")
        }
    }

    @Test func accent_isOrange() {
        #expect(ShowcaseTheme.light.tokens["swui-accent"] == "#ff9500")
        #expect(ShowcaseTheme.dark.tokens["swui-accent"]  == "#ff9f0a")
    }
}
