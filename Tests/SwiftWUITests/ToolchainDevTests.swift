import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftWUIToolchain

@Suite struct ToolchainDevTests {
    @Test func devURLSpaceServesInjectedIndexBundleAndShim() async throws {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-dev-\(UUID().uuidString)"
        let bundle = proj + "/bundle"
        try fm.createDirectory(atPath: bundle, withIntermediateDirectories: true)
        try "<head><title>t</title></head>".write(toFile: proj + "/index.html", atomically: true, encoding: .utf8)
        try "export const x = 1;".write(toFile: bundle + "/index.js", atomically: true, encoding: .utf8)
        try "\0asm".write(toFile: bundle + "/App.wasm", atomically: true, encoding: .utf8)

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
        // Dev has no dist/, and the PackageToJS plugin owns (and wipes) the
        // bundle dir — the shim reaches the browser only through its own
        // handler, ahead of the /app/ static one. A 404 here is a dead page.
        let (s6, b6) = try await get(DevSession.shimPath)
        #expect(s6 == 200 && b6.contains("data-swui-boot-config"))
        // …and the document has to point at it, with the bundle's real binary.
        #expect(b1.contains(#"src="/app/swiftwui-boot.js" data-swui-boot-config"#))
        #expect(b1.contains(#"data-wasm="/app/App.wasm""#))
        #expect(!b1.contains("data-size"), "dev stamps no size — the shim shows indeterminate progress")
    }

    @Test func theShimHandlerIgnoresEveryOtherPath() throws {
        let handler = DevSession.bootShimHandler()   // no session, no watcher, no build
        func serve(_ path: String) -> HTTPResponse? {
            handler(HTTPRequest(method: "GET", path: path, headers: [:]))
        }
        let hit = try #require(serve(DevSession.shimPath))
        #expect(hit.headers["Content-Type"]?.hasPrefix("text/javascript") == true)
        #expect(!hit.body.isEmpty)
        #expect(serve("/app/index.js") == nil)
        #expect(serve("/app/") == nil)
        #expect(serve("/swiftwui-boot.js") == nil)
    }

    /// The two orderings a dev page dies on: the flag must be set before any
    /// module runs (or `?swui-boot=` is silently ignored), and the modulepreload
    /// must stay below the import map (or Firefox rejects the map and the
    /// bundle's bare "@bjorn3/browser_wasi_shim" import never resolves).
    /// Exercised against the real scaffold, not a hand-written stub.
    @Test func devInjectionOrdersTheFlagAndKeepsTheShimBelowTheImportMap() throws {
        let template = try String(contentsOf: ToolchainResources.url("templates/basic/index.html"), encoding: .utf8)
        let out = DevInjection.inject(into: template, wasmURL: "/app/App.wasm")
        #expect(out.contains("data-swui-boot-config"))
        let flag = try #require(out.range(of: "__swiftwui_dev"))
        let map = try #require(out.range(of: "importmap"))
        let preload = try #require(out.range(of: "modulepreload"))
        let shim = try #require(out.range(of: "swiftwui-boot.js"))
        #expect(flag.lowerBound < shim.lowerBound, "the dev flag must be set before the module runs")
        #expect(map.upperBound < preload.lowerBound, "an import map after a modulepreload is rejected")
        #expect(!out.contains("<!--swiftwui:boot--><!--/swiftwui:boot-->"), "the marker region is where it goes")
    }

    /// No build yet, or a failed first one: naming a wasm we could not find
    /// would 404 the fetch. The inline import the templates used to carry lets
    /// index.js resolve the binary itself, so the page still boots.
    @Test func devInjectionWithoutAWasmFallsBackToTheInlineImport() {
        let out = DevInjection.inject(into: "<html><head></head><body></body></html>")
        #expect(!out.contains("swiftwui-boot.js"))
        #expect(out.contains(#"import { init } from "/app/index.js"; await window.__swiftwui_interop_ready; await init();"#))
    }

    /// `?swui-boot=` is gated on the dev flag, which a built dist/ never carries.
    @Test func bootDebugIsOffUnlessAskedFor() {
        let page: HTTPHandler = { _ in .text("<html><head></head></html>", contentType: "text/html; charset=utf-8") }
        let asset: HTTPHandler = { _ in .file(bytes: Array("<html>".utf8), mime: "application/wasm") }
        func body(_ h: HTTPHandler) -> String {
            String(decoding: h(HTTPRequest(method: "GET", path: "/", headers: [:]))?.body ?? [], as: UTF8.self)
        }
        #expect(!body(page).contains("__swiftwui_dev"))
        #expect(body(DevInjection.bootDebugFlag(wrapping: page)).contains("__swiftwui_dev"))
        // Only documents: a wasm that happens to start with "<html>" is not one.
        #expect(!body(DevInjection.bootDebugFlag(wrapping: asset)).contains("__swiftwui_dev"))
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
