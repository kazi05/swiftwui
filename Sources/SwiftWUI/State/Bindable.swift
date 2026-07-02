import Observation

/// Bindings into @Observable models (spec §3.2). No runtime integration: the
/// Binding writes into the model, Observation notifies readers.
@propertyWrapper @dynamicMemberLookup
public struct Bindable<Value: AnyObject & Observable> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public var projectedValue: Bindable<Value> { self }
    public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, T>) -> Binding<T> {
        let object = wrappedValue
        return Binding(get: { object[keyPath: keyPath] },
                       set: { object[keyPath: keyPath] = $0 })
    }
}
