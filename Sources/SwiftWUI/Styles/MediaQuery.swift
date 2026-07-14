public enum ColorScheme: String { case light, dark }

public struct MediaQuery: Equatable {
    public let condition: String
    public static func maxWidth(_ l: CSSLength) -> MediaQuery { .init(condition: "(max-width: \(l.css))") }
    public static func minWidth(_ l: CSSLength) -> MediaQuery { .init(condition: "(min-width: \(l.css))") }
    public static func prefersColorScheme(_ s: ColorScheme) -> MediaQuery {
        .init(condition: "(prefers-color-scheme: \(s.rawValue))")
    }
    /// Escape hatch; must be rule-safe (no braces/control chars).
    public static func custom(_ s: String) -> MediaQuery {
        guard CSSSanitize.isSafeValue(s) else {
            assertionFailure("unsafe media condition: \(s)")
            return .init(condition: "not all")            // matches nothing in release
        }
        return .init(condition: s)
    }
}

public enum Orientation: String { case portrait, landscape }

extension MediaQuery {
    public static func minHeight(_ l: CSSLength) -> MediaQuery { .init(condition: "(min-height: \(l.css))") }
    public static func maxHeight(_ l: CSSLength) -> MediaQuery { .init(condition: "(max-height: \(l.css))") }
    public static func orientation(_ o: Orientation) -> MediaQuery { .init(condition: "(orientation: \(o.rawValue))") }

    // Each COMPOUND operand is wrapped in parens so nesting stays valid CSS
    // (fixes v1's unparenthesized combinator bug). Simple features are already
    // individually parenthesized.
    public static func and(_ a: MediaQuery, _ b: MediaQuery) -> MediaQuery {
        .init(condition: "(\(a.condition) and \(b.condition))")
    }
    public static func or(_ a: MediaQuery, _ b: MediaQuery) -> MediaQuery {
        .init(condition: "(\(a.condition) or \(b.condition))")
    }
    public static func not(_ q: MediaQuery) -> MediaQuery {
        .init(condition: "(not \(q.condition))")
    }
}
