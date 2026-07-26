// Effects/motion CSS value types. Pure value types;
// reuse `CSSLength`/`CSSColor`/`CSSSanitize`/`cssNumber` from CSSValues.swift.

/// CSS `<angle>`. Integer-valued doubles render without a trailing `.0`.
public enum CSSAngle: Equatable, CSSValueConvertible {
    case deg(Double), turn(Double), rad(Double), grad(Double)
    public var css: String {
        switch self {
        case .deg(let v): return cssNumber(v) + "deg"
        case .turn(let v): return cssNumber(v) + "turn"
        case .rad(let v): return cssNumber(v) + "rad"
        case .grad(let v): return cssNumber(v) + "grad"
        }
    }
}

/// CSS `<time>`.
public enum CSSDuration: Equatable, CSSValueConvertible {
    case s(Double), ms(Double)
    public var css: String {
        switch self {
        case .s(let v): return cssNumber(v) + "s"
        case .ms(let v): return cssNumber(v) + "ms"
        }
    }
}

extension CSSDuration {
    /// Numeric milliseconds. Needed by the view-transition FLIP fallback, which
    /// drives WAAPI rather than CSS. Internal: the `_` prefix in this codebase
    /// marks cross-module SPI, which this is not.
    var milliseconds: Double {
        switch self {
        case .s(let v): return v * 1000
        case .ms(let v): return v
        }
    }
}

/// `steps()` jump-position keyword.
public enum StepPosition: String, CSSValueConvertible {
    case start, end
    case jumpStart = "jump-start", jumpEnd = "jump-end"
    case jumpBoth = "jump-both", jumpNone = "jump-none"
    public var css: String { rawValue }
}

/// CSS `<easing-function>`.
public enum TimingFunction: Equatable, CSSValueConvertible {
    case ease, easeIn, easeOut, easeInOut, linear, stepStart, stepEnd
    case cubicBezier(Double, Double, Double, Double)
    case steps(Int, StepPosition)
    public var css: String {
        switch self {
        case .ease: return "ease"
        case .easeIn: return "ease-in"
        case .easeOut: return "ease-out"
        case .easeInOut: return "ease-in-out"
        case .linear: return "linear"
        case .stepStart: return "step-start"
        case .stepEnd: return "step-end"
        case .cubicBezier(let a, let b, let c, let d):
            return "cubic-bezier(\(cssNumber(a)), \(cssNumber(b)), \(cssNumber(c)), \(cssNumber(d)))"
        case .steps(let n, let pos): return "steps(\(n), \(pos.css))"
        }
    }
}

/// `mix-blend-mode` / `background-blend-mode`.
public enum BlendMode: String, CSSValueConvertible {
    case normal, multiply, screen, overlay, darken, lighten
    case colorDodge = "color-dodge", colorBurn = "color-burn"
    case hardLight = "hard-light", softLight = "soft-light"
    case difference, exclusion, hue, saturation, color, luminosity
    public var css: String { rawValue }
}

/// One shadow layer, shared by `box-shadow` and `text-shadow`.
/// `text-shadow` ignores `spread`/`inset` — use `textShadowCSS` for it.
public struct Shadow: Equatable {
    public var offsetX: CSSLength
    public var offsetY: CSSLength
    public var blur: CSSLength
    public var spread: CSSLength
    public var color: CSSColor
    public var inset: Bool
    public init(offsetX: CSSLength, offsetY: CSSLength, blur: CSSLength = .zero,
                spread: CSSLength = .zero, color: CSSColor = .black, inset: Bool = false) {
        self.offsetX = offsetX; self.offsetY = offsetY; self.blur = blur
        self.spread = spread; self.color = color; self.inset = inset
    }
    /// `box-shadow`: `"[inset ]ox oy blur spread color"`.
    public var boxShadowCSS: String {
        let prefix = inset ? "inset " : ""
        return "\(prefix)\(offsetX.css) \(offsetY.css) \(blur.css) \(spread.css) \(color.css)"
    }
    /// `text-shadow`: `"ox oy blur color"` — no spread/inset.
    public var textShadowCSS: String {
        "\(offsetX.css) \(offsetY.css) \(blur.css) \(color.css)"
    }
}

/// A single `filter`/`backdrop-filter` function.
public enum FilterFunction: Equatable, CSSValueConvertible {
    case blur(CSSLength)
    case brightness(Double)
    case contrast(Double)
    case grayscale(Double)
    case invert(Double)
    case opacity(Double)
    case saturate(Double)
    case sepia(Double)
    case hueRotate(CSSAngle)
    case dropShadow(x: CSSLength, y: CSSLength, blur: CSSLength, color: CSSColor)
    case url(String)
    public var css: String {
        switch self {
        case .blur(let l): return "blur(\(l.css))"
        case .brightness(let v): return "brightness(\(cssNumber(v)))"
        case .contrast(let v): return "contrast(\(cssNumber(v)))"
        case .grayscale(let v): return "grayscale(\(cssNumber(v)))"
        case .invert(let v): return "invert(\(cssNumber(v)))"
        case .opacity(let v): return "opacity(\(cssNumber(v)))"
        case .saturate(let v): return "saturate(\(cssNumber(v)))"
        case .sepia(let v): return "sepia(\(cssNumber(v)))"
        case .hueRotate(let a): return "hue-rotate(\(a.css))"
        case .dropShadow(let x, let y, let blur, let color):
            return "drop-shadow(\(x.css) \(y.css) \(blur.css) \(color.css))"
        case .url(let s):
            guard CSSSanitize.isSafeValue(s) else {
                assertionFailure("unsafe filter url: \(s)")
                return "none"
            }
            return "url(\(s))"
        }
    }
}

/// A single `transform` function. `translate*` take `CSSLength` so percents work.
public enum TransformFunction: Equatable, CSSValueConvertible {
    case translate(x: CSSLength, y: CSSLength)
    case translateX(CSSLength)
    case translateY(CSSLength)
    case translateZ(CSSLength)
    case scale(x: Double, y: Double)
    case scaleX(Double)
    case scaleY(Double)
    case scaleZ(Double)
    case rotate(CSSAngle)
    case rotateX(CSSAngle)
    case rotateY(CSSAngle)
    case rotateZ(CSSAngle)
    case skew(x: Double, y: Double)
    case skewX(Double)
    case skewY(Double)
    case matrix(Double, Double, Double, Double, Double, Double)
    case perspective(CSSLength)
    public var css: String {
        switch self {
        case .translate(let x, let y): return "translate(\(x.css), \(y.css))"
        case .translateX(let l): return "translateX(\(l.css))"
        case .translateY(let l): return "translateY(\(l.css))"
        case .translateZ(let l): return "translateZ(\(l.css))"
        case .scale(let x, let y): return "scale(\(cssNumber(x)), \(cssNumber(y)))"
        case .scaleX(let v): return "scaleX(\(cssNumber(v)))"
        case .scaleY(let v): return "scaleY(\(cssNumber(v)))"
        case .scaleZ(let v): return "scaleZ(\(cssNumber(v)))"
        case .rotate(let a): return "rotate(\(a.css))"
        case .rotateX(let a): return "rotateX(\(a.css))"
        case .rotateY(let a): return "rotateY(\(a.css))"
        case .rotateZ(let a): return "rotateZ(\(a.css))"
        case .skew(let x, let y): return "skew(\(cssNumber(x)), \(cssNumber(y)))"
        case .skewX(let v): return "skewX(\(cssNumber(v)))"
        case .skewY(let v): return "skewY(\(cssNumber(v)))"
        case .matrix(let a, let b, let c, let d, let e, let f):
            return "matrix(\(cssNumber(a)), \(cssNumber(b)), \(cssNumber(c)), \(cssNumber(d)), \(cssNumber(e)), \(cssNumber(f)))"
        case .perspective(let l): return "perspective(\(l.css))"
        }
    }
}

/// `background-repeat`.
public enum BackgroundRepeat: String, CSSValueConvertible {
    case `repeat`   // `repeat` is a Swift keyword → backticked; rawValue is still "repeat"
    case repeatX = "repeat-x", repeatY = "repeat-y", noRepeat = "no-repeat"
    case space, round
    public var css: String { rawValue }
}

/// A gradient color stop: a color, or a color at a position.
public enum CSSGradientStop: Equatable, CSSValueConvertible {
    case color(CSSColor)
    case colorAt(CSSColor, CSSLength)
    public var css: String {
        switch self {
        case .color(let c): return c.css
        case .colorAt(let c, let pos): return "\(c.css) \(pos.css)"
        }
    }
}

/// `background-image`: `none`, `url()`, gradients, or a layered comma list.
/// Raw string sub-fields must pass `CSSSanitize.isSafeValue` — invalid ones are
/// dropped to a safe fallback.
public indirect enum CSSBackgroundImage: Equatable, CSSValueConvertible {
    case none
    case url(String)
    case linearGradient(angle: CSSAngle? = nil, stops: [CSSGradientStop])
    case radialGradient(shape: String? = nil, size: String? = nil, at: String? = nil, stops: [CSSGradientStop])
    case conicGradient(angle: CSSAngle? = nil, at: String? = nil, stops: [CSSGradientStop])
    case layered([CSSBackgroundImage])

    public var css: String {
        switch self {
        case .none: return "none"
        case .url(let s):
            guard CSSSanitize.isSafeValue(s) else {
                assertionFailure("unsafe background-image url: \(s)")
                return "none"
            }
            return "url(\(s))"
        case .linearGradient(let angle, let stops):
            var parts: [String] = []
            if let angle { parts.append(angle.css) }
            parts.append(contentsOf: stops.map(\.css))
            return "linear-gradient(\(parts.joined(separator: ", ")))"
        case .radialGradient(let shape, let size, let at, let stops):
            var prefix: [String] = []
            if let shape = Self.safe(shape) { prefix.append(shape) }
            if let size = Self.safe(size) { prefix.append(size) }
            if let at = Self.safe(at) { prefix.append("at \(at)") }
            var parts: [String] = []
            if !prefix.isEmpty { parts.append(prefix.joined(separator: " ")) }
            parts.append(contentsOf: stops.map(\.css))
            return "radial-gradient(\(parts.joined(separator: ", ")))"
        case .conicGradient(let angle, let at, let stops):
            var prefix: [String] = []
            if let angle { prefix.append("from \(angle.css)") }
            if let at = Self.safe(at) { prefix.append("at \(at)") }
            var parts: [String] = []
            if !prefix.isEmpty { parts.append(prefix.joined(separator: " ")) }
            parts.append(contentsOf: stops.map(\.css))
            return "conic-gradient(\(parts.joined(separator: ", ")))"
        case .layered(let layers):
            return layers.map(\.css).joined(separator: ", ")
        }
    }

    /// Returns the string if it passes the value sanitizer, else drops it (asserts in debug).
    private static func safe(_ s: String?) -> String? {
        guard let s else { return nil }
        guard CSSSanitize.isSafeValue(s) else {
            assertionFailure("unsafe gradient sub-field: \(s)")
            return nil
        }
        return s
    }
}

/// `clip-path`: a basic shape, an `inset()`, a `polygon()`, or a raw string.
/// `custom` raw strings must pass `CSSSanitize.isSafeValue` — invalid ones fall
/// back to `none`.
public enum ClipPath: Equatable, CSSValueConvertible {
    case none
    case circle(radius: CSSLength = .percent(50), at: UnitPoint = .center)
    case ellipse(rx: CSSLength, ry: CSSLength, at: UnitPoint = .center)
    case inset(_ top: CSSLength, _ right: CSSLength, _ bottom: CSSLength, _ left: CSSLength, round: CSSLength? = nil)
    case polygon([UnitPoint])
    case custom(String)
    public var css: String {
        switch self {
        case .none: return "none"
        case .circle(let radius, let at):
            return "circle(\(radius.css) at \(at.cssTransformOrigin))"
        case .ellipse(let rx, let ry, let at):
            return "ellipse(\(rx.css) \(ry.css) at \(at.cssTransformOrigin))"
        case .inset(let top, let right, let bottom, let left, let round):
            let base = "\(top.css) \(right.css) \(bottom.css) \(left.css)"
            if let round { return "inset(\(base) round \(round.css))" }
            return "inset(\(base))"
        case .polygon(let points):
            return "polygon(\(points.map(\.cssTransformOrigin).joined(separator: ", ")))"
        case .custom(let s):
            guard CSSSanitize.isSafeValue(s) else {
                assertionFailure("unsafe clip-path: \(s)")
                return "none"
            }
            return s
        }
    }
}

/// `transform-style`.
public enum TransformStyle: String, CSSValueConvertible {
    case flat
    case preserve3d = "preserve-3d"
    public var css: String { rawValue }
}

/// `backface-visibility`.
public enum BackfaceVisibility: String, CSSValueConvertible {
    case visible, hidden
    public var css: String { rawValue }
}

/// A single `will-change` hint. A `.property` name must be a CSS ident; an
/// invalid one asserts in debug and falls back to `auto`.
public enum WillChange: Equatable, CSSValueConvertible {
    case auto
    case scrollPosition
    case contents
    case property(String)
    public var css: String {
        switch self {
        case .auto: return "auto"
        case .scrollPosition: return "scroll-position"
        case .contents: return "contents"
        case .property(let name):
            guard CSSSanitize.isValidIdent(name) else {
                assertionFailure("invalid will-change property ident: \(name)")
                return "auto"
            }
            return name
        }
    }
}
