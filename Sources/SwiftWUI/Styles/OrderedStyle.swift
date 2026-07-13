// OrderedStyle.swift — typed, order-preserving CSS property/value map.
//
// Backs the per-property style diffing added on top of ElementNode: unlike a
// flattened style string, entries keep first-occurrence position with
// last-wins values, so a diff can tell "this one property changed" instead of
// replacing the whole `style` attribute.

/// An ordered map of CSS declarations. Order is first-occurrence; `set`
/// updates an existing property's value in place rather than moving it.
public struct OrderedStyle: Equatable {
    public struct Entry: Equatable {
        public var property: String
        public var value: String
        public init(property: String, value: String) {
            self.property = property
            self.value = value
        }
    }

    public private(set) var entries: [Entry] = []

    public init() {}

    /// Tolerant CSS text parser: splits on `;` outside parentheses (so a
    /// `url(data:image/png;base64,...)` value survives), then splits each
    /// chunk on the first `:` into property/value, trimming both. Chunks with
    /// no `:` or an empty property are dropped.
    public init(parsing cssText: String) {
        var depth = 0
        var current = ""
        var chunks: [String] = []
        for ch in cssText {
            switch ch {
            case "(":
                depth += 1
                current.append(ch)
            case ")":
                depth = max(0, depth - 1)
                current.append(ch)
            case ";" where depth == 0:
                chunks.append(current)
                current = ""
            default:
                current.append(ch)
            }
        }
        chunks.append(current)

        for chunk in chunks {
            guard let colon = chunk.firstIndex(of: ":") else { continue }
            let prop = chunk[..<colon].trimmed()
            let value = chunk[chunk.index(after: colon)...].trimmed()
            guard !prop.isEmpty else { continue }
            set(prop, value)
        }
    }

    /// Last-wins: an existing property's value is updated in place (keeping
    /// its position); a new property is appended.
    public mutating func set(_ property: String, _ value: String) {
        if let i = entries.firstIndex(where: { $0.property == property }) {
            entries[i].value = value
        } else {
            entries.append(Entry(property: property, value: value))
        }
    }

    /// Applies `set` for each declaration, in order.
    public mutating func merge(_ declarations: [StyleDeclaration]) {
        for d in declarations { set(d.property, d.value) }
    }

    public subscript(property: String) -> String? {
        entries.first(where: { $0.property == property })?.value
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// "prop: value; prop2: value2" in entry order. Empty → "".
    public var cssText: String {
        entries.map { "\($0.property): \($0.value)" }.joined(separator: "; ")
    }
}

private extension StringProtocol {
    /// Trim leading/trailing whitespace without pulling in Foundation.
    func trimmed() -> String {
        var start = startIndex
        var end = endIndex
        while start < end, self[start].isWhitespace { start = index(after: start) }
        while start < end, self[index(before: end)].isWhitespace { end = index(before: end) }
        return String(self[start..<end])
    }
}
