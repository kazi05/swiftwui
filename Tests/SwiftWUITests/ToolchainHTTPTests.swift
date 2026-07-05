import Testing
import Foundation
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
    func get(_ port: UInt16, _ path: String) async throws -> (Int, [UInt8], [AnyHashable: Any]) {
        let (data, resp) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)\(path)")!)
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
        let (_, _, h2) = try await get(server.boundPort, "/sub/app.wasm")
        #expect(h2["Content-Type"] as? String == "application/wasm")
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
}
