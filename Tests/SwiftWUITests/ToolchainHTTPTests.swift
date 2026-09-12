import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftWUIToolchain

@Suite struct ToolchainHTTPTests {
    func tempSite() throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-http-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir + "/sub", withIntermediateDirectories: true)
        try "<h1>home</h1>".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        try "body{}".write(toFile: dir + "/app.css", atomically: true, encoding: .utf8)
        try Data([0, 97, 115, 109]).write(to: URL(fileURLWithPath: dir + "/sub/app.wasm"))
        return dir
    }
    func get(_ port: UInt16, _ path: String, timeout: TimeInterval? = nil) async throws -> (Int, [UInt8], [AnyHashable: Any]) {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        if let timeout { request.timeoutInterval = timeout }
        let (data, resp) = try await URLSession.shared.data(for: request)
        let http = resp as! HTTPURLResponse
        return (http.statusCode, Array(data), http.allHeaderFields)
    }
    func getRange(_ port: UInt16, _ path: String, _ range: String?) async throws -> (Int, [UInt8], [AnyHashable: Any]) {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        if let range { req.setValue(range, forHTTPHeaderField: "Range") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as! HTTPURLResponse
        return (http.statusCode, Array(data), http.allHeaderFields)
    }

    @Test func servesFilesWithCorrectMIME() async throws {
        let dir = try tempSite()
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir)])
        try server.start(port: 0)
        defer { server.stop() }
        let (s1, b1, h1) = try await get(server.boundPort, "/index.html")
        #expect(s1 == 200 && String(decoding: b1, as: UTF8.self) == "<h1>home</h1>")
        #expect((h1["Content-Type"] as? String)?.hasPrefix("text/html") == true)
        #expect(h1["Cache-Control"] as? String == "no-cache")
        let (_, _, h2) = try await get(server.boundPort, "/sub/app.wasm")
        #expect(h2["Content-Type"] as? String == "application/wasm")
        #expect(h2["Cache-Control"] as? String == "no-cache")
        let (s3, _, _) = try await get(server.boundPort, "/nope.js")
        #expect(s3 == 404)
    }

    @Test func extensionlessResolvesDirectoryIndex() async throws {
        let dir = try tempSite()
        try FileManager.default.createDirectory(atPath: dir + "/about", withIntermediateDirectories: true)
        try "<h1>about</h1>".write(toFile: dir + "/about/index.html", atomically: true, encoding: .utf8)
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir)])
        try server.start(port: 0); defer { server.stop() }
        let (s, b, _) = try await get(server.boundPort, "/about")
        #expect(s == 200 && String(decoding: b, as: UTF8.self) == "<h1>about</h1>")
    }

    @Test func traversalIsBlocked() async throws {
        let dir = try tempSite()
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir + "/sub")])
        try server.start(port: 0); defer { server.stop() }
        let (s, _, _) = try await get(server.boundPort, "/%2e%2e/index.html")
        #expect(s == 404)   // ../index.html escapes root → guarded
    }

    @Test func traversalSiblingPrefixIsBlocked() async throws {
        let dir = try tempSite()
        // Sibling dir whose name shares the root as a string prefix: "/sub-evil"
        try FileManager.default.createDirectory(atPath: dir + "/sub-evil", withIntermediateDirectories: true)
        try "secret".write(toFile: dir + "/sub-evil/secret.txt", atomically: true, encoding: .utf8)
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir + "/sub")])
        try server.start(port: 0); defer { server.stop() }
        let (s, _, _) = try await get(server.boundPort, "/%2e%2e/sub-evil/secret.txt")
        #expect(s == 404)   // "/x/sub-evil" must NOT pass a "/x/sub" prefix check
    }

    @Test func portInUseThrows() throws {
        let a = HTTPServer(handlers: []); try a.start(port: 0); defer { a.stop() }
        let b = HTTPServer(handlers: [])
        #expect(throws: ToolchainError.self) { try b.start(port: a.boundPort) }
    }

    @Test func stopUnblocksAcceptLoopAndReleasesServer() async throws {
        var server: HTTPServer? = HTTPServer(handlers: [])
        weak var weakServer = server
        do {
            let startedServer = try #require(server)
            try startedServer.start(port: 0)
            defer { startedServer.stop() }
            let (status, _, _) = try await get(startedServer.boundPort, "/", timeout: 5)
            #expect(status == 404)
        }
        server = nil

        for _ in 0..<100 where weakServer != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(weakServer == nil)
    }

    @Test func mimeTableCoversAssetTypes() {
        #expect(MIME.type(forPath: "a/f.woff2") == "font/woff2")
        #expect(MIME.type(forPath: "f.webp") == "image/webp")
        #expect(MIME.type(forPath: "f.mp4") == "video/mp4")
        #expect(MIME.type(forPath: "f.webmanifest") == "application/manifest+json")
        #expect(MIME.type(forPath: "f.unknownext") == "application/octet-stream")
    }

    @Test func rangeRequestsSliceBody() async throws {
        let dir = try tempSite()
        try Data(Array(0..<100 as Range<UInt8>)).write(to: URL(fileURLWithPath: dir + "/blob.bin"))
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir)])
        try server.start(port: 0); defer { server.stop() }
        let p = server.boundPort

        let (s1, b1, h1) = try await getRange(p, "/blob.bin", "bytes=0-9")
        #expect(s1 == 206 && b1 == Array(0..<10))
        #expect(h1["Content-Range"] as? String == "bytes 0-9/100")

        let (s2, b2, _) = try await getRange(p, "/blob.bin", "bytes=90-")
        #expect(s2 == 206 && b2 == Array(90..<100))

        let (s3, b3, _) = try await getRange(p, "/blob.bin", "bytes=-10")
        #expect(s3 == 206 && b3 == Array(90..<100))

        let (s4, _, _) = try await getRange(p, "/blob.bin", "bytes=200-")
        #expect(s4 == 416)

        let (s5, b5, _) = try await getRange(p, "/blob.bin", "bytes=0-9,20-29")
        #expect(s5 == 200 && b5.count == 100)          // multi-range ignored

        let (s6, _, h6) = try await getRange(p, "/blob.bin", nil)
        #expect(s6 == 200)
        #expect(h6["Accept-Ranges"] as? String == "bytes")
    }

    @Test func rangedResponseEdgeCases() {
        let full = HTTPResponse(status: 200, headers: [:], body: Array(0..<10 as Range<UInt8>))
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=3-5").body == [3, 4, 5])
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=3-999").body == Array(3..<10))
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "garbage").status == 200)
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=-0").status == 200)
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=5-3").status == 416)
        let sse = HTTPResponse(status: 200, headers: [:], body: [1], hijack: { _ in })
        #expect(HTTPServer.rangedResponse(sse, rangeHeader: "bytes=0-0").headers["Accept-Ranges"] == nil)
    }
}
