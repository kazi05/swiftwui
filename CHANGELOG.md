# Changelog

Notable changes to SwiftWUI. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions match the
`v<version>` git tags described in `Sources/SwiftWUIToolchain/SwiftWUIVersion.swift`.

## [0.5.0] - 2026-07-16

Drag & drop and file input: HTML5 drag/drop for both OS files and typed
in-app payloads, plus a click-to-pick file dialog and a drag-reorderable
`ForEach`.

### Added

- `.draggable(_:isDragged:)` / `.dropDestination(for:allowedTypes:action:isTargeted:)`
  (`WebFile`) and `.dropDestination(for:action:isTargeted:)` (typed
  `DragPayload`) — HTMLTag drag sources and drop zones.
- `DragPayload` protocol (Codable-backed) for custom drag payloads; encoded
  into DOM attributes at render time and travels via the OS drag pasteboard
  — visible in the DOM, so never put secrets in a payload.
- `FileType` (UTType analog: `.image`, `.pdf`, `.zip`, …), `.fileImporter(
  isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)`
  for a click-to-pick file dialog, and typed file drop zones.
- `@Environment(\.dragSession)` — window-level signal for whether something
  is being dragged over the page right now, and whether it includes files.
- `.preventsAccidentalDropNavigation()` — guards against the classic
  drag-and-drop footgun where a file dropped outside any zone navigates the
  tab away.
- `ForEach.onMove(axis:perform:)` — drag-to-reorder rows with live preview
  (shifting siblings, dimmed source); `action` receives `(fromIndex,
  toInsertionOffset)`, not SwiftUI's `IndexSet` (would pull ~40 MB of
  Foundation/ICU into the wasm bundle for no benefit over HTML5's
  single-item drags).
- Reserved DOM contract: `swui:cmd:` property-command channel and
  `data-swui-*` attribute prefix — framework-owned, don't set by hand.

### Example

- `Examples/DragDrop` — acceptance app exercising every state above, plus
  `ACCEPTANCE.md` manual browser checklist.

## v0.4.0 — 2026-07-15

Typed style-modifier expansion: ~150 new typed CSS modifiers so real
web-apps rarely need the `.style("prop","val")` string escape. Purely
additive — no existing modifier changed; the escape hatch stays for the
deliberate long tail.

### Added — CSS value types

- `CSSLength` gained intrinsic sizing (`.minContent`, `.maxContent`,
  `.fitContent(_)`) and the mobile-safe viewport units
  (`.dvh/.svh/.lvh/.dvw/.svw/.lvw/.vmin/.vmax/.ch`).
- `Overflow` gained `.clip`; `Display` gained the table/`list-item`/
  `flow-root`/`inline-grid` family; `Cursor` gained ~28 keywords
  (resize directions, `grabbing`, `zoom-in/out`, …).
- New value types: `CSSAngle`, `CSSDuration`, `TimingFunction`, `Shadow`
  (box + text), `BlendMode`, `GridLine`, `BorderRadius` (per-corner),
  `FilterFunction`, `TransformFunction`, `CSSBackgroundImage` (linear/
  radial/conic gradients + `url()`), `ObjectPosition`, `BackgroundPosition`,
  `BackgroundSize`, `AspectRatio`, and dedicated `JustifyItems`/
  `JustifySelf`/`AlignContent`.

### Added — modifiers

- Layout/box: `overflowX/Y`, `objectFit`, `objectPosition`, `aspectRatio`,
  `visibility`, `inset`, logical `margin*/padding*/inset*` (inline/block),
  `min/maxInlineSize`, `min/maxBlockSize`, `rowGap`/`columnGap`/
  `gap(row:column:)`, `order`, `float`, `clear`, `isolation`.
- Flex/grid: `justifyItems`, `justifySelf`, `alignContent`, `placeContent/
  Items/Self`, `gridAutoFlow`, `grid{Column,Row}[Start/End]`, `gridArea`,
  `gridTemplateAreas`, `flex`, `flexFlow`.
- Typography: `whiteSpace`, `textTransform`, `textOverflow`, `lineClamp`,
  `textDecoration{Line,Color,Style,Thickness}`, `textIndent`, `textShadow`,
  `wordBreak`, `overflowWrap`, `verticalAlign`, `lineHeight(CSSLength)`,
  `listStyleType/Position`, `textWrap`, `fontVariant/Numeric`, `fontStyle`,
  `fontStretch`, `fontOpticalSizing`, `fontSmoothing`, `textAlignLast`,
  `textUnderlineOffset`, `wordSpacing`, `hyphens`, `direction`, `caretColor`,
  `textStroke`.
- Backgrounds/borders: `backgroundColor/Image/Repeat/Position/Size/
  Attachment/Origin/Clip/BlendMode`, per-side `border`/`borderWidth/Style/
  Color`, per-corner `borderRadius`, `outline{Width,Style,Color,Offset}`,
  `boxShadow(Shadow…)`, `borderCollapse`, `tableLayout`, `borderSpacing`.
- Effects/motion: `filter`, `backdropFilter`, `mixBlendMode`, `clipPath`,
  `transform`, `transformStyle`, `perspective`, `backfaceVisibility`,
  `willChange`, `transition(property:duration:timingFunction:delay:)` (typed;
  `cssTransition(String)` unchanged), `transitionDuration/TimingFunction/
  Delay`, `contentVisibility`, `containIntrinsicSize`.
- Interactivity/misc: `pointerEvents`, `userSelect`, `touchAction`,
  `scrollBehavior`, `scrollSnapType/Align/Stop`, `scrollPadding/Margin`,
  `overscrollBehavior[X/Y]`, `resize`, `appearance`, `accentColor`,
  `colorSchemeHint`, `break{Inside,Before,After}`, `scrollbarWidth`,
  `tapHighlightColor`, `fill`/`stroke`/`strokeWidth`, `columnCount/Width`,
  `counter{Reset,Increment,Set}`.

## v0.3.0 — 2026-07-15

Animations (WAAPI engine), responsive styling (breakpoints, container
queries, reactive viewport checks), release precompression + nginx config.

### Added — Release artifacts

- `swiftwui build -c release` now precompresses dist files: every
  compressible asset ≥ 1 KB (wasm/js/css/html/json/svg/…) gets `.gz`
  (gzip -9) and, when brotli is installed, `.br` (brotli -q 11) siblings —
  served for free via nginx `gzip_static`/`brotli_static`. Debug builds
  remove stale siblings; `swiftwui ssg` refreshes them after prerendering.
- `dist/nginx.conf` — generated ready-to-deploy server block (conf.d style):
  precompressed serving, wasm MIME for `instantiateStreaming`, SPA fallback
  with ssg prerender support, safe revalidation caching.
- Loud warning when `wasm-opt` (binaryen) is missing on release builds —
  PackageToJS silently ships a ~2.5× larger wasm without it.
- `nginx.conf` joined the reserved `public/` names; service-worker precache
  manifests exclude `.gz`/`.br` siblings and `nginx.conf`.

### Added — Responsive styling

- `@Environment(\.media)` — reactive `matches(_:)` viewport checks inside a
  component `body`, backed by `window.matchMedia` change events; defaults to
  `false` during SSR/hydration, so use it for structural branching, not styling.
- `Breakpoint` scale — `sm`/`md`/`lg`/`xl` at 640/768/1024/1280 px with
  `MediaQuery.up(_:)`/`.down(_:)` helpers.
- `MediaQuery` grew `minHeight`/`maxHeight`/`orientation(_:)` conditions and
  `and`/`or`/`not` combinators.
- `responsive(_:sm:md:lg:xl:)` / `Responsive<Value>` — per-breakpoint values
  desugared into non-overlapping media rules with a cascade-safe base.
- Container queries — `.containerType(_:name:)` / `.container(_:name:)`
  modifiers, `Rule(container:)`, and `container` blocks inside style proxies
  emit `@container` rules (names validated against CSS injection).

### Added — Animations

- `withAnimation(_:completion:)` — animates every state write inside the
  closure; `completion` fires once every animation it started has settled.
- `Animation` — springs solved to CSS `linear()` easing (`.spring(duration:bounce:)`,
  presets `.smooth`/`.snappy`/`.bouncy`), plus `.linear`/`.easeIn`/`.easeOut`/
  `.easeInOut`/`.timingCurve`, and `.delay`/`.speed`/`.repeatCount`/`.repeatForever`
  modifiers.
- `.animation(_:value:)` — scoped implicit animation that fires only when
  `value` changes.
- `AnyTransition` — `.opacity`, `.scale(anchor:)`, `.offset(x:y:)`, `.move(edge:)`,
  `.slide`, `.combined(with:)`, `.asymmetric(insertion:removal:)`, `.animation(_:)`,
  and the `.active([StyleDeclaration])` primitive — plus `.transition(_:)` to
  attach one to a view, with enter/exit playback, deferred DOM removal on
  exit, and bidirectional interruption (ghost adoption / enter cancellation).
- `.offset(x:y:)`, `.scaleEffect(_:anchor:)`, `.rotationEffect(_:anchor:)` —
  transform modifiers on individual `translate`/`scale`/`rotate` CSS channels
  (each animates and retargets independently).
- `\.accessibilityReduceMotion` environment key — mirrors
  `prefers-reduced-motion: reduce`; the engine automatically collapses every
  animation to duration ≈ 0 when it's on.
- DOMBackend animates via the Web Animations API (`element.animate`) — one
  call per changed style property, zero per-frame bridge traffic.

### Known limitations

- `.animation(_:value:)` drives enter transitions but does not drive removal
  transitions in v1 (removed identities never resolve under the wrapper).

### Changed

- **BREAKING:** the CSS shorthand modifier `.transition(String)` is renamed to
  `.cssTransition(String)` on both `Tag` and `HTMLTag` — `.transition(_:)` now
  refers exclusively to `AnyTransition`. `StyleProxy.transition(String)`
  (inside `.hover { }` / `.media { }` blocks) is unaffected.

## v0.2.0 — 2026-07-13

Browser APIs (`@AppStorage`/`@SceneStorage`, `colorScheme`, `WebSession`,
file selection), opt-in PWA mode, BridgeJS-backed DOM ops, `TagModifier`.

## v0.1.0 — 2026-07-06

First public release: core `Tag`/`@State` API, typed styles, routing,
full HTML + SSG/hydration, `swiftwui` CLI, tutorial site.
