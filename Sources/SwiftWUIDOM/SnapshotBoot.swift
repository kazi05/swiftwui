import SwiftWUI
#if arch(wasm32)
import JavaScriptKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Reads the SSG snapshot (spec §7): seeds pending rows + the skip set, and
/// installs the JSONDecoder-backed slot decoder (single-element-array
/// convention from Task 7).
@MainActor
enum SnapshotBoot {
    struct Payload: Decodable {
        let v: Int
        let path: String
        let rows: [String: [RawSlot]]
        let tasks: [String]
    }
    /// Captures each slot's raw JSON text so the typed decode can happen later
    /// at link() time when Value is known. `SnapshotJSON.assemble` embeds each
    /// already-wrapped "[value]" fragment as ONE element of the row's array —
    /// this decoder's value IS that fragment, so re-serializing it verbatim
    /// (no extra bracket) reproduces the exact fragment text.
    struct RawSlot: Decodable {
        let raw: String
        init(from decoder: Decoder) throws {
            let v = try JSONValue(from: decoder)
            raw = v.serialized
        }
    }
    /// Minimal JSON value tree for slot re-serialization.
    indirect enum JSONValue: Decodable {
        case null, bool(Bool), int(Int64), number(Double), string(String)
        case array([JSONValue]), object([String: JSONValue])

        private struct DynamicKey: CodingKey {
            let stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { return nil }
        }

        init(from decoder: Decoder) throws {
            let single = try decoder.singleValueContainer()
            if single.decodeNil() { self = .null; return }
            if let b = try? single.decode(Bool.self) { self = .bool(b); return }
            // Int64 before Double: Double loses precision above 2^53, so a
            // large integer (e.g. Int64.max) would silently corrupt (M1).
            if let i = try? single.decode(Int64.self) { self = .int(i); return }
            if let n = try? single.decode(Double.self) { self = .number(n); return }
            if let s = try? single.decode(String.self) { self = .string(s); return }
            if var unkeyed = try? decoder.unkeyedContainer() {
                var items: [JSONValue] = []
                while !unkeyed.isAtEnd { items.append(try unkeyed.decode(JSONValue.self)) }
                self = .array(items); return
            }
            if let keyed = try? decoder.container(keyedBy: DynamicKey.self) {
                var out: [String: JSONValue] = [:]
                for key in keyed.allKeys { out[key.stringValue] = try keyed.decode(JSONValue.self, forKey: key) }
                self = .object(out); return
            }
            throw DecodingError.dataCorruptedError(in: single, debugDescription: "SnapshotBoot: unsupported JSON value")
        }

        /// Canonical re-serialization, reusing the same escaping rules as
        /// `SwiftWUIStatic.SnapshotJSON.jsonString` (breakout defense: "/" → "\/").
        var serialized: String {
            switch self {
            case .null: return "null"
            case .bool(let b): return b ? "true" : "false"
            case .int(let i): return String(i)
            case .number(let n):
                // Integral values print without a trailing ".0".
                if n == n.rounded(), abs(n) < 1e15 { return String(Int64(n)) }
                return String(n)
            case .string(let s): return SnapshotBoot.jsonString(s)
            case .array(let items):
                return "[" + items.map(\.serialized).joined(separator: ",") + "]"
            case .object(let dict):
                let body = dict.keys.sorted().map { key in
                    SnapshotBoot.jsonString(key) + ":" + dict[key]!.serialized
                }.joined(separator: ",")
                return "{" + body + "}"
            }
        }
    }

    /// JSON string literal with "/" escaped — same breakout defense as
    /// `SnapshotJSON.jsonString` (copied in: SwiftWUIDOM doesn't depend on SwiftWUIStatic).
    /// `nonisolated`: called from `JSONValue.serialized`, a nested type that
    /// does NOT inherit SnapshotBoot's @MainActor (only direct members do).
    nonisolated private static func jsonString(_ s: String) -> String {
        var out = "\""
        for ch in s.unicodeScalars {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "/":  out += "\\/"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case let c where c.value < 0x20:
                let hex = String(c.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default:   out.unicodeScalars.append(ch)
            }
        }
        return out + "\""
    }

    static let decodeSlot: SnapshotDecode = { json, type in
        func open<T: Decodable>(_ t: T.Type) -> (any Decodable)? {
            (try? JSONDecoder().decode([T].self, from: Data(json.utf8)))?.first
        }
        return _openExistential(type, do: open)
    }

    /// nil when the page has no snapshot / version mismatch / current location
    /// differs from the snapshot's path (spec §7 — cold boot in those cases).
    static func read(currentPath: String) -> Payload? {
        let document = JSObject.global.document
        let el = document.querySelector("script[type=\"application/swiftwui-state\"]")
        guard let obj = el.object, let text = obj.textContent.string,
              let payload = try? JSONDecoder().decode(Payload.self, from: Data(text.utf8)),
              payload.v == 1,
              // Static servers serve "/about/" with a trailing slash; the
              // snapshot stores the normalized form — compare normalized.
              RouteURL._normalize(payload.path) == RouteURL._normalize(currentPath)
        else { return nil }
        return payload
    }
    static func removeScriptTag() {
        let el = JSObject.global.document.querySelector("script[type=\"application/swiftwui-state\"]")
        _ = el.object?.remove?()
    }
}
#endif
