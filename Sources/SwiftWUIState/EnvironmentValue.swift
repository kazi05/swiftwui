// EnvironmentValue.swift - Environment values that flow down the tag tree

/// A key for accessing values in the environment.
///
/// Define custom environment keys by conforming to this protocol:
/// ```swift
/// struct ThemeKey: EnvironmentKey {
///     static var defaultValue: Theme { .light }
/// }
///
/// extension EnvironmentValues {
///     var theme: Theme {
///         get { self[ThemeKey.self] }
///         set { self[ThemeKey.self] = newValue }
///     }
/// }
/// ```
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

/// A collection of environment values propagated through the tag tree.
public struct EnvironmentValues: @unchecked Sendable {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

// MARK: - Global Environment

/// The current global environment values.
///
/// In a full runtime, each subtree can override values. This simplified
/// version uses a single global instance. The Runtime module will replace
/// this with proper tree-scoped injection.
public enum CurrentEnvironment {
    nonisolated(unsafe) public static var values = EnvironmentValues()
}

// MARK: - @Environment Property Wrapper

/// A property wrapper that reads a value from the environment.
///
/// ```swift
/// struct ThemedText: Tag {
///     @Environment(\.theme) var theme
///
///     var body: some Tag {
///         Text("Hello").foreground(theme.primaryColor)
///     }
/// }
/// ```
@propertyWrapper
public struct Environment<Value> {
    private let keyPath: KeyPath<EnvironmentValues, Value>

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        CurrentEnvironment.values[keyPath: keyPath]
    }
}
