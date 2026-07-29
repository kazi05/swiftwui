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
        for f in ["Package.swift", "Sources/Entry.swift", "Sources/Locales/en.json",
                  "index.html", ".gitignore",
                  "Dockerfile", "Dockerfile.deploy", "nginx.conf", "README.md",
                  "vendor/wasi-shim/index.js", "vendor/wasi-shim/LICENSE-MIT"] {
            #expect(fm.fileExists(atPath: dir + "/" + f), "missing \(f)")
        }
        let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
        #expect(pkg.contains("name: \"MySite\""))
        #expect(!pkg.contains("{{"))                       // no unsubstituted placeholders
        let main = try String(contentsOfFile: dir + "/Sources/Entry.swift", encoding: .utf8)
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

    @Test(arguments: ["mvvm", "tca"]) func scaffoldArchitectureTemplates(template: String) throws {
        let dir = scratch()
        try Scaffolder.scaffold(template: template, name: "Arch", swiftwuiPath: repoRoot, into: dir)
        let main = try String(contentsOfFile: dir + "/Sources/Entry.swift", encoding: .utf8)
        #expect(!main.contains("{{"))
        #expect(main.contains("struct ArchApp: App"))
        #expect(main.contains(template == "mvvm" ? "CounterViewModel" : "func appReducer"))
        let readme = try String(contentsOfFile: dir + "/README.md", encoding: .utf8)
        #expect(readme.contains(template == "mvvm" ? "MVVM" : "TCA-style"))
    }

    /// A file literally named `main.swift` is top-level code, and `@main` cannot
    /// coexist with it. Every template ships `@main enum Entry`, so the moment a
    /// second source file appears — `Generated/L10n.swift`, or anything the user
    /// adds — the target stops compiling. The entry file must not be `main.swift`.
    @Test func scaffoldsTolerateASecondSourceFile() throws {
        for template in Scaffolder.templates {
            let dir = scratch()
            defer { try? FileManager.default.removeItem(atPath: dir) }
            try Scaffolder.scaffold(template: template, name: "Demo", swiftwuiPath: nil, into: dir)
            let sources = try FileManager.default.subpathsOfDirectory(atPath: dir + "/Sources")
            #expect(!sources.contains { $0 == "main.swift" || $0.hasSuffix("/main.swift") },
                    "template \(template) puts top-level code in main.swift")
            let entry = try String(contentsOfFile: dir + "/Sources/Entry.swift", encoding: .utf8)
            #expect(entry.contains("@main"), "template \(template) has no @main type")
        }
    }

    /// Every template ships a starter `Sources/Locales/en.json`, so `l10n add`
    /// — which seeds from an existing catalog and cannot create the first — works
    /// on a fresh project. The catalog has to be discoverable by the flat-layout
    /// owner scan, valid, and free of unsubstituted placeholders.
    @Test func scaffoldedCatalogGeneratesIntoTheTarget() throws {
        for template in Scaffolder.templates {
            let dir = scratch()
            defer { try? FileManager.default.removeItem(atPath: dir) }
            try Scaffolder.scaffold(template: template, name: "Demo", swiftwuiPath: nil, into: dir)

            let catalog = try String(contentsOfFile: dir + "/Sources/Locales/en.json", encoding: .utf8)
            #expect(!catalog.contains("{{"), "template \(template) left a placeholder in en.json")
            #expect(catalog.contains("\"Demo\""), "template \(template) did not substitute the name")

            #expect(L10nGenerator.localesOwner(projectDir: dir, target: nil) == dir + "/Sources")
            let outcome = try #require(try L10nGenerator.generate(projectDir: dir))
            #expect(outcome.path == dir + "/Sources/Generated/L10n.swift")
            let generated = try String(contentsOfFile: outcome.path, encoding: .utf8)
            #expect(generated.contains("public enum L10n"))
            #expect(generated.contains("counterClicks"))          // the plural key compiled through

            // SwiftPM would warn about unhandled files without this.
            let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
            #expect(pkg.contains("exclude: [\"Locales\"]"), "template \(template) does not exclude Locales")
        }
    }

    @Test func versionIsSemver() {
        #expect(SwiftWUIVersion.current.range(
            of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil)
    }

    @Test func scaffoldWithoutPathUsesGitHubDependency() throws {
        let dir = scratch()
        try Scaffolder.scaffold(template: "basic", name: "Remote", swiftwuiPath: nil, into: dir)
        let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
        #expect(pkg.contains(
            ".package(url: \"https://github.com/kazi05/swiftwui.git\", from: \"\(SwiftWUIVersion.current)\")"))
        #expect(!pkg.contains("{{"))
    }

    @Test func scaffoldWithPathKeepsLocalDependency() throws {
        let dir = scratch()
        try Scaffolder.scaffold(template: "basic", name: "Local", swiftwuiPath: repoRoot, into: dir)
        let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
        #expect(pkg.contains(".package(path: \""))
        #expect(!pkg.contains("github.com/kazi05/swiftwui"))
        #expect(!pkg.contains("{{"))
    }

    @Test func templatesScaffoldPublicDir() throws {
        for template in Scaffolder.templates {
            let dir = NSTemporaryDirectory() + "swiftwui-scaffold-pub-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: dir) }
            try Scaffolder.scaffold(template: template, name: "Demo", swiftwuiPath: nil, into: dir)
            #expect(FileManager.default.fileExists(atPath: dir + "/public/favicon.svg"),
                    "template \(template) missing public/favicon.svg")
            let html = try String(contentsOfFile: dir + "/index.html", encoding: .utf8)
            #expect(html.contains("rel=\"icon\""), "template \(template) index.html missing favicon link")
        }
    }
}
