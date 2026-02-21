// StateObserver.swift - Observation integration for re-rendering

import Observation

/// Continuously observes `@Observable` state accessed inside `apply` and calls
/// `onChange` whenever any tracked property mutates.
///
/// This is a minimal replacement for swift-navigation's `observe()`, built
/// directly on Swift's `Observation` framework (`withObservationTracking`).
///
/// Usage:
/// ```swift
/// let cancel = observe {
///     let _ = model.count  // track access
/// } onChange: {
///     // re-render
/// }
/// ```
///
/// - Parameters:
///   - apply: Closure whose property accesses are tracked. Called once immediately
///     and again after each change notification to re-register tracking.
///   - onChange: Called when any observed property changes.
/// - Returns: A `StateObservation` handle. Call `cancel()` to stop observing.
@discardableResult
public func observe(
    _ apply: @escaping @Sendable () -> Void,
    onChange: @escaping @Sendable () -> Void
) -> StateObservation {
    let observation = StateObservation()

    @Sendable func track() {
        guard !observation.isCancelled else { return }
        withObservationTracking {
            apply()
        } onChange: {
            guard !observation.isCancelled else { return }
            onChange()
            track()
        }
    }

    track()
    return observation
}

/// Handle for cancelling an active observation created by `observe()`.
public final class StateObservation: @unchecked Sendable {
    private(set) var isCancelled = false

    public init() {}

    /// Stop observing. No further `onChange` callbacks will fire.
    public func cancel() {
        isCancelled = true
    }
}
