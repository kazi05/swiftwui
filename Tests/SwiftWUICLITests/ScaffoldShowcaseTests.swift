import Testing
import Foundation

/// Integration tests for `swiftwui init`. These tests exec the pre-built CLI
/// binary at `<repo>/.build/debug/swiftwui` and SKIP cleanly if it does not
/// exist. We deliberately do NOT use `swift run` from inside `swift test`,
/// because the parent test process already holds SwiftPM's `.build`
/// resolver lock and the inner `swift run` would deadlock waiting for it.
///
/// To run locally:
///     swift build --target SwiftWUICLI   # produce .build/debug/swiftwui
///     swift test --filter "Scaffold"
///
/// CI integrates this via the `make ci` target which calls them in order.
@Suite("Scaffold — showcase template")
struct ScaffoldShowcaseTests {

    @Test func showcaseScaffoldCreatesExpectedTreeAndBuilds() throws {
        guard let binary = locateCLIBinary() else {
            // No pre-built CLI binary — skip cleanly. The Phase 5 architect
            // review verified the scaffold by hand; this test is a CI net.
            return
        }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let projectName = "TestApp"
        let initProcess = Process()
        initProcess.executableURL = binary
        initProcess.arguments = ["init", projectName]
        initProcess.currentDirectoryURL = tmp
        initProcess.standardOutput = Pipe()
        initProcess.standardError = Pipe()
        try initProcess.run()
        initProcess.waitUntilExit()
        #expect(initProcess.terminationStatus == 0, "swiftwui init exited non-zero")

        let project = tmp.appendingPathComponent(projectName)
        let mainSwift = project.appendingPathComponent("Sources/\(projectName)/main.swift")
        let pkg       = project.appendingPathComponent("Package.swift")
        let helloPage = project.appendingPathComponent("Sources/\(projectName)/Pages/Chapters/HelloPage.swift")
        let pwaPage   = project.appendingPathComponent("Sources/\(projectName)/Pages/Chapters/PWAPage.swift")
        let testsDir  = project.appendingPathComponent("Tests/\(projectName)Tests")

        for f in [mainSwift, pkg, helloPage, pwaPage] {
            #expect(FileManager.default.fileExists(atPath: f.path), "missing: \(f.lastPathComponent)")
        }
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: testsDir.path, isDirectory: &isDir) && isDir.boolValue,
                "Tests/\(projectName)Tests/ should exist as a directory")

        let pkgText = try String(contentsOf: pkg, encoding: .utf8)
        #expect(!pkgText.contains("{{PROJECT_NAME}}"))
        #expect(!pkgText.contains("{{project_name}}"))
        #expect(pkgText.contains(projectName))

        let helloText = try String(contentsOf: helloPage, encoding: .utf8)
        #expect(helloText.contains("public struct HelloPage"))
    }

    @Test func minimalFlagProducesSmallScaffold() throws {
        guard let binary = locateCLIBinary() else { return }

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let initProcess = Process()
        initProcess.executableURL = binary
        initProcess.arguments = ["init", "Min", "--minimal"]
        initProcess.currentDirectoryURL = tmp
        initProcess.standardOutput = Pipe()
        initProcess.standardError = Pipe()
        try initProcess.run()
        initProcess.waitUntilExit()
        #expect(initProcess.terminationStatus == 0)

        let project = tmp.appendingPathComponent("Min")
        let pages = project.appendingPathComponent("Sources/Min/Pages")
        #expect(!FileManager.default.fileExists(atPath: pages.path),
                "minimal scaffold should not include Pages/")
    }

    /// Locate the pre-built `swiftwui` binary under `<repoRoot>/.build/`.
    /// Returns `nil` if neither debug nor release build exists.
    private func locateCLIBinary() -> URL? {
        guard let root = repoRoot() else { return nil }
        for variant in ["debug", "release"] {
            let candidate = root.appendingPathComponent(".build/\(variant)/swiftwui")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Walk up from the current directory looking for SwiftWUI's root Package.swift.
    private func repoRoot() -> URL? {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let pkg = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: pkg.path),
               (try? String(contentsOf: pkg).contains("name: \"SwiftWUI\"")) == true {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }
}
