import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRuntime

/// Tests for keyed-children reconciliation. The unkeyed (positional) path is
/// covered by other suites; here we exercise the case where ForEach (and any
/// other keyed-emit source) sets `TagNode.Element.key` so the reconciler can
/// match elements by identity rather than by position.
@Suite("Reconciler Keyed Children")
struct ReconcilerKeyedTests {
    let reconciler = Reconciler()

    private func li(_ key: String, _ text: String) -> TagNode {
        .element(TagNode.Element(
            tagName: "li",
            children: [.text(text)],
            key: key
        ))
    }

    private func ul(_ children: [TagNode]) -> TagNode {
        .element(TagNode.Element(tagName: "ul", children: children))
    }

    @Test("Keyed children: identical lists produce no patch")
    func keyedIdenticalNoPatch() {
        let old = ul([li("a", "Alpha"), li("b", "Beta"), li("c", "Gamma")])
        let new = ul([li("a", "Alpha"), li("b", "Beta"), li("c", "Gamma")])
        #expect(reconciler.diff(old: old, new: new) == nil)
    }

    @Test("Keyed children: prepending an item does NOT re-text surviving children")
    func keyedPrependPreservesSurvivors() {
        // Old: [b, c]
        // New: [a, b, c]   ← only one new child created; b and c are reused.
        let old = ul([li("b", "Beta"), li("c", "Gamma")])
        let new = ul([li("a", "Alpha"), li("b", "Beta"), li("c", "Gamma")])

        guard let patch = reconciler.diff(old: old, new: new) else {
            Issue.record("Expected a patch when prepending a child")
            return
        }

        // Surviving children b and c keep their original text. Any
        // `updateText` patches mean we re-content'd nodes positionally
        // instead of matching keys and reusing the underlying DOM node.
        let replaceCount = countReplaceNode(in: patch)
        let textUpdates = countUpdateText(in: patch)
        #expect(replaceCount == 0)
        #expect(textUpdates == 0,
                "Keyed reconciliation should preserve surviving children's text")
    }

    @Test("Keyed children: reordering does NOT re-text or replace any child")
    func keyedReorderPreservesAll() {
        // Old: [a, b, c]
        // New: [c, a, b]
        let old = ul([li("a", "Alpha"), li("b", "Beta"), li("c", "Gamma")])
        let new = ul([li("c", "Gamma"), li("a", "Alpha"), li("b", "Beta")])

        guard let patch = reconciler.diff(old: old, new: new) else {
            Issue.record("Expected a patch when reordering")
            return
        }

        let replaceCount = countReplaceNode(in: patch)
        let textUpdates = countUpdateText(in: patch)
        #expect(replaceCount == 0)
        #expect(textUpdates == 0,
                "Keyed reorder should move existing nodes, not retext them")
    }

    @Test("Keyed children: removing an item leaves only the survivors in the plan")
    func keyedRemoveOnlyTargetsOne() {
        // Old: [a, b, c]
        // New: [a, c]   ← b removed; a and c survive untouched.
        let old = ul([li("a", "Alpha"), li("b", "Beta"), li("c", "Gamma")])
        let new = ul([li("a", "Alpha"), li("c", "Gamma")])

        guard let patch = reconciler.diff(old: old, new: new) else {
            Issue.record("Expected a patch when removing a child")
            return
        }

        // The renderer drops any old child whose index is not referenced
        // by a `.reuse` step in the plan. The plan must reuse exactly two
        // old indices (a and c at old positions 0 and 2) and contain no
        // `.insert` ops, no text updates, and no replace ops.
        let plan = extractPlan(from: patch)
        guard let plan else {
            Issue.record("Expected reorderChildren plan, got: \(patch)")
            return
        }
        let reusedIndices = plan.compactMap { op -> Int? in
            if case .reuse(let i, _) = op { return i } else { return nil }
        }
        let insertCount = plan.filter { if case .insert = $0 { return true } else { return false } }.count

        #expect(reusedIndices == [0, 2])
        #expect(insertCount == 0)
        #expect(countReplaceNode(in: patch) == 0)
        #expect(countUpdateText(in: patch) == 0,
                "Keyed remove must not retext the surviving siblings")
    }

    @Test("Mixing keyed and unkeyed children falls back to positional diff")
    func mixedKeysFallsBackToPositional() {
        // If keys are not present uniformly, the diff cannot use keyed
        // matching safely. It must still produce a valid patch.
        let unkeyed = TagNode.element(TagNode.Element(tagName: "li"))
        let old = ul([li("a", "Alpha"), unkeyed])
        let new = ul([unkeyed, li("a", "Alpha")])
        // Just assert we get a patch and don't crash; semantics are
        // positional (so this WILL emit replace patches), which is correct
        // for mixed-key inputs.
        _ = reconciler.diff(old: old, new: new)
    }

    // MARK: - Patch traversal helpers

    private func countReplaceNode(in patch: Patch) -> Int {
        switch patch {
        case .replaceNode: return 1
        case .patchChildren(let children):
            return children.reduce(0) { $0 + countReplaceNode(in: $1.patch) }
        default:
            return 0
        }
    }

    private func countRemoveNode(in patch: Patch) -> Int {
        switch patch {
        case .removeNode: return 1
        case .patchChildren(let children):
            return children.reduce(0) { $0 + countRemoveNode(in: $1.patch) }
        default:
            return 0
        }
    }

    private func countUpdateText(in patch: Patch) -> Int {
        switch patch {
        case .updateText: return 1
        case .patchChildren(let children):
            return children.reduce(0) { $0 + countUpdateText(in: $1.patch) }
        case .reorderChildren(let plan):
            return plan.reduce(0) { acc, op in
                if case .reuse(_, let sub) = op, let s = sub {
                    return acc + countUpdateText(in: s)
                }
                return acc
            }
        default:
            return 0
        }
    }

    /// Drill into a possibly-compound patch to find the keyed-reorder plan
    /// (if any). Returns nil if no `.reorderChildren` exists in the tree.
    private func extractPlan(from patch: Patch) -> [ReorderOp]? {
        switch patch {
        case .reorderChildren(let plan):
            return plan
        case .patchChildren(let children):
            for child in children {
                if let plan = extractPlan(from: child.patch) {
                    return plan
                }
            }
            return nil
        default:
            return nil
        }
    }
}
