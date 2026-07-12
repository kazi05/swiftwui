# {{NAME}}

A [SwiftWUI](https://github.com/swiftwasm) project. Pure Swift → WebAssembly.

This project uses the **MVVM** template: `CounterViewModel` (an `@Observable`
class injected through the environment) owns all state and intent; Tag views
render it and forward user actions. Views contain no logic.

Note: dev hot reload preserves `@State` holding `Codable` values; the view-model/store object itself is not `Codable`, so its state resets on reload.

## Develop

    swiftwui dev            # build, serve at http://127.0.0.1:8080, hot-reload with state preserved

## Build & prerender

    swiftwui build          # wasm bundle + index.html + vendored shim → dist/
    swiftwui ssg            # prerender pages into dist/ (hydrated on load)
    swiftwui serve dist     # preview the production output

## PWA

`swiftwui pwa init` adds a web-app manifest, placeholder icons, and an editable
service worker (`public/sw.js`). After that, every `swiftwui build` regenerates
`/sw-assets.js` — the offline precache list. Replace the placeholder icons in
`public/icons/` before shipping. See the SwiftWUI PWA documentation for the
update-toast pattern.

## Docker

`Dockerfile` builds dist/ inside a pinned toolchain container (host and wasm SDK
versions must match exactly). It requires the SwiftWUI dependency to be
reachable inside the build context — with the default path dependency pointing
outside this directory, build locally instead. `Dockerfile.deploy` serves a
locally built dist/ via nginx.

## Layout

- `Sources/main.swift` — the app; dual entry (wasm mount / native `ssg` subcommand)
- `index.html` — dev/prod entry; import map resolves the vendored WASI shim
- `public/` — static assets served from the site root (favicon, images, fonts)
- `vendor/wasi-shim/` — @bjorn3/browser_wasi_shim 0.3.0 (MIT/Apache-2.0), checked in
