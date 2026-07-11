/// A typed `@font-face` declaration (assets spec §7), registered app-wide via
/// `App.fontFaces` — the exact plumbing `App.themes` uses. `family` and `src`
/// are emitted inside CSS quoted strings, same validated-sink discipline as
/// `ThemeAssignments.set` in Theme.swift: `\` and `"` are escaped, control
/// characters (< 0x20, e.g. newline) are dropped so no unescaped scalar can
/// terminate the quoted string early, and `<` is hex-escaped as `\3c ` so the
/// text is inert even if it lands inside the SSG inline `<style>` sink. `src`
/// also passes `HTMLEscaping.sanitizeURL` first. No CSS or HTML breakout.
public struct FontFace: Equatable {
    public enum FontFormat: String, Equatable { case woff2, woff, truetype, opentype }
    public enum FontFaceStyle: String, Equatable { case normal, italic }
    public enum FontDisplay: String, Equatable { case auto, block, swap, fallback, optional }

    public var family: String
    public var src: String
    public var format: FontFormat?
    public var weight: ClosedRange<Int>?
    public var style: FontFaceStyle
    public var display: FontDisplay

    public init(family: String, src: String, format: FontFormat? = nil,
                weight: ClosedRange<Int>? = nil, style: FontFaceStyle = .normal,
                display: FontDisplay = .swap) {
        self.family = family; self.src = src; self.format = format
        self.weight = weight; self.style = style; self.display = display
    }
    public init(family: String, src: String, format: FontFormat? = nil,
                weight: Int, style: FontFaceStyle = .normal,
                display: FontDisplay = .swap) {
        self.init(family: family, src: src, format: format,
                  weight: weight...weight, style: style, display: display)
    }

    // Foundation-free: manual scalar loop instead of replacingOccurrences (core stays zero-dep).
    static func cssString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            if scalar.value < 0x20 { continue }              // drop control chars incl. newline — no bad-string breakout
            if scalar == "<" { out += "\\3c "; continue }     // CSS hex escape — inert inside SSG's `</style` sink
            if scalar == "\\" || scalar == "\"" { out.append("\\") }
            out.unicodeScalars.append(scalar)
        }
        return out + "\""
    }

    var ruleText: String {
        var decls = ["font-family: \(Self.cssString(family))"]
        var srcValue = "url(\(Self.cssString(HTMLEscaping.sanitizeURL(src))))"
        if let format { srcValue += " format(\(Self.cssString(format.rawValue)))" }
        decls.append("src: \(srcValue)")
        if let weight {
            decls.append(weight.lowerBound == weight.upperBound
                ? "font-weight: \(weight.lowerBound)"
                : "font-weight: \(weight.lowerBound) \(weight.upperBound)")
        }
        decls.append("font-style: \(style.rawValue)")
        decls.append("font-display: \(display.rawValue)")
        return "@font-face { \(decls.joined(separator: "; ")) }"
    }
}
