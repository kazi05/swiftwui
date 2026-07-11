import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainDevTests {
    @Test func devURLSpaceServesInjectedIndexBundleAndShim() async throws {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-dev-\(UUID().uuidString)"
        let bundle = proj + "/bundle"
        try fm.createDirectory(atPath: bundle, withIntermediateDirectories: true)
        try "<head><title>t</title></head>".write(toFile: proj + "/index.html", atomically: true, encoding: .utf8)
        try "export const x = 1;".write(toFile: bundle + "/index.js", atomically: true, encoding: .utf8)

        let hub = SSEHub()
        let runner = MockRunner(results: [:])   // reuse Task 6's MockRunner (same test module)
        let session = DevSession(builder: WasmBuilder(runner: runner, projectDir: proj, sdk: "x"), hub: hub)
        let server = HTTPServer(handlers: session.handlers(projectDir: proj, bundleDir: bundle))
        try server.start(port: 0); defer { server.stop() }

        func get(_ path: String) async throws -> (Int, String) {
            let (data, resp) = try await URLSession.shared.data(
                from: URL(string: "http://127.0.0.1:\(server.boundPort)\(path)")!)
            return ((resp as! HTTPURLResponse).statusCode, String(decoding: data, as: UTF8.self))
        }
        let (s1, b1) = try await get("/")
        #expect(s1 == 200 && b1.contains("window.__swiftwui_dev = true"))
        let (s2, b2) = try await get("/about")          // SPA dev routing
        #expect(s2 == 200 && b2.contains("__swiftwui_dev"))
        let (s3, b3) = try await get("/app/index.js")
        #expect(s3 == 200 && b3 == "export const x = 1;")
        let (s4, _) = try await get("/vendor/wasi-shim/index.js")   // resource fallback
        #expect(s4 == 200)
        let (s5, _) = try await get("/__swiftwui/dev-client.js")
        #expect(s5 == 200)
    }

    @Test func buildErrorBroadcastsAndReplaysOnConnect() {
        let hub = SSEHub()
        let runner = MockRunner(results: ["swift package": .init(exitCode: 1, stdout: "", stderr: "error: boom")])
        let session = DevSession(builder: WasmBuilder(runner: runner, projectDir: "/tmp/x", sdk: "s"), hub: hub)
        session.rebuildAndNotify()
        #expect(session.lastError?.contains("boom") == true)   // replayed to late connectors
    }

    @Test func devServesPublicAssets() throws {
        let dir = NSTemporaryDirectory() + "swiftwui-pub-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir + "/public/images", withIntermediateDirectories: true)
        try "<html>".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        try "png-bytes".write(toFile: dir + "/public/images/logo.png", atomically: true, encoding: .utf8)
        try "sitemap".write(toFile: dir + "/public/robots.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let runner = MockRunner(results: [:])
        let session = DevSession(
            builder: WasmBuilder(runner: runner, projectDir: dir, sdk: "x"),
            hub: SSEHub())
        let handlers = session.handlers(projectDir: dir, bundleDir: dir + "/.bundle")
        func serve(_ path: String) -> HTTPResponse? {
            let req = HTTPRequest(method: "GET", path: path, headers: [:])
            for h in handlers { if let r = h(req) { return r } }
            return nil
        }

        let hit = serve("/images/logo.png")
        #expect(hit?.status == 200)
        #expect(hit.map { String(decoding: $0.body, as: UTF8.self) } == "png-bytes")
        #expect(hit?.headers["Content-Type"] == "image/png")
        #expect(serve("/robots.txt")?.status == 200)
        #expect(serve("/missing.png") == nil)                    // falls to server-level 404
        // extensionless path → SPA index (routes win), not public lookup
        let spa = serve("/about")
        #expect(spa.map { String(decoding: $0.body, as: UTF8.self).contains("<html>") } == true)
    }

    @Test func devWithoutPublicDirUnchanged() throws {
        let dir = NSTemporaryDirectory() + "swiftwui-nopub-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "<html>".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let runner = MockRunner(results: [:])
        let session = DevSession(
            builder: WasmBuilder(runner: runner, projectDir: dir, sdk: "x"),
            hub: SSEHub())
        let handlers = session.handlers(projectDir: dir, bundleDir: dir + "/.bundle")
        let req = HTTPRequest(method: "GET", path: "/anything.png", headers: [:])
        #expect(handlers.compactMap { $0(req) }.first == nil)
    }
}
