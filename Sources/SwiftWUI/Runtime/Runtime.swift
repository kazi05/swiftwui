/// The render loop (spec §7): markDirty → microtask-coalesced flush →
/// resolve+link → sweep → diff → apply → commit.
@MainActor
public final class Runtime<Backend: RendererBackend> {
    private let applier: TreeApplier<Backend>
    private let store = StateStore()
    private let listeners = ListenerRegistry()
    private let rootTag: AnyTag
    private let scheduleMicrotask: (@escaping () -> Void) -> Void
    private var current: Node?
    private var dirty: Set<NodeIdentity> = []
    private var scheduled = false
    private var isRendering = false

    public init(backend: Backend, container: Backend.HostNode, root: some Tag,
                scheduleMicrotask: @escaping (@escaping () -> Void) -> Void) {
        applier = TreeApplier(backend: backend, container: container)
        rootTag = AnyTag(root)
        self.scheduleMicrotask = scheduleMicrotask
    }

    /// Event entry point: backends' listeners call this with the fired ID;
    /// tests call it directly to simulate clicks.
    public func dispatch(_ id: ListenerID) {
        listeners.handler(for: id)?()
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
        dirty.removeAll()      // phase 1: any dirt ⇒ full pass from root.
        renderPass()           // phase 2 reads the set for scoped re-render (spec §7).
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
    }
}
