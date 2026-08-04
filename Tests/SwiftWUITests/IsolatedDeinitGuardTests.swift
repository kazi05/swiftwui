import Testing
import Foundation

/// `SwiftWUI` and `SwiftWUIStatic` build with `.defaultIsolation(MainActor.self)`,
/// which makes every class's implicit `deinit` MainActor-isolated. Swift 6.3.2
/// and 6.3.3 crash (signal 11, `EarlyPerfInliner`) when optimizing such a deinit
/// for an Apple target — so `swift build -c release` dies on ANY class in these
/// two targets. Wasm targets are unaffected; the native CLI and `swift test -c
/// release` are not.
///
/// The workaround is one `nonisolated deinit { }` per class. No class in either
/// target has a deinit body, so the isolation buys nothing and costs an executor
/// hop per dealloc. This test fails the moment a new class arrives without it —
/// the crash itself cannot be reached from a debug test run.
@Suite struct IsolatedDeinitGuardTests {
    @Test func everyClassInTheMainActorTargetsOptsOutOfIsolatedDeinit() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        for target in ["SwiftWUI", "SwiftWUIStatic"] {
            let dir = root.appendingPathComponent("Sources/\(target)")
            let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" } ?? []
            for file in files {
                let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
                for (i, line) in lines.enumerated() {
                    let code = line.trimmingCharacters(in: .whitespaces)
                    guard !code.hasPrefix("//"), declaresAClass(code) else { continue }
                    // The opt-out sits inside the body: on the same line for a
                    // one-liner, else within the next few lines of the decl.
                    let window = lines[i..<min(i + 4, lines.count)].joined(separator: "\n")
                    if !window.contains("nonisolated deinit") {
                        offenders.append("\(file.lastPathComponent):\(i + 1) \(code)")
                    }
                }
            }
        }
        #expect(offenders.isEmpty, """
            These classes need `nonisolated deinit { }` as their first member — without it \
            `swift build -c release` crashes the compiler (see this file's doc comment). The \
            scan only looks at the four lines after the declaration, so keep it at the top:
            \(offenders.joined(separator: "\n"))
            """)
    }

    /// `class Name` at a declaration position — not `class=` in an HTML string,
    /// not `AnyClass`, not a doc comment.
    private func declaresAClass(_ code: String) -> Bool {
        guard let r = code.range(of: #"(^|[^A-Za-z_.])class [A-Z_]"#, options: .regularExpression) else { return false }
        // Anything before the match must be modifiers, never a string opener.
        return !code[code.startIndex..<r.lowerBound].contains("\"")
    }
}
