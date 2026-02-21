// Router.swift - URL-based routing

import SwiftWUICore
import Observation

/// Manages URL-based routing and navigation between pages.
/// Observable so that route changes trigger re-rendering.
///
/// ```swift
/// let router = Router {
///     Route("/") { HomePage() }
///     Route("/about") { AboutPage() }
/// }
/// router.navigate(to: "/about")
/// ```
/// - Note: `@unchecked Sendable` because WASM is single-threaded.
/// All DOM operations and state mutations happen synchronously.
@Observable
public final class Router: @unchecked Sendable {
    /// The current URL path.
    public var currentPath: String

    /// All registered routes.
    public private(set) var routes: [Route]

    /// Extracted parameters from the current matched route.
    public private(set) var currentParams: [String: String] = [:]

    public init(initialPath: String = "/", @RouteBuilder routes: () -> [Route]) {
        self.currentPath = initialPath
        self.routes = routes()
    }

    public init(initialPath: String = "/", routes: [Route]) {
        self.currentPath = initialPath
        self.routes = routes
    }

    // MARK: - Navigation

    /// Navigate to a new path.
    public func navigate(to path: String) {
        currentPath = path
        currentParams = matchedParams(for: path)
    }

    /// Go back in history (will be connected to History API in runtime).
    public func goBack() {
        // Will be implemented with History API integration in SwiftWUIRuntime
    }

    // MARK: - Route Matching

    /// Find the matching route for a given path.
    public func matchedRoute(for path: String) -> Route? {
        routes.first { $0.match(path) != nil }
    }

    /// Get the matched tag for a given path.
    public func matchedTag(for path: String) -> AnyTag? {
        guard let route = matchedRoute(for: path) else { return nil }
        let params = route.match(path) ?? [:]
        return route.builder(params)
    }

    /// Get the matched parameters for a given path.
    public func matchedParams(for path: String) -> [String: String] {
        guard let route = matchedRoute(for: path) else { return [:] }
        return route.match(path) ?? [:]
    }
}
