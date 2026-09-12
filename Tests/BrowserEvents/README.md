# Browser events, observer roots, and file resource regressions

This small WASM application exercises the actual SwiftWUIDOM event decoder,
listeners, IntersectionObserver callback, Blob storage, upload transport, and
typed temporary URL rendering. The test suite reuses the
Playwright dependency in `Sites/Tutorial/tools/screenshots`.

Requirements: Swift 6.3.3 with `swift-6.3.3-RELEASE_wasm`, Node/npm, Python 3,
curl, and Playwright's Chromium browser. If Chromium is not installed, run
`npx playwright install chromium` from the existing screenshots harness after
`npm ci` there.

From the repository root:

```sh
bash Tests/BrowserEvents/run.sh
```

`SWIFTWUI_BROWSER_PORT` overrides port 4175. `SWIFTWUI_BROWSER_SDK` selects a
different installed WASM SDK; its version must match the selected host Swift.
Extra arguments are forwarded to Playwright, for example `--grep IME`.

Coverage:

- Actual clipped geometry at 10%, 50%, 60%, and 100%; outside and zero-area targets.
- Controlled IntersectionObserver batches delivered to the real Swift callback,
  including `isIntersecting: true` below threshold and delivery after unmount.
  This explicit case is necessary because browser implementations can mask the
  missing ratio comparison in the geometry-only checks.
- Real explicit-root geometry, including clipping, negative viewport margins,
  native offscreen-root semantics, and nearest-marker shadowing.
- Root option changes, missing roots without observer construction, subtree
  replacement against a new exact host, and configured-observer cancellation
  during logical exit while the transition ghost remains. Cancellation also
  drains queued records before releasing the Swift callback.
- Real Enter/Shift+Enter default actions in a textarea; copied-payload cancellation,
  repeat handling, empty/disabled sending, and cancellation after the callback.
- Composition flags and legacy key-code 229 delivered through DOM KeyboardEvents,
  including keyup. These simulate IME signals; they do not automate an OS IME.
- Selected File and native Blob slice upload identity, with spies detecting
  unintended full-file reads. Explicit slice reads and byte-backed uploads have
  separate byte-content assertions.
- Img, Video, Audio, and A resource attributes; raw/localized replacements;
  shared handles, independent mappings, and explicit/fallback revocation.
- Upload after clearing a file input or revoking a preview, existing Data
  requests, pre-cancelled and in-flight operations, response-body cancellation,
  and header/body timeouts against the local fixture HTTP server.
- Real desktop Chromium resize events with coherent six-field visual viewport
  snapshots and listener reuse across component remounts.
- Controlled document visibility, visual viewport offsets and scale, missing
  `visualViewport` fallback, discarded-backend cleanup, and shared animation
  listener behavior in both installation orders.

The viewport coverage uses desktop Chromium. Controlled events validate payload
plumbing, but the suite does not exercise a physical software keyboard, pinch
zoom on a device, or Safari.

The fixture uses JavaScriptKit 0.56.1, matching the repository's resolved
dependency, and installs only the WASI runtime emitted by its packager.
