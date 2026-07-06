import TutorialKit
import SwiftWUI

#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: TutorialSite ssg --out <dir>")
            return
        }
        args.removeFirst()
        var out = "dist"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(TutorialApp.self, config: .init(
            outDir: out,
            mode: .hydrate(wasmScriptPath: "/app/index.js"),
            paths: Curriculum.ssgPaths))
        print("generated \(report.pages.count) pages, skipped \(report.skippedPatterns)")
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
