/// The render loop (spec §7): markDirty → microtask-coalesced flush →
/// resolve+link → sweep → diff → apply → commit.
@MainActor
public final class Runtime<Backend: RendererBackend> {
    private let applier: TreeApplier<Backend>
    private let store = StateStore()
    private let listeners = ListenerRegistry()
    private let effects = EffectStore()
    private let rootTag: AnyTag
    private let scheduleMicrotask: (@escaping () -> Void) -> Void
    private var current: Node?
    private var dirty: Set<NodeIdentity> = []
    private var scheduled = false
    private var isRendering = false
    var _forceFullPasses = false     // test hook (Task 7): bypass scoping
    var _store: StateStore { store }            // test hooks
    var _listenerCount: Int { listeners.count }

    public init(backend: Backend, container: Backend.HostNode, root: some Tag,
                scheduleMicrotask: @escaping (@escaping () -> Void) -> Void) {
        applier = TreeApplier(backend: backend, container: container)
        rootTag = AnyTag(root)
        self.scheduleMicrotask = scheduleMicrotask
    }

    /// Event entry point: backends' listeners call this with the fired ID;
    /// tests call it directly to simulate clicks.
    public func dispatch(_ id: ListenerID, payload: Any? = nil) {
        listeners.handler(for: id)?(payload)
    }

    func markDirty(_ id: NodeIdentity) {
        assert(!isRendering, "State write during body evaluation")
        dirty.insert(id)
        if !scheduled {
            scheduled = true
            scheduleMicrotask { [weak self] in self?.flush() }
        }
    }

    public func mount() { renderPass() }

    public func flush() {
        scheduled = false
        guard !dirty.isEmpty else { return }
        let ids = dirty
        dirty.removeAll()
        if current == nil || _forceFullPasses || ids.contains(.root) {
            renderPass(); return
        }
        for id in minimalCover(ids) {
            guard let row = store.retainedRow(at: id) else { continue }   // removed this flush
            subtreePass(id, row)
        }
    }

    /// Drops ids that are descendants of other dirty ids (spec §2.2).
    func minimalCover(_ ids: Set<NodeIdentity>) -> [NodeIdentity] {
        var cover: [NodeIdentity] = []
        for id in ids.sorted(by: { $0.segments.count < $1.segments.count }) {
            if !cover.contains(where: { id.isSelfOrDescendant(of: $0) }) { cover.append(id) }
        }
        return cover
    }

    private func subtreePass(_ id: NodeIdentity, _ row: RetainedComponent) {
        guard let old = findNode(current!, at: id),
              let mounted = applier.componentIndex[id] else {
            renderPass(); return                                  // defensive: fall back to full
        }
        var ctx = ResolveContext(store: store, listeners: listeners,
                                 invalidate: { [weak self] in self?.markDirty($0) })
        ctx.environment = row.environment
        isRendering = true
        let parentPath = NodeIdentity(segments: Array(id.segments.dropLast()))
        let nodes = resolve(row.tag, path: parentPath, ctx: &ctx)   // re-appends .type → same id
        isRendering = false
        assert(nodes.count == 1, "component must resolve to exactly one node")
        let new = nodes[0]

        store.sweep(under: id, reachable: ctx.reachable)
        listeners.sweep(under: id, keep: ctx.liveListeners)

        let patches = Reconciler().diff(old: old, new: new)
        applier.apply(patches, to: mounted)          // top-level per pass → shadow anchors safe
        current = splicing(current!, at: id, with: new)

        let callbacks = effects.reconcile(ctx.effects, under: id)
        for cb in callbacks { cb() }
    }

    private func renderPass() {
        // 1. RESOLVE + LINK.
        var ctx = ResolveContext(store: store, listeners: listeners,
                                 invalidate: { [weak self] id in self?.markDirty(id) })
        isRendering = true
        let children = coalesceText(resolve(rootTag, path: .root, ctx: &ctx))
        isRendering = false
        let new = Node.component(ComponentNode(identity: .root, typeName: "Root",
                                               key: nil, children: children))
        // 2. SWEEP (state: reachable component ids; listeners: live IDs — decision 21).
        store.sweep(under: .root, reachable: ctx.reachable)
        listeners.sweep(under: .root, keep: ctx.liveListeners)
        // 3–4. DIFF + APPLY.
        if let old = current {
            let patches = Reconciler().diff(old: old, new: new)
            applier.apply(patches, to: applier.root.children[0])
        } else {
            let m = applier.mount(new, hostParent: applier.root.host!, before: nil)
            m.parent = applier.root
            m.indexInParent = 0
            applier.root.children = [m]
        }
        // 5. COMMIT.
        current = new

        let callbacks = effects.reconcile(ctx.effects, under: .root)
        for cb in callbacks { cb() }
    }
}
