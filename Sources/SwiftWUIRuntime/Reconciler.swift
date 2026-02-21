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
    case patchChildren([ChildPatch])
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

        // Diff children
        let childPatches = diffChildren(old: old.children, new: new.children)
        if !childPatches.isEmpty {
            patches.append(.patchChildren(childPatches))
        }

        if patches.isEmpty { return nil }

        // If only one patch, return it directly
        if patches.count == 1 { return patches[0] }

        // Multiple patches need to be applied in sequence — wrap in children patches on self
        // For simplicity, we use a compound approach
        return patches.count == 1 ? patches[0] : .patchChildren(
            childPatches + patches.compactMap { p -> ChildPatch? in
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
