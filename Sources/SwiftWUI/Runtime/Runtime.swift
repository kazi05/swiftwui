/// The render loop (spec §7): markDirty → microtask-coalesced flush →
/// resolve+link → sweep → diff → apply → commit.
@MainActor
public final class Runtime<Backend: RendererBackend> {
    nonisolated deinit { }
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
    private lazy var scrollRegistry = ScrollRegistry(
        backend: applier.backend,
        mountedRoot: { [weak self] id in self?.applier.componentIndex[id] },
        operationsAllowed: { [weak self] in self.map { !$0.isRendering } ?? false },
        reducedMotion: { [weak self] in self?.signals.reduceMotion ?? true },
        scheduleWork: { [weak self] in self?.scheduleRuntimeWork() }
    )
    private lazy var documentVisibilityEvents = SnapshotSubscriptionHub<Bool>(
        begin: { [weak self] sink in
            self?.applier.backend.beginDocumentVisibilityObservation(sink)
        }, schedule: scheduleMicrotask)
    private lazy var visualViewportEvents = SnapshotSubscriptionHub<VisualViewportMetrics>(
        begin: { [weak self] sink in
            self?.applier.backend.beginVisualViewportObservation(sink)
        }, schedule: scheduleMicrotask)
    private let rootTag: AnyTag
    private let scheduleMicrotask: (@escaping () -> Void) -> Void
    private var current: Node?
    private var dirty: Set<NodeIdentity> = []
    private var scheduled = false
    private var isRendering = false
    public var diagnostics: RuntimeDiagnostics?
    private var pendingDiagnosticReasons: [RuntimeRenderReason] = []
    private var mounted = false
    private var disposed = false
    private var passBatchDepth = 0
    private var passCounter = 0     // bumped per render/subtree pass; scopes setStyleWrapper reset

    private struct ScopedRegistryCleanup {
        let root: NodeIdentity
        let newNode: Node
        let reachable: Set<NodeIdentity>
        let listeners: Set<ListenerID>
        let effects: [EffectRequest]
        let context: ResolveContext
    }
    private let styleRegistry = StyleRegistry()
    private var flushedStyleVersion = 0
    private let globalStyles: [Rule]
    /// The app's localization declaration, `nil` for monolingual apps.
    public let _localization: Localization?
    /// https pages get `Secure` cookies; dev over http must still be able to
    /// persist. Set by DOMRuntime at boot; false in tests and SSG.
    public var _isSecureContext = false
    /// `<html lang>` of the document the server delivered (`.negotiated`), set
    /// by DOMRuntime before mount(). nil off-browser.
    public var _servedLanguage: String?
    /// The locale the initial URL EXPLICITLY named — nil when it carried no
    /// prefix. `signals.locale` cannot answer this: `init` already collapsed
    /// "no prefix" into the app default.
    private let initialURLLocale: LocaleID?
    /// The external path currently displayed — what the browser arrived on until
    /// the first move. Boot and `setLocale` compare against it rather than
    /// re-deriving what "should" be shown: comparing LOCALES was equivalent
    /// under prefixes and is not once a slug can carry the locale (spec §5.1).
    /// Path only, no query — every comparison against it is path-only too.
    ///
    /// Written by `moveURL`, which is every URL move this runtime makes, plus
    /// the two it does not make itself: `init` and `handlePopState`, where the
    /// browser is already showing the URL.
    private var _lastExternalPath: String
    // Routing (spec §7): the runtime owns the current location.
    private var currentPath: String
    private var currentQuery: [String: String]
    /// The raw query string of the current location, kept verbatim so a locale
    /// switch can rewrite the path without re-encoding the query.
    private var _currentSearch: String
    private var lastPageHead: PageHead?
    /// Boot UI the last render pass resolved. SPI: the SSG reads it per
    /// document, folds `.inherit` into the app's, and renders the winner.
    public private(set) var _bootUI: BootUI?
    /// `.whileBooting` authoring findings from the last FULL pass (`BootProbe`),
    /// for the SSG to report. Full passes only: a subtree pass that never
    /// reached the `.whileBooting` wrapper would otherwise blank a real finding.
    public private(set) var _bootFindings: [BootProbe.Finding] = []
    /// The environment the last full pass assembled. Only `_renderBootShell`
    /// reads it — see the comment at its stash in `renderPass`.
    private var _lastEnvironment = EnvironmentValues()
    private var redirectHops = 0
    private var routeMatched = true
    /// Set by a URL move and consumed only after the destination pass commits.
    /// A guard redirect dirties root during the intermediate pass, so the hook
    /// naturally waits for the redirected destination rather than announcing
    /// content that was never presented as a settled route.
    private var navigationCommitPending = false
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
    /// This flush's navigation direction (push/pop, nil for a redirect),
    /// recorded unconditionally by every `navigate`/`handlePopState` arm — even
    /// one that resolves no transition of its own. Without this, an ambient
    /// `withViewTransition(.fade) { navigate(to: "/x") }` on a transition-less
    /// route would arm via `markDirty`'s ambient path (which always passes
    /// `direction: nil`) and the push/pop CSS could never fire. Cleared on the
    /// same paths as `pendingViewTransitionIsNavigation`.
    private var pendingNavigationDirection: NavDirection?
    private var vtInFlight = false
    // Routing transitions (spec §4): refreshed only by a pass that actually saw
    // a Router — a subtree pass builds a fresh context rooted at a component and
    // usually never runs Router._resolve, so an unconditional write would blank
    // the table on the first @State write anywhere.
    private var routerTransitionDefault: PageTransition?
    private var routeTransitions: [(RoutePattern, PageTransition?)] = []
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
    public var _isMounted: Bool { mounted }

    // SSG/hydration SPI (spec §5): stable underscore-public surface for
    // SwiftWUIStatic and SwiftWUIDOM. Not API.
    public var _currentTree: Node? { current }
    public var _pageHead: PageHead? { lastPageHead }
    public var _locationPath: String { currentPath }
    /// SPI: did the last Router pass match a real route? (spec §7)
    public var _routeMatched: Bool { routeMatched }

    /// One throwaway resolve with route collection on. Uses a FRESH store and
    /// listener registry. Collect passes skip StateStore.link (shared Slots
    /// would rebind live boxes — C1), so bodies resolve with struct-initial
    /// values and @Environment defaults. Guards DO run (they run on any
    /// resolve); redirects/pageHead of this pass are discarded.
    public func _collectRoutes() -> [_CollectedRoute] {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        ctx.collectedRoutes = []
        ctx.environment.routeInfo = RouteInfo(path: currentPath, query: currentQuery)
        passCounter += 1; ctx.pass = passCounter
        _ = resolve(rootTag, path: .root, ctx: &ctx)
        return ctx.collectedRoutes ?? []
    }

    /// Renders boot UI against THIS runtime's environment — so `\.locale` and
    /// `LocalizedText` see the document's locale — into a throwaway store and
    /// listener registry.
    ///
    /// `HTMLRenderer.renderWithStylesheet` is deliberately not used: it builds a
    /// signal-less `ResolveContext`, `EnvironmentValues.locale` falls back to
    /// "en", and a catalog-driven overlay would ship English inside every
    /// non-default-locale document.
    ///
    /// The returned CSS is the shell's own registry text and is emitted into a
    /// separate `<style data-swui-boot>` block; it never joins the app's
    /// stylesheet, which the client runtime overwrites at mount.
    public func _renderBootShell(_ content: AnyTag)
        -> (html: String, css: String, findings: [BootProbe.Finding]) {
        // Stale-proof but not seed-proof: called before any full pass has run,
        // `_lastEnvironment` is still the default one and the shell renders in
        // English inside every localized document — the exact failure the
        // per-document render exists to prevent. `_signals` is assigned by every
        // `renderPass`, localization or not, so this has no false positives.
        assert(_lastEnvironment._signals != nil, "boot shell rendered before any full pass")
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        ctx.environment = _lastEnvironment     // seeded by renderPass — carries the locale
        ctx.isBuildRender = true
        let nodes = resolve(_BootTemplate(content: content), path: .root, ctx: &ctx)
        return (HTMLRenderer._render(nodes), ctx.registry.text + "\n" + BootCSS.text,
                BootProbe.findings(root: .root, nodes: nodes, ctx: ctx, what: "boot UI"))
    }

    public init(backend: Backend, container: Backend.HostNode, root: some Tag,
                initialPath: String = "/",
                scheduleMicrotask: @escaping (@escaping () -> Void) -> Void,
                globalStyles: [Rule] = [], themes: [ThemeDefinition] = [], fontFaces: [FontFace] = [],
                localization: Localization? = nil,
                diagnostics: RuntimeDiagnostics? = nil) {
        // Routing never sees the locale segment: it is split off here and
        // re-applied only at the output boundaries (`_externalPath`).
        let (rawPath, query, search) = RouteURL.split(initialPath)
        var internalPath = RouteURL.normalizePath(rawPath)
        var urlLocale: LocaleID?
        if let localization, localization.strategy.usesURLPrefix {
            (internalPath, urlLocale) = LocalePath.internalize(rawPath, supported: localization.supported,
                                                               routes: localization.routePaths)
        }
        _lastExternalPath = RouteURL.normalizePath(rawPath)
        currentPath = internalPath
        currentQuery = query
        _currentSearch = search
        self.initialURLLocale = urlLocale
        applier = TreeApplier(backend: backend, container: container)
        applier.transitionsRef = transitions
        rootTag = AnyTag(root)
        self.scheduleMicrotask = scheduleMicrotask
        self.globalStyles = globalStyles
        self.themes = themes
        self.fontFaces = fontFaces
        self._localization = localization
        self.diagnostics = diagnostics
        if let localization {
            signals._setDefaultLocale(localization.default)
            signals._setLocale(urlLocale ?? localization.default)   // the URL wins over the default
            #if DEBUG
            // The table's table-only checks, at the one install point EVERY app
            // reaches. `swiftwui build` and `swiftwui dev` never construct a
            // StaticSite, so the SSG's two gates leave an SPA-only project with
            // no diagnostic at all — and every one of these fails silently and
            // looks like a working site (spec 2026-08-02 §4).
            //
            // A REPORT, never a trap: this runs at app startup, exactly where
            // `LocalizedRoutes._validate(localization:)` argues a trap would
            // kill the process before the diagnostic prints. Empty table → no
            // output, so a table-free app sees nothing.
            for line in localization.routePaths._validate(localization: localization) {
                print("SwiftWUI: \(line)")
            }
            #endif
        }
        effects._windowHub = windowEvents
        effects._documentVisibilityHub = documentVisibilityEvents
        effects._visualViewportHub = visualViewportEvents
        effects._onDropGuardChange = { [weak self] enabled in
            self?.applier.backend.setDropNavigationGuard(enabled)
        }
        applier.scheduleVisibility = { [weak self] job in
            self?.scheduleMicrotask(job)
        }
        applier.dispatchVisibility = { [weak self] id, value in
            self?.dispatch(id, payload: value)
        }
        effects._onCancelConfiguredVisibility = { [weak self] in
            self?.applier.cancelVisibility()
        }
        effects._onCancelScroll = { [weak self] in self?.scrollRegistry.cancelAll() }
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

    func markDirty(_ id: NodeIdentity, reason: RuntimeRenderReason? = nil) {
        assert(!isRendering, "State write during body evaluation")
        guard mounted else { return }
        dirty.insert(id)
        if diagnostics != nil {
            pendingDiagnosticReasons.append(reason ?? .dependency(id))
        }
        if let t = Transaction._active {
            pendingTransactions[id] = t
            if let g = t._group, !_pendingCompletionGroups.contains(where: { $0 === g }) {
                _pendingCompletionGroups.append(g)
            }
        }
        if let vt = ViewTransitionScope._active { armViewTransition(vt, direction: nil) }
        scheduleRuntimeWork()
    }

    private func scheduleRuntimeWork() {
        guard !scheduled else { return }
        scheduled = true
        scheduleMicrotask { [weak self] in self?.flush() }
    }

    public func mount() {
        guard !mounted && !disposed else { return }
        mounted = true
        let diagnosticStart = diagnostics.map { _ in ContinuousClock.now }
        let passBefore = passCounter
        beginPassBatch()
        defer { endPassBatch() }
        applier.backend.beginEnvironmentObservation(signals.writer)
        _resolveInitialLocale()
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
        emitRenderDiagnostic(kind: .mount, reasons: [.mount], dirtyCount: 0,
                             coveredRootCount: 1, passCount: passCounter - passBefore,
                             started: diagnosticStart)
    }

    /// Disposes the managed render tree while leaving the caller-owned
    /// container in place. Pending microtasks become inert and every runtime
    /// registry releases its handlers, state invalidations and subscriptions.
    public func unmount() {
        guard mounted else { return }
        mounted = false
        disposed = true
        scheduled = false
        dirty.removeAll()
        pendingTransactions.removeAll()
        pendingDiagnosticReasons.removeAll()
        _pendingCompletionGroups.removeAll()
        pendingViewTransition = nil
        pendingViewTransitionIsNavigation = false
        pendingNavigationDirection = nil
        navigationCommitPending = false
        vtInFlight = false

        let disappearCallbacks = effects.reconcile([], under: .root)
        if let mountedRoot = applier.root.children.first {
            applier.unmount(mountedRoot)
        }
        applier.root.children.removeAll()
        current = nil
        for callback in disappearCallbacks { callback() }
        effects._cancelAll()
        scrollRegistry.cancelAll()
        listeners.removeAll()
        animationValues.removeAll()
        transitions.removeAll()
        store.removeAll()
        diagnostics = nil
    }

    /// One data-theme attribute write on the mount container; zero re-render.
    public func setTheme(_ name: String?) {
        guard mounted else { return }
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
                         transition: PageTransition? = nil,
                         ambient: PageTransition? = nil) {
        guard mounted else { return }
        assert(!RouteURL.isExternal(url),
               "navigate() expects an app-internal path, got '\(url)' — use a plain A/Link for external URLs")
        let (rawPath, query, search) = RouteURL.split(url)
        let path = RouteURL.normalizePath(rawPath)
        #if DEBUG
        // Otherwise this is a blank page with no diagnostic: the prefix (or the
        // slug) becomes part of the path, no route matches, and the URL gets it
        // twice.
        if let l10n = _localization, l10n.strategy.usesURLPrefix,
           LocalePath.internalize(path, supported: l10n.supported,
                                  routes: l10n.routePaths).locale != nil {
            print("SwiftWUI: navigate('\(path)') is a URL that already identifies a locale — pass the canonical path, prefixes and slugs are applied on output")
        }
        #endif
        guard path != currentPath || query != currentQuery else { redirectHops = 0; return }  // arriving at the current location ends any redirect chain
        applier.backend.navigationWillBegin(isHistory: false)
        navigationCommitPending = true
        currentPath = path; currentQuery = query; _currentSearch = search
        let externalPath = _externalPath(path)
        let full = search.isEmpty ? externalPath : externalPath + "?" + search
        moveURL(to: full, replace: replace)
        // Precedence (spec §4): explicit call site → destination Route →
        // nearest ambient `.pageTransition`. No Router-default fourth term:
        // "explicitly nil" and "never set" must stay the same state end to
        // end (`.pageTransition(nil)` disables, RouteEnvironment.swift), and a
        // fourth term folded into this optional chain could never tell the
        // two apart, so a subtree wrapped in `.pageTransition(nil)` would
        // still inherit the Router's default. A `Link` rendered INSIDE the
        // Router's own subtree is unaffected: `\.navigate` binds whatever
        // `.pageTransition` is nearest wherever it's read
        // (RouteEnvironment.swift), and that's the Router's own value when
        // nothing closer overrides it. The cost: a `navigate` call made
        // OUTSIDE the Router's subtree (e.g. a sibling nav bar) no longer
        // inherits the Router's default — move `.pageTransition` to a common
        // ancestor if that's needed. `handlePopState` below keeps the old
        // fourth term: it has no call site and therefore no ambient channel,
        // so the Router's default is its only fallback.
        // A redirect (`replace: true`) animates only when asked explicitly.
        let resolved = transition
            ?? (replace ? nil : (routeDeclaredTransition(for: path) ?? ambient))
        armViewTransition(resolved, direction: replace ? nil : .push, isNavigation: true)
        markDirty(.root, reason: .navigation(path: path, isHistory: false))
    }

    /// The single client-side URL move. Everything the prerender wrote about
    /// THIS url — the synthesized canonical, the hreflang set — stops being
    /// true here, and the client can rebuild none of it (both live in
    /// SwiftWUIStatic, and neither `siteURL` nor the locale list ships in the
    /// snapshot). So the prerendered links are dropped, not rewritten: a
    /// missing canonical is a non-signal, a stale one is a wrong signal. NOT
    /// only an in-page hop: `_resolveInitialLocale` calls this during `mount()`,
    /// on the first render of a freshly fetched URL, so a crawler that renders
    /// JS can observe a page whose prerendered canonical and alternates were
    /// dropped. Tracked separately.
    ///
    /// Assumption: locale changes that do NOT move the URL cannot strand a
    /// stale link. Under `.pathPrefix` that case is now live — a slug spelled
    /// like its canonical leaves both locales on one URL — and the links stay
    /// correct because a page's canonical and its alternate set are facts about
    /// the URL, not about the current locale. For `.negotiated`/`.client` it
    /// holds for a second reason: they prerender a locale-free canonical, and
    /// `HreflangLinks` bails unless `usesURLPrefix`. A per-locale canonical for
    /// `.negotiated`, or any future strategy that encodes the locale off the
    /// path, breaks BOTH reasons and has to call this (or drop the links
    /// directly) from `setLocale` as well.
    private func moveURL(to full: String, replace: Bool) {
        // The one place the tracker is kept honest: it is by definition what the
        // address bar now shows, minus the query every comparand also lacks.
        _lastExternalPath = LocalePath._splitSuffix(full).head
        applier.backend.dropPrerenderedHeadLinks()
        if replace { applier.backend.replaceState(path: full) }
        else { applier.backend.pushState(path: full) }
    }

    /// Browser back/forward: the location already changed — no pushState.
    /// A back/forward step across locale prefixes also adopts the URL's locale.
    public func handlePopState(url: String) {
        guard mounted else { return }
        applier.backend.navigationWillBegin(isHistory: true)
        navigationCommitPending = true
        // The URL moved without going through `moveURL` (the browser did it).
        applier.backend.dropPrerenderedHeadLinks()
        let (rawPath, query, search) = RouteURL.split(url)
        _lastExternalPath = RouteURL.normalizePath(rawPath)
        if let localization = _localization, localization.strategy.usesURLPrefix {
            let (internalPath, urlLocale) = LocalePath.internalize(rawPath, supported: localization.supported,
                                                                   routes: localization.routePaths)
            currentPath = internalPath
            // A URL that identifies no locale means the DEFAULT locale: every
            // history entry under this strategy was written by `_externalPath`,
            // so neither a prefix nor a slug being present means the default.
            // Without this, Back from /ru/contact to /about leaves a Russian page
            // at an English URL and every later href carries a /ru the address
            // bar lacks.
            let target = urlLocale ?? localization.default
            if target != signals.locale {
                signals._setLocale(target)
                // Persist, like `setLocale` does. Every entry under this
                // strategy was written by this runtime from a choice or a
                // detection, so the URL is as explicit as the stored value —
                // and if the two are allowed to drift, a reload after Back
                // resurrects the locale the user just navigated away from
                // (boot's detection chain reads this key for unprefixed paths).
                applier.backend.storageWrite(kind: .local, key: "__swiftwui.locale",
                                             value: target.identifier)
                applier.backend.setDocumentLanguage(target.identifier,
                                                    dir: target.isRTL ? "rtl" : nil)
            }
        } else {
            currentPath = RouteURL.normalizePath(rawPath)
        }
        currentQuery = query
        _currentSearch = search
        armViewTransition(routeDeclaredTransition(for: currentPath) ?? routerTransitionDefault,
                          direction: .pop, isNavigation: true)
        markDirty(.root, reason: .navigation(path: currentPath, isHistory: true))
    }

    /// Internal route path → browser-visible path. The single place that
    /// decides what history and `Link` hrefs show; identity-ish (normalize
    /// only) for monolingual apps and prefix-less strategies.
    func _externalPath(_ path: String) -> String {
        guard let localization = _localization, localization.strategy.usesURLPrefix else {
            return RouteURL._normalize(path)
        }
        return LocalePath.externalize(path, locale: signals.locale, default: localization.default,
                                      routes: localization.routePaths)
    }

    /// Runs the detection chain once, before the first pass, and makes the
    /// document agree with the result: `<html lang>`/`dir`, the negotiation
    /// cookie, and — under `.pathPrefix` — the URL itself.
    ///
    /// Deliberately does NOT persist: `__swiftwui.locale` records CHOICES
    /// (`setLocale`, and the history entries those choices wrote), not
    /// detections. Persisting here would freeze the first navigator reading
    /// forever, so a visitor who changes their browser language would keep
    /// getting the old one.
    private func _resolveInitialLocale() {
        guard let localization = _localization else { return }
        // `.pathPrefix(.urlOnly)` decides from the URL alone — don't even read
        // the origin-writable sources it is not allowed to consult.
        let detects = localization.strategy.allowsClientDetection
        let inputs = LocaleResolution.Inputs(
            urlLocale: localization.strategy.usesURLPrefix ? initialURLLocale : nil,
            servedLang: _servedLanguage,
            persisted: detects ? applier.backend.storageRead(kind: .local, key: "__swiftwui.locale") : nil,
            preferred: detects ? applier.backend.preferredLanguages() : [])
        let resolved = LocaleResolution.initial(inputs, localization: localization)
        signals._setLocale(resolved)
        applier.backend.setDocumentLanguage(resolved.identifier, dir: resolved.isRTL ? "rtl" : nil)

        // The edge serves by cookie first, `Accept-Language` second: leave a
        // cookie whenever the client corrected what was served, so the next
        // request arrives in the right locale instead of flipping again.
        if case .negotiated = localization.strategy,
           localization.validated(_servedLanguage) != resolved {
            applier.backend.writeCookie("swiftwui_locale", value: resolved.identifier,
                                        maxAgeDays: 365, secure: _isSecureContext)
        }
        // Task 9's invariant: under `.pathPrefix` every history entry is written
        // by this runtime, so a URL that identifies no locale means the default
        // one. When detection picked something the URL did not name, the URL has
        // to move before the first pass — otherwise `handlePopState` would later
        // read that untouched entry as "default" and fight the rendered page.
        //
        // Compare URL FORMS, not locales. Under prefixes the two were
        // equivalent; with a slug table they are not — adding a slug retires
        // the prefix form, and a locale-only comparison would leave the address
        // bar on the retired URL while every href says the new one. The inverse
        // matters too: a slug identical to its canonical must NOT fire a move,
        // because `moveURL` drops the prerendered canonical and hreflang set.
        if localization.strategy.usesURLPrefix {
            let external = LocalePath.externalize(currentPath, locale: resolved,
                                                  default: localization.default,
                                                  routes: localization.routePaths)
            if external != _lastExternalPath {
                moveURL(to: _currentSearch.isEmpty ? external : external + "?" + _currentSearch,
                        replace: true)
            }
        }
    }

    /// Switches the active locale (spec §3.2). Validation → signal → persistence
    /// → `<html lang>`/`dir` → URL alignment for `.pathPrefix` → full re-render.
    ///
    /// `markDirty(.root)` rather than a targeted invalidation: `Text` resolves
    /// the locale inside `_resolve`, outside the Observation window, so a write
    /// to `signals.locale` would not invalidate the components displaying
    /// translated text.
    public func setLocale(_ locale: LocaleID) {
        guard mounted else { return }
        guard let localization = _localization else { return }
        guard localization.supported.contains(locale) else {
            #if DEBUG
            print("SwiftWUI: setLocale('\(locale)') is not in the declared locales \(localization.supported) — ignored")
            #endif
            return
        }
        guard locale != signals.locale else { return }
        signals._setLocale(locale)
        applier.backend.storageWrite(kind: .local, key: "__swiftwui.locale", value: locale.identifier)
        if case .negotiated = localization.strategy {
            applier.backend.writeCookie("swiftwui_locale", value: locale.identifier,
                                        maxAgeDays: 365, secure: _isSecureContext)
        }
        applier.backend.setDocumentLanguage(locale.identifier,
                                            dir: locale.isRTL ? "rtl" : nil)
        // Same route, new prefix (or new slug): `currentPath` stays locale-free,
        // only the browser-visible URL moves (replace, not push — it is the same
        // page). Gated on the URL FORM changing, for the reason spelled out in
        // `_resolveInitialLocale`: two locales can share one URL once a slug is
        // spelled like its canonical, and `moveURL` is not free — it drops the
        // prerendered head links. With an empty table the gate never fires:
        // exactly one of two distinct locales carries a prefix, so the forms
        // always differ.
        if localization.strategy.usesURLPrefix {
            let external = _externalPath(currentPath)      // reads the signal written above
            if external != _lastExternalPath {
                moveURL(to: _currentSearch.isEmpty ? external : external + "?" + _currentSearch,
                        replace: true)
            }
        }
        markDirty(.root)
    }

    public func flush() {
        guard mounted else { scheduled = false; return }
        if passBatchDepth > 0 { scheduled = false; return }
        // A transition's update callback owns the next pass; a flush that lands
        // in the capture window must ALSO clear `scheduled`, or markDirty's
        // `if !scheduled` gate stops queueing microtasks for good.
        if vtInFlight { scheduled = false; return }
        scheduled = false
        // Not necessarily consumed by the very next flush: one that bounces
        // off the `vtInFlight` guard above returns before reaching this line,
        // so the flag survives a flush that lands inside a transition's
        // capture window. It IS consumed unconditionally by the first flush
        // that gets past that guard — even one that then early-returns on
        // empty dirt below, without rendering anything (Task 9).
        let suppressOnce = _suppressTransitionsOnce
        _suppressTransitionsOnce = false
        guard !dirty.isEmpty else {
            pendingViewTransition = nil
            pendingViewTransitionIsNavigation = false
            scrollRegistry.drain()
            if scrollRegistry.shouldScheduleDrain { scheduleRuntimeWork() }
            return
        }
        let ids = dirty
        dirty.removeAll()
        let diagnosticReasons = pendingDiagnosticReasons
        pendingDiagnosticReasons.removeAll(keepingCapacity: true)
        let drained = pendingTransactions
        pendingTransactions.removeAll()
        let drainedGroups = _pendingCompletionGroups
        _pendingCompletionGroups.removeAll()
        _lastEffectiveTransactions.removeAll()
        // Cleared exactly once per flush, regardless of which path follows: a
        // navigation that armed nothing this flush (blocked by `vtInFlight`,
        // reduced motion, a drag session, or simply resolving no transition)
        // still records a direction in `armViewTransition`, and without this it
        // survives into a later, unrelated flush's ambient arm.
        pendingNavigationDirection = nil

        guard let vt = pendingViewTransition else {
            runPasses(ids, transactionOverrides: drained, groups: drainedGroups,
                      suppressTransitions: suppressOnce, allowScrollDuringViewTransition: false,
                      diagnosticReasons: diagnosticReasons)
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
                           suppressTransitions: true, allowScrollDuringViewTransition: true,
                           diagnosticReasons: diagnosticReasons)
        }
        applier.backend.performViewTransition(vt, update: body)
    }

    /// Pass dispatch + completion-group arming, lifted out of `flush` so a view
    /// transition can run it from inside the backend's update callback.
    private func runPasses(_ ids: Set<NodeIdentity>,
                           transactionOverrides drained: [NodeIdentity: Transaction],
                           groups: [CompletionGroup],
                           suppressTransitions: Bool,
                           allowScrollDuringViewTransition: Bool,
                           diagnosticReasons: [RuntimeRenderReason]) {
        let diagnosticStart = diagnostics.map { _ in ContinuousClock.now }
        let passBefore = passCounter
        var coveredRootCount = 1
        beginPassBatch()
        defer { endPassBatch(allowScrollDuringViewTransition: allowScrollDuringViewTransition) }
        // `_buildMode`: a build reads the tree as settled truth, the same
        // reasoning StaticSite already applies with `_disableViewTransitions`.
        // Its drain pumps after every build-task iteration and a `.staticTask`
        // write marks only its own component dirty, so the tree the SSG
        // serializes would otherwise be assembled partly from scoped passes —
        // and a scoped pass re-resolves the row's own tag, skipping back up
        // through any enclosing wrapper's `_resolve`. Anything that wrapper
        // stamps is then lost unless it also stashes and replays it
        // (`_StyledTag` does; `_WhileBootingTag`'s veil did not, and shipped
        // the real subtree unhidden). Gating here rather than at the SSG call
        // sites closes the divergence class for every build-mode entry point,
        // including ones added later. Client flushes are unaffected.
        if current == nil || _forceFullPasses || effects._buildMode || ids.contains(.root) {
            renderPass(transactionOverrides: drained, suppressTransitionsOnce: suppressTransitions)
        } else {
            var cleanup: [ScopedRegistryCleanup] = []
            let cover = minimalCover(ids)
            coveredRootCount = cover.count
            let oldNodes = findNodes(current!, at: Set(cover))
            for id in cover {
                guard let row = store.retainedRow(at: id) else { continue }   // removed this flush
                guard let pass = subtreePass(id, row, transactionOverrides: drained,
                                             suppressTransitionsOnce: suppressTransitions,
                                             deferRegistryCleanup: true,
                                             indexedOldNode: oldNodes[id]) else {
                    cleanup.removeAll()
                    break
                }
                cleanup.append(pass)
            }
            if !cleanup.isEmpty {
                current = splicing(current!, with: Dictionary(
                    uniqueKeysWithValues: cleanup.map { ($0.root, $0.newNode) }
                ))
                let roots = Set(cleanup.map(\.root))
                let reachable = cleanup.reduce(into: Set<NodeIdentity>()) { $0.formUnion($1.reachable) }
                let liveListeners = cleanup.reduce(into: Set<ListenerID>()) { $0.formUnion($1.listeners) }
                store.sweep(under: roots, reachable: reachable)
                listeners.sweep(under: roots, keep: liveListeners)
                animationValues.sweep(under: roots, reachable: reachable)
                if !effects._buildMode { applier.commitVisibility() }
                sweepTransitions(under: roots)
                #if DEBUG
                warnOnDuplicateTransitionNames()
                #endif
                if styleRegistry.version != flushedStyleVersion {
                    flushedStyleVersion = styleRegistry.version
                    applier.backend.setStylesheet(styleRegistry.text)
                }
                let callbacks = effects.reconcile(cleanup.map {
                    EffectReconcileBatch(root: $0.root, requests: $0.effects)
                })
                _commitViewportEffects()
                for callback in callbacks { callback() }
                for pass in cleanup {
                    commitRouteEffects(pass.context)
                    if pass.context.routerCount > 0 {
                        routerTransitionDefault = pass.context.routerTransitionDefault
                        routeTransitions = pass.context.routeTransitions
                    }
                }
            }
        }
        if navigationCommitPending && dirty.isEmpty {
            navigationCommitPending = false
            applier.backend.navigationDidCommit()
        }
        emitRenderDiagnostic(kind: .update, reasons: diagnosticReasons,
                             dirtyCount: ids.count, coveredRootCount: coveredRootCount,
                             passCount: passCounter - passBefore, started: diagnosticStart)
        // Armed AFTER all of this flush's passes: an empty group (nothing yet
        // registered against it) fires on the next microtask (anim spec §7.4).
        for g in groups { g.arm(schedule: scheduleMicrotask) }
    }

    private func beginPassBatch() { passBatchDepth += 1 }

    private func endPassBatch(allowScrollDuringViewTransition: Bool = false) {
        passBatchDepth -= 1
        guard passBatchDepth == 0 else { return }
        if !dirty.isEmpty {
            scheduleRuntimeWork()
            return
        }
        if !vtInFlight || allowScrollDuringViewTransition {
            scrollRegistry.drain()
        }
        if scrollRegistry.shouldScheduleDrain, !vtInFlight { scheduleRuntimeWork() }
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
        // Recorded unconditionally — even when `t` is nil — so an ambient arm
        // made later in the SAME flush (always `direction: nil`, see below)
        // still gets the right push/pop direction (residual gap from Task 1's
        // review, routed here because this task owns direction wiring).
        if isNavigation { pendingNavigationDirection = direction }
        let effectiveDirection = isNavigation ? direction : (pendingNavigationDirection ?? direction)
        guard let t, !vtInFlight, !_disableViewTransitions,
              !(signals.reduceMotion && t.respectsReducedMotion),
              !signals.dragSession.isActive,
              isNavigation || !pendingViewTransitionIsNavigation else { return }
        // Lazy, not in mount(): an app that never arms a transition must see
        // no `::view-transition` rule at all (no behavior change for apps
        // that don't opt in). Both calls dedupe by text hash, so registering
        // per arm is free.
        styleRegistry.registerRaw(ViewTransitionCSS.baseRuleText)
        t.register(into: styleRegistry)
        pendingViewTransition = t.options(direction: effectiveDirection)
        if isNavigation { pendingViewTransitionIsNavigation = true }
    }

    /// The transition declared by the route that will actually render `path`.
    /// First match wins in declaration order, INCLUDING a nil entry: a route
    /// that declares nothing still consumes the match and must not fall through
    /// to a later pattern's transition.
    private func routeDeclaredTransition(for path: String) -> PageTransition? {
        for (pattern, transition) in routeTransitions where pattern.match(path) != nil {
            return transition
        }
        return nil
    }

    /// Drops ids that are descendants of other dirty ids (spec §2.2).
    func minimalCover(_ ids: Set<NodeIdentity>) -> [NodeIdentity] {
        ids.filter { !$0.hasStrictAncestor(in: ids) }
            .sorted { $0.segments.count < $1.segments.count }
    }

    private func subtreePass(_ id: NodeIdentity, _ row: RetainedComponent,
                             transactionOverrides: [NodeIdentity: Transaction] = [:],
                             suppressTransitionsOnce: Bool = false,
                             deferRegistryCleanup: Bool = false,
                             indexedOldNode: Node? = nil) -> ScopedRegistryCleanup? {
        guard let old = indexedOldNode ?? findNode(current!, at: id),
              let mounted = applier.componentIndex[id] else {
            renderPass(transactionOverrides: transactionOverrides,
                      suppressTransitionsOnce: suppressTransitionsOnce); return nil   // defensive: fall back to full — forward the flush's captures so animated writes don't silently degrade
        }
        var ctx = ResolveContext(store: store, listeners: listeners,
                                 invalidate: { [weak self] in self?.markDirty($0) })
        ctx.isBuildRender = effects._buildMode
        ctx.registry = styleRegistry
        ctx.animationValues = animationValues
        ctx.transitions = transitions
        if !effects._buildMode { ctx.scrollRegistry = scrollRegistry }
        passCounter += 1; ctx.pass = passCounter
        // Snapshot is never stale for routeInfo: navigation always marks .root (full pass),
        // which re-retains every row's environment.
        ctx.environment = row.environment
        // Restore the caller's Styled scope. For a plain component this is a
        // no-op (its own boundary resets scope), but `ModifiedTag` preserves it —
        // without re-seeding, the scope marker would drop from the modifier body
        // and wrapped content on this pass (scoped ≡ full invariant, spec §6/§11).
        ctx.scopeClass = row.scopeClass
        ctx.visibilityRoots = row.visibilityRoots
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

        if !deferRegistryCleanup {
            store.sweep(under: id, reachable: ctx.reachable)
            listeners.sweep(under: id, keep: ctx.liveListeners)
            animationValues.sweep(under: id, reachable: ctx.reachable)
        }

        let patches = Reconciler().diff(old: old, new: new)
        applier.animationPass = AnimationPassContext(transactions: ctx.effectiveTransactions,
                                                      reduceMotion: signals.reduceMotion,
                                                      suppressTransitions: suppressTransitionsOnce,
                                                      defaultTransaction: ctx.transaction)
        applier.apply(patches, to: mounted)          // top-level per pass → shadow anchors safe
        applier.animationPass = nil
        if !deferRegistryCleanup {
            current = splicing(current!, at: id, with: new)
        }
        scrollRegistry.commit(ctx.scrollReaders, under: id)
        if !effects._buildMode && !deferRegistryCleanup {
            applier.commitVisibility()
        }
        #if DEBUG
        if !deferRegistryCleanup { warnOnDuplicateTransitionNames() }
        #endif
        // Post-commit (see renderPass): survive an entry whose element is
        // still live even though the registering wrapper is above this pass root.
        if !deferRegistryCleanup {
            sweepTransitions(under: [id])
        }

        if !deferRegistryCleanup && styleRegistry.version != flushedStyleVersion {
            flushedStyleVersion = styleRegistry.version
            applier.backend.setStylesheet(styleRegistry.text)
        }

        if !deferRegistryCleanup {
            let callbacks = effects.reconcile(ctx.effects, under: id)
            _commitViewportEffects()
            for cb in callbacks { cb() }
            commitRouteEffects(ctx)
            if ctx.routerCount > 0 {
                routerTransitionDefault = ctx.routerTransitionDefault
                routeTransitions = ctx.routeTransitions
            }
        }
        return ScopedRegistryCleanup(root: id, newNode: new, reachable: ctx.reachable,
                                     listeners: ctx.liveListeners,
                                     effects: ctx.effects, context: ctx)
    }

    /// Applies Router by-products after a pass (spec §5, §9): head writes when
    /// the snapshot changed, then at most one redirect hop (capped at 10).
    private func commitRouteEffects(_ ctx: ResolveContext) {
        // Head baseline (spec §5.1). A pass where the Router ran may have
        // CHANGED route, so the baseline must come from this pass — folding a
        // patch over `lastPageHead` would ship the previous page's title on a
        // route whose content conforms to no `Page`.
        let empty = PageHead(title: "", meta: [], links: [])
        if ctx.routerCount > 0 {
            routeMatched = ctx.routeMatched
            // Same guard as `routeMatched`: a scoped pass that never reached the
            // Router must not blank the matched page's declaration.
            _bootUI = ctx.bootUI
        }
        let baseline: PageHead? = ctx.routerCount > 0 ? ctx.pageHead : lastPageHead
        var head: PageHead? = baseline
        if let patch = ctx.pageHeadPatch {
            head = patch.folded(over: baseline ?? empty)
        }
        if let head, head != lastPageHead {
            lastPageHead = head
            applier.backend.setTitle(head.title)
            applier.backend.setMetaTags(head.meta)
            applier.backend.setLinks(head.links)
            applier.backend.setStructuredData(head.structuredData)
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
        ctx.isBuildRender = effects._buildMode
        ctx.registry = styleRegistry
        ctx.animationValues = animationValues
        ctx.transitions = transitions
        if !effects._buildMode { ctx.scrollRegistry = scrollRegistry }
        ctx.transactionOverrides = transactionOverrides   // carrier (anim spec §4): applied at each component boundary
        passCounter += 1; ctx.pass = passCounter
        ctx.environment.setTheme = { [weak self] name in self?.setTheme(name) }
        ctx.environment._signals = signals
        ctx.environment._mediaStore = mediaStore
        ctx.environment._storageStore = storage
        ctx.environment._webSessionOptional = _webSession
        ctx.environment.routeInfo = RouteInfo(path: currentPath, query: currentQuery)
        ctx.environment.navigate = NavigateAction { [weak self] path, replace, transition, ambient in
            self?.navigate(to: path, replace: replace, transition: transition, ambient: ambient)
        }
        ctx.environment.back = { [weak self] in self?.applier.backend.historyBack() }
        ctx.environment.reloadToUpdate = { [weak self] in self?.applier.backend.reloadForUpdate() }
        ctx.environment.setLocale = SetLocaleAction { [weak self] locale in self?.setLocale(locale) }
        ctx.environment._externalizePath = { [weak self] path in self?._externalPath(path) ?? path }
        ctx.environment.availableLocales = _localization?.supported ?? []
        // The boot shell renders outside a pass but must see the same
        // environment — above all the same locale, or a catalog-driven overlay
        // ships the default language into every localized document.
        _lastEnvironment = ctx.environment
        isRendering = true
        let children = coalesceText(resolve(rootTag, path: .root, ctx: &ctx))
        isRendering = false
        _bootFindings = ctx.bootFindings
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
        scrollRegistry.commit(ctx.scrollReaders, under: .root)
        if !effects._buildMode {
            applier.commitVisibility()
        }
        #if DEBUG
        warnOnDuplicateTransitionNames()
        #endif
        // Transition sweep runs post-commit: an entry survives while its
        // element is still in the tree even if this pass didn't re-run its
        // registering wrapper (wrapper above a subtree pass root).
        sweepTransitions(under: [.root])

        if styleRegistry.version != flushedStyleVersion {
            flushedStyleVersion = styleRegistry.version
            applier.backend.setStylesheet(styleRegistry.text)
        }

        let callbacks = effects.reconcile(ctx.effects, under: .root)
        _commitViewportEffects()
        for cb in callbacks { cb() }
        commitRouteEffects(ctx)
        if ctx.routerCount > 0 {
            routerTransitionDefault = ctx.routerTransitionDefault
            routeTransitions = ctx.routeTransitions
        }
    }

    private func _commitViewportEffects() {
        guard !effects._buildMode else { return }
        documentVisibilityEvents.commit()
        visualViewportEvents.commit()
    }

    /// Transition existence used to run a recursive `findNode` for every live
    /// registration. Indexing the candidates in one traversal keeps a large
    /// transition-bearing sibling batch linear while preserving post-commit
    /// sweep semantics.
    private func sweepTransitions(under roots: Set<NodeIdentity>) {
        guard !transitions.isEmpty, let current else {
            transitions.sweep(under: roots, stillExists: { _ in false })
            return
        }
        let existing = findNodes(current, at: Set(transitions.byIdentity.keys))
        transitions.sweep(under: roots, stillExists: { existing[$0] != nil })
    }

    private func emitRenderDiagnostic(kind: RuntimeRenderDiagnostic.Kind,
                                      reasons: [RuntimeRenderReason],
                                      dirtyCount: Int, coveredRootCount: Int,
                                      passCount: Int,
                                      started: ContinuousClock.Instant?) {
        guard let diagnostics, let started else { return }
        var uniqueReasons: [RuntimeRenderReason] = []
        for reason in reasons where !uniqueReasons.contains(reason) { uniqueReasons.append(reason) }
        let lifetimes = RuntimeLifetimeCounts(
            stateRows: store.rowCount,
            retainedComponents: store.retainedCount,
            listeners: listeners.count,
            effects: effects.activeCount,
            animationValues: animationValues.count,
            transitions: transitions.byIdentity.count,
            mountedComponents: applier.componentIndex.count
        )
        let tree = diagnostics.includeTreeStatistics ? current.map(runtimeTreeStatistics) : nil
        let componentTree = diagnostics.includeComponentTree ? current.map(runtimeComponentTree) : nil
        diagnostics.emit(.render(RuntimeRenderDiagnostic(
            kind: kind, reasons: uniqueReasons, dirtyIdentityCount: dirtyCount,
            coveredRootCount: coveredRootCount, passCount: passCount,
            duration: started.duration(to: ContinuousClock.now), lifetimes: lifetimes,
            tree: tree, componentTree: componentTree
        )))
    }

    public func _deferViewportEffectsUntilAdoption() {
        documentVisibilityEvents.deferUntilAdoption()
        visualViewportEvents.deferUntilAdoption()
    }

    public func _deferScrollUntilAdoption() { scrollRegistry.deferUntilAdoption() }

    public func _acceptScrollAdoption() { scrollRegistry.acceptAdoption() }

    public func _acceptViewportEffectsAdoption() {
        documentVisibilityEvents.acceptAdoption()
        visualViewportEvents.acceptAdoption()
    }

    #if DEBUG
    /// Two RENDERED elements sharing a `view-transition-name` make the browser
    /// reject `ready` and skip the whole transition, with no app-visible error.
    /// A warning, never an assert: only rendered elements count, and a mobile
    /// nav plus a desktop nav both named `logo` with one hidden by a media query
    /// is legal, common, and invisible to a tree walk.
    private func warnOnDuplicateTransitionNames() {
        guard let tree = current else { return }
        var seen: Set<String> = []
        func walk(_ node: Node) {
            switch node {
            case .element(let e):
                if let name = e.style.entries.first(where: { $0.property == "view-transition-name" })?.value,
                   !seen.insert(name).inserted {
                    print("SwiftWUI: duplicate view-transition-name '\(name)' — the browser will skip the transition")
                }
                for child in e.children { walk(child) }
            case .component(let c):
                for child in c.children { walk(child) }
            case .text:
                break
            }
        }
        walk(tree)
    }
    #endif
}
