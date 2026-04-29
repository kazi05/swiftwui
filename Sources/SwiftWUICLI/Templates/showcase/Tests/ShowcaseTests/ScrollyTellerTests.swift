import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

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
}
