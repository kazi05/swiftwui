# Tutorial

The "Hello, SwiftWUI" tutorial site: a 12-chapter, statically-prerendered
curriculum teaching SwiftWUI itself, built with SwiftWUI. It covers the core
`Tag` API, `@State` reactivity, styling, routing, and prerender + hydrate —
each chapter pairs prose with runnable samples and browser screenshots.

## Prerequisites

- Swift 6.3.3 (swiftly) with the matching official WASM SDK
  `swift-6.3.3-RELEASE_wasm`.
- Node.js — only needed for the screenshot/smoke tooling under
  `tools/screenshots`.

## Build

```
./build-site.sh
```

Assembles the wasm bundle, copies `public/` into `dist/`, and prerenders
all 12 pages into `dist/`.

## Preview

```
swift run --package-path ../.. swiftwui serve dist
```

## Test

```
swift test
```

Native content/golden/route tests — no browser required.

## Screenshots

```
cd tools/screenshots
npm install
npm run shots
```

Regenerates the chapter screenshots under `public/assets/screens` via Playwright.

## Smoke

```
cd tools/screenshots && npm run smoke
```

Runs against `swiftwui serve dist` — checks hydration marker on all 12
pages, quiz, chapter menu, scrollspy, and panel swap.

## Layout

- `Sources/TutorialKit` — content model, components, theme.
- `Sources/TutorialSite` — app entry + ssg config.
- `Samples/` — standalone packages referenced by chapter code excerpts.
- `public/assets/screens` — chapter screenshots, served from `/assets/screens`.
- `tools/screenshots` — Playwright shots + smoke suite.
- `dist/` — build output (generated, not checked in).

## Caveats

1. Assets live in `public/` (e.g. `public/assets/screens`); `swiftwui dev`
   serves them from `/`, and `swiftwui build`/`swiftwui ssg` copy them into
   `dist/`.
2. Never mix raw `swift package --swift-sdk … js` with native builds in the
   same directory — use the `swiftwui` CLI, which isolates `.build-wasm`.
3. The hydrate boot script is inline JS — do not put the site behind a
   strict `script-src` CSP without hashes (phase-6 carry).
4. State-dependent style overrides are emitted inline on elements, not as
   classes — `StyleRegistry` orders rules by hash, so two classes at the
   same specificity have unreliable override order.
5. Screenshots regenerate via `npm run shots`; the counter sample's two
   buttons both render accent-solid — the DSL has no positional selectors
   to style them differently.
