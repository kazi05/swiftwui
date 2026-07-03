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
    private var passCounter = 0     // bumped per render/subtree pass; scopes setStyleWrapper reset
    private let styleRegistry = StyleRegistry()
    private var flushedStyleVersion = 0
    private let globalStyles: [Rule]
    // Routing (spec §7): the runtime owns the current location.
    private var currentPath: String
    private var currentQuery: [String: String]
    private var lastPageHead: PageHead?
    private var redirectHops = 0
    private let themes: [ThemeDefinition]
    var _forceFullPasses = false     // test hook (Task 7): bypass scoping
    var _store: StateStore { store }            // test hooks
    var _listenerCount: Int { listeners.count }
    var _current: Node? { current }
    public var _registryText: String { styleRegistry.text }        // test hook + SPI (spec §5)
    public var _effects: EffectStore { effects }            // SPI: SSG driver (Task 11) / hydration boot (Task 13)

    // SSG/hydration SPI (spec §5): stable underscore-public surface for
    // SwiftWUIStatic and SwiftWUIDOM. Not API.
    public var _currentTree: Node? { current }
    public var _pageHead: PageHead? { lastPageHead }
    public var _locationPath: String { currentPath }

    /// One throwaway resolve with route collection on. Uses a FRESH store and
    /// listener registry. Collect passes skip StateStore.link (shared Slots
    /// would rebind live boxes — C1), so bodies resolve with struct-initial
    /// values and @Environment defaults. Guards DO run (they run on any
    /// resolve); redirects/pageHead of this pass are discarded.
    public func _collectRoutes() -> [RoutePattern] {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        ctx.collectedRoutes = []
        ctx.environment.routeInfo = RouteInfo(path: currentPath, query: currentQuery)
        passCounter += 1; ctx.pass = passCounter
        _ = resolve(rootTag, path: .root, ctx: &ctx)
        return ctx.collectedRoutes ?? []
    }

    public init(backend: Backend, container: Backend.HostNode, root: some Tag,
                initialPath: String = "/",
                scheduleMicrotask: @escaping (@escaping () -> Void) -> Void,
                globalStyles: [Rule] = [], themes: [ThemeDefinition] = []) {
        let (path, query, _) = RouteURL.split(initialPath)
        currentPath = RouteURL.normalizePath(path)
        currentQuery = query
        applier = TreeApplier(backend: backend, container: container)
        rootTag = AnyTag(root)
        self.scheduleMicrotask = scheduleMicrotask
        self.globalStyles = globalStyles
        self.themes = themes
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

    public func mount() {
        for theme in themes { styleRegistry.registerRaw(theme.ruleText) }
        for rule in globalStyles { rule.register(into: styleRegistry, scope: nil) }
        renderPass()
    }

    /// One data-theme attribute write on the mount container; zero re-render.
    public func setTheme(_ name: String?) {
        let container = applier.root.host!
        if let name {
            applier.backend.setAttribute(container, name: "data-theme", value: name)
        } else {
            applier.backend.removeAttribute(container, name: "data-theme")
        }
    }

    /// SPA navigation (spec §7): update location → pushState/replaceState →
    /// full pass. Same path+query → no-op (prevents self-redirect loops).
    public func navigate(to url: String, replace: Bool = false) {
        assert(!RouteURL.isExternal(url),
               "navigate() expects an app-internal path, got '\(url)' — use a plain A/Link for external URLs")
        let (rawPath, query, search) = RouteURL.split(url)
        let path = RouteURL.normalizePath(rawPath)
        guard path != currentPath || query != currentQuery else { redirectHops = 0; return }  // arriving at the current location ends any redirect chain
        currentPath = path; currentQuery = query
        let full = search.isEmpty ? path : path + "?" + search
        if replace { applier.backend.replaceState(path: full) }
        else { applier.backend.pushState(path: full) }
        markDirty(.root)
    }

    /// Browser back/forward: the location already changed — no pushState.
    public func handlePopState(url: String) {
        let (rawPath, query, _) = RouteURL.split(url)
        currentPath = RouteURL.normalizePath(rawPath)
        currentQuery = query
        markDirty(.root)
    }

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
        ctx.registry = styleRegistry
        passCounter += 1; ctx.pass = passCounter
        // Snapshot is never stale for routeInfo: navigation always marks .root (full pass),
        // which re-retains every row's environment.
        ctx.environment = row.environment
        isRendering = true
        let parentPath = NodeIdentity(segments: Array(id.segments.dropLast()))
        let nodes = resolve(row.tag, path: parentPath, ctx: &ctx)   // re-appends .type → same id
        isRendering = false
        assert(nodes.count == 1, "component must resolve to exactly one node")
        var new = nodes[0]
        new.key = old.key   // resolve() doesn't see ForEach's key tagging (one level up); preserve it
        // This pass starts at the row's own tag, skipping back up through any
        // enclosing `_StyledTag`'s `_resolve` — replay its stashed transforms
        // (spec §6, §11: scoped ≡ full must hold for wrapper-styled components).
        // The wrappers do NOT re-run during this subtree pass, so the list is
        // whatever the last pass that resolved them left — replay inner→outer.
        for wrapper in row.styleWrappers {
            // Re-stash at every descended identity too (not just this row's own),
            // same as the wrapper's own `_resolve` — a pass-through component one
            // level deeper still needs a fresh stash for pass `ctx.pass` (CRITICAL 1).
            applyStyleWrapper(declarations: wrapper.declarations, classes: wrapper.classes, to: &new) { [store] compId in
                store.setStyleWrapper(at: compId, pass: ctx.pass,
                                      declarations: wrapper.declarations, classes: wrapper.classes)
            }
        }

        store.sweep(under: id, reachable: ctx.reachable)
        listeners.sweep(under: id, keep: ctx.liveListeners)

        let patches = Reconciler().diff(old: old, new: new)
        applier.apply(patches, to: mounted)          // top-level per pass → shadow anchors safe
        current = splicing(current!, at: id, with: new)

        if styleRegistry.version != flushedStyleVersion {
            flushedStyleVersion = styleRegistry.version
            applier.backend.setStylesheet(styleRegistry.text)
        }

        let callbacks = effects.reconcile(ctx.effects, under: id)
        for cb in callbacks { cb() }
        commitRouteEffects(ctx)
    }

    /// Applies Router by-products after a pass (spec §5, §9): head writes when
    /// the snapshot changed, then at most one redirect hop (capped at 10).
    private func commitRouteEffects(_ ctx: ResolveContext) {
        if let head = ctx.pageHead, head != lastPageHead {
            lastPageHead = head
            applier.backend.setTitle(head.title)
            applier.backend.setMetaTags(head.meta)
        }
        if let target = ctx.pendingRedirect {
            redirectHops += 1
            guard redirectHops <= 10 else {
                assertionFailure("Router: redirect chain exceeded 10 hops (→ \(target))")
                redirectHops = 0
                return
            }
            navigate(to: target, replace: true)
        } else {
            redirectHops = 0
        }
    }

    private func renderPass() {
        // 1. RESOLVE + LINK.
        var ctx = ResolveContext(store: store, listeners: listeners,
                                 invalidate: { [weak self] id in self?.markDirty(id) })
        ctx.registry = styleRegistry
        passCounter += 1; ctx.pass = passCounter
        ctx.environment.setTheme = { [weak self] name in self?.setTheme(name) }
        ctx.environment.routeInfo = RouteInfo(path: currentPath, query: currentQuery)
        ctx.environment.navigate = NavigateAction { [weak self] path, replace in
            self?.navigate(to: path, replace: replace)
        }
        ctx.environment.back = { [weak self] in self?.applier.backend.historyBack() }
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

        if styleRegistry.version != flushedStyleVersion {
            flushedStyleVersion = styleRegistry.version
            applier.backend.setStylesheet(styleRegistry.text)
        }

        let callbacks = effects.reconcile(ctx.effects, under: .root)
        for cb in callbacks { cb() }
        commitRouteEffects(ctx)
    }
}
