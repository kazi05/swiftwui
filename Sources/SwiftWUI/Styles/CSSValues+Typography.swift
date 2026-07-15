// Typography-module CSS value types. String-backed enums;
// `var css: String { rawValue }`, matching the CSSValues.swift enum style.

/// `white-space`.
public enum WhiteSpace: String, CSSValueConvertible {
    case normal, nowrap, pre
    case preWrap = "pre-wrap", preLine = "pre-line", breakSpaces = "break-spaces"
    public var css: String { rawValue }
}

/// `text-transform`.
public enum TextTransform: String, CSSValueConvertible {
    case none, capitalize, uppercase, lowercase
    case fullWidth = "full-width", fullSizeKana = "full-size-kana"
    public var css: String { rawValue }
}

/// `text-overflow`.
public enum TextOverflow: String, CSSValueConvertible {
    case clip, ellipsis
    public var css: String { rawValue }
}

/// `font-style`.
public enum FontStyle: String, CSSValueConvertible {
    case normal, italic, oblique
    public var css: String { rawValue }
}

/// `text-decoration-line`.
public enum TextDecorationLine: String, CSSValueConvertible {
    case none, underline, overline, lineThrough = "line-through"
    public var css: String { rawValue }
}

/// `text-decoration-style`.
public enum TextDecorationStyle: String, CSSValueConvertible {
    case solid, double, dotted, dashed, wavy
    public var css: String { rawValue }
}

/// `word-break`.
public enum WordBreak: String, CSSValueConvertible {
    case normal, breakAll = "break-all", keepAll = "keep-all", breakWord = "break-word"
    public var css: String { rawValue }
}

/// `overflow-wrap`.
public enum OverflowWrap: String, CSSValueConvertible {
    case normal, breakWord = "break-word", anywhere
    public var css: String { rawValue }
}

/// `text-wrap`.
public enum TextWrap: String, CSSValueConvertible {
    case wrap, nowrap, balance, pretty, stable
    public var css: String { rawValue }
}

/// `font-variant-numeric`.
public enum FontVariantNumeric: String, CSSValueConvertible {
    case normal
    case tabularNums = "tabular-nums", oldstyleNums = "oldstyle-nums"
    case liningNums = "lining-nums", proportionalNums = "proportional-nums"
    public var css: String { rawValue }
}

/// `list-style-type`: keyword cases plus an arbitrary custom ident (validated).
public enum ListStyleType: CSSValueConvertible {
    case disc, circle, square, decimal
    case decimalLeadingZero, lowerRoman, upperRoman, lowerAlpha, upperAlpha, lowerGreek
    case none
    case custom(String)
    public var css: String {
        switch self {
        case .disc: return "disc"
        case .circle: return "circle"
        case .square: return "square"
        case .decimal: return "decimal"
        case .decimalLeadingZero: return "decimal-leading-zero"
        case .lowerRoman: return "lower-roman"
        case .upperRoman: return "upper-roman"
        case .lowerAlpha: return "lower-alpha"
        case .upperAlpha: return "upper-alpha"
        case .lowerGreek: return "lower-greek"
        case .none: return "none"
        case .custom(let s):
            guard CSSSanitize.isValidIdent(s) else {
                assertionFailure("invalid list-style-type ident: \(s)")
                return "disc"
            }
            return s
        }
    }
}

/// `font-variant` (shorthand keyword subset).
public enum FontVariant: String, CSSValueConvertible {
    case normal, none, smallCaps = "small-caps"
    public var css: String { rawValue }
}

/// `font-stretch`.
public enum FontStretch: String, CSSValueConvertible {
    case normal
    case ultraCondensed = "ultra-condensed", extraCondensed = "extra-condensed", condensed
    case semiCondensed = "semi-condensed", semiExpanded = "semi-expanded", expanded
    case extraExpanded = "extra-expanded", ultraExpanded = "ultra-expanded"
    public var css: String { rawValue }
}

/// `font-optical-sizing`.
public enum FontOpticalSizing: String, CSSValueConvertible {
    case auto, none
    public var css: String { rawValue }
}

/// Font smoothing. `antialiased`/`subpixel-antialiased` are valid only on the
/// prefixed `-webkit-font-smoothing`; the modifier emits `font-smooth` only for
/// `auto`/`none`.
public enum FontSmoothing: String, CSSValueConvertible {
    case auto, none, antialiased, subpixelAntialiased = "subpixel-antialiased"
    public var css: String { rawValue }
}

/// `text-align-last`.
public enum TextAlignLast: String, CSSValueConvertible {
    case auto, start, end, left, right, center, justify
    public var css: String { rawValue }
}

/// `hyphens`.
public enum Hyphens: String, CSSValueConvertible {
    case none, manual, auto
    public var css: String { rawValue }
}

/// `direction`.
public enum Direction: String, CSSValueConvertible {
    case ltr, rtl
    public var css: String { rawValue }
}

/// `caret-color`: the `auto` keyword or an explicit color.
public enum CaretColor: Equatable, CSSValueConvertible {
    case auto
    case color(CSSColor)
    public var css: String {
        switch self {
        case .auto: return "auto"
        case .color(let c): return c.css
        }
    }
}

/// `-webkit-text-stroke`: a stroke width paired with a color.
public struct TextStroke: Equatable, CSSValueConvertible {
    public var width: CSSLength
    public var color: CSSColor
    public init(width: CSSLength, color: CSSColor) { self.width = width; self.color = color }
    public var css: String { "\(width.css) \(color.css)" }
}

/// `vertical-align`: keyword cases or an explicit length.
public enum VerticalAlign: Equatable, CSSValueConvertible {
    case baseline, sub, `super`, textTop, textBottom, middle, top, bottom
    case length(CSSLength)
    public var css: String {
        switch self {
        case .baseline: return "baseline"
        case .sub: return "sub"
        case .super: return "super"
        case .textTop: return "text-top"
        case .textBottom: return "text-bottom"
        case .middle: return "middle"
        case .top: return "top"
        case .bottom: return "bottom"
        case .length(let l): return l.css
        }
    }
}
