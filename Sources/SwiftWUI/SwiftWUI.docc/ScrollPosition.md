# Scroll metrics and reading position

Read scroll geometry and preserve a visible row through updates with ``ScrollReader``.

## Choose a scroll container

``ScrollReader`` renders its content without adding an HTML wrapper. Its
``ScrollProxy`` controls either the document window or an element inside the
reader's own subtree. Element and anchor identifiers are exact HTML `id`
strings, assigned with `.id(...)`; a `ForEach` key does not create an HTML ID.

Keep each ID unique. An absent or ambiguous ID is unavailable, and an element
target never falls back to the window. Nested readers have separate lookup
scopes; an outer reader does not search an inner reader's content. An element
anchor must be a descendant of the selected container.

## Preserve a row when prepending history

Capture immediately before the model mutation, then request restoration.
The runtime waits for the actual DOM commit, including deferred View
Transitions. No timer or animation-frame workaround is necessary.

This complete example switches between a fixed-height card and window scrolling
while keeping the same reader. Capture and restore use a row ID and signed
visible-top offset, so a window offset is never reused as an element scrollTop.

<!-- scroll-example:start -->
```swift
import SwiftWUI

struct ReadingHistory: Tag {
    @State private var rows = Array(100..<160)
    @State private var useWindow = false
    @State private var remaining: Double? = nil

    private var elementIDs: [String] { rows.map { "history-row-\($0)" } }

    var body: some Tag {
        ScrollReader(container: useWindow ? .window : .element(id: "history")) { proxy in
            Div {
                Button("Load older rows") {
                    let anchor = proxy.captureAnchor(in: elementIDs)
                    let first = rows.first ?? 100
                    rows.insert(contentsOf: Array((first - 50)..<first), at: 0)
                    if let anchor { proxy.restore(anchor) }
                }
                Button("Switch scroll container") {
                    let anchor = proxy.captureAnchor(in: elementIDs)
                    useWindow.toggle()
                    if let anchor { proxy.restore(anchor) }
                }
                Button("Add a row") {
                    rows.append((rows.last ?? 99) + 1)
                }
                Button("Go to latest") {
                    proxy.scrollToEnd(behavior: .smooth)
                }
                if let remaining {
                    P { Text("Distance to bottom: \(remaining) CSS pixels") }
                }
                Div {
                    ForEach(rows, id: \.self) { row in
                        Div { Text("Row \(row)") }
                            .id("history-row-\(row)")
                            .height(.px(56))
                    }
                }
                .id("history")
                .height(useWindow ? .auto : .px(320))
                .overflowY(useWindow ? .visible : .auto)
                .onScrollChange { _ in
                    if !useWindow { updateDistance(using: proxy) }
                }
            }
            .onWindowScroll { _ in
                if useWindow { updateDistance(using: proxy) }
            }
        }
    }

    private func updateDistance(using proxy: ScrollProxy) {
        guard let value = proxy.metrics() else { return }
        remaining = max(0, value.contentHeight - value.viewportHeight - value.y)
    }
}
```
<!-- scroll-example:end -->

For asynchronous loading, await the response first, then capture immediately
before inserting it. A capture taken before the request could become stale if
the reader scrolls while data loads. Append-only updates do not request any
library scrolling; deciding when incoming messages should follow the end belongs
to the application.

## Geometry and commands

``ScrollMetrics`` contains fresh offsets and layout viewport/content dimensions
in CSS pixels. It preserves fractional and negative browser offsets. Its
viewport does not subtract a fixed composer or header; use size and
<doc:ViewportObservation> hooks for that application layout policy. Read metrics
inside existing `onScrollChange`, `onWindowScroll`, or size callbacks; the proxy
does not create another listener or make rows observe every scroll event.

Capture selects the first visible candidate in caller-supplied reading order.
It intersects the selected scrollport with the visual viewport, accounting for
the element's border. A partially visible row can have a negative
``ScrollAnchor/offsetFromVisibleTop``. An empty candidate list or no eligible row
returns `nil`.

Restoration uses current row geometry and makes one instant vertical correction,
preserving horizontal position. Missing anchors do nothing. The browser clamps
an unreachable position. An entirely offscreen element container has no visible
rectangle to restore against. If several commands are queued on the same reader,
the last command wins. A container switch on the same mounted reader preserves
that pending intent.

`scrollToEnd()` targets the physical bottom of the chosen container. For window
scrolling, this includes any document content after the reader. Its default
behavior is `.instant`; an explicit `.smooth` request becomes instant when
reduced motion is enabled at execution time. ``ScrollProxy/Behavior`` is
separate from the existing CSS ``ScrollBehavior`` type. Instant restoration
overrides page CSS smooth scrolling.

## Lifetime and limits

A proxy belongs to one mount. Removing its reader permanently disables the old
proxy, even if the reader later reappears at the same structural position.
Queued commands are cancelled on removal and runtime cancellation.

Reads observe committed DOM and return `nil` during body evaluation, provisional
hydration, static rendering, or after removal. Commands in body evaluation and
static rendering are ignored. Provisional hydration lifecycle commands are held
until adoption succeeds and discarded if that attempt is rejected. Metrics and
anchors are Codable value snapshots; the proxy and command queue are transient.

DOM commands run through a deferred microtask. A custom native runtime needs a
deferred `scheduleMicrotask` to coalesce every statement of an application
callback in the same way. A synchronous test scheduler still respects active
render-batch boundaries.

The API supports ordinary vertical flow. It does not infer fixed/sticky overlays,
intermediate clipping ancestors, transformed coordinate systems, reverse flow,
horizontal anchoring, or scroll snapping. Capture alone does not establish that
a message can be marked read. Media changes after a correction do not establish
permanent position locking; reserve media dimensions or request an explicit
restoration around a later application-controlled change.
