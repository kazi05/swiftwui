/// Pure decision layer between a resolved style change and a backend
/// `animate` call (anim spec §6.1): only CHANGED properties with a previous
/// value animate under `withAnimation` — property additions apply instantly.
enum AnimationPlanner {
    /// nil when the change should apply instantly (no previous value, or the
    /// value didn't actually change). Otherwise `.additive` when both values
    /// parse as matching number-lists ("10px", "0.5", "10px 20px", "45deg"),
    /// componentwise delta = old − new; everything else (colors, keywords,
    /// mismatched shapes) → `.replace(from: old, to: new)`.
    static func request(property: String, from old: String?, to new: String,
                         timing: ResolvedTiming) -> AnimationRequest? {
        guard let old, old != new else { return nil }
        if let (from, to) = additiveDelta(from: old, to: new) {
            return AnimationRequest(property: property, from: from, to: to, mode: .additive, timing: timing)
        }
        return AnimationRequest(property: property, from: old, to: new, mode: .replace, timing: timing)
    }

    /// A parsed number token: leading `[+-]?digits(.digits)?`, the rest is
    /// the unit suffix (may be empty, e.g. unitless opacity).
    private struct Token {
        let number: Double
        let unit: String
    }

    private static func additiveDelta(from old: String, to new: String) -> (from: String, to: String)? {
        guard let oldTokens = tokenize(old), let newTokens = tokenize(new),
              oldTokens.parts.count == newTokens.parts.count,
              oldTokens.separators == newTokens.separators else { return nil }
        var deltaParts: [String] = []
        var zeroParts: [String] = []
        for (o, n) in zip(oldTokens.parts, newTokens.parts) {
            guard o.unit == n.unit else { return nil }
            deltaParts.append(cssNumber4(o.number - n.number) + o.unit)
            zeroParts.append(cssNumber4(0) + o.unit)
        }
        return (rebuild(deltaParts, separators: oldTokens.separators),
                rebuild(zeroParts, separators: oldTokens.separators))
    }

    /// Splits on runs of spaces/commas, recording each run verbatim so the
    /// delta/zero strings can be rebuilt with identical separators.
    private static func tokenize(_ s: String) -> (parts: [Token], separators: [String])? {
        var parts: [Token] = []
        var separators: [String] = []
        var current = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == " " || chars[i] == "," {
                guard !current.isEmpty, let token = parseToken(current) else { return nil }
                parts.append(token)
                current = ""
                var separator = ""
                while i < chars.count, chars[i] == " " || chars[i] == "," {
                    separator.append(chars[i])
                    i += 1
                }
                separators.append(separator)
                continue
            }
            current.append(chars[i])
            i += 1
        }
        guard !current.isEmpty, let token = parseToken(current) else { return nil }
        parts.append(token)
        return (parts, separators)
    }

    private static func parseToken(_ token: String) -> Token? {
        var idx = token.startIndex
        if idx < token.endIndex, token[idx] == "+" || token[idx] == "-" {
            idx = token.index(after: idx)
        }
        while idx < token.endIndex, token[idx].isNumber {
            idx = token.index(after: idx)
        }
        if idx < token.endIndex, token[idx] == "." {
            idx = token.index(after: idx)
            while idx < token.endIndex, token[idx].isNumber {
                idx = token.index(after: idx)
            }
        }
        guard let number = Double(token[token.startIndex..<idx]) else { return nil }
        return Token(number: number, unit: String(token[idx...]))
    }

    private static func rebuild(_ parts: [String], separators: [String]) -> String {
        var result = parts[0]
        for i in 1..<parts.count {
            result += separators[i - 1] + parts[i]
        }
        return result
    }
}
