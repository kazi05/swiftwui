enum Patch: Equatable {
    case setText(String)
    case setAttribute(name: String, value: String)
    case removeAttribute(name: String)
    case setListener(event: String, id: ListenerID)
    case removeListener(event: String)
    case replaceSelf(with: Node)
    case updateChildren(ChildrenPlan)
}

struct ChildrenPlan: Equatable {
    enum Slot: Equatable {
        case reuse(oldIndex: Int, patches: [Patch])
        case fresh(Node)
    }
    var slots: [Slot]
    var removedOldIndices: [Int]

    /// True when the plan changes nothing: every slot reuses its own old index
    /// with no patches, in order, covering all old children.
    var isIdentity: Bool {
        guard removedOldIndices.isEmpty else { return false }
        for (i, slot) in slots.enumerated() {
            guard case .reuse(let oldIndex, let patches) = slot,
                  oldIndex == i, patches.isEmpty else { return false }
        }
        return true
    }
}

struct Reconciler {
    init() {}

    func diff(old: Node, new: Node) -> [Patch] {
        if old == new { return [] }
        switch (old, new) {
        case (.text(let o), .text(let n)):
            return o == n ? [] : [.setText(n)]

        case (.element(let o), .element(let n)):
            guard o.identity == n.identity, o.tag == n.tag else {
                return [.replaceSelf(with: new)]
            }
            var patches: [Patch] = []
            for name in n.attributes.keys.sorted() where o.attributes[name] != n.attributes[name] {
                patches.append(.setAttribute(name: name, value: n.attributes[name]!))
            }
            for name in o.attributes.keys.sorted() where n.attributes[name] == nil {
                patches.append(.removeAttribute(name: name))
            }
            for event in n.listeners.keys.sorted() where o.listeners[event] != n.listeners[event] {
                patches.append(.setListener(event: event, id: n.listeners[event]!))
            }
            for event in o.listeners.keys.sorted() where n.listeners[event] == nil {
                patches.append(.removeListener(event: event))
            }
            if !o.children.isEmpty || !n.children.isEmpty {
                let plan = diffChildren(old: o.children, new: n.children)
                if !plan.isIdentity { patches.append(.updateChildren(plan)) }
            }
            return patches

        case (.component(let o), .component(let n)):
            guard o.identity == n.identity else { return [.replaceSelf(with: new)] }
            if !o.children.isEmpty || !n.children.isEmpty {
                let plan = diffChildren(old: o.children, new: n.children)
                return plan.isIdentity ? [] : [.updateChildren(plan)]
            }
            return []

        default:
            return [.replaceSelf(with: new)]
        }
    }

    /// Same-node test (spec §8.3): drives prefix/suffix trim and keyed matching.
    func sameIdentity(_ a: Node, _ b: Node) -> Bool {
        switch (a, b) {
        case (.text, .text): return true
        case (.element(let o), .element(let n)): return o.identity == n.identity && o.tag == n.tag
        case (.component(let o), .component(let n)): return o.identity == n.identity
        default: return false
        }
    }

    func diffChildren(old: [Node], new: [Node]) -> ChildrenPlan {
        fatalError("implemented in Task 10")
    }
}
