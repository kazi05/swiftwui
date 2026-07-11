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
    func setProperty(_ node: HostNode, name: String, value: PropertyValue)
    func setEventListener(_ node: HostNode, event: String, id: ListenerID)
    func removeEventListener(_ node: HostNode, event: String)
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
}

extension RendererBackend {
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {}
}
