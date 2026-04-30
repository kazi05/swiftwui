# SwiftWUI

A SwiftUI-inspired declarative web framework that compiles to WebAssembly.

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-F05138?logo=swift&logoColor=white)
![WebAssembly](https://img.shields.io/badge/WebAssembly-654FF0?logo=webassembly&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Web-blue)
![License](https://img.shields.io/badge/License-MIT-green)

SwiftWUI brings SwiftUI's declarative programming model to the browser. Build interactive web applications in pure Swift — `Tag` (the SwiftUI `View` analog), `@State`, `@Environment`, result builders, modifier chains — all compiled to WebAssembly via SwiftWasm.

---

## Quick Start

### Prerequisites

| Dependency | Version |
|---|---|
| Swift | 6.0+ |
| SwiftWasm SDK | `swift-6.2.3-RELEASE_wasm` or later |
| Node.js | Required for the Vite dev server |

Install the SwiftWasm SDK once:

```bash
swift sdk install https://github.com/swiftwasm/swift/releases/download/swift-6.2.3-RELEASE/swift-6.2.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip
```

### Install the CLI

```bash
swift build -c release --product swiftwui
# Copy the binary to your PATH, e.g.:
cp .build/release/swiftwui /usr/local/bin/swiftwui
```

### Create and run a project

```bash
swiftwui init MyApp          # scaffold the 12-chapter showcase template
cd MyApp
swiftwui dev --target MyApp  # build, serve, and hot-reload on http://localhost:8080
```

---

## Core Ideas

- **`Tag` protocol** — SwiftUI's `View` analog. Compose UI with `var body: some Tag`.
- **`@TagBuilder`** — result builder for declarative tag composition, including conditionals and `ForEach` loops.
- **`@State` observation** — reactive state backed by Swift's `@Observable`. Mutations automatically re-render the affected subtree via `withObservationTracking`.
- **Virtual-DOM reconciler** — `TagNode` trees are diffed by `Reconciler`, producing minimal patch operations applied through `DOMBridge` (JavaScriptKit).
- **Type-safe CSS modifiers** — chainable `.fontSize(.px(16))`, `.backgroundColor(.hex("#333"))`, `.display(.flex)` with a `.style("prop", "val")` string escape hatch.
- **Sticky-pair scrolly-telling** — `ScrollyTeller` and `CodeAndPreview` components used in the showcase template keep a live preview panel sticky while the user scrolls through a chapter's steps.

---

## What's in the Box

Eight focused library modules, re-exported through the `SwiftWUI` umbrella:

- **SwiftWUICore** — `Tag` protocol, `@TagBuilder`, `TagNode` (virtual DOM), `AnyTag`, `ModifiedContent`, `ForEach`, `EventHandlerRegistry`.
- **SwiftWUIHTML** — HTML tags: `Div`, `Span`, `P`, `H1`–`H6`, `Button`, `Input`, `Form`, `Table`, `Select`, `Textarea`, `Img`, `A`, and more.
- **SwiftWUIStyles** — Type-safe CSS modifiers, `CSSUnit`, `CSSColor`, `Animation`, `TagTransition`, layout / flexbox / grid helpers, CSS Container Queries, Anchor Positioning.
- **SwiftWUIState** — `@State`, `Binding`, `@Environment`, `EnvironmentValues`.
- **SwiftWUIPage** — `Page` protocol, `PageHead`, `PageRenderer`.
- **SwiftWUIRouter** — `Router`, `Route`, `RouteBuilder`, `Link`, `NavigationStack`, dynamic path parameters.
- **SwiftWUIRuntime** — `Application`, `DOMRenderer`, `Reconciler`, `DOMBridge` (JavaScriptKit wrapper).
- **SwiftWUIBrowser** — `@AppStorage` (localStorage), `@SessionStorage`, `Geolocation`, `Clipboard`, `MediaQuery`, `Localization`, `WebAppManifest`, `ServiceWorker`.

---

## The CLI

The `swiftwui` binary is the single entry point for all project operations. It is built from `Sources/SwiftWUICLI` using `swift-argument-parser`.

### `swiftwui init`

Scaffold a new SwiftWUI project.

```
swiftwui init <ProjectName> [--minimal]
```

- Default: generates the 12-chapter Apple-tutorial-style showcase template.
- `--minimal`: generates a lean Counter-style scaffold for a blank-slate start.

```bash
swiftwui init MyApp           # showcase template (default)
swiftwui init MyApp --minimal # minimal Counter-style template
```

### `swiftwui dev`

Run the development server with hot reload.

```
swiftwui dev --target <Target> [--port <Port>] [--watch <Dir>] [--open]
```

```bash
swiftwui dev --target MyApp
swiftwui dev --target MyApp --port 3000 --open
```

Watches `Sources/` by default. The `--open` flag opens the project in the default browser on start.

### `swiftwui build`

Produce an optimised release build with brotli compression and SHA-384 SRI hashes.

```
swiftwui build --target <Target> [--output <Dir>] [--optimize default|size|aggressive]
```

```bash
swiftwui build --target MyApp --optimize size
```

Artefacts land in `dist/` by default. The `size` optimize level runs `wasm-opt -Oz` and compresses with both brotli and gzip.

### `swiftwui doctor`

Check that all required toolchain components are installed.

```bash
swiftwui doctor
```

Verifies: `swift`, `wasm-opt`, `brotli`, `gzip`, `openssl`, `fswatch`, the swiftwasm SDK, and that the showcase template in `Sources/SwiftWUICLI/Templates/showcase/` is in sync with `Examples/Showcase/`.

---

## Project Layout

```
SwiftWUI/
├── Sources/
│   ├── SwiftWUI/           # Umbrella module (re-exports all 8 modules)
│   ├── SwiftWUICore/       # Tag protocol, virtual DOM, result builder
│   ├── SwiftWUIHTML/       # HTML tag library
│   ├── SwiftWUIStyles/     # Type-safe CSS modifiers
│   ├── SwiftWUIState/      # @State, Binding, @Environment
│   ├── SwiftWUIPage/       # Page protocol and rendering
│   ├── SwiftWUIRouter/     # URL routing and navigation
│   ├── SwiftWUIRuntime/    # Application, Reconciler, DOMBridge
│   ├── SwiftWUIBrowser/    # Browser APIs
│   └── SwiftWUICLI/        # swiftwui CLI (init, dev, build, doctor)
│       └── Templates/
│           └── showcase/   # Bundled scaffold (synced from Examples/Showcase)
├── Tests/
│   ├── SwiftWUICoreTests/
│   ├── SwiftWUIHTMLTests/
│   ├── SwiftWUIStylesTests/
│   ├── SwiftWUIStateTests/
│   ├── SwiftWUIBrowserTests/
│   ├── SwiftWUIRuntimeTests/
│   └── SwiftWUICLITests/
├── Examples/
│   ├── Showcase/           # 12-chapter showcase app (default swiftwui init output)
│   └── Counter/            # Minimal counter app (--minimal scaffold)
├── docs/                   # Design specs, plans, tutorials
├── Makefile
└── Package.swift
```

---

## Testing

**Framework test suite** (315 tests, 7 suites):

```bash
swift test
```

**Full CI pipeline** (framework build + tests + showcase build + showcase tests):

```bash
make ci
```

**Showcase tests only** (28 tests):

```bash
make showcase-test
```

Individual Makefile targets:

```bash
make test           # swift test --parallel
make test-seq       # swift test (sequential, deterministic)
make test-coverage  # swift test --enable-code-coverage --parallel
```

---

## Examples

### `Examples/Showcase/`

The 12-chapter Apple-tutorial-style showcase app. This is what `swiftwui init MyApp` produces by default. See [`Examples/Showcase/README.md`](Examples/Showcase/README.md) for boot instructions and the full chapter listing.

### `Examples/Counter/`

A minimal counter application demonstrating `@State`, `Button`, and basic modifiers. This is the template produced by `swiftwui init MyApp --minimal`.

---

## Documentation

Design notes, specs, and tutorials live in [`docs/`](docs/):

| File | Content |
|---|---|
| `docs/getting-started.md` | Installation, first project, dev workflow |
| `docs/architecture.md` | Module dependency graph and design decisions |
| `docs/state-management.md` | `@State`, `Binding`, `@Environment` |
| `docs/styling.md` | Type-safe CSS modifiers, animations, transitions |
| `docs/routing.md` | URL routing, `NavigationStack`, dynamic parameters |
| `docs/browser-apis.md` | localStorage, geolocation, clipboard, media queries |
| `docs/animations.md` | CSS transitions and `withAnimation` |
| `docs/api-reference.md` | Full public API surface |
| `docs/tutorial.md` | Step-by-step tutorial |
| `docs/superpowers/specs/` | Approved design specifications |
| `docs/superpowers/plans/` | Implementation plans |

---

## Contributing

1. Branch from `main` using the convention `feat/`, `fix/`, or `docs/`.
2. Add tests for any new public API surface. The framework suite must stay green (`swift test`).
3. Run `make sync-templates` before committing changes to `Examples/Showcase/` — this rsyncs the showcase into `Sources/SwiftWUICLI/Templates/showcase/` with project-name placeholders substituted. Never edit `Templates/showcase/` directly.
4. Run `make ci` to verify the full pipeline before opening a pull request.

---

## License and Acknowledgements

MIT. See `LICENSE` for details.

Built on [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) (SwiftWasm), [swift-argument-parser](https://github.com/apple/swift-argument-parser) (Apple), and [Vapor](https://github.com/vapor/vapor) (used by the dev server).
