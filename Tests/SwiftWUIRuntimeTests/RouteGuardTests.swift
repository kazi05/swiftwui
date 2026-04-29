import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRouter

@Suite("Route guards", .serialized)
struct RouteGuardTests {
    @Test("Route without a guard matches normally")
    func noGuardMatches() {
        let router = Router {
            Route("/home") { Text("home") }
        }
        #expect(router.matchedRoute(for: "/home") != nil)
        #expect(router.pendingRedirect(for: "/home") == nil)
    }

    @Test("Guard returning .allow lets the route match")
    func allowGuardMatches() {
        let router = Router {
            Route("/admin", guard: { .allow }) { Text("admin") }
        }
        #expect(router.matchedRoute(for: "/admin") != nil)
        #expect(router.pendingRedirect(for: "/admin") == nil)
    }

    @Test("Guard returning .redirect blocks the match and surfaces the redirect target")
    func redirectGuardBlocksMatch() {
        let router = Router {
            Route("/admin", guard: { .redirect("/login") }) { Text("admin") }
            Route("/login") { Text("login") }
        }
        #expect(router.matchedRoute(for: "/admin") == nil)
        #expect(router.pendingRedirect(for: "/admin") == "/login")
    }

    @Test("rawMatchedRoute ignores the guard")
    func rawMatchedRouteIgnoresGuard() {
        let router = Router {
            Route("/admin", guard: { .redirect("/login") }) { Text("admin") }
        }
        #expect(router.rawMatchedRoute(for: "/admin") != nil)
    }

    @Test("Guards observe app state at evaluation time")
    func guardSeesLiveState() {
        final class Auth: @unchecked Sendable { var isAdmin = false }
        let auth = Auth()
        let router = Router {
            Route("/admin", guard: {
                auth.isAdmin ? .allow : .redirect("/login")
            }) { Text("admin") }
        }
        #expect(router.matchedRoute(for: "/admin") == nil)
        auth.isAdmin = true
        #expect(router.matchedRoute(for: "/admin") != nil)
    }

    @Test("Guard with parameterised content init still receives params on match")
    func parameterisedContentWithGuard() {
        let router = Router(
            initialPath: "/users/42",
            routes: [
                Route("/users/:id", guard: { .allow }, content: { params in
                    AnyTag(Text("user \(params["id"] ?? "?")"))
                })
            ]
        )
        let tag = router.matchedTag(for: "/users/42")
        #expect(tag != nil)
    }
}
