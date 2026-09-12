import Observation

/// A transparent render-tree scope for committed scroll geometry and commands.
public struct ScrollReader<Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never

    let container: ScrollContainer
    let content: @MainActor (ScrollProxy) -> Content

    public init(container: ScrollContainer,
                @TagBuilder content: @escaping @MainActor (ScrollProxy) -> Content) {
        self.container = container
        self.content = content
    }

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.reachable.insert(id)
        ctx.store.retain(AnyTag(self), at: id, environment: ctx.environment,
                         scopeClass: ctx.scopeClass, visibilityRoots: ctx.visibilityRoots)
        let inv = ctx.invalidate
        if ctx.collectedRoutes == nil {
            ctx.store.link(self, at: id, environment: ctx.environment,
                           invalidate: { inv(id) })
        }

        let proxy = ctx.scrollRegistry?._proxy(for: id) ?? .inert()
        if ctx.scrollRegistry != nil { ctx.scrollReaders[id] = container }
        let observationToken = ctx.store.beginObservation(at: id)
        let box = _InvalidateBox(token: observationToken, fire: { inv(id) })
        let savedOwner = ctx.owner
        let savedObservationToken = ctx.ownerObservationToken
        let savedTransaction = ctx.transaction
        ctx.owner = id
        ctx.ownerObservationToken = observationToken
        if let transaction = ctx.transactionOverrides[id] { ctx.transaction = transaction }
        defer {
            ctx.owner = savedOwner
            ctx.ownerObservationToken = savedObservationToken
            ctx.transaction = savedTransaction
        }

        let body = withObservationTracking {
            content(proxy)
        } onChange: {
            MainActor.assumeIsolated { box.fireIfCurrent() }
        }
        let children = resolve(body, path: id.appending(.child(0)), ctx: &ctx)
        return [.component(ComponentNode(identity: id,
                                         typeName: String(describing: Self.self),
                                         key: nil,
                                         children: children))]
    }
}
