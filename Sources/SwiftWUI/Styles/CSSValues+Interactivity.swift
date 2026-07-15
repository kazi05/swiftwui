// Interactivity-module CSS value types. String-backed enums;
// `var css: String { rawValue }`, matching the CSSValues.swift enum style.

/// `pointer-events`. The camelCase cases (`visiblePainted`, `visibleFill`,
/// `visibleStroke`) render to the EXACT CSS keywords verbatim — these are the real
/// CSS values (SVG heritage), NOT a case-conversion oversight. Do not hyphenate them.
public enum PointerEvents: String, CSSValueConvertible {
    case auto, none, all
    case visiblePainted, visibleFill, visibleStroke, visible
    case painted, fill, stroke
    public var css: String { rawValue }
}

/// `user-select`.
public enum UserSelect: String, CSSValueConvertible {
    case auto, text, none, all, contain
    public var css: String { rawValue }
}

/// `touch-action`. Value combinations (`pan-y pinch-zoom`) are out of scope — use `.style()`.
public enum TouchAction: String, CSSValueConvertible {
    case auto, none, manipulation
    case panX = "pan-x", panY = "pan-y"
    case panLeft = "pan-left", panRight = "pan-right"
    case panUp = "pan-up", panDown = "pan-down"
    case pinchZoom = "pinch-zoom"
    public var css: String { rawValue }
}

/// `scroll-behavior`.
public enum ScrollBehavior: String, CSSValueConvertible {
    case auto, smooth
    public var css: String { rawValue }
}

/// `scroll-snap-type`: `none`, an axis (`x`), or an axis with a strictness (`x mandatory`).
public struct ScrollSnapType: Equatable, CSSValueConvertible {
    public enum Axis: String { case x, y, block, inline, both }
    public enum Strictness: String { case mandatory, proximity }
    public var axis: Axis
    public var strictness: Strictness?
    private var isNone: Bool
    public init(axis: Axis, strictness: Strictness? = nil) {
        self.axis = axis; self.strictness = strictness; self.isNone = false
    }
    private init(none: Bool) { self.axis = .both; self.strictness = nil; self.isNone = none }
    public static let none = ScrollSnapType(none: true)
    public var css: String {
        if isNone { return "none" }
        if let strictness { return "\(axis.rawValue) \(strictness.rawValue)" }
        return axis.rawValue
    }
}

/// `scroll-snap-align`.
public enum ScrollSnapAlign: String, CSSValueConvertible {
    case none, start, end, center
    public var css: String { rawValue }
}

/// `overscroll-behavior` (and the x/y longhands).
public enum OverscrollBehavior: String, CSSValueConvertible {
    case auto, contain, none
    public var css: String { rawValue }
}

/// `resize`.
public enum Resize: String, CSSValueConvertible {
    case none, both, horizontal, vertical, block, inline
    public var css: String { rawValue }
}

/// `appearance`.
public enum Appearance: String, CSSValueConvertible {
    case none, auto, button, textfield, checkbox, radio, searchfield
    case menulistButton = "menulist-button"
    public var css: String { rawValue }
}

/// `list-style-position`.
public enum ListStylePosition: String, CSSValueConvertible {
    case inside, outside
    public var css: String { rawValue }
}

/// `border-collapse`.
public enum BorderCollapse: String, CSSValueConvertible {
    case collapse, separate
    public var css: String { rawValue }
}

/// `table-layout`.
public enum TableLayout: String, CSSValueConvertible {
    case auto, fixed
    public var css: String { rawValue }
}

/// `color-scheme`. Named distinctly from the media/environment `ColorScheme`.
public enum ColorSchemeHint: String, CSSValueConvertible {
    case normal, light, dark
    case lightDark = "light dark"
    public var css: String { rawValue }
}

/// `break-inside`.
public enum BreakInside: String, CSSValueConvertible {
    case auto, avoid
    case avoidPage = "avoid-page", avoidColumn = "avoid-column"
    public var css: String { rawValue }
}

/// `break-before` and `break-after`.
public enum BreakBetween: String, CSSValueConvertible {
    case auto, avoid, always, all, page, column
    case avoidPage = "avoid-page", avoidColumn = "avoid-column"
    public var css: String { rawValue }
}

/// `content-visibility`.
public enum ContentVisibility: String, CSSValueConvertible {
    case visible, auto, hidden
    public var css: String { rawValue }
}

/// `scroll-snap-stop`.
public enum ScrollSnapStop: String, CSSValueConvertible {
    case normal, always
    public var css: String { rawValue }
}

/// `scrollbar-width`.
public enum ScrollbarWidth: String, CSSValueConvertible {
    case auto, thin, none
    public var css: String { rawValue }
}

/// `flex` shorthand: a keyword, or a `grow shrink basis` triple.
public enum FlexShorthand: Equatable, CSSValueConvertible {
    case none, auto, initial
    case grow(Double, shrink: Double = 1, basis: CSSLength = .zero)
    public var css: String {
        switch self {
        case .none: return "none"
        case .auto: return "auto"
        case .initial: return "initial"
        case .grow(let g, let s, let b): return "\(cssNumber(g)) \(cssNumber(s)) \(b.css)"
        }
    }
}

/// One `counter-reset`/`-increment`/`-set` entry: a counter name and an integer
/// value. The name must be a CSS ident — validated at the factory.
public struct CounterAction: Equatable {
    public var name: String
    public var value: Int
    public init(_ name: String, _ value: Int = 0) {
        self.name = name; self.value = value
    }
}
