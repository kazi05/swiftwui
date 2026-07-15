// Layout-module CSS value types. Pure value types;
// reuse `CSSLength`/`CSSSanitize`/`cssNumber` from CSSValues.swift.

/// `aspect-ratio`: `auto` or `<w> / <h>`. Renders via `cssNumber` so
/// `.ratio(16, 9)` is `"16 / 9"`, never `"16.0 / 9.0"`.
public enum AspectRatio: Equatable, CSSValueConvertible {
    case auto
    case ratio(Double, Double)
    public var css: String {
        switch self {
        case .auto: return "auto"
        case .ratio(let w, let h): return cssNumber(w) + " / " + cssNumber(h)
        }
    }
}

/// A grid line reference for `grid-row`/`grid-column` (start/end).
/// `.name`/`.span(name)` idents are sanitized — invalid → fallback `"auto"`.
public enum GridLine: Equatable, CSSValueConvertible {
    case auto
    case line(Int)
    case name(String)
    case span(Int)
    public var css: String {
        switch self {
        case .auto: return "auto"
        case .line(let n): return String(n)
        case .name(let s):
            guard CSSSanitize.isValidIdent(s) else {
                assertionFailure("invalid grid line name: \(s)")
                return "auto"
            }
            return s
        case .span(let n): return "span \(n)"
        }
    }
}

/// `object-position`: an x/y length pair (percentages allowed via `CSSLength`).
public struct ObjectPosition: Equatable, CSSValueConvertible {
    public var x: CSSLength
    public var y: CSSLength
    public init(x: CSSLength, y: CSSLength) { self.x = x; self.y = y }
    public var css: String { "\(x.css) \(y.css)" }

    public static let center = ObjectPosition(x: .percent(50), y: .percent(50))
    public static let top = ObjectPosition(x: .percent(50), y: .percent(0))
    public static let bottom = ObjectPosition(x: .percent(50), y: .percent(100))
    public static let left = ObjectPosition(x: .percent(0), y: .percent(50))
    public static let right = ObjectPosition(x: .percent(100), y: .percent(50))
    public static let topLeft = ObjectPosition(x: .percent(0), y: .percent(0))
    public static let topRight = ObjectPosition(x: .percent(100), y: .percent(0))
    public static let bottomLeft = ObjectPosition(x: .percent(0), y: .percent(100))
    public static let bottomRight = ObjectPosition(x: .percent(100), y: .percent(100))
}

/// `background-position`: keyword pairs or a custom x/y length pair.
public enum BackgroundPosition: Equatable, CSSValueConvertible {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight
    case custom(x: CSSLength, y: CSSLength)
    public var css: String {
        switch self {
        case .topLeft: return "left top"
        case .top: return "center top"
        case .topRight: return "right top"
        case .left: return "left center"
        case .center: return "center"
        case .right: return "right center"
        case .bottomLeft: return "left bottom"
        case .bottom: return "center bottom"
        case .bottomRight: return "right bottom"
        case .custom(let x, let y): return "\(x.css) \(y.css)"
        }
    }
}

/// `background-size`: keyword or an explicit width (+ optional height).
public enum BackgroundSize: Equatable, CSSValueConvertible {
    case auto, cover, contain
    case custom(width: CSSLength, height: CSSLength?)
    public var css: String {
        switch self {
        case .auto: return "auto"
        case .cover: return "cover"
        case .contain: return "contain"
        case .custom(let w, let h):
            if let h { return "\(w.css) \(h.css)" }
            return w.css
        }
    }
}

/// Per-corner `border-radius`. No literal conformances — `borderRadius(8)`
/// must stay unambiguous against the `CSSLength` overload.
public struct BorderRadius: Equatable, CSSValueConvertible {
    public var topLeft: CSSLength
    public var topRight: CSSLength
    public var bottomRight: CSSLength
    public var bottomLeft: CSSLength
    public init(all: CSSLength) {
        self.topLeft = all; self.topRight = all
        self.bottomRight = all; self.bottomLeft = all
    }
    public init(topLeft: CSSLength = .zero, topRight: CSSLength = .zero,
                bottomRight: CSSLength = .zero, bottomLeft: CSSLength = .zero) {
        self.topLeft = topLeft; self.topRight = topRight
        self.bottomRight = bottomRight; self.bottomLeft = bottomLeft
    }
    public var css: String {
        "\(topLeft.css) \(topRight.css) \(bottomRight.css) \(bottomLeft.css)"
    }
}

// Dedicated align/justify enums — MUST NOT reuse AlignItems/JustifyContent:
// they carry extra `left`/`right`/`self-*`/distribution cases.

public enum JustifyItems: String, CSSValueConvertible {
    case normal, stretch, center, start, end
    case flexStart = "flex-start", flexEnd = "flex-end"
    case selfStart = "self-start", selfEnd = "self-end"
    case left, right, baseline
    public var css: String { rawValue }
}

public enum JustifySelf: String, CSSValueConvertible {
    case auto, normal, stretch, center, start, end
    case flexStart = "flex-start", flexEnd = "flex-end"
    case selfStart = "self-start", selfEnd = "self-end"
    case left, right, baseline
    public var css: String { rawValue }
}

public enum AlignContent: String, CSSValueConvertible {
    case normal, stretch, center, start, end
    case flexStart = "flex-start", flexEnd = "flex-end"
    case spaceBetween = "space-between", spaceAround = "space-around", spaceEvenly = "space-evenly"
    case baseline
    public var css: String { rawValue }
}

/// `object-fit`.
public enum ObjectFit: String, CSSValueConvertible {
    case fill, contain, cover, none, scaleDown = "scale-down"
    public var css: String { rawValue }
}

/// `visibility`.
public enum Visibility: String, CSSValueConvertible {
    case visible, hidden, collapse
    public var css: String { rawValue }
}

/// `grid-auto-flow`. `rowDense`/`columnDense` render the two-keyword forms.
public enum GridAutoFlow: String, CSSValueConvertible {
    case row, column, dense
    case rowDense = "row dense", columnDense = "column dense"
    public var css: String { rawValue }
}

/// `float`. Named `CSSFloat` to avoid clashing with Swift's `Float`; the modifier
/// is still `float(_:)`.
public enum CSSFloat: String, CSSValueConvertible {
    case left, right, none
    case inlineStart = "inline-start", inlineEnd = "inline-end"
    public var css: String { rawValue }
}

/// `clear`.
public enum Clear: String, CSSValueConvertible {
    case none, left, right, both
    case inlineStart = "inline-start", inlineEnd = "inline-end"
    public var css: String { rawValue }
}

/// `isolation`.
public enum Isolation: String, CSSValueConvertible {
    case auto, isolate
    public var css: String { rawValue }
}
