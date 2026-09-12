// Isolated SE-0506 probe. Requires matching Swift 6.4 host/compiler libraries.
// This file is deliberately not part of the supported SwiftWUI target graph.
import Observation

@Observable @MainActor final class CounterModel {
    var count = 0
}

@MainActor final class ProbeEvents {
    var values: [Int] = []
}

@main struct Swift64ObservationProbe {
    @MainActor static func main() async throws {
        let model = CounterModel()
        let events = ProbeEvents()
        // Continuous tracking has ONE closure: it reads dependencies initially
        // and after each coalesced event. The event is borrowed by this callback.
        let token = withContinuousObservationTracking(options: [.didSet]) { event in
            events.values.append(model.count)
            precondition(event.kind == .initial || event.kind == .didSet)
        }
        for _ in 0..<100 where events.values.isEmpty { await Task.yield() }
        precondition(events.values == [0], "Missing initial observation")
        model.count = 1
        for _ in 0..<100 where events.values.last != 1 { await Task.yield() }
        precondition(events.values == [0, 1], "Missing continuous didSet observation")
        token.cancel()
        model.count = 2
        try await Task.sleep(for: .milliseconds(20))
        precondition(events.values == [0, 1], "Cancelled observation still fired")
        print("SE-0506 initial, didSet, and cancellation passed")
    }
}
