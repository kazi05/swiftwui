// SwiftWUI.swift - Unified CLI entry point.
//
// Replaces the old `swiftwui-init` and `swiftwui-dev` executables. Single
// binary with subcommands so users invoke `swiftwui dev`, `swiftwui build`,
// `swiftwui init`, `swiftwui doctor` instead of two distinct tools with a
// hand-rolled argument parser.

import ArgumentParser
import Foundation

// MARK: - Shared option structs consumed by DevServer / ProductionBuilder.

struct DevOptions {
    var target: String
    var port: Int = 8080
    var sdk: String?
    var watchPath: String = "Sources"
    var openBrowser: Bool = false
}

struct BuildOptions {
    var target: String
    var output: String = "dist"
    var sdk: String?
    var optimize: OptimizeLevel = .default
}

enum OptimizeLevel: String {
    case `default`
    case size
    case aggressive
}

@main
struct SwiftWUICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftwui",
        abstract: "Build and ship Swift web apps that compile to WebAssembly.",
        version: "0.1.0-dev",
        subcommands: [
            Init.self,
            Dev.self,
            Build.self,
            Doctor.self,
        ],
        defaultSubcommand: nil
    )
}

// MARK: - Subcommand: init

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Scaffold a new SwiftWUI project."
    )

    @Argument(help: "Project name (letters, digits, hyphens, underscores).")
    var projectName: String

    @Flag(name: .long, help: "Use the minimal Counter-style scaffold instead of the showcase template.")
    var minimal: Bool = false

    func run() throws {
        guard isValidProjectName(projectName) else {
            throw ValidationError(
                "Project name must contain only letters, numbers, hyphens, and underscores."
            )
        }
        let mode: FileGenerator.Mode = minimal ? .minimal : .showcase
        let generator = FileGenerator(projectName: projectName, mode: mode)
        try generator.generate()
        print("""

        Project '\(projectName)' created (\(mode == .minimal ? "minimal" : "showcase") template).

        Next steps:
          cd \(projectName)
          swiftwui dev --target \(projectName)

        Then open http://localhost:8080.
        """)
    }

    private func isValidProjectName(_ name: String) -> Bool {
        !name.isEmpty
            && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

// MARK: - Subcommand: dev

struct Dev: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dev",
        abstract: "Run the development server with hot reload."
    )

    @Option(name: .shortAndLong, help: "Executable target to build and serve.")
    var target: String

    @Option(name: .shortAndLong, help: "HTTP port to bind.")
    var port: Int = 8080

    @Option(help: "swiftwasm SDK identifier (auto-detected if omitted).")
    var sdk: String?

    @Option(help: "Directory to watch for changes.")
    var watch: String = "Sources"

    @Flag(name: .long, help: "Open the project in the default browser on start.")
    var open: Bool = false

    func run() async throws {
        let options = DevOptions(
            target: target,
            port: port,
            sdk: sdk,
            watchPath: watch,
            openBrowser: open
        )
        let server = DevServer(options: options)
        try await server.start()
    }
}

// MARK: - Subcommand: build

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Produce an optimised release build."
    )

    @Option(name: .shortAndLong, help: "Executable target to build.")
    var target: String

    @Option(name: .shortAndLong, help: "Output directory for the build artefacts.")
    var output: String = "dist"

    @Option(help: "swiftwasm SDK identifier (auto-detected if omitted).")
    var sdk: String?

    @Option(help: "Optimisation level: default | size | aggressive.")
    var optimize: String = "size"

    func run() throws {
        let level: OptimizeLevel
        switch optimize.lowercased() {
        case "default": level = .default
        case "size":    level = .size
        case "aggressive", "agg": level = .aggressive
        default:
            throw ValidationError("--optimize must be one of: default, size, aggressive")
        }
        let options = BuildOptions(
            target: target,
            output: output,
            sdk: sdk,
            optimize: level
        )
        ProductionBuilder(options: options).build()
    }
}

// MARK: - Subcommand: doctor

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that all required toolchain components are installed."
    )

    func run() throws {
        var allOK = true

        check("swift",      "swift --version") { allOK = $0 && allOK }
        check("wasm-opt",   "wasm-opt --version") { allOK = $0 && allOK }
        check("brotli",     "brotli --version") { allOK = $0 && allOK }
        check("gzip",       "gzip --version") { allOK = $0 && allOK }
        check("openssl",    "openssl version") { allOK = $0 && allOK }
        check("fswatch",    "fswatch --version") { allOK = $0 && allOK }

        if let sdk = WASMBuilder.detectSDK() {
            print("✓ swiftwasm SDK installed: \(sdk)")
        } else {
            print("✗ swiftwasm SDK not found. Install via: swift sdk install <url>")
            print("  See: https://book.swiftwasm.org/getting-started/setup.html")
            allOK = false
        }

        checkShowcaseTemplateSync(&allOK)

        if !allOK {
            print("\nSome dependencies are missing. Install hints above.")
            throw ExitCode.failure
        }
        print("\nAll required tools installed.")
    }

    private func check(_ name: String, _ command: String, _ done: (Bool) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let ok = process.terminationStatus == 0
            print(ok ? "✓ \(name)" : "✗ \(name) (\(command) exited non-zero)")
            done(ok)
        } catch {
            print("✗ \(name) (not found on PATH)")
            done(false)
        }
    }

    private static func locateRepoRoot() -> URL? {
        // Walk up from the binary location looking for a directory that contains
        // both `Examples/Showcase` and `Sources/SwiftWUICLI/Templates`, which
        // together uniquely identify the SwiftWUI repo root. Cap the walk at 8
        // levels to avoid scanning the entire filesystem on a mis-configured PATH.
        var url = URL(fileURLWithPath: CommandLine.arguments[0])
            .standardizedFileURL
            .deletingLastPathComponent()
        for _ in 0..<8 {
            let exShowcase = url.appendingPathComponent("Examples/Showcase").path
            let cliTemplates = url.appendingPathComponent("Sources/SwiftWUICLI/Templates").path
            if FileManager.default.fileExists(atPath: exShowcase),
               FileManager.default.fileExists(atPath: cliTemplates) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private func checkShowcaseTemplateSync(_ allOK: inout Bool) {
        guard let root = Self.locateRepoRoot() else {
            // No dev tree found — running from an installed binary. The drift
            // check requires the live source tree and is not applicable here.
            print("• Showcase template drift check: skipped (not in dev tree)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.currentDirectoryURL = root
        process.arguments = [
            "-c",
            // Compare Examples/Showcase to the synced template, ignoring
            // directories that the sync target excludes and the placeholder
            // substitutions that sync introduces. A non-zero exit from `diff`
            // indicates drift.
            """
            diff -qr \\
                --exclude='.build' \\
                --exclude='Tests' \\
                --exclude='node_modules' \\
                --exclude='.swiftpm' \\
                --exclude='Package.resolved' \\
                --exclude='dist' \\
                Examples/Showcase Sources/SwiftWUICLI/Templates/showcase 2>/dev/null \\
                | grep -v '{{PROJECT_NAME}}' \\
                | grep -v '{{project_name}}' \\
                | head -1
            """
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = (try? stdout.fileHandleForReading.readToEnd()) ?? Data()
            let output = String(data: data ?? Data(), encoding: .utf8) ?? ""
            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("✓ Showcase template in sync with Examples/Showcase")
            } else {
                // Non-fatal warning: hard CI checks live in Phase 6.
                print("⚠︎ Showcase template differs from Examples/Showcase — run `make sync-templates`")
            }
        } catch {
            print("⚠︎ Could not verify showcase template sync (diff unavailable)")
        }
    }
}
