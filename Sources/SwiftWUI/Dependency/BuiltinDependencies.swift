/// Framework-shipped dependency keys, available in every SwiftWUI app.
///
/// Inside component `body` prefer the environment channel where one exists
/// (`@Environment(\.webSession)`); the dependency keys serve models, services,
/// and other code outside the render tree.

struct WebSessionDependencyKey: DependencyKey {
    /// Resolved lazily on first access — by then the platform runtime
    /// (SwiftWUIDOM / SwiftWUIStatic) has configured `WebSession.shared`.
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
