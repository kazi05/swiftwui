@MainActor
protocol _ScrollRegistryContext: AnyObject {
    func _proxy(for id: NodeIdentity) -> ScrollProxy
}

@MainActor
final class ScrollRegistry<Backend: RendererBackend>: _ScrollRegistryContext {
    nonisolated deinit { }

    private enum Phase: Equatable { case unmounted, provisional, active }
    private struct Entry {
        let generation: UInt64
        let proxy: ScrollProxy
        var container: ScrollContainer = .window
        var phase: Phase = .unmounted
        var command: ScrollCommand?
    }

    private let backend: Backend
    private let mountedRoot: (NodeIdentity) -> MountedNode<Backend.HostNode>?
    private let operationsAllowed: () -> Bool
    private let reducedMotion: () -> Bool
    private let scheduleWork: () -> Void
    private var entries: [NodeIdentity: Entry] = [:]
    private var nextGeneration: UInt64 = 0
    private var adoptionAccepted = true
    private var cancelled = false
    private var isDraining = false

    init(backend: Backend,
         mountedRoot: @escaping (NodeIdentity) -> MountedNode<Backend.HostNode>?,
         operationsAllowed: @escaping () -> Bool,
         reducedMotion: @escaping () -> Bool,
         scheduleWork: @escaping () -> Void) {
        self.backend = backend
        self.mountedRoot = mountedRoot
        self.operationsAllowed = operationsAllowed
        self.reducedMotion = reducedMotion
        self.scheduleWork = scheduleWork
    }

    func _proxy(for id: NodeIdentity) -> ScrollProxy {
        if let existing = entries[id] { return existing.proxy }
        nextGeneration &+= 1
        let generation = nextGeneration
        let proxy = ScrollProxy(
            metrics: { [weak self] in self?.metrics(for: id, generation: generation) },
            capture: { [weak self] ids in self?.capture(ids, for: id, generation: generation) },
            submit: { [weak self] command in self?.submit(command, for: id, generation: generation) }
        )
        entries[id] = Entry(generation: generation, proxy: proxy)
        return proxy
    }

    func commit(_ requested: [NodeIdentity: ScrollContainer], under root: NodeIdentity) {
        guard !cancelled else { return }
        for id in Array(entries.keys)
        where id.isSelfOrDescendant(of: root) && requested[id] == nil {
            entries[id] = nil
        }
        for (id, container) in requested where id.isSelfOrDescendant(of: root) {
            _ = _proxy(for: id)
            guard var entry = entries[id] else { continue }
            entry.container = container
            entry.phase = adoptionAccepted ? .active : .provisional
            entries[id] = entry
        }
    }

    func deferUntilAdoption() { adoptionAccepted = false }

    func acceptAdoption() {
        guard !cancelled else { return }
        adoptionAccepted = true
        var hasPending = false
        for id in Array(entries.keys) {
            guard var entry = entries[id] else { continue }
            if entry.phase == .provisional { entry.phase = .active }
            hasPending = hasPending || entry.command != nil
            entries[id] = entry
        }
        if hasPending { scheduleWork() }
    }

    func cancelAll() {
        cancelled = true
        entries.removeAll()
    }

    var hasPendingCommands: Bool { entries.values.contains { $0.command != nil } }
    var shouldScheduleDrain: Bool {
        adoptionAccepted && !cancelled && !isDraining && hasPendingCommands
    }

    func drain() {
        guard adoptionAccepted, !cancelled, !isDraining, operationsAllowed() else { return }
        isDraining = true
        let pending = entries.compactMap { id, entry -> (NodeIdentity, UInt64, ScrollCommand)? in
            guard entry.phase == .active, let command = entry.command else { return nil }
            return (id, entry.generation, command)
        }
        for (id, generation, _) in pending {
            guard var entry = entries[id], entry.generation == generation else { continue }
            entry.command = nil
            entries[id] = entry
        }
        for (id, generation, command) in pending {
            execute(command, for: id, generation: generation)
        }
        isDraining = false
    }

    private func submit(_ command: ScrollCommand, for id: NodeIdentity, generation: UInt64) {
        guard operationsAllowed(), !cancelled, var entry = entries[id],
              entry.generation == generation, entry.phase != .unmounted else { return }
        entry.command = command
        entries[id] = entry
        scheduleWork()
    }

    private func metrics(for id: NodeIdentity, generation: UInt64) -> ScrollMetrics? {
        guard operationsAllowed(), let (entry, target, _, _) = resolved(id, generation: generation),
              entry.phase == .active else { return nil }
        return backend._scrollMetrics(in: target)
    }

    private func capture(_ orderedIDs: [String], for id: NodeIdentity,
                         generation: UInt64) -> ScrollAnchor? {
        guard operationsAllowed(), !orderedIDs.isEmpty,
              let (entry, target, scope, container) = resolved(id, generation: generation),
              entry.phase == .active else { return nil }
        let candidates = uniqueCandidates(orderedIDs, in: scope, container: container)
        guard !candidates.isEmpty,
              let geometry = backend._captureScrollAnchor(in: target,
                                                           candidates: candidates.map(\.node.host!)),
              candidates.indices.contains(geometry.index),
              geometry.offsetFromVisibleTop.isFinite else { return nil }
        return ScrollAnchor(elementID: candidates[geometry.index].id,
                            offsetFromVisibleTop: geometry.offsetFromVisibleTop)
    }

    private func execute(_ command: ScrollCommand, for id: NodeIdentity, generation: UInt64) {
        guard let (_, target, scope, container) = resolved(id, generation: generation) else { return }
        switch command {
        case .restore(let anchor):
            let candidates = uniqueCandidates([anchor.elementID], in: scope, container: container)
            guard let candidate = candidates.first else { return }
            backend._restoreScrollAnchor(in: target, element: candidate.node.host!,
                                         offset: anchor.offsetFromVisibleTop)
        case .end(let behavior):
            backend._scrollToEnd(in: target,
                                 behavior: reducedMotion() && behavior == .smooth ? .instant : behavior)
        }
    }

    private func resolved(_ id: NodeIdentity, generation: UInt64)
        -> (Entry, _ScrollTarget<Backend.HostNode>, MountedNode<Backend.HostNode>, MountedNode<Backend.HostNode>?)? {
        guard let entry = entries[id], entry.generation == generation,
              entry.phase != .unmounted, let scope = mountedRoot(id) else { return nil }
        switch entry.container {
        case .window:
            return (entry, .window, scope, nil)
        case .element(let elementID):
            guard !elementID.isEmpty,
                  let container = uniqueNode(named: elementID, in: scope) else { return nil }
            return (entry, .element(container.host!), scope, container)
        }
    }

    private func uniqueCandidates(_ orderedIDs: [String], in scope: MountedNode<Backend.HostNode>,
                                  container: MountedNode<Backend.HostNode>?)
        -> [(id: String, node: MountedNode<Backend.HostNode>)] {
        var seen = Set<String>()
        var result: [(String, MountedNode<Backend.HostNode>)] = []
        for id in orderedIDs where !id.isEmpty && seen.insert(id).inserted {
            guard let node = uniqueNode(named: id, in: scope) else { continue }
            if let container {
                guard node !== container, isDescendant(node, of: container) else { continue }
            }
            result.append((id, node))
        }
        return result
    }

    private func uniqueNode(named id: String, in scope: MountedNode<Backend.HostNode>)
        -> MountedNode<Backend.HostNode>? {
        var found: MountedNode<Backend.HostNode>?
        var duplicate = false
        walk(scope, readerRoot: scope.componentIdentity) { node in
            if node.scrollElementID == id {
                if found == nil { found = node } else { duplicate = true }
            }
        }
        return duplicate ? nil : found
    }

    private func walk(_ node: MountedNode<Backend.HostNode>, readerRoot: NodeIdentity?,
                      visit: (MountedNode<Backend.HostNode>) -> Void) {
        if let componentID = node.componentIdentity, componentID != readerRoot,
           let nestedReader = entries[componentID], nestedReader.phase != .unmounted { return }
        visit(node)
        for child in node.children { walk(child, readerRoot: readerRoot, visit: visit) }
    }

    private func isDescendant(_ node: MountedNode<Backend.HostNode>,
                              of ancestor: MountedNode<Backend.HostNode>) -> Bool {
        var cursor = node.parent
        while let current = cursor {
            if current === ancestor { return true }
            cursor = current.parent
        }
        return false
    }
}
