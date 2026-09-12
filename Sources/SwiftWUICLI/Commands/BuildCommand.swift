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
    @Option(name: .long, help: "Name of the fixture recorded in the build report.") var fixture: String = "app"
    @Option(name: .long, help: "Optional JSON size budget (default: swiftwui-wasm-budget.json when present).") var budget: String?

    func run() throws {
        let runner = FoundationProcessRunner()
        let cwd = FileManager.default.currentDirectoryPath
        if let l10n = try L10nGenerator.generate(projectDir: cwd), l10n.changed {
            print("regenerated \(l10n.path)")
        }
        let preflight = try WasmSDK.preflight(selectedSDK: swiftSdk, runner: runner, cwd: cwd)
        let sdk = preflight.sdk
        print("toolchain: swift \(preflight.hostVersion ?? "unknown") · sdk \(sdk)")
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
        // Before the wasm build, never after: this is a HOST build of the same
        // sources, and a project that fails to compile exits non-zero here with
        // its diagnostics swallowed. The wasm build then prints the real error.
        let shell = try BootShellRunner.run(projectDir: cwd, runner: runner)
        // Variants are written under public/ and must exist before assembly copies
        // public/ into dist. Manifest generation below runs after assembly.
        _ = try AssetPipeline.prepare(projectDir: cwd, runner: runner)
        let bundle = try WasmBuilder(runner: runner, projectDir: cwd, sdk: sdk)
            .build(configuration: config)
        let outDir = cwd + "/" + out
        try DistLayout.assemble(projectDir: cwd, bundleDir: bundle, outDir: outDir)
        if let assets = try AssetPipeline.writePreparedManifest(projectDir: cwd, outDir: outDir) {
            print("generated \(AssetPipeline.manifestName) (\(assets.images.count) responsive image set(s))")
        }
        // Between `assemble` and `generateManifest`, and the order is not
        // negotiable: `assemble` re-copies index.html over any earlier splice;
        // after `generateManifest` the manifest's SRI covers the pre-splice
        // index.html and every PWA install fails its integrity check; after
        // `compress` the .gz sibling gzip_static serves is the boot-less one.
        try BootSplice.write(outDir: outDir, shell: shell)
        // Only the root index.html was just rewritten. Prerenders from an earlier
        // `swiftwui ssg` still name the previous wasm version, and they keep
        // asking for it forever — so say so here (debug builds included, where
        // the prerenders are just as stale) and drop the immutable header below.
        let audit = ReleaseArtifacts.auditWasmVersions(distDir: outDir)
        if let first = audit.stale.first {
            print("warning: dist holds \(audit.stale.count) prerendered page(s) stamped for an older "
                + "binary (e.g. \(first)) — run 'swiftwui ssg'; wasm caching stays off until they agree")
        }
        if try PWAAssets.generateManifest(distDir: outDir) {
            print("generated sw-assets.js (PWA precache manifest)")
        }
        if config == "release" {
            let s = try ReleaseArtifacts.compress(distDir: outDir, runner: runner)
            try ReleaseArtifacts.writeNginxConf(distDir: outDir,
                                                site: LocaleNegotiation.read(distDir: outDir),
                                                wasmVersioned: audit.versioned)
            print("precompressed \(s.gzipped) file(s) (\(s.brotliAvailable ? "gzip + brotli" : "gzip only")); wrote nginx.conf")
        } else {
            try ReleaseArtifacts.clean(distDir: outDir)
        }
        let report = try WasmMetrics.report(distDir: outDir, fixture: fixture, configuration: config,
                                            preflight: preflight, runner: runner)
        let reportPath = outDir + "/swiftwui-build-report.json"
        try WasmMetrics.write(report, to: reportPath)
        let budgetPath = budget.map { path in path.hasPrefix("/") ? path : cwd + "/" + path } ?? cwd + "/swiftwui-wasm-budget.json"
        if let configured = try WasmMetrics.readBudget(path: budgetPath) {
            try WasmMetrics.enforce(configured, against: report)
            print("validated WASM budget \(budgetPath)")
        } else if budget != nil {
            throw ToolchainError.io("budget file does not exist: \(budgetPath)")
        }
        print("WASM: \(report.rawBytes) raw, \(report.gzipBytes.map(String.init) ?? "n/a") gzip, \(report.brotliBytes.map(String.init) ?? "n/a") brotli; report: \(out)/swiftwui-build-report.json")
        print("built \(out)/ (app bundle + vendor shim + index.html)")
        // Last, and after the success line on purpose: the wasm-opt warning above
        // gets buried under the build's own output, and 36 MB of ICU data is not
        // something to bury. Warn, never fail — an app that genuinely needs
        // Locale or Calendar must still build. Release only; debug is not shipped.
        if config == "release",
           let icu = ReleaseArtifacts.auditICU(distDir: outDir, projectDir: cwd, configuration: config) {
            print(ReleaseArtifacts.icuWarningText(icu))
        }
    }
}
