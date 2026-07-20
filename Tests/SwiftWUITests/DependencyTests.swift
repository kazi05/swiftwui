import Testing
@testable import SwiftWUI

// MARK: - Fixtures

private final class ProbeService {
    let name: String
    init(name: String) { self.name = name }
}

private struct ProbeKey: DependencyKey {
    static var liveValue: ProbeService { ProbeService(name: "live") }
    static var testValue: ProbeService { ProbeService(name: "test") }
}

private struct LiveOnlyKey: DependencyKey {
    static var liveValue: String { "live-only" }
}

extension DependencyValues {
    fileprivate var probe: ProbeService {
        get { self[ProbeKey.self] }
        set { self[ProbeKey.self] = newValue }
    }
    fileprivate var liveOnly: String {
        get { self[LiveOnlyKey.self] }
        set { self[LiveOnlyKey.self] = newValue }
    }
}

@MainActor
private final class ProbeModel {
    @Dependency(\.probe) var probe
}

private struct LiveOnlyReader {
    @Dependency(\.liveOnly) var value
}

// MARK: - Suite
// .serialized + @MainActor: @MainActor alone prevents data races but not
// cross-test interleaving under Swift Testing's parallel scheduler (same
// pattern as WebSessionSharedTests) — .serialized is required so the shared
// DependencyStore never sees interleaved access. _reset() in init isolates
// each test from cached defaults of the previous one.

@Suite("Dependency", .serialized)
@MainActor
struct DependencyTests {
    init() { DependencyStore._reset() }

    @Test func keyWithoutTestValueFallsBackToLiveValue() {
        #expect(LiveOnlyReader().value == "live-only")
    }

    @Test func testValueAutoSelectedUnderTests() {
        #expect(DependencyStore.isTesting)
        #expect(ProbeModel().probe.name == "test")
    }

    @Test func withDependenciesOverridesAndRestores() {
        let inside = withDependencies {
            $0.probe = ProbeService(name: "mock")
        } operation: {
            ProbeModel().probe.name
        }
        #expect(inside == "mock")
        #expect(ProbeModel().probe.name == "test")   // scope exited: default again
    }

    @Test func nestedScopesStack() {
        withDependencies {
            $0.probe = ProbeService(name: "outer")
        } operation: {
            #expect(ProbeModel().probe.name == "outer")
            withDependencies {
                $0.probe = ProbeService(name: "inner")
            } operation: {
                #expect(ProbeModel().probe.name == "inner")
            }
            #expect(ProbeModel().probe.name == "outer")   // inner scope restored
        }
    }

    @Test func captureAtInitSurvivesScopeExit() {
        let model = withDependencies {
            $0.probe = ProbeService(name: "captured")
        } operation: {
            ProbeModel()
        }
        #expect(model.probe.name == "captured")   // snapshot wins after scope exit
        #expect(ProbeModel().probe.name == "test")   // fresh model: default
    }

    @Test func modelOutsideScopeSeesLaterGlobalOverride() {
        let model = ProbeModel()                  // snapshot has no probe entry
        prepareDependencies { $0.probe = ProbeService(name: "staging") }
        #expect(model.probe.name == "staging")    // priority 2: current globals
    }

    @Test func defaultsAreCachedSingletons() {
        #expect(ProbeModel().probe === ProbeModel().probe)
    }

    @Test func subscriptGetInsideMutateReturnsEffectiveDefault() {
        withDependencies {
            #expect($0.probe.name == "test")      // read before write: cached default
        } operation: {}
    }

    @Test func resetClearsOverridesAndCache() {
        prepareDependencies { $0.probe = ProbeService(name: "staging") }
        let cached = ProbeModel().probe
        DependencyStore._reset()
        #expect(ProbeModel().probe.name == "test")   // override gone
        #expect(ProbeModel().probe !== cached)       // cache gone: new instance
    }
}
