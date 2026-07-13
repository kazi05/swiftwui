/// Shadow tree: the single owner of virtual-identity → host-node mapping and
/// listener bookkeeping (spec §8.4, traps T5/T10).
final class MountedNode<N> {
    let host: N?                       // nil for component shadow nodes
    let hostParent: N                  // nearest enclosing realized element
    let componentIdentity: NodeIdentity?   // set for component shadow nodes only
    let elementIdentity: NodeIdentity?     // set for element hosts only (anim spec §6); stable across reuse slots
    weak var parent: MountedNode<N>?
    var indexInParent: Int = 0
    var children: [MountedNode<N>] = []
    var events: Set<String> = []
    var observerKinds: Set<ObserverKind> = []
    init(host: N?, hostParent: N, componentIdentity: NodeIdentity? = nil, elementIdentity: NodeIdentity? = nil) {
        self.host = host; self.hostParent = hostParent
        self.componentIdentity = componentIdentity
        self.elementIdentity = elementIdentity
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
    /// Set by Runtime immediately before each `apply`/`mount` call, cleared
    /// immediately after — never leaks into a later pass (anim spec §6).
    var animationPass: AnimationPassContext?
    let animationRegistry = AnimationRegistry()
    /// Set once by `Runtime` (init/mount) — the persistent `.transition(_:)`
    /// registry (Task 8); the applier only reads it, never owns it.
    var transitionsRef: TransitionRegistry?

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
            let m = MountedNode(host: h, hostParent: hostParent, elementIdentity: el.identity)
            m.events = Set(el.listeners.keys)
            m.observerKinds = Set(el.observers.keys)
            for child in el.children {
                let cm = mount(child, hostParent: h, before: nil)
                cm.parent = m; cm.indexInParent = m.children.count
                m.children.append(cm)
            }
            playEnterTransition(el, host: h)
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

    // MARK: Animation (Task 9)

    /// Shared enter/style-diff animate ceremony (anim spec §6, §6.2): drive
    /// `backend.animate`, track/retarget the registry entry, and balance the
    /// driving transaction's completion group.
    private func playAnimation(_ host: Backend.HostNode, key: AnimationRegistry.Key,
                               request: AnimationRequest, group: CompletionGroup?) {
        if let old = animationRegistry.running[key], request.mode == .replace {
            backend.cancelAnimation(old.token)   // additive retarget hygiene (anim spec §6.2)
        }
        // register() always; settle() either via onSettle (finite) or immediately
        // here (infinite) — onSettle then must skip the group to avoid double-settle.
        let countsTowardGroup = !request.timing.isInfinite
        group?.register()
        var ownToken: AnimationToken?
        let token = backend.animate(host, request: request) { [weak self] _ in
            // Token-ownership guard: an additive retarget leaves the OLD
            // animation running; its later natural settle must NOT evict the
            // NEWER registry entry (anim spec §6.2). AnimationToken is a class.
            if let self, self.animationRegistry.running[key]?.token === ownToken {
                self.animationRegistry.remove(key)
            }
            if countsTowardGroup { group?.settle() }
        }
        ownToken = token
        if let token {
            animationRegistry.track(key, .init(token: token, timing: request.timing, to: request.to))
            if !countsTowardGroup { group?.settle() }   // repeatForever excluded from groups (anim spec §7.4)
        } else {
            animationRegistry.remove(key)
            group?.settle()   // no-op backend: settle immediately
        }
    }

    /// Enter animation for a freshly-mounted element (anim spec §3.4, Task 9).
    /// Runs AFTER `backend.insert` and children mount, so `from` at offset 0
    /// with implicit `to` (current value) is flash-free: the whole flush
    /// completes before paint, there's no frame where the un-animated final
    /// value is visible.
    private func playEnterTransition(_ el: ElementNode, host: Backend.HostNode) {
        guard transitionsRef?.isEmpty == false,
              let pass = animationPass, !pass.suppressTransitions, !pass.reduceMotion,
              let t = transitionsRef!.transition(for: el.identity) else { return }
        // Driving animation resolution order (anim spec §3.4): the transition's
        // own `.animation` always plays and carries no completion group (it
        // isn't a Transaction); otherwise "the transaction that caused the
        // insert" — this element's own in-effect transaction, else the pass's
        // default — supplies both the timing and the group it settles into.
        let anim: Animation?
        let group: CompletionGroup?
        if let ownAnim = t.animation {
            anim = ownAnim; group = nil
        } else if let elTxn = pass.transactions[el.identity], let txnAnim = elTxn.animation {
            anim = txnAnim; group = elTxn._group
        } else if let defTxn = pass.defaultTransaction, let defAnim = defTxn.animation {
            anim = defAnim; group = defTxn._group
        } else {
            anim = nil; group = nil
        }
        guard let anim else { return }   // unanimated structural insert doesn't transition
        let timing = anim.resolved()
        for d in t.insertionActive {
            let request = AnimationRequest(property: d.property, from: d.value, to: nil,
                                           mode: .replace, timing: timing)
            let key = AnimationRegistry.Key(identity: el.identity, property: d.property)
            playAnimation(host, key: key, request: request, group: group)
        }
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
            case .setStyleProperty(let name, let value, let previous):
                backend.setStyleProperty(m.host!, name: name, value: value)   // model final FIRST (anim spec §6.1)
                if let pass = animationPass,
                   let id = m.elementIdentity, let txn = pass.transactions[id],
                   let anim = txn.animation,
                   let request = AnimationPlanner.request(property: name, from: previous, to: value,
                                                          timing: anim.resolved()) {
                    let group = txn._group
                    if pass.reduceMotion {
                        // Reduce motion: no backend animation, no registry entry — but still
                        // register()+settle() so completion semantics hold (anim spec §6, Task 13).
                        group?.register()
                        group?.settle()
                    } else {
                        let key = AnimationRegistry.Key(identity: id, property: name)
                        playAnimation(m.host!, key: key, request: request, group: group)
                    }
                }
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
