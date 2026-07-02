import Testing
import SwiftWUICore
import SwiftWUIState
@testable import SwiftWUIRuntime

/// `.onChange(of:)` keyed its previous-value storage by call site only, so two
/// instances of the same component shared one slot and fired spurious change
/// callbacks against each other's values. Scoping the key by structural path
/// fixes the collision.
@Suite("onChange instance identity")
struct OnChangeIdentityTests {

    // Collects (old,new) pairs the action observed, across all instances.
    final class Sink: @unchecked Sendable {
        var events: [String] = []
    }

    struct Row: SwiftWUICore.Tag {
        let flag: Bool
        let sink: Sink
        var body: some SwiftWUICore.Tag {
            Text("row")
                .onChange(of: flag) { old, new in
                    self.sink.events.append("\(old)->\(new)")
                }
        }
    }

    struct Two: SwiftWUICore.Tag {
        let sink: Sink
        var body: some SwiftWUICore.Tag {
            Row(flag: true, sink: sink)
            Row(flag: false, sink: sink)
        }
    }

    @Test("stable-valued sibling instances never fire onChange")
    func noSpuriousCrossInstanceFiring() {
        let sink = Sink()
        let r = TestRenderer()
        // Two renders; neither Row's flag ever changes, so no onChange should fire.
        r.render(Two(sink: sink))
        r.update(Two(sink: sink))
        r.update(Two(sink: sink))
        #expect(sink.events == [])
    }
}
