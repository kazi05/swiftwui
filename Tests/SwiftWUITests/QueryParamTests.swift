import Testing
@testable import SwiftWUI

private struct QProbe: Tag {
    @QueryParam("filter") var filter: String?
    @QueryParam("page") var page: Int?
    @Environment(\.navigate) var navigate
    var body: some Tag {
        Div {
            P { "f:\(filter ?? "-") p:\(page.map(String.init) ?? "-")" }
            Button("go") { navigate("/?filter=active&page=2") }
            Button("bad") { navigate("/?page=nope") }
        }
    }
}

@MainActor @Suite struct QueryParamTests {
    private func make(initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: QProbe(), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func absentIsNil() {
        let (_, backend, _) = make()
        #expect(backend.serializeHTML().contains("f:- p:-"))
    }
    @Test func typedReadAndRerenderOnQueryChange() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)
        #expect(backend.serializeHTML().contains("f:active p:2"))
    }
    @Test func parseFailureIsNil() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 1, sched: sched)
        #expect(backend.serializeHTML().contains("p:-"))
    }
    @Test func initialQueryVisible() {
        let (_, backend, _) = make(initialPath: "/?filter=done&page=9")
        #expect(backend.serializeHTML().contains("f:done p:9"))
    }
}
