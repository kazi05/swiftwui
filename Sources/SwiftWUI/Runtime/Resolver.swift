import Observation

// Sendable adapter for the @Sendable onChange closure. Safe: every state write
// in the pipeline is @MainActor (module default isolation), so onChange always
// fires on the main actor in practice (spec D4).
struct _InvalidateBox: @unchecked Sendable {
    let fire: () -> Void
}

public struct ResolveContext {
    let store: StateStore
    let listeners: ListenerRegistry
    let invalidate: (NodeIdentity) -> Void
    var reachable: Set<NodeIdentity> = []
    var liveListeners: Set<ListenerID> = []
    var environment = EnvironmentValues()
    /// Nearest enclosing component — primitives that run content closures
    /// outside the component's tracking window (ForEach) bind their own
    /// tracking to this id so model reads still invalidate the right owner.
    var owner: NodeIdentity = .root
    /// Scope marker of the innermost Styled component; appended to every
    /// element resolved in its body. Reset at EVERY component boundary.
    var scopeClass: String? = nil
    var visibilityRoots: [String: NodeIdentity] = [:]
    var effects: [EffectRequest] = []
    var registry = StyleRegistry()
    /// Monotonic id of the current resolution (one renderPass/subtreePass).
    /// Lets `setStyleWrapper` reset its per-identity accumulator once per pass.
    var pass: Int = 0
    /// First guard `.redirect` seen this pass; the runtime performs it
    /// POST-pass via navigate(replace: true) — never re-entrantly (spec §5).
    var pendingRedirect: String? = nil
    /// Head snapshot of the matched Page, if any (spec §9).
    var pageHead: PageHead? = nil
    /// Boot UI declared by the matched Page, if any (boot spec §5.3).
    /// Deliberately NOT a `PageHead` field: `PageHead: Equatable` gates head
    /// re-application, and `BootUI` wraps an `AnyTag`.
    var bootUI: BootUI? = nil
    /// True during the SSG's build render. Read by `_WhileBootingTag` to decide
    /// whether to emit its placeholder — it must never change the identity path
    /// of the wrapped content (boot spec §5.4).
    var isBuildRender = false
    /// Authoring findings collected by `.whileBooting` placeholders (`BootProbe`).
    /// Always empty in the browser: the placeholder is not resolved at all when
    /// `isBuildRender` is false.
    var bootFindings: [BootProbe.Finding] = []
    /// False when the Router fell through to its notFound branch (spec §7).
    var routeMatched = true
    /// Partial head written by `.pageMeta` from inside the route subtree (spec §5.1).
    var pageHeadPatch: PageHeadPatch? = nil
    /// Routers resolved this pass — asserted ≤ 1 (spec D9).
    var routerCount = 0
    /// Ambient page transition seen by the Router (spec §4); nil = none.
    var routerTransitionDefault: PageTransition? = nil
    /// ALL routes in declaration order with their declared transition (nil
    /// included). Ordered and complete because the Runtime must reproduce
    /// Router's first-match-wins: a dictionary is unordered and would omit
    /// transition-less patterns, so `/todo/new` before `/todo/:id` could resolve
    /// to a different route than the one that renders.
    var routeTransitions: [(RoutePattern, PageTransition?)] = []
    /// Non-nil during a `Runtime._collectRoutes()` pass: every Router appends
    /// its routes here (spec §5, SSG route enumeration).
    var collectedRoutes: [_CollectedRoute]? = nil
    /// Ambient transaction for the element(s) currently resolving (anim spec §4).
    /// Set at a component boundary from `transactionOverrides`; otherwise
    /// inherited from the enclosing component (propagates through primitives).
    var transaction: Transaction? = nil
    /// Input: this flush's per-write captures, keyed by the component id that
    /// made the write (`Runtime.markDirty`). Looked up at every component
    /// boundary to (re)set `transaction`.
    var transactionOverrides: [NodeIdentity: Transaction] = [:]
    /// Output: element identity → the transaction in effect when it resolved.
    var effectiveTransactions: [NodeIdentity: Transaction] = [:]
    /// Owning runtime's `.animation(_:value:)` value store (anim spec §4.3);
    /// nil in passes that never seed it (e.g. `_collectRoutes`).
    var animationValues: AnimationValueStore? = nil
    /// Owning runtime's `.transition(_:)` registry (Task 8); nil in passes
    /// that never seed it (e.g. `_collectRoutes`).
    var transitions: TransitionRegistry? = nil
    var scrollRegistry: (any _ScrollRegistryContext)? = nil
    var scrollReaders: [NodeIdentity: ScrollContainer] = [:]
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
    _TypeNameRegistry.register(T.self)     // snapshot keys need the stable name (spec D7)
    ctx.reachable.insert(id)
    ctx.store.retain(AnyTag(tag), at: id, environment: ctx.environment,
                     scopeClass: ctx.scopeClass, visibilityRoots: ctx.visibilityRoots)
    let inv = ctx.invalidate
    if ctx.collectedRoutes == nil {                    // collect passes never link (C1: shared Slots would rebind live boxes)
        ctx.store.link(tag, at: id, environment: ctx.environment, invalidate: { inv(id) })          // graft BEFORE body
    }
    let box = _InvalidateBox(fire: { inv(id) })
    let savedOwner = ctx.owner
    let savedScope = ctx.scopeClass
    let savedTransaction = ctx.transaction
    ctx.owner = id
    ctx.scopeClass = nil                       // child components never inherit a parent scope
    if let t = ctx.transactionOverrides[id] { ctx.transaction = t }
    defer { ctx.owner = savedOwner; ctx.scopeClass = savedScope; ctx.transaction = savedTransaction }
    // Tracking covers body evaluation; ForEach additionally re-binds tracking
    // for its per-item content closures to ctx.owner (see ForEach._resolve).
    var styledRules: [Rule] = []
    let body = withObservationTracking {
        if let styled = tag as? any Styled { styledRules = styled.styles }
        return tag.body
    } onChange: {
        MainActor.assumeIsolated { box.fire() }
    }
    if !styledRules.isEmpty {
        let marker = scopeMarker(forTypeName: String(reflecting: T.self))
        ctx.scopeClass = marker
        for rule in styledRules { rule.register(into: ctx.registry, scope: marker) }
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
    var observers: [ObserverKind: ListenerID] = [:]
    var byKind: [ObserverKind: [(Any?) -> Void]] = [:]
    var kindOrder: [ObserverKind] = []
    for (kind, action) in bag.observers {
        if byKind[kind] == nil { kindOrder.append(kind) }
        byKind[kind, default: []].append(action)
    }
    for kind in kindOrder {
        let lid = ListenerID(owner: path, event: kind.key)
        let chain = byKind[kind]!
        ctx.listeners.set(lid, payloadHandler: { payload in
            for handler in chain { handler(payload) }
        })
        ctx.liveListeners.insert(lid)
        observers[kind] = lid
    }
    var configured: [_ResolvedVisibilityObservation] = []
    for (index, request) in bag.configuredVisibility.enumerated() {
        let id = ListenerID(owner: path, event: "swui:configuredVisibility:\(index)")
        let root: _ResolvedVisibilityRoot
        switch request.root {
        case .viewport:
            root = .viewport
        case .ancestor(let name):
            root = ctx.visibilityRoots[name].map { .ancestor($0) } ?? .unavailable
        }
        ctx.listeners.set(id, payloadHandler: { payload in
            guard let value = payload as? Bool else { return }
            request.action(value)
        })
        ctx.liveListeners.insert(id)
        configured.append(.init(id: id, root: root,
                                threshold: request.threshold, margin: request.margin))
    }
    var effectiveBag = bag
    if !bag.localized.isEmpty {
        let locale = ctx.environment.locale
        let fallback = ctx.environment._signals?.defaultLocale
        for (name, text) in bag.localized {
            effectiveBag.set(name, text.resolved(for: locale, fallback: fallback))
        }
    }
    for rule in bag.pendingRules {
        if let kf = rule.keyframes { ctx.registry.registerRaw(kf.ruleText) }
        if let raw = rule.rawText { ctx.registry.registerRaw(raw); continue }
        let cls = ctx.registry.registerAnonymous(pseudo: rule.pseudo, media: rule.media,
                                                 container: rule.container,
                                                 declarations: rule.declarations)
        effectiveBag.appendClasses([cls])
    }
    if let scope = ctx.scopeClass {
        effectiveBag.appendClasses([scope])
    }
    let savedRoots = ctx.visibilityRoots
    if let name = bag.visibilityRootID { ctx.visibilityRoots[name] = path }
    let children = coalesceText(resolve(content, path: path.appending(.child(0)), ctx: &ctx))
    ctx.visibilityRoots = savedRoots
    var attrs = effectiveBag.flattened()
    let objectURLs = effectiveBag.objectURLs.filter { !$0.value.isRevoked }
    var style = OrderedStyle(parsing: attrs["style"] ?? "")   // raw `.attribute("style", …)` escape hatch as base
    style.merge(effectiveBag.styles)                          // bag styles on top, last-wins per property
    attrs["style"] = nil                                      // moved onto the typed ElementNode.style
    if let t = ctx.transaction { ctx.effectiveTransactions[path] = t }
    var element = ElementNode(identity: path, tag: tagName, attributes: attrs,
                              objectURLs: objectURLs, style: style,
                              properties: effectiveBag.flattenedProperties(),
                              listeners: listeners, observers: observers, children: children, key: nil)
    element.configuredVisibility = configured
    return [.element(element)]
}
