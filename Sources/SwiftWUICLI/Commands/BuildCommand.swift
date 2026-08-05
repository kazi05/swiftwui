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
        if let l10n = try L10nGenerator.generate(projectDir: cwd), l10n.changed {
            print("regenerated \(l10n.path)")
        }
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
        // Before the wasm build, never after: this is a HOST build of the same
        // sources, and a project that fails to compile exits non-zero here with
        // its diagnostics swallowed. The wasm build then prints the real error.
        let shell = try BootShellRunner.run(projectDir: cwd, runner: runner)
        let bundle = try WasmBuilder(runner: runner, projectDir: cwd, sdk: sdk)
            .build(configuration: config)
        let outDir = cwd + "/" + out
        try DistLayout.assemble(projectDir: cwd, bundleDir: bundle, outDir: outDir)
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
