/// Shadow tree: the single owner of virtual-identity → host-node mapping and
/// listener bookkeeping (spec §8.4, traps T5/T10).
final class MountedNode<N> {
    var vnode: Node
    let host: N?                       // nil for component shadow nodes
    let hostParent: N                  // nearest enclosing realized element
    weak var parent: MountedNode<N>?
    var indexInParent: Int = 0
    var children: [MountedNode<N>] = []
    var events: Set<String> = []
    init(vnode: Node, host: N?, hostParent: N) {
        self.vnode = vnode; self.host = host; self.hostParent = hostParent
    }
}

@MainActor
final class TreeApplier<Backend: RendererBackend> {
    let backend: Backend
    /// Root wraps the container element (host != nil) — anchor recursion
    /// terminates here (spec §8.4, decision 22).
    let root: MountedNode<Backend.HostNode>

    init(backend: Backend, container: Backend.HostNode) {
        self.backend = backend
        root = MountedNode(vnode: .text(""), host: container, hostParent: container)
    }

    // MARK: Mount / unmount

    func mount(_ node: Node, hostParent: Backend.HostNode,
               before anchor: Backend.HostNode?) -> MountedNode<Backend.HostNode> {
        switch node {
        case .text(let s):
            let h = backend.createTextNode(s)
            backend.insert(h, into: hostParent, before: anchor)
            return MountedNode(vnode: node, host: h, hostParent: hostParent)

        case .element(let el):
            let h = backend.createElement(el.tag)
            for name in el.attributes.keys.sorted() {
                backend.setAttribute(h, name: name, value: el.attributes[name]!)
            }
            for event in el.listeners.keys.sorted() {
                backend.setEventListener(h, event: event, id: el.listeners[event]!)
            }
            backend.insert(h, into: hostParent, before: anchor)
            let m = MountedNode(vnode: node, host: h, hostParent: hostParent)
            m.events = Set(el.listeners.keys)
            for child in el.children {
                let cm = mount(child, hostParent: h, before: nil)
                cm.parent = m; cm.indexInParent = m.children.count
                m.children.append(cm)
            }
            return m

        case .component(let c):
            // Transparent: children realize into the SAME hostParent, in order,
            // each before the same outer anchor.
            let m = MountedNode(vnode: node, host: nil, hostParent: hostParent)
            for child in c.children {
                let cm = mount(child, hostParent: hostParent, before: anchor)
                cm.parent = m; cm.indexInParent = m.children.count
                m.children.append(cm)
            }
            return m
        }
    }

    func unmount(_ m: MountedNode<Backend.HostNode>) {
        tearDownListeners(m)
        removeHosts(m)
    }
    private func tearDownListeners(_ m: MountedNode<Backend.HostNode>) {
        for c in m.children { tearDownListeners(c) }
        if let h = m.host {
            for e in m.events { backend.removeEventListener(h, event: e) }
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

    func apply(_ patches: [Patch], to m: MountedNode<Backend.HostNode>) {
        for p in patches {
            switch p {
            case .setText(let s):
                backend.setText(m.host!, s); m.vnode = .text(s)
            case .setAttribute(let name, let value):
                backend.setAttribute(m.host!, name: name, value: value)
            case .removeAttribute(let name):
                backend.removeAttribute(m.host!, name: name)
            case .setListener(let event, let id):
                backend.setEventListener(m.host!, event: event, id: id)
                m.events.insert(event)
            case .removeListener(let event):
                backend.removeEventListener(m.host!, event: event)
                m.events.remove(event)
            case .replaceSelf(let new):
                replace(m, with: new)
            case .updateChildren(let plan):
                applyChildren(plan, on: m)
            }
        }
    }

    private func replace(_ m: MountedNode<Backend.HostNode>, with new: Node) {
        guard let parent = m.parent else { preconditionFailure("replace at shadow root") }
        // Position marker: m's own first host, else the next sibling's.
        let a = firstHost(m) ?? anchor(after: m.indexInParent, in: parent)
        let nm = mount(new, hostParent: m.hostParent, before: a)
        unmount(m)
        nm.parent = parent
        nm.indexInParent = m.indexInParent
        parent.children[m.indexInParent] = nm
    }

    /// Normative application order (spec decision 22): removals first, then the
    /// shadow children array adopts the NEW order, then slots realize
    /// RIGHT-TO-LEFT so anchor scans always see already-attached later siblings.
    func applyChildren(_ plan: ChildrenPlan, on parent: MountedNode<Backend.HostNode>) {
        let oldChildren = parent.children

        for i in plan.removedOldIndices { unmount(oldChildren[i]) }

        let hostParent = parent.host ?? parent.hostParent
        var newChildren = [MountedNode<Backend.HostNode>?](repeating: nil, count: plan.slots.count)

        // Anchor past the end of this child list (walks up through components).
        var anchorNode: Backend.HostNode? = {
            if parent.host != nil { return nil }
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
                if oldIndex > minOldToRight {
                    moveHosts(m, before: anchorNode, in: hostParent)   // out of order → move
                } else {
                    minOldToRight = oldIndex                           // greedy in-place check
                }
                apply(patches, to: m)
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
