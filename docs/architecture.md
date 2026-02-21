# SwiftWUI Architecture

This document describes the internal architecture of SwiftWUI: how modules are organized, how the rendering pipeline works, and the key design patterns that enable a SwiftUI-like declarative API for the web.

---

## Table of Contents

1. [Module Structure](#module-structure)
2. [Rendering Pipeline](#rendering-pipeline)
3. [Reactivity Model](#reactivity-model)
4. [Virtual DOM](#virtual-dom)
5. [Key Design Patterns](#key-design-patterns)

---

## Module Structure

SwiftWUI is organized into 8 focused modules plus an umbrella module. Each module has a single responsibility and well-defined dependencies.

```
SwiftWUI (umbrella)
  |
  +-- SwiftWUICore        Tag protocol, TagBuilder, TagNode, AnyTag, ForEach,
  |                       ModifiedContent, EventHandlerRegistry, Text, EmptyTag
  |
  +-- SwiftWUIHTML        HTML tags (Div, Span, P, H1-H6, Button, Input, Ul, Li,
  |                       Ol, Form, Table, Select, Textarea, Anchor, Image, etc.)
  |                       HTMLTag protocol, EventHandler type, attribute enums
  |                       Depends on: Core
  |
  +-- SwiftWUIStyles      CSS modifiers (padding, margin, fontSize, backgroundColor, etc.)
  |                       CSSUnit, CSSColor, CSSValue enums, Animation, Transition
  |                       Depends on: Core
  |
  +-- SwiftWUIState       @State, @ObservedObject, @Environment, Binding
  |                       StateStorage (@Observable), EnvironmentValues
  |                       Depends on: Core
  |
  +-- SwiftWUIPage        Page protocol, PageHead, PageRenderer
  |                       Depends on: Core, HTML, Styles
  |
  +-- SwiftWUIRouter      Route, Router, Link, NavigationStack, RouteBuilder
  |                       Depends on: Core, Page
  |
  +-- SwiftWUIRuntime     Application, DOMRenderer, DOMBridge, Reconciler
  |                       StaticRenderer (server-side rendering)
  |                       Depends on: Core, HTML, Styles, State, Page, Router,
  |                       JavaScriptKit
  |
  +-- SwiftWUIBrowser     BrowserEnvironment, AppStorage, SessionStorage,
                          Geolocation, Clipboard, MediaQuery, Localization
                          Depends on: Core, State, JavaScriptKit
```

### Module Dependency Graph

```
                    +---------------+
                    |   SwiftWUI    |  (umbrella -- re-exports all)
                    +-------+-------+
                            |
        +-------+-------+---+---+-------+-------+-------+
        |       |       |       |       |       |       |
      Core    HTML   Styles   State   Page   Router  Runtime  Browser
        |       |       |       |       |       |       |        |
        |   Core    Core    Core    Core    Core    Core+     Core+
        |                           HTML    Page    HTML     State
        |                           Styles          Styles   JSKit
        |                                           State
        |                                           Page
        |                                           Router
        |                                           JSKit
        +-- (no dependencies, foundation of everything)
```

### Why This Structure?

- **Core** has zero external dependencies. It defines the fundamental protocols and types that everything else builds on. You can write and test components with Core alone.
- **HTML** and **Styles** extend Core with DOM-specific functionality but remain independent of each other. You can use HTML tags without CSS modifiers or vice versa.
- **State** depends only on Core and Swift's `Observation` framework. No UIKit, no AppKit, no platform-specific APIs -- this is essential for WebAssembly compatibility.
- **Runtime** is the only module that depends on JavaScriptKit. This keeps the WASM-specific code isolated and allows all other modules to compile and test natively on macOS.
- **Browser** provides browser-specific APIs (localStorage, geolocation, etc.) and is also gated behind `#if canImport(JavaScriptKit)`.

---

## Rendering Pipeline

The rendering pipeline transforms your declarative `Tag` tree into real DOM nodes through four stages.

### Overview

```
  User Code           Core              Runtime              Browser
  --------           ----              -------              -------

  struct MyTag        Tag protocol      Application          DOM
    @State var x      @TagBuilder       DOMRenderer          (real HTML)
    var body: Tag      |                Reconciler
      Div { ... }     |                DOMBridge
                      v                  |
             resolveTagBody()            |
                      |                  |
                      v                  v
                   TagNode         Patch operations
                (virtual DOM)      applied to DOM
```

### Stage 1: Tag Tree Construction (User Code)

Users create a declarative tree of `Tag` values. The `@TagBuilder` result builder enables the SwiftUI-like syntax:

```swift
struct Counter: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            Text("Count: \(count)")
            Button(onclick: { count += 1 }) { Text("+") }
        }
    }
}
```

At this stage, nothing has been rendered. The `body` property returns a tree of Swift structs -- `Div` contains an `AnyTag` wrapping a `TupleTag` of `Text` and `Button`.

### Stage 2: Tag Body Resolution (Core)

The `resolveTagBody()` function recursively resolves custom components down to primitive tags (HTML elements):

```swift
public func resolveTagBody<T: Tag>(_ tag: T) -> [TagNode] {
    if let convertible = tag as? TagNodeConvertible {
        return convertible.toTagNodes()
    }
    let body = tag.body
    if let convertible = body as? TagNodeConvertible {
        return convertible.toTagNodes()
    }
    return resolveTagBody(body)
}
```

**Resolution flow:**

1. Check if the tag directly conforms to `TagNodeConvertible` (all HTML tags do).
2. If not, evaluate its `body` property to get the next layer of tags.
3. Repeat until reaching `TagNodeConvertible` types (primitives like `Div`, `Text`, `Button`).

Each `TagNodeConvertible` produces `[TagNode]` -- the virtual DOM representation:

- `Text("hello")` produces `[.text("hello")]`
- `Div { ... }` produces `[.element(ElementNode(tagName: "div", children: [...]))]`
- `ModifiedContent` applies styles/classes/attributes to the element nodes from its wrapped content
- `ForEach` expands its collection into an array of `TagNode` values

### Stage 3: Reconciliation (Runtime)

The `Reconciler` compares the previous virtual DOM tree with the new one and produces a minimal set of `Patch` operations:

```swift
public struct Reconciler {
    public func diff(old: TagNode?, new: TagNode?) -> Patch?
}
```

The diff algorithm:

1. **Same node type, same tag** -- compare attributes, styles, classes, event listeners, and children recursively.
2. **Same node type, different tag** -- replace the entire subtree.
3. **Text nodes** -- compare strings; emit `updateText` if different.
4. **Fragments** -- diff children arrays positionally.
5. **Missing nodes** -- emit `createNode` or `removeNode`.

### Stage 4: DOM Application (Runtime)

The `DOMRenderer` applies patches to the real DOM through the `DOMBridge`:

```
Reconciler.diff(old, new) -> Patch
       |
       v
DOMRenderer.applyPatch(patch, to: domElement)
       |
       v
DOMBridge.setAttribute / .setStyle / .addClass / ...
       |
       v
JavaScriptKit -> JavaScript DOM API -> Browser renders pixels
```

**Initial render** (`render()`):

1. Clear `EventHandlerRegistry`.
2. Resolve the tag tree to a `TagNode.fragment(...)`.
3. Create real DOM nodes for every virtual node.
4. Append the root DOM node to the container element.

**Subsequent updates** (`update()`):

1. Clear `EventHandlerRegistry` (closures are re-registered during body evaluation).
2. Resolve the new tag tree.
3. Diff against the stored previous tree.
4. Apply only the necessary patches.
5. Store the new tree for the next diff cycle.

---

## Reactivity Model

SwiftWUI's reactivity is built on Swift's native `Observation` framework, with no third-party dependencies.

### @State and StateStorage

```swift
@propertyWrapper
public struct State<Value>: @unchecked Sendable {
    private let storage: StateStorage<Value>

    public var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    public var projectedValue: Binding<Value> { ... }
}

@Observable
final class StateStorage<Value> {
    var value: Value
}
```

**Key design decisions:**

- `StateStorage` is a **reference type** (class), so when a `Tag` struct is copied during re-rendering, all copies share the same storage. This is how state persists across render cycles.
- `@Observable` (from Swift's Observation framework) makes property access trackable via `withObservationTracking`.
- `@unchecked Sendable` is safe because WASM is single-threaded.

### The Observation Loop

The `Application.mount()` method sets up a continuous observation loop:

```
1. withObservationTracking {
      // Track which @State properties are READ during body evaluation
      let tag = router.matchedTag(for: path)
      renderer.render(tag)  // or renderer.update(tag)
   } onChange: {
      // Called when ANY tracked property is about to change (willSet)
      queueMicrotask {
          renderCycle()  // Schedule re-render on next microtask
      }
   }

2. State mutation occurs (e.g., count += 1)
   -> willSet fires on StateStorage.value
   -> onChange callback is invoked
   -> renderCycle is scheduled via queueMicrotask

3. On the next microtask:
   -> The new value is now available (didSet has completed)
   -> body is re-evaluated with the new state
   -> Reconciler diffs old vs. new virtual DOM
   -> DOMRenderer applies patches

4. withObservationTracking re-registers tracking for the new render
   -> Loop continues
```

**Why `queueMicrotask`?**

The `onChange` callback fires during `willSet`, before the new value is stored. If we re-rendered immediately, we would read the old value. By deferring to the next microtask, we guarantee the new value is available when `body` is re-evaluated.

**Why cache tags per route?**

Route closures (e.g., `Route("/") { Counter() }`) create a new `Counter` struct each time they are called. If `Counter` has `@State`, a new `StateStorage` would be allocated, losing all state. To prevent this, `RenderState` caches the `AnyTag` for each route path and only recreates it when the route changes.

### Binding

`Binding<Value>` provides a two-way reference to a piece of state:

```swift
public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }
}
```

Access a binding via the `$` prefix on a `@State` property: `$count` returns `Binding<Int>`.

### @ObservedObject

For externally owned observable objects, `@ObservedObject` wraps an `@Observable` class and provides `Binding` access through dynamic member lookup:

```swift
@Observable class AppModel {
    var username = ""
}

struct Profile: Tag {
    @ObservedObject var model: AppModel

    var body: some Tag {
        Text(model.username)
        // $model.username gives Binding<String>
    }
}
```

### @Environment

Environment values propagate data down the tag tree without explicit passing:

```swift
@Environment(\.theme) var theme
```

Currently implemented as a global singleton (`CurrentEnvironment.values`). Environment keys are defined via the `EnvironmentKey` protocol.

---

## Virtual DOM

### TagNode

The virtual DOM is represented by the `TagNode` enum:

```swift
public enum TagNode: Equatable, Sendable {
    case element(Element)
    case text(String)
    case fragment([TagNode])
}
```

#### TagNode.Element

```swift
public struct Element: Equatable, Sendable {
    public var tagName: String                           // "div", "button", "input"
    public var attributes: [String: String]              // id, href, type, value, ...
    public var styles: [String: String]                  // CSS property -> value
    public var classes: [String]                         // CSS class names
    public var eventListeners: [String: EventListenerID] // event name -> listener ID
    public var children: [TagNode]                       // child nodes
}
```

#### TagNode.text

A plain text node. Rendered as a DOM `TextNode`.

#### TagNode.fragment

A group of sibling nodes without a wrapper element. In the current implementation, fragments are rendered as a `<div data-swiftwui-fragment="true">` container element because the browser DOM requires a single root node.

### Patch Operations

The `Reconciler` produces `Patch` values that describe the minimal DOM mutations needed:

```swift
public enum Patch: Sendable {
    case createNode(TagNode)                                           // Insert a new node
    case removeNode                                                    // Remove existing node
    case replaceNode(with: TagNode)                                    // Replace entirely
    case updateText(String)                                            // Change text content
    case updateAttributes(add: [String: String], remove: [String])     // Add/remove HTML attrs
    case updateStyles(add: [String: String], remove: [String])         // Add/remove CSS styles
    case updateClasses(add: [String], remove: [String])                // Add/remove CSS classes
    case updateEventListeners(add: [String: EventListenerID],          // Add/remove event
                              remove: [String])                        //   listeners
    case patchChildren([ChildPatch])                                   // Recurse into children
}
```

`ChildPatch` pairs an index with a `Patch`:

```swift
public struct ChildPatch: Sendable {
    public let index: Int    // Child index (-1 means "apply to self")
    public let patch: Patch
}
```

### Diffing Algorithm

The current algorithm uses a **positional diff** strategy:

1. Iterate over children by index up to `max(old.count, new.count)`.
2. For each index, diff `old[i]` vs `new[i]`.
3. Extra nodes on the new side produce `createNode`; extra nodes on the old side produce `removeNode`.

This approach is simple and correct but not optimal for reordering (no key-based reconciliation yet). The `Identifiable` conformance on `ForEach` data is reserved for a future key-based diff optimization.

---

## Key Design Patterns

### Tag Protocol and @TagBuilder

The `Tag` protocol mirrors SwiftUI's `View`:

```swift
public protocol Tag {
    associatedtype Body: Tag
    @TagBuilder var body: Body { get }
}
```

- **Custom components** (user code) have `Body` as `some Tag` and provide a `body` implementation.
- **Primitive tags** (HTML elements) have `Body == Never` and render directly via `TagNodeConvertible`.

The `@TagBuilder` result builder supports:

- Single expressions: `Div { Text("hello") }`
- Multiple expressions: `Div { Text("a"); Text("b") }` via variadic `buildBlock`
- Conditionals: `if condition { A() } else { B() }` via `buildEither`
- Optionals: `if let x { Text(x) }` via `buildOptional`
- String literals: `Div { "hello" }` auto-converted to `Text` via `buildExpression`

### ModifiedContent

`ModifiedContent<Content: Tag>` wraps a tag with additional styles, classes, or attributes:

```swift
public struct ModifiedContent<Content: Tag>: Tag {
    public typealias Body = Never
    public let content: Content
    public var styles: [(String, String)]
    public var classes: [String]
    public var attributes: [(String, String)]
}
```

When converting to `TagNode`, `ModifiedContent` resolves its `content` first, then merges its modifications into each resulting element node. This design allows modifiers to chain naturally:

```swift
Div { "Hello" }
    .padding(.px(16))         // ModifiedContent<Div>
    .backgroundColor(.red)    // ModifiedContent<Div> (same level, appended)
```

The chaining extensions on `ModifiedContent` append to the same wrapper rather than creating nested wrappers, keeping the type flat.

### AnyTag (Type Erasure)

`AnyTag` wraps `any Tag` for use in heterogeneous collections:

```swift
public struct AnyTag: Tag {
    public typealias Body = Never
    let storage: any Tag
}
```

Used extensively by HTML tags to store mixed children, and by `Route` builders to return different tag types from route closures.

### EventHandlerRegistry

Closures cannot be compared for equality, but the virtual DOM diff needs to detect event listener changes. The `EventHandlerRegistry` solves this:

1. During tag-to-TagNode conversion, each event handler closure is registered in the global registry and assigned a unique `EventListenerID`.
2. The `TagNode.Element` stores `[String: EventListenerID]` (event name to ID).
3. The `Reconciler` compares IDs to detect which listeners changed.
4. The `DOMRenderer` uses the registry to look up the actual closure when attaching it to the DOM.

```swift
public enum EventHandlerRegistry {
    static func register(_ handler: @escaping @Sendable () -> Void) -> EventListenerID
    static func handler(for id: EventListenerID) -> (@Sendable () -> Void)?
    static func clear()
}
```

The registry is **cleared at the start of every render cycle** and repopulated during body evaluation. This ensures stale closures are garbage collected.

### Conditional Compilation Guards

The `#if canImport(JavaScriptKit)` guard separates WASM-only code from platform-independent code:

```swift
#if canImport(JavaScriptKit)
import JavaScriptKit

public func mount(on elementId: String = "app") {
    // Real DOM rendering with JavaScriptKit
}
#else
public func mount(on elementId: String = "app") {
    print("SwiftWUI: mount() is only available in WASM environment")
}
#endif
```

This pattern appears in `Application`, `DOMRenderer`, `DOMBridge`, and `SwiftWUIBrowser`. It allows:

- Running `swift test` natively on macOS for all non-DOM logic.
- Full compilation of the library in both environments.

### @unchecked Sendable for WASM

WebAssembly currently runs in a single-threaded environment. Types that would normally need synchronization are marked `@unchecked Sendable` with a clear comment explaining why:

```swift
// @unchecked Sendable because WASM is single-threaded
public final class Router: @unchecked Sendable { ... }
public struct State<Value>: @unchecked Sendable { ... }
```

Similarly, `nonisolated(unsafe)` is used for mutable variables captured in `@Sendable` closures:

```swift
nonisolated(unsafe) var renderCycle: (() -> Void)!
```

### DOMBridge and Event Listener Tracking

The `DOMBridge` wraps all JavaScript DOM operations via JavaScriptKit. A critical pattern is **tracked event listeners** to prevent listener accumulation:

```swift
public func setTrackedEventListener(
    _ element: JSObject,
    event: String,
    handler: @escaping () -> Void
) {
    let dataKey = "__swev_\(event)"
    // Remove previous listener for this event if present
    if let oldId = element[dataKey].string {
        removeEventListener(element, event: event, id: oldId)
    }
    let id = addEventListener(element, event: event, handler: handler)
    element[dataKey] = .string(id)
}
```

Each DOM element stores its current listener ID as a JavaScript property (`__swev_click`, etc.). When a new listener is set for the same event, the old one is automatically removed first. This prevents memory leaks and duplicate event firings across re-renders.

### Animation Integration

Animations use a global context pattern:

1. `withAnimation(.easeInOut(duration: 0.3)) { stateMutation() }` sets `AnimationContext.current`.
2. The mutation triggers `onChange`, scheduling a re-render.
3. The render cycle captures `AnimationContext.current` and clears it.
4. During `DOMRenderer.applyPatch()`, if an `Animation` is active and styles changed, a CSS `transition` property is set on the element before applying the new styles.
5. The browser handles the visual interpolation.

The `.animation()` modifier takes a different approach: it sets a permanent `transition` CSS property on the element, so all future style changes are automatically animated by the browser.

---

## Further Reading

- [Tutorial: Building a Todo App](./tutorial.md) -- hands-on guide to using SwiftWUI
- `Sources/SwiftWUICore/` -- Tag protocol, TagBuilder, TagNode, and all foundational types
- `Sources/SwiftWUIRuntime/` -- Application, DOMRenderer, DOMBridge, Reconciler
- `Sources/SwiftWUIStyles/` -- all CSS modifiers, CSSUnit, CSSColor, Animation
- `Examples/Counter/` -- a working counter application you can build and run
