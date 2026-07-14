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
