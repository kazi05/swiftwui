import Testing
@testable import {{PROJECT_NAME}}

@Suite("{{PROJECT_NAME}}Theme")
struct {{PROJECT_NAME}}ThemeTests {
    @Test func light_definesAllRequiredTokens() {
        let tokens = {{PROJECT_NAME}}Theme.light.tokens
        for key in {{PROJECT_NAME}}Theme.requiredTokens {
            #expect(tokens[key] != nil, "missing light token: \(key)")
        }
    }

    @Test func dark_definesAllRequiredTokens() {
        let tokens = {{PROJECT_NAME}}Theme.dark.tokens
        for key in {{PROJECT_NAME}}Theme.requiredTokens {
            #expect(tokens[key] != nil, "missing dark token: \(key)")
        }
    }

    @Test func accent_isOrange() {
        #expect({{PROJECT_NAME}}Theme.light.tokens["swui-accent"] == "#ff9500")
        #expect({{PROJECT_NAME}}Theme.dark.tokens["swui-accent"]  == "#ff9f0a")
    }
}
