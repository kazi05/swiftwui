/// Locates the node with exactly `id`, pruning by identity-prefix descent.
func findNode(_ node: Node, at id: NodeIdentity) -> Node? {
    switch node {
    case .text: return nil
    case .element(let e):
        if e.identity == id { return node }
        guard id.isSelfOrDescendant(of: e.identity) else { return nil }
        for c in e.children { if let f = findNode(c, at: id) { return f } }
        return nil
    case .component(let c):
        if c.identity == id { return node }
        guard id.isSelfOrDescendant(of: c.identity) else { return nil }
        for ch in c.children { if let f = findNode(ch, at: id) { return f } }
        return nil
    }
}

/// Indexes several disjoint pass roots with one tree traversal. A burst that
/// dirties many siblings must not repeat `findNode` from the root for each one.
func findNodes(_ node: Node, at identities: Set<NodeIdentity>) -> [NodeIdentity: Node] {
    var result: [NodeIdentity: Node] = [:]
    result.reserveCapacity(identities.count)
    func visit(_ node: Node) {
        switch node {
        case .text:
            return
        case .element(let element):
            if identities.contains(element.identity) { result[element.identity] = node }
            for child in element.children { visit(child) }
        case .component(let component):
            if identities.contains(component.identity) { result[component.identity] = node }
            for child in component.children { visit(child) }
        }
    }
    visit(node)
    return result
}

/// Copy-on-write replacement of the subtree rooted at `id` (spec §2.3 step 5).
func splicing(_ tree: Node, at id: NodeIdentity, with replacement: Node) -> Node {
    switch tree {
    case .text: return tree
    case .element(var e):
        if e.identity == id { return replacement }
        guard id.isSelfOrDescendant(of: e.identity) else { return tree }
        e.children = e.children.map { splicing($0, at: id, with: replacement) }
        return .element(e)
    case .component(var c):
        if c.identity == id { return replacement }
        guard id.isSelfOrDescendant(of: c.identity) else { return tree }
        c.children = c.children.map { splicing($0, at: id, with: replacement) }
        return .component(c)
    }
}


/// Copy-on-write replacement for several disjoint roots in one traversal.
/// Returns existing node values for branches with no replacement descendant,
/// keeping both work and allocations linear in the committed tree size.
func splicing(_ tree: Node, with replacements: [NodeIdentity: Node]) -> Node {
    func replace(_ node: Node) -> (node: Node, changed: Bool) {
        switch node {
        case .text:
            return (node, false)
        case .element(var element):
            if let replacement = replacements[element.identity] {
                return (replacement, true)
            }
            var children = element.children
            var changed = false
            for index in children.indices {
                let result = replace(children[index])
                if result.changed {
                    children[index] = result.node
                    changed = true
                }
            }
            guard changed else { return (node, false) }
            element.children = children
            return (.element(element), true)
        case .component(var component):
            if let replacement = replacements[component.identity] {
                return (replacement, true)
            }
            var children = component.children
            var changed = false
            for index in children.indices {
                let result = replace(children[index])
                if result.changed {
                    children[index] = result.node
                    changed = true
                }
            }
            guard changed else { return (node, false) }
            component.children = children
            return (.component(component), true)
        }
    }
    return replace(tree).node
}
