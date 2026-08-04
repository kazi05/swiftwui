import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct SSG: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ssg",
        abstract: "Prerender the site: runs the project's native `<App> ssg` entry (dual-entry pattern).")

    @Option(name: .long, help: "Output directory.") var out: String = "dist"
    @Option(name: .long, help: "Executable product (default: auto-detect).") var product: String?

    func run() throws {
        let runner = FoundationProcessRunner()
        let cwd = FileManager.default.currentDirectoryPath
        if let l10n = try L10nGenerator.generate(projectDir: cwd), l10n.changed {
            print("regenerated \(l10n.path)")
        }
        let name = try product ?? PackageInfo.executableProduct(in: cwd, runner: runner)
        let r = try runner.run("swift", ["run", name, "ssg", "--out", out], cwd: cwd, streamOutput: true)
        guard r.exitCode == 0 else { throw ExitCode(r.exitCode) }
        let outDir = cwd + "/" + out
        try DistLayout.copyPublic(projectDir: cwd, outDir: outDir)
        if try PWAAssets.generateManifest(distDir: outDir) {
            print("generated sw-assets.js (PWA precache manifest)")
        }
        // ssg rewrites index.html files; refresh .gz/.br so a stale
        // index.html.gz never shadows fresh markup under gzip_static.
        if ReleaseArtifacts.hasCompressedArtifacts(distDir: outDir) {
            let s = try ReleaseArtifacts.compress(distDir: outDir, runner: runner)
            print("refreshed \(s.gzipped) precompressed file(s) after ssg")
        }
        // `.negotiated` is the one strategy a plain static host cannot serve —
        // say so here, where the folders were just written, not in the docs only.
        if let site = LocaleNegotiation.read(distDir: outDir), site.isNegotiated {
            // This rewrites the file `swiftwui build -c release` just wrote, so the
            // signal has to be recomputed: leaving the default would silently strip
            // the wasm cache header off every `.negotiated` release, and these
            // documents carry `?v=` exactly like the build's does.
            try ReleaseArtifacts.writeNginxConf(distDir: outDir, site: site,
                                                wasmVersioned: ReleaseArtifacts
                                                    .auditWasmVersions(distDir: outDir).versioned)
            print("""
            NOTE: this site uses the .negotiated locale strategy — clean URLs with \
            per-locale folders. It requires a host that can rewrite by cookie/Accept-Language. \
            Wrote \(out)/nginx.conf; on GitHub Pages or bare S3 only '\(site.defaultLocale)' will be reachable.
            """)
        }
    }
}
