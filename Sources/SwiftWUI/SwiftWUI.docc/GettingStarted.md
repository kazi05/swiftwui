# Getting Started

Install the toolchain, scaffold a project, and run it with hot reload.

## Overview

SwiftWUI targets WebAssembly through the official Swift.org WASM SDK. The
host toolchain and the SDK versions must match exactly — 6.3.3 with 6.3.3.

### Install the toolchain

```sh
swiftly install 6.3.3
swiftly use 6.3.3

# WASM SDK — bundle URL from swift.org/download
swift sdk install <swift-6.3.3-RELEASE_wasm bundle URL>
swift sdk list        # → swift-6.3.3-RELEASE_wasm
```

### Install the CLI

```sh
brew tap kazi05/swiftwui
brew trust kazi05/swiftwui
brew install swiftwui
```

Or build from a checkout: `git clone https://github.com/kazi05/swiftwui.git && cd swiftwui && swift build -c release --product swiftwui`.

### Create and run a project

```sh
swiftwui init MyApp
cd MyApp
swiftwui dev          # http://127.0.0.1:8080, rebuilds on save
```

`init` accepts `--template basic|mvvm|tca`, and `--pwa` to also scaffold a
manifest, icons, and a service worker (see <doc:PWA>). The scaffold contains
`Package.swift`, `Sources/main.swift`, `index.html`, `nginx.conf`, two
Dockerfiles, and a vendored wasi-shim, so it builds offline and in
containers. Its `Package.swift` depends on the published
`https://github.com/kazi05/swiftwui.git`; pass `--swiftwui-path <dir>` to
point at a local checkout instead.

### Static assets

Files in `public/` are served from the site root: `public/favicon.svg`
is `/favicon.svg`, `public/fonts/Inter.woff2` is `/fonts/Inter.woff2`.
`swiftwui dev` serves them directly; `swiftwui build` and `swiftwui ssg`
copy them into `dist/`. Eight names are reserved at the top level of
`public/`, because they would shadow the framework's own `dist/` layout:
`app`, `vendor`, `index.html`, `styles.css`, `__swiftwui`, `sw-assets.js`,
`nginx.conf` and `swiftwui-site.json`. A collision is a hard error from `build` and `ssg`, not a
silent overwrite; nested paths like `public/assets/index.html` are fine,
since only the first path component competes.

Reference assets with plain URLs — `Img(src: "/images/hero.webp", alt: "…",
width: 1200, height: 630)` — declare fonts with
`static var fontFaces: [FontFace]` on your `App`, and page-level `<link>`
tags (favicon, preload) with `var links: [LinkTag]` on a `Page`.

### Write a component

A component is a struct conforming to ``Tag``. Local state lives in
``State``; mutating it schedules a re-render that patches only the changed
DOM nodes:

```swift
struct Greeting: Tag {
    @State private var name = ""
    var body: some Tag {
        Div {
            Input(value: $name)
            if !name.isEmpty { P { "Hello, \(name)!" } }
        }
    }
}
```

### Ship

```sh
swiftwui build        # release wasm bundle → dist/
swiftwui ssg          # prerender routes into dist/
swiftwui serve dist   # preview the built site
```

Prerendered pages hydrate in the browser: the wasm app adopts the existing
DOM instead of re-creating it. `build` defaults to the release
configuration, which also writes `.gz`/`.br` siblings and a `dist/nginx.conf`
— see <doc:Deployment> for what a server has to provide, and
<doc:Prerendering> for choosing which routes get prerendered.

### Learn more

The repository ships three example apps — `Examples/Counter` (minimal),
`Examples/TodoMVC` (routing, themes, bindings, SSG), and
`Examples/DragDrop` (drag sources, drop zones, file import) — and a
19-chapter interactive tutorial under `Sites/Tutorial`, itself built with
SwiftWUI.
