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

// MARK: - Tree-scoped environment

extension EnvironmentValues {
    /// Tree-scoped current environment, resolved via Swift's TaskLocal so
    /// each subtree's `.environment(_:_:)` override is visible only while
    /// that subtree's `toTagNodes()` is running. The render pipeline is
    /// synchronous, but `TaskLocal.withValue` works the same for both
    /// sync and async callers and gives us correct push/pop semantics
    /// without any explicit RenderContext plumbing.
    @TaskLocal public static var current: EnvironmentValues = EnvironmentValues()
}

/// Back-compat shim. Older code wrote to a global to seed the environment;
/// reading still resolves through the task-local view. Mutating the global
/// has no effect on rendering — use `.environment(_:_:)` instead.
@available(*, deprecated, message: "Use `.environment(_:_:)` for subtree overrides; this global is read-only.")
public enum CurrentEnvironment {
    public static var values: EnvironmentValues {
        EnvironmentValues.current
    }
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
///
/// `wrappedValue` reads from the task-local current environment, so
/// values flow through the tree via `.environment(_:_:)` modifiers
/// applied to ancestor tags.
@propertyWrapper
public struct Environment<Value> {
    private let keyPath: KeyPath<EnvironmentValues, Value>

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        EnvironmentValues.current[keyPath: keyPath]
    }
}
