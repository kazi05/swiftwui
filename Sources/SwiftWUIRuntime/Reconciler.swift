// Reconciler.swift - Virtual DOM diffing and patching

import SwiftWUICore

/// Diff operations that transform the old virtual DOM into the new one.
public enum Patch: Sendable {
    case createNode(TagNode)
    case removeNode
    case replaceNode(with: TagNode)
    case updateText(String)
    case updateAttributes(add: [String: String], remove: [String])
    case updateStyles(add: [String: String], remove: [String])
    case updateClasses(add: [String], remove: [String])
    case updateEventListeners(add: [String: EventListenerID], remove: [String])
    case updateObservers(new: [WebObserver])
    case patchChildren([ChildPatch])
    /// Keyed-children reorder. Each entry tells the renderer how to assemble
    /// the new child list out of (a) DOM nodes that already exist at the
    /// listed old positions (`reuse`), and (b) brand-new TagNode subtrees
    /// (`insert`). The renderer applies the entries in order, calling
    /// `appendChild` on the reused JSObjects (DOM standard says this *moves*
    /// the node, preserving its identity, focus, scroll, in-flight animations,
    /// and any `@State` storage tied to that DOM node), and finally removes
    /// any old children whose indices were not reused.
    case reorderChildren(plan: [ReorderOp])
}

/// Step in a keyed-reorder plan emitted by `reorderChildren`.
public enum ReorderOp: Sendable {
    /// Reuse the DOM node that was at `oldIndex` in the previous render.
    /// `subPatch`, if non-nil, is applied to the reused node to bring its
    /// content/attributes/etc up to date with the new TagNode.
    case reuse(oldIndex: Int, subPatch: Patch?)
    /// Create a brand-new node from the supplied TagNode and append it.
    case insert(node: TagNode)
}

/// Patch operation for a child node at a given index.
public struct ChildPatch: Sendable {
    public let index: Int
    public let patch: Patch

    public init(index: Int, patch: Patch) {
        self.index = index
        self.patch = patch
    }
}

/// Compares old and new virtual DOM trees and produces a list of patches.
public struct Reconciler: Sendable {

    public init() {}

    /// Compute the diff between two virtual DOM trees.
    public func diff(old: TagNode?, new: TagNode?) -> Patch? {
        switch (old, new) {
        case (.none, .none):
            return nil

        case (.none, .some(let newNode)):
            return .createNode(newNode)

        case (.some, .none):
            return .removeNode

        case (.some(let oldNode), .some(let newNode)):
            return diffNodes(old: oldNode, new: newNode)
        }
    }

    // MARK: - Private

    private func diffNodes(old: TagNode, new: TagNode) -> Patch? {
        switch (old, new) {
        // Text → Text
        case (.text(let oldText), .text(let newText)):
            if oldText != newText {
                return .updateText(newText)
            }
            return nil

        // Element → Element (same tag)
        case (.element(let oldEl), .element(let newEl)) where oldEl.tagName == newEl.tagName:
            return diffElements(old: oldEl, new: newEl)

        // Fragment → Fragment
        case (.fragment(let oldChildren), .fragment(let newChildren)):
            let childPatches = diffChildren(old: oldChildren, new: newChildren)
            if childPatches.isEmpty { return nil }
            return .patchChildren(childPatches)

        // Different node types — replace entirely
        default:
            return .replaceNode(with: new)
        }
    }

    private func diffElements(old: TagNode.Element, new: TagNode.Element) -> Patch? {
        // Check for identity change — force full replacement
        let oldId = old.attributes["data-swiftwui-id"]
        let newId = new.attributes["data-swiftwui-id"]
        if oldId != newId && (oldId != nil || newId != nil) {
            return .replaceNode(with: .element(new))
        }

        var patches: [Patch] = []

        // Diff attributes
        let attrPatch = diffDict(old: old.attributes, new: new.attributes)
        if !attrPatch.add.isEmpty || !attrPatch.remove.isEmpty {
            patches.append(.updateAttributes(add: attrPatch.add, remove: attrPatch.remove))
        }

        // Diff styles
        let stylePatch = diffDict(old: old.styles, new: new.styles)
        if !stylePatch.add.isEmpty || !stylePatch.remove.isEmpty {
            patches.append(.updateStyles(add: stylePatch.add, remove: stylePatch.remove))
        }

        // Diff classes (including generated responsive style classes)
        let oldResponsiveClasses = responsiveClassNames(for: old.responsiveStyles)
        let newResponsiveClasses = responsiveClassNames(for: new.responsiveStyles)
        let oldAllClasses = Set(old.classes).union(oldResponsiveClasses)
        let newAllClasses = Set(new.classes).union(newResponsiveClasses)
        let addClasses = Array(newAllClasses.subtracting(oldAllClasses))
        let removeClasses = Array(oldAllClasses.subtracting(newAllClasses))
        if !addClasses.isEmpty || !removeClasses.isEmpty {
            patches.append(.updateClasses(add: addClasses, remove: removeClasses))
        }

        // Diff event listeners
        let eventPatch = diffEvents(old: old.eventListeners, new: new.eventListeners)
        if !eventPatch.add.isEmpty || !eventPatch.remove.isEmpty {
            patches.append(.updateEventListeners(add: eventPatch.add, remove: eventPatch.remove))
        }

        // Diff observers
        if old.observers != new.observers {
            patches.append(.updateObservers(new: new.observers))
        }

        // Diff children. When both sides are fully keyed (every child is an
        // `.element` with a non-nil `key`, e.g. emitted by `ForEach`), use
        // the keyed-reorder algorithm so DOM nodes physically move rather
        // than have their contents rewritten in place. Otherwise the
        // historical positional diff applies.
        var positionalChildPatches: [ChildPatch] = []
        if let plan = diffKeyedChildren(old: old.children, new: new.children) {
            // Plan is non-empty by definition for non-trivial diffs; treat
            // an all-`.reuse(_, nil)` plan as no-op only when the order is
            // also unchanged, otherwise the renderer will move nodes.
            if !planIsNoOp(plan) {
                patches.append(.reorderChildren(plan: plan))
            }
        } else {
            positionalChildPatches = diffChildren(old: old.children, new: new.children)
            if !positionalChildPatches.isEmpty {
                patches.append(.patchChildren(positionalChildPatches))
            }
        }

        if patches.isEmpty { return nil }

        // If only one patch, return it directly
        if patches.count == 1 { return patches[0] }

        // Multiple patches need to be applied in sequence. Self-modifying
        // patches (attribute/style/class/event/observer updates) get encoded
        // as `ChildPatch(index: -1, patch: …)` entries that the renderer
        // recognises as "apply to self". Keyed reorder patches stay outside
        // this compound — they are emitted alongside.
        return patches.count == 1 ? patches[0] : .patchChildren(
            positionalChildPatches + patches.compactMap { p -> ChildPatch? in
                if case .patchChildren = p { return nil }
                return ChildPatch(index: -1, patch: p)  // -1 means "apply to self"
            }
        )
    }

    private func diffChildren(old: [TagNode], new: [TagNode]) -> [ChildPatch] {
        var patches: [ChildPatch] = []
        let maxCount = max(old.count, new.count)

        for i in 0..<maxCount {
            let oldChild = i < old.count ? old[i] : nil
            let newChild = i < new.count ? new[i] : nil

            if let patch = diff(old: oldChild, new: newChild) {
                patches.append(ChildPatch(index: i, patch: patch))
            }
        }

        return patches
    }

    /// True when the plan is a strict identity (every entry reuses the same
    /// old index it sits at, with no sub-patch). Used to suppress no-op
    /// reorder patches.
    private func planIsNoOp(_ plan: [ReorderOp]) -> Bool {
        for (i, op) in plan.enumerated() {
            switch op {
            case .insert: return false
            case .reuse(let oldIndex, let subPatch):
                if oldIndex != i || subPatch != nil { return false }
            }
        }
        return true
    }

    /// True when every child is an `.element` carrying a non-nil `key`. Mixed
    /// keyed/unkeyed runs fall back to the positional path because matching
    /// some children by key while leaving others positional is ambiguous and
    /// would produce surprising state preservation in practice.
    private func childrenAreFullyKeyed(_ children: [TagNode]) -> Bool {
        guard !children.isEmpty else { return false }
        for child in children {
            guard case .element(let el) = child, el.key != nil else { return false }
        }
        return true
    }

    /// Build a keyed-reorder plan that, when applied, produces `new` from `old`
    /// while preserving the DOM identity of every child whose key survived.
    /// Returns nil if either side is not fully keyed (caller should fall back
    /// to positional diff) or if the lists are identical.
    private func diffKeyedChildren(old: [TagNode], new: [TagNode]) -> [ReorderOp]? {
        guard childrenAreFullyKeyed(old), childrenAreFullyKeyed(new) else { return nil }

        // Build key → old-index map. Duplicate keys in old are not allowed —
        // first occurrence wins, the rest fall through to the unkeyed path.
        var keyToOld: [String: Int] = [:]
        for (i, node) in old.enumerated() {
            guard case .element(let el) = node, let k = el.key else { return nil }
            if keyToOld[k] != nil { return nil }   // duplicate key → bail
            keyToOld[k] = i
        }

        var plan: [ReorderOp] = []
        for newChild in new {
            guard case .element(let newEl) = newChild, let k = newEl.key else {
                // childrenAreFullyKeyed already guarantees this, but bail
                // safely just in case the data shape changes.
                return nil
            }
            if let oldIndex = keyToOld[k] {
                let oldChild = old[oldIndex]
                let sub = diffNodes(old: oldChild, new: newChild)
                plan.append(.reuse(oldIndex: oldIndex, subPatch: sub))
            } else {
                plan.append(.insert(node: newChild))
            }
        }
        return plan
    }

    private func diffDict(
        old: [String: String],
        new: [String: String]
    ) -> (add: [String: String], remove: [String]) {
        var add: [String: String] = [:]
        var remove: [String] = []

        // Find additions and changes
        for (key, value) in new {
            if old[key] != value {
                add[key] = value
            }
        }

        // Find removals
        for key in old.keys {
            if new[key] == nil {
                remove.append(key)
            }
        }

        return (add, remove)
    }

    private func diffEvents(
        old: [String: EventListenerID],
        new: [String: EventListenerID]
    ) -> (add: [String: EventListenerID], remove: [String]) {
        var add: [String: EventListenerID] = [:]
        var remove: [String] = []

        for (event, newID) in new {
            if old[event] != newID {
                add[event] = newID
            }
        }

        for event in old.keys {
            if new[event] == nil {
                remove.append(event)
            }
        }

        return (add, remove)
    }
}
