import Testing
@testable import SwiftWUI

@Suite struct ContainerRegistryTests {
    @Test func containerAtRuleWraps() {
        let reg = StyleRegistry()
        _ = reg.registerAnonymous(pseudo: nil, media: nil,
                                  container: "sidebar (min-width: 400px)",
                                  declarations: [StyleDeclaration(property: "flex-direction", value: "row")])
        #expect(reg.text.hasPrefix("@container sidebar (min-width: 400px) { .swui-"))
        #expect(reg.text.contains("flex-direction: row"))
    }
    @Test func mediaPathUnchanged() {
        let reg = StyleRegistry()
        _ = reg.registerAnonymous(pseudo: nil, media: "(max-width: 600px)", container: nil,
                                  declarations: [StyleDeclaration(property: "display", value: "none")])
        #expect(reg.text.hasPrefix("@media (max-width: 600px) { .swui-"))
    }
}

@Suite struct ContainerModifierTests {
    @Test func containerModifierEmitsAtContainer() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.container(.minWidth(.px(400)), name: "sidebar") { $0.flexDirection(.row) }
        )
        #expect(css.hasPrefix("@container sidebar (min-width: 400px) { .swui-"))
        #expect(css.contains("flex-direction: row"))
    }
    @Test func unnamedContainer() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.container(.minWidth(.px(400))) { $0.display(.flex) }
        )
        #expect(css.hasPrefix("@container (min-width: 400px) { .swui-"))
    }
    @Test func containerTypeSetsDeclarations() {
        let (html, _) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.containerType(.inlineSize, name: "sidebar")
        )
        #expect(html.contains("container-type: inline-size"))
        #expect(html.contains("container-name: sidebar"))
    }
    @Test func ruleContainer() {
        struct Card: Tag, Styled {
            @RulesBuilder var styles: [Rule] {
                Rule(class: "card", container: .minWidth(.px(400)), containerName: "sidebar") {
                    $0.flexDirection(.row)
                }
            }
            var body: some Tag { Div(class: "card") { Text("x") } }
        }
        let (_, css) = HTMLRenderer.renderWithStylesheet(Card())
        #expect(css.contains("@container sidebar (min-width: 400px) { .card"))
    }
}
