// Renderer.swift - Host-agnostic rendering protocol.
//
// `Renderer` decouples the Tag-tree → output flow from any specific host
// (DOM, terminal, native canvas, snapshot test recorder). `DOMRenderer`
// is the production WASM implementation; `TestRenderer` records trees
// and patches for native unit tests; future implementations can target
// terminals (TUI), Cairo/Skia canvases, server-rendered HTML strings,
// etc., all sharing the same Reconciler and Tag conversion machinery.

import SwiftWUICore
import SwiftWUIStyles

/// A renderer that mounts a SwiftWUI tag tree into a host and applies
/// subsequent updates as the tree's state changes.
///
/// Implementations are responsible for (a) resolving a Tag tree into a
/// `TagNode` virtual DOM via `resolveTagBody`, (b) diffing successive
/// snapshots through `Reconciler`, and (c) translating the resulting
/// patches into host-specific operations.
///
/// `Renderer` does not prescribe an observation loop — that lives in
/// `Application` (WASM) or in test setup code (native). Implementations
/// only need to support point-in-time `render` (initial) and `update`
/// (subsequent) calls; the observation loop drives them.
public protocol Renderer: AnyObject {
    /// Mount the supplied tag tree as the initial render. Implementations
    /// should perform whatever host setup is needed (creating DOM nodes,
    /// snapshotting state, etc.) and remember the resolved `TagNode` so
    /// the next call to `update` can diff against it.
    func render<T: Tag>(_ rootTag: T)

    /// Re-render with a new tag tree. The renderer diffs against the
    /// previously rendered tree and applies any resulting patch.
    /// `animation`, if non-nil, hints that style transitions should
    /// animate during this update; renderers that do not support
    /// animation simply ignore it.
    func update<T: Tag>(_ rootTag: T, animation: Animation?)
}

/// A renderer that produces a one-shot HTML string for SSR / SSG.
///
/// Distinct from `Renderer` because the SSR pipeline does not maintain a
/// previous tree to diff against — each call is independent. Vapor
/// request handlers and the static-site builder both consume this.
public protocol StringRendering {
    /// Render a tag tree to an HTML fragment.
    func renderFragment<T: Tag>(_ rootTag: T) -> String
}
