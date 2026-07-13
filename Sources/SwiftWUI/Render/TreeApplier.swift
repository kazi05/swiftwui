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

    /// A removed subtree kept alive as an inert "ghost" while its exit
    /// transition plays; torn out of the DOM once every exit animation settles
    /// (anim spec §7.3). Keyed by the removed root's identity.
    struct ExitRecord {
        let mounted: MountedNode<Backend.HostNode>
        let oldNode: Node?          // retained for ghost-adoption re-diff (Task 11)
        var tokens: [AnimationToken]
        var settledTokens: Set<ObjectIdentifier> = []   // token-verified idempotence (anim spec §7.5)
    }
    private(set) var exiting: [NodeIdentity: ExitRecord] = [:]

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
        forceFinishExits(under: m)   // ghosts under m die with it (anim spec §7.3.6)
        unregister(m)
        tearDownListeners(m)
        removeHosts(m)
    }
    private func unregister(_ m: MountedNode<Backend.HostNode>) {
        // mount-before-unmount replace(): only clear the index if it still points at US
        if let id = m.componentIdentity, componentIndex[id] === m { componentIndex[id] = nil }
        for c in m.children { unregister(c) }
    }
    /// Mirror of `unregister` (Task 11, anim spec §7.5): repopulates
    /// `componentIndex` for a ghost being adopted back into the live tree. The
    /// ids were freed at exit-start, so this simply re-claims them.
    private func reregister(_ m: MountedNode<Backend.HostNode>) {
        if let id = m.componentIdentity { componentIndex[id] = m }
        for c in m.children { reregister(c) }
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
        playEnter(identity: el.identity, host: host)
    }

    /// Emits the active→identity enter animations for `identity`'s registered
    /// transition. Shared by the fresh-mount enter path (Task 9) and ghost
    /// adoption's enter replay (Task 11) — both drive from the current
    /// presentation (WAAPI implicit `to`) with the same resolution order.
    private func playEnter(identity: NodeIdentity, host: Backend.HostNode) {
        guard transitionsRef?.isEmpty == false,
              let pass = animationPass, !pass.suppressTransitions, !pass.reduceMotion,
              let t = transitionsRef!.transition(for: identity), !t.insertionActive.isEmpty else { return }
        // Driving animation resolution order (anim spec §3.4): the transition's
        // own `.animation` always plays and carries no completion group (it
        // isn't a Transaction); otherwise "the transaction that caused the
        // insert" — this element's own in-effect transaction, else the pass's
        // default — supplies both the timing and the group it settles into.
        let anim: Animation?
        let group: CompletionGroup?
        if let ownAnim = t.animation {
            anim = ownAnim; group = nil
        } else if let elTxn = pass.transactions[identity], let txnAnim = elTxn.animation {
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
            let key = AnimationRegistry.Key(identity: identity, property: d.property)
            playAnimation(host, key: key, request: request, group: group)
        }
    }

    // MARK: Exit orchestration (Task 10 — anim spec §7.3)

    private func rootIdentity(of node: Node) -> NodeIdentity? {
        switch node {
        case .element(let e): return e.identity
        case .component(let c): return c.identity
        case .text: return nil
        }
    }

    /// Visits the OUTERMOST transition-bearing element hosts under `m` (stops
    /// descending once a root animates — SwiftUI's outermost-transition rule).
    private func collectExitRoots(_ m: MountedNode<Backend.HostNode>,
                                  _ visit: (Backend.HostNode, NodeIdentity, AnyTransition) -> Void) {
        if let h = m.host, let id = m.elementIdentity,
           let t = transitionsRef?.transition(for: id), !t.removalActive.isEmpty {
            visit(h, id, t); return
        }
        for c in m.children { collectExitRoots(c, visit) }
    }

    /// Every realized element host at the root level of `m`'s block (a component
    /// ghost realizes several) — the hosts marked `inert` (anim spec §7.3.2).
    private func topLevelHosts(_ m: MountedNode<Backend.HostNode>, into out: inout [Backend.HostNode]) {
        if let h = m.host { out.append(h); return }
        for c in m.children { topLevelHosts(c, into: &out) }
    }

    /// Nearest identity at or under `m` — force-finish's prefix anchor.
    private func nearestIdentity(_ m: MountedNode<Backend.HostNode>) -> NodeIdentity? {
        if let id = m.componentIdentity ?? m.elementIdentity { return id }
        for c in m.children { if let id = nearestIdentity(c) { return id } }
        return nil
    }

    /// Returns true when an exit transition started (the ghost is kept and torn
    /// out on settle); false → the caller must `unmount(m)` normally. `node` is
    /// the removed Node (nil from `replace()`, which has no old Node in hand).
    func beginExit(_ m: MountedNode<Backend.HostNode>, node: Node?) -> Bool {
        guard let pass = animationPass, !pass.reduceMotion,
              transitionsRef?.isEmpty == false else { return false }
        // Driving-animation resolution per outermost root, mirroring the enter
        // path (anim spec §3.4): the transition's own animation, else this
        // element's in-effect transaction, else the pass default. All nil = no
        // transition on that root (unanimated remove is instant — SwiftUI parity).
        var work: [(host: Backend.HostNode, transition: AnyTransition,
                    timing: ResolvedTiming, group: CompletionGroup?)] = []
        collectExitRoots(m) { host, id, t in
            let anim: Animation?
            let group: CompletionGroup?
            if let own = t.animation {
                anim = own; group = nil
            } else if let txn = pass.transactions[id], let a = txn.animation {
                anim = a; group = txn._group
            } else if let def = pass.defaultTransaction, let a = def.animation {
                anim = a; group = def._group
            } else {
                anim = nil; group = nil
            }
            if let anim { work.append((host, t, anim.resolved(), group)) }
        }
        guard !work.isEmpty,
              let key = node.flatMap(rootIdentity(of:)) ?? m.componentIdentity ?? m.elementIdentity
        else { return false }

        // Commit the ghost: free component bookkeeping and mark inert. Listeners
        // stay attached (registry sweep already killed the handlers; fire-time
        // lookup no-ops) — DOM listener teardown happens in finishExit, and Task
        // 11 adoption needs them attached until then (anim spec §7.3).
        unregister(m)
        var hosts: [Backend.HostNode] = []
        topLevelHosts(m, into: &hosts)
        for h in hosts { backend.setAttribute(h, name: "inert", value: "") }

        // Same-identity re-exit (toggle off→on→off inside the window): the prior
        // ghost still owns `key`. Tear it out first or its host + listeners leak.
        // (Its cancelled tokens' late async settle can no longer contaminate the
        // new record — `recordExitSettle` is token-verified — but the DOM/listener
        // teardown still has to happen here.)
        if let stale = exiting[key] {
            stale.tokens.forEach(backend.cancelAnimation)
            finishExit(key)
        }
        exiting[key] = ExitRecord(mounted: m, oldNode: node, tokens: [])

        // Removal during enter (anim spec §7.5): kill any in-flight enter/style
        // animations under this subtree so the exit starts from the CURRENT
        // presentation (implicit-from), not a snapped-to-final value. Their
        // onSettle balances the driving transaction's completion group (t7).
        animationRegistry.cancelAll(under: key, using: backend.cancelAnimation)

        for w in work {
            for d in w.transition.removalActive {
                // identity→active: from implicit (current), to the off-stage value.
                let request = AnimationRequest(property: d.property, from: nil, to: d.value,
                                               mode: .replace, timing: w.timing)
                let countsGroup = !w.timing.isInfinite   // repeatForever excluded (anim spec §7.4)
                w.group?.register()
                var ownToken: AnimationToken?
                let token = backend.animate(w.host, request: request) { [weak self] _ in
                    if countsGroup { w.group?.settle() }
                    if let ownToken { self?.recordExitSettle(key, token: ownToken) }
                }
                ownToken = token
                if let token {
                    exiting[key]?.tokens.append(token)
                    if !countsGroup { w.group?.settle() }
                } else {
                    w.group?.settle()   // no-op backend: nothing to wait on
                }
            }
        }
        // No real animation ran (backend couldn't animate any property): remove
        // the ghost immediately rather than leaking it (backends never call
        // onSettle synchronously, so tokens is fully populated here).
        if exiting[key]?.tokens.isEmpty == true { finishExit(key) }
        return true
    }

    /// Token-verified (anim spec §7.5): a superseded record's token settling late
    /// (an async backend's cancel-rejection lands a microtask later) must NOT
    /// count against whatever record now holds this key — only this record's own
    /// tokens advance it toward finish. Stray tokens are ignored no-ops.
    private func recordExitSettle(_ key: NodeIdentity, token: AnimationToken) {
        guard var rec = exiting[key], rec.tokens.contains(where: { $0 === token }) else { return }
        rec.settledTokens.insert(ObjectIdentifier(token))
        exiting[key] = rec
        if rec.settledTokens.count >= rec.tokens.count { finishExit(key) }
    }

    /// Idempotent (anim spec §7.3.6): tears the ghost down for good.
    /// `unregister` already ran in `beginExit`; here we drop DOM listeners + hosts.
    func finishExit(_ id: NodeIdentity) {
        guard let record = exiting.removeValue(forKey: id) else { return }
        tearDownListeners(record.mounted)
        removeHosts(record.mounted)
    }

    /// Force-finishes every exit whose ghost lives under `m` before `m` unmounts:
    /// its DOM dies with the ancestor anyway, so cancel the backend animations
    /// (which fire onSettle) and finish the records; late settles are no-ops.
    private func forceFinishExits(under m: MountedNode<Backend.HostNode>) {
        guard !exiting.isEmpty, let root = nearestIdentity(m) else { return }
        for (id, rec) in exiting.filter({ $0.key.isSelfOrDescendant(of: root) }) {
            rec.tokens.forEach(backend.cancelAnimation)
            finishExit(id)
        }
    }

    /// Visits the OUTERMOST enter-transition-bearing element hosts under `m` —
    /// adoption's enter-replay counterpart of `collectExitRoots` (Task 11).
    private func collectEnterRoots(_ m: MountedNode<Backend.HostNode>,
                                   _ visit: (Backend.HostNode, NodeIdentity) -> Void) {
        if let h = m.host, let id = m.elementIdentity,
           let t = transitionsRef?.transition(for: id), !t.insertionActive.isEmpty {
            visit(h, id); return
        }
        for c in m.children { collectEnterRoots(c, visit) }
    }

    /// Re-insertion during exit (anim spec §7.5): a fresh slot whose identity is
    /// still exiting adopts the ghost back instead of mounting a duplicate.
    /// State was swept at exit-start, so the incoming (already-resolved-with-
    /// fresh-state) `node` re-diffs against the ghost's retained `oldNode` and
    /// the adopted subtree restarts fresh — SwiftUI parity, documented.
    /// `anchorNode` is the live anchor of the in-flight right-to-left slot pass.
    private func adopt(_ node: Node, key: NodeIdentity, rec: ExitRecord,
                       hostParent: Backend.HostNode,
                       anchorNode: Backend.HostNode?) -> MountedNode<Backend.HostNode> {
        guard let oldNode = rec.oldNode else {
            // replaceSelf ghost has no retained old Node to re-diff against:
            // force-finish it and mount fresh (documented fallback, anim spec §7.5).
            rec.tokens.forEach(backend.cancelAnimation)
            finishExit(key)
            return mount(node, hostParent: hostParent, before: anchorNode)
        }
        // Drop the record BEFORE cancelling: cancel fires each token's onSettle
        // (recordExitSettle), which must no-op against a gone record rather than
        // run finishExit → removeHosts and tear the ghost's DOM/listeners out.
        // The onSettle still balances the exit's completion group.
        exiting[key] = nil
        rec.tokens.forEach(backend.cancelAnimation)   // presentation snaps toward model
        reregister(rec.mounted)                        // ghost back into componentIndex
        var hosts: [Backend.HostNode] = []
        topLevelHosts(rec.mounted, into: &hosts)
        for h in hosts { backend.removeAttribute(h, name: "inert") }   // clicks/focus live again
        let patches = Reconciler().diff(old: oldNode, new: node)
        apply(patches, to: rec.mounted, endAnchor: anchorNode)
        moveHosts(rec.mounted, before: anchorNode, in: hostParent)     // ghost may be out of position
        // Re-run the enter path from the current presentation (WAAPI implicit-from).
        collectEnterRoots(rec.mounted) { host, id in playEnter(identity: id, host: host) }
        return rec.mounted
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
        // Enter side fires inside mount(new) → playEnterTransition (Task 9). Exit
        // side: try to keep the old subtree as a ghost that animates out AFTER
        // the new node in DOM order (anim spec §7.1). `node: nil` — replace has no
        // old Node in hand, so ghost adoption after a replaceSelf-exit falls back
        // to force-finish + fresh mount (documented, Task 11).
        let nm = mount(new, hostParent: m.hostParent, before: a)
        if animationPass == nil || !beginExit(m, node: nil) {
            unmount(m)
        }
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

        // Removals first (anim spec §7.3): a transition-bearing removed root
        // becomes an inert ghost that leaves the shadow tree here but stays in
        // the DOM until its exit animation settles; everything else unmounts now.
        assert(plan.removedNodes.count == plan.removedOldIndices.count)
        for (k, i) in plan.removedOldIndices.enumerated() {
            let m = oldChildren[i]
            if animationPass != nil, beginExit(m, node: plan.removedNodes[k]) { continue }
            unmount(m)
        }

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
                // Adopt a still-exiting ghost of the same identity back to life
                // (anim spec §7.5) rather than mounting a duplicate.
                if let key = rootIdentity(of: node), let rec = exiting[key] {
                    newChildren[idx] = adopt(node, key: key, rec: rec,
                                             hostParent: hostParent, anchorNode: anchorNode)
                } else {
                    newChildren[idx] = mount(node, hostParent: hostParent, before: anchorNode)
                }
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
