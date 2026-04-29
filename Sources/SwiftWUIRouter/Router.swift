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
    /// The current URL path. The query string is stripped here and parsed
    /// into `currentSearchParams`; consumers reading `currentPath` see only
    /// the path portion (`/users/123`), never the trailing `?…`.
    public var currentPath: String

    /// All registered routes.
    public private(set) var routes: [Route]

    /// Extracted path parameters from the current matched route
    /// (e.g. `/users/:id` with `/users/42` → `["id": "42"]`).
    public private(set) var currentParams: [String: String] = [:]

    /// Parsed `?key=value&…` query string for the current URL. Updated by
    /// `navigate(to:)` and observable through Swift's Observation, so a
    /// `@QueryParam`-style reader re-fires when the user edits the URL.
    public private(set) var currentSearchParams: [String: String] = [:]

    public init(initialPath: String = "/", @RouteBuilder routes: () -> [Route]) {
        let (path, search) = Self.splitPathAndSearch(initialPath)
        self.currentPath = path
        self.currentSearchParams = search
        self.routes = routes()
    }

    public init(initialPath: String = "/", routes: [Route]) {
        let (path, search) = Self.splitPathAndSearch(initialPath)
        self.currentPath = path
        self.currentSearchParams = search
        self.routes = routes
    }

    // MARK: - Navigation

    /// Navigate to a new URL. The URL may contain a `?key=value&…` suffix;
    /// the path portion goes into `currentPath`, the query into
    /// `currentSearchParams`.
    public func navigate(to url: String) {
        let (path, search) = Self.splitPathAndSearch(url)
        currentPath = path
        currentSearchParams = search
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

    // MARK: - Query string parsing

    /// Split a URL into its path and query components. Anything after the
    /// first `?` is the query string; the search params are URL-decoded
    /// into a flat `[key: value]` map. Repeated keys keep the last value
    /// — apps that need multi-value params should reach for the raw
    /// `currentSearchParams` directly and parse manually.
    static func splitPathAndSearch(_ url: String) -> (path: String, search: [String: String]) {
        guard let qIndex = url.firstIndex(of: "?") else {
            return (url, [:])
        }
        let path = String(url[..<qIndex])
        let queryStart = url.index(after: qIndex)
        let queryString = String(url[queryStart...])
        var params: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let keyPart = parts.first else { continue }
            let key = percentDecode(String(keyPart))
            let value = parts.count > 1 ? percentDecode(String(parts[1])) : ""
            params[key] = value
        }
        return (path, params)
    }

    /// Minimal percent-decoder: handles `+ → space`, `%XX → byte`, leaves
    /// invalid escapes untouched. Avoids pulling Foundation's
    /// `removingPercentEncoding` so the router stays usable from
    /// Foundation-free builds (e.g. Embedded Swift in the long term).
    private static func percentDecode(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "+" {
                out.append(" ")
                i = s.index(after: i)
            } else if c == "%", let hi = s.index(i, offsetBy: 1, limitedBy: s.endIndex),
                      let lo = s.index(i, offsetBy: 2, limitedBy: s.endIndex),
                      hi < s.endIndex, lo < s.endIndex,
                      let byte = UInt8(s[hi...lo], radix: 16) {
                out.append(Character(Unicode.Scalar(byte)))
                i = s.index(after: lo)
            } else {
                out.append(c)
                i = s.index(after: i)
            }
        }
        return out
    }
}
