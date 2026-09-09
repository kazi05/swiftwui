# Document and viewport observation

Observe page visibility and the visual viewport without changing the server-rendered tree.

## Overview

Use `onDocumentVisibilityChange(initial:_:)` to receive whether
`document.visibilityState` is `visible`. This value is independent of window
focus and application modal state.

Use `onVisualViewportChange(initial:_:)` to receive a coherent snapshot of the
visual viewport. Width, height, offsets, and `layoutViewportHeight` are measured
in CSS pixels; `scale` is the browser's visual scale. When `visualViewport` is
unavailable, width and height fall back to the window dimensions, offsets are
zero, and scale is `1`.

Both modifiers deliver a current value after the accepted client commit when
`initial` is `true`, which is the default. Pass `initial: false` to receive only
later changes. Each subscriber suppresses equal values, uses the latest callback
after a rerender, and stops receiving callbacks when it unmounts. Static and
server-side rendering do not invoke either callback or read browser state.

The geometric space below the visual viewport can be calculated as follows:

```swift
max(0, metrics.layoutViewportHeight - metrics.height - metrics.offsetTop)
```

This is a bottom offset derived from viewport geometry, not a software-keyboard
detection API. Application read eligibility also depends on whether content
intersects the screen and whether application overlays obscure it.

<!-- viewport-example:start -->
```swift
import SwiftWUI

struct ComposerViewportStatus: Tag {
    @State private var visible: Bool? = nil
    @State private var metrics: VisualViewportMetrics? = nil
    private var bottomOffset: Double {
        guard let metrics else { return 0 }
        return max(0, metrics.layoutViewportHeight - metrics.height - metrics.offsetTop)
    }
    var body: some Tag {
        Div {
            Text(visible == true ? "Document visible" : "Waiting or hidden")
            Text("Composer bottom offset: \(bottomOffset) CSS pixels")
        }
        .onDocumentVisibilityChange { visible = $0 }
        .onVisualViewportChange { metrics = $0 }
    }
}
```
<!-- viewport-example:end -->

SwiftWUI verifies real resize behavior in desktop Chromium and uses controlled
browser events for visibility, offsets, scale, and the missing-API fallback.
Physical software-keyboard resizing, pinch zoom on a device, and Safari behavior
require separate device testing and are not covered by that suite.
