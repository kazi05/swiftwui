import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

@Suite struct PrerenderResolutionTests {
    @Test func routeWinsOverApp() {
        let r = PrerenderResolution.effective(route: .never, app: .build, config: .build)
        #expect(r?.buildEnabled == false)
    }

    @Test func appWinsOverConfig() {
        let r = PrerenderResolution.effective(route: nil, app: .never, config: .build)
        #expect(r?.buildEnabled == false)
    }

    @Test func configUsedWhenRouteAndAppSayNothing() {
        let r = PrerenderResolution.effective(route: nil, app: nil, config: .onDemand)
        #expect(r?.onDemandEnabled == true)
    }

    @Test func nilEverywhereMeansPhase5Behaviour() {
        #expect(PrerenderResolution.effective(route: nil, app: nil, config: nil) == nil)
    }

    // Env grammar is FAIL-CLOSED: anything unrecognized disables prerendering,
    // because this switch exists to be reached for during an incident.
    @Test func envGrammarEnables() {
        for raw in ["1", "true", "TRUE", "on", "Yes", " yes "] {
            #expect(PrerenderSwitch.enabled(fromEnvironment: raw) == true, "\(raw)")
        }
    }

    @Test func envGrammarDisables() {
        for raw in ["0", "false", "off", "no", "garbage", ""] {
            #expect(PrerenderSwitch.enabled(fromEnvironment: raw) == false, "\(raw)")
        }
    }

    @Test func envUnsetKeepsPrerenderingOn() {
        #expect(PrerenderSwitch.enabled(fromEnvironment: nil) == true)
    }

    @Test func configDefaultsPreserveTodaysBehaviour() {
        let c = StaticSiteConfig(outDir: "dist", mode: .staticOnly)
        #expect(c.prerenderEnabled == true)
        #expect(c.synthesizeCanonical == true)
        #expect(c.siteURL == nil)
        #expect(c.defaultPrerender == nil)
    }
}
