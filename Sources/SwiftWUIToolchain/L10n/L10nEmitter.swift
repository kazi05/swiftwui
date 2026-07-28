import Foundation

/// Turns parsed catalogs into `Generated/L10n.swift`.
///
/// Output shape (spec §2.2): one function per key returning `LocalizedText`,
/// per-locale bodies as local functions so each template is emitted once, an
/// exact-tag switch followed by a language switch, and `nil` for locales that
/// do not have the key (the runtime then falls back to the app default).
///
/// Every piece of catalog text reaches the output through
/// `SwiftLiteralEscaping.literal` — there is deliberately no second route.
public enum L10nEmitter {
    private static let swiftKeywords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import",
        "init", "inout", "internal", "let", "open", "operator", "private", "protocol", "public",
        "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "continue",
        "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat",
        "return", "switch", "where", "while", "as", "catch", "false", "is", "nil", "super", "self",
        "Self", "throw", "throws", "true", "try", "any", "some",
    ]

    public static func symbolName(forKey key: String) throws -> String {
        let segments = key.split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "_" }).map(String.init)
        guard let first = segments.first else { throw L10nError.unusableKey(key: key, symbol: "") }
        let head = first.prefix(1).lowercased() + first.dropFirst()
        let tail = segments.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        let name = head + tail
        // The parser allows keys like "123" or "-": legal catalog keys, illegal Swift
        // identifiers. Refuse them here rather than emitting source that will not compile.
        guard let lead = name.first, lead.isASCII, lead.isLetter || lead == "_" else {
            throw L10nError.unusableKey(key: key, symbol: name)
        }
        return swiftKeywords.contains(name) ? "`\(name)`" : name
    }

    /// Placeholder names become parameter names. The parser guarantees an ASCII
    /// identifier shape but not Swift legality: keywords need backticks, and `_`
    /// would generate a parameter the function body cannot reference.
    public static func parameterName(_ raw: String, key: String) throws -> String {
        guard raw != "_" else { throw L10nError.unusablePlaceholder(name: raw, key: key) }
        return swiftKeywords.contains(raw) ? "`\(raw)`" : raw
    }

    /// Validates a locale tag and returns its canonical form.
    ///
    /// Tags come from `Locales/<tag>.json` filenames, so this is a trust boundary:
    /// the tag reaches both a string literal and five *identifier* positions, and
    /// only the literal is escapable. It also has to agree with `LocaleID`, whose
    /// `identifier` the runtime matches on — `Locales/pt-br.json` must emit
    /// `case "pt-BR"`, or that locale never matches and silently dies.
    ///
    /// `SwiftWUIToolchain` cannot import `SwiftWUI` (Package.swift:34), so the
    /// grammar of `LocaleID.init?` is mirrored here and pinned against it by
    /// `canonicalTagAgreesWithLocaleID` in the test target, which sees both.
    public static func canonicalTag(_ tag: String) throws -> String {
        let parts = tag.split(omittingEmptySubsequences: false,
                              whereSeparator: { $0 == "-" || $0 == "_" })
        func isAlpha(_ s: Substring) -> Bool { !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isLetter } }
        func isDigits(_ s: Substring) -> Bool { !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isNumber } }

        guard (1...3).contains(parts.count), isAlpha(parts[0]), (2...3).contains(parts[0].count) else {
            throw L10nError.invalidLocaleTag(tag: tag)
        }
        var segments = [parts[0].lowercased()]
        var index = 1
        if index < parts.count, isAlpha(parts[index]), parts[index].count == 4 {
            let script = parts[index].lowercased()
            segments.append(script.prefix(1).uppercased() + script.dropFirst())
            index += 1
        }
        if index < parts.count {
            let region = parts[index]
            if isAlpha(region), region.count == 2 { segments.append(region.uppercased()) }
            else if isDigits(region), region.count == 3 { segments.append(String(region)) }
            else { throw L10nError.invalidLocaleTag(tag: tag) }
            index += 1
        }
        guard index == parts.count else { throw L10nError.invalidLocaleTag(tag: tag) }
        return segments.joined(separator: "-")
    }

    /// An identifier that is safe in a declaration: Swift keywords need backticks.
    static func escaped(_ name: String) -> String {
        swiftKeywords.contains(name) ? "`\(name)`" : name
    }

    /// `"en-US"` -> `"enUS"`. Always a plain identifier: the canonical grammar
    /// admits only ASCII letters and digits after a letter lead.
    private static func identifier(forCanonicalTag tag: String) -> String {
        let segments = tag.split(separator: "-")
        return segments[0] + segments.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Precondition: `catalogs` has passed `L10nCatalog.validate` — a key whose
    /// placeholders differ across locales emits a parameter list from one locale
    /// and a body referencing another's, which does not compile.
    public static func file(catalogs: [String: [String: L10nTemplate]]) throws -> String {
        // Raw dictionary key = the `Locales/<tag>.json` filename stem; everything
        // emitted uses the canonical tag, which is what the runtime matches on.
        var locales: [Locale] = []
        var claimedTags: [String: String] = [:]                   // identifier -> raw tag
        for raw in catalogs.keys.sorted() {
            let canonical = try canonicalTag(raw)
            let identifier = identifier(forCanonicalTag: canonical)
            if let existing = claimedTags[identifier] {
                throw L10nError.duplicateLocale(first: existing, second: raw, canonical: canonical)
            }
            claimedTags[identifier] = raw
            locales.append(Locale(canonical: canonical, raw: raw, identifier: identifier))
        }
        locales.sort { $0.canonical < $1.canonical }

        let allKeys = Set(catalogs.values.flatMap(\.keys)).sorted()

        var claimed: [String: String] = [:]                       // symbol -> key
        for key in allKeys {
            let symbol = try symbolName(forKey: key)
            if let existing = claimed[symbol] {
                throw L10nError.nameCollision(first: existing, second: key, symbol: symbol)
            }
            claimed[symbol] = key
        }

        // The file lands in the app's own target, so it carries its own import:
        // `LocaleID`, `LocalizedText`, `LocalizationCatalog` and `_PluralCategory`
        // all live in SwiftWUI.
        var out = """
        // Generated by `swiftwui l10n generate`. Do not edit.
        // Source of truth: Locales/*.json

        import SwiftWUI

        extension LocaleID {

        """
        for locale in locales {
            out += "    public static let \(locale.symbol) = LocaleID(\(SwiftLiteralEscaping.literal(locale.canonical)))!\n"
        }
        out += "}\n\npublic enum L10n {\n"
        for key in allKeys {
            out += try function(key: key, catalogs: catalogs, locales: locales)
        }
        out += "}\n\nextension L10n: LocalizationCatalog {\n"
        out += "    public static let supportedLocales: [LocaleID] = ["
        out += locales.map { "." + $0.symbol }.joined(separator: ", ")
        out += "]\n}\n"

        let pluralLanguages = try usedPluralLanguages(catalogs: catalogs, locales: locales)
        if !pluralLanguages.isEmpty {
            out += "\nenum _SWUIPlural {\n"
            for language in pluralLanguages.sorted() {
                guard let body = PluralRules.swiftBody(language: language) else { continue }
                // `nonisolated`: app targets build with `.defaultIsolation(MainActor.self)`,
                // and these run inside `LocalizedText`'s nonisolated render closure.
                // `escaped`: `is` (Icelandic) and `as` (Assamese) are real language
                // subtags, so a future entry in `PluralRules.supported` must not be
                // able to emit a function named after a Swift keyword.
                out += "    nonisolated static func \(escaped(language))(_ value: Int) -> _PluralCategory {\n\(body)\n    }\n"
            }
            out += "}\n"
        }
        return out
    }

    /// A validated locale: `raw` indexes `catalogs`, everything emitted uses the
    /// canonical tag or the identifier derived from it.
    private struct Locale {
        let canonical: String
        let raw: String
        let identifier: String
        var language: String { String(canonical.split(separator: "-")[0]) }
        /// Identifier as it appears in declarations — backticked if a keyword
        /// (`in` is Indonesian).
        var symbol: String { swiftKeywords.contains(identifier) ? "`\(identifier)`" : identifier }
        /// Per-locale local function inside the render closure. Prefixed so it can
        /// never shadow a parameter named after a locale (`{"k":"Hi, {en}!"}`).
        var localFunction: String { "_l_\(identifier)" }
    }

    private static func usedPluralLanguages(catalogs: [String: [String: L10nTemplate]],
                                            locales: [Locale]) throws -> Set<String> {
        var out: Set<String> = []
        for locale in locales {
            let hasPlural = (catalogs[locale.raw] ?? [:]).values.contains { template in
                template.parts.contains { if case .plural = $0 { return true } else { return false } }
            }
            guard hasPlural else { continue }
            // Without a rule the function body would call `_SWUIPlural.<lang>`, which
            // this file never defines. Fail here rather than emit uncompilable Swift.
            guard PluralRules.supported.contains(locale.language) else {
                throw L10nError.unsupportedPluralLanguage(language: locale.language, locale: locale.raw)
            }
            out.insert(locale.language)
        }
        return out
    }

    private static func function(key: String, catalogs: [String: [String: L10nTemplate]],
                                 locales: [Locale]) throws -> String {
        let present = locales.filter { catalogs[$0.raw]?[key] != nil }
        let signature = L10nCatalog.signature(catalogs[present[0].raw]![key]!)
        var params = try signature.strings.map { "\(try parameterName($0, key: key)): String" }
        if let plural = signature.pluralVariable {
            params.append("\(try parameterName(plural, key: key)): Int")
        }
        let paramList = params.joined(separator: ", ")

        var out = "    public static func \(try symbolName(forKey: key))(\(paramList)) -> LocalizedText {\n"
        out += "        LocalizedText(key: \(SwiftLiteralEscaping.literal(key))) { locale in\n"
        for locale in present {
            out += "            func \(locale.localFunction)() -> String {\n"
            out += try expression(catalogs[locale.raw]![key]!, language: locale.language, key: key,
                                  indent: "                ")
            out += "            }\n"
        }
        out += "            switch locale.identifier {\n"
        for locale in present {
            out += "            case \(SwiftLiteralEscaping.literal(locale.canonical)): return \(locale.localFunction)()\n"
        }
        out += "            default: break\n            }\n"
        out += "            switch locale.language {\n"
        for locale in present where !locale.canonical.contains("-") {
            out += "            case \(SwiftLiteralEscaping.literal(locale.canonical)): return \(locale.localFunction)()\n"
        }
        out += "            default: return nil\n            }\n"
        out += "        }\n    }\n"
        return out
    }

    private static func expression(_ template: L10nTemplate, language: String, key: String,
                                   indent: String) throws -> String {
        // A plural key becomes a switch; a plain key becomes one return.
        if let index = template.parts.firstIndex(where: { if case .plural = $0 { return true } else { return false } }),
           case .plural(let variable, let branches) = template.parts[index] {
            let prefix = Array(template.parts[..<index])
            let suffix = Array(template.parts[(index + 1)...])
            let parameter = try parameterName(variable, key: key)
            var out = "\(indent)switch _SWUIPlural.\(escaped(language))(\(parameter)) {\n"
            for branch in branches where branch.category != "other" {
                out += "\(indent)case .\(branch.category): return "
                out += try concat(prefix + branch.parts + suffix, pluralVariable: variable, key: key) + "\n"
            }
            let other = branches.first { $0.category == "other" }!
            out += "\(indent)default: return "
            out += try concat(prefix + other.parts + suffix, pluralVariable: variable, key: key) + "\n"
            out += "\(indent)}\n"
            return out
        }
        return "\(indent)return " + (try concat(template.parts, pluralVariable: nil, key: key)) + "\n"
    }

    private static func concat(_ parts: [L10nPart], pluralVariable: String?, key: String) throws -> String {
        var pieces: [String] = []
        for part in parts {
            switch part {
            case .literal(let s): pieces.append(SwiftLiteralEscaping.literal(s))
            case .placeholder(let n): pieces.append(try parameterName(n, key: key))
            case .number:
                pieces.append("String(\(try parameterName(pluralVariable ?? "count", key: key)))")
            case .plural: continue                              // flattened by the caller
            }
        }
        return pieces.isEmpty ? "\"\"" : pieces.joined(separator: " + ")
    }
}
