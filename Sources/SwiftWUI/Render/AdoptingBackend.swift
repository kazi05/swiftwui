/// Hydration backend (spec §8, D2/D6): while adoption is active,
/// createElement/createTextNode return the NEXT node of a pre-order walk over
/// `container`'s existing subtree instead of creating; insert() verifies the
/// adopted child already sits under the expected parent. TreeApplier's mount
/// emits creates in exactly pre-order (parent created+inserted before its
/// children), so a T8-conforming document adopts 1:1.
///
/// First divergence sets `failed` and flips to passthrough creation so the
/// mount completes structurally; the CALLER must then discard everything and
/// cold-mount (clear container + fresh Runtime) — never repair in place.
///
/// Write calls (setAttribute/setProperty/setEventListener/setText) always
/// delegate: values are byte-identical to the prerender (T8), so they're
/// idempotent, and listener attachment is precisely what hydration must do.
@MainActor
public final class AdoptingBackend<Base: RendererBackend>: RendererBackend
where Base.HostNode: AnyObject {
    public typealias HostNode = Base.HostNode
    public let base: Base
    public private(set) var failed = false
    private var active = true
    /// Pre-order stream over the container's ORIGINAL subtree (container excluded).
    private var stream: [HostNode] = []
    private var cursor = 0
    /// ObjectIdentifier(child wrapper) → ObjectIdentifier(parent wrapper).
    /// Safe even for JSObject: we only ever key the wrapper instances WE
    /// handed out (stream entries + container) — never re-read wrappers.
    private var parentOf: [ObjectIdentifier: ObjectIdentifier] = [:]
    private let containerID: ObjectIdentifier
    /// D6 wants debug-loud mismatches, but the fallback path itself must be
    /// testable in debug — tests that exercise deliberate mismatches set false.
    public var _assertOnMismatch = true

    public init(base: Base, container: HostNode) {
        self.base = base
        containerID = ObjectIdentifier(container)
        buildStream(of: container)
    }
    private func buildStream(of node: HostNode) {
        for i in 0..<base.childCount(of: node) {
            let c = base.child(of: node, at: i)
            stream.append(c)
            parentOf[ObjectIdentifier(c)] = ObjectIdentifier(node)
            // textarea's serialized value is child TEXT in HTML but a `value`
            // PROPERTY in the VDOM — skip its subtree (spec §8 / textarea rule).
            if base.tagName(of: c) == "textarea" { continue }
            buildStream(of: c)
        }
    }

    private func fail() {
        if !failed {
            failed = true
            if _assertOnMismatch {
                assertionFailure("SwiftWUI hydration mismatch at stream index \(cursor)/\(stream.count)")
            }
        }
        active = false
    }
    private func nextAdopted(expectTag: String?) -> HostNode? {
        guard cursor < stream.count else { fail(); return nil }
        let candidate = stream[cursor]
        let actual = base.tagName(of: candidate)
        // Tag names compare lowercased: DOM tagName is uppercase, our
        // serializer emits lowercase; MockBackend stores lowercase.
        guard actual?.lowercased() == expectTag?.lowercased() else { fail(); return nil }
        cursor += 1
        return candidate
    }

    /// True when every prerendered node was claimed and nothing diverged.
    /// Always deactivates adoption — subsequent calls create for real.
    public func finishAdoption() -> Bool {
        let ok = !failed && cursor == stream.count
        if !ok && !failed { fail() }     // leftover nodes = mismatch (spec §8)
        active = false
        return ok
    }

    // MARK: creates (adopt while active)
    public func createElement(_ tag: String) -> HostNode {
        if active, let n = nextAdopted(expectTag: tag) { return n }
        return base.createElement(tag)
    }
    public func createTextNode(_ text: String) -> HostNode {
        // No byte comparison of text (browser entity/whitespace view); the
        // mount pass's setText below overwrites with the canonical value.
        if active, let n = nextAdopted(expectTag: nil) { return n }
        return base.createTextNode(text)
    }
    public func insert(_ child: HostNode, into parent: HostNode, before anchor: HostNode?) {
        if active {
            // Adopted child must already sit under this parent; adopted parent
            // wrappers and the container are the only legal parents mid-adoption.
            if parentOf[ObjectIdentifier(child)] == ObjectIdentifier(parent) { return }  // no-op: already in place
            fail()
            // fall through: base.insert makes the (doomed) tree structurally sound
        }
        base.insert(child, into: parent, before: anchor)
    }

    // MARK: passthrough
    public func setText(_ node: HostNode, _ text: String) { base.setText(node, text) }
    public func setAttribute(_ node: HostNode, name: String, value: String) { base.setAttribute(node, name: name, value: value) }
    public func removeAttribute(_ node: HostNode, name: String) { base.removeAttribute(node, name: name) }
    public func setProperty(_ node: HostNode, name: String, value: PropertyValue) { base.setProperty(node, name: name, value: value) }
    public func setEventListener(_ node: HostNode, event: String, id: ListenerID) { base.setEventListener(node, event: event, id: id) }
    public func removeEventListener(_ node: HostNode, event: String) { base.removeEventListener(node, event: event) }
    public func remove(_ child: HostNode, from parent: HostNode) { base.remove(child, from: parent) }
    public func setStylesheet(_ text: String) { base.setStylesheet(text) }
    public func pushState(path: String) { base.pushState(path: path) }
    public func replaceState(path: String) { base.replaceState(path: path) }
    public func historyBack() { base.historyBack() }
    public func setTitle(_ title: String) { base.setTitle(title) }
    public func setMetaTags(_ tags: [MetaTag]) { base.setMetaTags(tags) }
    public func childCount(of node: HostNode) -> Int { base.childCount(of: node) }
    public func child(of node: HostNode, at index: Int) -> HostNode { base.child(of: node, at: index) }
    public func tagName(of node: HostNode) -> String? { base.tagName(of: node) }
    public func textContent(of node: HostNode) -> String { base.textContent(of: node) }
}
