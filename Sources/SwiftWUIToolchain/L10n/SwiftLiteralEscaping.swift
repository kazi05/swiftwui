import Foundation

/// The ONLY path from catalog text into generated Swift source.
///
/// Catalog values are translator-supplied data; this is where data becomes
/// code, so it gets the same treatment as `HTMLEscaping` on the render side:
/// one audited function, no second route, output always a complete quoted
/// literal.
///
/// Escaped: `\`, `"`, and every Unicode control character (category Cc —
/// U+0000...U+001F, U+007F...U+009F), plus U+2028 and U+2029. That covers
/// every scalar that can terminate a Swift string literal or a source line;
/// everything else is copied through, so translations keep their own
/// punctuation, emoji and scripts intact.
public enum SwiftLiteralEscaping {
    public static func literal(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\0": out += "\\0"
            case "\u{2028}", "\u{2029}": out += String(format: "\\u{%04X}", scalar.value)
            default:
                if scalar.value < 0x20 || (0x7F...0x9F).contains(scalar.value) {
                    out += String(format: "\\u{%04X}", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}
