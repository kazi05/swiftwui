import Foundation
import SwiftWUI

/// Snapshot payload assembly (spec §7, D7). Slot fragments follow the Task-7
/// convention: single-element JSON arrays. JSONEncoder escapes "/" as "\/"
/// by default — that is our </script> breakout defense; jsonString() below
/// does the same for hand-assembled keys. Deterministic: keys sorted.
enum SnapshotJSON {
    /// Encodes one @State value as "[<value>]".
    static let encodeSlot: SnapshotEncode = { value in
        struct Box: Encodable {
            let base: any Encodable
            func encode(to encoder: Encoder) throws {
                var c = encoder.unkeyedContainer()
                try c.encode(AnyEnc(base: base))
            }
        }
        struct AnyEnc: Encodable {
            let base: any Encodable
            func encode(to encoder: Encoder) throws { try base.encode(to: encoder) }
        }
        guard let data = try? JSONEncoder().encode(Box(base: value)) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// JSON string literal with "/" escaped (breakout defense for keys/paths).
    static func jsonString(_ s: String) -> String {
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
                out += String(format: "\\u%04x", c.value)
            default:   out.unicodeScalars.append(ch)
            }
        }
        return out + "\""
    }

    /// Hand-assembled because row values are pre-encoded fragments — running
    /// them through JSONEncoder again would double-encode.
    static func assemble(version: Int, path: String,
                         rows: [String: [String]], tasks: [String]) -> String {
        var out = "{\"v\":\(version),\"path\":\(jsonString(path)),\"rows\":{"
        out += rows.keys.sorted().map { key in
            jsonString(key) + ":[" + rows[key]!.map { $0 }.joined(separator: ",") + "]"
        }.joined(separator: ",")
        out += "},\"tasks\":["
        out += tasks.sorted().map(jsonString).joined(separator: ",")
        out += "]}"
        return out
    }
}
