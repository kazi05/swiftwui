@MainActor
public final class ListenerRegistry {
    nonisolated deinit { }
    private var handlers: [ListenerID: (Any?) -> Void] = [:]
    public init() {}

    func set(_ id: ListenerID, handler: @escaping () -> Void) { handlers[id] = { _ in handler() } }
    func set(_ id: ListenerID, payloadHandler: @escaping (Any?) -> Void) { handlers[id] = payloadHandler }
    func handler(for id: ListenerID) -> ((Any?) -> Void)? { handlers[id] }

    /// Keep-set = ListenerIDs present in the newly resolved tree (spec decision 21).
    /// NEVER ctx.reachable (component ids only — would empty the registry).
    func sweep(under root: NodeIdentity, keep: Set<ListenerID>) {
        for id in Array(handlers.keys)
        where id.owner.isSelfOrDescendant(of: root) && !keep.contains(id) {
            handlers.removeValue(forKey: id)
        }
    }

    var count: Int { handlers.count }
}
