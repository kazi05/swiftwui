import TutorialKit
import SwiftWUI

#if canImport(SwiftWUIStatic)
import Foundation
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        if args.first == "boot-shell" {
            // One tagged line on stdout — `swiftwui build` identifies the answer
            // by that key, not by exit status. Without this branch a declared
            // boot overlay is silently dropped from the build.
            let shell = StaticSite.renderBootShell(TutorialApp.self)
            print(String(decoding: try JSONEncoder().encode(shell), as: UTF8.self))
            return
        }
        guard args.first == "ssg" else {
            print("usage: TutorialSite ssg --out <dir>")
            print("       TutorialSite boot-shell")
            return
        }
        args.removeFirst()
        var out = "dist"
        // Canonical links and sitemap.xml both need an absolute origin. It stays
        // a flag rather than a constant so a preview deploy can claim its own.
        var siteURL: String? = "https://swiftwui.dev/tutorials"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            case "--site-url":
                guard i + 1 < args.count else { print("--site-url needs a value"); return }
                i += 1; siteURL = args[i]
            case "--no-site-url": siteURL = nil
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(TutorialApp.self, config: .init(
            outDir: out,
            mode: .hydrate(wasmScriptPath: "/app/index.js"),
            paths: Curriculum.ssgPaths,
            siteURL: siteURL))
        print("generated \(report.pages.count) pages, skipped \(report.skippedPatterns)")
        print("sitemap: \(report.sitemapFiles.isEmpty ? "not generated (no --site-url)" : report.sitemapFiles.joined(separator: ", "))")
        if !report.unmatchedPaths.isEmpty {
            print("UNMATCHED paths (config typo?): \(report.unmatchedPaths)")
        }
    }
}
#else
import SwiftWUIDOM

@main enum Entry {
    static func main() { TutorialApp.main() }
}
#endif
