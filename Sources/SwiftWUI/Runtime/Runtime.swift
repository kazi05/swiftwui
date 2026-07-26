/// The render loop (spec §7): markDirty → microtask-coalesced flush →
/// resolve+link → sweep → diff → apply → commit.
@MainActor
public final class Runtime<Backend: RendererBackend> {
    private let applier: TreeApplier<Backend>
    private let store = StateStore()
    private let signals = EnvironmentSignals()
    private lazy var mediaStore = MediaMatchStore(observe: { [weak self] cond, cb in
        self?.applier.backend.observeMediaQuery(cond, onChange: cb) ?? false
    })
    private let storage = StorageStore()
    private let listeners = ListenerRegistry()
    private let effects = EffectStore()
    private let animationValues = AnimationValueStore()
    private let transitions = TransitionRegistry()
    private let windowEvents = WindowEventHub()
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
    private let fontFaces: [FontFace]
    var _forceFullPasses = false     // test hook (Task 7): bypass scoping
    /// SSG/hydration SPI (Task 9): set by boot code before its first flush
    /// after adopting a server-rendered tree, so that flush's fresh mounts
    /// don't play enter transitions as if newly inserted. Consumed (cleared)
    /// after that flush — covers every pass the flush runs, not just the first.
    public var _suppressTransitionsOnce = false
    // Per-write capture, drained each flush. Component-granularity: a second write
    // to the SAME component id under a different withAnimation in one flush is last-wins.
    private var pendingTransactions: [NodeIdentity: Transaction] = [:]
    var _pendingCompletionGroups: [CompletionGroup] = []                 // armed post-flush
    var _lastEffectiveTransactions: [NodeIdentity: Transaction] = [:]    // test hook (Task 4): union of this flush's passes
    // MARK: View transitions (spec 2026-07-26 §3.2)
    private var pendingViewTransition: ViewTransitionOptions?
    /// True once this flush's arm came from `navigate`/`handlePopState`, which
    /// already resolved the full precedence chain (explicit → Route → ambient).
    /// A navigation wins: the ambient `markDirty` path may only arm when
    /// nothing armed yet this flush, so a `withViewTransition` scope wrapping
    /// a `navigate(transition:)` call can't clobber its direction/preset with
    /// a directionless ambient one.
    private var pendingViewTransitionIsNavigation = false
    private var vtInFlight = false
    /// Set by build drivers (SSG/HTMLRenderer) BEFORE mount: a build reads
    /// `_currentTree`/`_locationPath` as settled truth and must never defer a commit.
    public var _disableViewTransitions = false
    var _viewTransitionInFlight: Bool { vtInFlight }      // test hook
    /// Test hook: models the DOM watchdog clearing a transition whose callback
    /// was never delivered.
    func _forceClearViewTransitionForTests() { vtInFlight = false }
    var _animationRegistry: AnimationRegistry { applier.animationRegistry }   // test hook (Task 7)
    var _exitingCount: Int { applier.exiting.count }   // test hook (Task 10): ghost-leak assertions
    var _transitionRegistry: TransitionRegistry { transitions }   // test hook (Task 8)
    public var _store: StateStore { store }     // test hook + SPI (spec §5): SSG snapshot encode
    public var _signals: EnvironmentSignals { signals }   // SPI: backend wiring + tests
    public var _mediaStore: MediaMatchStore { mediaStore }   // SPI: tests
    public var _storage: StorageStore { storage }   // SPI: backend wiring + tests
    /// Set by the platform layer (DOMRuntime / SSG driver) BEFORE mount().
    public var _webSession: WebSession?
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
                globalStyles: [Rule] = [], themes: [ThemeDefinition] = [], fontFaces: [FontFace] = []) {
        let (path, query, _) = RouteURL.split(initialPath)
        currentPath = RouteURL.normalizePath(path)
        currentQuery = query
        applier = TreeApplier(backend: backend, container: container)
        applier.transitionsRef = transitions
        rootTag = AnyTag(root)
        self.scheduleMicrotask = scheduleMicrotask
        self.globalStyles = globalStyles
        self.themes = themes
        self.fontFaces = fontFaces
        effects._windowHub = windowEvents
        effects._onDropGuardChange = { [weak self] enabled in
            self?.applier.backend.setDropNavigationGuard(enabled)
        }
        windowEvents.onFirstSubscriber = { [weak self] in
            guard let self else { return }
            self.applier.backend.beginWindowEventObservation { [weak self] kind, payload in
                self?.windowEvents.dispatch(kind, payload: payload)
            }
        }
    }

    /// Event entry point: backends' listeners call this with the fired ID;
    /// tests call it directly to simulate clicks.
    public func dispatch(_ id: ListenerID, payload: Any? = nil) {
        listeners.handler(for: id)?(payload)
    }

    func markDirty(_ id: NodeIdentity) {
        assert(!isRendering, "State write during body evaluation")
        dirty.insert(id)
        if let t = Transaction._active {
            pendingTransactions[id] = t
            if let g = t._group, !_pendingCompletionGroups.contains(where: { $0 === g }) {
                _pendingCompletionGroups.append(g)
            }
        }
        if let vt = ViewTransitionScope._active { armViewTransition(vt, direction: nil) }
        if !scheduled {
            scheduled = true
            scheduleMicrotask { [weak self] in self?.flush() }
        }
    }

    public func mount() {
        applier.backend.beginEnvironmentObservation(signals.writer)
        storage.readBacking = { [weak self] kind, key in
            self?.applier.backend.storageRead(kind: kind, key: key)
        }
        storage.writeBacking = { [weak self] kind, key, value in
            self?.applier.backend.storageWrite(kind: kind, key: key, value: value)
        }
        applier.backend.beginStorageObservation { [weak self] kind, key, raw in
            self?.storage.externalChange(kind: kind, key: key, raw: raw)
        }
        for face in fontFaces { styleRegistry.registerRaw(face.ruleText) }
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
    public func navigate(to url: String, replace: Bool = false,
                         transition: PageTransition? = nil) {
        assert(!RouteURL.isExternal(url),
               "navigate() expects an app-internal path, got '\(url)' — use a plain A/Link for external URLs")
        let (rawPath, query, search) = RouteURL.split(url)
        let path = RouteURL.normalizePath(rawPath)
        guard path != currentPath || query != currentQuery else { redirectHops = 0; return }  // arriving at the current location ends any redirect chain
        currentPath = path; currentQuery = query
        let full = search.isEmpty ? path : path + "?" + search
        if replace { applier.backend.replaceState(path: full) }
        else { applier.backend.pushState(path: full) }
        // A guard redirect must not animate a hop the user never asked for; an
        // explicit transition on a replace call still wins (spec §4).
        armViewTransition(transition ?? (replace ? nil : routeDeclaredTransition(for: path)),
                          direction: replace ? nil : .push, isNavigation: true)
        markDirty(.root)
    }

    /// Browser back/forward: the location already changed — no pushState.
    public func handlePopState(url: String) {
        let (rawPath, query, _) = RouteURL.split(url)
        currentPath = RouteURL.normalizePath(rawPath)
        currentQuery = query
        armViewTransition(routeDeclaredTransition(for: currentPath), direction: .pop, isNavigation: true)
        markDirty(.root)
    }

    public func flush() {
        // A transition's update callback owns the next pass; a flush that lands
        // in the capture window must ALSO clear `scheduled`, or markDirty's
        // `if !scheduled` gate stops queueing microtasks for good.
        if vtInFlight { scheduled = false; return }
        scheduled = false
        // Consumed unconditionally by any flush, even one that early-returns on
        // empty dirt — the contract is "cleared after that flush", not "after
        // the next flush that renders" (Task 9).
        let suppressOnce = _suppressTransitionsOnce
        _suppressTransitionsOnce = false
        guard !dirty.isEmpty else {
            pendingViewTransition = nil; pendingViewTransitionIsNavigation = false; return
        }
        let ids = dirty
        dirty.removeAll()
        let drained = pendingTransactions
        pendingTransactions.removeAll()
        let drainedGroups = _pendingCompletionGroups
        _pendingCompletionGroups.removeAll()
        _lastEffectiveTransactions.removeAll()

        guard let vt = pendingViewTransition else {
            runPasses(ids, transactionOverrides: drained, groups: drainedGroups,
                      suppressTransitions: suppressOnce)
            return
        }
        pendingViewTransition = nil
        pendingViewTransitionIsNavigation = false
        vtInFlight = true
        var ran = false
        let body: () -> Void = { [weak self] in
            guard let self, !ran else { return }   // idempotent: at most one commit per transition
            ran = true
            // Clearing the flag and scheduling the follow-up from a `defer`
            // keeps both correct if `runPasses` exits abnormally. Order matters:
            // clear first, THEN schedule — an immediate scheduler (SSG, tests)
            // runs the follow-up synchronously and would otherwise bounce off
            // the guard and swallow the owed flush.
            defer {
                self.vtInFlight = false
                self.scheduleMicrotask { [weak self] in self?.flush() }
            }
            // Enter/exit transitions are suppressed: an exit ghost keeps its
            // view-transition-name in the DOM and would duplicate a name in the
            // new frame, which makes the browser skip the whole transition.
            self.runPasses(ids, transactionOverrides: drained, groups: drainedGroups,
                           suppressTransitions: true)
        }
        applier.backend.performViewTransition(vt, update: body)
    }

    /// Pass dispatch + completion-group arming, lifted out of `flush` so a view
    /// transition can run it from inside the backend's update callback.
    private func runPasses(_ ids: Set<NodeIdentity>,
                           transactionOverrides drained: [NodeIdentity: Transaction],
                           groups: [CompletionGroup],
                           suppressTransitions: Bool) {
        if current == nil || _forceFullPasses || ids.contains(.root) {
            renderPass(transactionOverrides: drained, suppressTransitionsOnce: suppressTransitions)
        } else {
            for id in minimalCover(ids) {
                guard let row = store.retainedRow(at: id) else { continue }   // removed this flush
                subtreePass(id, row, transactionOverrides: drained,
                            suppressTransitionsOnce: suppressTransitions)
            }
        }
        // Armed AFTER all of this flush's passes: an empty group (nothing yet
        // registered against it) fires on the next microtask (anim spec §7.4).
        for g in groups { g.arm(schedule: scheduleMicrotask) }
    }

    /// Arms `t` for the next flush unless something forbids a transition
    /// (spec §3.2, §4). Never arms while one is in flight: the in-flight
    /// transition already renders the newest path, and a nested
    /// `startViewTransition` would abort it and reorder callbacks.
    ///
    /// `isNavigation` is true only for `navigate`/`handlePopState`, which have
    /// already resolved the full precedence chain (explicit → Route →
    /// ambient) — that arm wins over an enclosing `withViewTransition` scope's
    /// ambient arm for the rest of this flush. Two ambient arms in the same
    /// flush still last-wins, same as before.
    private func armViewTransition(_ t: PageTransition?, direction: NavDirection?,
                                   isNavigation: Bool = false) {
        guard let t, !vtInFlight, !_disableViewTransitions,
              !(signals.reduceMotion && t.respectsReducedMotion),
              !signals.dragSession.isActive,
              isNavigation || !pendingViewTransitionIsNavigation else { return }
        pendingViewTransition = t.options(direction: direction)
        if isNavigation { pendingViewTransitionIsNavigation = true }
    }

    /// The transition declared by the `Route` that will match `path`.
    /// Task 3 fills this in from the Router-published table; until then only
    /// explicit call-site transitions arm.
    private func routeDeclaredTransition(for path: String) -> PageTransition? { nil }

    /// Drops ids that are descendants of other dirty ids (spec §2.2).
    func minimalCover(_ ids: Set<NodeIdentity>) -> [NodeIdentity] {
        var cover: [NodeIdentity] = []
        for id in ids.sorted(by: { $0.segments.count < $1.segments.count }) {
            if !cover.contains(where: { id.isSelfOrDescendant(of: $0) }) { cover.append(id) }
        }
        return cover
    }

    private func subtreePass(_ id: NodeIdentity, _ row: RetainedComponent,
                             transactionOverrides: [NodeIdentity: Transaction] = [:],
                             suppressTransitionsOnce: Bool = false) {
        guard let old = findNode(current!, at: id),
              let mounted = applier.componentIndex[id] else {
            renderPass(transactionOverrides: transactionOverrides,
                      suppressTransitionsOnce: suppressTransitionsOnce); return   // defensive: fall back to full — forward the flush's captures so animated writes don't silently degrade
        }
        var ctx = ResolveContext(store: store, listeners: listeners,
                                 invalidate: { [weak self] in self?.markDirty($0) })
        ctx.registry = styleRegistry
        ctx.animationValues = animationValues
        ctx.transitions = transitions
        passCounter += 1; ctx.pass = passCounter
        // Snapshot is never stale for routeInfo: navigation always marks .root (full pass),
        // which re-retains every row's environment.
        ctx.environment = row.environment
        // Restore the caller's Styled scope. For a plain component this is a
        // no-op (its own boundary resets scope), but `ModifiedTag` preserves it —
        // without re-seeding, the scope marker would drop from the modifier body
        // and wrapped content on this pass (scoped ≡ full invariant, spec §6/§11).
        ctx.scopeClass = row.scopeClass
        // Carrier (anim spec §4): this cover id's own captured transaction, plus
        // the full drained map so deeper dirty ids under this cover still
        // override at their own component boundary.
        ctx.transaction = transactionOverrides[id]
        ctx.transactionOverrides = transactionOverrides
        isRendering = true
        let parentPath = NodeIdentity(segments: Array(id.segments.dropLast()))
        let nodes = resolve(row.tag, path: parentPath, ctx: &ctx)   // re-appends .type → same id
        isRendering = false
        _lastEffectiveTransactions.merge(ctx.effectiveTransactions) { _, latest in latest }
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
        animationValues.sweep(under: id, reachable: ctx.reachable)

        let patches = Reconciler().diff(old: old, new: new)
        applier.animationPass = AnimationPassContext(transactions: ctx.effectiveTransactions,
                                                      reduceMotion: signals.reduceMotion,
                                                      suppressTransitions: suppressTransitionsOnce,
                                                      defaultTransaction: ctx.transaction)
        applier.apply(patches, to: mounted)          // top-level per pass → shadow anchors safe
        applier.animationPass = nil
        current = splicing(current!, at: id, with: new)
        // Post-commit (see renderPass): survive an entry whose element is
        // still live even though the registering wrapper is above this pass root.
        transitions.sweep(under: id, stillExists: { [weak self] eid in
            self.flatMap { $0.current.flatMap { findNode($0, at: eid) != nil } } ?? false
        })

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
            applier.backend.setLinks(head.links)
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

    private func renderPass(transactionOverrides: [NodeIdentity: Transaction] = [:],
                            suppressTransitionsOnce: Bool = false) {
        // 1. RESOLVE + LINK.
        var ctx = ResolveContext(store: store, listeners: listeners,
                                 invalidate: { [weak self] id in self?.markDirty(id) })
        ctx.registry = styleRegistry
        ctx.animationValues = animationValues
        ctx.transitions = transitions
        ctx.transactionOverrides = transactionOverrides   // carrier (anim spec §4): applied at each component boundary
        passCounter += 1; ctx.pass = passCounter
        ctx.environment.setTheme = { [weak self] name in self?.setTheme(name) }
        ctx.environment._signals = signals
        ctx.environment._mediaStore = mediaStore
        ctx.environment._storageStore = storage
        ctx.environment._webSessionOptional = _webSession
        ctx.environment.routeInfo = RouteInfo(path: currentPath, query: currentQuery)
        ctx.environment.navigate = NavigateAction { [weak self] path, replace in
            self?.navigate(to: path, replace: replace)
        }
        ctx.environment.back = { [weak self] in self?.applier.backend.historyBack() }
        ctx.environment.reloadToUpdate = { [weak self] in self?.applier.backend.reloadForUpdate() }
        isRendering = true
        let children = coalesceText(resolve(rootTag, path: .root, ctx: &ctx))
        isRendering = false
        _lastEffectiveTransactions.merge(ctx.effectiveTransactions) { _, latest in latest }
        let new = Node.component(ComponentNode(identity: .root, typeName: "Root",
                                               key: nil, children: children))
        // 2. SWEEP (state: reachable component ids; listeners: live IDs — decision 21).
        store.sweep(under: .root, reachable: ctx.reachable)
        listeners.sweep(under: .root, keep: ctx.liveListeners)
        animationValues.sweep(under: .root, reachable: ctx.reachable)
        // 3–4. DIFF + APPLY.
        applier.animationPass = AnimationPassContext(transactions: ctx.effectiveTransactions,
                                                      reduceMotion: signals.reduceMotion,
                                                      suppressTransitions: current == nil || suppressTransitionsOnce,
                                                      defaultTransaction: transactionOverrides[.root])
        if let old = current {
            let patches = Reconciler().diff(old: old, new: new)
            applier.apply(patches, to: applier.root.children[0])
        } else {
            let m = applier.mount(new, hostParent: applier.root.host!, before: nil)
            m.parent = applier.root
            m.indexInParent = 0
            applier.root.children = [m]
        }
        applier.animationPass = nil
        // 5. COMMIT.
        current = new
        // Transition sweep runs post-commit: an entry survives while its
        // element is still in the tree even if this pass didn't re-run its
        // registering wrapper (wrapper above a subtree pass root).
        transitions.sweep(under: .root, stillExists: { [weak self] id in
            self.flatMap { $0.current.flatMap { findNode($0, at: id) != nil } } ?? false
        })

        if styleRegistry.version != flushedStyleVersion {
            flushedStyleVersion = styleRegistry.version
            applier.backend.setStylesheet(styleRegistry.text)
        }

        let callbacks = effects.reconcile(ctx.effects, under: .root)
        for cb in callbacks { cb() }
        commitRouteEffects(ctx)
    }
}
