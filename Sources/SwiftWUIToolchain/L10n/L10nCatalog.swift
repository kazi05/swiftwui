import Foundation

public indirect enum L10nPart {
    case literal(String)
    case placeholder(String)
    /// `#` inside a plural branch — the plural variable rendered as digits.
    case number
    case plural(variable: String, branches: [(category: String, parts: [L10nPart])])
}

public struct L10nTemplate {
    public let parts: [L10nPart]
}

/// The parameter shape of a key: named string placeholders plus at most one
/// plural variable. All locales of a key must agree on it.
public struct L10nSignature: Equatable {
    public let strings: [String]
    public let pluralVariable: String?
}

public enum L10nError: Error, CustomStringConvertible {
    case notAnObject(locale: String)
    case nonStringValue(key: String, locale: String)
    case invalidKey(key: String, locale: String)
    case invalidPlaceholder(name: String, key: String, locale: String)
    case unterminated(key: String, locale: String)
    case unknownPluralCategory(category: String, key: String, locale: String)
    case missingOtherBranch(key: String, locale: String)
    case nestedPlural(key: String, locale: String)
    case multiplePlurals(key: String, locale: String)
    case missingKey(key: String, locale: String)
    case signatureMismatch(key: String, locales: [String])
    case nameCollision(first: String, second: String, symbol: String)
    case duplicatePluralCategory(category: String, key: String, locale: String)
    case unusableKey(key: String, symbol: String)
    case unusablePlaceholder(name: String, key: String)
    case unsupportedPluralLanguage(language: String, locale: String)
    case invalidLocaleTag(tag: String)
    case duplicateLocale(first: String, second: String, canonical: String)

    public var description: String {
        switch self {
        case .notAnObject(let l): return "Locales/\(l).json: top level must be a flat JSON object"
        case .nonStringValue(let k, let l): return "Locales/\(l).json: value for '\(k)' must be a string"
        case .invalidKey(let k, let l): return "Locales/\(l).json: key '\(k)' must match [A-Za-z0-9._-]+"
        case .invalidPlaceholder(let n, let k, let l): return "Locales/\(l).json: '\(k)' has invalid placeholder '\(n)' (must be a Swift identifier)"
        case .unterminated(let k, let l): return "Locales/\(l).json: '\(k)' has an unterminated '{'"
        case .unknownPluralCategory(let c, let k, let l): return "Locales/\(l).json: '\(k)' uses unknown plural category '\(c)'"
        case .missingOtherBranch(let k, let l): return "Locales/\(l).json: '\(k)' plural is missing the required 'other' branch"
        case .nestedPlural(let k, let l): return "Locales/\(l).json: '\(k)' nests plurals — unsupported"
        case .multiplePlurals(let k, let l): return "Locales/\(l).json: '\(k)' has more than one plural — unsupported"
        case .missingKey(let k, let l): return "key '\(k)' is missing from Locales/\(l).json (use --allow-missing to downgrade to a warning)"
        case .signatureMismatch(let k, let ls): return "key '\(k)' has different placeholders across locales \(ls.sorted())"
        case .nameCollision(let a, let b, let s): return "keys '\(a)' and '\(b)' both generate '\(s)'"
        case .duplicatePluralCategory(let c, let k, let l): return "Locales/\(l).json: '\(k)' repeats the plural category '\(c)'"
        case .unusableKey(let k, let s): return "key '\(k)' generates '\(s)', which is not a Swift identifier — rename the key"
        case .unusablePlaceholder(let n, let k): return "'\(k)' uses placeholder '\(n)', which cannot be a Swift parameter name"
        case .unsupportedPluralLanguage(let lang, let l): return "Locales/\(l).json uses a plural, but language '\(lang)' has no built-in CLDR rule"
        case .invalidLocaleTag(let t): return "'\(t)' is not a locale tag — expected language[-Script][-Region], e.g. 'en', 'pt-BR', 'zh-Hans-CN'"
        case .duplicateLocale(let a, let b, let c): return "Locales/\(a).json and Locales/\(b).json both describe locale '\(c)'"
        }
    }
}

public enum L10nCatalog {
    private static let categories: Set<String> = ["zero", "one", "two", "few", "many", "other"]

    public static func parse(json: String, locale: String) throws -> [String: L10nTemplate] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw L10nError.notAnObject(locale: locale) }

        var out: [String: L10nTemplate] = [:]
        // Sorted so a bad catalog always names the same offending key.
        for key in object.keys.sorted() {
            let value = object[key]!
            guard isValidKey(key) else { throw L10nError.invalidKey(key: key, locale: locale) }
            guard let string = value as? String else { throw L10nError.nonStringValue(key: key, locale: locale) }
            out[key] = L10nTemplate(parts: try parseParts(Array(string), key: key, locale: locale, insidePlural: false))
        }
        return out
    }

    static func isValidKey(_ key: String) -> Bool {
        !key.isEmpty && key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-") }
    }

    static func isIdentifier(_ name: String) -> Bool {
        // `_` is a legal ASCII identifier but an unusable parameter name.
        guard name != "_" else { return false }
        guard let first = name.first, first.isASCII, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }

    private static func parseParts(_ chars: [Character], key: String, locale: String,
                                   insidePlural: Bool) throws -> [L10nPart] {
        var parts: [L10nPart] = []
        var literal = ""
        var i = 0
        var sawPlural = false

        func flush() { if !literal.isEmpty { parts.append(.literal(literal)); literal = "" } }

        while i < chars.count {
            let c = chars[i]
            if c == "#" && insidePlural {
                flush(); parts.append(.number); i += 1; continue
            }
            guard c == "{" else { literal.append(c); i += 1; continue }

            guard let close = matchingBrace(chars, from: i) else {
                throw L10nError.unterminated(key: key, locale: locale)
            }
            let inner = String(chars[(i + 1)..<close])
            flush()

            if let commaIndex = inner.firstIndex(of: ",") {
                let variable = String(inner[inner.startIndex..<commaIndex]).trimmingCharacters(in: .whitespaces)
                let rest = String(inner[inner.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
                guard rest.hasPrefix("plural") else {
                    throw L10nError.invalidPlaceholder(name: inner, key: key, locale: locale)
                }
                if insidePlural { throw L10nError.nestedPlural(key: key, locale: locale) }
                if sawPlural { throw L10nError.multiplePlurals(key: key, locale: locale) }
                guard isIdentifier(variable) else {
                    throw L10nError.invalidPlaceholder(name: variable, key: key, locale: locale)
                }
                let afterPlural = String(rest.dropFirst("plural".count)).drop(while: { $0 == "," || $0 == " " })
                let branches = try parseBranches(Array(afterPlural), key: key, locale: locale)
                guard branches.contains(where: { $0.category == "other" }) else {
                    throw L10nError.missingOtherBranch(key: key, locale: locale)
                }
                parts.append(.plural(variable: variable, branches: branches))
                sawPlural = true
            } else {
                guard isIdentifier(inner) else {
                    throw L10nError.invalidPlaceholder(name: inner, key: key, locale: locale)
                }
                parts.append(.placeholder(inner))
            }
            i = close + 1
        }
        flush()
        return parts
    }

    private static func parseBranches(_ chars: [Character], key: String,
                                      locale: String) throws -> [(category: String, parts: [L10nPart])] {
        var branches: [(category: String, parts: [L10nPart])] = []
        var i = 0
        while i < chars.count {
            while i < chars.count, chars[i].isWhitespace { i += 1 }
            guard i < chars.count else { break }
            var name = ""
            while i < chars.count, !chars[i].isWhitespace, chars[i] != "{" { name.append(chars[i]); i += 1 }
            while i < chars.count, chars[i].isWhitespace { i += 1 }
            guard i < chars.count, chars[i] == "{", let close = matchingBrace(chars, from: i) else {
                throw L10nError.unterminated(key: key, locale: locale)
            }
            guard categories.contains(name) else {
                throw L10nError.unknownPluralCategory(category: name, key: key, locale: locale)
            }
            guard !branches.contains(where: { $0.category == name }) else {
                throw L10nError.duplicatePluralCategory(category: name, key: key, locale: locale)
            }
            let body = Array(chars[(i + 1)..<close])
            branches.append((name, try parseParts(body, key: key, locale: locale, insidePlural: true)))
            i = close + 1
        }
        return branches
    }

    private static func matchingBrace(_ chars: [Character], from index: Int) -> Int? {
        var depth = 0
        var i = index
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    public static func signature(_ template: L10nTemplate) -> L10nSignature {
        var strings: Set<String> = []
        var plural: String? = nil
        func walk(_ parts: [L10nPart]) {
            for part in parts {
                switch part {
                case .literal, .number: continue
                case .placeholder(let n): strings.insert(n)
                case .plural(let variable, let branches):
                    plural = variable
                    for b in branches { walk(b.parts) }
                }
            }
        }
        walk(template.parts)
        return L10nSignature(strings: strings.sorted(), pluralVariable: plural)
    }

    /// Cross-locale checks. Returns warnings; throws on anything fatal.
    @discardableResult
    public static func validate(catalogs: [String: [String: L10nTemplate]],
                                allowMissing: Bool) throws -> [String] {
        var warnings: [String] = []
        let allKeys = Set(catalogs.values.flatMap(\.keys)).sorted()
        for key in allKeys {
            var signatures: [String: L10nSignature] = [:]
            for (locale, entries) in catalogs.sorted(by: { $0.key < $1.key }) {
                guard let template = entries[key] else {
                    if allowMissing { warnings.append("key '\(key)' missing from Locales/\(locale).json — falls back to the default locale") ; continue }
                    throw L10nError.missingKey(key: key, locale: locale)
                }
                signatures[locale] = signature(template)
            }
            if Set(signatures.values.map { "\($0.strings)|\($0.pluralVariable ?? "-")" }).count > 1 {
                throw L10nError.signatureMismatch(key: key, locales: Array(signatures.keys))
            }
        }
        return warnings
    }
}
