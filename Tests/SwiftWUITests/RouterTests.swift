import Testing
@testable import SwiftWUI

private struct RCounterPage: Tag {
    let label: String
    @State var n = 0
    var body: some Tag {
        Div {
            P { "\(label):\(n)" }
            Button("inc") { n += 1 }
        }
    }
}
private struct RNav: Tag {
    @Environment(\.navigate) var navigate
    var body: some Tag {
        Div(class: "nav") {
            Button("home") { navigate("/") }
            Button("detail1") { navigate("/todo/1") }
            Button("detail2") { navigate("/todo/2") }
            Button("boom") { navigate("/definitely-missing") }
        }
    }
}
private struct RApp: Tag {
    var body: some Tag {
        Div {
            RNav()
            Router(notFound: { P { "404" } }) {
                Route("/") { RCounterPage(label: "home") }
                Route("/todo/:id") { params in RCounterPage(label: "todo-\(params["id"] ?? "?")") }
                Route("/todo/special") { RCounterPage(label: "never") }   // shadowed: declaration order
                Route("/docs/*") { params in P { "docs:\(params["*"] ?? "")" } }
            }
        }
    }
}

@MainActor @Suite struct RouterTests {
    private func make(initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: RApp(), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }
    /// Buttons: [home, detail1, detail2, boom, inc?] — nav block renders first.
    private func click(_ label: Int, _ rt: Runtime<MockBackend>,
                       _ b: MockBackend, _ s: TestScheduler) {
        clickFirst(b, rt, tag: "button", index: label, sched: s)
    }

    @Test func matchesInitialAndSwitchesRoutes() {
        let (rt, backend, sched) = make()
        #expect(backend.serializeHTML().contains("home:0"))
        click(1, rt, backend, sched)                       // → /todo/1
        #expect(backend.serializeHTML().contains("todo-1:0"))
        #expect(!backend.serializeHTML().contains("home:0"))
    }
    @Test func routeChangeResetsStateParamChangePreservesIt() {
        let (rt, backend, sched) = make(initialPath: "/todo/1")
        clickFirst(backend, rt, tag: "button", index: 4, sched: sched)   // inc on the page
        #expect(backend.serializeHTML().contains("todo-1:1"))
        click(2, rt, backend, sched)                       // → /todo/2: SAME pattern
        #expect(backend.serializeHTML().contains("todo-2:1"), "param change preserves @State (D2)")
        click(0, rt, backend, sched)                       // → /
        click(1, rt, backend, sched)                       // → /todo/1: was torn down at "/"
        #expect(backend.serializeHTML().contains("todo-1:0"), "route change resets @State")
    }
    @Test func declarationOrderWins() {
        let (_, backend, _) = make(initialPath: "/todo/special")
        #expect(backend.serializeHTML().contains("todo-special:0"))
        #expect(!backend.serializeHTML().contains("never"))
    }
    @Test func catchAllCapturesTail() {
        let (_, backend, _) = make(initialPath: "/docs/a/b")
        #expect(backend.serializeHTML().contains("docs:a/b"))
    }
    @Test func notFoundRenders() {
        let (rt, backend, sched) = make()
        click(3, rt, backend, sched)                       // → missing
        #expect(backend.serializeHTML().contains("404"))
    }
    @Test func emptyRouterWithoutNotFoundRendersNothing() {
        let backend = MockBackend(); let sched = TestScheduler()
        struct Bare: Tag { var body: some Tag { Router { Route("/only") { Text("x") } } } }
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Bare(), initialPath: "/other",
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(!backend.serializeHTML().contains("x"))
        _ = rt
    }
    @Test func collectRoutesReportsAllPatterns() {
        struct CollectApp: Tag {
            @State var n = 0
            var body: some Tag {
                Div {
                    P { "n:\(n)" }
                    Button("inc") { n += 1 }
                    Router {
                        Route("/") { Text("home") }
                        Route("/about") { Text("about") }
                        Route("/todo/:id") { _ in Text("todo") }
                    }
                }
            }
        }
        let backend = MockBackend()
        let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: CollectApp(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let patterns = rt._collectRoutes()
        #expect(patterns.map(\.raw) == ["/", "/about", "/todo/:id"])
        #expect(patterns.map(\.isStatic) == [true, true, false])
        // Collection must not disturb live state (C1): a root @State write
        // after _collectRoutes() still schedules a flush and updates the DOM
        // (regression — link() used to rebind the live box's invalidate to
        // the collect pass's no-op closure, silently freezing the UI).
        clickFirst(backend, rt, tag: "button", sched: sched)
        #expect(backend.serializeHTML().contains("n:1"))
    }
}
