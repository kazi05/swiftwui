public final class MockNode {
    public var tag: String?
    public var text: String?
    public var attrs: [String: String] = [:]
    public var props: [String: PropertyValue] = [:]
    public var events: [String: ListenerID] = [:]
    public var observers: [ObserverKind: ListenerID] = [:]
    public var children: [MockNode] = []
    public weak var parent: MockNode?
    public init() {}
}

/// Native reference backend: counts every primitive call (churn assertions)
/// and serializes to HTML for the cross-check property (spec §10.4).
@MainActor
public final class MockBackend: RendererBackend {
    public typealias HostNode = MockNode
    public let container = MockNode()
    public private(set) var counts: [String: Int] = [:]
    public init() {}
    private func bump(_ k: String) { counts[k, default: 0] += 1 }

    public func createElement(_ tag: String) -> MockNode {
        bump("createElement"); let n = MockNode(); n.tag = tag; return n
    }
    public func createTextNode(_ text: String) -> MockNode {
        bump("createTextNode"); let n = MockNode(); n.text = text; return n
    }
    public func setText(_ node: MockNode, _ text: String) { bump("setText"); node.text = text }
    public func setAttribute(_ node: MockNode, name: String, value: String) {
        bump("setAttribute"); node.attrs[name] = value
    }
    public func removeAttribute(_ node: MockNode, name: String) {
        bump("removeAttribute"); node.attrs[name] = nil
    }
    public func setProperty(_ node: MockNode, name: String, value: PropertyValue) {
        bump("setProperty"); node.props[name] = value
    }
    public func setEventListener(_ node: MockNode, event: String, id: ListenerID) {
        bump("setEventListener"); node.events[event] = id
    }
    public func removeEventListener(_ node: MockNode, event: String) {
        bump("removeEventListener"); node.events[event] = nil
    }
    public func observe(_ node: MockNode, kind: ObserverKind, id: ListenerID) {
        bump("observe"); node.observers[kind] = id
    }
    public func unobserve(_ node: MockNode, kind: ObserverKind) {
        bump("unobserve"); node.observers[kind] = nil
    }
    public func insert(_ child: MockNode, into parent: MockNode, before anchor: MockNode?) {
        bump("insert")
        child.parent?.children.removeAll { $0 === child }          // DOM move semantics
        if let anchor, let i = parent.children.firstIndex(where: { $0 === anchor }) {
            parent.children.insert(child, at: i)
        } else {
            parent.children.append(child)
        }
        child.parent = parent
    }
    public func remove(_ child: MockNode, from parent: MockNode) {
        bump("remove")
        parent.children.removeAll { $0 === child }
        child.parent = nil
    }
    public private(set) var stylesheetText: String?
    public func setStylesheet(_ text: String) { bump("setStylesheet"); stylesheetText = text }

    public private(set) var historyStack: [String] = []
    public private(set) var replacedStates: [String] = []
    public private(set) var backCount = 0
    public private(set) var title: String?
    public private(set) var metaTags: [MetaTag] = []
    public private(set) var links: [LinkTag] = []
    public func pushState(path: String) { bump("pushState"); historyStack.append(path) }
    public func replaceState(path: String) { bump("replaceState"); replacedStates.append(path) }
    public func historyBack() { bump("historyBack"); backCount += 1 }
    public func setTitle(_ title: String) { bump("setTitle"); self.title = title }
    public func setMetaTags(_ tags: [MetaTag]) { bump("setMetaTags"); metaTags = tags }
    public func setLinks(_ links: [LinkTag]) { bump("setLinks"); self.links = links }

    public func childCount(of node: MockNode) -> Int { node.children.count }
    public func child(of node: MockNode, at index: Int) -> MockNode { node.children[index] }
    public func tagName(of node: MockNode) -> String? { node.tag }

    public private(set) var environmentWriter: EnvironmentSignals.Writer?
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {
        bump("beginEnvironmentObservation")
        environmentWriter = writer
    }

    public private(set) var reloadForUpdateCount = 0
    public func reloadForUpdate() { bump("reloadForUpdate"); reloadForUpdateCount += 1 }

    public var localStorage: [String: String] = [:]        // pre-seedable by tests
    public var sessionStorage: [String: String] = [:]
    public private(set) var storageObserver: ((StorageKind, String, String?) -> Void)?
    public func storageRead(kind: StorageKind, key: String) -> String? {
        bump("storageRead")
        return kind == .local ? localStorage[key] : sessionStorage[key]
    }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {
        bump("storageWrite")
        switch kind {
        case .local:   localStorage[key] = value
        case .session: sessionStorage[key] = value
        }
    }
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {
        bump("beginStorageObservation")
        storageObserver = onExternalChange
    }
    /// Test helper: simulate another tab's localStorage write (storage event).
    public func simulateExternalStorageChange(kind: StorageKind, key: String, value: String?) {
        switch kind {
        case .local:   localStorage[key] = value
        case .session: sessionStorage[key] = value
        }
        storageObserver?(kind, key, value)
    }

    public private(set) var windowEventSink: ((WindowEventKind, Any) -> Void)?
    public func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void) {
        bump("beginWindowEventObservation"); windowEventSink = sink
    }

    /// Same rules as HTMLRenderer: escaped text/attrs, sorted attrs, void set.
    public func serializeHTML(_ node: MockNode? = nil) -> String {
        let n = node ?? container
        if let text = n.text { return HTMLEscaping.text(text) }
        guard let tag = n.tag else {                               // container root
            return n.children.map { serializeHTML($0) }.joined()
        }
        var out = "<" + tag
        for name in n.attrs.keys.sorted() {
            let value = n.attrs[name]!
            out += value.isEmpty ? " " + name : " \(name)=\"\(HTMLEscaping.text(value))\""
        }
        var textareaValue: String? = nil
        for name in n.props.keys.sorted() {
            if tag == "textarea", name == "value",
               case .string(let s) = n.props[name]! {
                textareaValue = s                          // real HTML: child text, not attr
                continue
            }
            switch n.props[name]! {
            case .string(let s): out += " \(name)=\"\(HTMLEscaping.text(s))\""
            case .bool(true):    out += " " + name
            case .bool(false):   break
            }
        }
        out += ">"
        if HTMLRenderer.voidElements.contains(tag) { return out }
        return out + (textareaValue.map { HTMLEscaping.text($0) } ?? "")
            + n.children.map { serializeHTML($0) }.joined() + "</" + tag + ">"
    }
}
