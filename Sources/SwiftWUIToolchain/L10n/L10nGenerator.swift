import Foundation

public enum L10nGeneratorError: Error, CustomStringConvertible {
    case checkFailed(path: String)
    case noLocalesDirectory
    case badTag(String)
    case localeExists(String)

    public var description: String {
        switch self {
        case .checkFailed(let p): return "\(p) is out of date — run `swiftwui l10n generate` and commit the result"
        case .noLocalesDirectory: return "no Sources/<Target>/Locales directory found"
        case .badTag(let t): return "'\(t)' is not a valid locale tag (expected e.g. 'ru' or 'pt-BR')"
        case .localeExists(let t): return "Locales/\(t).json already exists"
        }
    }
}

/// Filesystem side of code generation: find the catalogs, feed them to
/// `L10nCatalog`/`L10nEmitter`, decide whether to write.
public enum L10nGenerator {
    public struct Outcome {
        public let path: String
        public let changed: Bool
        public let warnings: [String]
    }

    /// The Sources/<Target> directory that owns a `Locales` folder.
    public static func localesOwner(projectDir: String, target: String?) -> String? {
        let sources = projectDir + "/Sources"
        let fm = FileManager.default
        if let target {
            // `target` is joined into a path that `addLocale` then writes into, so
            // it is a trust boundary: one component, no traversal, no separators.
            guard !target.isEmpty, !target.contains("/"), !target.contains("\\"),
                  !target.contains("..") else { return nil }
            let dir = sources + "/" + target
            return fm.fileExists(atPath: dir + "/Locales") ? dir : nil
        }
        guard let names = try? fm.contentsOfDirectory(atPath: sources) else { return nil }
        for name in names.sorted() where fm.fileExists(atPath: sources + "/" + name + "/Locales") {
            return sources + "/" + name
        }
        // Flat layout, checked only after the nested one so existing projects
        // cannot change owner: every `swiftwui init` template sets
        // `path: "Sources"`, which makes Sources itself the target directory —
        // so its catalogs live at Sources/Locales and Generated/ belongs beside
        // them. Without this, the path a scaffolded project would use is
        // silently ignored with the same message an unlocalized project gets.
        return fm.fileExists(atPath: sources + "/Locales") ? sources : nil
    }

    /// Locale tags must be safe as filenames and URL segments before they are
    /// ever used to build one — and they must ALSO be constructible as a
    /// `LocaleID`, because the emitter writes `LocaleID("<tag>")!` into the
    /// generated file: a tag this accepts but `LocaleID` rejects becomes a
    /// force-unwrap trap at app boot.
    ///
    /// `SwiftWUIToolchain` cannot import `SwiftWUI` (Package.swift:34), so the
    /// grammar lives in `L10nEmitter.canonicalTag` — the same module, already
    /// pinned against `LocaleID` by the test target, which sees both. Asking it
    /// is the only way this cannot disagree with the emitter about which
    /// filenames are legal; `tagValidationMatchesLocaleID` guards the pair.
    static func isValidTag(_ tag: String) -> Bool {
        (try? L10nEmitter.canonicalTag(tag)) != nil
    }

    /// Returns `nil` — rather than throwing — for a project with no catalogs:
    /// every monolingual app runs this on every `swiftwui build`.
    @discardableResult
    public static func generate(projectDir: String, target: String? = nil,
                                allowMissing: Bool = false, check: Bool = false) throws -> Outcome? {
        guard let owner = localesOwner(projectDir: projectDir, target: target) else { return nil }
        let fm = FileManager.default
        let localesDir = owner + "/Locales"
        let files = (try? fm.contentsOfDirectory(atPath: localesDir))?.filter { $0.hasSuffix(".json") } ?? []
        guard !files.isEmpty else { return nil }

        var catalogs: [String: [String: L10nTemplate]] = [:]
        for file in files.sorted() {
            let tag = String(file.dropLast(".json".count))
            guard isValidTag(tag) else { throw L10nGeneratorError.badTag(tag) }
            let json = try String(contentsOfFile: localesDir + "/" + file, encoding: .utf8)
            catalogs[tag] = try L10nCatalog.parse(json: json, locale: tag)
        }
        let warnings = try L10nCatalog.validate(catalogs: catalogs, allowMissing: allowMissing)
        let text = try L10nEmitter.file(catalogs: catalogs)

        let generatedDir = owner + "/Generated"
        let path = generatedDir + "/L10n.swift"
        let existing = try? String(contentsOfFile: path, encoding: .utf8)
        // `--check` is a CI gate: byte-for-byte, and it writes nothing.
        if check {
            guard existing == text else { throw L10nGeneratorError.checkFailed(path: path) }
            return Outcome(path: path, changed: false, warnings: warnings)
        }
        if existing == text { return Outcome(path: path, changed: false, warnings: warnings) }
        try fm.createDirectory(atPath: generatedDir, withIntermediateDirectories: true)
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return Outcome(path: path, changed: true, warnings: warnings)
    }

    /// Seeds a new catalog from the alphabetically-first existing one so the
    /// translator gets every key instead of copying by hand. Values keep their
    /// placeholders — the seed passes `validate` before anyone translates it.
    public static func addLocale(projectDir: String, tag: String, target: String?) throws -> String {
        guard isValidTag(tag) else { throw L10nGeneratorError.badTag(tag) }
        guard let owner = localesOwner(projectDir: projectDir, target: target) else {
            throw L10nGeneratorError.noLocalesDirectory
        }
        let fm = FileManager.default
        let localesDir = owner + "/Locales"
        let path = localesDir + "/\(tag).json"
        guard !fm.fileExists(atPath: path) else { throw L10nGeneratorError.localeExists(tag) }

        let sources = (try? fm.contentsOfDirectory(atPath: localesDir))?
            .filter { $0.hasSuffix(".json") }.sorted() ?? []
        guard let seedFile = sources.first else { throw L10nGeneratorError.noLocalesDirectory }
        let seedJSON = try String(contentsOfFile: localesDir + "/" + seedFile, encoding: .utf8)
        guard let data = seedJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw L10nError.notAnObject(locale: String(seedFile.dropLast(".json".count))) }

        var lines: [String] = []
        for key in object.keys.sorted() {
            let value = (object[key] as? String) ?? ""
            lines.append("  \(try jsonString(key)): \(try jsonString("TODO " + value))")
        }
        let text = "{\n" + lines.joined(separator: ",\n") + "\n}\n"
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// A JSON string literal, quotes included. Encoded as a one-element array
    /// because `JSONSerialization` refuses a bare string as a top-level object.
    private static func jsonString(_ s: String) throws -> String {
        let array = String(decoding: try JSONSerialization.data(withJSONObject: [s]), as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }
}
