public struct ResolveContext {
    let store: StateStore
    let listeners: ListenerRegistry
    let invalidate: (NodeIdentity) -> Void
    var reachable: Set<NodeIdentity> = []
    var liveListeners: Set<ListenerID> = []
    init(store: StateStore, listeners: ListenerRegistry, invalidate: @escaping (NodeIdentity) -> Void) {
        self.store = store; self.listeners = listeners; self.invalidate = invalidate
    }
}

@MainActor
func resolve<T: Tag>(_ tag: T, path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
    if let primitive = tag as? any _PrimitiveTag {
        return primitive._resolve(path: path, ctx: &ctx)
    }
    fatalError("component resolution implemented in Task 6")
}
