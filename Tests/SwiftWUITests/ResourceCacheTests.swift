import Foundation
import Testing
@testable import SwiftWUI

@MainActor private final class ResourceTransport: FetchTransport {
    var calls = 0
    var pending: [CheckedContinuation<(Foundation.Data, WebResponse), any Error>] = []
    func perform(_ request: WebRequest) async throws -> (Foundation.Data, WebResponse) {
        calls += 1
        return try await withCheckedThrowingContinuation { pending.append($0) }
    }
    func finish(_ body: String = "42") {
        pending.removeFirst().resume(returning: (Foundation.Data(body.utf8), WebResponse(status: 200, headers: [:])))
    }
}

@Suite @MainActor struct ResourceCacheTests {
    @Test func boundedSeedsRespectExpirationAndNoStore() async throws {
        var time = 10.0
        let cache = WebResourceCache(session: .unsupported, capacity: 2, now: { time })
        let value = WebResourceValue(data: Foundation.Data("42".utf8), status: 200)
        cache.seed(url: "/short", value: value, ttl: 5)
        cache.seed(url: "/long", value: value, ttl: 20)
        cache.seed(url: "/new", value: value, ttl: 10)
        #expect(cache.snapshot().map(\.url) == ["/long", "/new"])
        cache.seed(url: "/private", value: .init(data: value.data, status: 200,
                   headers: ["Cache-Control": "public,\tNO-STORE "]), ttl: 30)
        #expect(cache.snapshot().count == 2)
        time = 21
        #expect(cache.snapshot().map(\.url) == ["/long"])
        let noCache = WebResourceCache(session: .unsupported, capacity: 0)
        noCache.seed(url: "/answer", value: value, ttl: 30)
        #expect(noCache.snapshot().isEmpty)
    }

    @Test func timeoutIsPartOfRequestIdentity() async throws {
        let transport = ResourceTransport()
        let cache = WebResourceCache(session: WebSession(transport: transport))
        var request = WebRequest(url: "/answer"); request.timeout = .seconds(10)
        let timed = Task { try await cache.data(for: request) }
        let plain = Task { try await cache.data(from: "/answer") }
        while transport.calls < 2 { await Task.yield() }
        transport.finish(); transport.finish()
        _ = try await timed.value; _ = try await plain.value
        #expect(transport.calls == 2)
        #expect(cache.snapshot().count == 1)
    }

    @Test func deduplicatesAndExpires() async throws {
        let transport = ResourceTransport()
        var time = 10.0
        let cache = WebResourceCache(session: WebSession(transport: transport), now: { time })
        let first = Task { try await cache.data(from: "/answer", ttl: 5) }
        let second = Task { try await cache.data(from: "/answer", ttl: 5) }
        while transport.calls == 0 { await Task.yield() }
        for _ in 0..<10 { await Task.yield() }
        #expect(transport.calls == 1)
        transport.finish()
        #expect(try await first.value.data == second.value.data)
        _ = try await cache.data(from: "/answer", ttl: 5)
        #expect(transport.calls == 1)
        time = 16
        let third = Task { try await cache.data(from: "/answer", ttl: 5) }
        while transport.calls < 2 { await Task.yield() }
        transport.finish("43")
        #expect(try await third.value.data == Foundation.Data("43".utf8))
    }

    @Test func cancellationDoesNotCancelOtherConsumers() async throws {
        let transport = ResourceTransport()
        let cache = WebResourceCache(session: WebSession(transport: transport))
        let first = Task { try await cache.data(from: "/answer") }
        let second = Task { try await cache.data(from: "/answer") }
        while transport.calls == 0 { await Task.yield() }
        for _ in 0..<10 { await Task.yield() }
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        transport.finish()
        #expect(try await second.value.status == 200)
        #expect(transport.calls == 1)
    }

    @Test func invalidationRejectsLateCompletion() async throws {
        let transport = ResourceTransport()
        let cache = WebResourceCache(session: WebSession(transport: transport))
        let old = Task { try await cache.data(from: "/answer") }
        while transport.calls == 0 { await Task.yield() }
        cache.invalidate(url: "/answer")
        await #expect(throws: CancellationError.self) { try await old.value }
        let fresh = Task { try await cache.data(from: "/answer") }
        while transport.calls < 2 { await Task.yield() }
        transport.finish("old")
        transport.finish("fresh")
        #expect(try await fresh.value.data == Foundation.Data("fresh".utf8))
        #expect(try await cache.data(from: "/answer").data == Foundation.Data("fresh".utf8))
    }

    @Test func snapshotIsExplicitAndSeedable() async throws {
        let source = WebResourceCache(session: .unsupported, now: { 10 })
        source.seed(url: "/answer", value: WebResourceValue(data: Foundation.Data("42".utf8), status: 200), ttl: 20)
        let snapshot = try JSONEncoder().encode(source.snapshot())
        let restored = WebResourceCache(session: .unsupported, now: { 11 })
        restored.seed(try JSONDecoder().decode([WebResourceSeed].self, from: snapshot))
        let value: Int = try await restored.json(from: "/answer")
        #expect(value == 42)
    }

    @Test func nonGETIsRejectedAndHeadersArePartOfIdentity() async throws {
        let cache = WebResourceCache(session: .unsupported)
        var post = WebRequest(url: "/answer"); post.method = .post
        await #expect(throws: WebResourceError.readOnly) { try await cache.data(for: post) }
        cache.seed(url: "/answer", value: WebResourceValue(data: Foundation.Data(), status: 200), ttl: 20)
        var privateRequest = WebRequest(url: "/answer"); privateRequest.headers["Authorization"] = "Bearer private"
        await #expect(throws: WebFetchError.unsupported) { try await cache.data(for: privateRequest) }
    }
}
