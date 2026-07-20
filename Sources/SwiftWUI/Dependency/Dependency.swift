#if !arch(wasm32)
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
#endif

/// Declares an injectable dependency — the analog of `EnvironmentKey` for the
/// DI layer. `liveValue` is the production default; `testValue` (optional,
/// defaults to `liveValue`) is substituted automatically when the process is
/// a test run.
///
///     struct APIClientKey: DependencyKey {
///         static var liveValue: APIClient { APIClient(base: "https://api.example.com") }
///         static var testValue: APIClient { .mock }
///     }
///     extension DependencyValues {
///         var apiClient: APIClient {
///             get { self[APIClientKey.self] }
///             set { self[APIClientKey.self] = newValue }
///         }
///     }
public protocol DependencyKey {
    associatedtype Value
    /// Production default. Computed lazily on first resolution and cached for
    /// the lifetime of the process — reference types are singletons.
    static var liveValue: Value { get }
    /// Substituted for `liveValue` when the process is a test run
    /// (Swift Testing or XCTest detected). Defaults to `liveValue`.
    static var testValue: Value { get }
}

extension DependencyKey {
    public static var testValue: Value { liveValue }
}

/// Keyed collection of dependency overrides. Apps extend it with computed
/// properties, mirroring `EnvironmentValues`. Reads return the effective
/// value: an override stored in this instance, else the key's cached default.
public struct DependencyValues {
    var storage: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<K: DependencyKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? DependencyStore.defaultValue(key) }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

/// Implicitly MainActor-isolated (module default isolation) — single-threaded
/// on wasm, main actor on native.
enum DependencyStore {
    /// `prepareDependencies` mutations plus the active `withDependencies` scope.
    static var overrides = DependencyValues()
    /// Key defaults computed once per key (singleton semantics).
    static var cachedDefaults: [ObjectIdentifier: Any] = [:]

    /// True when the process is a test run. Swift Testing links its stable
    /// ABI entry point into the runner; XCTest sets an env var. Tests never
    /// run on wasm.
    static let isTesting: Bool = {
        #if arch(wasm32)
        return false
        #else
        if dlsym(dlopen(nil, RTLD_LAZY), "swt_abiv0_getEntryPoint") != nil { return true }
        return getenv("XCTestConfigurationFilePath") != nil
        #endif
    }()

    static func defaultValue<K: DependencyKey>(_ key: K.Type) -> K.Value {
        let id = ObjectIdentifier(key)
        if let cached = cachedDefaults[id] as? K.Value { return cached }
        let value = isTesting ? K.testValue : K.liveValue
        cachedDefaults[id] = value
        return value
    }

    /// Test-only: wipes overrides and cached defaults between framework tests.
    static func _reset() {
        overrides = DependencyValues()
        cachedDefaults = [:]
    }
}

/// Resolves a dependency anywhere — Tag components, plain models, closures.
/// Unlike `@Environment` it is not tied to the render tree.
///
/// Resolution order per access:
/// 1. overrides captured at wrapper init — a model built inside
///    `withDependencies` keeps its mocks, including in escaping/async work;
/// 2. current global overrides (`prepareDependencies` + active scope);
/// 3. the key's cached default (`testValue` under tests, else `liveValue`).
///
/// Not reactive: changing a dependency never re-renders components.
@propertyWrapper
public struct Dependency<Value> {
    private let keyPath: KeyPath<DependencyValues, Value>
    private let snapshot: DependencyValues

    public init(_ keyPath: KeyPath<DependencyValues, Value>) {
        self.keyPath = keyPath
        self.snapshot = DependencyStore.overrides
    }

    public var wrappedValue: Value {
        var merged = DependencyStore.overrides
        merged.storage.merge(snapshot.storage) { _, snapshot in snapshot }
        return merged[keyPath: keyPath]
    }
}

/// Runs `operation` with scoped dependency overrides, restoring the previous
/// overrides afterwards. Synchronous only: build models INSIDE the scope —
/// they capture the overrides at init and keep them beyond it.
///
///     let model = withDependencies {
///         $0.apiClient = .stub(returning: fixtures)
///     } operation: {
///         CartModel()
///     }
public func withDependencies<R>(
    _ mutate: (inout DependencyValues) throws -> Void,
    operation: () throws -> R
) rethrows -> R {
    let saved = DependencyStore.overrides
    var copy = saved
    try mutate(&copy)
    DependencyStore.overrides = copy
    defer { DependencyStore.overrides = saved }
    return try operation()
}

/// Permanently mutates the global overrides — app startup, staging
/// configuration, SSG prerender stubs.
public func prepareDependencies(_ mutate: (inout DependencyValues) throws -> Void) rethrows {
    var copy = DependencyStore.overrides
    try mutate(&copy)
    DependencyStore.overrides = copy
}
