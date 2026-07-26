/// Host primitives a live renderer provides (spec §8.1). Deliberately dumb:
/// no diffing, no bookkeeping, no handler storage.
@MainActor
public protocol RendererBackend: AnyObject {
    associatedtype HostNode
    func createElement(_ tag: String) -> HostNode
    func createTextNode(_ text: String) -> HostNode
    func setText(_ node: HostNode, _ text: String)
    func setAttribute(_ node: HostNode, name: String, value: String)
    func removeAttribute(_ node: HostNode, name: String)
    // MARK: Typed inline style (spec 2026-07-13, animations)
    func setStyleProperty(_ node: HostNode, name: String, value: String)
    func removeStyleProperty(_ node: HostNode, name: String)
    func setProperty(_ node: HostNode, name: String, value: PropertyValue)
    func setEventListener(_ node: HostNode, event: String, id: ListenerID)
    func removeEventListener(_ node: HostNode, event: String)

    // MARK: Element observers (spec 2026-07-12)
    func observe(_ node: HostNode, kind: ObserverKind, id: ListenerID)
    func unobserve(_ node: HostNode, kind: ObserverKind)

    func insert(_ child: HostNode, into parent: HostNode, before anchor: HostNode?)
    func remove(_ child: HostNode, from parent: HostNode)
    /// Replace the full text of the document's single managed stylesheet.
    /// Called at most once per flush, only when the rule registry grew.
    func setStylesheet(_ text: String)

    // MARK: Routing (phase 4, spec §3)
    /// History API. Backends without history (Mock) just record.
    func pushState(path: String)
    func replaceState(path: String)
    func historyBack()
    /// document.title.
    func setTitle(_ title: String)
    /// Replaces the document's MANAGED meta set (marked data-swiftwui);
    /// hand-written <meta> in the host HTML is never touched.
    func setMetaTags(_ tags: [MetaTag])
    /// Replaces the document's MANAGED link set (marked data-swiftwui);
    /// hand-written <link> in the host HTML is never touched.
    func setLinks(_ links: [LinkTag])

    // MARK: Hydration read API (phase 5, spec §10)
    /// Minimal DOM reads for the adopting walk. Text nodes count as children.
    func childCount(of node: HostNode) -> Int
    func child(of node: HostNode, at index: Int) -> HostNode
    /// Lowercased element tag name; nil for text nodes.
    func tagName(of node: HostNode) -> String?

    // MARK: Environment signals (phase 8a)
    /// Called once by Runtime.mount() BEFORE the first render pass. Backends
    /// read initial values synchronously, then attach change listeners. Every
    /// listener closure must be retained by the backend for its lifetime.
    func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer)

    // MARK: Web storage (phase 8a)
    func storageRead(kind: StorageKind, key: String) -> String?
    /// nil value = remove the key.
    func storageWrite(kind: StorageKind, key: String, value: String?)
    /// Cross-document `storage` events (localStorage only by platform design).
    /// The backend retains the callback for its lifetime.
    func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void)

    // MARK: PWA (spec 2026-07-12)
    /// Activate a waiting service worker and reload the page. No-op default
    /// for non-browser backends.
    func reloadForUpdate()

    // MARK: Window-level events (spec 2026-07-12)
    /// Called once, lazily, on the first onWindowScroll/onWindowResize
    /// subscription ever (page lifetime — like environment observation).
    func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void)

    // MARK: Drop-navigation guard (spec 2026-07-16, DnD task 7)
    /// Enabled while `.preventsAccidentalDropNavigation()` is mounted anywhere
    /// in the tree; toggled only on 0↔some subscriber-count transitions.
    func setDropNavigationGuard(_ enabled: Bool)

    // MARK: Reactive media matching (spec 2026-07-14)
    /// Called lazily the first time a component reads `matches(condition)`. The
    /// backend evaluates the condition now (synchronous initial value), retains a
    /// change listener calling `onChange` on every future flip, and returns the
    /// current match. Non-browser backends return `false` and never call onChange.
    func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool

    // MARK: Animations (spec 2026-07-13, task 6)
    /// Drives a single property's animation. `onSettle` fires exactly once
    /// (`.finished`, `.cancelled`, or `.forced`). No-op default returns nil.
    @discardableResult
    func animate(_ node: HostNode, request: AnimationRequest,
                 onSettle: @escaping (AnimationSettle) -> Void) -> AnimationToken?
    /// Settles with `.cancelled` and snaps to the current presentation value.
    func cancelAnimation(_ token: AnimationToken)
    /// Settles with `.forced` and jumps straight to the end value.
    func finishAnimation(_ token: AnimationToken)

    // MARK: View transitions (spec 2026-07-26)
    /// Runs `update` inside a platform view transition when one is available.
    /// Backends without support MUST call `update()` synchronously before
    /// returning; backends with support call it from the platform's update
    /// callback. The CALLER makes the call idempotent and self-healing (spec
    /// §3.2), so dropping or deferring `update` cannot brick the renderer.
    func performViewTransition(_ options: ViewTransitionOptions, update: @escaping () -> Void)
}

extension RendererBackend {
    public func observe(_ node: HostNode, kind: ObserverKind, id: ListenerID) {}
    public func unobserve(_ node: HostNode, kind: ObserverKind) {}
    public func setStyleProperty(_ node: HostNode, name: String, value: String) {}
    public func removeStyleProperty(_ node: HostNode, name: String) {}
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {}
    public func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool { false }
    public func storageRead(kind: StorageKind, key: String) -> String? { nil }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {}
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {}
    public func reloadForUpdate() {}
    public func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void) {}
    public func setDropNavigationGuard(_ enabled: Bool) {}
    @discardableResult
    public func animate(_ node: HostNode, request: AnimationRequest,
                         onSettle: @escaping (AnimationSettle) -> Void) -> AnimationToken? { nil }
    public func cancelAnimation(_ token: AnimationToken) {}
    public func finishAnimation(_ token: AnimationToken) {}
    public func performViewTransition(_ options: ViewTransitionOptions, update: @escaping () -> Void) {
        update()
    }
}
