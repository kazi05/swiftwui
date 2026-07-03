public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

/// Resolver-facing seam, injected by StateStore.link's Mirror pass BEFORE body
/// evaluation (spec §4, decision D5). Machinery, not user API.
public protocol _EnvironmentProperty {
    func _inject(_ values: EnvironmentValues)
}

@propertyWrapper
public struct Environment<Value>: _EnvironmentProperty {
    final class Slot { var snapshot: EnvironmentValues? }
    private let keyPath: KeyPath<EnvironmentValues, Value>
    private let slot = Slot()
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) { self.keyPath = keyPath }
    public var wrappedValue: Value {
        (slot.snapshot ?? EnvironmentValues())[keyPath: keyPath]   // defaults when unset
    }
    public func _inject(_ values: EnvironmentValues) { slot.snapshot = values }
}

/// `.environment()` wrapper: one identity segment, save/write/restore around
/// content resolution (spec §4, decision D3).
struct _EnvironmentWriter<V, Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let keyPath: WritableKeyPath<EnvironmentValues, V>
    let value: V
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let saved = ctx.environment
        ctx.environment[keyPath: keyPath] = value
        let nodes = resolve(content, path: path.appending(.type(ObjectIdentifier(Self.self))), ctx: &ctx)
        ctx.environment = saved
        return nodes
    }
}

extension Tag {
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>,
                               _ value: V) -> some Tag {
        _EnvironmentWriter(keyPath: keyPath, value: value, content: self)
    }
}

private struct SetThemeKey: EnvironmentKey {
    static let defaultValue: (String?) -> Void = { _ in }
}
extension EnvironmentValues {
    /// Switches the active theme: `setTheme("dark")` / `setTheme(nil)` (default).
    /// Provided by the runtime; the default value is a no-op (HTMLRenderer, tests).
    public var setTheme: (String?) -> Void {
        get { self[SetThemeKey.self] }
        set { self[SetThemeKey.self] = newValue }
    }
}
