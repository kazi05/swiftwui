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
            // has to trigger a rebuild exactly like editing a source file.
            for case let rel as String in e
            where rel.hasSuffix(".swift") || (rel.hasSuffix(".json") && rel.contains("/Locales/")) {
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
}
