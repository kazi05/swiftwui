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
    @Dependency(\.navigate) var navigate
    @Dependency(\.webStorage) var webStorage
    @Dependency(\.logger) var logger
}

private struct EmptyFixture: Tag {
    var body: some Tag { Div() }
}

// MARK: - Suite

// @MainActor + .serialized: tests share the global DependencyStore and reset
// it in init — parallel scheduling would interleave resets with sibling tests.
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

    @Test func navigateDefaultIsNoOp() {
        BuiltinModel().navigate("/anywhere")   // must not trap or navigate
    }

    @Test func navigateOverrideRecords() {
        var recorded: [(String, Bool)] = []
        let model = withDependencies {
            $0.navigate = NavigateAction { path, replace in recorded.append((path, replace)) }
        } operation: {
            BuiltinModel()
        }
        model.navigate("/login")
        model.navigate("/home", replace: true)
        #expect(recorded.count == 2)
        #expect(recorded[0] == ("/login", false))
        #expect(recorded[1] == ("/home", true))
    }

    @Test func webStorageRoundtrip() {
        let model = BuiltinModel()
        #expect(model.webStorage.get("count", as: Int.self) == nil)
        model.webStorage.set("count", 42)
        #expect(model.webStorage.get("count", as: Int.self) == 42)
        model.webStorage.remove("count")
        #expect(model.webStorage.get("count", as: Int.self) == nil)
    }

    @Test func webStorageKindsAreSeparate() {
        let model = BuiltinModel()
        model.webStorage.set("k", "local-value")
        model.webStorage.set("k", "session-value", kind: .session)
        #expect(model.webStorage.get("k", as: String.self) == "local-value")
        #expect(model.webStorage.get("k", as: String.self, kind: .session) == "session-value")
    }

    @Test func loggerOverrideCaptures() {
        var lines: [String] = []
        let model = withDependencies {
            $0.logger = Logger { level, message in lines.append("\(level.rawValue):\(message)") }
        } operation: {
            BuiltinModel()
        }
        model.logger.info("hello")
        model.logger.error("boom")
        #expect(lines == ["info:hello", "error:boom"])
    }

    @Test func bootstrapDependenciesWiresRuntime() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: EmptyFixture(), scheduleMicrotask: { _ in })
        runtime.mount()
        runtime.bootstrapDependencies()
        let model = BuiltinModel()
        model.webStorage.set("boot", "wired")
        #expect(runtime._storage.box(kind: .local, key: "boot").raw == "wired")
        model.navigate("/next")
        #expect(backend.historyStack.contains("/next"))
    }
}
