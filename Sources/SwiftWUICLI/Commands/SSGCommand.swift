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
    }
}
