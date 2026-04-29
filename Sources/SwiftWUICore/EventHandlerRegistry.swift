// EventHandlerRegistry.swift - Global registry for event handler closures

#if !arch(wasm32)
import Foundation
#endif

/// Global registry mapping EventListenerIDs to their closures.
///
/// When a Tag tree is converted to TagNodes, event handler closures are
/// stored here with IDs that are either UUID-based (anonymous) or derived
/// from a stable call-site identity. The DOMRenderer looks up closures by
/// ID when attaching event listeners to real DOM elements.
///
/// **Stable identity:** Use `register(_:identity:)` when the call site is
/// stable across re-renders (e.g., `.task`, `.onChange`, `.onClick` at a
/// fixed source location). The returned `EventListenerID` will be the same
/// for the same identity across renders, which lets `Reconciler.diffEvents`
/// and `diffObservers` recognise unchanged handlers and avoid redundant DOM
/// listener replacement and lifecycle re-firing.
///
/// **Anonymous identity:** Use `register(_:)` for handlers without a stable
/// source location (e.g., synthesised inside loops where `#filePath:#line`
/// would collide). Each call returns a fresh UUID-based ID, which causes
/// the reconciler to treat it as a new listener every render.
public enum EventHandlerRegistry {
    nonisolated(unsafe) private static var handlers: [String: @Sendable () -> Void] = [:]
    #if !arch(wasm32)
    private static let lock = NSLock()
    #endif

    /// Register a handler under a stable identity and return its EventListenerID.
    ///
    /// Calling this with the same `identity` always returns the same ID and
    /// replaces any previously stored handler at that identity. Identities
    /// should be derived from call-site information (`#filePath:#line:#column`)
    /// or a structural path so they remain stable across re-renders.
    public static func register(
        _ handler: @escaping @Sendable () -> Void,
        identity: String
    ) -> EventListenerID {
        #if arch(wasm32)
        handlers[identity] = handler
        #else
        lock.lock()
        handlers[identity] = handler
        lock.unlock()
        #endif
        return EventListenerID(identity)
    }

    /// Register a handler with a UUID-based anonymous identity.
    /// Prefer `register(_:identity:)` when the call site is fixed.
    public static func register(_ handler: @escaping @Sendable () -> Void) -> EventListenerID {
        let id = makeAnonymousID()
        #if arch(wasm32)
        handlers[id] = handler
        #else
        lock.lock()
        handlers[id] = handler
        lock.unlock()
        #endif
        return EventListenerID(id)
    }

    /// Look up a handler by its ID.
    public static func handler(for id: EventListenerID) -> (@Sendable () -> Void)? {
        #if arch(wasm32)
        return handlers[id.id]
        #else
        lock.lock()
        let result = handlers[id.id]
        lock.unlock()
        return result
        #endif
    }

    /// Clear all registered handlers. Use only at app teardown or test isolation;
    /// for per-render bookkeeping prefer `beginRender()` which preserves stable
    /// identity slots while resetting the anonymous counter.
    public static func clear() {
        #if arch(wasm32)
        handlers.removeAll()
        anonymousCounter = 0
        #else
        lock.lock()
        handlers.removeAll()
        anonymousCounter = 0
        lock.unlock()
        #endif
    }

    /// Mark the start of a render cycle.
    ///
    /// Resets the anonymous-ID counter so an identical Tag tree produces the
    /// same sequence of `EventListenerID`s on every render. Combined with
    /// fire-time handler lookup in `DOMRenderer`, this lets the reconciler
    /// recognise unchanged event listeners and skip redundant DOM work.
    ///
    /// Handlers registered under stable identities (`register(_:identity:)`)
    /// are not affected.
    public static func beginRender() {
        #if arch(wasm32)
        anonymousCounter = 0
        #else
        lock.lock()
        anonymousCounter = 0
        lock.unlock()
        #endif
    }

    // MARK: - Anonymous ID generation

    nonisolated(unsafe) private static var anonymousCounter: UInt64 = 0

    private static func makeAnonymousID() -> String {
        #if arch(wasm32)
        // Single-threaded WASM: monotonic counter is unique within a render
        // and cheap. `beginRender()` resets it so identical render sequences
        // produce identical IDs (essential for the reconciler's identity diff).
        anonymousCounter &+= 1
        return "anon-\(anonymousCounter)"
        #else
        // Native (test/SSR) hosts can run tests in parallel where two
        // threads racing through `register(_:)` would collide on the same
        // monotonic ID and overwrite each other in the shared dictionary.
        // UUID-based IDs sidestep that race entirely. The reconciler's
        // identity-diff optimisation only matters in WASM at runtime.
        return UUID().uuidString
        #endif
    }
}
