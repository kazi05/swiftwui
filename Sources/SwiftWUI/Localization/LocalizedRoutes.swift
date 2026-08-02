/// Optional per-locale path patterns (spec 2026-08-02 §2).
///
/// Empty by default: an app that declares none pays nothing, and `LocalePath`
/// short-circuits to its pre-existing behaviour character for character.
///
/// The canonical pattern is written exactly as the corresponding `Route(...)`
/// pattern — it is the identity key that ties the two together.
public struct LocalizedRoutes {
    public struct Entry {
        public let canonical: RoutePattern
        let localized: [LocaleID: RoutePattern]
        /// Locale tags `LocaleID(_:)` rejected. Collected, never trapped: this
        /// value is built during `static let` initialization, where a trap kills
        /// the process before any diagnostic can print. Surfaced by validation.
        let invalidTags: [String]
    }

    /// Declaration order is load-bearing — resolution is first-match-wins,
    /// exactly like `Router`.
    let entries: [Entry]

    public var isEmpty: Bool { entries.isEmpty }
    public static let none = LocalizedRoutes()

    public init(@LocalizedRoutesBuilder _ build: () -> [Entry] = { [] }) {
        self.entries = build()
    }
}

/// The name entries are written under: `LocalizedRoute("/about", ["ru": "/o-nas"])`.
///
/// Spelled as an initializer, not the spec's `.path(...)` factory: two
/// leading-dot lines in a row parse as ONE chained expression, so
/// `.path("/a")` / `.path("/b")` on consecutive lines fails to compile with
/// "static member 'path' cannot be used on instance of type". A statement that
/// starts with an identifier has no such trap — which is why `Route(...)` in
/// `RouteBuilder` reads the way it does.
public typealias LocalizedRoute = LocalizedRoutes.Entry

extension LocalizedRoutes.Entry {
    /// Locale keys are `String`, not `LocaleID`: `LocaleID`'s only initializer
    /// is failable, so a typed key would force `[LocaleID("ru")!: …]` at every
    /// declaration. The raw tags pass through that same validating initializer
    /// here — one choke point, as everywhere else locale strings arrive.
    public init(_ canonical: String, _ localized: [String: String]) {
        var parsed: [LocaleID: RoutePattern] = [:]
        var invalid: [String] = []
        for tag in localized.keys.sorted() {           // sorted: deterministic invalidTags
            if let id = LocaleID(tag) { parsed[id] = RoutePattern(localized[tag]!) }
            else { invalid.append(tag) }
        }
        self.canonical = RoutePattern(canonical)
        self.localized = parsed
        self.invalidTags = invalid
    }
}

// Mirrors RouteBuilder (Routing/Route.swift:61): variadic buildBlock also covers
// the empty block — do NOT add a zero-arg overload (ambiguity).
@resultBuilder
public enum LocalizedRoutesBuilder {
    public static func buildBlock(_ parts: [LocalizedRoutes.Entry]...) -> [LocalizedRoutes.Entry] {
        parts.flatMap { $0 }
    }
    public static func buildExpression(_ e: LocalizedRoutes.Entry) -> [LocalizedRoutes.Entry] { [e] }
    public static func buildOptional(_ e: [LocalizedRoutes.Entry]?) -> [LocalizedRoutes.Entry] { e ?? [] }
    public static func buildEither(first: [LocalizedRoutes.Entry]) -> [LocalizedRoutes.Entry] { first }
    public static func buildEither(second: [LocalizedRoutes.Entry]) -> [LocalizedRoutes.Entry] { second }
    public static func buildArray(_ parts: [[LocalizedRoutes.Entry]]) -> [LocalizedRoutes.Entry] {
        parts.flatMap { $0 }
    }
}

extension LocalizedRoutes {
    /// `RoutePattern.match`, minus the percent-decode (`RoutePattern.swift:130`).
    ///
    /// The table's entire job is to hand a path back byte-for-byte. Decoding
    /// here would turn `/dostavka/a%2Fb/x` into a three-segment canonical path,
    /// break the round-trip invariant, and make the SSG classify every page of
    /// that route as a self-targeting redirect (spec §2.1).
    static func matchRaw(_ path: String, _ pattern: RoutePattern) -> [String: String]? {
        let parts = RouteURL.pathSegments(RouteURL.normalizePath(path))
        var params: [String: String] = [:]
        var i = 0
        for seg in pattern.segments {
            switch seg {
            case .catchAll:
                params["*"] = parts[i...].joined(separator: "/")
                return params
            case .literal(let lit):
                guard i < parts.count, parts[i] == lit else { return nil }
            case .param(let name):
                guard i < parts.count else { return nil }
                params[name] = parts[i]
            }
            i += 1
        }
        return i == parts.count ? params : nil
    }

    /// The inverse: raw segments spliced into another pattern, by NAME.
    static func substituteRaw(_ params: [String: String], into pattern: RoutePattern) -> String {
        var out = ""
        for seg in pattern.segments {
            switch seg {
            case .literal(let lit): out += "/" + lit
            case .param(let name):  out += "/" + (params[name] ?? "")
            case .catchAll:
                let tail = params["*"] ?? ""
                if !tail.isEmpty { out += "/" + tail }
            }
        }
        return out.isEmpty ? "/" : out
    }
}
