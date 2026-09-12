#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Observation

public enum WebResourceError: Error { case readOnly }

/// A successful GET response suitable for explicit snapshot transfer.
public struct WebResourceValue: Codable, Sendable, Equatable {
    public var data: _FoundationData
    public var status: Int
    public var headers: [String: String]
    public init(data: _FoundationData, status: Int, headers: [String: String] = [:]) {
        self.data = data; self.status = status; self.headers = headers
    }
}

public struct WebResourceSeed: Codable, Sendable {
    public let url: String
    public let value: WebResourceValue
    public let expiresAt: Double
    public init(url: String, value: WebResourceValue, expiresAt: Double) {
        self.url = url; self.value = value; self.expiresAt = expiresAt
    }
}

/// Per-session read cache. Consumers own their wait, the last cancellation aborts
/// the transport. Mutations continue to use WebSession and explicit invalidation.
@MainActor public final class WebResourceCache {
    nonisolated deinit { }
    private struct Key: Hashable {
        let url: String
        let headers: [String]
        let timeout: Duration?
        init(_ request: WebRequest) {
            url = request.url
            timeout = request.timeout
            // Preserve header spelling/value to avoid incorrectly sharing requests
            // with duplicated, differently cased header names.
            headers = request.headers.sorted { $0.key < $1.key }.flatMap { [$0.key, $0.value] }
        }
    }
    private struct Entry { let value: WebResourceValue; let expiresAt: Double }
    private struct Flight {
        let generation: UInt64
        var waiters: [UInt64: CheckedContinuation<WebResourceValue, any Error>]
        let task: Task<Void, Never>
    }
    private let session: WebSession
    private let now: () -> Double
    private let capacity: Int
    private var entries: [Key: Entry] = [:]
    private var flights: [Key: Flight] = [:]
    private var sequence: UInt64 = 0

    public init(session: WebSession, capacity: Int = 128,
                now: @escaping () -> Double = { Date().timeIntervalSince1970 }) {
        self.session = session; self.now = now; self.capacity = max(0, capacity)
    }

    public func data(from url: String, ttl: Double = 30) async throws -> WebResourceValue {
        try await data(for: WebRequest(url: url), ttl: ttl)
    }

    public func data(for request: WebRequest, ttl: Double = 30) async throws -> WebResourceValue {
        guard request.method == .get, request.body == nil else { throw WebResourceError.readOnly }
        try WebSession.validate(request)
        try Task.checkCancellation()
        let key = Key(request)
        if let entry = entries[key], entry.expiresAt > now() { return entry.value }
        entries[key] = nil
        sequence &+= 1
        let waiter = sequence
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                if flights[key] != nil {
                    flights[key]!.waiters[waiter] = continuation
                    return
                }
                let generation = waiter
                let task = Task { [weak self, session] in
                    let result: Result<WebResourceValue, any Error>
                    do {
                        let (data, response) = try await session.data(for: request)
                        try Task.checkCancellation()
                        guard response.isSuccess else { throw WebFetchError.httpStatus(response.status, data) }
                        result = .success(WebResourceValue(data: data, status: response.status, headers: response.headers))
                    } catch { result = .failure(error) }
                    self?.complete(key, generation: generation, result: result, ttl: ttl)
                }
                flights[key] = Flight(generation: generation, waiters: [waiter: continuation], task: task)
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(key, waiter: waiter) }
        }
    }

    public func json<Value: Decodable>(from url: String, ttl: Double = 30, as: Value.Type = Value.self) async throws -> Value {
        let response = try await data(from: url, ttl: ttl)
        do { return try JSONDecoder().decode(Value.self, from: response.data) }
        catch { throw WebFetchError.decoding(String(describing: error)) }
    }

    public func invalidate(url: String) {
        for key in entries.keys.filter({ $0.url == url }) { entries[key] = nil }
        for key in flights.keys.filter({ $0.url == url }) { cancelFlight(key) }
    }
    public func removeAll() {
        entries.removeAll()
        for key in Array(flights.keys) { cancelFlight(key) }
    }

    /// Export only headerless entries. This operation is explicit: never embed a
    /// cache containing user data in public HTML without choosing its contents.
    public func snapshot() -> [WebResourceSeed] {
        entries.compactMap { key, entry in
            guard key.headers.isEmpty, key.timeout == nil, entry.expiresAt > now() else { return nil }
            return WebResourceSeed(url: key.url, value: entry.value, expiresAt: entry.expiresAt)
        }.sorted { $0.url < $1.url }
    }
    public func seed(url: String, value: WebResourceValue, ttl: Double) {
        seed([WebResourceSeed(url: url, value: value, expiresAt: now() + max(0, ttl))])
    }
    public func seed(_ seeds: [WebResourceSeed]) {
        for seed in seeds where seed.expiresAt > now() && (200..<300).contains(seed.value.status) {
            let key = Key(WebRequest(url: seed.url))
            guard flights[key] == nil else { continue }
            insert(Entry(value: seed.value, expiresAt: seed.expiresAt), for: key)
        }
    }
    private func complete(_ key: Key, generation: UInt64, result: Result<WebResourceValue, any Error>, ttl: Double) {
        guard let flight = flights[key], flight.generation == generation else { return }
        flights[key] = nil
        if case .success(let value) = result, ttl > 0 {
            insert(Entry(value: value, expiresAt: now() + ttl), for: key)
        }
        for waiter in flight.waiters.values { waiter.resume(with: result) }
    }
    private func cancel(_ key: Key, waiter: UInt64) {
        guard let continuation = flights[key]?.waiters.removeValue(forKey: waiter) else { return }
        continuation.resume(throwing: CancellationError())
        if flights[key]?.waiters.isEmpty == true { cancelFlight(key) }
    }
    private func insert(_ entry: Entry, for key: Key) {
        guard capacity > 0 else { return }
        let control = entry.value.headers.first { $0.key.lowercased() == "cache-control" }?.value.lowercased() ?? ""
        let directives = control.split(separator: ",").map {
            String($0.drop(while: { $0 == " " || $0 == "\t" }).reversed()
                .drop(while: { $0 == " " || $0 == "\t" }).reversed())
        }
        guard !directives.contains("no-store"), !directives.contains("no-cache") else { return }
        entries = entries.filter { $0.value.expiresAt > now() }
        if entries[key] == nil, entries.count >= capacity,
           let oldest = entries.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key { entries[oldest] = nil }
        entries[key] = entry
    }
    private func cancelFlight(_ key: Key) {
        guard let flight = flights.removeValue(forKey: key) else { return }
        flight.task.cancel()
        for waiter in flight.waiters.values { waiter.resume(throwing: CancellationError()) }
    }
}

public enum AsyncResourceState<Value> {
    case idle, pending, success(Value), failure(String)
    public var isPending: Bool { if case .pending = self { true } else { false } }
}

/// Observable, retryable state for route loaders and async UI. Call load() from
/// `.task` so teardown cancels that consumer's operation automatically.
@Observable @MainActor public final class AsyncResource<Value: Sendable> {
    nonisolated deinit { }
    public private(set) var state: AsyncResourceState<Value> = .idle
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private let loader: @MainActor () async throws -> Value
    public init(loader: @escaping @MainActor () async throws -> Value) { self.loader = loader }
    public func load() async {
        generation &+= 1; let current = generation
        state = .pending
        do {
            let value = try await loader()
            try Task.checkCancellation()
            guard current == generation else { return }
            state = .success(value)
        } catch {
            guard current == generation else { return }
            state = Task.isCancelled || error is CancellationError ? .idle : .failure(String(describing: error))
        }
    }
    public func reset() { generation &+= 1; state = .idle }
}

/// Rendering boundary with application-owned pending/error/retry presentation.
public struct AsyncBoundary<Value: Sendable, Content: Tag>: Tag {
    public let resource: AsyncResource<Value>
    private let content: (AsyncResourceState<Value>) -> Content
    public init(_ resource: AsyncResource<Value>, @TagBuilder content: @escaping (AsyncResourceState<Value>) -> Content) {
        self.resource = resource; self.content = content
    }
    public var body: some Tag { content(resource.state).task { await resource.load() } }
}
