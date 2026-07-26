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
