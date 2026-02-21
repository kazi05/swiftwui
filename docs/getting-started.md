# Getting Started with SwiftWUI

SwiftWUI is a Swift-based web UI framework that compiles to WebAssembly. It brings a
SwiftUI-inspired declarative programming model to the browser, letting you build
interactive web applications entirely in Swift.

This guide walks you through installing the prerequisites, scaffolding a new project,
understanding its structure, and running your first SwiftWUI application.

---

## Prerequisites

You need three tools installed on your system before you begin.

### 1. Swift 6.0+

SwiftWUI targets Swift 6.0 and uses its strict concurrency model. Download the latest
toolchain from [swift.org](https://www.swift.org/install/).

Verify your installation:

```bash
swift --version
# Swift version 6.x.x
```

### 2. SwiftWasm SDK

The SwiftWasm SDK is the cross-compilation target that turns your Swift code into a
`.wasm` binary the browser can execute. It is **not** a separate compiler -- it plugs
into your existing Swift toolchain as an SDK.

Install it with a single command:

```bash
swift sdk install https://github.com/aspect-build/aspect-wasm/releases/download/swift-6.2.3-RELEASE/swift-6.2.3-RELEASE_wasm.artifactbundle.tar.gz
```

This downloads the pre-built SDK artifact bundle and registers it so you can reference
it later with `--swift-sdk swift-6.2.3-RELEASE_wasm`.

Verify the SDK was registered:

```bash
swift sdk list
# swift-6.2.3-RELEASE_wasm
```

### 3. Node.js 18+

The development server uses [Vite](https://vite.dev/) to serve your compiled WASM
binary, resolve the `@bjorn3/browser_wasi_shim` runtime dependency, and provide hot
module replacement during development.

Download Node.js from [nodejs.org](https://nodejs.org/) or use a version manager
like `nvm`.

Verify your installation:

```bash
node --version
# v18.x.x or higher

npm --version
# 9.x.x or higher
```

---

## Creating a New Project

SwiftWUI ships with a CLI scaffolding tool called `swiftwui-init`. Run it from the
SwiftWUI repository root to generate a ready-to-build project:

```bash
swift run --package-path /path/to/SwiftWUI swiftwui-init MyApp
cd MyApp
```

Replace `/path/to/SwiftWUI` with the actual path to your local SwiftWUI checkout.

You will see output confirming that each file was created:

```
  Created MyApp/Package.swift
  Created MyApp/Sources/main.swift
  Created MyApp/index.html
  Created MyApp/package.json
  Created MyApp/.gitignore

Project 'MyApp' created successfully!

Next steps:
  cd MyApp
  npm install
  swift package --swift-sdk swift-6.2.3-RELEASE_wasm js -c debug
  npm run dev

Then open http://localhost:8080 in your browser.
```

---

## Project Structure

After scaffolding, your project contains five files:

```
MyApp/
  Package.swift          # Swift package manifest
  Sources/
    main.swift           # Application entry point
  index.html             # HTML host page
  package.json           # npm configuration for Vite
  .gitignore             # Ignores .build/, node_modules/, etc.
```

### Package.swift

The Swift Package Manager manifest. It declares your executable target and pulls in
two dependencies:

- **SwiftWUI** -- the framework itself (initially set to a local path; swap to a
  remote URL for published releases).
- **JavaScriptKit** -- the Swift-to-JavaScript bridge that SwiftWUI uses under the
  hood to interact with the DOM.

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "SwiftWUI", path: "../../"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "SwiftWUI", package: "SwiftWUI"),
            ]
        ),
    ]
)
```

> **Tip:** When SwiftWUI is published to a remote repository, replace the local
> `.package(name: "SwiftWUI", path: "../../")` line with a URL-based dependency.

### Sources/main.swift

Your application code. This file contains a `ContentView` component and the
`Application` entry point that mounts it to the DOM. See the
[Your First App](#your-first-app) section below for a detailed walkthrough.

### index.html

A minimal HTML page that provides the mount point (`<div id="app">`) and loads the
compiled WASM module:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>MyApp</title>
</head>
<body>
    <div id="app"></div>
    <script type="module">
        import { init } from "myapp";
        await init();
    </script>
</body>
</html>
```

The `import { init } from "myapp"` line resolves through Vite to the compiled
package output at `.build/plugins/PackageToJS/outputs/Package`.

### package.json

Configures npm with Vite as the dev server. The `devDependencies` section maps your
compiled WASM package as a local file dependency:

```json
{
  "name": "myapp-app",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "devDependencies": {
    "myapp": "file:.build/plugins/PackageToJS/outputs/Package",
    "vite": "^7.3.1"
  }
}
```

### .gitignore

Excludes build artifacts and dependencies from version control:

```
.build/
node_modules/
.swiftpm/
*.js
!vite.config.js
```

---

## Building and Running

Follow these four steps to compile and launch your application.

### Step 1: Build for WebAssembly

Compile your Swift code into a WASM binary using the JavaScriptKit `PackageToJS`
plugin:

```bash
swift package --swift-sdk swift-6.2.3-RELEASE_wasm js -c debug
```

This command does the following:

1. Compiles all Swift sources with the WASM SDK.
2. Runs the `PackageToJS` plugin from JavaScriptKit, which packages the `.wasm`
   binary together with JavaScript glue code.
3. Outputs the result to `.build/plugins/PackageToJS/outputs/Package`.

The first build takes longer because it resolves and compiles all dependencies. Subsequent
builds are incremental and significantly faster.

> **Note:** Use `-c release` instead of `-c debug` for optimized production builds.
> Debug builds are faster to compile and include better error messages.

### Step 2: Install npm dependencies

```bash
npm install
```

This installs Vite and links the local WASM package output so Vite can resolve the
`import { init } from "myapp"` statement in `index.html`.

### Step 3: Start the dev server

```bash
npm run dev
```

Vite starts a local development server, typically on port 5173.

### Step 4: Open in your browser

Navigate to **http://localhost:5173** in any modern browser.

You should see your application running -- a heading and a counter with increment and
decrement buttons.

### Full build-and-run sequence

For quick reference, here is the complete sequence from a freshly scaffolded project:

```bash
cd MyApp
swift package --swift-sdk swift-6.2.3-RELEASE_wasm js -c debug
npm install
npm run dev
# Open http://localhost:5173
```

After making changes to your Swift code, re-run the WASM build command and refresh
the browser:

```bash
swift package --swift-sdk swift-6.2.3-RELEASE_wasm js -c debug
```

---

## Your First App

The generated `Sources/main.swift` contains a working counter application. Let's walk
through every part of it.

### The full template

```swift
import SwiftWUI

struct ContentView: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            H1 { "MyApp" }
            P {
                Text("Count: \(count)")
            }
            .fontSize(.px(24))
            Div {
                Button(onclick: { count -= 1 }) {
                    Text("-")
                }
                .padding(.px(8), .px(16))
                .fontSize(.px(20))
                .cursor(.pointer)

                Button(onclick: { count += 1 }) {
                    Text("+")
                }
                .padding(.px(8), .px(16))
                .fontSize(.px(20))
                .cursor(.pointer)
            }
            .display(.flex)
            .style("gap", "12px")
            .style("align-items", "center")
        }
        .padding(.px(32))
        .style("font-family", "system-ui, sans-serif")
    }
}

let app = Application {
    Route("/") { ContentView() }
}
app.mount()
```

### Understanding the code

**Importing the framework:**

```swift
import SwiftWUI
```

The `SwiftWUI` umbrella module re-exports all sub-modules (Core, HTML, Styles, State,
Router, Runtime, Browser), so a single import gives you access to every API.

**Defining a component:**

```swift
struct ContentView: Tag {
    @State var count = 0

    var body: some Tag {
        // ...
    }
}
```

Components in SwiftWUI conform to the `Tag` protocol (analogous to SwiftUI's `View`).
Each component declares a `body` property that returns the UI tree. The `@TagBuilder`
result builder is applied automatically, so you can list multiple child tags without
explicit composition.

**Reactive state:**

```swift
@State var count = 0
```

The `@State` property wrapper creates reactive state. When `count` changes, SwiftWUI
automatically re-renders only the affected parts of the DOM through its virtual DOM
reconciler.

**HTML elements:**

```swift
Div {
    H1 { "MyApp" }
    P { Text("Count: \(count)") }
}
```

HTML elements are Swift structs with uppercase names: `Div`, `H1`, `P`, `Button`,
`Span`, `Input`, `A`, `Img`, `Ul`, `Li`, `Table`, and more. Each accepts a
`@TagBuilder` closure for its children. String literals inside a `@TagBuilder` are
automatically converted to `Text` nodes.

**Event handling:**

```swift
Button(onclick: { count -= 1 }) {
    Text("-")
}
```

Event handlers are passed as parameters to HTML tag constructors. The `Button` type
accepts an `onclick` closure that fires when the user clicks. Because `@State` uses
a reference-type backing store, mutations inside closures work without `mutating`.

**Styling:**

SwiftWUI provides two approaches to inline styles:

1. **Type-safe modifiers** for common CSS properties:

   ```swift
   .padding(.px(32))
   .fontSize(.px(24))
   .display(.flex)
   .backgroundColor(.hex("#f0f0f0"))
   .cursor(.pointer)
   ```

2. **String-based fallback** for any CSS property:

   ```swift
   .style("gap", "12px")
   .style("font-family", "system-ui, sans-serif")
   ```

Both approaches can be chained freely on any tag.

**Mounting the application:**

```swift
let app = Application {
    Route("/") { ContentView() }
}
app.mount()
```

`Application` is the entry point. It accepts a `@RouteBuilder` closure where you
define one or more routes. `app.mount()` finds the `<div id="app">` element in your
HTML page and renders the matched route into it.

### Modifying the template

Try changing the counter into a greeting app:

```swift
import SwiftWUI

struct GreetingApp: Tag {
    @State var name = ""
    @State var submitted = false

    var body: some Tag {
        Div {
            H1 { "Hello, SwiftWUI!" }
                .foregroundColor(.hex("#333"))

            if submitted {
                P { Text("Welcome, \(name)!") }
                    .fontSize(.px(20))
                    .foregroundColor(.hex("#2563eb"))

                Button(onclick: { submitted = false }) {
                    Text("Reset")
                }
                .padding(.px(8), .px(16))
                .cursor(.pointer)
            } else {
                P { "Enter your name:" }
                    .fontSize(.px(16))

                Input(
                    type: .text,
                    placeholder: "Your name",
                    value: name
                )
                .padding(.px(8))
                .fontSize(.px(16))

                Button(onclick: { submitted = true }) {
                    Text("Greet")
                }
                .padding(.px(8), .px(16))
                .cursor(.pointer)
            }
        }
        .padding(.px(32))
        .style("font-family", "system-ui, sans-serif")
    }
}

let app = Application {
    Route("/") { GreetingApp() }
}
app.mount()
```

This demonstrates conditional rendering with `if/else` (supported natively by
`@TagBuilder`), the `Input` element, and multiple `@State` properties.

---

## Key Concepts at a Glance

| SwiftUI Concept | SwiftWUI Equivalent | Description |
|---|---|---|
| `View` | `Tag` | Core protocol for UI components |
| `@ViewBuilder` | `@TagBuilder` | Result builder for composing children |
| `body: some View` | `body: some Tag` | Computed property returning the UI tree |
| `@State` | `@State` | Reactive local state |
| `$value` (Binding) | `$value` (Binding) | Two-way binding via projected value |
| `NavigationStack` | `Application` + `Route` | URL-based routing |
| `NavigationLink` | `Link` | Client-side navigation |

---

## Troubleshooting

**"Could not find element with id 'app'"**

Make sure your `index.html` contains `<div id="app"></div>` before the script tag.
The `app.mount()` call looks for this element by default.

**WASM build fails with missing SDK**

Confirm the SDK is installed by running `swift sdk list`. If
`swift-6.2.3-RELEASE_wasm` does not appear, re-run the install command from the
[Prerequisites](#2-swiftwasm-sdk) section.

**`npm run dev` shows module resolution errors**

Make sure you ran the WASM build command **before** `npm install`. The
`.build/plugins/PackageToJS/outputs/Package` directory must exist for npm to link it
correctly. If you built after installing, delete `node_modules` and run `npm install`
again.

**Build is slow**

The first compilation downloads and builds all dependencies (including JavaScriptKit
and SwiftSyntax). Subsequent incremental builds are much faster. Use `-c debug` during
development and reserve `-c release` for production.

---

## Next Steps

Now that your first application is running, continue with these guides:

- [Tutorial](tutorial.md) -- Build a complete multi-page application step by step.
- [State Management](state-management.md) -- Deep dive into `@State`, `@Binding`,
  `@ObservedObject`, and the reactivity system.
- [Styling](styling.md) -- Type-safe CSS modifiers, the `.style()` fallback, CSS
  classes, animations, and transitions.
- [Routing](routing.md) -- Multi-page apps with `Route`, URL parameters, `Link`
  navigation, and the History API.
