/// Read-only typed access to the matched route's captures (spec §6):
/// `@RouteParam("from") var from: String?`. nil when the capture is absent OR
/// fails to parse. Mirrors `@QueryParam` and rides the same injection seam.
@propertyWrapper
public struct RouteParam<Value: LosslessStringConvertible>: _EnvironmentProperty {
    final class Slot { var snapshot: EnvironmentValues? }
    private let name: String
    private let slot = Slot()
    public init(_ name: String) { self.name = name }
    public var wrappedValue: Value? {
        guard let raw = (slot.snapshot ?? EnvironmentValues()).routeInfo.params[name]
        else { return nil }
        return Value(raw)
    }
    public func _inject(_ values: EnvironmentValues) { slot.snapshot = values }
}
