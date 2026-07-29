# SwiftWUI

Build websites in pure Swift. SwiftWUI is a SwiftUI-inspired declarative UI
framework that compiles to WebAssembly: value-type components, `@State`
reactivity, typed CSS with breakpoints and container queries, client-side
routing, spring-based animations, view transitions, drag and drop, dependency
injection, localization, and prerendering with hydration — without writing a
line of JavaScript.

```swift
import SwiftWUI
import SwiftWUIDOM

struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
            if count >= 10 { P { "Double digits." } }
        }
    }
}

@main
struct CounterApp: App {
    var body: some Tag { Counter() }
}
```

## Requirements

- Swift **6.3.3** via [swiftly](https://swift.org/install) (macOS 14+ or Linux)
- The official Swift.org WASM SDK `swift-6.3.3-RELEASE_wasm`
- Node.js — optional, only for the Vite-based example dev servers

> Host toolchain and WASM SDK versions must match **exactly** (6.3.3 with
> 6.3.3). A mismatched pair fails at link time with confusing errors.

## Installation

```sh
# 1. Swift toolchain
swiftly install 6.3.3
swiftly use 6.3.3
swift --version        # → Swift version 6.3.3 (swift-6.3.3-RELEASE)

# 2. WASM SDK (bundle URL from swift.org/download)
swift sdk install <swift-6.3.3-RELEASE_wasm bundle URL>
swift sdk list         # → swift-6.3.3-RELEASE_wasm

# 3. The `swiftwui` CLI — via Homebrew
brew tap kazi05/swiftwui
brew trust kazi05/swiftwui
brew install swiftwui
```

<details>
<summary>Manual CLI install (from a checkout)</summary>

```sh
git clone https://github.com/kazi05/swiftwui.git
cd swiftwui
swift build -c release --product swiftwui
export PATH="$PWD/.build/release:$PATH"
```

</details>

## Quick start

```sh
swiftwui init MyApp
cd MyApp
swiftwui dev           # http://127.0.0.1:8080 — rebuilds and reloads on save
```

Ship it:

```sh
swiftwui build         # release wasm bundle → dist/
swiftwui ssg           # prerender routes into dist/ (dual-entry pattern)
swiftwui serve dist    # static preview of the built site
```

### CLI commands

| Command | What it does |
|---|---|
| `swiftwui init <name> [--template basic\|mvvm\|tca] [--swiftwui-path <path>]` | Scaffold a project (Package.swift, `Sources/Entry.swift`, a starter `Sources/Locales/en.json`, index.html, Dockerfile, vendored wasi-shim). `--swiftwui-path` points the scaffold at a local checkout instead of the GitHub release. |
| `swiftwui dev [--port 8080]` | Dev server with hot reload (watches `Sources/`) |
| `swiftwui build [-c release] [--out dist]` | Build the wasm bundle and assemble `dist/` |
| `swiftwui ssg [--out dist]` | Prerender pages via the app's native `<App> ssg` entry |
| `swiftwui serve [dist] [--port 8080]` | Preview a built site (SPA fallback, no watcher) |
| `swiftwui l10n generate [--check] [--target <name>]` | Regenerate `Generated/L10n.swift` from `Locales/*.json`; `--check` is the CI gate |
| `swiftwui l10n add <tag>` | Seed a new `Locales/<tag>.json` from an existing catalog, values marked `TODO` |

Templates: `basic` (counter + two routes + `.staticTask`), `mvvm`
(`@Observable` view model via a custom environment key), `tca`
(TCA-style store/reducer on SwiftWUI reactivity).

## Learn more

- **[Examples/Counter](Examples/Counter)** — the smallest complete app (the
  code above). Run it:

  ```sh
  cd Examples/Counter
  swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
  npm install && npm run dev
  ```

- **[Examples/TodoMVC](Examples/TodoMVC)** — the full tour: routing with
  params, `@Observable` store through the environment, typed
  styles with light/dark themes, controlled inputs with bindings, per-page
  `<head>` metadata, and SSG (`swift run TodoMVC ssg --out dist`).

- **[Examples/Localized](Examples/Localized)** — localization end to end: JSON
  catalogs for `en`/`ru`/`ar`, generated type-safe `L10n`, a language switcher
  built from `@Environment(\.availableLocales)`, ICU plurals, and an RTL demo.
  `swift run Localized ssg --out dist` prerenders one tree per locale;
  `swift run -Xswiftc -DNEGOTIATED Localized ssg --out dist` switches the
  strategy (the define has to be on `run` — a separate `build` gets recompiled).

- **[Sites/Tutorial](Sites/Tutorial)** — "Hello, SwiftWUI": a 20-chapter
  interactive tutorial covering the `Tag` API, `@State`, styling and
  responsive design, bindings and events, drag and drop, routing, animation
  and view transitions, data and dependency injection, prerendering and
  localization. Built with SwiftWUI itself.

## Documentation

The `SwiftWUI` module ships a DocC catalog: open `Package.swift` in Xcode
and choose **Product → Build Documentation** for the full API reference and
a getting-started guide.

## Modules

| Product | Purpose |
|---|---|
| `SwiftWUI` | Renderer-agnostic core: tags, state, styles, routing, effects. Builds natively — zero dependencies. |
| `SwiftWUIDOM` | Browser backend (JavaScriptKit): mounts the app, patches the DOM, hydrates prerendered HTML. |
| `SwiftWUIStatic` | Static-site generation: renders routes to HTML files at build time (macOS/Linux). |
| `swiftwui` | The CLI above. |

## Tests

```sh
swift test
```

886 native tests (Swift Testing) — the renderer and reconciler are
exercised through a mock backend, so no browser or WASM toolchain is needed.
