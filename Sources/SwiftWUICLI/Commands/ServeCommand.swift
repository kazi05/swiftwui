import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Serve: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Statically preview a built site (no watcher, no dev injection).")

    @Argument(help: "Directory to serve.") var dir: String = "dist"
    @Option(name: .long, help: "Port to serve on.") var port: UInt16 = 8080
    @Flag(name: .long, help: "Set the dev flag so ?swui-boot=slow|fail|stall works against dist/.")
    var bootDebug = false

    func run() throws {
        let root = URL(fileURLWithPath: dir, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path
        guard FileManager.default.fileExists(atPath: root) else { throw ToolchainError.io("'\(dir)' not found — run swiftwui build/ssg first") }
        let site = LocaleNegotiation.read(distDir: root)
        var files = StaticFiles.handler(urlPrefix: "/", root: root, spaFallback: true, localeSite: site)
        if bootDebug {
            files = DevInjection.bootDebugFlag(wrapping: files)
            print("warning: serving with boot debug enabled — do not use for a production preview")
        }
        let server = HTTPServer(handlers: [files])
        try server.start(port: port)
        print("serving \(dir)/ at http://127.0.0.1:\(server.boundPort) (Ctrl-C to stop)")
        while true { Thread.sleep(forTimeInterval: 60) }
    }
}
