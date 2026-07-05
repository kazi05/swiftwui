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
}
