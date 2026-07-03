/// A named CSS custom property, declared once as a static (spec §9):
///
///     extension ColorToken { static let accent = ColorToken("accent") }
///     H1("Hi").color(.token(.accent))          // → color: var(--accent)
public struct StyleToken<Value: CSSValueConvertible> {
    public let name: String
    public init(_ name: String) {
        assert(CSSSanitize.isValidIdent(name), "token name must be a CSS ident: \(name)")
        self.name = CSSSanitize.isValidIdent(name) ? name : "invalid"
    }
}
public typealias ColorToken = StyleToken<CSSColor>
public typealias LengthToken = StyleToken<CSSLength>

extension CSSColor {
    public static func token(_ t: ColorToken) -> CSSColor { .variable(t.name) }
}
extension CSSLength {
    /// Length tokens render via a raw var() passthrough.
    public static func token(_ t: LengthToken) -> CSSLength { .variable(t.name) }
}

public struct ThemeAssignments {
    var pairs: [(name: String, value: String)] = []
    public mutating func set<V: CSSValueConvertible>(_ token: StyleToken<V>, _ value: V) {
        pairs.append(("--" + token.name, value.css))
    }
}

/// Default theme emits `:root { … }`; named themes emit `[data-theme="name"] { … }`.
/// Switching = one attribute write via setTheme, zero re-render (spec §9).
public struct ThemeDefinition {
    let name: String?                      // nil = default
    let pairs: [(name: String, value: String)]
    public init(_ build: (inout ThemeAssignments) -> Void) {
        var a = ThemeAssignments(); build(&a)
        self.name = nil; self.pairs = a.pairs
    }
    public init(name: String, _ build: (inout ThemeAssignments) -> Void) {
        assert(CSSSanitize.isValidIdent(name), "theme name must be a CSS ident: \(name)")
        var a = ThemeAssignments(); build(&a)
        self.name = CSSSanitize.isValidIdent(name) ? name : "invalid"; self.pairs = a.pairs
    }
    var ruleText: String {
        let selector = name.map { "[data-theme=\"\($0)\"]" } ?? ":root"
        let body = pairs.map { "\($0.name): \($0.value)" }.joined(separator: "; ")
        return "\(selector) { \(body) }"
    }
}
