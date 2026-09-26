import Testing
@testable import SwiftWUI

private struct PathProbe: Tag {
    @Environment(\.routeInfo) var info
    @Environment(\.navigate) var navigate
    @Environment(\.back) var back
    var body: some Tag {
        Div {
            P { "at:\(info.path) q:\(info.query["x"] ?? "-")" }
            Button("go") { navigate("/next?x=1") }
            Button("replace") { navigate("/swap", replace: true) }
            Button("back") { back() }
        }
    }
}

@MainActor @Suite struct NavigationTests {
    private func make(initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: PathProbe(), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func initialPathReachesEnvironment() {
        let (_, backend, _) = make(initialPath: "/a/b?x=7")
        #expect(backend.serializeHTML().contains("at:/a/b q:7"))
    }
    @Test func navigatePushesAndRerenders() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)   // "go"
        #expect(backend.historyStack == ["/next?x=1"])
        #expect(backend.serializeHTML().contains("at:/next q:1"))
    }
    @Test func replaceUsesReplaceState() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 1, sched: sched)   // "replace"
        #expect(backend.historyStack.isEmpty)
        #expect(backend.replacedStates == ["/swap"])
    }
    @Test func popStateChangesLocationWithoutPush() {
        let (rt, backend, sched) = make()
        rt.handlePopState(url: "/popped?x=9")
        sched.pump()
        #expect(backend.historyStack.isEmpty)
        #expect(backend.serializeHTML().contains("at:/popped q:9"))
    }
    /// Regression: browsers fire popstate for same-document fragment moves
    /// (`<a href="#faq">`); handling them as history navigations re-rendered
    /// the page, played a pop transition and reset the scroll position.
    @Test func fragmentOnlyPopStateIsLeftToTheBrowser() {
        let (rt, backend, sched) = make(initialPath: "/docs?x=2")
        rt.handlePopState(url: "/docs?x=2")                // location.hash changed only
        sched.pump()
        #expect(backend.navigationBegins.isEmpty)
        #expect(backend.serializeHTML().contains("at:/docs q:2"))
        rt.handlePopState(url: "/docs/?x=2")               // trailing slash is the same route
        sched.pump()
        #expect(backend.navigationBegins.isEmpty)
        rt.handlePopState(url: "/docs?x=3")                // a real history step still routes
        sched.pump()
        #expect(backend.navigationBegins == [true])
        #expect(backend.serializeHTML().contains("at:/docs q:3"))
    }
    @Test func sameLocationNavigationIsNoOp() {
        let (rt, backend, sched) = make(initialPath: "/here")
        rt.navigate(to: "/here")
        sched.pump()
        #expect(backend.historyStack.isEmpty)
    }
    @Test func backCallsBackend() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 2, sched: sched)   // "back"
        #expect(backend.backCount == 1)
    }
}
