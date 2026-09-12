@MainActor
final class SnapshotSubscriptionHub<Value: Equatable> {
    nonisolated deinit { }
    private struct Subscriber {
        let generation: UInt64
        let initial: Bool
        var action: (Value) -> Void
        var committed = false
        var active = false
        var lastEnqueued: Value?
        var lastDelivered: Value?
        var deliveredRevision: UInt64?
    }
    private struct Delivery {
        let id: NodeIdentity
        let generation: UInt64
        let value: Value
        let revision: UInt64
    }
    private let begin: (@escaping (Value) -> Void) -> Value?
    private let schedule: (@escaping () -> Void) -> Void
    private var subscribers: [NodeIdentity: Subscriber] = [:]
    private var latest: Value?
    private var revision: UInt64 = 0
    private var generation: UInt64 = 0
    private var began = false
    private var cancelled = false
    private var adoptionAccepted = true
    private var activationScheduled = false

    init(begin: @escaping (@escaping (Value) -> Void) -> Value?,
         schedule: @escaping (@escaping () -> Void) -> Void) {
        self.begin = begin
        self.schedule = schedule
    }
    func subscribe(id: NodeIdentity, initial: Bool, action: @escaping (Value) -> Void) {
        guard !cancelled else { return }
        if var old = subscribers[id] {
            old.action = action
            subscribers[id] = old
            return
        }
        generation += 1
        subscribers[id] = Subscriber(generation: generation, initial: initial, action: action)
    }
    func unsubscribe(id: NodeIdentity) { subscribers[id] = nil }
    func deferUntilAdoption() { adoptionAccepted = false }
    func acceptAdoption() {
        adoptionAccepted = true
        scheduleActivationIfNeeded()
    }
    func commit() {
        for id in Array(subscribers.keys) { subscribers[id]?.committed = true }
        scheduleActivationIfNeeded()
    }
    func cancelAll() {
        cancelled = true
        subscribers.removeAll()
    }
    private func scheduleActivationIfNeeded() {
        guard !cancelled, adoptionAccepted, !activationScheduled,
              subscribers.values.contains(where: { $0.committed && !$0.active }) else { return }
        activationScheduled = true
        schedule { [weak self] in self?.activateCommitted() }
    }
    private func activateCommitted() {
        activationScheduled = false
        guard !cancelled, adoptionAccepted else { return }
        let pending = subscribers.compactMap { id, sub in
            sub.committed && !sub.active ? (id, sub.generation) : nil
        }
        guard !pending.isEmpty else { return }
        if !began {
            began = true
            let before = revision
            let snapshot = begin { [weak self] value in self?.receive(value) }
            if revision == before { latest = snapshot }
        }
        var deliveries: [Delivery] = []
        for (id, generation) in pending {
            guard var sub = subscribers[id], sub.generation == generation else { continue }
            sub.active = true
            sub.lastEnqueued = latest
            if !sub.initial, let latest {
                sub.lastDelivered = latest
                sub.deliveredRevision = revision
            }
            subscribers[id] = sub
            if sub.initial, let latest {
                deliveries.append(Delivery(id: id, generation: generation,
                                           value: latest, revision: revision))
            }
        }
        for delivery in deliveries { enqueue(delivery) }
    }
    private func receive(_ value: Value) {
        guard !cancelled else { return }
        revision += 1
        latest = value
        var deliveries: [Delivery] = []
        for id in Array(subscribers.keys) {
            guard var sub = subscribers[id], sub.active, sub.lastEnqueued != value else { continue }
            sub.lastEnqueued = value
            subscribers[id] = sub
            deliveries.append(Delivery(id: id, generation: sub.generation,
                                       value: value, revision: revision))
        }
        for delivery in deliveries { enqueue(delivery) }
    }
    private func enqueue(_ delivery: Delivery) {
        schedule { [weak self] in
            guard let self, !self.cancelled, self.adoptionAccepted,
                  var sub = self.subscribers[delivery.id], sub.active,
                  sub.generation == delivery.generation,
                  sub.deliveredRevision.map({ delivery.revision >= $0 }) ?? true else { return }
            sub.deliveredRevision = delivery.revision
            let changed = sub.lastDelivered != delivery.value
            sub.lastDelivered = delivery.value
            self.subscribers[delivery.id] = sub
            if changed { sub.action(delivery.value) }
        }
    }
}
