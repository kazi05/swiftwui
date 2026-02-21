// Route.swift - Route definition

import SwiftWUICore

/// Defines a route mapping a URL path pattern to a page/tag.
///
/// ```swift
/// Route("/") { HomePage() }
/// Route("/users/:id") { params in UserPage(id: params["id"]!) }
/// ```
public struct Route: Sendable {
    /// The URL path pattern. Supports `:param` placeholders.
    /// Examples: "/", "/about", "/users/:id", "/posts/:id/comments"
    public let path: String

    /// The tag builder for this route.
    public let builder: @Sendable ([String: String]) -> AnyTag

    /// Route with no parameters.
    public init(_ path: String, @TagBuilder content: @Sendable @escaping () -> some Tag) {
        self.path = path
        self.builder = { _ in AnyTag(content()) }
    }

    /// Route with URL parameters.
    public init(_ path: String, content: @Sendable @escaping ([String: String]) -> AnyTag) {
        self.path = path
        self.builder = content
    }
}

// MARK: - Route Matching

extension Route {
    /// Attempts to match a URL path against this route's pattern.
    /// Returns extracted parameters on success, nil on failure.
    public func match(_ urlPath: String) -> [String: String]? {
        let patternParts = path.split(separator: "/", omittingEmptySubsequences: true)
        let urlParts = urlPath.split(separator: "/", omittingEmptySubsequences: true)

        guard patternParts.count == urlParts.count else { return nil }

        var params: [String: String] = [:]

        for (pattern, url) in zip(patternParts, urlParts) {
            if pattern.hasPrefix(":") {
                let paramName = String(pattern.dropFirst())
                params[paramName] = String(url)
            } else if pattern != url {
                return nil
            }
        }

        return params
    }
}

// MARK: - RouteBuilder

/// Result builder for declaring routes.
@resultBuilder
public struct RouteBuilder {
    public static func buildBlock(_ routes: Route...) -> [Route] {
        routes
    }

    public static func buildBlock(_ routes: [Route]) -> [Route] {
        routes
    }

    public static func buildExpression(_ route: Route) -> Route {
        route
    }
}
