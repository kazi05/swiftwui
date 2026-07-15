// Border/background CSS value types. String-backed enums;
// `var css: String { rawValue }`, matching the CSSValues.swift enum style.

/// `background-clip`. The `.text` value drives gradient-text; it requires the
/// prefixed emit handled by the modifier.
public enum BackgroundClip: String, CSSValueConvertible {
    case borderBox = "border-box", paddingBox = "padding-box", contentBox = "content-box"
    case text
    public var css: String { rawValue }
}

/// `outline-style`.
public enum OutlineStyle: String, CSSValueConvertible {
    case auto, none, dotted, dashed, solid, double, groove, ridge, inset, outset
    public var css: String { rawValue }
}

/// `background-attachment`.
public enum BackgroundAttachment: String, CSSValueConvertible {
    case scroll, fixed, local
    public var css: String { rawValue }
}

/// `background-origin`.
public enum BackgroundOrigin: String, CSSValueConvertible {
    case borderBox = "border-box", paddingBox = "padding-box", contentBox = "content-box"
    public var css: String { rawValue }
}
