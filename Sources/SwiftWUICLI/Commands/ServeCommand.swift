import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Serve: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Statically preview a built site (no watcher, no dev injection).")

    @Argument(help: "Directory to serve.") var dir: String = "dist"
    @Option(name: .long, help: "Port to serve on.") var port: UInt16 = 8080
    @Flag(name: .long, help: "Set the dev flag so ?swui-boot=slow|fail|stall works against dist/. The flag also skips service-worker registration, so a PWA preview stops being faithful.")
    var bootDebug = false

    func run() throws {
        let root = URL(fileURLWithPath: dir, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path
        guard FileManager.default.fileExists(atPath: root) else { throw ToolchainError.io("'\(dir)' not found — run swiftwui build/ssg first") }
        let site = LocaleNegotiation.read(distDir: root)
        var files = StaticFiles.handler(urlPrefix: "/", root: root, spaFallback: true, localeSite: site)
        if bootDebug {
            files = DevInjection.bootDebugFlag(wrapping: files)
            // `__swiftwui_dev` is not single-purpose: DOMBackend also skips
            // service-worker registration under it, so a PWA dist served this
            // way is no longer the build it is meant to be previewing.
            print("warning: serving with boot debug enabled — the dev flag also skips "
                + "service-worker registration, so this is not a faithful production or PWA preview")
        }
        let server = HTTPServer(handlers: [files])
        try server.start(port: port)
        print("serving \(dir)/ at http://127.0.0.1:\(server.boundPort) (Ctrl-C to stop)")
        while true { Thread.sleep(forTimeInterval: 60) }
    }
}
