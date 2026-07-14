import Testing
@testable import SwiftWUI

@Suite struct ResponsiveValueTests {
    @Test func baseOnlyEmitsNoMedia() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.padding(responsive(.px(16)))
        )
        #expect(css.contains("padding: 16px"))
        #expect(!css.contains("@media"))
    }
    @Test func overridesEmitNonOverlappingRanges() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.padding(responsive(.px(16), md: .px(32), lg: .px(48)))
        )
        // base
        #expect(css.contains("padding: 16px"))
        // md: [768, 1024) — bounded above so it can't beat lg by source order
        #expect(css.contains("(min-width: 768px) and (max-width: 1023"))
        #expect(css.contains("padding: 32px"))
        // lg: open-ended min-width
        #expect(css.contains("@media (min-width: 1024px) {"))
        #expect(css.contains("padding: 48px"))
    }
    @Test func displayResponsive() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.display(responsive(.block, md: .flex))
        )
        #expect(css.contains("display: block"))
        #expect(css.contains("display: flex"))
    }
}
