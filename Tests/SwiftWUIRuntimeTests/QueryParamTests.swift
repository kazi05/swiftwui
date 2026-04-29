import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRouter

@Suite("Query parameters", .serialized)
struct QueryParamTests {
    @Test("Router parses ?key=value into currentSearchParams")
    func basicParse() {
        let router = Router(initialPath: "/posts?page=2&sort=date") {
            Route("/posts") { Text("posts") }
        }
        #expect(router.currentPath == "/posts")
        #expect(router.currentSearchParams["page"] == "2")
        #expect(router.currentSearchParams["sort"] == "date")
    }

    @Test("Router percent-decodes both keys and values")
    func percentDecoding() {
        let router = Router(initialPath: "/?q=hello%20world&full+name=Jane%20Doe") {
            Route("/") { Text("home") }
        }
        #expect(router.currentSearchParams["q"] == "hello world")
        #expect(router.currentSearchParams["full name"] == "Jane Doe")
    }

    @Test("navigate(to:) updates both path and search params")
    func navigateUpdatesBoth() {
        let router = Router { Route("/") { Text("h") } }
        router.navigate(to: "/users?id=42")
        #expect(router.currentPath == "/users")
        #expect(router.currentSearchParams["id"] == "42")
    }

    @Test("@QueryParam returns the parsed value when the key is present")
    func queryParamReadsRouter() {
        let router = Router(initialPath: "/?page=7") {
            Route("/") { Text("h") }
        }
        QueryParamContext.router = router
        struct Reader { @QueryParam("page", default: 1) var page: Int }
        let reader = Reader()
        #expect(reader.page == 7)
    }

    @Test("@QueryParam falls back to its default when the key is absent")
    func queryParamFallback() {
        let router = Router(initialPath: "/") { Route("/") { Text("h") } }
        QueryParamContext.router = router
        struct Reader { @QueryParam("page", default: 1) var page: Int }
        let reader = Reader()
        #expect(reader.page == 1)
    }

    @Test("@QueryParam<String> uses empty-string default via the convenience init")
    func queryParamStringDefault() {
        let router = Router(initialPath: "/") { Route("/") { Text("h") } }
        QueryParamContext.router = router
        struct Reader { @QueryParam("q") var query: String }
        let reader = Reader()
        #expect(reader.query == "")
    }
}
