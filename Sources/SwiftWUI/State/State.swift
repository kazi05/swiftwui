final class StateBox<Value> {
    var value: Value
    var invalidate: (() -> Void)?
    init(_ value: Value) { self.value = value }
}

/// Resolver-facing seam (spec §6). Machinery, not user API.
public protocol _StateProperty {
    var _box: AnyObject { get }
    func _adopt(_ box: AnyObject) -> Bool
    func _bindInvalidate(_ f: @escaping () -> Void)
    /// Builds a box seeded from a snapshot slot, or nil when Value isn't
    /// Decodable / the JSON doesn't decode. Never traps (spec §7).
    func _boxDecoding(json: String, decode: SnapshotDecode) -> AnyObject?
}

/// Seam for `StateStore._encodeSnapshotRows` (spec §7): lets the store encode
/// a type-erased `StateBox<Value>` without knowing `Value`.
protocol _SnapshotEncodableBox: AnyObject {
    func _encodeJSON(_ encode: SnapshotEncode) -> String?
}
extension StateBox: _SnapshotEncodableBox {
    func _encodeJSON(_ encode: SnapshotEncode) -> String? {
        guard let v = value as? any Encodable else { return nil }
        return encode(v)
    }
}

@propertyWrapper
public struct State<Value> {
    final class Slot { var box: StateBox<Value>; init(_ b: StateBox<Value>) { box = b } }
    private let slot: Slot

    public init(wrappedValue: Value) { slot = Slot(StateBox(wrappedValue)) }

    public var wrappedValue: Value {
        get { slot.box.value }
        nonmutating set {
            slot.box.value = newValue
            slot.box.invalidate?()       // didSet: value already written (spec §6)
        }
    }

    public var projectedValue: Binding<Value> {
        let slot = self.slot             // capture slot, not box: survives adoption
        return Binding(
            get: { slot.box.value },
            set: { slot.box.value = $0; slot.box.invalidate?() })
    }
}

extension State: _StateProperty {
    public var _box: AnyObject { slot.box }
    public func _adopt(_ box: AnyObject) -> Bool {
        guard let b = box as? StateBox<Value> else { return false }
        slot.box = b
        return true
    }
    public func _bindInvalidate(_ f: @escaping () -> Void) { slot.box.invalidate = f }
    public func _boxDecoding(json: String, decode: SnapshotDecode) -> AnyObject? {
        guard let decodableType = Value.self as? any Decodable.Type,
              let decoded = decode(json, decodableType),
              let value = decoded as? Value else { return nil }
        return StateBox(value)
    }
}

@propertyWrapper
public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        getter = get; setter = set
    }
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }
    public var projectedValue: Binding<Value> { self }
}
