/// Named responsive breakpoint scale (mobile-first). Static default; a
/// theme-injected scale can replace `minWidthPx` later without touching call
/// sites. // ponytail: static default scale.
public enum Breakpoint: Int, Comparable, CaseIterable {
    case sm, md, lg, xl
    public var minWidthPx: Double {
        switch self {
        case .sm: return 640
        case .md: return 768
        case .lg: return 1024
        case .xl: return 1280
        }
    }
    public static func < (a: Breakpoint, b: Breakpoint) -> Bool { a.rawValue < b.rawValue }
}

extension MediaQuery {
    /// Matches at/above the breakpoint. `@media (min-width: …)`.
    public static func up(_ bp: Breakpoint) -> MediaQuery { .minWidth(.px(bp.minWidthPx)) }
    /// Matches below the breakpoint. -0.02px avoids the exact-boundary overlap with `up`.
    public static func down(_ bp: Breakpoint) -> MediaQuery { .maxWidth(.px(bp.minWidthPx - 0.02)) }
}
