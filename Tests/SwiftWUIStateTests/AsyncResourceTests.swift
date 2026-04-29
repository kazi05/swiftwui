import Testing
@testable import SwiftWUIState

@Suite("AsyncResource")
struct AsyncResourceTests {
    @Test("starts in .idle")
    func startsIdle() {
        let r = AsyncResource<Int>()
        if case .idle = r.phase { /* ok */ } else {
            Issue.record("expected .idle, got \(r.phase)")
        }
        #expect(!r.isLoading)
        #expect(r.value == nil)
        #expect(r.error == nil)
    }

    @Test("init(value:) starts in .success")
    func initWithValue() {
        let r = AsyncResource<Int>(42)
        #expect(r.value == 42)
    }

    @Test("load() completes with success and exposes value")
    func loadSuccess() async {
        let r = AsyncResource<Int>()
        r.load { 7 }
        // Yield until the spawned Task settles. A handful of yields
        // is enough — the operation has no awaitable suspensions.
        for _ in 0..<10 {
            if r.value != nil { break }
            await Task.yield()
        }
        #expect(r.value == 7)
        #expect(r.error == nil)
    }

    @Test("load() failure surfaces in .failure")
    func loadFailure() async {
        struct Boom: Error {}
        let r = AsyncResource<Int>()
        r.load { throw Boom() }
        for _ in 0..<10 {
            if r.error != nil { break }
            await Task.yield()
        }
        #expect(r.error != nil)
        #expect(r.value == nil)
    }

    @Test("subsequent load() cancels the in-flight task before starting the next one")
    func loadCancelsPrevious() async {
        let r = AsyncResource<Int>()
        // First load spins forever (until cancelled).
        r.load {
            while !Task.isCancelled { await Task.yield() }
            throw CancellationError()
        }
        // Second load completes immediately.
        r.load { 99 }
        for _ in 0..<20 {
            if r.value != nil { break }
            await Task.yield()
        }
        #expect(r.value == 99)
    }

    @Test("cancel() stops the in-flight task without crashing the resource")
    func cancelLeavesResourceUsable() async {
        let r = AsyncResource<Int>()
        r.load {
            while !Task.isCancelled { await Task.yield() }
            throw CancellationError()
        }
        r.cancel()
        for _ in 0..<10 { await Task.yield() }
        // After cancel, phase is either idle (if task observed cancellation
        // and returned early) or loading (if cancel beat the .idle write).
        // Either way the resource is reusable.
        r.load { 1 }
        for _ in 0..<10 {
            if r.value != nil { break }
            await Task.yield()
        }
        #expect(r.value == 1)
    }
}
