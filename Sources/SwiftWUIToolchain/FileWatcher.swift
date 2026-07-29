import Foundation

/// mtime polling — cross-platform by construction, no FSEvents/inotify forks (spec D9).
public final class FileWatcher {
    private let root: String
    private var baseline: [String: Date] = [:]
    public init(root: String) {
        self.root = root
        baseline = scan()
    }

    func scan() -> [String: Date] {
        var result: [String: Date] = [:]
        let fm = FileManager.default
        func stat(_ path: String) {
            if let mtime = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date {
                result[path] = mtime
            }
        }
        stat(root + "/Package.swift")
        stat(root + "/index.html")
        if let e = fm.enumerator(atPath: root + "/Sources") {
            // Catalogs too: editing Locales/*.json regenerates L10n.swift, so it
            // has to trigger a rebuild exactly like editing a source file. The
            // leading "/" matters: the enumerator yields paths relative to
            // Sources, so the flat layout arrives as "Locales/en.json".
            for case let rel as String in e
            where rel.hasSuffix(".swift") || (rel.hasSuffix(".json") && ("/" + rel).contains("/Locales/")) {
                stat(root + "/Sources/" + rel)
            }
        }
        return result
    }

    /// True when anything changed since the last call (file edited, added, or removed).
    public func changed() -> Bool {
        let now = scan()
        defer { baseline = now }
        return now != baseline
    }

    /// One cycle of the `swiftwui dev` watch loop, extracted so it can be tested
    /// without a real wasm build (`rebuild` is the seam).
    ///
    /// Ordering is the whole point: code generation runs BEFORE the debounce
    /// absorb, so its write to `Generated/L10n.swift` — itself a watched `.swift`
    /// file — is swallowed by the absorb that already exists. Absorbing after
    /// `rebuild` instead would swallow the entire build window, silently dropping
    /// every edit the user makes while the build runs.
    public func pollAndRebuild(projectDir: String, debounce: () -> Void, rebuild: () -> Void) {
        guard changed() else { return }
        debounce()
        // Errors are ignored here: `rebuild` runs the generator again and reports
        // a bad catalog the way it reports any other build failure.
        _ = try? L10nGenerator.generate(projectDir: projectDir)
        _ = changed()
        rebuild()
    }
}
