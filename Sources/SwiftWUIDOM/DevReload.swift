#if arch(wasm32)
import JavaScriptKit
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Dev-mode state-preserving reload (phase-6 spec §7). Every entry point is
/// gated on `window.__swiftwui_dev`, which only the dev server injects —
/// production pages never execute this path.
@MainActor enum DevReload {
    static let storageKey = "__swiftwui_dev_snapshot"

    static var isDevPage: Bool { JSObject.global.__swiftwui_dev.boolean == true }

    private struct AnyEnc: Encodable {
        let base: any Encodable
        func encode(to encoder: Encoder) throws { try base.encode(to: encoder) }
    }
    /// Wasm mirror of SwiftWUIStatic.SnapshotJSON.encodeSlot (single-element-array
    /// convention) — SwiftWUIDOM deliberately doesn't depend on SwiftWUIStatic.
    static let encodeSlot: SnapshotEncode = { value in
        guard let data = try? JSONEncoder().encode([AnyEnc(base: value)]) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// sessionStorage carries an opaque JS string: layer-1 JSON escaping only,
    /// no HTMLEscaping.scriptJSON (that layer exists solely for <script> embedding).
    static func assemble(path: String, rows: [String: [String]], tasks: [String]) -> String {
        var out = "{\"v\":1,\"path\":" + SnapshotBoot.jsonString(path) + ",\"rows\":{"
        var first = true
        for key in rows.keys.sorted() {
            if !first { out += "," }
            first = false
            out += SnapshotBoot.jsonString(key) + ":[" + rows[key]!.joined(separator: ",") + "]"
        }
        out += "},\"tasks\":["
        out += tasks.sorted().map(SnapshotBoot.jsonString).joined(separator: ",")
        out += "]}"
        return out
    }

    static func save(store: StateStore, skipTasks: [String]) {
        let rows = store._encodeSnapshotRows(encodeSlot)
        let path = JSObject.global.location.pathname.string ?? "/"
        let json = assemble(path: path, rows: rows, tasks: skipTasks)
        _ = JSObject.global.sessionStorage.object?.setItem?(storageKey, json)
    }

    /// Consume-once read; malformed/mismatched content degrades to nil (cold render).
    static func takeStoredPayload(currentPath: String) -> SnapshotBoot.Payload? {
        guard isDevPage,
              let stored = JSObject.global.sessionStorage.object?.getItem?(storageKey).string
        else { return nil }
        _ = JSObject.global.sessionStorage.object?.removeItem?(storageKey)
        guard let payload = SnapshotBoot.parse(stored, currentPath: currentPath) else {
            print("[SwiftWUI] dev snapshot unreadable or path-mismatched — cold render")
            return nil
        }
        return payload
    }
}
#endif
