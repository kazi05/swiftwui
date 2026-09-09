import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private nonisolated final class FixturePortHandshake: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int, any Error>?
    private var bytes: [UInt8] = []
    private var finished = false

    func install(_ continuation: CheckedContinuation<Int, any Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func receive(_ data: Foundation.Data) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        guard !data.isEmpty else {
            finishLocked(.failure(WebFetchError.network("fixture server exited before reporting a port")))
            lock.unlock()
            return
        }
        bytes.append(contentsOf: data)
        guard let newline = bytes.firstIndex(of: 10) else { lock.unlock(); return }
        let value = Int(String(decoding: bytes[..<newline], as: UTF8.self))
        if let value {
            finishLocked(.success(value))
        } else {
            finishLocked(.failure(WebFetchError.network("fixture server reported an invalid port")))
        }
        lock.unlock()
    }

    func timeout() {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finishLocked(.failure(WebFetchError.timeout))
        lock.unlock()
    }

    private func finishLocked(_ result: Result<Int, any Error>) {
        finished = true
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}

@MainActor
private final class UploadFixtureServer {
    nonisolated deinit { }

    private let process: Process
    let port: Int

    private init(process: Process, port: Int) {
        self.process = process
        self.port = port
    }

    static func start() async throws -> UploadFixtureServer {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-u", "-c", Self.script]
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()

        let handshake = FixturePortHandshake()
        let handle = output.fileHandleForReading
        do {
            let port = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Int, any Error>) in
                handshake.install(continuation)
                handle.readabilityHandler = { readable in
                    handshake.receive(readable.availableData)
                }
                Task.detached {
                    try? await Task.sleep(for: .seconds(3))
                    handshake.timeout()
                }
            }
            handle.readabilityHandler = nil
            return UploadFixtureServer(process: process, port: port)
        } catch {
            handle.readabilityHandler = nil
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            throw error
        }
    }

    func stop() {
        guard process.isRunning else { return }
        process.terminate()
        process.waitUntilExit()
    }

    var baseURL: String { "http://127.0.0.1:\(port)" }

    private static let script = #"""
import http.server
import time

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        body = b"legacy-data"
        self.send_response(207)
        self.send_header("X-Regression", "yes")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        self.handle_upload()

    def do_PUT(self):
        self.handle_upload()

    def handle_upload(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        if self.path == "/delay":
            time.sleep(0.3)
        elif self.path == "/delay-long":
            time.sleep(1.0)
        status = 418 if self.path == "/status" else 200
        self.send_response(status)
        self.send_header("X-Seen-Method", self.command)
        self.send_header("X-Seen-Content-Type", self.headers.get("Content-Type", ""))
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except BrokenPipeError:
            pass

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
print(server.server_address[1], flush=True)
server.serve_forever()
"""#
}

@Suite(.serialized) @MainActor struct URLSessionUploadTests {
    private func withServer<T>(_ operation: (UploadFixtureServer) async throws -> T) async throws -> T {
        let server = try await UploadFixtureServer.start()
        defer { server.stop() }
        return try await operation(server)
    }

    private func request(_ url: String, method: HTTPMethod = .put) -> WebRequest {
        var request = WebRequest(url: url)
        request.method = method
        return request
    }

    @Test func uploadsOnlySelectedRangeWithDefaultMIME() async throws {
        try await withServer { server in
            let session = WebSession(transport: URLSessionTransport())
            let blob = try WebBlob(
                data: _FoundationData([10, 20, 30, 40, 50]), mimeType: "APPLICATION/OCTET-STREAM"
            ).slice(1..<4)

            let (body, response) = try await session.upload(
                for: request(server.baseURL + "/echo"), from: blob
            )

            #expect(body == _FoundationData([20, 30, 40]))
            #expect(response.status == 200)
            #expect(response.headers["x-seen-method"] == "PUT")
            #expect(response.headers["x-seen-content-type"] == "application/octet-stream")
        }
    }

    @Test func explicitContentTypeReachesNativeServer() async throws {
        try await withServer { server in
            let session = WebSession(transport: URLSessionTransport())
            var upload = request(server.baseURL + "/echo", method: .post)
            upload.headers["content-type"] = "application/custom"

            let (_, response) = try await session.upload(
                for: upload,
                from: WebBlob(data: _FoundationData([1]), mimeType: "text/plain")
            )

            #expect(response.headers["x-seen-content-type"] == "application/custom")
        }
    }

    @Test func nonSuccessStatusReturnsBodyAndResponse() async throws {
        try await withServer { server in
            let session = WebSession(transport: URLSessionTransport())
            let (body, response) = try await session.upload(
                for: request(server.baseURL + "/status"),
                from: WebBlob(data: _FoundationData([7, 8]))
            )

            #expect(body == _FoundationData([7, 8]))
            #expect(response.status == 418)
            #expect(!response.isSuccess)
        }
    }

    @Test func fractionalTimeoutMapsToTimeout() async throws {
        try await withServer { server in
            let session = WebSession(transport: URLSessionTransport())
            var upload = request(server.baseURL + "/delay")
            upload.timeout = .milliseconds(50)

            await #expect(throws: WebFetchError.timeout) {
                _ = try await session.upload(
                    for: upload, from: WebBlob(data: _FoundationData([1]))
                )
            }
        }
    }

    @Test func inFlightCancellationMapsToCancelled() async throws {
        try await withServer { server in
            let session = WebSession(transport: URLSessionTransport())
            let task = Task { @MainActor in
                try await session.upload(
                    for: request(server.baseURL + "/delay-long"),
                    from: WebBlob(data: _FoundationData([1]))
                )
            }
            try await Task.sleep(for: .milliseconds(50))
            task.cancel()

            await #expect(throws: WebFetchError.cancelled) { _ = try await task.value }
        }
    }

    @Test func opaqueStorageIsUnsupportedWithoutReading() async throws {
        let storage = BlobStorageSpy()
        let session = WebSession(transport: URLSessionTransport())

        await #expect(throws: WebFetchError.unsupported) {
            _ = try await session.upload(
                for: request("http://127.0.0.1:1/upload"),
                from: WebBlob(storage: storage)
            )
        }
        #expect(storage.dataCalls == 0)
    }

    @Test func existingDataPathKeepsStatusBodyAndNormalizedHeaders() async throws {
        try await withServer { server in
            let session = WebSession(transport: URLSessionTransport())
            let (body, response) = try await session.data(from: server.baseURL + "/data")

            #expect(body == _FoundationData("legacy-data".utf8))
            #expect(response.status == 207)
            #expect(response.headers["x-regression"] == "yes")
        }
    }
}
