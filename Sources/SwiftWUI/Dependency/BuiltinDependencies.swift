/// Framework-shipped dependency keys, available in every SwiftWUI app.
///
/// Inside component `body` prefer the environment channel where one exists
/// (`@Environment(\.webSession)`); the dependency keys serve models, services,
/// and other code outside the render tree.

struct WebSessionDependencyKey: DependencyKey {
    /// `WebSession.shared` passthrough. In a DOM app the session is ALSO
    /// installed as a global override by `bootstrapDependencies()` — a read
    /// during the first render (before `WebSession.bootstrap`) may cache
    /// `.unsupported` as the default, and the override shadows that.
    static var liveValue: WebSession { .shared }
    /// Unmocked network access in tests throws `WebFetchError.unsupported`.
    static var testValue: WebSession { .unsupported }
}

extension DependencyValues {
    /// Process-wide fetch session (`WebSession.shared` passthrough). In tests
    /// it defaults to `.unsupported` — mock it via `withDependencies`.
    public var webSession: WebSession {
        get { self[WebSessionDependencyKey.self] }
        set { self[WebSessionDependencyKey.self] = newValue }
    }
}

// MARK: - Navigation

struct NavigateDependencyKey: DependencyKey {
    /// No-op outside a booted app (SSG, tests without an override) — the same
    /// default as `@Environment(\.navigate)`. The DOM entry point rebinds it
    /// to the live runtime via `bootstrapDependencies()`.
    static var liveValue: NavigateAction { NavigateAction { _, _ in } }
}

// MARK: - Web storage

/// Imperative localStorage/sessionStorage access for models and services —
/// the non-reactive counterpart of `@AppStorage`/`@SceneStorage`. Writes go
/// through the same `StorageStore`, so `@AppStorage` readers of the same key
/// re-render. Plaintext + origin-readable — never store secrets.
public struct WebStorage {
    let store: StorageStore
    public init(store: StorageStore) { self.store = store }

    /// Decoded value for `key`, or nil when absent or undecodable.
    public func get<Value: StorageConvertible>(
        _ key: String, as type: Value.Type = Value.self, kind: StorageKind = .local
    ) -> Value? {
        store.box(kind: kind, key: key).raw.flatMap(Value._decodeStorage)
    }
    public func set<Value: StorageConvertible>(
        _ key: String, _ value: Value, kind: StorageKind = .local
    ) {
        if key.hasPrefix("__swiftwui.") {
            store.warnOnce(forKey: key, "WebStorage: key '\(key)' uses the reserved __swiftwui. prefix")
        }
        store.write(kind: kind, key: key, raw: value._encodeStorage)
    }
    public func remove(_ key: String, kind: StorageKind = .local) {
        if key.hasPrefix("__swiftwui.") {
            store.warnOnce(forKey: key, "WebStorage: key '\(key)' uses the reserved __swiftwui. prefix")
        }
        store.write(kind: kind, key: key, raw: nil)
    }
}

struct WebStorageDependencyKey: DependencyKey {
    /// In-memory store outside a booted app (SSG prerender, tests) — reads and
    /// writes work, nothing persists. The DOM entry point rebinds to the
    /// runtime's backend-wired store via `bootstrapDependencies()`. In tests
    /// the default is re-created after every `DependencyStore._reset()`, so
    /// each test gets an isolated store.
    static var liveValue: WebStorage { WebStorage(store: StorageStore()) }
}

// MARK: - Logging

public enum LogLevel: String {
    case debug, info, warning, error
}

/// Minimal logging service. The default prints to stdout — the browser
/// console under wasm, the terminal natively. Override in tests to capture
/// output, or in apps to add filtering or a transport.
public struct Logger {
    public var handler: (LogLevel, String) -> Void
    public init(handler: @escaping (LogLevel, String) -> Void) { self.handler = handler }
    public func debug(_ message: String) { handler(.debug, message) }
    public func info(_ message: String) { handler(.info, message) }
    public func warning(_ message: String) { handler(.warning, message) }
    public func error(_ message: String) { handler(.error, message) }
}

struct LoggerDependencyKey: DependencyKey {
    static var liveValue: Logger {
        Logger { level, message in print("[\(level.rawValue)] \(message)") }
    }
}

extension DependencyValues {
    /// Programmatic SPA navigation from models and services. No-op until the
    /// DOM runtime boots; inside component `body` prefer
    /// `@Environment(\.navigate)`.
    public var navigate: NavigateAction {
        get { self[NavigateDependencyKey.self] }
        set { self[NavigateDependencyKey.self] = newValue }
    }
    /// Imperative web storage. In-memory until the DOM runtime boots; then
    /// backend-wired and shared with `@AppStorage` (writes re-render readers).
    public var webStorage: WebStorage {
        get { self[WebStorageDependencyKey.self] }
        set { self[WebStorageDependencyKey.self] = newValue }
    }
    /// App-level logger. Print-based default.
    public var logger: Logger {
        get { self[LoggerDependencyKey.self] }
        set { self[LoggerDependencyKey.self] = newValue }
    }
}

// MARK: - Runtime wiring

extension Runtime {
    /// Called by platform entry points (DOM boot) after construction — wires
    /// runtime-backed built-ins into the global DI defaults. Deliberately NOT
    /// part of `mount()`: bare Runtime construction/mount must never touch
    /// process globals, or parallel native tests that build their own runtimes
    /// would pollute the shared store (the `WebSession.shared` rule).
    public func bootstrapDependencies() {
        prepareDependencies { deps in
            deps.navigate = NavigateAction { [weak self] path, replace in
                self?.navigate(to: path, replace: replace)
            }
            deps.webStorage = WebStorage(store: _storage)
            if let session = _webSession { deps.webSession = session }
        }
    }
}
