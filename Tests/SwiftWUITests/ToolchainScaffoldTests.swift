import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainScaffoldTests {
    func scratch() -> String { NSTemporaryDirectory() + "swiftwui-init-\(UUID().uuidString)" }
    /// The repo root is a valid --swiftwui-path for tests.
    var repoRoot: String {
        // Tests run from the package dir; Package.swift sits at the root.
        FileManager.default.currentDirectoryPath
    }

    @Test func scaffoldBasicProducesFullProject() throws {
        let dir = scratch()
        try Scaffolder.scaffold(template: "basic", name: "MySite", swiftwuiPath: repoRoot, into: dir)
        let fm = FileManager.default
        for f in ["Package.swift", "Sources/main.swift", "index.html", ".gitignore",
                  "Dockerfile", "Dockerfile.deploy", "nginx.conf", "README.md",
                  "vendor/wasi-shim/index.js", "vendor/wasi-shim/LICENSE-MIT"] {
            #expect(fm.fileExists(atPath: dir + "/" + f), "missing \(f)")
        }
        let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
        #expect(pkg.contains("name: \"MySite\""))
        #expect(!pkg.contains("{{"))                       // no unsubstituted placeholders
        let main = try String(contentsOfFile: dir + "/Sources/main.swift", encoding: .utf8)
        #expect(main.contains("struct MySiteApp: App"))
        #expect(!main.contains("{{"))
    }

    @Test func refusesNonEmptyDirAndBadNames() throws {
        let dir = scratch()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "x".write(toFile: dir + "/junk", atomically: true, encoding: .utf8)
        #expect(throws: ToolchainError.self) {
            try Scaffolder.scaffold(template: "basic", name: "A", swiftwuiPath: repoRoot, into: dir)
        }
        #expect(throws: ToolchainError.self) {
            try Scaffolder.scaffold(template: "basic", name: "9lives", swiftwuiPath: repoRoot, into: scratch())
        }
        #expect(throws: ToolchainError.self) {
            try Scaffolder.scaffold(template: "nope", name: "Ok", swiftwuiPath: repoRoot, into: scratch())
        }
    }
}
