import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Dev: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build, serve and hot-reload the current project.")

    @Option(name: .long, help: "Port to serve on.") var port: UInt16 = 8080
    @Option(name: .long, help: "Swift SDK id (default: auto-detect).") var swiftSdk: String?

    func run() throws {
        let runner = FoundationProcessRunner()
        let cwd = FileManager.default.currentDirectoryPath
        guard FileManager.default.fileExists(atPath: cwd + "/Package.swift") else {
            throw ToolchainError.notAProject(cwd)
        }
        let sdk = try swiftSdk ?? WasmSDK.detect(runner: runner)
        let builder = WasmBuilder(runner: runner, projectDir: cwd, sdk: sdk)
        let hub = SSEHub()
        let session = DevSession(builder: builder, hub: hub)

        print("building (\(sdk))…")
        session.rebuildAndNotify()   // first build; on failure the overlay shows it on connect
        let bundleDir = WasmBuilder.bundleDir(projectDir: cwd)

        let server = HTTPServer(handlers: session.handlers(projectDir: cwd, bundleDir: bundleDir))
        try server.start(port: port)
        print("serving http://127.0.0.1:\(server.boundPort) — watching Sources/ (Ctrl-C to stop)")

        let watcher = FileWatcher(root: cwd)
        while true {                                    // main thread IS the watch loop
            Thread.sleep(forTimeInterval: 0.5)          // poll interval (spec §6)
            if watcher.changed() {
                Thread.sleep(forTimeInterval: 0.2)      // debounce: let the editor finish writing
                _ = watcher.changed()                   // absorb the debounce window
                print("change detected — rebuilding…")
                session.rebuildAndNotify()
            }
        }
    }
}
