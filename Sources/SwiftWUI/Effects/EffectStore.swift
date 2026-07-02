enum EffectRequest {
    case onChange(id: NodeIdentity, newValue: Any,
                  isEqual: (Any, Any) -> Bool, initial: Bool,
                  action: (Any, Any) -> Void)
    case task(id: NodeIdentity, taskID: AnyHashable?, action: () async -> Void)
    case appear(id: NodeIdentity, action: () -> Void)
    case disappear(id: NodeIdentity, action: () -> Void)

    var id: NodeIdentity {
        switch self {
        case .onChange(let id, _, _, _, _), .task(let id, _, _),
             .appear(let id, _), .disappear(let id, _): return id
        }
    }
}

/// Effect lifecycle (spec §5.3–5.4): keyed by wrapper identity; sweep
/// set-difference under the pass root = onDisappear / task cancellation.
@MainActor
final class EffectStore {
    private var previousValues: [NodeIdentity: Any] = [:]
    private var tasks: [NodeIdentity: (task: Task<Void, Never>, id: AnyHashable?)] = [:]
    private var appeared: Set<NodeIdentity> = []
    private var disappearActions: [NodeIdentity: () -> Void] = [:]

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
            case .task(let id, let taskID, let action):
                if let existing = tasks[id] {
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
