# PWA mode

Turn a SwiftWUI site into an installable, offline-capable Progressive Web
App: a web manifest, icons, and a service worker that precaches `dist/` and
surfaces updates through ``Environment``.

## Overview

PWA support is opt-in and its artifacts are user-owned: the CLI scaffolds
`public/manifest.webmanifest`, `public/icons/`, and `public/sw.js` once, and
never touches them again. Every `swiftwui build`/`swiftwui ssg` regenerates
`/sw-assets.js` — a SHA-256 precache manifest of the current `dist/` — which
the scaffolded `sw.js` imports at install time.

### Enabling

`swiftwui init --pwa` scaffolds the artifacts into a brand-new project;
`swiftwui pwa init` adds them to an existing one. Both are idempotent: running
either again does not overwrite files that already exist.

### Build behavior

`sw-assets.js` is generated fresh on every `build`/`ssg` run — never edit it
by hand, and never place a file named `sw-assets.js` under `public/` (the
name is reserved and would be silently overwritten). Everything under
`dist/` is precached by the generated manifest, so keep an eye on total
payload size as the site grows.

### Update flow

A new deployment installs into a fresh versioned cache and **waits** — it
does not take over running tabs on its own. It activates once every open tab
closes, or immediately via `reloadToUpdate()`. Until then, users may still be
running the previous version, so avoid shipping backend API changes that
break older clients.

`\.appUpdateAvailable` flips to `true` (reactive when read inside `body`)
when a waiting update is detected; `\.reloadToUpdate` activates it and
reloads the page:

```swift
struct UpdateToast: Tag {
    @Environment(\.appUpdateAvailable) var updateAvailable
    @Environment(\.reloadToUpdate) var reload

    var body: some Tag {
        if updateAvailable {
            Div(class: "update-toast") {
                Span("A new version is available.")
                Button("Reload") { reload() }
            }
        }
    }
}
```

A second tab left open keeps running the old version until it reloads too —
this is normal waiting semantics, not a bug.

### Offline behavior

Once installed, the app boots from the precached `dist/` with no network.
Offline deep links (e.g. `/about`) serve the app shell and hydrate client-side;
on an SSG build this means a brief flash of the `/` prerender before wasm
takes over and renders the requested route.

### Constraints

- HTTPS is required in production; `localhost` is exempt for local testing.
- `swiftwui dev` never registers a service worker — the dev client actively
  unregisters any stray registration left over from a previous production
  preview on the same origin, so hot reload keeps working.
- One service worker per origin: future push-notification handling (phase
  8b) belongs in the marked section at the bottom of the scaffolded `sw.js`,
  not a second worker file.

### See it running

`swiftwui init --pwa` (or `swiftwui pwa init`) followed by `swiftwui build`
and `swiftwui serve` produces an installable app you can test offline in
DevTools.
