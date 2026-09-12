import Observation
import Testing
@testable import SwiftWUI

@Observable private final class SwitchingObservationModel {
    var primary = "primary"
    var secondary = "secondary"
}

@MainActor private final class ObservationRenderTally {
    nonisolated deinit { }
    var bodies = 0
}

private struct SwitchingObservationReader: Tag {
    let model: SwitchingObservationModel
    let tally: ObservationRenderTally
    @State var readsPrimary = true

    var body: some Tag {
        tally.bodies += 1
        let value = readsPrimary ? model.primary : model.secondary
        return Div {
            Text(value)
            Button("switch") { readsPrimary.toggle() }
        }
    }
}

private struct ObservedConditionalLeaf: Tag {
    let model: SwitchingObservationModel
    let tally: ObservationRenderTally

    var body: some Tag {
        tally.bodies += 1
        return Text(model.primary)
    }
}

private struct ConditionalObservationHost: Tag {
    let model: SwitchingObservationModel
    let tally: ObservationRenderTally
    @State var showsLeaf = true

    var body: some Tag {
        Div {
            if showsLeaf { ObservedConditionalLeaf(model: model, tally: tally) }
            Button("toggle") { showsLeaf.toggle() }
        }
    }
}

@MainActor private final class ObservationJobQueue {
    nonisolated deinit { }
    private(set) var jobs: [() -> Void] = []

    func schedule(_ job: @escaping () -> Void) { jobs.append(job) }
    func drain() {
        while !jobs.isEmpty { jobs.removeFirst()() }
    }
}

@Suite @MainActor struct ObservationSubscriptionLifecycleTests {
    @Test func propertyNoLongerReadDoesNotScheduleRender() {
        let model = SwitchingObservationModel()
        let tally = ObservationRenderTally()
        let backend = MockBackend()
        let queue = ObservationJobQueue()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SwitchingObservationReader(model: model, tally: tally),
                              scheduleMicrotask: queue.schedule)
        runtime.mount()

        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        queue.drain()
        #expect(tally.bodies == 2)
        #expect(backend.serializeHTML().contains("secondary"))

        model.primary = "stale"

        #expect(queue.jobs.isEmpty,
                "a callback from the previous render must not invalidate a component that no longer reads this property")
        queue.drain()
        #expect(tally.bodies == 2)
    }

    @Test func removedComponentObservationDoesNotScheduleRender() {
        let model = SwitchingObservationModel()
        let tally = ObservationRenderTally()
        let backend = MockBackend()
        let queue = ObservationJobQueue()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ConditionalObservationHost(model: model, tally: tally),
                              scheduleMicrotask: queue.schedule)
        runtime.mount()
        #expect(tally.bodies == 1)

        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        queue.drain()
        #expect(tally.bodies == 1)

        model.primary = "stale"

        #expect(queue.jobs.isEmpty,
                "an unmounted component's retained Observation callback must not schedule work")
        queue.drain()
        #expect(tally.bodies == 1)
    }

    @Test func currentPropertyStillSchedulesAfterGenerationChanges() {
        let model = SwitchingObservationModel()
        let tally = ObservationRenderTally()
        let backend = MockBackend()
        let queue = ObservationJobQueue()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SwitchingObservationReader(model: model, tally: tally),
                              scheduleMicrotask: queue.schedule)
        runtime.mount()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        queue.drain()

        model.secondary = "current"

        #expect(!queue.jobs.isEmpty)
        queue.drain()
        #expect(tally.bodies == 3)
        #expect(backend.serializeHTML().contains("current"))
    }

    @Test func remountedIdentityGetsFreshObservationGeneration() {
        let model = SwitchingObservationModel()
        let tally = ObservationRenderTally()
        let backend = MockBackend()
        let queue = ObservationJobQueue()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: ConditionalObservationHost(model: model, tally: tally),
                              scheduleMicrotask: queue.schedule)
        runtime.mount()

        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        queue.drain()
        runtime.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        queue.drain()
        #expect(tally.bodies == 2)

        model.primary = "remounted"

        #expect(!queue.jobs.isEmpty)
        queue.drain()
        #expect(tally.bodies == 3)
        #expect(backend.serializeHTML().contains("remounted"))
    }

    @Test func primitiveRootForEachKeepsOnlyCurrentGenerationActive() {
        let model = SwitchingObservationModel()
        let store = StateStore()
        var invalidations = 0
        let root = ForEach([0], id: \.self) { _ in Text(model.primary) }

        var first = ResolveContext(store: store, listeners: ListenerRegistry(),
                                   invalidate: { _ in invalidations += 1 })
        _ = resolve(root, path: .root, ctx: &first)
        var second = ResolveContext(store: store, listeners: ListenerRegistry(),
                                    invalidate: { _ in invalidations += 1 })
        _ = resolve(root, path: .root, ctx: &second)

        model.primary = "next"

        #expect(invalidations == 1)
    }
}
