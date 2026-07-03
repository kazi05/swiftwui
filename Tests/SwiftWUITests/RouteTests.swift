import Testing
@testable import SwiftWUI

@MainActor @Suite struct RouteTests {
    @Test func builderShapes() {
        let flag = true
        @RouteBuilder func routes() -> [Route] {
            Route("/") { Text("home") }
            if flag { Route("/a") { Text("a") } }
            for p in ["/x", "/y"] { Route(p) { Text(p) } }
        }
        let r = routes()
        #expect(r.count == 4)
        #expect(r[0].pattern.raw == "/")
        #expect(r[3].pattern.raw == "/y")
    }
    @Test func paramClosureReceivesCaptures() {
        let route = Route("/t/:id") { params in Text(params["id"] ?? "-") }
        let tag = route.builder(["id": "7"])
        #expect((tag.base as? Text)?.content == "7")
    }
    @Test func guardStored() {
        let route = Route("/admin", guard: { .redirect("/login") }) { Text("admin") }
        guard case .redirect(let target)? = route.guardClosure?() else {
            Issue.record("expected redirect"); return
        }
        #expect(target == "/login")
    }
}
