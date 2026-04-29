// AnchorPositioning.swift - CSS Anchor Positioning modifiers.
//
// CSS Anchor Positioning (Chrome 125+, Safari 18+) lets one element
// position itself relative to another without JavaScript. Pair an
// anchor element (the one being referenced) with a positioned target
// (the one snapping to the anchor's geometry):
//
// ```swift
// Button(...) { "Trigger" }
//     .anchorName("--menu-trigger")
//
// Div { ... popover content ... }
//     .positionAnchor("--menu-trigger")
//     .style("position", "absolute")
//     .style("top", "anchor(--menu-trigger bottom)")
//     .style("left", "anchor(--menu-trigger left)")
// ```

import SwiftWUICore

extension Tag {
    /// Declare this element as a CSS anchor named `name`. Other
    /// elements can reference it via `position-anchor: <name>` and
    /// `top: anchor(<name> ...)`. Names must start with `--`.
    public func anchorName(_ name: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("anchor-name", name)])
    }

    /// Anchor this element to a previously-named anchor. Pairs with
    /// `top: anchor(<name> top)` etc on the same element.
    public func positionAnchor(_ name: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("position-anchor", name)])
    }
}
