import Testing
@testable import SwiftWUI

/// Router asserts `ctx.routerCount == 1` (spec D9) — debug-only, so verifying
/// the trap needs a genuine process exit, not a Swift `assert` catch.
@Suite struct ExitTests {
    @Test func twoRoutersTrapInDebug() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                struct TwoRouters: Tag {
                    var body: some Tag {
                        Router { Route("/") { P { "a" } } }
                        Router { Route("/") { P { "b" } } }
                    }
                }
                let backend = MockBackend()
                let runtime = Runtime(backend: backend, container: backend.container,
                                      root: TwoRouters(), scheduleMicrotask: { $0() })
                runtime.mount()   // ctx.routerCount == 2 → assert (Router.swift)
            }
        }
    }
}
