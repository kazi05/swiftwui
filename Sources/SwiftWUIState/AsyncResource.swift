// AsyncResource.swift - Observable async value with Suspense-style phases.

import Observation

/// Observable holder for an in-flight async operation. Drives Suspense-style
/// rendering via `AsyncBoundary` — components observe `phase` and pick the
/// appropriate subtree (loading, error, success) for each state.
///
/// ```swift
/// @State var user = AsyncResource<User>()
///
/// .task {
///     user.load { try await api.fetchUser(id) }
/// }
///
/// AsyncBoundary(resource: user) {
///     ProgressView()
/// } error: { error in
///     ErrorView(error: error)
/// } success: { user in
///     UserCard(user: user)
/// }
/// ```
///
/// Calling `load` while a previous task is in flight cancels the previous
/// task before kicking off the new one — this is the "Suspense semantic"
/// that lets users abandon a search query without race-y stale results.
@Observable
public final class AsyncResource<T>: @unchecked Sendable {
    /// The current state of the underlying async operation.
    public enum Phase {
        case idle
        case loading
        case success(T)
        case failure(any Error)
    }

    public private(set) var phase: Phase = .idle

    /// Currently in-flight task, if any. Stored so a follow-up `load` or
    /// `cancel` can interrupt it.
    @ObservationIgnored
    private var task: Task<Void, Never>?

    /// Generation counter incremented on every `load` / `cancel`. The
    /// closure inside each `Task` captures its own generation and only
    /// writes back to `phase` if the counter still matches when it
    /// finishes — otherwise a stale completion (e.g. from a previously
    /// cancelled task whose CancellationError catch landed late) would
    /// clobber a subsequent `.success`. Race-safe under WASM's single
    /// thread and under native test concurrency.
    @ObservationIgnored
    private var generation: UInt64 = 0

    public init() {}
    public init(_ value: T) { self.phase = .success(value) }

    /// Kick off (or restart) the underlying async operation. Cancels the
    /// previous task if one is still running. Errors land in
    /// `.failure(_:)`; `CancellationError` resets to `.idle` so a deliberate
    /// abort does not show an error UI.
    ///
    /// `T` and `operation` are marked `@Sendable`-compatible because the
    /// underlying `Task` may run on any executor under Swift 6 strict
    /// concurrency. WASM in practice is single-threaded, but the type
    /// system has no way to know that, so we honour the Sendable contract.
    public func load(
        _ operation: @escaping @Sendable () async throws -> T
    ) where T: Sendable {
        cancel()
        generation &+= 1
        let myGen = generation
        phase = .loading
        let assign: @Sendable (Phase) -> Void = { [weak self] p in
            // Drop stale completions from previously-cancelled tasks
            // whose terminal handler lost the race against a fresh
            // `load` call. Only the most recent generation may write.
            guard let self, self.generation == myGen else { return }
            self.phase = p
        }
        task = Task {
            do {
                let value = try await operation()
                guard !Task.isCancelled else { return }
                assign(.success(value))
            } catch is CancellationError {
                assign(.idle)
            } catch {
                guard !Task.isCancelled else { return }
                assign(.failure(error))
            }
        }
    }

    /// Cancel the in-flight task, if any. Leaves `phase` unchanged.
    /// Bumps the generation counter so any pending continuation from the
    /// cancelled task is dropped on arrival rather than overwriting later
    /// state.
    public func cancel() {
        task?.cancel()
        task = nil
        generation &+= 1
    }

    /// Convenience accessors so consumers don't have to spell out the
    /// switch over `Phase` for the common cases.
    public var isLoading: Bool {
        if case .loading = phase { return true } else { return false }
    }
    public var value: T? {
        if case .success(let v) = phase { return v } else { return nil }
    }
    public var error: (any Error)? {
        if case .failure(let e) = phase { return e } else { return nil }
    }

    deinit {
        task?.cancel()
    }
}
