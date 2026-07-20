import Testing
@testable import SwiftWUI

// MARK: - Fixtures

private final class StubTransport: FetchTransport {
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        (_FoundationData(), WebResponse(status: 200, headers: [:]))
    }
}

@MainActor
private final class BuiltinModel {
    @Dependency(\.webSession) var session
}

// MARK: - Suite

@MainActor
@Suite("BuiltinDependencies", .serialized)
struct BuiltinDependencyTests {
    init() { DependencyStore._reset() }

    @Test func webSessionDefaultsToUnsupportedInTests() {
        #expect(BuiltinModel().session === WebSession.unsupported)
    }

    @Test func webSessionOverrideWins() async throws {
        let stub = WebSession(transport: StubTransport())
        let model = withDependencies {
            $0.webSession = stub
        } operation: {
            BuiltinModel()
        }
        #expect(model.session === stub)
        let (_, response) = try await model.session.data(from: "/ok")
        #expect(response.status == 200)
    }
}
