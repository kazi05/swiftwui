import Testing
@testable import SwiftWUI

@Suite struct PrerenderPolicyTests {
    @Test func neverDisablesBothPaths() {
        let p = Prerender.never
        #expect(p.buildEnabled == false)
        #expect(p.onDemandEnabled == false)
        #expect(p.pathProvider == nil)
    }

    @Test func buildRendersAtBuildTimeOnly() {
        let p = Prerender.build
        #expect(p.buildEnabled == true)
        #expect(p.onDemandEnabled == false)
    }

    @Test func onDemandRendersOnRequestOnly() {
        let p = Prerender.onDemand
        #expect(p.buildEnabled == false)
        #expect(p.onDemandEnabled == true)
    }

    @Test func chainingComposesWithoutLosingFields() async throws {
        let p = Prerender.paths { ["/a", "/b"] }
            .allowingOnDemand()
            .revalidate(.hours(6))
        #expect(p.buildEnabled == true)
        #expect(p.onDemandEnabled == true)
        #expect(p.revalidateInterval == .seconds(6 * 3600))
        let provided = try await p.pathProvider!()
        #expect(provided == ["/a", "/b"])
    }

    @Test func allowingOnDemandFalseTurnsItBackOff() {
        let p = Prerender.onDemand.allowingOnDemand(false)
        #expect(p.onDemandEnabled == false)
    }

    @Test func durationSugarMatchesSeconds() {
        #expect(Duration.minutes(2) == .seconds(120))
        #expect(Duration.hours(1) == .seconds(3600))
    }
}

private struct PolicyApp: App {
    init() {}
    static var prerender: Prerender? { .never }
    var body: some Tag {
        Router {
            Route("/") { Text("home") }
            Route("/routes/:from/:to") { p in Text("\(p["from"] ?? "")-\(p["to"] ?? "")") }
                .prerender(.paths { ["/routes/mcx/mow"] }.allowingOnDemand())
            Route("/account") { Text("private") }.prerender(.never)
        }
    }
}

@Suite @MainActor struct PrerenderCollectionTests {
    @Test func collectRoutesCarriesPolicies() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: PolicyApp().body, scheduleMicrotask: { $0() })
        runtime.mount()
        let collected = runtime._collectRoutes()
        #expect(collected.count == 3)
        #expect(collected[0].pattern.raw == "/")
        #expect(collected[0].prerender == nil)                       // route said nothing
        #expect(collected[1].prerender?.onDemandEnabled == true)
        #expect(collected[2].prerender?.buildEnabled == false)       // .never
    }

    @Test func appDefaultIsReadable() {
        #expect(PolicyApp.prerender?.buildEnabled == false)
    }

    @Test func appDefaultIsNilWhenUndeclared() {
        #expect(UndeclaredApp.prerender == nil)
    }
}

private struct UndeclaredApp: App {
    init() {}
    var body: some Tag { Text("x") }
}
