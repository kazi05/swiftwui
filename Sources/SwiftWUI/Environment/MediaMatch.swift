import Observation

/// Reactive media-query matching, one per Runtime. Read `matches(_:)` inside a
/// component `body`; a condition flip re-renders exactly the readers.
@MainActor @Observable
public final class MediaMatchStore {
    nonisolated deinit { }
    // Baseline captured at registration. NON-observed: it is written during the
    // body eval that first reads a new query, and must not invalidate that read.
    @ObservationIgnored private var registered: [String: Bool] = [:]
    // Live overrides pushed by the backend change listener (fires OUTSIDE eval).
    // Observed → a write invalidates the components that read it.
    private var changes: [String: Bool] = [:]
    @ObservationIgnored private let observe: (String, @escaping (Bool) -> Void) -> Bool

    public init(observe: @escaping (String, @escaping (Bool) -> Void) -> Bool) {
        self.observe = observe
    }

    func matches(_ condition: String) -> Bool {
        let live = changes[condition]                 // TRACKED read → records dependency
        if let live { return live }
        if let base = registered[condition] { return base }
        let initial = observe(condition) { [weak self] v in self?.update(condition, v) }
        registered[condition] = initial               // non-observed write — safe during eval
        return initial
        // ponytail: no sweep — one matchMedia listener per distinct condition,
        // bounded like StyleRegistry.
    }
    private func update(_ condition: String, _ v: Bool) {
        guard changes[condition] != v else { return }
        changes[condition] = v                        // observed write → re-render readers
        // ponytail: whole-store invalidation (one observed dict); split per-key only if measured.
    }
}

/// Lightweight `@Environment(\.media)` value. `nil` store outside a live runtime
/// (native/SSG) → `matches` returns the SSR default `false`.
public struct MediaProxy {
    let store: MediaMatchStore?
    public func matches(_ q: MediaQuery) -> Bool { store?.matches(q.condition) ?? false }
}
