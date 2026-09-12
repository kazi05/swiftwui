import Foundation

public enum WasmSDK {
    /// Repo pin (CLAUDE.md): host toolchain and SDK versions must match exactly.
    public static let pinned = "swift-6.3.3-RELEASE_wasm"

    public struct Preflight: Equatable, Sendable {
        public var sdk: String
        public var hostVersion: String?
        public var sdkVersion: String?
        public var compilerVersion: String?
        /// Executables resolved in the build process environment. Keeping these
        /// in the report makes a PATH/shim mismatch actionable in CI logs.
        public var hostExecutable: String?
        public var compilerExecutable: String?

        public init(sdk: String, hostVersion: String?, sdkVersion: String?, compilerVersion: String?, hostExecutable: String? = nil, compilerExecutable: String? = nil) {
            self.sdk = sdk; self.hostVersion = hostVersion; self.sdkVersion = sdkVersion; self.compilerVersion = compilerVersion
            self.hostExecutable = hostExecutable; self.compilerExecutable = compilerExecutable
        }
    }

    public static func detect(runner: ProcessRunner, cwd: String? = nil) throws -> String {
        let r = try runner.run("swift", ["sdk", "list"], cwd: cwd, streamOutput: false)
        guard r.exitCode == 0 else {
            throw ToolchainError.noWasmSDK(hint: "`swift sdk list` failed: \(r.stderr.isEmpty ? r.stdout : r.stderr)")
        }
        let ids = r.stdout.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        if ids.contains(pinned) { return pinned }
        if let id = ids.first(where: { $0.contains("wasm") && !$0.contains("embedded") }) { return id }
        throw ToolchainError.noWasmSDK(hint:
            "Install the Swift.org WASM SDK matching your toolchain exactly (expected \(pinned)): " +
            "see the Swift SDK bundles on swift.org/download, then `swift sdk install <artifactbundle url>`.")
    }

    /// Resolves the SDK and the compiler through the same process environment used
    /// for the build. This deliberately accepts future matching toolchains: the
    /// repository pin is a supported default, not a ceiling on user overrides.
    public static func preflight(selectedSDK: String?, runner: ProcessRunner, cwd: String?) throws -> Preflight {
        let listed = try runner.run("swift", ["sdk", "list"], cwd: cwd, streamOutput: false)
        guard listed.exitCode == 0 else {
            throw ToolchainError.noWasmSDK(hint: "`swift sdk list` failed: \(listed.stderr.isEmpty ? listed.stdout : listed.stderr)")
        }
        let installed = listed.stdout.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let sdk = try selectedSDK ?? detect(runner: runner, cwd: cwd)
        guard installed.contains(sdk) else {
            throw ToolchainError.noWasmSDK(hint: "'\(sdk)' is not installed for the selected swift executable. Run `swift sdk list`, install that SDK, or pass an installed --swift-sdk id.")
        }
        guard sdk.contains("wasm"), !sdk.contains("embedded") else {
            throw ToolchainError.incompatibleToolchain("'\(sdk)' is not a WASM web SDK")
        }
        let host = try runner.run("swift", ["--version"], cwd: cwd, streamOutput: false)
        guard host.exitCode == 0 else {
            throw ToolchainError.incompatibleToolchain("`swift --version` failed: \(host.stderr.isEmpty ? host.stdout : host.stderr)")
        }
        // SwiftPM honors SWIFT_EXEC. Query that exact executable when it is set;
        // checking a different `swiftc` on PATH would give a false green result.
        let compilerCommand = ProcessInfo.processInfo.environment["SWIFT_EXEC"] ?? "swiftc"
        let compiler = try runner.run(compilerCommand, ["--version"], cwd: cwd, streamOutput: false)
        guard compiler.exitCode == 0 else {
            throw ToolchainError.incompatibleToolchain("`\(compilerCommand) --version` failed: \(compiler.stderr.isEmpty ? compiler.stdout : compiler.stderr)")
        }
        let hostVersion = swiftVersion(in: host.stdout + host.stderr)
        let compilerVersion = swiftVersion(in: compiler.stdout + compiler.stderr)
        let sdkVersion = swiftVersion(in: sdk)
        guard let hostVersion else {
            throw ToolchainError.incompatibleToolchain("could not parse a Swift release from `swift --version`: \(host.stdout + host.stderr)")
        }
        guard let compilerVersion else {
            throw ToolchainError.incompatibleToolchain("could not parse a Swift release from `\(compilerCommand) --version`: \(compiler.stdout + compiler.stderr)")
        }
        guard let sdkVersion else {
            throw ToolchainError.incompatibleToolchain("could not parse a Swift release from SDK id '\(sdk)'")
        }
        if hostVersion != compilerVersion {
            throw ToolchainError.incompatibleToolchain("swift is \(hostVersion), but swiftc is \(compilerVersion). Select one toolchain (for example set PATH and SWIFT_EXEC together).")
        }
        if hostVersion != sdkVersion {
            throw ToolchainError.incompatibleToolchain("swift is \(hostVersion), but SDK '\(sdk)' is \(sdkVersion). Install/select matching releases; mixed host/SDK builds are not reproducible.")
        }
        let hostExecutable = resolved("swift", runner: runner, cwd: cwd)
        let compilerExecutable = ProcessInfo.processInfo.environment["SWIFT_EXEC"] ?? resolved("swiftc", runner: runner, cwd: cwd)
        return Preflight(sdk: sdk, hostVersion: hostVersion, sdkVersion: sdkVersion, compilerVersion: compilerVersion,
                         hostExecutable: hostExecutable, compilerExecutable: compilerExecutable)
    }

    private static func resolved(_ executable: String, runner: ProcessRunner, cwd: String?) -> String {
        guard let result = try? runner.run("which", [executable], cwd: cwd, streamOutput: false), result.exitCode == 0 else { return executable }
        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? executable : value
    }

    private static func swiftVersion(in text: String) -> String? {
        let pattern = #"(?:swift[- ]|Swift version )([0-9]+\.[0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

public struct WasmBuilder {
    public var runner: ProcessRunner
    public var projectDir: String
    public var sdk: String
    public init(runner: ProcessRunner, projectDir: String, sdk: String) {
        self.runner = runner; self.projectDir = projectDir; self.sdk = sdk
    }

    // ponytail: dedicated scratch dir, not the shared `.build`. Mixing a native `swift
    // build`/`swift run` with a wasm `swift package --swift-sdk ... js` under the same
    // `.build` corrupts SwiftPM's `.build/debug` triple symlink (repro: native build,
    // then wasm build, then native `swift run` → "No target named ...-debug.exe").
    public static func bundleDir(projectDir: String) -> String {
        projectDir + "/.build-wasm/plugins/PackageToJS/outputs/Package"
    }

    /// Runs the JavaScriptKit PackageToJS plugin; returns the bundle directory.
    public func build(configuration: String) throws -> String {
        let scratchPath = projectDir + "/.build-wasm"
        let r = try runner.run("swift",
            ["package", "--swift-sdk", sdk, "--scratch-path", scratchPath, "js", "-c", configuration],
            cwd: projectDir, streamOutput: true)
        guard r.exitCode == 0 else { throw ToolchainError.buildFailed(output: r.stdout + r.stderr) }
        return Self.bundleDir(projectDir: projectDir)
    }
}

public enum DistLayout {
    /// dist/index.html + dist/app/ (bundle verbatim) + dist/vendor/wasi-shim/ (spec §4).
    /// Shim source: the project's checked-in vendor/ dir (scaffolded by init, Task 10),
    /// falling back to the CLI's bundled resources for non-scaffolded projects.
    public static func assemble(projectDir: String, bundleDir: String, outDir: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectDir + "/index.html") else {
            throw ToolchainError.io("'\(projectDir)' has no index.html — swiftwui build needs the project's index.html to assemble dist/")
        }
        try? fm.removeItem(atPath: outDir + "/app")
        try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try fm.copyItem(atPath: bundleDir, toPath: outDir + "/app")
        try copyBootShim(outDir: outDir)
        try? fm.removeItem(atPath: outDir + "/index.html")
        try fm.copyItem(atPath: projectDir + "/index.html", toPath: outDir + "/index.html")
        let projectShim = projectDir + "/vendor/wasi-shim"
        let shimSource = fm.fileExists(atPath: projectShim)
            ? projectShim
            : ToolchainResources.url("vendor/wasi-shim").path
        try? fm.removeItem(atPath: outDir + "/vendor/wasi-shim")
        try fm.createDirectory(atPath: outDir + "/vendor", withIntermediateDirectories: true)
        try fm.copyItem(atPath: shimSource, toPath: outDir + "/vendor/wasi-shim")
        try copyPublic(projectDir: projectDir, outDir: outDir)
    }

    /// Part of the bundle directory, not of the boot opt-in: `A.bootUI` may be
    /// `.none` while a single `Page.bootUI` is an overlay, and it is the SSG
    /// that decides per page. Gating this on the SPA-level answer 404s the shim
    /// for that page — which does not surface as the shim's failure UI, since
    /// nothing runs to produce one: the page just renders static and never
    /// hydrates. An unreferenced 13 KB file in dist/app is the cheaper mistake.
    ///
    /// Not in `reservedNames`: that list guards dist-ROOT names against
    /// top-level public/ entries, and the shim lives under the already-reserved
    /// `app`.
    static func copyBootShim(outDir: String) throws {
        for name in ["swiftwui-boot.js", "swiftwui-worker.js"] {
            let src = ToolchainResources.url(name).path
            let dst = outDir + "/app/" + name
            try? FileManager.default.removeItem(atPath: dst)
            try FileManager.default.copyItem(atPath: src, toPath: dst)
        }
    }

    public static let reservedNames: Set<String> = ["app", "vendor", "index.html", "styles.css", "__swiftwui", "sw-assets.js", "nginx.conf", "swiftwui-site.json", "swiftwui-delivery.json", "swiftwui-redirects.conf", "swiftwui-build-report.json", AssetPipeline.manifestName]

    /// Top-level public/ entries that would shadow the framework's dist layout (spec §1).
    public static func reservedCollisions(projectDir: String) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: projectDir + "/public")) ?? []
        return entries.filter { reservedNames.contains($0) }.sorted()
    }

    /// Copy every top-level child of public/ into outDir (spec §4). Replaces
    /// each target child; never wipes outDir itself (it holds app/ + vendor/).
    public static func copyPublic(projectDir: String, outDir: String) throws {
        let fm = FileManager.default
        let publicDir = projectDir + "/public"
        guard fm.fileExists(atPath: publicDir) else { return }
        let collisions = reservedCollisions(projectDir: projectDir)
        guard collisions.isEmpty else {
            throw ToolchainError.io("public/ contains reserved name(s) \(collisions.joined(separator: ", ")) — these collide with the framework's dist layout (reserved: \(reservedNames.sorted().joined(separator: ", ")))")
        }
        try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        for entry in try fm.contentsOfDirectory(atPath: publicDir).sorted() {
            try? fm.removeItem(atPath: outDir + "/" + entry)
            try fm.copyItem(atPath: publicDir + "/" + entry, toPath: outDir + "/" + entry)
        }
    }
}
