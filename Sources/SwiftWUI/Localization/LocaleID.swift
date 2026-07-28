/// Writing direction of a locale's script.
public enum LayoutDirection: String, Hashable {
    case leftToRight = "ltr"
    case rightToLeft = "rtl"
}

/// A validated BCP-47 subset: language[-Script][-Region].
///
/// NOT named `Locale`: application code almost always imports Foundation, and a
/// same-named type would make every use site ambiguous.
///
/// The failable initializer is the single choke point for untrusted locale
/// strings — URL prefixes, localStorage, cookies, `navigator.languages` and
/// catalog filenames all pass through it before any value reaches a filesystem
/// path, a URL, or `<html lang>`.
public struct LocaleID: Hashable, CustomStringConvertible {
    public let identifier: String
    public let language: String
    public let script: String?
    public let region: String?

    public init?(_ raw: String) {
        // Empty subsequences are kept, so "en-", "-en" and "en--US" reach the
        // per-subtag checks below and fail there instead of being normalized away.
        let parts = raw.split(omittingEmptySubsequences: false,
                              whereSeparator: { $0 == "-" || $0 == "_" })
        guard (1...3).contains(parts.count) else { return nil }

        func isAlpha(_ s: Substring) -> Bool { !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isLetter } }
        func isDigits(_ s: Substring) -> Bool { !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isNumber } }

        guard isAlpha(parts[0]), (2...3).contains(parts[0].count) else { return nil }
        let lang = parts[0].lowercased()

        var scriptPart: String? = nil
        var regionPart: String? = nil
        var index = 1
        if index < parts.count, isAlpha(parts[index]), parts[index].count == 4 {
            let s = parts[index].lowercased()
            scriptPart = s.prefix(1).uppercased() + s.dropFirst()
            index += 1
        }
        if index < parts.count {
            let p = parts[index]
            if isAlpha(p), p.count == 2 { regionPart = p.uppercased() }
            else if isDigits(p), p.count == 3 { regionPart = String(p) }
            else { return nil }
            index += 1
        }
        guard index == parts.count else { return nil }

        language = lang
        script = scriptPart
        region = regionPart
        identifier = [lang, scriptPart, regionPart].compactMap { $0 }.joined(separator: "-")
    }

    /// Languages written right-to-left (CLDR script direction, language level).
    private static let rtlLanguages: Set<String> =
        ["ar", "he", "fa", "ur", "ps", "sd", "ug", "yi", "dv", "ckb"]

    public var isRTL: Bool { Self.rtlLanguages.contains(language) }
    public var direction: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
    public var description: String { identifier }
}
