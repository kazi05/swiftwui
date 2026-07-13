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
/// Trailing leftover nodes at `finishAdoption` (stream fully consumed in
/// order, but extra nodes remain after the app's) are tolerated, not a
/// mismatch, ONLY when container-level: browser extensions (DeepL, Grammarly,
/// LastPass) append elements to `<body>`, and legacy pre-phase-6 output left
/// whitespace reparented there too. Leftovers deeper in the tree (e.g. a
/// stale trailing child under a still-recognized element) are app content
/// from a version-skewed cache, not foreign injections — they still fail
/// (D6 cold render). A mid-stream divergence also still fails — alignment
/// breaks at the divergent node, long before finish.
///
/// Write calls (setAttribute/setProperty/setEventListener/setText) always
/// delegate: values are byte-identical to the prerender (T8), so they're
/// idempotent, and listener attachment is precisely what hydration must do.
///
/// Common mismatch causes (browser parser normalization, phase-6): `<table>`
/// without an explicit `Tbody` (the parser auto-inserts one); text nodes split
/// across component boundaries; children inside `Iframe` (the parser drops
/// them).
///
/// Public API by decision (phase-6): part of the SSG/backend integration surface,
/// not an underscored SPI. Members prefixed `_` remain SPI.
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
    /// ObjectIdentifier of the container itself — trailing-leftover tolerance
    /// (finishAdoption) is container-level only, this is the comparison target.
    private let containerID: ObjectIdentifier
    /// D6 wants debug-loud mismatches, but the fallback path itself must be
    /// testable in debug — tests that exercise deliberate mismatches set false.
    public var _assertOnMismatch = true

    public init(base: Base, container: HostNode) {
        self.base = base
        self.containerID = ObjectIdentifier(container)
        buildStream(of: container)
        // An empty container is a cold mount, not a mismatch — Task 13's
        // fallback re-wraps a cleared container and must not trap.
        active = !stream.isEmpty
    }
    private func buildStream(of node: HostNode) {
        for i in 0..<base.childCount(of: node) {
            let c = base.child(of: node, at: i)
            stream.append(c)
            parentOf[ObjectIdentifier(c)] = ObjectIdentifier(node)
            // textarea's serialized value is child TEXT in HTML but a `value`
            // PROPERTY in the VDOM — skip its subtree (spec §8 / textarea rule).
            if base.tagName(of: c)?.lowercased() == "textarea" { continue }
            buildStream(of: c)
        }
    }

    /// Non-trapping diagnostic (always printed) plus a debug-only assert
    /// (`_assertOnMismatch`) — the fallback path itself must stay testable in
    /// debug builds, so the trap is opt-out, not unconditional.
    private func fail(expected: String = "?", found: String = "?") {
        guard !failed else { return }
        failed = true
        let msg = """
        SwiftWUI hydration mismatch at stream index \(cursor)/\(stream.count): \
        expected <\(expected)>, found <\(found)>. Common causes (browser parser \
        normalization): <table> without explicit Tbody (parser auto-inserts tbody); \
        text nodes split across component boundaries; children inside Iframe \
        (parser drops them). Falling back to a cold render.
        """
        print("[SwiftWUI] " + msg)                        // non-trapping diagnostic, all builds
        if _assertOnMismatch { assertionFailure(msg) }    // debug trap preserved
        active = false
    }
    private func nextAdopted(expectTag: String?) -> HostNode? {
        let expectedDesc = expectTag ?? "text node"
        guard cursor < stream.count else { fail(expected: expectedDesc, found: "end of stream"); return nil }
        let candidate = stream[cursor]
        let actual = base.tagName(of: candidate)
        // Tag names compare lowercased: DOM tagName is uppercase, our
        // serializer emits lowercase; MockBackend stores lowercase.
        guard actual?.lowercased() == expectTag?.lowercased() else {
            fail(expected: expectedDesc, found: actual ?? "text node")
            return nil
        }
        cursor += 1
        return candidate
    }

    /// True when the app tree adopted fully and nothing diverged mid-stream.
    /// Leftover TRAILING nodes (cursor < stream.count with no prior failure)
    /// are tolerated ONLY when every leftover's recorded parent is the
    /// container itself — see class doc. Leftovers deeper in the tree (e.g. a
    /// stale prerendered `<li>` child from a version-skewed cache) are app
    /// content, not foreign injections, and still fail → cold render (D6).
    /// Always deactivates adoption — subsequent calls create for real.
    public func finishAdoption() -> Bool {
        if !failed && cursor < stream.count {
            let allContainerLevel = stream[cursor...].allSatisfy { parentOf[ObjectIdentifier($0)] == containerID }
            if allContainerLevel {
                print("[SwiftWUI] hydration: \(stream.count - cursor) unmanaged trailing node(s) left in container (e.g. browser-extension injections) — tolerated")
            } else {
                fail(expected: "end of stream", found: "leftover nodes")
            }
        }
        let ok = !failed
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
        // adopted node's text is not trusted verbatim — self-heal below.
        if active, let n = nextAdopted(expectTag: nil) {
            // TreeApplier.mount never setTexts fresh text nodes — self-heal
            // here (idempotent under T8, corrective otherwise).
            base.setText(n, text)
            return n
        }
        return base.createTextNode(text)
    }
    public func insert(_ child: HostNode, into parent: HostNode, before anchor: HostNode?) {
        if active {
            // Adopted child must already sit under this parent; adopted parent
            // wrappers and the container are the only legal parents mid-adoption.
            if parentOf[ObjectIdentifier(child)] == ObjectIdentifier(parent) { return }  // no-op: already in place
            fail(expected: "adopted parent", found: "wrong-parent insert")
            // fall through: base.insert makes the (doomed) tree structurally sound
        }
        base.insert(child, into: parent, before: anchor)
    }

    // MARK: passthrough
    public func setText(_ node: HostNode, _ text: String) { base.setText(node, text) }
    public func setAttribute(_ node: HostNode, name: String, value: String) { base.setAttribute(node, name: name, value: value) }
    public func removeAttribute(_ node: HostNode, name: String) { base.removeAttribute(node, name: name) }
    public func setStyleProperty(_ node: HostNode, name: String, value: String) { base.setStyleProperty(node, name: name, value: value) }
    public func removeStyleProperty(_ node: HostNode, name: String) { base.removeStyleProperty(node, name: name) }
    public func setProperty(_ node: HostNode, name: String, value: PropertyValue) { base.setProperty(node, name: name, value: value) }
    public func setEventListener(_ node: HostNode, event: String, id: ListenerID) { base.setEventListener(node, event: event, id: id) }
    public func removeEventListener(_ node: HostNode, event: String) { base.removeEventListener(node, event: event) }
    public func observe(_ node: Base.HostNode, kind: ObserverKind, id: ListenerID) { base.observe(node, kind: kind, id: id) }
    public func unobserve(_ node: Base.HostNode, kind: ObserverKind) { base.unobserve(node, kind: kind) }
    public func remove(_ child: HostNode, from parent: HostNode) { base.remove(child, from: parent) }
    public func setStylesheet(_ text: String) { base.setStylesheet(text) }
    public func pushState(path: String) { base.pushState(path: path) }
    public func replaceState(path: String) { base.replaceState(path: path) }
    public func historyBack() { base.historyBack() }
    public func setTitle(_ title: String) { base.setTitle(title) }
    public func setMetaTags(_ tags: [MetaTag]) { base.setMetaTags(tags) }
    public func setLinks(_ links: [LinkTag]) { base.setLinks(links) }
    public func reloadForUpdate() { base.reloadForUpdate() }
    public func childCount(of node: HostNode) -> Int { base.childCount(of: node) }
    public func child(of node: HostNode, at index: Int) -> HostNode { base.child(of: node, at: index) }
    public func tagName(of node: HostNode) -> String? { base.tagName(of: node) }
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {
        base.beginEnvironmentObservation(writer)
    }
    public func storageRead(kind: StorageKind, key: String) -> String? {
        base.storageRead(kind: kind, key: key)
    }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {
        base.storageWrite(kind: kind, key: key, value: value)
    }
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {
        base.beginStorageObservation(onExternalChange: onExternalChange)
    }
    public func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void) {
        base.beginWindowEventObservation(sink)
    }
}
