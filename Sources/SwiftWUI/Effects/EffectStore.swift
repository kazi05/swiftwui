/// Build-vs-client scheduling for `.task` effects (spec §6, D5).
public enum TaskPolicy { case client, build }

enum EffectRequest {
    case onChange(id: NodeIdentity, newValue: Any,
                  isEqual: (Any, Any) -> Bool, initial: Bool,
                  action: (Any, Any) -> Void)
    case task(id: NodeIdentity, taskID: AnyHashable?, policy: TaskPolicy, action: () async -> Void)
    case appear(id: NodeIdentity, action: () -> Void)
    case disappear(id: NodeIdentity, action: () -> Void)

    var id: NodeIdentity {
        switch self {
        case .onChange(let id, _, _, _, _), .task(let id, _, _, _),
             .appear(let id, _), .disappear(let id, _): return id
        }
    }
}

/// Effect lifecycle (spec §5.3–5.4): keyed by wrapper identity; sweep
/// set-difference under the pass root = onDisappear / task cancellation.
@MainActor
public final class EffectStore {
    private var previousValues: [NodeIdentity: Any] = [:]
    private var tasks: [NodeIdentity: (task: Task<Void, Never>, id: AnyHashable?)] = [:]
    private var appeared: Set<NodeIdentity> = []
    private var disappearActions: [NodeIdentity: () -> Void] = [:]

    /// SSG driver mode (spec §6): .build tasks are collected, not started;
    /// .client tasks don't run at all.
    public var _buildMode = false
    /// Canonical ids of .build tasks the snapshot says already ran (client boot).
    public var _skipBuildTaskKeys: Set<String> = []
    private var pendingBuild: [(id: NodeIdentity, action: () async -> Void)] = []
    private var startedBuild: Set<NodeIdentity> = []
    public private(set) var _completedBuildKeys: [String] = []

    public func _drainBuildTasks() -> [(id: NodeIdentity, action: () async -> Void)] {
        defer { pendingBuild = [] }
        return pendingBuild
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

        var known = Set(previousValues.keys)
        known.formUnion(tasks.keys); known.formUnion(appeared); known.formUnion(disappearActions.keys)
        for id in known where id.isSelfOrDescendant(of: passRoot) && !requested.contains(id) {
            if let t = tasks.removeValue(forKey: id) { t.task.cancel() }
            if let d = disappearActions.removeValue(forKey: id) { queue.append(d) }
            previousValues[id] = nil
            appeared.remove(id)
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
            }
        }
        return queue
    }
}
