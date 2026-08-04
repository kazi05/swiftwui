import Observation
#if canImport(FoundationEssentials)
import FoundationEssentials
// SwiftWUI itself declares an HTML `Data<Content>` tag (Tags+Text.swift, the
// `<data>` element) — same-module type wins unqualified lookup over the
// imported Foundation type, so StorageConvertible conformance below must
// disambiguate explicitly.
public typealias _FoundationData = FoundationEssentials.Data
#else
import Foundation
public typealias _FoundationData = Foundation.Data
#endif

// MARK: - Kind & conversion

public enum StorageKind: Hashable, Sendable { case local, session }

/// Raw-string codec for web storage. Encode returning nil = remove the key
/// (Optional.none). SECURITY: web storage is plaintext, origin-scoped, and
/// readable by any script on the origin — never store secrets or tokens.
public protocol StorageConvertible {
    static func _decodeStorage(_ raw: String) -> Self?
    var _encodeStorage: String? { get }
}

extension String: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> String? { raw }
    public var _encodeStorage: String? { self }
}
extension Bool: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Bool? {
        raw == "true" ? true : raw == "false" ? false : nil
    }
    public var _encodeStorage: String? { self ? "true" : "false" }
}
extension Int: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Int? { Int(raw) }
    public var _encodeStorage: String? { String(self) }
}
extension Double: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Double? { Double(raw) }
    public var _encodeStorage: String? { String(self) }
}
extension URL: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> URL? { URL(string: raw) }
    public var _encodeStorage: String? { absoluteString }
}
extension _FoundationData: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> _FoundationData? { _FoundationData(base64Encoded: raw) }
    public var _encodeStorage: String? { base64EncodedString() }
}
extension Optional: StorageConvertible where Wrapped: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Wrapped?? {
        Wrapped._decodeStorage(raw).map { Optional($0) }   // inner decode failure → nil → wrapper default
    }
    public var _encodeStorage: String? { self?._encodeStorage }
}
/// RawRepresentable enums opt in with `extension MyEnum: StorageConvertible {}` —
/// Swift cannot conform them retroactively; these supply the implementations.
public extension StorageConvertible where Self: RawRepresentable, RawValue == String {
    static func _decodeStorage(_ raw: String) -> Self? { Self(rawValue: raw) }
    var _encodeStorage: String? { rawValue }
}
public extension StorageConvertible where Self: RawRepresentable, RawValue == Int {
    static func _decodeStorage(_ raw: String) -> Self? { Int(raw).flatMap(Self.init(rawValue:)) }
    var _encodeStorage: String? { String(rawValue) }
}

// MARK: - Store

/// ONE shared @Observable box per (kind, key) — every wrapper for the same key
/// shares it, so a write through any instance re-renders every reader (v1's
/// per-instance-cache divergence is impossible by construction). Raw string is
/// the source of truth; each wrapper decodes at read with its own type.
@MainActor
public final class StorageStore {
    nonisolated deinit { }
    @Observable
    public final class Box {
        nonisolated deinit { }
        public internal(set) var raw: String?
        init(_ raw: String?) { self.raw = raw }
    }
    private struct SlotKey: Hashable { let kind: StorageKind; let key: String }
    private var boxes: [SlotKey: Box] = [:]
    private var warnedKeys: Set<String> = []
    /// Wired by Runtime.mount() to the backend BEFORE the first render pass.
    var readBacking: (StorageKind, String) -> String? = { _, _ in nil }
    var writeBacking: (StorageKind, String, String?) -> Void = { _, _, _ in }
    public init() {}

    func box(kind: StorageKind, key: String) -> Box {
        let sk = SlotKey(kind: kind, key: key)
        if let b = boxes[sk] { return b }
        let b = Box(readBacking(kind, key))         // lazy hydrate from the backing store
        boxes[sk] = b
        return b
    }
    func write(kind: StorageKind, key: String, raw: String?) {
        box(kind: kind, key: key).raw = raw         // Observation fires for readers
        writeBacking(kind, key, raw)
    }
    /// storage event (cross-tab) → update the box only; never echo a write back.
    public func externalChange(kind: StorageKind, key: String, raw: String?) {
        boxes[SlotKey(kind: kind, key: key)]?.raw = raw   // nobody linked it yet → nothing to update
    }
    func warnOnce(forKey key: String, _ message: @autoclosure () -> String) {
        guard warnedKeys.insert(key).inserted else { return }
        print("SwiftWUI storage: \(message())")
    }
}

struct _StorageStoreKey: EnvironmentKey {
    static let defaultValue: StorageStore? = nil
}
extension EnvironmentValues {
    var _storageStore: StorageStore? {
        get { self[_StorageStoreKey.self] }
        set { self[_StorageStoreKey.self] = newValue }
    }
}

// MARK: - Wrappers

@MainActor
final class _StorageSlot {
    nonisolated deinit { }
    var store: StorageStore?
    var box: StorageStore.Box?
}

@MainActor
private func _storageRead<Value: StorageConvertible>(
    _ slot: _StorageSlot, key: String, default defaultValue: Value) -> Value {
    guard let raw = slot.box?.raw else { return defaultValue }   // tracked @Observable read
    if let v = Value._decodeStorage(raw) { return v }
    slot.store?.warnOnce(forKey: key,
        "value for '\(key)' failed to decode as \(Value.self) — using the wrapper default")
    return defaultValue
}

/// localStorage-backed persistent value. SwiftUI-parity types; RawRepresentable
/// enums opt in via `extension MyEnum: StorageConvertible {}`. Requires a live
/// runtime (link injects the store); outside one, reads return the default and
/// writes are dropped. Never store secrets (see StorageConvertible doc).
@propertyWrapper
public struct AppStorage<Value: StorageConvertible>: _EnvironmentProperty {
    private let key: String
    private let defaultValue: Value
    private let slot = _StorageSlot()

    public init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        if key.hasPrefix("__swiftwui.") {
            print("SwiftWUI @AppStorage: key '\(key)' uses the reserved __swiftwui. prefix")
        }
    }
    public func _inject(_ values: EnvironmentValues) {
        guard let store = values._storageStore else { return }
        slot.store = store
        slot.box = store.box(kind: .local, key: key)
    }
    public var wrappedValue: Value {
        get { _storageRead(slot, key: key, default: defaultValue) }
        nonmutating set { slot.store?.write(kind: .local, key: key, raw: newValue._encodeStorage) }
    }
    public var projectedValue: Binding<Value> {
        let slot = self.slot; let key = self.key; let def = self.defaultValue
        return Binding(
            get: { _storageRead(slot, key: key, default: def) },
            set: { slot.store?.write(kind: .local, key: key, raw: $0._encodeStorage) })
    }
}

/// sessionStorage-backed per-tab value. Same semantics as @AppStorage minus
/// cross-tab events (sessionStorage has none by platform design).
@propertyWrapper
public struct SceneStorage<Value: StorageConvertible>: _EnvironmentProperty {
    private let key: String
    private let defaultValue: Value
    private let slot = _StorageSlot()

    public init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        if key.hasPrefix("__swiftwui.") {
            print("SwiftWUI @SceneStorage: key '\(key)' uses the reserved __swiftwui. prefix")
        }
    }
    public func _inject(_ values: EnvironmentValues) {
        guard let store = values._storageStore else { return }
        slot.store = store
        slot.box = store.box(kind: .session, key: key)
    }
    public var wrappedValue: Value {
        get { _storageRead(slot, key: key, default: defaultValue) }
        nonmutating set { slot.store?.write(kind: .session, key: key, raw: newValue._encodeStorage) }
    }
    public var projectedValue: Binding<Value> {
        let slot = self.slot; let key = self.key; let def = self.defaultValue
        return Binding(
            get: { _storageRead(slot, key: key, default: def) },
            set: { slot.store?.write(kind: .session, key: key, raw: $0._encodeStorage) })
    }
}
