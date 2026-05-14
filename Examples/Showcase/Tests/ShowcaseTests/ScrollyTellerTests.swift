import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("ScrollyTeller")
struct ScrollyTellerTests {
    @Test func rendersAllStepsAndStickyPane() {
        let steps = (1...3).map { n in
            ScrollyTeller.Step(
                number: n,
                title: "Step \(n)",
                prose: "Prose \(n)",
                code: "code \(n)",
                preview: AnyTag(Div { Text("preview \(n)") })
            )
        }
        let html = StaticRenderer().renderFragment(ScrollyTeller(steps: steps))
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"3\""))
        #expect(html.contains("data-swui-scrolly-sticky"))
        #expect(html.contains("data-swui-scrolly"))
    }

    @Test("Code panel emits data-line attributes per source line")
    func dataLineAttrs() {
        let step = ScrollyTeller.Step(
            number: 1, title: "t", prose: "p",
            code: "let x = 1\nlet y = 2", highlightLines: [2],
            preview: AnyTag(Text("ok"))
        )
        let html = StaticRenderer().renderFragment(ScrollyTeller(steps: [step]))
        #expect(html.contains("data-line=\"1\""))
        #expect(html.contains("data-line=\"2\""))
    }

    @Test("Highlight lines apply data-line-hl marker")
    func highlightApplied() {
        let step = ScrollyTeller.Step(
            number: 1, title: "t", prose: "p",
            code: "a\nb\nc", highlightLines: [2],
            preview: AnyTag(Text("ok"))
        )
        let html = StaticRenderer().renderFragment(ScrollyTeller(steps: [step]))
        #expect(html.contains("data-line-hl=\"2\""))
    }
}
