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
