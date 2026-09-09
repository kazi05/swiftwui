import Testing
@testable import SwiftWUI

@MainActor private final class ViewportJobs {
    nonisolated deinit { }
    var jobs: [() -> Void] = []
    func schedule(_ job: @escaping () -> Void) { jobs.append(job) }
    func first() { jobs.removeFirst()() }
    func last() { jobs.removeLast()() }
    func drain() { while !jobs.isEmpty { first() } }
}

@Suite @MainActor struct ViewportSubscriptionTests {
    @Test func activationWaitsForCommitAndAdoption() {
        let jobs = ViewportJobs()
        var starts = 0
        var values: [Bool] = []
        let hub = SnapshotSubscriptionHub<Bool>(begin: { _ in
            starts += 1; return true
        }, schedule: jobs.schedule)
        hub.deferUntilAdoption()
        hub.subscribe(id: .root, initial: true) { values.append($0) }
        jobs.drain()
        #expect(starts == 0)
        hub.commit(); jobs.drain()
        #expect(starts == 0 && values.isEmpty)
        hub.acceptAdoption()
        #expect(values.isEmpty)
        jobs.drain()
        #expect(starts == 1 && values == [true])
    }

    @Test func closureRefreshAndInitialFlagDoNotReplay() {
        let jobs = ViewportJobs()
        var sink: ((Bool) -> Void)?
        var old: [Bool] = []; var fresh: [Bool] = []
        let hub = SnapshotSubscriptionHub<Bool>(begin: { sink = $0; return true },
                                                 schedule: jobs.schedule)
        hub.subscribe(id: .root, initial: false) { old.append($0) }
        hub.commit(); jobs.drain()
        sink?(true); jobs.drain()
        #expect(old.isEmpty)
        hub.subscribe(id: .root, initial: true) { fresh.append($0) }
        hub.commit(); jobs.drain()
        #expect(fresh.isEmpty)
        sink?(false); sink?(false); jobs.drain()
        #expect(old.isEmpty && fresh == [false])
    }

    @Test func newerEventCannotBeOverwrittenByQueuedInitial() {
        let jobs = ViewportJobs()
        var sink: ((Bool) -> Void)?
        var values: [Bool] = []
        let hub = SnapshotSubscriptionHub<Bool>(begin: { sink = $0; return true },
                                                 schedule: jobs.schedule)
        hub.subscribe(id: .root, initial: true) { values.append($0) }
        hub.commit(); jobs.first() // source activated; initial is queued
        sink?(false)
        jobs.last(); jobs.drain() // deliberately deliver newer event first
        #expect(values == [false])
    }

    @Test func remountAndCancellationInvalidateQueuedJobs() {
        let jobs = ViewportJobs()
        var sink: ((Bool) -> Void)?
        var values: [Bool] = []
        var starts = 0
        let hub = SnapshotSubscriptionHub<Bool>(begin: {
            starts += 1; sink = $0; return true
        }, schedule: jobs.schedule)
        hub.subscribe(id: .root, initial: true) { values.append($0) }
        hub.commit(); jobs.first()
        hub.unsubscribe(id: .root)
        sink?(false) // source stays current with zero subscribers
        hub.subscribe(id: .root, initial: true) { values.append($0) }
        hub.commit(); jobs.drain()
        #expect(starts == 1 && values == [false])
        sink?(true); hub.cancelAll(); jobs.drain()
        #expect(values == [false])
    }

    @Test func synchronousInstallationEventWinsOverReturnedSnapshot() {
        let jobs = ViewportJobs()
        var values: [Bool] = []
        let hub = SnapshotSubscriptionHub<Bool>(begin: { sink in
            sink(false); return true
        }, schedule: jobs.schedule)
        hub.subscribe(id: .root, initial: true) { values.append($0) }
        hub.commit(); jobs.drain()
        #expect(values == [false])
    }

    @Test func unsupportedSourceDoesNotFabricateSnapshot() {
        let jobs = ViewportJobs()
        var calls = 0
        let hub = SnapshotSubscriptionHub<Bool>(begin: { _ in nil }, schedule: jobs.schedule)
        hub.subscribe(id: .root, initial: true) { _ in calls += 1 }
        hub.commit(); jobs.drain()
        #expect(calls == 0)
    }

    @Test func deduplicatedNewerDeliveryStillInvalidatesOlderValue() {
        let jobs = ViewportJobs()
        var sink: ((Bool) -> Void)?
        var values: [Bool] = []
        let hub = SnapshotSubscriptionHub<Bool>(begin: { sink = $0; return true },
                                                 schedule: jobs.schedule)
        hub.subscribe(id: .root, initial: true) { values.append($0) }
        hub.commit(); jobs.drain()
        sink?(false); sink?(true)
        jobs.last(); jobs.drain()
        #expect(values == [true])
    }

    @Test func reorderedInitialFalseBaselineSuppressesEqualValue() {
        let jobs = ViewportJobs()
        var sink: ((Bool) -> Void)?
        var values: [Bool] = []
        let hub = SnapshotSubscriptionHub<Bool>(begin: { sink = $0; return true },
                                                 schedule: jobs.schedule)
        hub.subscribe(id: .root, initial: false) { values.append($0) }
        hub.commit(); jobs.drain()
        sink?(false); sink?(true)
        jobs.last(); jobs.drain()
        #expect(values.isEmpty)
    }
}
