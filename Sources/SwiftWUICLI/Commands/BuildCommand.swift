import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build the wasm bundle and assemble dist/ (index.html + app/ + vendor/).")

    // `configuration` collides with ParsableCommand's static — store under `config`,
    // expose the conventional -c/--configuration surface via custom names.
    @Option(name: [.customShort("c"), .customLong("configuration")], help: "Build configuration.")
    var config: String = "release"
    @Option(name: .long, help: "Output directory.") var out: String = "dist"
    @Option(name: .long, help: "Swift SDK id (default: auto-detect).") var swiftSdk: String?

    func run() throws {
        let runner = FoundationProcessRunner()
        let cwd = FileManager.default.currentDirectoryPath
        let sdk = try swiftSdk ?? WasmSDK.detect(runner: runner)
        if config == "release" && !ReleaseArtifacts.toolAvailable("wasm-opt", runner: runner) {
            print("""

            ================================================================
            WARNING: wasm-opt not found — release wasm ships ~2.5x larger
            (≈22 MB vs ≈9 MB optimized). Install binaryen to shrink it:
              macOS:  brew install binaryen
              Linux:  your distro's binaryen package (apt/dnf/pacman)
            Building unoptimized.
            ================================================================

            """)
        }
        let bundle = try WasmBuilder(runner: runner, projectDir: cwd, sdk: sdk)
            .build(configuration: config)
        let outDir = cwd + "/" + out
        try DistLayout.assemble(projectDir: cwd, bundleDir: bundle, outDir: outDir)
        if try PWAAssets.generateManifest(distDir: outDir) {
            print("generated sw-assets.js (PWA precache manifest)")
        }
        if config == "release" {
            let s = try ReleaseArtifacts.compress(distDir: outDir, runner: runner)
            try ReleaseArtifacts.writeNginxConf(distDir: outDir)
            print("precompressed \(s.gzipped) file(s) (\(s.brotliAvailable ? "gzip + brotli" : "gzip only")); wrote nginx.conf")
        } else {
            try ReleaseArtifacts.clean(distDir: outDir)
        }
        print("built \(out)/ (app bundle + vendor shim + index.html)")
    }
}
