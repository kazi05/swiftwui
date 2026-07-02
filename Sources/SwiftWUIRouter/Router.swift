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

    /// Find the matching route for a given path. Routes whose `guard`
    /// returns `.redirect(_:)` are NOT considered matches by this method
    /// — the redirect intent is captured separately via
    /// `pendingRedirect(for:)` so the caller can dispatch it. Apps that
    /// want the unfiltered "would have matched if guards passed" route
    /// can call `rawMatchedRoute(for:)`.
    public func matchedRoute(for path: String) -> Route? {
        for route in routes {
            guard route.match(path) != nil else { continue }
            if let g = route.guardClosure {
                if case .allow = g() { return route }
                continue
            }
            return route
        }
        return nil
    }

    /// Pre-guard match (the route's path pattern matched the URL,
    /// regardless of what the guard returned). Used internally by
    /// `pendingRedirect(for:)` to find which route's guard wants to
    /// redirect.
    public func rawMatchedRoute(for path: String) -> Route? {
        routes.first { $0.match(path) != nil }
    }

    /// If the route matching `path` has a guard that returned
    /// `.redirect(target)`, return `target`. Returns `nil` when no route
    /// matches, the matching route has no guard, or the guard allowed
    /// the match.
    public func pendingRedirect(for path: String) -> String? {
        guard let route = rawMatchedRoute(for: path),
              let g = route.guardClosure else { return nil }
        if case .redirect(let target) = g() { return target }
        return nil
    }

    /// Get the matched tag for a given path. Returns nil if the
    /// matching route's guard returned `.redirect` — callers should
    /// inspect `pendingRedirect(for:)` and dispatch the redirect.
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
    ///
    /// Decoded `%XX` escapes are accumulated as raw bytes and interpreted as
    /// UTF-8 at the end — a multi-byte character such as "Привет"
    /// ("%D0%9F%D1%80…") or "✓" ("%E2%9C%93") spans several escapes and must
    /// not be turned into one Latin-1 scalar per byte.
    private static func percentDecode(_ s: String) -> String {
        let src = Array(s.utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(src.count)

        func hexValue(_ b: UInt8) -> UInt8? {
            switch b {
            case 0x30...0x39: return b - 0x30            // 0-9
            case 0x41...0x46: return b - 0x41 + 10       // A-F
            case 0x61...0x66: return b - 0x61 + 10       // a-f
            default: return nil
            }
        }

        var i = 0
        while i < src.count {
            let c = src[i]
            if c == 0x2B {                                // '+'
                bytes.append(0x20)                       // space
                i += 1
            } else if c == 0x25, i + 2 < src.count,      // '%XX'
                      let hi = hexValue(src[i + 1]),
                      let lo = hexValue(src[i + 2]) {
                bytes.append(hi << 4 | lo)
                i += 3
            } else {
                bytes.append(c)
                i += 1
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
