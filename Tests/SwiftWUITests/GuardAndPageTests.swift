import Testing
@testable import SwiftWUI

private final class GateBox { var open = false }

private struct GHome: Tag, Page {
    var title: String { "Home — G" }
    var meta: [MetaTag] { [.description("home page")] }
    var body: some Tag { P { "ghome" } }
}
private struct GAdmin: Tag, Page {
    var title: String { "Admin — G" }
    var body: some Tag { P { "gadmin" } }
}
private struct GPlain: Tag {                       // NOT a Page
    var body: some Tag { P { "gplain" } }
}
private struct GNav: Tag {
    @Environment(\.navigate) var navigate
    var body: some Tag {
        Div {
            Button("admin") { navigate("/admin") }
            Button("plain") { navigate("/plain") }
            Button("home") { navigate("/") }
        }
    }
}
private struct GApp: Tag {
    let gate: GateBox
    var body: some Tag {
        Div {
            GNav()
            Router {
                Route("/") { GHome() }
                Route("/plain") { GPlain() }
                Route("/admin", guard: { [gate] in gate.open ? .allow : .redirect("/") }) { GAdmin() }
            }
        }
    }
}

private struct SelfRedirectApp: Tag {
    @State var n = 0
    var body: some Tag {
        Div {
            Button("tick") { n += 1 }
            P { "n:\(n)" }
            Router {
                Route("/loop", guard: { .redirect("/loop") }) { P { "never" } }
                Route("/") { P { "srhome" } }
            }
        }
    }
}

@MainActor @Suite struct GuardAndPageTests {
    private func make(gate: GateBox = GateBox(), initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: GApp(gate: gate), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func pageHeadAppliedAtMount() {
        let (_, backend, _) = make()
        #expect(backend.title == "Home — G")
        #expect(backend.metaTags == [.description("home page")])
    }
    @Test func headSwapsOnNavigationAndNonPageLeavesTitle() {
        let (rt, backend, sched) = make(gate: { let g = GateBox(); g.open = true; return g }())
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)   // → /admin (allowed)
        #expect(backend.title == "Admin — G")
        #expect(backend.metaTags.isEmpty)                                 // default meta replaces old set
        clickFirst(backend, rt, tag: "button", index: 1, sched: sched)   // → /plain (not a Page)
        #expect(backend.title == "Admin — G", "non-Page route leaves the title untouched")
    }
    @Test func headWriteDeduped() {
        let (rt, backend, sched) = make()
        let sets = backend.counts["setTitle", default: 0]
        clickFirst(backend, rt, tag: "button", index: 2, sched: sched)   // navigate to current → no-op
        rt.handlePopState(url: "/")                                       // re-render same page
        sched.pump()
        #expect(backend.counts["setTitle", default: 0] == sets, "unchanged head → no backend writes")
    }
    @Test func closedGuardRedirects() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)   // → /admin, guard closed
        sched.pump()                                                      // redirect flush
        #expect(backend.serializeHTML().contains("ghome"))
        #expect(!backend.serializeHTML().contains("gadmin"))
        #expect(backend.historyStack == ["/admin"], "the blocked push happened first")
        #expect(backend.replacedStates == ["/"], "redirect is replace, not push (spec §5)")
    }
    @Test func openGuardAllows() {
        let gate = GateBox(); gate.open = true
        let (rt, backend, sched) = make(gate: gate)
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)
        #expect(backend.serializeHTML().contains("gadmin"))
    }
    @Test func mountOnGuardedRouteRedirectsImmediately() {
        // `rt` must stay bound (not `_`): its post-mount redirect is a
        // scheduled microtask that captures the runtime only weakly, so
        // discarding the return value here frees it before sched.pump()
        // runs (same gotcha as RouterTests.emptyRouterWithoutNotFoundRendersNothing).
        let (rt, backend, sched) = make(initialPath: "/admin")
        sched.pump()
        #expect(backend.serializeHTML().contains("ghome"))
        #expect(backend.replacedStates == ["/"])
        _ = rt
    }

    /// Task-5 review follow-up: a guard that redirects to the CURRENT location
    /// must stay stable across many re-render passes — navigate() no-ops and
    /// resets the hop counter every time (Runtime.swift's self-redirect fix),
    /// so it never accumulates toward the 10-hop assertionFailure cap.
    @Test func selfRedirectHopCounterStaysStableAcrossManyPasses() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: SelfRedirectApp(), initialPath: "/loop",
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        sched.pump()
        for _ in 0..<12 {
            clickFirst(backend, rt, tag: "button", index: 0, sched: sched)   // "tick"
        }
        #expect(!backend.serializeHTML().contains("never"))
        #expect(backend.serializeHTML().contains("n:12"))
    }
}
