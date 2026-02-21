# SwiftWUI

**Declarative web UI framework for Swift, compiled to WebAssembly.**

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-F05138?logo=swift&logoColor=white)
![WebAssembly](https://img.shields.io/badge/WebAssembly-654FF0?logo=webassembly&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Web-blue)
![License](https://img.shields.io/badge/License-MIT-green)

SwiftWUI brings SwiftUI's declarative programming model to the browser. Build interactive web applications in pure Swift using familiar patterns -- `Tag` (the SwiftUI `View` analog), `@State`, `@Environment`, result builders, and modifier chains -- all compiled to WebAssembly via SwiftWasm.

---

## Quick Start

### Scaffold a New Project

```bash
swift run swiftwui-init MyApp
```

This generates a ready-to-run project:

```
MyApp/
  Package.swift          # Swift 6.0, WASM-ready
  Sources/main.swift     # Application + ContentView template
  index.html             # HTML entry point with <div id="app">
  package.json           # Vite dev server
  .gitignore
```

### Build and Run

```bash
cd MyApp
npm install
swift package --swift-sdk swift-6.2.3-RELEASE_wasm js -c debug
npm run dev
```

Open `http://localhost:8080` in your browser.

---

## Example: Counter App

```swift
import SwiftWUI

struct CounterApp: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            H1 { "SwiftWUI Counter" }
            P { Text("Count: \(count)") }.fontSize(.px(24))
            Button(onclick: { count += 1 }) { Text("+") }
                .padding(.px(8), .px(16))
                .cursor(.pointer)
        }
        .padding(.px(32))
    }
}

let app = Application {
    Route("/") { CounterApp() }
}
app.mount()
```

---

## Features

| Feature | Description |
|---|---|
| **Tag Protocol** | SwiftUI's `View` analog. Compose UI with `var body: some Tag`. |
| **@TagBuilder** | Result builder for declarative tag composition, including conditionals and loops. |
| **@State** | Reactive state backed by Swift's `@Observable`. Mutations trigger automatic re-renders. |
| **Binding** | Two-way data binding via `$property`. Supports `$model.field` for `@Observable` classes. |
| **@Environment** | Inject values down the tag tree with custom `EnvironmentKey` definitions. |
| **TagModifier** | Reusable modifier protocol (analogous to SwiftUI's `ViewModifier`). |
| **Type-Safe CSS** | Chainable modifiers: `.fontSize(.px(16))`, `.backgroundColor(.hex("#333"))`, `.display(.flex)`. |
| **CSS Transitions** | `withAnimation(.easeInOut(duration: 0.3)) { ... }` and `.transition(.opacity)`. |
| **URL Routing** | `Route`, `Link`, `NavigationStack`, and dynamic path parameters (`:id`). |
| **Browser APIs** | `@AppStorage` (localStorage), `Geolocation`, `Clipboard`, `MediaQuery`, `Localization`. |
| **Page Protocol** | Define page-level metadata (head tags, title). |
| **CLI Scaffolding** | `swift run swiftwui-init <Name>` generates a complete project. |

---

## Architecture

SwiftWUI is organized into 8 focused modules, plus an umbrella module that re-exports them all:

```
SwiftWUI (umbrella)
  |
  +-- SwiftWUICore       Tag protocol, @TagBuilder, TagNode (virtual DOM),
  |                      AnyTag, ModifiedContent, ForEach, EventHandlerRegistry
  |
  +-- SwiftWUIHTML       HTML tags: Div, Span, P, H1-H6, Button, Input,
  |                      Form, Table, Select, Textarea, Img, A, and more
  |
  +-- SwiftWUIStyles     Type-safe CSS modifiers, CSSUnit, CSSColor,
  |                      Animation, TagTransition, layout/flexbox/grid helpers
  |
  +-- SwiftWUIState      @State, Binding, @Environment, EnvironmentValues
  |
  +-- SwiftWUIPage       Page protocol, PageHead, PageRenderer
  |
  +-- SwiftWUIRouter     Router, Route, RouteBuilder, Link, NavigationStack
  |
  +-- SwiftWUIRuntime    Application, DOMRenderer, Reconciler, DOMBridge
  |
  +-- SwiftWUIBrowser    @AppStorage, @SessionStorage, Geolocation,
                         Clipboard, MediaQuery, Localization
```

The virtual DOM (`TagNode`) is diffed by the `Reconciler`, which produces patch operations applied through `DOMBridge` (a thin wrapper over JavaScriptKit). State changes are tracked via Swift's Observation framework and re-renders are batched using `queueMicrotask`.

---

## Requirements

| Dependency | Version |
|---|---|
| Swift | 6.0+ |
| SwiftWasm SDK | `swift-6.2.3-RELEASE_wasm` or later |
| Node.js | Required for Vite dev server |
| JavaScriptKit | 0.22+ |

---

## Build Commands

**Native build and tests** (no WASM -- useful for unit testing core logic):

```bash
swift build
swift test
```

**WASM library build:**

```bash
swift build --swift-sdk swift-6.2.3-RELEASE_wasm
```

**Run an example (Counter):**

```bash
cd Examples/Counter
swift package --swift-sdk swift-6.2.3-RELEASE_wasm js -c debug
npm run dev
```

---

## Documentation

Detailed documentation is available in the [`docs/`](docs/) folder:

- **Getting Started** -- installation, first project, and dev workflow
- **Tag Protocol** -- building custom components
- **State Management** -- `@State`, `Binding`, `@Environment`
- **Styling** -- type-safe CSS modifiers, animations, transitions
- **Routing** -- URL routing, navigation, dynamic parameters
- **Browser APIs** -- localStorage, geolocation, clipboard, media queries

---

## Dependencies

| Package | Purpose |
|---|---|
| [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) 0.22+ | Swift-to-JavaScript bridge for WebAssembly |

---

## License

MIT
