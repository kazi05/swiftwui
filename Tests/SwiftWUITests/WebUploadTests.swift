import Foundation
import Testing
@testable import SwiftWUI

@MainActor
private final class UploadTransportSpy: @MainActor _BlobUploadingTransport {
    nonisolated deinit { }
    private(set) var requests: [WebRequest] = []
    var result = (_FoundationData([9]), WebResponse(status: 202, headers: ["x-result": "ok"]))

    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        throw WebFetchError.network("wrong transport entry point")
    }

    func upload(_ request: WebRequest, from blob: WebBlob) async throws -> (_FoundationData, WebResponse) {
        requests.append(request)
        return result
    }
}

@MainActor
private final class LegacyTransportSpy: FetchTransport {
    nonisolated deinit { }
    private(set) var performCalls = 0

    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        performCalls += 1
        return (_FoundationData(), WebResponse(status: 200, headers: [:]))
    }
}

@MainActor
private final class LegacyFileReader: _FileReading {
    nonisolated deinit { }
    private(set) var dataCalls = 0

    func data() async throws -> _FoundationData {
        dataCalls += 1
        return _FoundationData([1])
    }

    func text() async throws -> String { "x" }
}

@MainActor
private final class BlobFileReader: @MainActor _FileBlobProviding {
    nonisolated deinit { }
    private(set) var dataCalls = 0
    let value = WebBlob(data: _FoundationData([4, 5]), mimeType: "IMAGE/PNG")

    func data() async throws -> _FoundationData {
        dataCalls += 1
        return _FoundationData([4, 5])
    }

    func text() async throws -> String { "ignored" }
    func blob() async throws -> WebBlob { value }
}

@Suite @MainActor struct WebUploadTests {
    private func request(_ method: HTTPMethod = .put) -> WebRequest {
        var request = WebRequest(url: "/upload")
        request.method = method
        return request
    }

    @Test func fileBlobRequiresCapabilityWithoutReadingLegacyFile() async throws {
        let legacy = LegacyFileReader()
        let unsupported = WebFile(
            name: "x.bin", size: 1, mimeType: "application/octet-stream",
            lastModified: Date(timeIntervalSince1970: 0), reader: legacy
        )
        await #expect(throws: WebFetchError.unsupported) { _ = try await unsupported.blob() }
        #expect(legacy.dataCalls == 0)

        let provider = BlobFileReader()
        let supported = WebFile(
            name: "x.png", size: 2, mimeType: "image/png",
            lastModified: Date(timeIntervalSince1970: 0), reader: provider
        )
        #expect(try await supported.blob() === provider.value)
        #expect(provider.dataCalls == 0)
    }

    @Test func uploadAddsNormalizedMIMEWithoutMutatingCallerRequest() async throws {
        let transport = UploadTransportSpy()
        let session = WebSession(transport: transport)
        let original = request()

        let (data, response) = try await session.upload(
            for: original,
            from: WebBlob(data: _FoundationData([1]), mimeType: "TEXT/PLAIN")
        )

        #expect(data == _FoundationData([9]))
        #expect(response.status == 202)
        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].headers["Content-Type"] == "text/plain")
        #expect(original.headers.isEmpty)
    }

    @Test func explicitContentTypeWinsUnderAnyHeaderCasing() async throws {
        let transport = UploadTransportSpy()
        let session = WebSession(transport: transport)
        var original = request(.post)
        original.headers["content-TYPE"] = "application/custom"

        _ = try await session.upload(
            for: original,
            from: WebBlob(data: _FoundationData([1]), mimeType: "text/plain")
        )

        #expect(transport.requests[0].headers == ["content-TYPE": "application/custom"])
    }

    @Test func bodyConflictPrecedesMethodRejectionAndIncludesEmptyData() async {
        let transport = UploadTransportSpy()
        let session = WebSession(transport: transport)
        var original = request(.get)
        original.body = _FoundationData()

        await #expect(throws: WebUploadError.conflictingBody) {
            _ = try await session.upload(for: original, from: WebBlob(data: _FoundationData()))
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func getAndHeadUploadsAreRejected() async {
        let transport = UploadTransportSpy()
        let session = WebSession(transport: transport)

        for method in [HTTPMethod.get, .head] {
            await #expect(throws: WebUploadError.invalidMethod) {
                _ = try await session.upload(for: request(method), from: WebBlob(data: _FoundationData()))
            }
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func requestValidationRunsBeforeUploadSpecificChecks() async {
        let transport = UploadTransportSpy()
        let session = WebSession(transport: transport)
        var invalid = WebRequest(url: "javascript:alert(1)")
        invalid.method = .get
        invalid.body = _FoundationData()

        await #expect(throws: WebFetchError.badURL("javascript:alert(1)")) {
            _ = try await session.upload(for: invalid, from: WebBlob(data: _FoundationData()))
        }
    }

    @Test func legacyTransportIsUnsupportedWithoutPerformOrBlobRead() async {
        let transport = LegacyTransportSpy()
        let session = WebSession(transport: transport)
        let storage = BlobStorageSpy()

        await #expect(throws: WebFetchError.unsupported) {
            _ = try await session.upload(for: request(), from: WebBlob(storage: storage))
        }
        #expect(transport.performCalls == 0)
        #expect(storage.dataCalls == 0)
    }

    @Test func preCancelledUploadDoesNotDispatch() async {
        let transport = UploadTransportSpy()
        let session = WebSession(transport: transport)
        let task = Task { @MainActor in
            await Task.yield()
            return try await session.upload(
                for: request(), from: WebBlob(data: _FoundationData([1]))
            )
        }
        task.cancel()

        await #expect(throws: WebFetchError.cancelled) {
            _ = try await task.value
        }
        #expect(transport.requests.isEmpty)
    }
}
