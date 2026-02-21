// MediaQuery.swift - CSS media query type for responsive styles

import SwiftWUICore

/// Represents a CSS `@media` query for responsive design.
///
/// Use with the `.media()` modifier to apply styles conditionally:
/// ```swift
/// Text("Hello")
///     .fontSize(.px(24))
///     .media(.compact) { $0.fontSize(.px(16)) }
/// ```
///
/// Predefined breakpoints match `ScreenSize` from SwiftWUIBrowser:
/// - `.compact`  — max-width: 767px (mobile)
/// - `.regular`  — 768–1023px (tablet)
/// - `.expanded` — min-width: 1024px (desktop)
public indirect enum MediaQuery: Hashable, Sendable {

    // MARK: - Size Constraints

    case minWidth(CSSUnit)
    case maxWidth(CSSUnit)
    case minHeight(CSSUnit)
    case maxHeight(CSSUnit)

    // MARK: - User Preferences

    /// Color scheme preference. Uses its own enum to avoid
    /// cross-module dependency on SwiftWUIBrowser.
    case colorScheme(ColorSchemeValue)
    case prefersReducedMotion

    // MARK: - Combinators

    case and(MediaQuery, MediaQuery)
    case or(MediaQuery, MediaQuery)
    case not(MediaQuery)

    // MARK: - Predefined Breakpoints

    /// Mobile: max-width 767px. Matches `ScreenSize.compact`.
    public static let compact  = MediaQuery.maxWidth(.px(767))
    /// Tablet: 768–1023px. Matches `ScreenSize.regular`.
    public static let regular  = MediaQuery.and(.minWidth(.px(768)), .maxWidth(.px(1023)))
    /// Desktop: min-width 1024px. Matches `ScreenSize.expanded`.
    public static let expanded = MediaQuery.minWidth(.px(1024))

    // MARK: - Color Scheme

    /// Color scheme values for media queries.
    /// Separate from `SwiftWUIBrowser.ColorScheme` to avoid cross-module dependency.
    public enum ColorSchemeValue: String, Hashable, Sendable {
        case light
        case dark
    }

    // MARK: - CSS Output

    /// The full CSS `@media` string, e.g. `@media (min-width: 768px)`.
    public var cssString: String {
        "@media \(condition)"
    }

    /// The inner condition without the `@media` prefix.
    /// Used for building compound queries.
    var condition: String {
        switch self {
        case .minWidth(let unit):
            return "(min-width: \(unit.cssValue))"
        case .maxWidth(let unit):
            return "(max-width: \(unit.cssValue))"
        case .minHeight(let unit):
            return "(min-height: \(unit.cssValue))"
        case .maxHeight(let unit):
            return "(max-height: \(unit.cssValue))"
        case .colorScheme(let scheme):
            return "(prefers-color-scheme: \(scheme.rawValue))"
        case .prefersReducedMotion:
            return "(prefers-reduced-motion: reduce)"
        case .and(let lhs, let rhs):
            return "\(lhs.condition) and \(rhs.condition)"
        case .or(let lhs, let rhs):
            return "\(lhs.condition), \(rhs.condition)"
        case .not(let query):
            return "not \(query.condition)"
        }
    }
}
