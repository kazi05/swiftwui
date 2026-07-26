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

/// `navigate("/x")` / `navigate("/x", replace: true)` /
/// `navigate("/x", transition: .zoom(sourceID: "card"))` (spec §7, §4).
///
/// The call-site `transition` and the ambient `\.pageTransition` travel in
/// SEPARATE channels on purpose: if the ambient value arrived as the explicit
/// argument, every `Link` click would look explicit and silently outrank the
/// destination `Route(transition:)`.
public struct NavigateAction {
    /// (path, replace, explicit transition, ambient transition)
    let handler: (String, Bool, PageTransition?, PageTransition?) -> Void
    let ambient: PageTransition?

    /// Kept for source compatibility: `withDependencies` overrides and
    /// `.environment(\.navigate, fake)` construct this form.
    public init(handler: @escaping (String, Bool) -> Void) {
        self.handler = { path, replace, _, _ in handler(path, replace) }
        self.ambient = nil
    }
    public init(ambient: PageTransition? = nil,
                handler: @escaping (String, Bool, PageTransition?, PageTransition?) -> Void) {
        self.handler = handler
        self.ambient = ambient
    }
    /// Rebinds the ambient value; the computed `\.navigate` key calls this per node.
    func withAmbient(_ t: PageTransition?) -> NavigateAction {
        NavigateAction(ambient: t, handler: handler)
    }
    public func callAsFunction(_ path: String, replace: Bool = false,
                              transition: PageTransition? = nil) {
        handler(path, replace, transition, ambient)
    }
}

private struct RouteInfoKey: EnvironmentKey {
    static let defaultValue = RouteInfo()
}
private struct NavigateBaseKey: EnvironmentKey {
    static let defaultValue = NavigateAction { _, _ in }
}
private struct BackKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
private struct PageTransitionKey: EnvironmentKey {
    static let defaultValue: PageTransition? = nil
}

extension EnvironmentValues {
    /// Current path/query/params. Default is "/" with empty dictionaries
    /// (HTMLRenderer, tests without a runtime).
    public var routeInfo: RouteInfo {
        get { self[RouteInfoKey.self] }
        set { self[RouteInfoKey.self] = newValue }
    }
    /// SPA navigation bound to the current ambient `\.pageTransition`; no-op
    /// default outside a runtime.
    public var navigate: NavigateAction {
        get { self[NavigateBaseKey.self].withAmbient(pageTransition) }
        set { self[NavigateBaseKey.self] = newValue }
    }
    /// history.back(); no-op default outside a runtime.
    public var back: () -> Void {
        get { self[BackKey.self] }
        set { self[BackKey.self] = newValue }
    }
    /// Ambient page transition for navigations made from this subtree.
    /// `.pageTransition(nil)` disables — "explicitly none" and "never set" are
    /// the same state, so there is no double optional anywhere.
    public var pageTransition: PageTransition? {
        get { self[PageTransitionKey.self] }
        set { self[PageTransitionKey.self] = newValue }
    }
}
