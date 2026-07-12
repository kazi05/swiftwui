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
        let bundle = try WasmBuilder(runner: runner, projectDir: cwd, sdk: sdk)
            .build(configuration: config)
        try DistLayout.assemble(projectDir: cwd, bundleDir: bundle, outDir: cwd + "/" + out)
        if try PWAAssets.generateManifest(distDir: cwd + "/" + out) {
            print("generated sw-assets.js (PWA precache manifest)")
        }
        print("built \(out)/ (app bundle + vendor shim + index.html)")
    }
}
