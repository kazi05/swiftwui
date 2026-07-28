import Foundation

public final class DevSession: @unchecked Sendable {   // lastError guarded by `lock`
    private let builder: WasmBuilder
    private let hub: SSEHub
    private let lock = NSLock()
    private var _lastError: String?
    public var lastError: String? { lock.lock(); defer { lock.unlock() }; return _lastError }

    public init(builder: WasmBuilder, hub: SSEHub) {
        self.builder = builder; self.hub = hub
    }

    /// One watcher-triggered cycle: rebuild, then `reload` or `build-error` (spec §6).
    public func rebuildAndNotify() {
        do {
            // Before the compiler sees them: the watcher wakes on Locales/*.json,
            // so a catalog edit has to reach L10n.swift or the rebuild is a no-op.
            // A bad catalog throws here and lands in the browser overlay like any
            // other build error.
            _ = try L10nGenerator.generate(projectDir: builder.projectDir)
            _ = try builder.build(configuration: "debug")
            lock.lock(); _lastError = nil; lock.unlock()
            hub.broadcast(event: "reload", data: "{}")
        } catch let e as ToolchainError {
            let output: String
            if case .buildFailed(let out) = e { output = out } else { output = e.description }
            let encoded = DevInjection.jsonStringLiteral(output)
            lock.lock(); _lastError = encoded; lock.unlock()
            hub.broadcast(event: "build-error", data: encoded)
        } catch {
            let encoded = DevInjection.jsonStringLiteral("\(error)")
            lock.lock(); _lastError = encoded; lock.unlock()
            hub.broadcast(event: "build-error", data: encoded)
        }
    }

    /// The dev URL space (spec §4/§5): SSE + dev client + vendor + /app/* + injected index.html.
    public func handlers(projectDir: String, bundleDir: String) -> [HTTPHandler] {
        let resources = ToolchainResources.root.path
        let projectShim = projectDir + "/vendor/wasi-shim"
        let shimRoot = FileManager.default.fileExists(atPath: projectShim)
            ? projectShim : resources + "/vendor/wasi-shim"
        // Dedicated closure, not StaticFiles.handler: an exact-match prefix leaves an
        // empty remainder, which StaticFiles resolves as the Resources *directory*
        // (falling through to its own index.html lookup) rather than dev-client.js.
        let devClient: HTTPHandler = { request in
            guard request.path == "/__swiftwui/dev-client.js",
                  let data = FileManager.default.contents(atPath: resources + "/dev-client.js")
            else { return nil }
            return .file(bytes: Array(data), mime: "text/javascript; charset=utf-8")
        }
        let indexHandler: HTTPHandler = { request in
            // "/", "/index.html", and any extensionless route (SPA dev routing) → injected index.
            guard request.path == "/" || request.path == "/index.html"
                || !request.path.dropFirst().contains(".") else { return nil }
            guard let html = try? String(contentsOfFile: projectDir + "/index.html", encoding: .utf8)
            else { return nil }
            return .text(DevInjection.inject(into: html), contentType: "text/html; charset=utf-8")
        }
        // public/ assets (spec §2): dotted paths only — extensionless paths
        // must keep falling through to the SPA index handler below.
        let publicFiles = StaticFiles.handler(urlPrefix: "/", root: projectDir + "/public")
        let publicHandler: HTTPHandler = { request in
            guard request.path.split(separator: "/").last?.contains(".") == true else { return nil }
            return publicFiles(request)
        }
        return [
            hub.handler(lastError: { [weak self] in self?.lastError }),
            devClient,
            StaticFiles.handler(urlPrefix: "/__swiftwui/vendor/wasi-shim/", root: shimRoot),
            StaticFiles.handler(urlPrefix: "/vendor/wasi-shim/", root: shimRoot),
            StaticFiles.handler(urlPrefix: "/app/", root: bundleDir),
            publicHandler,
            indexHandler,
        ]
    }
}
