import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import {{PROJECT_NAME}}

@Suite("BadgeGrid")
struct BadgeGridTests {
    @Test func rendersAllBadges() {
        let html = StaticRenderer().renderFragment(
            BadgeGrid(items: [
                .init(title: "Container Queries", description: "Component-level responsive styles"),
                .init(title: "Hot Reload", description: "Sub-second iteration"),
            ])
        )
        #expect(html.contains("Container Queries"))
        #expect(html.contains("Hot Reload"))
        #expect(html.contains("Sub-second"))
        #expect(html.contains("Component-level"))
    }
}
