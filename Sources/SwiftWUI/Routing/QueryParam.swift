/// Read-only typed query access (spec §10): `@QueryParam("page") var page: Int?`.
/// nil when the parameter is absent OR fails to parse. Writing the query is
/// `navigate`. Rides the same injection seam as @Environment.
@propertyWrapper
public struct QueryParam<Value: LosslessStringConvertible>: _EnvironmentProperty {
    final class Slot { var snapshot: EnvironmentValues? }
    private let name: String
    private let slot = Slot()
    public init(_ name: String) { self.name = name }
    public var wrappedValue: Value? {
        guard let raw = (slot.snapshot ?? EnvironmentValues()).routeInfo.query[name]
        else { return nil }
        return Value(raw)
    }
    public func _inject(_ values: EnvironmentValues) { slot.snapshot = values }
}
