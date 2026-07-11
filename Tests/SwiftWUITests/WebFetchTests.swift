import Foundation
import Testing
@testable import SwiftWUI

@MainActor
private final class MockTransport: FetchTransport {
    var queue: [Result<(Foundation.Data, WebResponse), WebFetchError>] = []
    private(set) var requests: [WebRequest] = []
    func perform(_ request: WebRequest) async throws -> (Foundation.Data, WebResponse) {
        requests.append(request)
        return try queue.removeFirst().get()
    }
}

private struct Item: Codable, Equatable { let id: Int; let name: String }

@Suite @MainActor struct WebFetchTests {

    @Test func schemeValidation() async {
        let session = WebSession(transport: MockTransport())
        await #expect(throws: WebFetchError.badURL("javascript:alert(1)")) {
            _ = try await session.data(from: "javascript:alert(1)")
        }
        await #expect(throws: WebFetchError.badURL("data:text/html,x")) {
            _ = try await session.data(from: "data:text/html,x")
        }
        await #expect(throws: WebFetchError.badURL("//evil.com/x")) {   // protocol-relative → cross-origin
            _ = try await session.data(from: "//evil.com/x")
        }
        await #expect(throws: WebFetchError.badURL("")) {
            _ = try await session.data(from: "")
        }
        // WHATWG-parser bypasses: leading C0/space stripped, '\' normalized to '/',
        // and tab/LF/CR stripped from anywhere (so "/\t/evil.com/x" → "//evil.com/x").
        for bad in [" //evil.com/x", "\t//evil.com/x", "\\\\evil.com/x", "/\\evil.com/x",
                    "/\t/evil.com/x", "http\n://evil.com"] {
            await #expect(throws: WebFetchError.badURL(bad)) {
                _ = try await session.data(from: bad)
            }
        }
        // Genuine origin-relative paths still pass validation.
        for ok in ["/api", "api/x"] {
            #expect(throws: Never.self) { try WebSession.validate(WebRequest(url: ok)) }
        }
    }

    @Test func relativeURLsPass() async throws {
        let t = MockTransport()
        t.queue = [.success((Data(), WebResponse(status: 200, headers: [:]))),
                   .success((Data(), WebResponse(status: 200, headers: [:])))]
        let session = WebSession(transport: t)
        _ = try await session.data(from: "/api/items?tag=a:b")   // colon after "/" is fine
        _ = try await session.data(from: "https://example.com/x")
        #expect(t.requests.count == 2)
    }

    @Test func headerCRLFRejected() async {
        var req = WebRequest(url: "/x")
        req.headers["X-Bad"] = "a\r\nInjected: yes"
        let session = WebSession(transport: MockTransport())
        await #expect(throws: WebFetchError.invalidHeader("X-Bad")) {
            _ = try await session.data(for: req)
        }
    }

    @Test func jsonSugarDecodes() async throws {
        let t = MockTransport()
        let payload = try JSONEncoder().encode(Item(id: 1, name: "a"))
        t.queue = [.success((payload, WebResponse(status: 200, headers: [:])))]
        let session = WebSession(transport: t)
        let item: Item = try await session.json(from: "/api/item")
        #expect(item == Item(id: 1, name: "a"))
    }

    @Test func jsonSugarThrowsHttpStatusOnNon2xx() async throws {
        let t = MockTransport()
        let body = Data("nope".utf8)
        t.queue = [.success((body, WebResponse(status: 404, headers: [:])))]
        let session = WebSession(transport: t)
        await #expect(throws: WebFetchError.httpStatus(404, body)) {
            let _: Item = try await session.json(from: "/missing")
        }
    }

    @Test func dataForDoesNotTreatStatusAsError() async throws {
        let t = MockTransport()
        t.queue = [.success((Data(), WebResponse(status: 500, headers: [:])))]
        let session = WebSession(transport: t)
        let (_, resp) = try await session.data(from: "/x")
        #expect(resp.status == 500)
        #expect(!resp.isSuccess)
    }

    @Test func sendEncodesBodyAndContentType() async throws {
        let t = MockTransport()
        let respBody = try JSONEncoder().encode(Item(id: 2, name: "b"))
        t.queue = [.success((respBody, WebResponse(status: 201, headers: [:])))]
        let session = WebSession(transport: t)
        let created: Item = try await session.send(.post, "/api/items", json: Item(id: 2, name: "b"))
        #expect(created.id == 2)
        #expect(t.requests[0].method == .post)
        #expect(t.requests[0].headers["Content-Type"] == "application/json")
        #expect(t.requests[0].body != nil)
    }

    @Test func unconfiguredDefaultThrowsUnsupported() async {
        await #expect(throws: WebFetchError.unsupported) {
            _ = try await EnvironmentValues().webSession.data(from: "/x")
        }
    }

    @Test func runtimeSeedsSessionIntoEnvironment() {
        @MainActor final class Probe { var configured: Bool? = nil }
        struct FetchReader: Tag {
            let probe: Probe
            @Environment(\.webSession) var session
            var body: some Tag {
                probe.configured = (session !== WebSession.unsupported)
                return Text("x")
            }
        }
        let probe = Probe()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: FetchReader(probe: probe), scheduleMicrotask: { $0() })
        runtime._webSession = WebSession(transport: MockTransport())
        runtime.mount()
        #expect(probe.configured == true)
    }
}
