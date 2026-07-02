// TestRenderer.swift - In-memory Renderer for native unit and integration tests.
//
// `TestRenderer` records every rendered TagNode tree and every patch
// produced between renders, with no JavaScriptKit dependency. It runs
// natively on macOS / Linux so application code can be exercised through
// the full Tag → resolveTagBody → Reconciler.diff pipeline inside Swift
// Testing without spinning up a browser.
//
// ```swift
// let r = TestRenderer()
// r.render(MyView(count: 0))
// r.update(MyView(count: 1))
// #expect(r.patches.count == 1)
// ```

import SwiftWUICore
import SwiftWUIStyles

/// A `Renderer` implementation that captures rendered trees and reconciler
/// patches in memory rather than mutating any host. Intended for unit and
/// snapshot tests that want to assert on render output without booting a
/// DOM environment.
public final class TestRenderer: Renderer {
    /// Every TagNode tree that has been rendered, in order. Index 0 is the
    /// initial render; subsequent indices are the post-update trees.
    public private(set) var renderedTrees: [TagNode] = []

    /// Every reconciler patch produced by `update` calls, in order. Index
    /// 0 corresponds to the diff between renderedTrees[0] and [1], etc.
    public private(set) var patches: [Patch] = []

    /// Animation context captured for each `update` call. Aligns 1:1 with
    /// `patches` so tests can assert which updates were animated.
    public private(set) var animations: [Animation?] = []

    private let reconciler = Reconciler()
    private var currentTree: TagNode?
    /// Persists @State across render/update calls via structural identity.
    private let renderContext = RenderContext()

    public init() {}

    public func render<T: Tag>(_ rootTag: T) {
        let tree = TagNode.fragment(renderContext.resolveRoot(rootTag))
        renderedTrees.append(tree)
        currentTree = tree
    }

    public func update<T: Tag>(_ rootTag: T, animation: Animation? = nil) {
        let next = TagNode.fragment(renderContext.resolveRoot(rootTag))
        if let prior = currentTree, let patch = reconciler.diff(old: prior, new: next) {
            patches.append(patch)
            animations.append(animation)
        }
        renderedTrees.append(next)
        currentTree = next
    }

    /// The most recent rendered TagNode tree, or nil if `render` has not
    /// been called yet.
    public var latestTree: TagNode? { currentTree }

    /// Discard all recorded trees, patches, and animations. Useful between
    /// test phases when reusing a single renderer instance.
    public func reset() {
        renderedTrees.removeAll()
        patches.removeAll()
        animations.removeAll()
        currentTree = nil
    }
}
