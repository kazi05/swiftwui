/// Shadow tree: the single owner of virtual-identity → host-node mapping and
/// listener bookkeeping (spec §8.4, traps T5/T10).
final class MountedNode<N> {
    let host: N?                       // nil for component shadow nodes
    let hostParent: N                  // nearest enclosing realized element
    let componentIdentity: NodeIdentity?   // set for component shadow nodes only
    weak var parent: MountedNode<N>?
    var indexInParent: Int = 0
    var children: [MountedNode<N>] = []
    var events: Set<String> = []
    var observerKinds: Set<ObserverKind> = []
    init(host: N?, hostParent: N, componentIdentity: NodeIdentity? = nil) {
        self.host = host; self.hostParent = hostParent; self.componentIdentity = componentIdentity
    }
}

@MainActor
final class TreeApplier<Backend: RendererBackend> {
    let backend: Backend
    /// Root wraps the container element (host != nil) — anchor recursion
    /// terminates here (spec §8.4, decision 22).
    let root: MountedNode<Backend.HostNode>
    /// Component shadow-node lookup by identity, kept in sync by mount/unmount.
    private(set) var componentIndex: [NodeIdentity: MountedNode<Backend.HostNode>] = [:]

    init(backend: Backend, container: Backend.HostNode) {
        self.backend = backend
        root = MountedNode(host: container, hostParent: container)
    }

    // MARK: Mount / unmount

    func mount(_ node: Node, hostParent: Backend.HostNode,
               before anchor: Backend.HostNode?) -> MountedNode<Backend.HostNode> {
        switch node {
        case .text(let s):
            let h = backend.createTextNode(s)
            backend.insert(h, into: hostParent, before: anchor)
            return MountedNode(host: h, hostParent: hostParent)

        case .element(let el):
            let h = backend.createElement(el.tag)
            for name in el.attributes.keys.sorted() {
                backend.setAttribute(h, name: name, value: el.attributes[name]!)
            }
            for e in el.style.entries {
                backend.setStyleProperty(h, name: e.property, value: e.value)
            }
            for name in el.properties.keys.sorted() {
                backend.setProperty(h, name: name, value: el.properties[name]!)
            }
            for event in el.listeners.keys.sorted() {
                backend.setEventListener(h, event: event, id: el.listeners[event]!)
            }
            for kind in el.observers.keys.sorted(by: { $0.key < $1.key }) {
                backend.observe(h, kind: kind, id: el.observers[kind]!)
            }
            backend.insert(h, into: hostParent, before: anchor)
            let m = MountedNode(host: h, hostParent: hostParent)
            m.events = Set(el.listeners.keys)
            m.observerKinds = Set(el.observers.keys)
            for child in el.children {
                let cm = mount(child, hostParent: h, before: nil)
                cm.parent = m; cm.indexInParent = m.children.count
                m.children.append(cm)
            }
            return m

        case .component(let c):
            // Transparent: children realize into the SAME hostParent, in order,
            // each before the same outer anchor.
            let m = MountedNode(host: nil, hostParent: hostParent, componentIdentity: c.identity)
            componentIndex[c.identity] = m
            for child in c.children {
                let cm = mount(child, hostParent: hostParent, before: anchor)
                cm.parent = m; cm.indexInParent = m.children.count
                m.children.append(cm)
            }
            return m
        }
    }

    func unmount(_ m: MountedNode<Backend.HostNode>) {
        unregister(m)
        tearDownListeners(m)
        removeHosts(m)
    }
    private func unregister(_ m: MountedNode<Backend.HostNode>) {
        // mount-before-unmount replace(): only clear the index if it still points at US
        if let id = m.componentIdentity, componentIndex[id] === m { componentIndex[id] = nil }
        for c in m.children { unregister(c) }
    }
    private func tearDownListeners(_ m: MountedNode<Backend.HostNode>) {
        for c in m.children { tearDownListeners(c) }
        if let h = m.host {
            for e in m.events { backend.removeEventListener(h, event: e) }
            for k in m.observerKinds { backend.unobserve(h, kind: k) }
        }
    }
    private func removeHosts(_ m: MountedNode<Backend.HostNode>) {
        if let h = m.host { backend.remove(h, from: m.hostParent); return }
        for c in m.children { removeHosts(c) }     // component: remove each realized root
    }

    // MARK: Anchors (spec §8.4 — normative algorithm)

    func firstHost(_ m: MountedNode<Backend.HostNode>) -> Backend.HostNode? {
        if let h = m.host { return h }
        for c in m.children { if let h = firstHost(c) { return h } }
        return nil
    }

    func anchor(after index: Int, in parent: MountedNode<Backend.HostNode>) -> Backend.HostNode? {
        for j in (index + 1)..<parent.children.count {
            if let h = firstHost(parent.children[j]) { return h }
        }
        if parent.host != nil { return nil }                 // real element: append
        guard let gp = parent.parent else { return nil }     // unreachable (root has host)
        return anchor(after: parent.indexInParent, in: gp)   // component: enclosing scope
    }

    // MARK: Patch application

    /// `endAnchor` is the live host that should end up right after `m`'s block,
    /// threaded down by an enclosing `applyChildren` call that is still mid-flight
    /// (its shadow `children`/`indexInParent` aren't updated yet). `nil` (not
    /// `.some(nil)`) means "not threaded" — recompute via the shadow tree, which
    /// is only safe for non-nested/top-level callers (spec §8.4, C1 fix).
    func apply(_ patches: [Patch], to m: MountedNode<Backend.HostNode>,
               endAnchor: Backend.HostNode?? = nil) {
        for p in patches {
            switch p {
            case .setText(let s):
                backend.setText(m.host!, s)
            case .setAttribute(let name, let value):
                backend.setAttribute(m.host!, name: name, value: value)
            case .removeAttribute(let name):
                backend.removeAttribute(m.host!, name: name)
            case .setStyleProperty(let name, let value, _):
                backend.setStyleProperty(m.host!, name: name, value: value)
            case .removeStyleProperty(let name):
                backend.removeStyleProperty(m.host!, name: name)
            case .setProperty(let name, let value):
                backend.setProperty(m.host!, name: name, value: value)
            case .setListener(let event, let id):
                backend.setEventListener(m.host!, event: event, id: id)
                m.events.insert(event)
            case .removeListener(let event):
                backend.removeEventListener(m.host!, event: event)
                m.events.remove(event)
            case .setObserver(let kind, let id):
                backend.observe(m.host!, kind: kind, id: id)
                m.observerKinds.insert(kind)
            case .removeObserver(let kind):
                backend.unobserve(m.host!, kind: kind)
                m.observerKinds.remove(kind)
            case .replaceSelf(let new):
                replace(m, with: new, endAnchor: endAnchor)
            case .updateChildren(let plan):
                applyChildren(plan, on: m, endAnchor: endAnchor)
            }
        }
    }

    // Reachable ONLY from a top-level diff of same-position roots (renderPass /
    // subtree pass). diffChildren never emits replaceSelf into a reuse slot:
    // sameIdentity() gates reuse, and diff() emits replaceSelf only on
    // identity/tag mismatch (pinned by ApplierRegressionTests).
    private func replace(_ m: MountedNode<Backend.HostNode>, with new: Node,
                         endAnchor: Backend.HostNode?? = nil) {
        guard let parent = m.parent else { preconditionFailure("replace at shadow root") }
        // Position marker: m's own first host, else the threaded live anchor if
        // given, else the (only safe when non-nested) shadow-tree fallback.
        let a = firstHost(m) ?? (endAnchor ?? anchor(after: m.indexInParent, in: parent))
        let nm = mount(new, hostParent: m.hostParent, before: a)
        unmount(m)
        nm.parent = parent
        nm.indexInParent = m.indexInParent
        parent.children[m.indexInParent] = nm
    }

    /// Normative application order (spec decision 22): removals first, then the
    /// shadow children array adopts the NEW order, then slots realize
    /// RIGHT-TO-LEFT so anchor scans always see already-attached later siblings.
    func applyChildren(_ plan: ChildrenPlan, on parent: MountedNode<Backend.HostNode>,
                       endAnchor: Backend.HostNode?? = nil) {
        let oldChildren = parent.children

        for i in plan.removedOldIndices { unmount(oldChildren[i]) }

        let hostParent = parent.host ?? parent.hostParent
        var newChildren = [MountedNode<Backend.HostNode>?](repeating: nil, count: plan.slots.count)

        // Anchor past the end of this child list. If the caller threaded a live
        // anchor (we're a component-hosted child of an in-flight outer
        // applyChildren), trust it; otherwise walk up through components via the
        // shadow tree (only safe when not nested inside another application).
        var anchorNode: Backend.HostNode? = {
            if parent.host != nil { return nil }
            if let threaded = endAnchor { return threaded }
            guard let gp = parent.parent else { return nil }
            return anchor(after: parent.indexInParent, in: gp)
        }()

        var minOldToRight = Int.max
        for idx in stride(from: plan.slots.count - 1, through: 0, by: -1) {
            switch plan.slots[idx] {
            case .fresh(let node):
                newChildren[idx] = mount(node, hostParent: hostParent, before: anchorNode)
            case .reuse(let oldIndex, let patches):
                let m = oldChildren[oldIndex]
                // Apply patches (which may grow/reorder m's own children) BEFORE
                // moving m's hosts, so a moved block carries its updated children.
                apply(patches, to: m, endAnchor: m.host == nil ? anchorNode : nil)
                if oldIndex > minOldToRight {
                    moveHosts(m, before: anchorNode, in: hostParent)   // out of order → move
                } else {
                    minOldToRight = oldIndex                           // greedy in-place check
                }
                newChildren[idx] = m
            }
            anchorNode = firstHost(newChildren[idx]!) ?? anchorNode
        }

        parent.children = newChildren.map { $0! }
        for (i, c) in parent.children.enumerated() { c.parent = parent; c.indexInParent = i }
    }

    private func moveHosts(_ m: MountedNode<Backend.HostNode>, before anchor: Backend.HostNode?,
                           in hostParent: Backend.HostNode) {
        if let h = m.host { backend.insert(h, into: hostParent, before: anchor); return }
        for c in m.children { moveHosts(c, before: anchor, in: hostParent) }
    }
}
