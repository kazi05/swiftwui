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
