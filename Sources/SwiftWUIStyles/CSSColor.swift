// CSSColor.swift - Type-safe CSS colors

/// Type-safe CSS color values.
public struct CSSColor: Sendable {
    public let cssValue: String

    public init(cssValue: String) {
        self.cssValue = cssValue
    }

    // MARK: - Named Colors

    public static let transparent = CSSColor(cssValue: "transparent")
    public static let currentColor = CSSColor(cssValue: "currentColor")
    public static let inherit = CSSColor(cssValue: "inherit")

    // Basic
    public static let black = CSSColor(cssValue: "#000000")
    public static let white = CSSColor(cssValue: "#ffffff")
    public static let red = CSSColor(cssValue: "#ff0000")
    public static let green = CSSColor(cssValue: "#008000")
    public static let blue = CSSColor(cssValue: "#0000ff")
    public static let yellow = CSSColor(cssValue: "#ffff00")
    public static let orange = CSSColor(cssValue: "#ffa500")
    public static let purple = CSSColor(cssValue: "#800080")
    public static let pink = CSSColor(cssValue: "#ffc0cb")
    public static let gray = CSSColor(cssValue: "#808080")
    public static let lightGray = CSSColor(cssValue: "#d3d3d3")
    public static let darkGray = CSSColor(cssValue: "#a9a9a9")
    public static let cyan = CSSColor(cssValue: "#00ffff")
    public static let magenta = CSSColor(cssValue: "#ff00ff")
    public static let brown = CSSColor(cssValue: "#a52a2a")
    public static let navy = CSSColor(cssValue: "#000080")
    public static let teal = CSSColor(cssValue: "#008080")
    public static let indigo = CSSColor(cssValue: "#4b0082")
    public static let coral = CSSColor(cssValue: "#ff7f50")

    // MARK: - Constructors

    /// Create a color from a hex string (with or without #).
    public init(hex: String) {
        let hex = hex.hasPrefix("#") ? hex : "#\(hex)"
        self.cssValue = hex
    }

    /// Create an RGB color.
    public static func rgb(_ r: Int, _ g: Int, _ b: Int) -> CSSColor {
        CSSColor(cssValue: "rgb(\(r), \(g), \(b))")
    }

    /// Create an RGBA color.
    public static func rgba(_ r: Int, _ g: Int, _ b: Int, _ a: Double) -> CSSColor {
        CSSColor(cssValue: "rgba(\(r), \(g), \(b), \(a))")
    }

    /// Create an HSL color.
    public static func hsl(_ h: Int, _ s: Int, _ l: Int) -> CSSColor {
        CSSColor(cssValue: "hsl(\(h), \(s)%, \(l)%)")
    }

    /// Create an HSLA color.
    public static func hsla(_ h: Int, _ s: Int, _ l: Int, _ a: Double) -> CSSColor {
        CSSColor(cssValue: "hsla(\(h), \(s)%, \(l)%, \(a))")
    }
}
