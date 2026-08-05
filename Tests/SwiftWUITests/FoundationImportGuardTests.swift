import Testing
import Foundation

/// `SwiftWUI` and `SwiftWUIDOM` are the two targets that compile into every wasm
/// bundle, and Swift emits autolink entries **per module, not per file**: one
/// umbrella `import Foundation` anywhere in `SwiftWUI` makes all ~250 of its
/// object files — and every module that imports it — request
/// `-lFoundationInternationalization -l_FoundationICU`. `lib_FoundationICU.a`
/// defines `icudt76_dat`, a single non-strippable data symbol carrying every ICU
/// locale table: **~36 MB added to every shipped wasm binary**.
///
/// That is exactly what happened on 2026-08-03, when `SHA256.swift` moved into
/// `SwiftWUI` carrying a bare `import Foundation`. Bundles went 8.4 MB → 45 MB
/// (Boosa: 48.9 MB raw / 12.7 MB brotli) with no source change to blame.
///
/// The guard is the one every other file in these targets already uses:
///
/// ```swift
/// #if canImport(FoundationEssentials)
/// import FoundationEssentials
/// #else
/// import Foundation
/// #endif
/// ```
///
/// `FoundationEssentials` carries `Data`, `URL`, `JSONEncoder` and friends
/// without any of the internationalisation machinery, so the wasm side takes the
/// first branch and links no ICU; hosts that lack the module fall back to the
/// umbrella, where the cost does not apply.
///
/// Host-only targets (`SwiftWUIStatic`, `SwiftWUIToolchain`, `SwiftWUICLI`) are
/// deliberately not scanned — they never reach a wasm bundle.
@Suite struct FoundationImportGuardTests {
    /// The modules whose autolink entry drags in `_FoundationICU`.
    /// `FoundationEssentials` is the sanctioned one and is absent here on purpose.
    static let banned: Set<String> = ["Foundation", "CoreFoundation", "FoundationInternationalization"]

    @Test func wasmTargetsImportFoundationOnlyBehindTheFoundationEssentialsGuard() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        for target in ["SwiftWUI", "SwiftWUIDOM"] {
            let dir = root.appendingPathComponent("Sources/\(target)")
            let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" }
                .sorted(by: { $0.path < $1.path }) ?? []
            for file in files {
                for (line, module) in Self.unguardedImports(in: try String(contentsOf: file, encoding: .utf8)) {
                    offenders.append("\(target)/\(file.lastPathComponent):\(line) import \(module)")
                }
            }
        }
        #expect(offenders.isEmpty, """
            These imports add ~36 MB of ICU data to every wasm bundle built from this framework \
            (see this file's doc comment for the mechanism). Wrap each one:

              #if canImport(FoundationEssentials)
              import FoundationEssentials
              #else
              import Foundation
              #endif

            and use `_FoundationData` (State/Storage.swift) where the umbrella `Data` was needed. \
            Note that `String(format:)` does NOT exist in FoundationEssentials — hand-roll it.
            \(offenders.joined(separator: "\n"))
            """)
    }

    /// Every banned import in `source` that is not inside the `#else` branch of a
    /// `#if canImport(FoundationEssentials)`.
    ///
    /// The `#else` branch specifically, not the block: an umbrella import in the
    /// `#if` branch runs precisely where `FoundationEssentials` exists — the wasm
    /// build — and costs the full 36 MB while looking guarded.
    ///
    /// Internal so the mutation check (`guardCatchesABareUmbrellaImport`) can
    /// exercise the rule without writing to the source tree.
    static func unguardedImports(in source: String) -> [(line: Int, module: String)] {
        // One entry per open `#if`: does its condition name FoundationEssentials,
        // and are we past its `#else`/`#elseif`?
        var blocks: [(isEssentialsGuard: Bool, inFallback: Bool)] = []
        var found: [(line: Int, module: String)] = []
        for (i, raw) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let code = raw.trimmingCharacters(in: .whitespaces)
            if code.hasPrefix("#if") {
                blocks.append((code.contains("canImport(FoundationEssentials)"), false))
            } else if code.hasPrefix("#else") || code.hasPrefix("#elseif") {
                if !blocks.isEmpty { blocks[blocks.count - 1].inFallback = true }
            } else if code.hasPrefix("#endif") {
                _ = blocks.popLast()
            } else if let module = importedModule(code), banned.contains(module) {
                let guarded = blocks.contains { $0.isEssentialsGuard && $0.inFallback }
                if !guarded { found.append((i + 1, module)) }
            }
        }
        return found
    }

    /// The first module component of an import declaration — `import Foundation`,
    /// `@_exported import Foundation`, `import Foundation.NSString` all yield
    /// `Foundation`. Comments and `import` inside a string never match.
    private static func importedModule(_ code: String) -> String? {
        guard !code.hasPrefix("//"),
              let r = code.range(of: #"^(@[A-Za-z_]+ )*import ([A-Za-z_][A-Za-z0-9_]*)"#,
                                 options: .regularExpression) else { return nil }
        return code[r].split(separator: " ").last.map { String($0.split(separator: ".")[0]) }
    }

    /// The guard is only worth having if it fails on the exact regression it was
    /// written for — a bare umbrella import, and one hiding in the wrong branch.
    @Test func guardCatchesABareUmbrellaImportAndAWrongBranchOne() {
        let bare = "import Foundation\n\nenum X {}\n"
        #expect(Self.unguardedImports(in: bare).map(\.module) == ["Foundation"])

        let wrongBranch = """
        #if canImport(FoundationEssentials)
        import Foundation
        #else
        import Foundation
        #endif
        """
        #expect(Self.unguardedImports(in: wrongBranch).map(\.line) == [2])

        let correct = """
        #if canImport(FoundationEssentials)
        import FoundationEssentials
        #else
        import Foundation
        #endif
        """
        #expect(Self.unguardedImports(in: correct).isEmpty)

        // A nested unrelated `#if` inside the fallback branch must not lose the guard.
        let nested = """
        #if canImport(FoundationEssentials)
        import FoundationEssentials
        #else
        #if arch(wasm32)
        import Foundation
        #endif
        #endif
        """
        #expect(Self.unguardedImports(in: nested).isEmpty)

        // An unrelated `#if` is no guard at all.
        let unrelated = "#if arch(wasm32)\nimport Foundation\n#endif\n"
        #expect(Self.unguardedImports(in: unrelated).map(\.line) == [2])
    }
}
