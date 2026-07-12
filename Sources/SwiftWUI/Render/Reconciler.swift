enum Patch: Equatable {
    case setText(String)
    case setAttribute(name: String, value: String)
    case removeAttribute(name: String)
    case setProperty(name: String, value: PropertyValue)
    case setListener(event: String, id: ListenerID)
    case removeListener(event: String)
    case setObserver(kind: ObserverKind, id: ListenerID)
    case removeObserver(kind: ObserverKind)
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
            for name in n.properties.keys.sorted() where o.properties[name] != n.properties[name] {
                patches.append(.setProperty(name: name, value: n.properties[name]!))
            }
            for name in o.properties.keys.sorted() where n.properties[name] == nil {
                // property "removal" = write the neutral value (spec §7: value="" clears, checked=false unchecks)
                switch o.properties[name]! {
                case .string: patches.append(.setProperty(name: name, value: .string("")))
                case .bool:   patches.append(.setProperty(name: name, value: .bool(false)))
                }
            }
            for event in n.listeners.keys.sorted() where o.listeners[event] != n.listeners[event] {
                patches.append(.setListener(event: event, id: n.listeners[event]!))
            }
            for event in o.listeners.keys.sorted() where n.listeners[event] == nil {
                patches.append(.removeListener(event: event))
            }
            for kind in n.observers.keys.sorted(by: { $0.key < $1.key })
                where o.observers[kind] != n.observers[kind] {
                patches.append(.setObserver(kind: kind, id: n.observers[kind]!))
            }
            for kind in o.observers.keys.sorted(by: { $0.key < $1.key })
                where n.observers[kind] == nil {
                patches.append(.removeObserver(kind: kind))
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
        var start = 0
        while start < old.count && start < new.count && sameIdentity(old[start], new[start]) {
            start += 1
        }
        var endOld = old.count
        var endNew = new.count
        while endOld > start && endNew > start && sameIdentity(old[endOld - 1], new[endNew - 1]) {
            endOld -= 1; endNew -= 1
        }

        var slots: [ChildrenPlan.Slot] = []
        var usedOld = Set<Int>()

        for i in 0..<start {
            slots.append(.reuse(oldIndex: i, patches: diff(old: old[i], new: new[i])))
            usedOld.insert(i)
        }

        // Middle: keyed map + positional keyless matching.
        var keyToOld: [NodeKey: Int] = [:]
        for i in start..<endOld {
            if let k = old[i].key {
                assert(keyToOld[k] == nil, "duplicate key in child list")   // last-wins in release
                keyToOld[k] = i
            }
        }
        let unkeyedOld = (start..<endOld).filter { old[$0].key == nil }
        var unkeyedCursor = 0

        for j in start..<endNew {
            let n = new[j]
            if let k = n.key {
                if let oi = keyToOld[k], !usedOld.contains(oi), sameIdentity(old[oi], n) {
                    slots.append(.reuse(oldIndex: oi, patches: diff(old: old[oi], new: n)))
                    usedOld.insert(oi)
                } else {
                    slots.append(.fresh(n))
                }
            } else {
                while unkeyedCursor < unkeyedOld.count && usedOld.contains(unkeyedOld[unkeyedCursor]) {
                    unkeyedCursor += 1
                }
                if unkeyedCursor < unkeyedOld.count, sameIdentity(old[unkeyedOld[unkeyedCursor]], n) {
                    let oi = unkeyedOld[unkeyedCursor]
                    unkeyedCursor += 1
                    slots.append(.reuse(oldIndex: oi, patches: diff(old: old[oi], new: n)))
                    usedOld.insert(oi)
                } else {
                    slots.append(.fresh(n))
                }
            }
        }

        for offset in 0..<(new.count - endNew) {
            let oi = endOld + offset
            let nj = endNew + offset
            slots.append(.reuse(oldIndex: oi, patches: diff(old: old[oi], new: new[nj])))
            usedOld.insert(oi)
        }

        let removed = (0..<old.count).filter { !usedOld.contains($0) }
        return ChildrenPlan(slots: slots, removedOldIndices: removed)
    }
}
