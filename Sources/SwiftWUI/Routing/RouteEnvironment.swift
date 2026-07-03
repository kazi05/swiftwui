/// Current location, provided by the runtime (spec §7). `params` holds the
/// matched route's captures — written by Router for its subtree; readers
/// outside any Router see [:].
public struct RouteInfo: Equatable {
    public var path: String
    public var query: [String: String]
    public var params: [String: String]
    public init(path: String = "/", query: [String: String] = [:],
                params: [String: String] = [:]) {
        self.path = path; self.query = query; self.params = params
    }
}

/// `navigate("/x")` / `navigate("/x", replace: true)` (spec §7).
public struct NavigateAction {
    let handler: (String, Bool) -> Void
    public init(handler: @escaping (String, Bool) -> Void) { self.handler = handler }
    public func callAsFunction(_ path: String, replace: Bool = false) {
        handler(path, replace)
    }
}

private struct RouteInfoKey: EnvironmentKey {
    static let defaultValue = RouteInfo()
}
private struct NavigateKey: EnvironmentKey {
    static let defaultValue = NavigateAction { _, _ in }
}
private struct BackKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Current path/query/params. Default is "/" with empty dictionaries
    /// (HTMLRenderer, tests without a runtime).
    public var routeInfo: RouteInfo {
        get { self[RouteInfoKey.self] }
        set { self[RouteInfoKey.self] = newValue }
    }
    /// SPA navigation action; no-op default outside a runtime.
    public var navigate: NavigateAction {
        get { self[NavigateKey.self] }
        set { self[NavigateKey.self] = newValue }
    }
    /// history.back(); no-op default outside a runtime.
    public var back: () -> Void {
        get { self[BackKey.self] }
        set { self[BackKey.self] = newValue }
    }
}
