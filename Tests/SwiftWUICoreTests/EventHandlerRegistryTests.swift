import Testing
@testable import SwiftWUICore

@Suite("EventHandlerRegistry", .serialized)
struct EventHandlerRegistryTests {
    @Test("anonymous register returns sequential IDs")
    func anonymousRegisterMonotonic() {
        EventHandlerRegistry.clear()
        EventHandlerRegistry.beginRender()
        let id1 = EventHandlerRegistry.register { }
        let id2 = EventHandlerRegistry.register { }
        let id3 = EventHandlerRegistry.register { }
        #expect(id1 != id2)
        #expect(id2 != id3)
        #expect(id1 != id3)
    }

    /// Counter-reset semantics are only observable on WASM, where anonymous IDs
    /// are derived from a monotonic counter. On native test/SSR hosts anonymous
    /// IDs come from UUIDs to avoid cross-thread collisions when tests run in
    /// parallel, so an `id1 == id3` invariant cannot hold there. This test
    /// exercises the counter path on WASM only.
    #if arch(wasm32)
    @Test("beginRender resets anonymous counter so identical render sequences produce identical IDs")
    func beginRenderResetsCounter() {
        EventHandlerRegistry.clear()
        EventHandlerRegistry.beginRender()
        let id1 = EventHandlerRegistry.register { }
        let id2 = EventHandlerRegistry.register { }
        EventHandlerRegistry.beginRender()
        let id3 = EventHandlerRegistry.register { }
        let id4 = EventHandlerRegistry.register { }
        #expect(id1 == id3)
        #expect(id2 == id4)
    }
    #endif

    @Test("beginRender does not invalidate existing handlers")
    func beginRenderPreservesHandlers() {
        EventHandlerRegistry.clear()
        let id = EventHandlerRegistry.register({ }, identity: "stable")
        EventHandlerRegistry.beginRender()
        // After beginRender, the stable-identity handler must still be reachable.
        #expect(EventHandlerRegistry.handler(for: id) != nil)
    }

    @Test("identity-based register returns the identity verbatim")
    func identityRegisterIsStable() {
        EventHandlerRegistry.clear()
        let id1 = EventHandlerRegistry.register({ }, identity: "site-A")
        let id2 = EventHandlerRegistry.register({ }, identity: "site-A")
        let id3 = EventHandlerRegistry.register({ }, identity: "site-B")
        #expect(id1 == id2)
        #expect(id1 != id3)
    }

    /// The fire-time handler-resolution semantics rely on stable identities.
    /// Anonymous registrations on native use UUIDs and therefore do not exhibit
    /// slot-reuse, so this test uses an explicit identity to validate that a
    /// re-registration under the same identity is observed by lookups against
    /// the previously returned ID.
    @Test("identity register: handler lookup resolves to the most recent registration")
    func handlerLookupResolvesLatest() {
        EventHandlerRegistry.clear()
        final class Box: @unchecked Sendable { var n = 0 }
        let box = Box()
        let id1 = EventHandlerRegistry.register({ box.n = 1 }, identity: "slot")
        _ = EventHandlerRegistry.register({ box.n = 2 }, identity: "slot")
        guard let resolved = EventHandlerRegistry.handler(for: id1) else {
            Issue.record("handler not found at stable ID")
            return
        }
        resolved()
        #expect(box.n == 2)
    }

    @Test("identity register replaces handler in place without changing ID")
    func identityRegisterReplacesHandler() {
        // Use a unique identity per test rather than `clear()`-ing the global
        // registry. Other suites running in parallel may also call `clear()`
        // and would otherwise wipe our entry between registration and lookup.
        // A unique identity sidesteps that race entirely.
        final class Box: @unchecked Sendable { var n = 0 }
        let box = Box()
        let identity = "EventHandlerRegistryTests.identityRegisterReplacesHandler"
        let id1 = EventHandlerRegistry.register({ box.n = 10 }, identity: identity)
        let id2 = EventHandlerRegistry.register({ box.n = 20 }, identity: identity)
        #expect(id1 == id2)
        EventHandlerRegistry.handler(for: id1)?()
        #expect(box.n == 20)
    }
}
