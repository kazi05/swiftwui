/// URL router (spec §6). A PRIMITIVE tag — matched content resolves under
/// `.keyed(pattern)`, so a route change tears @State down while a param-only
/// change (/todo/1 → /todo/2) keeps identity and preserves it (spec D2).
///
/// First-match-wins in declaration order (spec D3). One Router per app (D9).
public struct Router: Tag, _PrimitiveTag {
    public typealias Body = Never
    let routes: [Route]
    let notFound: AnyTag?

    public init(@RouteBuilder routes: () -> [Route]) {
        self.routes = routes()
        self.notFound = nil
    }
    public init<NF: Tag>(@TagBuilder notFound: () -> NF,
                         @RouteBuilder routes: () -> [Route]) {
        self.routes = routes()
        self.notFound = AnyTag(notFound())
    }

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        ctx.routerCount += 1
        assert(ctx.routerCount == 1, "SwiftWUI supports one Router per app (spec D9)")
        let info = ctx.environment.routeInfo
        for route in routes {
            guard let params = route.pattern.match(info.path) else { continue }
            if let g = route.guardClosure, case .redirect(let target) = g() {
                if ctx.pendingRedirect == nil { ctx.pendingRedirect = target }  // first wins
                continue                                                        // skipped (spec §5)
            }
            let content = route.builder(params)
            if let page = content.base as? any Page {                           // top-level only (spec §9)
                ctx.pageHead = PageHead(title: page.title, meta: page.meta)
            }
            let saved = ctx.environment
            ctx.environment.routeInfo.params = params
            let nodes = resolve(content,
                                path: path.appending(.keyed(NodeKey(route.pattern.raw))),
                                ctx: &ctx)
            ctx.environment = saved
            return nodes
        }
        if let notFound {
            return resolve(notFound, path: path.appending(.keyed(NodeKey("#not-found"))), ctx: &ctx)
        }
        #if DEBUG
        print("SwiftWUI Router: no route matched '\(info.path)' and no notFound content")
        #endif
        return []
    }
}
