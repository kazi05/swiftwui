# Changelog

Notable changes to SwiftWUI. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions match the
`v<version>` git tags described in `Sources/SwiftWUIToolchain/SwiftWUIVersion.swift`.

## Unreleased

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
