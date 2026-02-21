# Web Modifiers + Vapor Dev Server — Design Document

**Date:** 2026-02-21
**Status:** Approved

## Overview

Two major additions to SwiftWUI:
1. **Web-adapted modifiers** — 20 modifiers covering State observation, DOM events, geometry/layout observers, and lifecycle hooks
2. **Vapor Dev Server** — Hot-reload dev server replacing Vite workflow + production build tool

---

## Part 1: Web-Adapted Modifiers

### Approach

Hybrid architecture:
- **State modifiers** (`.onChange(of:)`) — use Swift's Observation framework (`withObservationTracking`)
- **DOM modifiers** — use Web APIs (IntersectionObserver, ResizeObserver, MutationObserver, addEventListener)
- New `WebObserver` type in `TagNode.Element` for observer-based modifiers
- Standard `eventListeners` for simple DOM events

### Complete Modifier Catalog

#### Category 1: State Observation (SwiftUI-style)

| Modifier | API | Implementation |
|---|---|---|
| `.onChange(of:)` | `.onChange(of: count) { old, new in }` | `withObservationTracking` on specific value, wrapper tag that subscribes |
| `.task` | `.task { await loadData() }` | Async task spawned on element mount, cancelled on unmount |

#### Category 2: DOM Event Modifiers

| Modifier | API | DOM Event |
|---|---|---|
| `.onAppear` | `.onAppear { }` | IntersectionObserver (isIntersecting = true) |
| `.onDisappear` | `.onDisappear { }` | IntersectionObserver (isIntersecting = false) |
| `.onScroll` | `.onScroll { offset in }` | `scroll` event → ScrollOffset(x, y) |
| `.onResize` | `.onResize { size in }` | ResizeObserver → Size(width, height) |
| `.onHover` | `.onHover { isHovering in }` | `mouseenter`/`mouseleave` |
| `.onFocus` | `.onFocus { }` | `focus` event |
| `.onBlur` | `.onBlur { }` | `blur` event |
| `.onKeyDown` | `.onKeyDown { key in }` | `keydown` → KeyInfo |
| `.onKeyUp` | `.onKeyUp { key in }` | `keyup` → KeyInfo |
| `.onSubmit` | `.onSubmit { }` | `submit` + preventDefault |
| `.onInput` | `.onInput { value in }` | `input` → current value string |
| `.onCopy` | `.onCopy { }` | `copy` event |
| `.onPaste` | `.onPaste { text in }` | `paste` → clipboard text |
| `.onDrag` | `.onDrag { }` | drag API |
| `.onDrop` | `.onDrop { files in }` | drop API → file list |

#### Category 3: Geometry/Layout Observers

| Modifier | API | Web API |
|---|---|---|
| `.onFrameChange` | `.onFrameChange { rect in }` | ResizeObserver + getBoundingClientRect → CGRect |
| `.onIntersection` | `.onIntersection(threshold: 0.5) { ratio in }` | IntersectionObserver with threshold |
| `.onMutation` | `.onMutation(.childList) { }` | MutationObserver |

#### Category 4: Lifecycle

| Modifier | API | Implementation |
|---|---|---|
| `.onMount` | `.onMount { }` | DOMRenderer callback after DOM insertion |
| `.onUnmount` | `.onUnmount { }` | DOMRenderer callback before DOM removal |
| `.id(_)` | `.id(item.id)` | Force element recreation on ID change |

### Architecture

#### New types in SwiftWUICore

```swift
/// Stored in TagNode.Element alongside eventListeners
public enum WebObserver: Equatable, Sendable {
    case intersection(threshold: Double, callbackID: EventListenerID)
    case resize(callbackID: EventListenerID)
    case mutation(options: MutationOptions, callbackID: EventListenerID)
    case lifecycle(event: LifecycleEvent, callbackID: EventListenerID)
}

public struct MutationOptions: Equatable, Sendable {
    public var childList: Bool
    public var attributes: Bool
    public var subtree: Bool
}

public enum LifecycleEvent: Equatable, Sendable {
    case mount
    case unmount
}
```

#### TagNode.Element extension

```swift
public struct Element {
    // ... existing fields ...
    public var observers: [WebObserver]  // NEW
}
```

#### Data types for callbacks

```swift
public struct ScrollOffset: Sendable {
    public let x: Double
    public let y: Double
}

public struct Size: Sendable {
    public let width: Double
    public let height: Double
}

public struct Rect: Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public struct KeyInfo: Sendable {
    public let key: String
    public let code: String
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    public let metaKey: Bool
}
```

#### Modifier API location

- State modifiers (`.onChange(of:)`, `.task`) → `SwiftWUIState/`
- DOM event modifiers → `SwiftWUIHTML/` (extension on Tag)
- Geometry observers → `SwiftWUIHTML/` or `SwiftWUIStyles/`
- Lifecycle modifiers → `SwiftWUICore/`

#### EventHandlerRegistry changes

Currently stores `@Sendable () -> Void`. Needs to be extended to support:
- `@Sendable (ScrollOffset) -> Void` for onScroll
- `@Sendable (Size) -> Void` for onResize
- `@Sendable (Rect) -> Void` for onFrameChange
- `@Sendable (KeyInfo) -> Void` for onKeyDown/onKeyUp
- `@Sendable (String) -> Void` for onInput/onPaste
- `@Sendable (Bool) -> Void` for onHover

Approach: Use type-erased closures. Register `() -> Void` that internally captures and extracts event data from JS event object. DOMRenderer creates the appropriate JSClosure that:
1. Reads event properties from JSValue
2. Constructs Swift type (ScrollOffset, KeyInfo, etc.)
3. Calls the registered closure with the constructed value

#### Reconciler changes

Reconciler.diff() needs to compare old/new `observers` arrays:
- If observers differ → produce new Patch case `.updateObservers(add:, remove:)`
- DOMRenderer applies patch by disconnecting old observers and creating new ones

#### DOMRenderer changes

New responsibility: manage JS observer objects per DOM element.

```swift
// Track active observers per element
private var activeObservers: [JSObject: [JSObject]] = [:]  // element → [observer]

func createObserver(_ observer: WebObserver, for element: JSObject) {
    switch observer {
    case .intersection(let threshold, let callbackID):
        let jsCallback = JSClosure { args in
            // Read IntersectionObserverEntry, call registered handler
        }
        let obs = JSObject.global.IntersectionObserver.new(jsCallback, ["threshold": threshold])
        obs.observe(element)
        activeObservers[element, default: []].append(obs)

    case .resize(let callbackID):
        let obs = JSObject.global.ResizeObserver.new(...)
        obs.observe(element)

    case .lifecycle(.mount, let callbackID):
        // Call immediately after DOM insertion
        EventHandlerRegistry.handler(for: callbackID)?()

    case .lifecycle(.unmount, let callbackID):
        // Store, call before removal
    }
}

func cleanupObservers(for element: JSObject) {
    activeObservers[element]?.forEach { $0.disconnect() }
    activeObservers.removeValue(forKey: element)
}
```

#### .onChange(of:) implementation

This is special — it doesn't map to DOM events. It wraps the child tag in an observation context:

```swift
extension Tag {
    public func onChange<V: Equatable & Sendable>(
        of value: @autoclosure @escaping @Sendable () -> V,
        perform action: @escaping @Sendable (V, V) -> Void
    ) -> some Tag {
        OnChangeModifier(content: self, getValue: value, action: action)
    }
}

struct OnChangeModifier<Content: Tag, V: Equatable & Sendable>: Tag {
    let content: Content
    let getValue: @Sendable () -> V
    let action: @Sendable (V, V) -> Void
    // Subscribes via withObservationTracking in DOMRenderer
}
```

Implementation approach: During render, DOMRenderer detects OnChangeModifier nodes and sets up observation tracking that fires the action closure when the tracked value changes.

---

## Part 2: Vapor Dev Server

### Overview

New executable target `SwiftWUIDevServer` in the main package. Provides two commands:
- `swift run swiftwui-dev` — development server with hot-reload
- `swift run swiftwui-dev build` — production build with optimizations

### Architecture

```
Sources/SwiftWUIDevServer/
    main.swift              — CLI entry point, argument parsing
    DevServer.swift         — Vapor app configuration, routes, WebSocket
    FileWatcher.swift       — File system monitoring for .swift changes
    WASMBuilder.swift       — Invokes swift package js via Process
    HTMLTemplate.swift      — Generates index.html with WS client injection
    ErrorOverlay.swift      — JS code for build error display overlay
    ProductionBuilder.swift — Production build pipeline
```

### Dev Server Flow

```
1. User runs: swift run swiftwui-dev --target Counter --port 8080
2. Initial build: swift package --swift-sdk <sdk> js -c debug
3. Start Vapor HTTP server on :8080
4. Start file watcher on Sources/**/*.swift
5. Serve index.html (with injected WS client)
6. Serve .wasm, .js from PackageToJS output
7. On .swift file change (debounced 300ms):
   a. Send {"type": "building"} via WebSocket
   b. Run swift package js rebuild
   c. On success: send {"type": "reload"}
   d. On failure: send {"type": "error", "message": "..."}
8. Browser receives WS message:
   - "building" → show subtle loading indicator
   - "reload" → location.reload()
   - "error" → show error overlay with compiler output
```

### CLI Interface

```bash
# Development mode
swift run swiftwui-dev [dev] \
    --target <product-name> \       # Required: executable target to build
    --port <port>                   # Default: 8080
    --sdk <swift-sdk-id>            # Default: auto-detect from swift sdk list
    --watch <path>                  # Default: Sources/
    --open                          # Auto-open browser

# Production build
swift run swiftwui-dev build \
    --target <product-name> \       # Required
    --output <path>                 # Default: dist/
    --sdk <swift-sdk-id> \
    --optimize <level>              # default | size | aggressive
```

### File Watcher Implementation

```swift
class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let debounceInterval: TimeInterval = 0.3

    func watch(directory: String, onChange: @escaping () -> Void) {
        #if os(macOS)
        // FSEvents via DispatchSource
        #else
        // Linux: inotify via Process("inotifywait") or polling fallback
        #endif
    }
}
```

Debounce: 300ms after last file change before triggering rebuild. This handles multi-file saves.

### WebSocket Protocol

```json
// Server → Browser messages:
{"type": "connected"}          // Initial connection
{"type": "building"}           // Build started
{"type": "reload"}             // Build success, reload page
{"type": "error", "message": "..."} // Build failed, show error
```

### Injected Client JS (~20 lines)

```javascript
(function() {
    const ws = new WebSocket(`ws://${location.host}/_dev`);
    let overlay = null;

    ws.onmessage = function(e) {
        const msg = JSON.parse(e.data);
        if (msg.type === 'reload') {
            if (overlay) overlay.remove();
            location.reload();
        }
        if (msg.type === 'building') {
            // Show subtle "Rebuilding..." indicator
        }
        if (msg.type === 'error') {
            showErrorOverlay(msg.message);
        }
    };
    ws.onclose = function() {
        // Attempt reconnection every 2s
    };
})();
```

### HTML Template

Generated `index.html`:
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{target}</title>
    <script type="module">
        import { init } from "./{target}.js";
        init();
    </script>
</head>
<body>
    <div id="app"></div>
    <!-- Dev-only: WebSocket client injected here -->
</body>
</html>
```

### WASI Shim Handling

Two strategies:
1. **CDN** (default for dev): `--use-cdn` flag on `swift package js` → fetches `@bjorn3/browser_wasi_shim` from CDN
2. **Bundled** (for production): Include shim in output directory

### Production Build Pipeline

```swift
struct ProductionBuilder {
    enum OptimizeLevel: String {
        case `default`  // release + standard wasm-opt
        case size       // release + wasm-opt -Oz + strip
        case aggressive // release + wasm-opt -O3 + strip + gzip + brotli
    }

    func build(target: String, sdk: String, output: String, optimize: OptimizeLevel) async throws {
        // 1. Build release
        try await runProcess("swift", ["package", "--swift-sdk", sdk, "js",
                                        "-c", "release",
                                        "--debug-info-format", "none"])

        // 2. Copy output to dist/
        try copyPackageOutput(to: output)

        // 3. Generate clean production index.html (no WS client)
        try generateProductionHTML(target: target, output: output)

        // 4. Additional wasm-opt passes based on level
        switch optimize {
        case .size:
            try await runProcess("wasm-opt", ["-Oz", "--strip-debug", ...])
        case .aggressive:
            try await runProcess("wasm-opt", ["-O3", "--strip-debug", ...])
            try compressFiles(in: output)  // gzip + brotli
        case .default:
            break  // PackageToJS already runs wasm-opt in release
        }

        // 5. Content hashing for cache busting
        try addContentHashes(in: output)

        // 6. Print summary (file sizes, etc.)
        printBuildSummary(output: output)
    }
}
```

### Dependencies

Added to Package.swift:
```swift
.package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),

.executableTarget(
    name: "SwiftWUIDevServer",
    dependencies: [
        .product(name: "Vapor", package: "vapor"),
    ]
)
```

No other new dependencies. File watching uses Foundation. Process management uses Foundation.Process.

### Package.swift Conditional Dependencies

Vapor is macOS/Linux only (not WASM). The dev server target is separate from the library targets, so it doesn't affect WASM compilation of SwiftWUI itself.

---

## Testing Strategy

### Modifiers
- Unit tests for each modifier's TagNode conversion (verify observers/eventListeners are set)
- Unit tests for Reconciler diff of observers
- Unit tests for data types (ScrollOffset, Size, Rect, KeyInfo)
- Integration test in Counter example

### Dev Server
- Manual testing of the dev server workflow
- Unit tests for FileWatcher debounce logic
- Unit tests for HTMLTemplate generation
- Unit tests for ProductionBuilder file operations

---

## Implementation Order

Recommended sequence:
1. Core infrastructure (WebObserver type, TagNode changes, Reconciler)
2. Simple DOM event modifiers (onHover, onFocus, onBlur, onInput)
3. Observer-based modifiers (onAppear, onDisappear, onResize, onFrameChange)
4. State modifiers (onChange(of:), task)
5. Remaining DOM modifiers (onScroll, onKeyDown, onDrag/onDrop, clipboard)
6. Lifecycle modifiers (onMount, onUnmount, id)
7. Vapor dev server (HTTP + WS + file watcher)
8. Production build pipeline
