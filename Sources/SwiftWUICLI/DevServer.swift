import Vapor
import Foundation
import Crypto

final class DevServer: @unchecked Sendable {
    let options: DevOptions
    let builder: WASMBuilder
    let htmlTemplate: HTMLTemplate

    /// All access to `connectedClients` must hold `clientsLock`. The list is
    /// touched from three threads:
    ///   1. Vapor event-loop threads when WebSockets connect/disconnect
    ///      (`app.webSocket` handler and `ws.onClose` callback).
    ///   2. The FileWatcher dispatch source thread when rebuild() fires the
    ///      `broadcast` reload signal.
    /// Without the lock, parallel append/removeAll/iterate on `Array<WebSocket>`
    /// races and can crash on Linux Swift release builds (Array's COW invariants
    /// are not thread-safe).
    private var connectedClients: [WebSocket] = []
    private let clientsLock = NSLock()

    init(options: DevOptions) {
        let sdk = options.sdk ?? WASMBuilder.detectSDK() ?? "swift-6.2.3-RELEASE_wasm"
        self.options = options
        self.builder = WASMBuilder(target: options.target, sdk: sdk)
        self.htmlTemplate = HTMLTemplate(target: options.target)
    }

    private func addClient(_ ws: WebSocket) {
        clientsLock.lock()
        connectedClients.append(ws)
        clientsLock.unlock()
    }

    private func removeClient(_ ws: WebSocket) {
        clientsLock.lock()
        connectedClients.removeAll { $0 === ws }
        clientsLock.unlock()
    }

    /// Snapshot the connected clients under the lock, then send outside it so
    /// `ws.send` (which can block briefly on a NIO write) does not extend the
    /// critical section.
    private func snapshotClients() -> [WebSocket] {
        clientsLock.lock()
        defer { clientsLock.unlock() }
        return connectedClients
    }

    func start() async throws {
        // Initial build
        print("[SwiftWUI] Building \(options.target)...")
        let result = builder.build()
        if !result.success {
            print("[SwiftWUI] Initial build failed:\n\(result.output)")
            print("[SwiftWUI] Starting server anyway — fix errors and save to rebuild.")
        } else {
            print("[SwiftWUI] Build succeeded in \(String(format: "%.1f", result.duration))s")
        }

        // Configure Vapor
        var env = try Environment.detect()
        env.arguments = ["serve", "--port", "\(options.port)", "--hostname", "0.0.0.0"]
        let app = try await Application.make(env)

        // Serve index.html at root
        let template = htmlTemplate
        let port = options.port
        app.get { req -> Response in
            let html = template.devHTML(port: port)
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: .init(string: html)
            )
        }

        // Serve PackageToJS output files
        let outputDir = builder.outputDirectory
        app.get("**") { req -> Response in
            let path = req.url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let filePath = outputDir + "/" + path

            guard FileManager.default.fileExists(atPath: filePath) else {
                return Response(status: .notFound, body: .init(string: "Not found: \(path)"))
            }

            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))

            var contentType = "application/octet-stream"
            if path.hasSuffix(".js") { contentType = "application/javascript" }
            else if path.hasSuffix(".wasm") { contentType = "application/wasm" }
            else if path.hasSuffix(".html") { contentType = "text/html" }
            else if path.hasSuffix(".css") { contentType = "text/css" }
            else if path.hasSuffix(".json") { contentType = "application/json" }
            else if path.hasSuffix(".d.ts") { contentType = "application/typescript" }

            return Response(
                status: .ok,
                headers: [
                    "Content-Type": contentType,
                    "Cache-Control": "no-cache",
                    "Access-Control-Allow-Origin": "*",
                ],
                body: .init(data: data)
            )
        }

        // WebSocket for hot reload
        app.webSocket("_dev") { [weak self] req, ws in
            self?.addClient(ws)
            ws.send("{\"type\":\"connected\"}")
            ws.onClose.whenComplete { [weak self] _ in
                self?.removeClient(ws)
            }
        }

        // Start file watcher
        let watcher = FileWatcher { [weak self] in
            self?.rebuild()
        }
        watcher.watch(directory: options.watchPath)

        print("[SwiftWUI] Dev server running at http://localhost:\(options.port)")

        if options.openBrowser {
            #if os(macOS)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["http://localhost:\(options.port)"]
            try? proc.run()
            #endif
        }

        try await app.execute()
    }

    /// Last successful build's artefact manifest. Filename → SHA-256 hex.
    /// Sent to dev clients on every successful rebuild so they can decide
    /// whether to reload at all (fswatch routinely fires several times for
    /// a single editor save) and, in future, do granular updates (CSS-only
    /// stylesheet swap, asset cache bust, etc.) without a full page reload.
    private var lastManifest: [String: String] = [:]

    func rebuild() {
        print("[SwiftWUI] File changed, rebuilding...")
        broadcast("{\"type\":\"building\"}")

        let result = builder.build()

        if result.success {
            print("[SwiftWUI] Rebuild succeeded in \(String(format: "%.1f", result.duration))s")

            let manifest = computeManifest()
            lastManifest = manifest
            broadcast("{\"type\":\"reload\",\"manifest\":\(manifestJSONString(manifest))}")
        } else {
            print("[SwiftWUI] Rebuild failed")
            let escaped = result.output
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            broadcast("{\"type\":\"error\",\"message\":\"\(escaped)\"}")
        }
    }

    /// Walk the PackageToJS output directory and return a `{filename: sha256}`
    /// map for every emitted `.wasm` / `.js` / `.html` artefact. Hashes are
    /// SHA-256 hex (32 bytes / 64 hex chars). The dev client uses these only
    /// for equality, not cryptographic SRI — that lives in production builds.
    private func computeManifest() -> [String: String] {
        let fm = FileManager.default
        let dir = builder.outputDirectory
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return [:] }

        var manifest: [String: String] = [:]
        for name in entries
        where name.hasSuffix(".wasm")
            || name.hasSuffix(".js")
            || name.hasSuffix(".html") {
            let path = dir + "/" + name
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            manifest[name] = sha256Hex(data)
        }
        return manifest
    }

    /// Render a manifest to JSON without pulling in JSONEncoder. The map is
    /// small (a handful of entries) and the values are constrained to hex
    /// digits, so manual escaping is sufficient.
    private func manifestJSONString(_ manifest: [String: String]) -> String {
        let parts = manifest
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\"\(jsonEscape(key))\":\"\(value)\""
            }
        return "{\(parts.joined(separator: ","))}"
    }

    private func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// SHA-256 over a Data blob, encoded as lowercase hex.
    /// Uses swift-crypto, which Vapor pulls in transitively, so no new dep.
    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func broadcast(_ message: String) {
        for ws in snapshotClients() {
            ws.send(message)
        }
    }
}
