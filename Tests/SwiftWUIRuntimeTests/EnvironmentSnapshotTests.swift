import Testing
import SwiftWUICore
import SwiftWUIState
@testable import SwiftWUIRuntime

/// `@Environment` read the live task-local at access time, so a value read
/// inside an event handler or async closure — which runs *after* render, when
/// the `.environment(_:_:)` task-local scope has already popped — returned the
/// default instead of the value set by an ancestor. Snapshotting the
/// environment onto the wrapper at render time fixes it.
@Suite("@Environment snapshot")
struct EnvironmentSnapshotTests {

    struct ProbeKey: EnvironmentKey { static var defaultValue: Int { 0 } }

    final class Sink: @unchecked Sendable {
        var read: (() -> Int)?
    }

    struct Probe: SwiftWUICore.Tag {
        @Environment(\.probeValue) var value
        let sink: Sink
        var body: some SwiftWUICore.Tag {
            // Capture a closure that reads @Environment; it is invoked after
            // render returns, i.e. outside the environment's task-local scope.
            sink.read = { self.value }
            return Text("probe")
        }
    }

    struct Root: SwiftWUICore.Tag {
        let sink: Sink
        var body: some SwiftWUICore.Tag {
            Probe(sink: sink).environment(\.probeValue, 42)
        }
    }

    @Test("environment value read in a post-render closure sees the ancestor override")
    func snapshotSurvivesRender() {
        let sink = Sink()
        let r = TestRenderer()
        r.render(Root(sink: sink))
        #expect(sink.read?() == 42)
    }
}

extension EnvironmentValues {
    var probeValue: Int {
        get { self[EnvironmentSnapshotTests.ProbeKey.self] }
        set { self[EnvironmentSnapshotTests.ProbeKey.self] = newValue }
    }
}
