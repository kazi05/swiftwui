import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

@MainActor
private final class MockTransport: FetchTransport {
    var queue: [Result<(Foundation.Data, WebResponse), WebFetchError>] = []
    private(set) var requests: [WebRequest] = []
    func perform(_ request: WebRequest) async throws -> (Foundation.Data, WebResponse) {
        requests.append(request)
        return try queue.removeFirst().get()
    }
}

@Suite(.serialized) @MainActor struct WebSessionSharedTests {

    @Test func defaultsToUnsupportedAndThrows() async {
        WebSession.resetShared()
        let s = WebSession.shared                      // capture before await
        #expect(s === WebSession.unsupported)
        await #expect(throws: WebFetchError.unsupported) {
            _ = try await s.data(from: "/api/x")
        }
    }

    @Test func bootstrapSetsAndResetClears() {
        let t = MockTransport()                        // reuse WebFetchTests pattern
        let session = WebSession(transport: t)
        WebSession.bootstrap(session)
        #expect(WebSession.shared === session)
        WebSession.resetShared()
        #expect(WebSession.shared === WebSession.unsupported)
    }

    @Test func sharedWorksFromPlainCode() async throws {
        // The ViewModel story: no Tag/Page anywhere in sight.
        let t = MockTransport()
        t.queue = [.success((Data("{\"ok\":true}".utf8),
                             WebResponse(status: 200, headers: [:])))]
        WebSession.bootstrap(WebSession(transport: t))
        defer { WebSession.resetShared() }
        struct R: Decodable { let ok: Bool }
        let s = WebSession.shared
        let r: R = try await s.json(from: "/api/x")
        #expect(r.ok)
    }

    @Test func ssgGenerateBootstrapsShared() async throws {
        WebSession.resetShared()
        defer { WebSession.resetShared() }
        let out = NSTemporaryDirectory() + "swiftwui-ssg-shared-\(UUID().uuidString)"
        _ = try await StaticSite.generate(SharedProbeApp.self, config: .init(outDir: out, mode: .staticOnly))
        #expect(WebSession.shared !== WebSession.unsupported)
    }

    @Test func environmentObservedSessionIsShared() async throws {
        WebSession.resetShared()
        SharedEnvProbe.shared.seen = nil
        SharedEnvProbe.shared.matchedShared = nil
        defer { WebSession.resetShared() }
        let out = NSTemporaryDirectory() + "swiftwui-ssg-env-\(UUID().uuidString)"
        _ = try await StaticSite.generate(SharedEnvApp.self, config: .init(outDir: out, mode: .staticOnly))
        let seen = SharedEnvProbe.shared.seen              // capture before further awaits
        let matchedShared = SharedEnvProbe.shared.matchedShared
        #expect(seen != nil)
        #expect(matchedShared == true)                     // recorded synchronously inside body — race-free
        #expect(seen !== WebSession.unsupported)
    }
}

@MainActor private final class SharedEnvProbe {
    static let shared = SharedEnvProbe()
    var seen: WebSession?
    var matchedShared: Bool?
}
private struct SharedEnvPage: Tag, Page {
    var title: String { "Probe" }
    @Environment(\.webSession) var session
    var body: some Tag {
        SharedEnvProbe.shared.seen = session
        SharedEnvProbe.shared.matchedShared = (session === WebSession.shared)
        return Text("ok")
    }
}
private struct SharedEnvApp: App {
    init() {}
    var body: some Tag { Router { Route("/") { SharedEnvPage() } } }
}

// Minimal StaticSite.generate fixture (mirrors WebFetchTests.ssgRuntimeSeesConfiguredSession).
private struct SharedProbePage: Tag, Page {
    var title: String { "Probe" }
    var body: some Tag { Text("ok") }
}
private struct SharedProbeApp: App {
    init() {}
    var body: some Tag { Router { Route("/") { SharedProbePage() } } }
}
