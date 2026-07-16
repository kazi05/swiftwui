#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Transferable analog for HTML5 DnD (spec §1.2). The encoded body is
/// written into a DOM attribute at render time and travels via the OS drag
/// pasteboard — VISIBLE to the page and other apps. Never put secrets in a
/// drag payload. Inbound bodies on drop are untrusted foreign data.
public protocol DragPayload: Codable {
    /// DataTransfer content type; also the zone-acceptance token.
    static var dragContentType: String { get }
    /// Body written to `data-swui-drag` / `dataTransfer.setData`.
    func _encodeDragBody() -> String?
    /// Inverse; nil on malformed/foreign input (drop is silently ignored).
    static func _decodeDragBody(_ body: String) -> Self?
}

extension DragPayload {
    public static var dragContentType: String {
        "application/x-swiftwui.\(String(describing: Self.self).lowercased())"
    }
    public func _encodeDragBody() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]     // deterministic attributes
        guard let data = try? encoder.encode(self) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    public static func _decodeDragBody(_ body: String) -> Self? {
        try? JSONDecoder().decode(Self.self, from: _FoundationData(body.utf8))
    }
}

extension String: DragPayload {
    public static var dragContentType: String { "text/plain" }
    public func _encodeDragBody() -> String? { self }
    public static func _decodeDragBody(_ body: String) -> String? { body }
}

/// text/uri-list: CRLF-separated URIs, `#` lines are comments. We encode a
/// single URL and decode the first non-comment line.
extension URL: DragPayload {
    public static var dragContentType: String { "text/uri-list" }
    public func _encodeDragBody() -> String? { absoluteString }
    public static func _decodeDragBody(_ body: String) -> URL? {
        for line in body.split(whereSeparator: \.isNewline) {
            // ponytail: stdlib whitespace trim — trimmingCharacters(in:) is full
            // Foundation only (absent from FoundationEssentials), and pulling it
            // links ICU into every wasm app (~40 MB). isWhitespace is equivalent here.
            var s = line
            while let c = s.first, c.isWhitespace { s = s.dropFirst() }
            while let c = s.last, c.isWhitespace { s = s.dropLast() }
            if s.isEmpty || s.first == "#" { continue }
            return URL(string: String(s))
        }
        return nil
    }
}
