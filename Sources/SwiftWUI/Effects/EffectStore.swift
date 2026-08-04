/// Build-vs-client scheduling for `.task` effects (spec §6, D5).
public enum TaskPolicy { case client, build }

enum EffectRequest {
    case onChange(id: NodeIdentity, newValue: Any,
                  isEqual: (Any, Any) -> Bool, initial: Bool,
                  action: (Any, Any) -> Void)
    case task(id: NodeIdentity, taskID: AnyHashable?, policy: TaskPolicy, action: () async -> Void)
    case appear(id: NodeIdentity, action: () -> Void)
    case disappear(id: NodeIdentity, action: () -> Void)
    case windowEvent(id: NodeIdentity, kind: WindowEventKind, action: (Any) -> Void)
    case dropGuard(id: NodeIdentity)

    var id: NodeIdentity {
        switch self {
        case .onChange(let id, _, _, _, _), .task(let id, _, _, _),
             .appear(let id, _), .disappear(let id, _),
             .windowEvent(let id, _, _): return id
        case .dropGuard(let id): return id
        }
    }
}

/// Effect lifecycle (spec §5.3–5.4): keyed by wrapper identity; sweep
/// set-difference under the pass root = onDisappear / task cancellation.
///
/// Public API by decision (phase-6): part of the SSG/backend integration surface,
/// not an underscored SPI. Members prefixed `_` remain SPI.
@MainActor
public final class EffectStore {
    nonisolated deinit { }
    private var previousValues: [NodeIdentity: Any] = [:]
    private var tasks: [NodeIdentity: (task: Task<Void, Never>, id: AnyHashable?)] = [:]
    private var appeared: Set<NodeIdentity> = []
    private var disappearActions: [NodeIdentity: () -> Void] = [:]
    /// Set by Runtime (internal — `WindowEventHub` is an internal type even
    /// though `EffectStore` is public).
    var _windowHub: WindowEventHub?
    private var windowSubscriptions: Set<NodeIdentity> = []
    private var dropGuardIDs: Set<NodeIdentity> = []
    /// Set by Runtime → backend.setDropNavigationGuard.
    var _onDropGuardChange: ((Bool) -> Void)?

    /// SSG driver mode (spec §6): .build tasks are collected, not started;
    /// .client tasks don't run at all.
    public var _buildMode = false
    /// Canonical ids of .build tasks the snapshot says already ran (client boot).
    public var _skipBuildTaskKeys: Set<String> = []
    private var pendingBuild: [(id: NodeIdentity, action: () async -> Void)] = []
    private var startedBuild: Set<NodeIdentity> = []
    public private(set) var _completedBuildKeys: [String] = []
    /// SSG build-task write attribution (phase-6 I3): task key → canonical
    /// identity strings written to `StateStore` while that task's action ran.
    public private(set) var _buildWrites: [String: Set<String>] = [:]

    /// Discards a runtime that never committed (hydration mismatch, spec §8):
    /// client `.task` effects already started real Tasks that hold the runtime
    /// alive and would duplicate side effects when the cold-mount fallback
    /// re-runs them — cancel and forget everything before the fallback mounts.
    public func _cancelAll() {
        for (_, entry) in tasks { entry.task.cancel() }
        tasks.removeAll()
        previousValues.removeAll()
        appeared.removeAll()
        disappearActions.removeAll()
        for id in windowSubscriptions { _windowHub?.unsubscribe(id: id) }
        windowSubscriptions.removeAll()
        if !dropGuardIDs.isEmpty {
            dropGuardIDs.removeAll()
            _onDropGuardChange?(false)
        }
    }

    /// Awaits every pending `.build` task in turn, tracking which identities
    /// each one wrote to `store` (phase-6 I3 — replaces the old path-prefix
    /// heuristic with real write attribution). Returns false when nothing was
    /// pending; the caller's build-task loop treats that as quiescence.
    @discardableResult
    public func _drainBuildTasks(store: StateStore) async -> Bool {
        let pending = pendingBuild
        pendingBuild = []
        guard !pending.isEmpty else { return false }
        for task in pending {
            var written = Set<String>()
            store._writeObserver = { id in if let k = id._canonicalString { written.insert(k) } }
            await task.action()               // awaited sequentially, MainActor
            store._writeObserver = nil
            if let key = task.id._canonicalString {
                _buildWrites[key, default: []].formUnion(written)
            }
            _recordBuildCompleted(task.id)
        }
        return true
    }
    public func _recordBuildCompleted(_ id: NodeIdentity) {
        if let key = id._canonicalString { _completedBuildKeys.append(key) }
    }

    /// ORDER DEPENDENCY (_AppearEffect): a disappear request marks presence in
    /// `appeared` (line ~62) so the SAME pass's appear request is not treated
    /// as first appearance. Processing appear before disappear within one
    /// reconcile would break this — keep request handling in emission order.
    /// Returns callbacks to run post-commit. Order (normative, spec D6):
    /// disappear/cancel first, then appear/task/onChange in document order.
    func reconcile(_ requests: [EffectRequest], under passRoot: NodeIdentity) -> [() -> Void] {
        var queue: [() -> Void] = []
        let requested = Set(requests.map(\.id))
        let hadGuards = !dropGuardIDs.isEmpty

        var known = Set(previousValues.keys)
        known.formUnion(tasks.keys); known.formUnion(appeared); known.formUnion(disappearActions.keys)
        known.formUnion(windowSubscriptions)
        known.formUnion(dropGuardIDs)
        for id in known where id.isSelfOrDescendant(of: passRoot) && !requested.contains(id) {
            if let t = tasks.removeValue(forKey: id) { t.task.cancel() }
            if let d = disappearActions.removeValue(forKey: id) { queue.append(d) }
            previousValues[id] = nil
            appeared.remove(id)
            if windowSubscriptions.remove(id) != nil { _windowHub?.unsubscribe(id: id) }
            dropGuardIDs.remove(id)
        }

        for request in requests {
            switch request {
            case .onChange(let id, let new, let isEqual, let initial, let action):
                if let old = previousValues[id] {
                    if !isEqual(old, new) { queue.append { action(old, new) } }
                } else if initial {
                    queue.append { action(new, new) }
                }
                previousValues[id] = new
            case .task(let id, let taskID, let policy, let action):
                if _buildMode {
                    // SSG: .client never runs at build; .build is collected once per identity
                    // and awaited by the driver (spec §6). No Task objects are created here.
                    if policy == .build, !startedBuild.contains(id) {
                        startedBuild.insert(id)
                        pendingBuild.append((id, action))
                    }
                } else if policy == .build, let key = id._canonicalString,
                          _skipBuildTaskKeys.remove(key) != nil {
                    // Hydration boot: the snapshot carried this loader's result — consume
                    // the skip entry and park a finished Task so the identity is occupied
                    // (a later taskID change still restarts it via the normal path).
                    tasks[id] = (Task {}, taskID)
                } else if let existing = tasks[id] {
                    if existing.id != taskID {
                        existing.task.cancel()
                        tasks[id] = (Task { await action() }, taskID)
                    }
                } else {
                    tasks[id] = (Task { await action() }, taskID)
                }
            case .appear(let id, let action):
                if !appeared.contains(id) { appeared.insert(id); queue.append(action) }
            case .disappear(let id, let action):
                if !appeared.contains(id) { appeared.insert(id) }   // presence marker
                disappearActions[id] = action
            case .windowEvent(let id, let kind, let action):
                windowSubscriptions.insert(id)
                _windowHub?.subscribe(id: id, kind: kind, action: action)
            case .dropGuard(let id):
                dropGuardIDs.insert(id)
            }
        }
        if hadGuards != !dropGuardIDs.isEmpty { _onDropGuardChange?(!dropGuardIDs.isEmpty) }
        return queue
    }
}
