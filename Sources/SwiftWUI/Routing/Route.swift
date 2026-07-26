/// Outcome of a route guard (spec §5): `.allow` lets the route win the match;
/// `.redirect(path)` skips it and schedules a post-pass `navigate(replace: true)`.
public enum RouteGuardResult {
    case allow
    case redirect(String)
}

/// One URL pattern → content mapping (spec §4–5).
///
/// ```swift
/// Route("/") { HomePage() }
/// Route("/todo/:id") { params in TodoDetail(id: params["id"]!) }
/// Route("/admin", guard: { isAdmin ? .allow : .redirect("/login") }) { AdminPanel() }
/// ```
public struct Route {
    let pattern: RoutePattern
    let transition: PageTransition?
    let guardClosure: (() -> RouteGuardResult)?
    let builder: ([String: String]) -> AnyTag
    /// Prerender policy (spec 2026-07-26 §4.2); nil = "said nothing".
    let prerenderPolicy: Prerender?

    private init(pattern: RoutePattern, transition: PageTransition?,
                 guardClosure: (() -> RouteGuardResult)?,
                 builder: @escaping ([String: String]) -> AnyTag,
                 prerenderPolicy: Prerender?) {
        self.pattern = pattern
        self.transition = transition
        self.guardClosure = guardClosure
        self.builder = builder
        self.prerenderPolicy = prerenderPolicy
    }

    /// Route without parameters in the content closure.
    public init<C: Tag>(_ path: String, transition: PageTransition? = nil,
                        guard guardClosure: (() -> RouteGuardResult)? = nil,
                        @TagBuilder content: @escaping () -> C) {
        self.init(pattern: RoutePattern(path), transition: transition,
                  guardClosure: guardClosure, builder: { _ in AnyTag(content()) },
                  prerenderPolicy: nil)
    }

    /// Route receiving captured `:param` values (catch-all tail under "*").
    public init<C: Tag>(_ path: String, transition: PageTransition? = nil,
                        guard guardClosure: (() -> RouteGuardResult)? = nil,
                        @TagBuilder content: @escaping ([String: String]) -> C) {
        self.init(pattern: RoutePattern(path), transition: transition,
                  guardClosure: guardClosure, builder: { AnyTag(content($0)) },
                  prerenderPolicy: nil)
    }

    /// Declares how (and whether) this route is prerendered.
    public func prerender(_ policy: Prerender) -> Route {
        Route(pattern: pattern, transition: transition, guardClosure: guardClosure,
              builder: builder, prerenderPolicy: policy)
    }
}

// Mirrors RulesBuilder (Styles/Rule.swift:50): variadic buildBlock also covers
// the empty block — do NOT add a zero-arg overload (ambiguity).
@resultBuilder
public enum RouteBuilder {
    public static func buildBlock(_ parts: [Route]...) -> [Route] { parts.flatMap { $0 } }
    public static func buildExpression(_ r: Route) -> [Route] { [r] }
    public static func buildOptional(_ r: [Route]?) -> [Route] { r ?? [] }
    public static func buildEither(first: [Route]) -> [Route] { first }
    public static func buildEither(second: [Route]) -> [Route] { second }
    public static func buildArray(_ parts: [[Route]]) -> [Route] { parts.flatMap { $0 } }
}
