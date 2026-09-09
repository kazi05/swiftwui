# Visibility Roots

Observe an element against the viewport or a named ancestor with typed margins.

## Mark an ancestor

Use ``HTMLTag/visibilityRoot(id:)`` to mark an HTML element as an observation
root, then select it with ``VisibilityRoot/ancestor(id:)``:

<!-- visibility-example:start -->
```swift
import SwiftWUI

struct TimelineIntersectionStatus: Tag {
    let isMobile: Bool
    @State private var intersects = false

    var body: some Tag {
        Section {
            Div {
                Div { Text("Message") }
                    .onVisibilityChange(
                        threshold: 0.5,
                        root: isMobile ? .viewport : .ancestor(id: "chat-timeline"),
                        rootMargin: .init(top: .px(-48), bottom: .px(-64))
                    ) {
                        intersects = $0
                    }
            }
            .attribute("style", "height:320px;overflow:auto")
            .visibilityRoot(id: "chat-timeline")

            P {
                Text(intersects ? "Message intersects reading root" : "Outside reading root")
            }
        }
    }
}
```
<!-- visibility-example:end -->

A visibility-root name is a lexical SwiftWUI marker. It does not set an HTML
`id` and is not a CSS selector. Resolution walks the framework element tree and
uses the nearest marked ancestor with the requested name. The observed target
itself is excluded, so placing a matching marker on the target does not make it
its own root. Nested markers with the same name shadow outer markers, and
separate component instances can reuse a name.

When no matching ancestor is mounted, the observation is inactive. SwiftWUI
reports `false` after the mount commit and creates no native observer. A later
render that makes the root available starts observation against that exact
mounted element.

## Configure intersection geometry

``VisibilityMargin`` accepts pixel and percentage values on all four edges.
Positive values expand the root rectangle and negative values shrink it. As
defined by the browser's [Intersection Observer
contract](https://w3c.github.io/IntersectionObserver/#intersection-observer-interface),
percentages on every edge, including top and bottom, are based on the root's
width.

The threshold must be finite and in `0...1`. A callback receives `true` only
when the browser reports an intersection and the intersection ratio meets the
threshold. Changing the selected root, threshold, or margin disconnects the old
binding and starts a new one. Removing the target deactivates its binding at
logical unmount, including while an exit transition keeps the old DOM element
visible.

An explicit root uses native ancestor geometry. Its target can intersect even
when the entire root is outside the viewport. The callback therefore reports
intersection geometry; it does not establish read eligibility or account for
arbitrary overlays. Combine it with the document and application state needed
by your interface.

The existing ``HTMLTag/onVisibilityChange(threshold:_:)`` overload remains the
convenience for viewport observation with no configured margin. Use the
`root:` overload when the observation boundary must be explicit.
