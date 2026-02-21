import Vapor
import Foundation

final class DevServer: @unchecked Sendable {
    let options: DevOptions
    let builder: WASMBuilder
    let htmlTemplate: HTMLTemplate
    var connectedClients: [WebSocket] = []

    init(options: DevOptions) {
        let sdk = options.sdk ?? WASMBuilder.detectSDK() ?? "swift-6.2.3-RELEASE_wasm"
        self.options = options
        self.builder = WASMBuilder(target: options.target, sdk: sdk)
        self.htmlTemplate = HTMLTemplate(target: options.target)
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
            self?.connectedClients.append(ws)
            ws.send("{\"type\":\"connected\"}")
            ws.onClose.whenComplete { [weak self] _ in
                self?.connectedClients.removeAll { $0 === ws }
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

    func rebuild() {
        print("[SwiftWUI] File changed, rebuilding...")
        broadcast("{\"type\":\"building\"}")

        let result = builder.build()

        if result.success {
            print("[SwiftWUI] Rebuild succeeded in \(String(format: "%.1f", result.duration))s")
            broadcast("{\"type\":\"reload\"}")
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

    func broadcast(_ message: String) {
        for ws in connectedClients {
            ws.send(message)
        }
    }
}
