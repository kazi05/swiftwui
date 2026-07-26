/// Prerender policy for a route (spec 2026-07-26 §4). A value, attached with
/// `Route.prerender(_:)`, defaulted by `App.prerender`, overridable by
/// `StaticSiteConfig.defaultPrerender`, and overridden entirely by the
/// kill-switch.
///
/// ```swift
/// Route("/routes/:from/:to") { … }
///     .prerender(.paths { try await api.topRoutes() }
///                  .allowingOnDemand()
///                  .revalidate(.hours(6)))
/// ```
public struct Prerender: Sendable {
    public typealias PathProvider = @Sendable () async throws -> [String]

    /// Build-time path enumeration; nil = "no explicit list".
    let pathProvider: PathProvider?
    /// May this route produce pages during `StaticSite.generate`?
    let buildEnabled: Bool
    /// May a server render this route on first request? (Phase B reads it.)
    let onDemandEnabled: Bool
    /// Cache lifetime before a rendered page is considered stale; nil = never.
    let revalidateInterval: Duration?

    init(pathProvider: PathProvider?, buildEnabled: Bool,
         onDemandEnabled: Bool, revalidateInterval: Duration?) {
        self.pathProvider = pathProvider
        self.buildEnabled = buildEnabled
        self.onDemandEnabled = onDemandEnabled
        self.revalidateInterval = revalidateInterval
    }

    // SPI for SwiftWUIStatic's generate() — not app-facing, mirrors the
    // `RouteURL._normalize` underscore convention for cross-module framework use.
    public var _pathProvider: PathProvider? { pathProvider }
    public var _buildEnabled: Bool { buildEnabled }
    public var _onDemandEnabled: Bool { onDemandEnabled }
    public var _revalidateInterval: Duration? { revalidateInterval }

    /// Never prerendered — the route is client-only (private dashboards).
    public static let never = Prerender(pathProvider: nil, buildEnabled: false,
                                        onDemandEnabled: false, revalidateInterval: nil)
    /// Rendered at build time. For a dynamic pattern with no `paths` provider
    /// this yields nothing on its own — pair it with `.paths { … }`.
    public static let build = Prerender(pathProvider: nil, buildEnabled: true,
                                        onDemandEnabled: false, revalidateInterval: nil)
    /// Not built; rendered by the server on first request (Phase B).
    public static let onDemand = Prerender(pathProvider: nil, buildEnabled: false,
                                           onDemandEnabled: true, revalidateInterval: nil)

    /// Build-time paths, resolved once per `generate()` run. Paths the route
    /// pattern does not match are reported as configuration errors.
    public static func paths(_ provider: @escaping PathProvider) -> Prerender {
        Prerender(pathProvider: provider, buildEnabled: true,
                  onDemandEnabled: false, revalidateInterval: nil)
    }

    /// Also render paths that were not built, on first request.
    /// Named `allowingOnDemand`, not `onDemand`: a static property and an
    /// instance method sharing one identifier compile when chained but fail in
    /// leading-dot position.
    public func allowingOnDemand(_ enabled: Bool = true) -> Prerender {
        Prerender(pathProvider: pathProvider, buildEnabled: buildEnabled,
                  onDemandEnabled: enabled, revalidateInterval: revalidateInterval)
    }

    /// Cache lifetime before a rendered page is stale (Phase B).
    public func revalidate(_ d: Duration) -> Prerender {
        Prerender(pathProvider: pathProvider, buildEnabled: buildEnabled,
                  onDemandEnabled: onDemandEnabled, revalidateInterval: d)
    }
}

extension Duration {
    public static func minutes(_ n: Int) -> Duration { .seconds(n * 60) }
    public static func hours(_ n: Int) -> Duration { .seconds(n * 3600) }
}

/// One route as seen by SSG enumeration (spec §4.4): its pattern plus the
/// policy declared on it, if any. SPI — not part of the app-facing API.
public struct _CollectedRoute {
    public let pattern: RoutePattern
    public let prerender: Prerender?
    public init(pattern: RoutePattern, prerender: Prerender?) {
        self.pattern = pattern
        self.prerender = prerender
    }
}
