// HTMLEscaping.swift — the single audited escaping choke point for every
// string-output sink in SwiftWUI.
//
// HTML is emitted from three renderers (StaticRenderer, PageRenderer, the SSR
// document assembler) plus one CSS sink (StyleSheetManager). Each used to carry
// its own partial escaping, so class/style attribute values, inline
// `<style>`/`<script>` text, and embedded JSON state were interpolated raw —
// an XSS surface. Route every sink through these helpers instead.
//
// Foundation-free on purpose: this is hot-path SSR/SSG code and Core stays
// light for the WASM binary.
public enum HTMLEscaping {

    /// Escape text and attribute values for HTML. Safe for element text nodes
    /// and for any `attr="…"` value, including `class`/`style` attributes where
    /// escaping `"` is what prevents attribute breakout.
    public static func text(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Make JSON safe to embed inside a `<script>` element. A `</script>`
    /// substring in a JSON string value would otherwise close the block;
    /// escaping `<`/`>` as `\uXXXX` keeps the JSON valid (these only ever appear
    /// inside string values) while making a literal tag impossible. Also escapes
    /// U+2028/U+2029, which are legal in JSON but terminate a JS line.
    public static func scriptJSON(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "<": out += "\\u003c"
            case ">": out += "\\u003e"
            case "\u{2028}": out += "\\u2028"
            case "\u{2029}": out += "\\u2029"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Make arbitrary text safe as the content of a raw-text element
    /// (`<style>` / `<script>`). The HTML parser ends these only on the literal
    /// `</` + tag name, so neutralising every `</` to `<\/` prevents an early
    /// close. `<\/` is a no-op inside JS strings and harmless in CSS.
    public static func rawTextElement(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        var iterator = s.makeIterator()
        var pending = iterator.next()
        while let c = pending {
            let next = iterator.next()
            if c == "<" && next == "/" {
                out += "<\\/"
                pending = iterator.next()
            } else {
                out.append(c)
                pending = next
            }
        }
        return out
    }

    /// Sanitise a CSS property name or value before it is interpolated into a
    /// stylesheet rule. Strips the characters that can escape a declaration or
    /// rule (`{`, `}`, `;`) and the raw-text terminators (`<`, `>`), so a value
    /// can neither break its rule nor close a `<style>` block. A legitimate CSS
    /// value never needs any of these.
    public static func cssToken(_ s: String) -> String {
        String(s.filter { $0 != "{" && $0 != "}" && $0 != ";" && $0 != "<" && $0 != ">" })
    }

    /// Schemes safe to place in an `href`/`src` produced from app data. Anything
    /// else (notably `javascript:`, `data:`, `vbscript:`) is dropped to `#`.
    /// Relative URLs (no scheme) and fragment/query-only URLs are always allowed.
    public static func sanitizeURL(_ url: String) -> String {
        let trimmed = url.trimmingASCIIWhitespaceAndControls()
        guard let colon = trimmed.firstIndex(of: ":") else { return url } // no scheme → relative, safe
        // A "/" or "?" or "#" before the first ":" means the ":" is in a path
        // segment (e.g. "/a:b"), not a scheme — treat as relative.
        for ch in trimmed[trimmed.startIndex..<colon] where ch == "/" || ch == "?" || ch == "#" {
            return url
        }
        let scheme = trimmed[trimmed.startIndex..<colon].lowercased()
        let allowed: Set<String> = ["http", "https", "mailto", "tel", "ftp"]
        return allowed.contains(scheme) ? url : "#"
    }
}

private extension String {
    /// Trim leading/trailing ASCII whitespace and control characters (incl. the
    /// NUL/tab/newline tricks used to smuggle `java\tscript:` past a naive
    /// scheme check) without pulling in Foundation.
    func trimmingASCIIWhitespaceAndControls() -> String {
        // Drop control chars (< 0x20) entirely, then trim spaces at the ends.
        var kept = String.UnicodeScalarView()
        for s in unicodeScalars where s.value >= 0x20 { kept.append(s) }
        var result = String(kept)
        while let f = result.first, f == " " { result.removeFirst() }
        while let l = result.last, l == " " { result.removeLast() }
        return result
    }
}
