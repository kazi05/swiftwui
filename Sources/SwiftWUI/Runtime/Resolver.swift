import Observation

// Sendable adapter for the @Sendable onChange closure. Safe: every state write
// in the pipeline is @MainActor (module default isolation), so onChange always
// fires on the main actor in practice (spec D4).
private struct _InvalidateBox: @unchecked Sendable {
    let fire: () -> Void
}

public struct ResolveContext {
    let store: StateStore
    let listeners: ListenerRegistry
    let invalidate: (NodeIdentity) -> Void
    var reachable: Set<NodeIdentity> = []
    var liveListeners: Set<ListenerID> = []
    var environment = EnvironmentValues()
    var effects: [EffectRequest] = []
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
    ctx.store.retain(AnyTag(tag), at: id, environment: ctx.environment)
    let inv = ctx.invalidate
    ctx.store.link(tag, at: id, environment: ctx.environment, invalidate: { inv(id) })          // graft BEFORE body
    let box = _InvalidateBox(fire: { inv(id) })
    // Tracking covers body evaluation only; reads inside primitive content
    // closures (ForEach) are not tracked — see ForEach's `content` doc.
    let body = withObservationTracking {
        tag.body
    } onChange: {
        MainActor.assumeIsolated { box.fire() }
    }
    let children = resolve(body, path: id.appending(.child(0)), ctx: &ctx)
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

/// The single element resolution path (spec §3.3): registers listeners under
/// structural IDs, resolves content under path + .child(0), emits ElementNode.
@MainActor
func resolveElement(tagName: String, bag: _AttributeBag, content: some Tag,
                    path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
    var listeners: [String: ListenerID] = [:]
    // Same-event handlers compose in registration order (e.g. an auto-registered
    // controlled-input binding writer followed by a user `.on()` handler) rather
    // than last-wins, which would silently drop the earlier handler.
    var byEvent: [String: [(Any?) -> Void]] = [:]
    var eventOrder: [String] = []
    for (event, action) in bag.handlers {
        if byEvent[event.rawValue] == nil { eventOrder.append(event.rawValue) }
        byEvent[event.rawValue, default: []].append(action)
    }
    for event in eventOrder {
        let lid = ListenerID(owner: path, event: event)
        let chain = byEvent[event]!
        ctx.listeners.set(lid, payloadHandler: { payload in
            for handler in chain { handler(payload) }
        })
        ctx.liveListeners.insert(lid)
        listeners[event] = lid
    }
    let children = coalesceText(resolve(content, path: path.appending(.child(0)), ctx: &ctx))
    return [.element(ElementNode(identity: path, tag: tagName, attributes: bag.flattened(),
                                 properties: bag.flattenedProperties(),
                                 listeners: listeners, children: children, key: nil))]
}
