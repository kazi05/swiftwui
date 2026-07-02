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
    // Custom component boundary (spec §7).
    let id = path.appending(.type(ObjectIdentifier(T.self)))
    ctx.reachable.insert(id)
    let inv = ctx.invalidate
    ctx.store.link(tag, at: id, invalidate: { inv(id) })          // graft BEFORE body
    let children = resolve(tag.body, path: id.appending(.child(0)), ctx: &ctx)
    return [.component(ComponentNode(identity: id,
                                     typeName: String(describing: T.self),
                                     key: nil,
                                     children: children))]
}

/// Adjacent text nodes merge so string-serialized output parses back
/// node-for-node identical to the DOM backend's tree (spec §4, decision 18).
func coalesceText(_ nodes: [Node]) -> [Node] {
    var out: [Node] = []
    for n in nodes {
        if case .text(let t) = n, case .text(let prev)? = out.last {
            out[out.count - 1] = .text(prev + t)
        } else {
            out.append(n)
        }
    }
    return out
}
