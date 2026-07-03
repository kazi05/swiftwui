public protocol CSSValueConvertible {
    var css: String { get }
}

/// Integer-valued doubles render without a trailing ".0" (Foundation-free).
func cssNumber(_ d: Double) -> String {
    if d == d.rounded(), abs(d) < 1e15 { return String(Int(d)) }
    return String(d)
}

public enum CSSLength: Equatable, CSSValueConvertible {
    case px(Double), rem(Double), em(Double), percent(Double), vw(Double), vh(Double)
    case auto, zero
    case variable(String)
    public var css: String {
        switch self {
        case .px(let v): return cssNumber(v) + "px"
        case .rem(let v): return cssNumber(v) + "rem"
        case .em(let v): return cssNumber(v) + "em"
        case .percent(let v): return cssNumber(v) + "%"
        case .vw(let v): return cssNumber(v) + "vw"
        case .vh(let v): return cssNumber(v) + "vh"
        case .auto: return "auto"
        case .zero: return "0"
        case .variable(let name): return "var(--\(name))"
        }
    }
}

public enum CSSColor: Equatable, CSSValueConvertible {
    case hex(String)                       // "#RGB" | "#RRGGBB" | "#RRGGBBAA"
    case rgb(Int, Int, Int)
    case rgba(Int, Int, Int, Double)
    case white, black, transparent, current
    case variable(String)                  // var(--name); built via .token(_:) in Task 9
    public var css: String {
        switch self {
        case .hex(let s):
            guard Self.isValidHex(s) else {
                assertionFailure("invalid hex color: \(s)")
                return "transparent"
            }
            return s
        case .rgb(let r, let g, let b): return "rgb(\(r), \(g), \(b))"
        case .rgba(let r, let g, let b, let a): return "rgba(\(r), \(g), \(b), \(cssNumber(a)))"
        case .white: return "#fff"
        case .black: return "#000"
        case .transparent: return "transparent"
        case .current: return "currentColor"
        case .variable(let name): return "var(--\(name))"
        }
    }
    static func isValidHex(_ s: String) -> Bool {
        guard s.first == "#" else { return false }
        let digits = s.dropFirst()
        guard [3, 6, 8].contains(digits.count) else { return false }
        return digits.allSatisfy { $0.isHexDigit }
    }
}

public enum Display: String, CSSValueConvertible {
    case block, inline, flex, grid, none, contents
    case inlineBlock = "inline-block", inlineFlex = "inline-flex"
    public var css: String { rawValue }
}
public enum Position: String, CSSValueConvertible {
    case `static`, relative, absolute, fixed, sticky
    public var css: String { rawValue }
}
public enum FlexDirection: String, CSSValueConvertible {
    case row, column, rowReverse = "row-reverse", columnReverse = "column-reverse"
    public var css: String { rawValue }
}
public enum FlexWrap: String, CSSValueConvertible {
    case nowrap, wrap, wrapReverse = "wrap-reverse"
    public var css: String { rawValue }
}
public enum JustifyContent: String, CSSValueConvertible {
    case flexStart = "flex-start", flexEnd = "flex-end", center
    case spaceBetween = "space-between", spaceAround = "space-around", spaceEvenly = "space-evenly"
    public var css: String { rawValue }
}
public enum AlignItems: String, CSSValueConvertible {
    case flexStart = "flex-start", flexEnd = "flex-end", center, baseline, stretch
    public var css: String { rawValue }
}
public enum TextAlign: String, CSSValueConvertible {
    case left, right, center, justify
    public var css: String { rawValue }
}
public enum TextDecoration: String, CSSValueConvertible {
    case none, underline, overline, lineThrough = "line-through"
    public var css: String { rawValue }
}
public enum FontWeight: CSSValueConvertible {
    case normal, bold, custom(Int)
    public var css: String {
        switch self {
        case .normal: return "normal"; case .bold: return "bold"
        case .custom(let w): return String(w)
        }
    }
}
public enum Cursor: String, CSSValueConvertible {
    case auto, `default`, pointer, text, move, notAllowed = "not-allowed", grab
    public var css: String { rawValue }
}
public enum Overflow: String, CSSValueConvertible {
    case visible, hidden, scroll, auto
    public var css: String { rawValue }
}
public enum BorderStyle: String, CSSValueConvertible {
    case none, solid, dashed, dotted, double
    public var css: String { rawValue }
}
public enum BoxSizing: String, CSSValueConvertible {
    case contentBox = "content-box", borderBox = "border-box"
    public var css: String { rawValue }
}
public enum Outline: CSSValueConvertible {
    case none, custom(String)
    public var css: String {
        switch self { case .none: return "none"; case .custom(let s): return s }
    }
}
public enum Side: String {
    case top, right, bottom, left
}

/// Validation choke points for the string escape hatches (spec §12).
public enum CSSSanitize {
    /// CSS ident: letters/digits/hyphen/underscore, must not start with a digit.
    public static func isValidIdent(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first else { return false }
        func alpha(_ c: Unicode.Scalar) -> Bool { ("a"..."z").contains(c) || ("A"..."Z").contains(c) }
        guard alpha(first) || first == "_" || first == "-" else { return false }
        return s.unicodeScalars.allSatisfy {
            alpha($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == "-"
        }
    }
    /// Declaration values must not be able to escape a rule body.
    public static func isSafeValue(_ s: String) -> Bool {
        !s.unicodeScalars.contains { $0 == "{" || $0 == "}" || $0.properties.generalCategory == .control }
    }
}
