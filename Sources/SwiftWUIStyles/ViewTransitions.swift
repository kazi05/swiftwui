// ViewTransitions.swift - Native browser View Transitions API support.
//
// The View Transitions API (Chrome 111+, Safari 18+, Firefox 130+, all
// major browsers as of 2025) animates between DOM states with browser-
// native cross-fades, and morphs matched-name elements between renders
// when paired with the `view-transition-name` CSS property.
//
// SwiftWUI exposes the static side here — the modifier that stamps a
// `view-transition-name` onto an element so the browser can match it
// across renders. The runtime wrapper that calls `startViewTransition`
// lives in `DOMBridge`/`Application` and is platform-gated to WASM.

import SwiftWUICore

extension Tag {
    /// Assign a `view-transition-name` to this element. When two renders
    /// share the same name on different elements, the browser morphs
    /// between them (position, size, opacity) during a view transition.
    /// `none` disables matching — useful inside lists where you only
    /// want SOME items to morph.
    ///
    /// ```swift
    /// Img(src: thumbURL, alt: "")
    ///     .viewTransitionName("photo-\(photo.id)")
    /// ```
    public func viewTransitionName(_ name: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self, styles: [("view-transition-name", name)])
    }
}
