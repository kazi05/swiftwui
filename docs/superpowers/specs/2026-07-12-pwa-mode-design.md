# PWA Mode — Design

**Date:** 2026-07-12
**Status:** Approved (brainstorm complete)
**Depends on:** phase 6 toolchain (CLI, dev server, templates), phase 5 SSG + hydration, phase 8a EnvironmentSignals

## Context

SwiftWUI today produces two shapes from one wasm binary:

- `swiftwui build` — client-only SPA: one `dist/index.html` + `dist/app/` (PackageToJS bundle, verbatim) + `dist/vendor/wasi-shim/` + `public/` copied in (`DistLayout.assemble`, `Sources/SwiftWUIToolchain/WasmBuild.swift`). History-API routing; dev/serve provide SPA index fallback.
- `swiftwui ssg` — per-route prerendered `dist/<route>/index.html` with a `@State` snapshot; the wasm runtime adopts the prerendered DOM (`AdoptingBackend`, `SnapshotBoot`) and continues as an SPA.

There is no PWA layer anywhere: no manifest, no service worker, no offline capability. This phase adds an **opt-in** PWA mode as a thin layer over the same SPA build. The target model:

- **SPA** (default) — unchanged, zero PWA artifacts.
- **PWA** (opt-in) — installable + offline via service worker precache.
- **SSG** — stays an SEO-only prerender layer; composes with both.

## Goals

1. `swiftwui init --pwa` scaffolds a project that is installable (Chrome/Edge/Safari-manual) and fully offline-capable after first visit.
2. `swiftwui pwa init` adds the same artifacts to an existing project.
3. Atomic, integrity-checked offline cache of the whole dist (including the multi-MB wasm), versioned by content.
4. Update flow surfaced to Swift: reactive `appUpdateAvailable` environment value + `reloadToUpdate` action; the "new version — reload" toast is written by the app in SwiftWUI.
5. Default build stays a clean SPA — no service worker unless the project opted in (Flutter lesson: their auto-generated default SW was deprecated and removed in 2025 after years of stale-version bugs).

## Non-goals (out of scope)

- Push notifications (phase 8b; see Cross-phase constraints).
- Icon generation from a user-provided source image (placeholders are scaffolded; users replace them).
- Workbox or any runtime-caching strategies beyond precache + navigation fallback.
- Periodic background sync, badging, share target.
- `<link rel="canonical">` / SEO meta emission in SSG output — separate ticket.
- Content-hashed output filenames (see Rejected alternatives).

## Approach decision

**Chosen — A. Blazor model: stable filenames + build-generated asset manifest.**
The build walks `dist/`, writes `sw-assets.js` (URL + SHA-256 per file, plus a version derived from the list). A scaffolded, user-editable `sw.js` consumes it: atomic versioned precache with integrity checks, cache-first fetch, navigation fallback to the shell. Filenames stay exactly as PackageToJS emits them, so the bundle's internal imports (`index.js` → `runtime.js` → `platforms/…`) are untouched.

**Rejected — B. Content-hashed filenames (Vite/Trunk model).** Requires rewriting imports inside PackageToJS-generated glue and `index.html`; fragile against every JavaScriptKit update; the SW still needs a manifest anyway. High risk for a benefit the SW already delivers.

**Rejected — C. Workbox.** New JS dependency (against project convention), and the CLI generating the precache list is precisely the value Workbox would not add.

Consequence of stable (unhashed) filenames: HTTP caching must be revalidation-based. The template `nginx.conf` and `swiftwui serve` send `Cache-Control: no-cache` (ETag/304 revalidation) for everything including `app/*`. Instant repeat loads come from the SW cache; V8's compiled-code cache is keyed by stable URL and survives 304s.

## CLI surface

- `swiftwui init --pwa [--template basic|mvvm|tca]` — scaffolds the project including PWA artifacts.
- `swiftwui pwa init` — adds PWA artifacts to an existing project. Idempotent: creates only missing files, never overwrites existing ones; reports what it added and what it skipped. Inserts the `index.html` lines only if the marker meta is absent.
- `swiftwui build` — **no new flags.** PWA is detected: if `dist/sw.js` exists after `DistLayout.assemble` (i.e. the project shipped one via `public/`), the build generates `dist/sw-assets.js`. No `sw.js` → no manifest → identical SPA output to today.
- `swiftwui ssg` — same detection after its `public/` copy step; generates `sw-assets.js` over the ssg dist (see SSG interaction for the precache filter).

## Scaffolded artifacts (user-owned, editable)

All live in the project; the framework never regenerates or overwrites them.

1. `public/manifest.webmanifest`
   - `name`/`short_name` from the package name; `id: "/"`, `start_url: "/"`, `scope: "/"`, `display: "standalone"`; `theme_color`/`background_color` placeholders; icons: 192, 512, 512-maskable (`purpose: "maskable"`).
2. `public/icons/` — placeholder PNGs: `icon-192.png`, `icon-512.png`, `icon-512-maskable.png`, `apple-touch-icon.png` (180×180). Bundled in CLI resources.
3. `public/sw.js` — the service worker template (see Service worker).
4. `index.html` additions (4 lines in `<head>`):
   ```html
   <link rel="manifest" href="/manifest.webmanifest">
   <link rel="apple-touch-icon" href="/icons/apple-touch-icon.png">
   <meta name="theme-color" content="#111111">
   <meta name="swiftwui:serviceworker" content="/sw.js">
   ```
   The last meta is the registration marker: `DOMRuntime` registers the SW only when it is present. No registration `<script>` in HTML — registration is Swift-side so the update signal wires into EnvironmentSignals.

Templates: `init --pwa` applies to all three templates (basic/mvvm/tca); the PWA artifacts are template-independent (one shared set in CLI resources), only `manifest.webmanifest` name fields are stamped from the package name.

## Build pipeline: `sw-assets.js` generation

After `DistLayout.assemble` (build) or the SSG output + `public/` copy (ssg), when `dist/sw.js` exists:

1. Walk `dist/` recursively. Exclusions: `sw.js`, `sw-assets.js`, and any `index.html` **not at the dist root** (mechanical rule covering ssg per-route prerenders; the root `index.html` **is included** — it is the offline shell).
2. For each file compute SHA-256; emit base64 digests (the format `fetch`'s `integrity` option requires).
3. Write `dist/sw-assets.js`:
   ```js
   self.__SWIFTWUI_ASSETS = {
     version: "<sha256 over the sorted url+hash list>",
     assets: [
       { url: "/app/App.wasm", integrity: "sha256-<base64>" },
       ...
     ]
   };
   ```
   Deterministic: assets sorted by URL; version changes iff any byte of any asset changes.
4. `sw-assets.js` joins `DistLayout.reservedNames` (a user `public/sw-assets.js` is a hard error, same as `app`/`vendor` today).

**SHA-256 without a new dependency:** a vendored pure-Swift SHA-256 (~80 lines, FIPS 180-4) in `SwiftWUIToolchain`, unit-tested against the official FIPS test vectors. swift-crypto is not worth a new dependency for one hash function (no-new-deps convention).

Failure of manifest generation (unreadable file, I/O error) fails the build with a clear message — never a silently incomplete manifest.

## Service worker (`public/sw.js` template)

~60 lines, deliberately dumb and readable; the user owns and edits it.

- `importScripts('/sw-assets.js')`; cache name `swiftwui-precache-${version}`.
- **install**: `cache.addAll` semantics done manually — for every asset `fetch(new Request(url, { cache: 'no-cache', integrity }))`, put into the versioned cache. All-or-nothing: any failure (including integrity mismatch) fails install, and the previous version keeps serving. **No `skipWaiting()`** — the new version waits until all tabs close or an explicit message.
- **activate**: delete every other `swiftwui-precache-*` cache; `clients.claim()`.
- **fetch**: same-origin GET only.
  - `request.mode === 'navigate'` → respond with cached `/index.html` (SPA navigation fallback; works offline for every route).
  - Otherwise cache-first by URL; cache miss → network passthrough, **no runtime caching** (predictability over cleverness).
  - A commented escape-hatch block lists path prefixes that must always bypass the SW (e.g. `/api/`).
- **message**: `{ type: 'SKIP_WAITING' }` → `self.skipWaiting()`.

## Swift API (SwiftWUI + SwiftWUIDOM)

Two new environment values, following the phase-8a EnvironmentSignals Writer-closure recipe:

- `\.appUpdateAvailable: Bool` — reactive signal, default `false`. Set `true` when a new SW reaches the waiting state. Tracked only when read in a component `body` (8a rule).
- `\.reloadToUpdate: () -> Void` — `openURL`-style action. If a waiting SW exists: post `SKIP_WAITING` to it, then on `controllerchange` call `location.reload()`. No waiting SW: plain `location.reload()`.

**Registration (`DOMRuntime.mount`, after `finishMount`):**
- Read `<meta name="swiftwui:serviceworker">`. Absent → do nothing (plain SPA).
- Present AND `navigator.serviceWorker` exists AND not dev mode (`window.__swiftwui_dev`) → `register(<meta content value>, { updateViaCache: 'none' })`.
- Wire the signal: `registration.waiting` already non-null at load (update found while the tab was away) → signal immediately; `updatefound` → installing worker's `statechange` to `installed` while `navigator.serviceWorker.controller` is non-null → signal.
- Registration failure → `console.warn`, app continues as a normal SPA (progressive enhancement).

**Other targets:** native/SSG render with `appUpdateAvailable == false` — the same default as the first client paint, so hydration never mismatches. `reloadToUpdate` is a no-op outside the browser. MockBackend records `register` (with options), `SKIP_WAITING` posts, and reload calls for tests.

## Dev & serve behavior

- `swiftwui dev`: runtime skips registration (`window.__swiftwui_dev` guard). Additionally `dev-client.js` runs `navigator.serviceWorker.getRegistrations().then(rs => rs.forEach(r => r.unregister()))` — kills any SW left over from a production preview on the same origin/port (the classic poisoned-dev-loop trap).
- `swiftwui serve`: sends `Cache-Control: no-cache` for `index.html`, `sw.js`, `sw-assets.js` (and, per the stable-filename decision, for `app/*` too), so the full update flow is testable locally. localhost is exempt from the HTTPS requirement; production needs HTTPS (documented).
- Template `nginx.conf`: same header policy.

## SSG interaction ("SSG is SEO-only")

- `sw-assets.js` for an ssg dist includes **only** root assets: `app/`, `vendor/`, root `index.html`, `styles.css` (when emitted), `manifest.webmanifest`, `icons/`, other `public/` files. Per-route prerendered `<route>/index.html` files are **never precached** — they are an HTTP-layer SEO artifact for crawlers and first hits. After SW install, returning users never see them again (by design).
- Offline navigation to `/about` serves the shell = root `index.html` (the "/" prerender with its snapshot). The existing boot machinery already handles this: `SnapshotBoot` rejects the snapshot on path mismatch → cold mount renders `/about` correctly. Accepted v1 residual: a brief flash of "/" content before wasm boot when offline-navigating to a non-root route. Future refinement if the flash matters: SSG emits a neutral hydrate shell (e.g. `__swiftwui/shell.html`, name already reserved) and the SW falls back to it instead.

## Error handling summary

| Failure | Behavior |
|---|---|
| Manifest generation I/O error | `swiftwui build`/`ssg` fails with a clear message |
| `public/sw-assets.js` present | Build error (reserved name), same as existing collisions |
| SW registration fails | `console.warn`; app runs as plain SPA |
| Precache fetch/integrity failure | install fails; previous version keeps serving |
| `navigator.serviceWorker` absent (HTTP, old browser) | No registration; plain SPA |

## Testing

Native (`swift test`, MockBackend — the primary gate):

1. Vendored SHA-256 against official FIPS 180-4 test vectors.
2. `sw-assets.js` generator: fixture dir → byte-deterministic output; exclusion of `sw.js`/`sw-assets.js`; ssg per-route page filtering; stable sort; version changes when one byte changes; version stable across runs.
3. Scaffolder: `init --pwa` produces the full artifact set for each template; `pwa init` is idempotent, never overwrites, inserts `index.html` lines only when the marker meta is absent.
4. Build detection: `sw.js` in dist → manifest generated; absent → dist byte-identical to a non-PWA build; reserved-name collision error.
5. Environment values: defaults false/no-op; MockBackend records registration (path + `updateViaCache`), waiting-at-load → immediate signal, `updatefound` path → signal, `reloadToUpdate` posts `SKIP_WAITING` then reloads on `controllerchange`.
6. `sw.js` template structural validation (it cannot execute natively): imports `sw-assets.js`, contains no cross-origin fetches, contains the SKIP_WAITING handler.

Browser acceptance checklist (manual, per phases 3–7 precedent):

1. Chrome install prompt appears; app installs and launches standalone.
2. Load once, go offline, reload — app boots from cache, deep link `/about` works offline.
3. Deploy a changed build → toast (app-side) appears via `appUpdateAvailable`; `reloadToUpdate` activates and reloads into the new version.
4. Second open tab keeps the old version until both reload (waiting semantics).
5. `swiftwui dev` after a production preview on the same port: SW unregistered, hot reload unaffected.
6. Lighthouse PWA/installability pass.

## Cross-phase constraints

- **Phase 8b (push notifications):** its design doc proposes its own `sw.js` for push. An origin has one SW — 8b's push logic must merge into this file. The scaffolded `sw.js` carries a marked section (`// --- push (phase 8b) ---` placeholder comment) where push handlers land. 8b's plan must be updated to extend the PWA template rather than ship a second worker.
- Update-toast UX depends on nothing from 8b/8c and can ship first.

## Residuals / future work

- Neutral hydrate shell for offline SSG navigation (kills the "/" flash).
- `<link rel="canonical">` + per-route SEO meta in SSG output (separate ticket).
- Icon generation from a source SVG (`swiftwui pwa icons`).
- Optional runtime caching strategies (documented as user edits to `sw.js`, not framework features).
