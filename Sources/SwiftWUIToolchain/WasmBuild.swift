import Foundation

public enum WasmSDK {
    /// Repo pin (CLAUDE.md): host toolchain and SDK versions must match exactly.
    public static let pinned = "swift-6.3.3-RELEASE_wasm"

    public static func detect(runner: ProcessRunner) throws -> String {
        let r = try runner.run("swift", ["sdk", "list"], cwd: nil, streamOutput: false)
        let ids = r.stdout.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        if ids.contains(pinned) { return pinned }
        if let id = ids.first(where: { $0.contains("wasm") && !$0.contains("embedded") }) { return id }
        throw ToolchainError.noWasmSDK(hint:
            "Install the Swift.org WASM SDK matching your toolchain exactly (expected \(pinned)): " +
            "see the Swift SDK bundles on swift.org/download, then `swift sdk install <artifactbundle url>`.")
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
        try? fm.removeItem(atPath: outDir + "/index.html")
        try fm.copyItem(atPath: projectDir + "/index.html", toPath: outDir + "/index.html")
        let projectShim = projectDir + "/vendor/wasi-shim"
        let shimSource = fm.fileExists(atPath: projectShim)
            ? projectShim
            : ToolchainResources.url("vendor/wasi-shim").path
        try? fm.removeItem(atPath: outDir + "/vendor/wasi-shim")
        try fm.createDirectory(atPath: outDir + "/vendor", withIntermediateDirectories: true)
        try fm.copyItem(atPath: shimSource, toPath: outDir + "/vendor/wasi-shim")
    }
}
