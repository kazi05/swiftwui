# Web Modifiers + Vapor Dev Server — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 20 web-adapted modifiers (State observation, DOM events, geometry observers, lifecycle) and a Vapor-based dev server with hot-reload and production build.

**Architecture:** Two independent workstreams: (1) Modifiers extend TagNode with `observers` field, use EventHandlerRegistry for callbacks, DOMRenderer creates/manages JS observers. (2) Dev server is a new executable target using Vapor for HTTP/WebSocket, Foundation.Process for builds, DispatchSource for file watching.

**Tech Stack:** Swift 6.0, JavaScriptKit, Observation framework, Vapor 4, SwiftNIO (via Vapor)

---

## Workstream 1: Web Modifiers

### Task 1: Add WebObserver types to SwiftWUICore

**Files:**
- Create: `Sources/SwiftWUICore/WebObserver.swift`
- Test: `Tests/SwiftWUICoreTests/WebObserverTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/SwiftWUICoreTests/WebObserverTests.swift
import Testing
@testable import SwiftWUICore

@Suite("WebObserver")
struct WebObserverTests {
    @Test("WebObserver intersection is equatable")
    func intersectionEquatable() {
        let id1 = EventListenerID("test-1")
        let id2 = EventListenerID("test-1")
        let obs1 = WebObserver.intersection(threshold: 0.5, callbackID: id1)
        let obs2 = WebObserver.intersection(threshold: 0.5, callbackID: id2)
        #expect(obs1 == obs2)
    }

    @Test("WebObserver resize stores callback")
    func resizeStoresCallback() {
        let id = EventListenerID("resize-cb")
        let obs = WebObserver.resize(callbackID: id)
        if case .resize(let cbID) = obs {
            #expect(cbID == id)
        } else {
            Issue.record("Expected resize observer")
        }
    }

    @Test("MutationOptions defaults")
    func mutationOptionsDefaults() {
        let opts = MutationOptions()
        #expect(opts.childList == false)
        #expect(opts.attributes == false)
        #expect(opts.subtree == false)
    }

    @Test("LifecycleEvent cases")
    func lifecycleEventCases() {
        #expect(LifecycleEvent.mount != LifecycleEvent.unmount)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter WebObserverTests 2>&1 | head -20`
Expected: FAIL — types not found

**Step 3: Write minimal implementation**

```swift
// Sources/SwiftWUICore/WebObserver.swift

/// Represents a JavaScript observer to be attached to a DOM element.
/// Stored in TagNode.Element and managed by DOMRenderer.
public enum WebObserver: Equatable, Sendable {
    /// IntersectionObserver — fires when element enters/exits viewport.
    case intersection(threshold: Double, callbackID: EventListenerID)
    /// ResizeObserver — fires when element size changes.
    case resize(callbackID: EventListenerID)
    /// MutationObserver — fires on DOM subtree changes.
    case mutation(options: MutationOptions, callbackID: EventListenerID)
    /// Lifecycle event — mount/unmount hooks.
    case lifecycle(event: LifecycleEvent, callbackID: EventListenerID)
}

/// Configuration for MutationObserver.
public struct MutationOptions: Equatable, Sendable {
    public var childList: Bool
    public var attributes: Bool
    public var subtree: Bool

    public init(childList: Bool = false, attributes: Bool = false, subtree: Bool = false) {
        self.childList = childList
        self.attributes = attributes
        self.subtree = subtree
    }
}

/// Lifecycle events for DOM elements.
public enum LifecycleEvent: Equatable, Sendable {
    case mount
    case unmount
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter WebObserverTests`
Expected: PASS (4/4)

**Step 5: Commit**

```bash
git add Sources/SwiftWUICore/WebObserver.swift Tests/SwiftWUICoreTests/WebObserverTests.swift
git commit -m "feat: add WebObserver, MutationOptions, LifecycleEvent types"
```

---

### Task 2: Add callback data types (ScrollOffset, Size, Rect, KeyInfo)

**Files:**
- Create: `Sources/SwiftWUICore/WebEventTypes.swift`
- Test: `Tests/SwiftWUICoreTests/WebEventTypesTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/SwiftWUICoreTests/WebEventTypesTests.swift
import Testing
@testable import SwiftWUICore

@Suite("WebEventTypes")
struct WebEventTypesTests {
    @Test("ScrollOffset stores x and y")
    func scrollOffset() {
        let offset = ScrollOffset(x: 100, y: 200)
        #expect(offset.x == 100)
        #expect(offset.y == 200)
    }

    @Test("Size stores width and height")
    func sizeValues() {
        let size = ElementSize(width: 320, height: 480)
        #expect(size.width == 320)
        #expect(size.height == 480)
    }

    @Test("Rect stores all fields")
    func rectValues() {
        let rect = ElementRect(x: 10, y: 20, width: 100, height: 50)
        #expect(rect.x == 10)
        #expect(rect.y == 20)
        #expect(rect.width == 100)
        #expect(rect.height == 50)
    }

    @Test("KeyInfo stores all fields")
    func keyInfoValues() {
        let key = KeyInfo(key: "Enter", code: "Enter", ctrlKey: false, shiftKey: true, altKey: false, metaKey: false)
        #expect(key.key == "Enter")
        #expect(key.code == "Enter")
        #expect(key.shiftKey == true)
        #expect(key.ctrlKey == false)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter WebEventTypesTests 2>&1 | head -20`
Expected: FAIL — types not found

**Step 3: Write minimal implementation**

```swift
// Sources/SwiftWUICore/WebEventTypes.swift

/// Scroll position of an element.
public struct ScrollOffset: Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Size of a DOM element (from ResizeObserver).
public struct ElementSize: Sendable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Bounding rectangle of a DOM element (from getBoundingClientRect).
public struct ElementRect: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Keyboard event information.
public struct KeyInfo: Sendable, Equatable {
    public let key: String
    public let code: String
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    public let metaKey: Bool

    public init(key: String, code: String, ctrlKey: Bool, shiftKey: Bool, altKey: Bool, metaKey: Bool) {
        self.key = key
        self.code = code
        self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey
        self.altKey = altKey
        self.metaKey = metaKey
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter WebEventTypesTests`
Expected: PASS (4/4)

**Step 5: Commit**

```bash
git add Sources/SwiftWUICore/WebEventTypes.swift Tests/SwiftWUICoreTests/WebEventTypesTests.swift
git commit -m "feat: add ScrollOffset, ElementSize, ElementRect, KeyInfo types"
```

---

### Task 3: Add `observers` field to TagNode.Element

**Files:**
- Modify: `Sources/SwiftWUICore/TagNode.swift:11-38`
- Test: `Tests/SwiftWUICoreTests/WebObserverTests.swift` (extend)

**Step 1: Write the failing test**

Add to `Tests/SwiftWUICoreTests/WebObserverTests.swift`:

```swift
@Test("TagNode.Element stores observers")
func tagNodeElementStoresObservers() {
    let obs = WebObserver.resize(callbackID: EventListenerID("cb"))
    let element = TagNode.Element(
        tagName: "div",
        observers: [obs]
    )
    #expect(element.observers.count == 1)
    #expect(element.observers[0] == obs)
}

@Test("TagNode.Element observers default empty")
func tagNodeElementObserversDefault() {
    let element = TagNode.Element(tagName: "div")
    #expect(element.observers.isEmpty)
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter WebObserverTests 2>&1 | head -20`
Expected: FAIL — `observers` parameter does not exist

**Step 3: Modify TagNode.Element**

In `Sources/SwiftWUICore/TagNode.swift`, add `observers` field to `Element`:
- Add `public var observers: [WebObserver]` after line 19 (`responsiveStyles`)
- Add `observers: [WebObserver] = []` parameter to `init` after `responsiveStyles` parameter
- Add `self.observers = observers` in init body

**Step 4: Run test to verify it passes**

Run: `swift test --filter WebObserverTests`
Expected: PASS (6/6)

**Step 5: Run full test suite**

Run: `swift test`
Expected: All 51+ tests pass (existing tests use default `observers: []`)

**Step 6: Commit**

```bash
git add Sources/SwiftWUICore/TagNode.swift Tests/SwiftWUICoreTests/WebObserverTests.swift
git commit -m "feat: add observers field to TagNode.Element"
```

---

### Task 4: Extend EventHandlerRegistry for typed callbacks

Currently `EventHandlerRegistry` only stores `@Sendable () -> Void`. We need typed callbacks for modifiers that receive data (onScroll, onResize, etc.). The approach: store type-erased closures. The DOMRenderer creates a `() -> Void` wrapper that extracts event data from JS and calls the typed closure.

**Files:**
- Modify: `Sources/SwiftWUICore/EventHandlerRegistry.swift:1-32`
- Test: `Tests/SwiftWUICoreTests/WebEventTypesTests.swift` (extend)

**Step 1: Write the failing test**

Add to `Tests/SwiftWUICoreTests/WebEventTypesTests.swift`:

```swift
@Test("EventHandlerRegistry registers typed callback via wrapper")
func typedCallbackWrapper() {
    EventHandlerRegistry.clear()
    var received: String? = nil
    // Register a () -> Void that wraps typed logic
    let id = EventHandlerRegistry.register {
        received = "called"
    }
    let handler = EventHandlerRegistry.handler(for: id)
    #expect(handler != nil)
    handler?()
    #expect(received == "called")
}
```

**Step 2: Run test — this should already pass**

Run: `swift test --filter "typedCallbackWrapper"`
Expected: PASS — existing registry already handles `() -> Void`

This confirms the existing architecture works: modifiers register `() -> Void` closures that internally capture typed behavior. No changes needed to EventHandlerRegistry itself.

**Step 3: Commit (if test was added)**

```bash
git add Tests/SwiftWUICoreTests/WebEventTypesTests.swift
git commit -m "test: verify EventHandlerRegistry works for typed callback wrappers"
```

---

### Task 5: DOM event modifiers — onHover, onFocus, onBlur

These are simple event listener modifiers that work on any Tag. They store closures in `eventListeners` dict on TagNode.Element via the existing modifier pipeline.

**Files:**
- Create: `Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift`
- Test: `Tests/SwiftWUIHTMLTests/EventModifiersTests.swift`

**Step 1: Write the failing test**

```swift
// Tests/SwiftWUIHTMLTests/EventModifiersTests.swift
import Testing
@testable import SwiftWUICore
@testable import SwiftWUIHTML

@Suite("Event Modifiers")
struct EventModifiersTests {
    @Test("onHover registers mouseenter and mouseleave listeners")
    func onHoverRegistersListeners() {
        EventHandlerRegistry.clear()
        let div = Div {}
            .onHover { _ in }
        let nodes = resolveTagBody(div)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["mouseenter"] != nil)
        #expect(el.eventListeners["mouseleave"] != nil)
    }

    @Test("onFocus registers focus listener")
    func onFocusRegistersListener() {
        EventHandlerRegistry.clear()
        let input = Input(type: "text")
            .onFocus { }
        let nodes = resolveTagBody(input)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["focus"] != nil)
    }

    @Test("onBlur registers blur listener")
    func onBlurRegistersListener() {
        EventHandlerRegistry.clear()
        let input = Input(type: "text")
            .onBlur { }
        let nodes = resolveTagBody(input)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["blur"] != nil)
    }

    @Test("onInput registers input listener")
    func onInputRegistersListener() {
        EventHandlerRegistry.clear()
        let input = Input(type: "text")
            .onInput { _ in }
        let nodes = resolveTagBody(input)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["input"] != nil)
    }

    @Test("onSubmit registers submit listener")
    func onSubmitRegistersListener() {
        EventHandlerRegistry.clear()
        let form = Form {}
            .onSubmit { }
        let nodes = resolveTagBody(form)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element"); return
        }
        #expect(el.eventListeners["submit"] != nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter EventModifiersTests 2>&1 | head -20`
Expected: FAIL — `.onHover`, `.onFocus`, etc. not found

**Step 3: Write implementation**

The modifiers need to work on any `Tag`, not just `HTMLTag`. They should store events in the TagNode via the modifier pipeline. For non-HTMLTag types, we need a different approach — wrapping in a container that holds event info.

Best approach: extend `HTMLTag` (since events are only meaningful on DOM elements) and use the existing `.on()` method internally.

```swift
// Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift
import SwiftWUICore

// MARK: - Simple Event Modifiers on HTMLTag

extension HTMLTag {
    /// Called when the mouse enters or leaves the element.
    /// - Parameter action: Closure receiving `true` when hovering, `false` when not.
    public func onHover(_ action: @escaping @Sendable (Bool) -> Void) -> Self {
        var copy = self
        copy.eventListeners["mouseenter"] = { action(true) }
        copy.eventListeners["mouseleave"] = { action(false) }
        return copy
    }

    /// Called when the element receives focus.
    public func onFocus(_ action: @escaping @Sendable () -> Void) -> Self {
        on(.focus, handler: action)
    }

    /// Called when the element loses focus.
    public func onBlur(_ action: @escaping @Sendable () -> Void) -> Self {
        on(.blur, handler: action)
    }

    /// Called when the element's value changes (input event).
    /// The closure receives the current input value as a String.
    /// Note: The actual value extraction happens in DOMRenderer at runtime.
    /// In non-WASM context, the closure is called with empty string.
    public func onInput(_ action: @escaping @Sendable (String) -> Void) -> Self {
        var copy = self
        copy.eventListeners["input"] = { action("") }
        return copy
    }

    /// Called when a form is submitted. Prevents default form submission.
    public func onSubmit(_ action: @escaping @Sendable () -> Void) -> Self {
        on(.submit, handler: action)
    }

    /// Called on scroll event.
    /// The closure receives the current scroll offset.
    public func onScroll(_ action: @escaping @Sendable (ScrollOffset) -> Void) -> Self {
        var copy = self
        copy.eventListeners["scroll"] = { action(ScrollOffset(x: 0, y: 0)) }
        return copy
    }

    /// Called on keydown event.
    public func onKeyDown(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
        var copy = self
        let placeholder = KeyInfo(key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
        copy.eventListeners["keydown"] = { action(placeholder) }
        return copy
    }

    /// Called on keyup event.
    public func onKeyUp(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
        var copy = self
        let placeholder = KeyInfo(key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
        copy.eventListeners["keyup"] = { action(placeholder) }
        return copy
    }

    /// Called on copy event.
    public func onCopy(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        copy.eventListeners["copy"] = action
        return copy
    }

    /// Called on paste event.
    /// The closure receives clipboard text. Value extraction at runtime.
    public func onPaste(_ action: @escaping @Sendable (String) -> Void) -> Self {
        var copy = self
        copy.eventListeners["paste"] = { action("") }
        return copy
    }

    /// Called on drag start.
    public func onDrag(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        copy.eventListeners["dragstart"] = action
        return copy
    }

    /// Called on drop event.
    public func onDrop(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        copy.eventListeners["drop"] = action
        return copy
    }
}
```

**Step 4: Run test to verify it passes**

Run: `swift test --filter EventModifiersTests`
Expected: PASS (5/5)

**Step 5: Commit**

```bash
git add Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift Tests/SwiftWUIHTMLTests/EventModifiersTests.swift
git commit -m "feat: add DOM event modifiers (onHover, onFocus, onBlur, onInput, onSubmit, onScroll, onKeyDown, onKeyUp, onCopy, onPaste, onDrag, onDrop)"
```

---

### Task 6: DOMBridge — typed event listener support

The current `DOMBridge.addEventListener` takes `() -> Void`. For typed modifiers (onInput gets value, onKeyDown gets KeyInfo, onScroll gets offset), DOMRenderer needs to extract data from the JS event object. Add a new `addTypedEventListener` method.

**Files:**
- Modify: `Sources/SwiftWUIRuntime/DOMBridge.swift:123-172`

**Step 1: Add typed event listener methods to DOMBridge**

Add after the existing `addEventListener` method (after line 140):

```swift
/// Add an event listener that receives the raw JSValue event object.
/// Used by DOMRenderer to extract typed data (value, key, scroll offset, etc.)
public func addEventListenerWithEvent(
    _ element: JSObject,
    event: String,
    handler: @escaping (JSValue) -> Void
) -> String {
    let id = "\(event)-\(UUID().uuidString)"
    let closure = JSClosure { args in
        let jsEvent = args.count > 0 ? args[0] : .undefined
        handler(jsEvent)
        return .undefined
    }
    closures[id] = closure
    _ = element.addEventListener!(event, closure)
    return id
}

/// Set a tracked event listener that receives the raw JS event object.
public func setTrackedEventListenerWithEvent(
    _ element: JSObject,
    event: String,
    handler: @escaping (JSValue) -> Void
) {
    let dataKey = "__swev_\(event)"
    if let oldId = element[dataKey].string {
        removeEventListener(element, event: event, id: oldId)
    }
    let id = addEventListenerWithEvent(element, event: event, handler: handler)
    element[dataKey] = .string(id)
}
```

**Step 2: Run full test suite**

Run: `swift test`
Expected: All tests pass (new methods are additive, no existing tests affected)

**Step 3: Commit**

```bash
git add Sources/SwiftWUIRuntime/DOMBridge.swift
git commit -m "feat: add typed event listener methods to DOMBridge (receives JSValue event)"
```

---

### Task 7: DOMRenderer — typed event handling for onInput, onScroll, onKeyDown

Update DOMRenderer to use the typed DOMBridge methods for events that need data extraction.

**Files:**
- Modify: `Sources/SwiftWUIRuntime/DOMRenderer.swift:90-95` (createDOMNode event section)
- Modify: `Sources/SwiftWUIRuntime/DOMRenderer.swift:179-187` (applyPatch event section)

**Step 1: Identify typed events**

Events needing JS data extraction: `input`, `scroll`, `keydown`, `keyup`, `paste`. The DOMRenderer checks the event name and uses the typed listener for these.

**Step 2: Modify createDOMNode**

In `DOMRenderer.swift`, replace the event listener loop in `createDOMNode` (around lines 91-95):

```swift
// Set event listeners from the global registry (tracked for proper cleanup)
for (event, listenerID) in element.eventListeners {
    if let handler = EventHandlerRegistry.handler(for: listenerID) {
        attachEventListener(to: domElement, event: event, handler: handler)
    }
}
```

Add a new private method:

```swift
/// Attach event listener with appropriate handling for typed events.
/// For events like input/scroll/keydown, extracts data from JS event object.
private func attachEventListener(to element: JSObject, event: String, handler: @escaping () -> Void) {
    switch event {
    case "input":
        bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
            // Extract value from event.target.value
            if let target = jsEvent.object?["target"].object,
               let value = target["value"].string {
                // The handler was registered as () -> Void wrapping (String) -> Void
                // We need a way to pass the value. Use a thread-local or global.
                InputEventContext.currentValue = value
            }
            handler()
            InputEventContext.currentValue = nil
        }
    case "scroll":
        bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
            if let target = jsEvent.object?["target"].object {
                let scrollLeft = target["scrollLeft"].number ?? 0
                let scrollTop = target["scrollTop"].number ?? 0
                ScrollEventContext.currentOffset = ScrollOffset(x: scrollLeft, y: scrollTop)
            }
            handler()
            ScrollEventContext.currentOffset = nil
        }
    case "keydown", "keyup":
        bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
            if let evt = jsEvent.object {
                KeyEventContext.currentKey = KeyInfo(
                    key: evt["key"].string ?? "",
                    code: evt["code"].string ?? "",
                    ctrlKey: evt["ctrlKey"].boolean ?? false,
                    shiftKey: evt["shiftKey"].boolean ?? false,
                    altKey: evt["altKey"].boolean ?? false,
                    metaKey: evt["metaKey"].boolean ?? false
                )
            }
            handler()
            KeyEventContext.currentKey = nil
        }
    case "paste":
        bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
            if let clipboardData = jsEvent.object?["clipboardData"].object,
               let text = clipboardData.getData?("text/plain").string {
                PasteEventContext.currentText = text
            }
            handler()
            PasteEventContext.currentText = nil
        }
    case "submit":
        bridge.setTrackedEventListenerWithEvent(element, event: event) { jsEvent in
            _ = jsEvent.object?.preventDefault?()
            handler()
        }
    default:
        bridge.setTrackedEventListener(element, event: event, handler: handler)
    }
}
```

Also add event context types (at the top of DOMRenderer.swift or in a separate file):

```swift
/// Thread-local context for passing typed event data from JS to Swift closures.
/// Safe because WASM is single-threaded.
enum InputEventContext {
    nonisolated(unsafe) static var currentValue: String?
}

enum ScrollEventContext {
    nonisolated(unsafe) static var currentOffset: ScrollOffset?
}

enum KeyEventContext {
    nonisolated(unsafe) static var currentKey: KeyInfo?
}

enum PasteEventContext {
    nonisolated(unsafe) static var currentText: String?
}
```

**Step 3: Update EventModifiers to read from context**

Modify `Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift` — update closures to read from context:

```swift
public func onInput(_ action: @escaping @Sendable (String) -> Void) -> Self {
    var copy = self
    copy.eventListeners["input"] = {
        let value = InputEventContext.currentValue ?? ""
        action(value)
    }
    return copy
}

public func onScroll(_ action: @escaping @Sendable (ScrollOffset) -> Void) -> Self {
    var copy = self
    copy.eventListeners["scroll"] = {
        let offset = ScrollEventContext.currentOffset ?? ScrollOffset(x: 0, y: 0)
        action(offset)
    }
    return copy
}

public func onKeyDown(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
    var copy = self
    copy.eventListeners["keydown"] = {
        let key = KeyEventContext.currentKey ?? KeyInfo(key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
        action(key)
    }
    return copy
}

public func onKeyUp(_ action: @escaping @Sendable (KeyInfo) -> Void) -> Self {
    var copy = self
    copy.eventListeners["keyup"] = {
        let key = KeyEventContext.currentKey ?? KeyInfo(key: "", code: "", ctrlKey: false, shiftKey: false, altKey: false, metaKey: false)
        action(key)
    }
    return copy
}

public func onPaste(_ action: @escaping @Sendable (String) -> Void) -> Self {
    var copy = self
    copy.eventListeners["paste"] = {
        let text = PasteEventContext.currentText ?? ""
        action(text)
    }
    return copy
}
```

**Step 4: Update applyPatch for event listeners**

In DOMRenderer's `applyPatch`, in the `.updateEventListeners` case (around line 183), replace:
```swift
bridge.setTrackedEventListener(element, event: event, handler: handler)
```
with:
```swift
attachEventListener(to: element, event: event, handler: handler)
```

**Step 5: Run full tests**

Run: `swift test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Sources/SwiftWUIRuntime/DOMRenderer.swift Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift
git commit -m "feat: add typed event handling for input/scroll/key/paste/submit in DOMRenderer"
```

---

### Task 8: Observer-based modifiers — onAppear, onDisappear, onResize, onFrameChange

These use Web Observer APIs (IntersectionObserver, ResizeObserver) and store `WebObserver` values in TagNode.

**Files:**
- Modify: `Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift` (add observer modifiers)
- Modify: `Sources/SwiftWUICore/TagNodeConvertible.swift:71-110` (merge observers in ModifiedContent)
- Modify: `Sources/SwiftWUIHTML/HTMLTag.swift:33-59` (pass observers to TagNode)
- Test: `Tests/SwiftWUIHTMLTests/EventModifiersTests.swift` (extend)

**Step 1: Add observers storage to HTMLTag**

First, we need HTMLTag to be able to store observers. Add to the protocol in `Sources/SwiftWUIHTML/HTMLTag.swift`:

```swift
/// Web observers (IntersectionObserver, ResizeObserver, etc.)
var observers: [WebObserver] { get set }
```

And update `toTagNodes()` to pass observers to TagNode.Element:

```swift
let element = TagNode.Element(
    tagName: Self.tagName,
    attributes: attributes,
    styles: styles,
    classes: classes,
    eventListeners: listenerIDs,
    children: childNodes,
    observers: observers  // NEW
)
```

Note: All HTMLTag conformances (Div, Button, etc.) will need `var observers: [WebObserver] = []` added. Check all existing HTMLTag implementations.

**Step 2: Write failing test**

Add to `Tests/SwiftWUIHTMLTests/EventModifiersTests.swift`:

```swift
@Test("onAppear adds intersection observer to TagNode")
func onAppearAddsObserver() {
    EventHandlerRegistry.clear()
    let div = Div {}
        .onAppear { }
    let nodes = resolveTagBody(div)
    guard case .element(let el) = nodes.first else {
        Issue.record("Expected element"); return
    }
    #expect(el.observers.count == 1)
    if case .intersection(let threshold, _) = el.observers.first {
        #expect(threshold == 0)
    } else {
        Issue.record("Expected intersection observer")
    }
}

@Test("onDisappear adds intersection observer")
func onDisappearAddsObserver() {
    EventHandlerRegistry.clear()
    let div = Div {}
        .onDisappear { }
    let nodes = resolveTagBody(div)
    guard case .element(let el) = nodes.first else {
        Issue.record("Expected element"); return
    }
    #expect(el.observers.count == 1)
}

@Test("onResize adds resize observer")
func onResizeAddsObserver() {
    EventHandlerRegistry.clear()
    let div = Div {}
        .onResize { _ in }
    let nodes = resolveTagBody(div)
    guard case .element(let el) = nodes.first else {
        Issue.record("Expected element"); return
    }
    #expect(el.observers.count == 1)
    if case .resize(_) = el.observers.first {
        // OK
    } else {
        Issue.record("Expected resize observer")
    }
}

@Test("onFrameChange adds resize observer for rect")
func onFrameChangeAddsObserver() {
    EventHandlerRegistry.clear()
    let div = Div {}
        .onFrameChange { _ in }
    let nodes = resolveTagBody(div)
    guard case .element(let el) = nodes.first else {
        Issue.record("Expected element"); return
    }
    #expect(el.observers.count == 1)
}
```

**Step 3: Run test to verify it fails**

Run: `swift test --filter EventModifiersTests 2>&1 | head -30`
Expected: FAIL — `.onAppear` not found, `observers` not in HTMLTag

**Step 4: Implement**

Add `observers` to HTMLTag protocol and all concrete HTML tags. Then add observer modifiers:

```swift
// In Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift

extension HTMLTag {
    /// Called when the element enters the viewport.
    public func onAppear(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register(action)
        copy.observers.append(.intersection(threshold: 0, callbackID: id))
        return copy
    }

    /// Called when the element leaves the viewport.
    public func onDisappear(_ action: @escaping @Sendable () -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register(action)
        // Use negative threshold convention to distinguish from onAppear
        copy.observers.append(.intersection(threshold: -1, callbackID: id))
        return copy
    }

    /// Called when the element is resized. Receives the new size.
    public func onResize(_ action: @escaping @Sendable (ElementSize) -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register {
            let size = ResizeEventContext.currentSize ?? ElementSize(width: 0, height: 0)
            action(size)
        }
        copy.observers.append(.resize(callbackID: id))
        return copy
    }

    /// Called when the element's frame changes. Receives full bounding rect.
    public func onFrameChange(_ action: @escaping @Sendable (ElementRect) -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register {
            let rect = FrameChangeContext.currentRect ?? ElementRect(x: 0, y: 0, width: 0, height: 0)
            action(rect)
        }
        // Use resize observer internally, DOMRenderer will also call getBoundingClientRect
        copy.observers.append(.resize(callbackID: id))
        return copy
    }

    /// Called with intersection ratio (0.0 to 1.0) at given threshold.
    public func onIntersection(threshold: Double = 0.5, action: @escaping @Sendable (Double) -> Void) -> Self {
        var copy = self
        let id = EventHandlerRegistry.register {
            let ratio = IntersectionContext.currentRatio ?? 0
            action(ratio)
        }
        copy.observers.append(.intersection(threshold: threshold, callbackID: id))
        return copy
    }
}
```

Add event contexts:

```swift
// In DOMRenderer.swift (alongside other contexts)
enum ResizeEventContext {
    nonisolated(unsafe) static var currentSize: ElementSize?
}

enum FrameChangeContext {
    nonisolated(unsafe) static var currentRect: ElementRect?
}

enum IntersectionContext {
    nonisolated(unsafe) static var currentRatio: Double?
}
```

**Step 5: Update ModifiedContent.toTagNodes() to merge observers**

In `Sources/SwiftWUICore/TagNodeConvertible.swift`, inside the `ModifiedContent` extension (around line 105), add observer merging. But wait — ModifiedContent currently doesn't have observers storage. We need to decide: do observers go through ModifiedContent, or only through HTMLTag?

Since observers are only set on HTMLTag (not arbitrary Tags), they're already stored in the HTMLTag's own `observers` array. The HTMLTag.toTagNodes() passes them to TagNode.Element. ModifiedContent just passes through the underlying nodes, which already have observers set. So no changes needed to ModifiedContent.

**Step 6: Run tests**

Run: `swift test --filter EventModifiersTests`
Expected: PASS

Run: `swift test`
Expected: All tests pass

**Step 7: Commit**

```bash
git add Sources/SwiftWUIHTML/HTMLTag.swift Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift
git add $(find Sources/SwiftWUIHTML -name "*.swift" | grep -v Modifiers | grep -v HTMLTag.swift | grep -v EventAttribute.swift)
git commit -m "feat: add observer modifiers (onAppear, onDisappear, onResize, onFrameChange, onIntersection)"
```

---

### Task 9: DOMRenderer — create/manage JS observers

When DOMRenderer creates a DOM node that has `observers`, it needs to create the corresponding JavaScript observer objects and manage their lifecycle.

**Files:**
- Modify: `Sources/SwiftWUIRuntime/DOMRenderer.swift`
- Modify: `Sources/SwiftWUIRuntime/DOMBridge.swift` (add observer creation methods)

**Step 1: Add observer methods to DOMBridge**

```swift
// In DOMBridge.swift, add after the event handling section:

// MARK: - Web Observers

/// Create and attach an IntersectionObserver to an element.
/// Returns the observer JSObject for later disconnect().
public func createIntersectionObserver(
    _ element: JSObject,
    threshold: Double,
    callback: @escaping (Bool, Double) -> Void
) -> JSObject {
    let jsClosure = JSClosure { args in
        guard let entries = args.first?.object else { return .undefined }
        let length = entries["length"].number.map(Int.init) ?? 0
        for i in 0..<length {
            if let entry = entries[i].object {
                let isIntersecting = entry["isIntersecting"].boolean ?? false
                let ratio = entry["intersectionRatio"].number ?? 0
                callback(isIntersecting, ratio)
            }
        }
        return .undefined
    }
    let options = JSObject.global.Object.function!.new()
    options["threshold"] = .number(threshold < 0 ? 0 : threshold)
    let observer = JSObject.global.IntersectionObserver.function!.new(jsClosure, options)
    closures["io-\(UUID().uuidString)"] = jsClosure
    _ = observer.observe!(element)
    return observer
}

/// Create and attach a ResizeObserver to an element.
/// Returns the observer JSObject for later disconnect().
public func createResizeObserver(
    _ element: JSObject,
    callback: @escaping (Double, Double) -> Void
) -> JSObject {
    let jsClosure = JSClosure { args in
        guard let entries = args.first?.object else { return .undefined }
        let length = entries["length"].number.map(Int.init) ?? 0
        for i in 0..<length {
            if let entry = entries[i].object,
               let contentRect = entry["contentRect"].object {
                let width = contentRect["width"].number ?? 0
                let height = contentRect["height"].number ?? 0
                callback(width, height)
            }
        }
        return .undefined
    }
    let observer = JSObject.global.ResizeObserver.function!.new(jsClosure)
    closures["ro-\(UUID().uuidString)"] = jsClosure
    _ = observer.observe!(element)
    return observer
}

/// Create and attach a MutationObserver to an element.
public func createMutationObserver(
    _ element: JSObject,
    childList: Bool,
    attributes: Bool,
    subtree: Bool,
    callback: @escaping () -> Void
) -> JSObject {
    let jsClosure = JSClosure { _ in
        callback()
        return .undefined
    }
    let observer = JSObject.global.MutationObserver.function!.new(jsClosure)
    let config = JSObject.global.Object.function!.new()
    config["childList"] = .boolean(childList)
    config["attributes"] = .boolean(attributes)
    config["subtree"] = .boolean(subtree)
    closures["mo-\(UUID().uuidString)"] = jsClosure
    _ = observer.observe!(element, config)
    return observer
}

/// Disconnect an observer (IntersectionObserver, ResizeObserver, MutationObserver).
public func disconnectObserver(_ observer: JSObject) {
    _ = observer.disconnect?()
}

/// Get bounding client rect of an element.
public func getBoundingClientRect(_ element: JSObject) -> (x: Double, y: Double, width: Double, height: Double) {
    guard let rect = element.getBoundingClientRect?().object else {
        return (0, 0, 0, 0)
    }
    return (
        x: rect["x"].number ?? 0,
        y: rect["y"].number ?? 0,
        width: rect["width"].number ?? 0,
        height: rect["height"].number ?? 0
    )
}
```

**Step 2: Update DOMRenderer to create observers**

In `DOMRenderer.swift`, add observer tracking and creation:

```swift
/// Active JS observer objects per DOM element. Cleaned up on element removal.
private var activeObservers: [ObjectIdentifier: [JSObject]] = [:]

/// Create JS observers for a DOM element based on its WebObserver list.
private func createObservers(for element: JSObject, observers: [WebObserver]) {
    guard !observers.isEmpty else { return }
    let key = ObjectIdentifier(element)

    for observer in observers {
        switch observer {
        case .intersection(let threshold, let callbackID):
            if let handler = EventHandlerRegistry.handler(for: callbackID) {
                let isAppear = threshold >= 0
                let jsObs = bridge.createIntersectionObserver(element, threshold: max(threshold, 0)) { isIntersecting, ratio in
                    if isAppear && isIntersecting {
                        handler()
                    } else if !isAppear && !isIntersecting {
                        handler()
                    }
                    IntersectionContext.currentRatio = ratio
                }
                activeObservers[key, default: []].append(jsObs)
            }

        case .resize(let callbackID):
            if let handler = EventHandlerRegistry.handler(for: callbackID) {
                let jsObs = bridge.createResizeObserver(element) { width, height in
                    ResizeEventContext.currentSize = ElementSize(width: width, height: height)
                    let rect = bridge.getBoundingClientRect(element)
                    FrameChangeContext.currentRect = ElementRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
                    handler()
                    ResizeEventContext.currentSize = nil
                    FrameChangeContext.currentRect = nil
                }
                activeObservers[key, default: []].append(jsObs)
            }

        case .mutation(let options, let callbackID):
            if let handler = EventHandlerRegistry.handler(for: callbackID) {
                let jsObs = bridge.createMutationObserver(
                    element,
                    childList: options.childList,
                    attributes: options.attributes,
                    subtree: options.subtree,
                    callback: handler
                )
                activeObservers[key, default: []].append(jsObs)
            }

        case .lifecycle(let event, let callbackID):
            if event == .mount, let handler = EventHandlerRegistry.handler(for: callbackID) {
                handler()
            }
            // .unmount is handled in cleanupObservers
        }
    }
}

/// Disconnect and clean up all observers for a DOM element.
private func cleanupObservers(for element: JSObject) {
    let key = ObjectIdentifier(element)
    activeObservers[key]?.forEach { bridge.disconnectObserver($0) }
    activeObservers.removeValue(forKey: key)
}
```

Then call `createObservers` in `createDOMNode` after creating the element (after event listeners, around line 96):

```swift
// Create web observers (IntersectionObserver, ResizeObserver, etc.)
createObservers(for: domElement, observers: element.observers)
```

**Step 3: Run full tests**

Run: `swift test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add Sources/SwiftWUIRuntime/DOMBridge.swift Sources/SwiftWUIRuntime/DOMRenderer.swift
git commit -m "feat: DOMRenderer creates and manages JS observers (Intersection, Resize, Mutation)"
```

---

### Task 10: Reconciler — diff observers

**Files:**
- Modify: `Sources/SwiftWUIRuntime/Reconciler.swift:6-16` (add new Patch case)
- Modify: `Sources/SwiftWUIRuntime/Reconciler.swift:78-128` (add observer diff)
- Test: `Tests/SwiftWUIRuntimeTests/ReconcilerObserverTests.swift`

**Step 1: Write failing test**

```swift
// Tests/SwiftWUIRuntimeTests/ReconcilerObserverTests.swift
import Testing
@testable import SwiftWUICore
@testable import SwiftWUIRuntime

@Suite("Reconciler Observer Diffing")
struct ReconcilerObserverTests {
    let reconciler = Reconciler()

    @Test("Adding observers produces patch")
    func addObservers() {
        let old = TagNode.element(.init(tagName: "div"))
        let obs = WebObserver.resize(callbackID: EventListenerID("cb"))
        let new = TagNode.element(.init(tagName: "div", observers: [obs]))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Removing observers produces patch")
    func removeObservers() {
        let obs = WebObserver.resize(callbackID: EventListenerID("cb"))
        let old = TagNode.element(.init(tagName: "div", observers: [obs]))
        let new = TagNode.element(.init(tagName: "div"))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Unchanged observers produce no patch")
    func unchangedObservers() {
        let obs = WebObserver.resize(callbackID: EventListenerID("cb"))
        let old = TagNode.element(.init(tagName: "div", observers: [obs]))
        let new = TagNode.element(.init(tagName: "div", observers: [obs]))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch == nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter ReconcilerObserverTests 2>&1 | head -20`
Expected: FAIL on "Adding observers" — no observer diffing yet, so diff returns nil

**Step 3: Add `updateObservers` Patch case and diffing**

Add to `Patch` enum:
```swift
case updateObservers(new: [WebObserver])
```

Add observer diffing to `diffElements` in Reconciler (after event listener diff):

```swift
// Diff observers
if old.observers != new.observers {
    patches.append(.updateObservers(new: new.observers))
}
```

**Step 4: Handle new patch in DOMRenderer.applyPatch**

Add case in `applyPatch`:
```swift
case .updateObservers(let newObservers):
    cleanupObservers(for: element)
    createObservers(for: element, observers: newObservers)
```

**Step 5: Run tests**

Run: `swift test --filter ReconcilerObserverTests`
Expected: PASS (3/3)

Run: `swift test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Sources/SwiftWUIRuntime/Reconciler.swift Sources/SwiftWUIRuntime/DOMRenderer.swift Tests/SwiftWUIRuntimeTests/ReconcilerObserverTests.swift
git commit -m "feat: Reconciler diffs observers, DOMRenderer applies updateObservers patch"
```

---

### Task 11: Lifecycle modifiers — onMount, onUnmount

**Files:**
- Modify: `Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift`
- Test: `Tests/SwiftWUIHTMLTests/EventModifiersTests.swift` (extend)

**Step 1: Write failing test**

```swift
@Test("onMount adds lifecycle mount observer")
func onMountAddsObserver() {
    EventHandlerRegistry.clear()
    let div = Div {}
        .onMount { }
    let nodes = resolveTagBody(div)
    guard case .element(let el) = nodes.first else {
        Issue.record("Expected element"); return
    }
    #expect(el.observers.count == 1)
    if case .lifecycle(.mount, _) = el.observers.first {
        // OK
    } else {
        Issue.record("Expected lifecycle mount observer")
    }
}

@Test("onUnmount adds lifecycle unmount observer")
func onUnmountAddsObserver() {
    EventHandlerRegistry.clear()
    let div = Div {}
        .onUnmount { }
    let nodes = resolveTagBody(div)
    guard case .element(let el) = nodes.first else {
        Issue.record("Expected element"); return
    }
    #expect(el.observers.count == 1)
    if case .lifecycle(.unmount, _) = el.observers.first {
        // OK
    } else {
        Issue.record("Expected lifecycle unmount observer")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter "onMountAdds|onUnmountAdds" 2>&1 | head -20`
Expected: FAIL — .onMount/.onUnmount not found

**Step 3: Implement**

Add to `Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift`:

```swift
/// Called after the element is inserted into the DOM.
public func onMount(_ action: @escaping @Sendable () -> Void) -> Self {
    var copy = self
    let id = EventHandlerRegistry.register(action)
    copy.observers.append(.lifecycle(event: .mount, callbackID: id))
    return copy
}

/// Called before the element is removed from the DOM.
public func onUnmount(_ action: @escaping @Sendable () -> Void) -> Self {
    var copy = self
    let id = EventHandlerRegistry.register(action)
    copy.observers.append(.lifecycle(event: .unmount, callbackID: id))
    return copy
}
```

**Step 4: Handle unmount in DOMRenderer**

When removing a node, check for unmount observers and call them. In DOMRenderer `applyPatch`, in the `.removeNode` case, before removing:

```swift
case .removeNode:
    // Fire unmount callbacks before removal
    fireUnmountCallbacks(for: element)
    cleanupObservers(for: element)
    if let parent = element.parentNode.object {
        bridge.removeChild(parent, child: element)
    }
```

Add helper:
```swift
private func fireUnmountCallbacks(for element: JSObject) {
    // Check current tree for unmount observers matching this element
    // Since we track observers per element, we stored them in createObservers
    // We need to also track unmount callback IDs
}
```

Alternative simpler approach: store unmount callback IDs alongside active observers:

```swift
private var unmountCallbacks: [ObjectIdentifier: [EventListenerID]] = [:]
```

In `createObservers`, for `.lifecycle(.unmount, callbackID)`:
```swift
case .lifecycle(let event, let callbackID):
    if event == .mount, let handler = EventHandlerRegistry.handler(for: callbackID) {
        handler()
    }
    if event == .unmount {
        unmountCallbacks[key, default: []].append(callbackID)
    }
```

In `cleanupObservers`:
```swift
private func cleanupObservers(for element: JSObject, fireUnmount: Bool = false) {
    let key = ObjectIdentifier(element)
    activeObservers[key]?.forEach { bridge.disconnectObserver($0) }
    activeObservers.removeValue(forKey: key)
    if fireUnmount {
        unmountCallbacks[key]?.forEach { id in
            EventHandlerRegistry.handler(for: id)?()
        }
    }
    unmountCallbacks.removeValue(forKey: key)
}
```

**Step 5: Run tests**

Run: `swift test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift Sources/SwiftWUIRuntime/DOMRenderer.swift Tests/SwiftWUIHTMLTests/EventModifiersTests.swift
git commit -m "feat: add onMount and onUnmount lifecycle modifiers"
```

---

### Task 12: State observation modifier — onChange(of:)

This requires a different approach since it observes @State values, not DOM events.

**Files:**
- Create: `Sources/SwiftWUIState/OnChangeModifier.swift`
- Test: `Tests/SwiftWUIStateTests/OnChangeTests.swift`

**Step 1: Write failing test**

```swift
// Tests/SwiftWUIStateTests/OnChangeTests.swift
import Testing
import Observation
@testable import SwiftWUICore
@testable import SwiftWUIState

@Suite("onChange Modifier")
struct OnChangeTests {
    @Test("onChange wraps content and is TagNodeConvertible")
    func onChangeWrapsContent() {
        let text = Text("Hello")
        let modified = text.onChange(of: 0) { _, _ in }
        let nodes = resolveTagBody(modified)
        #expect(nodes.count == 1)
        if case .text(let content) = nodes.first {
            #expect(content == "Hello")
        } else {
            Issue.record("Expected text node passed through")
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter OnChangeTests 2>&1 | head -20`
Expected: FAIL — `.onChange(of:)` not found

**Step 3: Implement**

```swift
// Sources/SwiftWUIState/OnChangeModifier.swift
import SwiftWUICore

/// A tag wrapper that observes a value and calls an action when it changes.
/// The observation is set up by DOMRenderer during the render cycle.
public struct OnChangeTag<Content: Tag, V: Equatable & Sendable>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let getValue: @Sendable () -> V
    public let action: @Sendable (V, V) -> Void

    /// Stores the previous value for comparison.
    nonisolated(unsafe) var previousValue: V?

    public init(content: Content, getValue: @escaping @Sendable () -> V, action: @escaping @Sendable (V, V) -> Void) {
        self.content = content
        self.getValue = getValue
        self.action = action
        self.previousValue = getValue()
    }

    public func toTagNodes() -> [TagNode] {
        // Pass through content nodes — onChange is a side-effect wrapper
        if let convertible = content as? TagNodeConvertible {
            return convertible.toTagNodes()
        }
        return resolveTagBody(content)
    }
}

// MARK: - Tag extension

extension Tag {
    /// Perform an action when the given value changes.
    /// Modeled after SwiftUI's `.onChange(of:perform:)`.
    public func onChange<V: Equatable & Sendable>(
        of value: @autoclosure @escaping @Sendable () -> V,
        perform action: @escaping @Sendable (V, V) -> Void
    ) -> OnChangeTag<Self, V> {
        OnChangeTag(content: self, getValue: value, action: action)
    }
}
```

Note: The actual observation happens in the `Application.mount()` render cycle — `withObservationTracking` already tracks all `@State` accesses during body evaluation, so `onChange(of:)` values that reference `@State` are automatically tracked. The action fires via the existing re-render mechanism. The `onChange` modifier checks old vs new value during each render.

For this to work properly, we need DOMRenderer to detect `OnChangeTag` nodes and trigger the action. Alternative simpler approach: make `onChange` check values during `toTagNodes()`:

```swift
public func toTagNodes() -> [TagNode] {
    let currentValue = getValue()
    if let prev = OnChangeStorage.shared.previousValues[ObjectIdentifier(self as AnyObject)] as? V,
       prev != currentValue {
        action(prev, currentValue)
    }
    OnChangeStorage.shared.previousValues[ObjectIdentifier(self as AnyObject)] = currentValue

    if let convertible = content as? TagNodeConvertible {
        return convertible.toTagNodes()
    }
    return resolveTagBody(content)
}
```

Actually, since Swift structs don't have stable identity, this approach won't work. Better approach: use a class-based storage keyed by a hash of the value accessor. For MVP, the simplest working approach is to store the old value in a side table keyed by a user-provided or auto-generated ID.

Simplest correct approach for now: `onChange` fires the action during each `toTagNodes()` call when the value has changed. The old value is stored in a global dictionary keyed by a unique ID generated at init time.

```swift
public struct OnChangeTag<Content: Tag, V: Equatable & Sendable>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let getValue: @Sendable () -> V
    public let action: @Sendable (V, V) -> Void
    private let storageKey: String

    public init(content: Content, getValue: @escaping @Sendable () -> V, action: @escaping @Sendable (V, V) -> Void) {
        self.content = content
        self.getValue = getValue
        self.action = action
        self.storageKey = UUID().uuidString
    }

    public func toTagNodes() -> [TagNode] {
        let currentValue = getValue()

        if let oldValue = OnChangeStorage.value(for: storageKey) as? V {
            if oldValue != currentValue {
                action(oldValue, currentValue)
            }
        }
        OnChangeStorage.setValue(currentValue, for: storageKey)

        if let convertible = content as? TagNodeConvertible {
            return convertible.toTagNodes()
        }
        return resolveTagBody(content)
    }
}

/// Global storage for onChange previous values.
enum OnChangeStorage {
    nonisolated(unsafe) private static var values: [String: Any] = [:]

    static func value(for key: String) -> Any? { values[key] }
    static func setValue(_ value: Any, for key: String) { values[key] = value }
}
```

**Step 4: Run tests**

Run: `swift test --filter OnChangeTests`
Expected: PASS

Run: `swift test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/SwiftWUIState/OnChangeModifier.swift Tests/SwiftWUIStateTests/OnChangeTests.swift
git commit -m "feat: add .onChange(of:) modifier for observing @State changes"
```

---

### Task 13: .task modifier

**Files:**
- Create: `Sources/SwiftWUIState/TaskModifier.swift`
- Test: `Tests/SwiftWUIStateTests/TaskModifierTests.swift`

**Step 1: Write failing test**

```swift
// Tests/SwiftWUIStateTests/TaskModifierTests.swift
import Testing
@testable import SwiftWUICore
@testable import SwiftWUIState

@Suite("Task Modifier")
struct TaskModifierTests {
    @Test("task wraps content transparently")
    func taskWrapsContent() {
        let text = Text("Hello")
        let modified = text.task { }
        let nodes = resolveTagBody(modified)
        #expect(nodes.count == 1)
        if case .text(let content) = nodes.first {
            #expect(content == "Hello")
        }
    }
}
```

**Step 2: Implement**

```swift
// Sources/SwiftWUIState/TaskModifier.swift
import SwiftWUICore

/// A tag wrapper that runs an async task when the element appears.
/// The task is stored and executed by the DOMRenderer.
public struct TaskTag<Content: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never

    public let content: Content
    public let action: @Sendable () async -> Void

    public init(content: Content, action: @escaping @Sendable () async -> Void) {
        self.content = content
        self.action = action
    }

    public func toTagNodes() -> [TagNode] {
        // The async task is triggered on mount by DOMRenderer.
        // For now, we just pass through the content.
        // The actual async execution happens in WASM context.
        var nodes: [TagNode]
        if let convertible = content as? TagNodeConvertible {
            nodes = convertible.toTagNodes()
        } else {
            nodes = resolveTagBody(content)
        }

        // Mark the first element node with a lifecycle mount observer
        // that triggers the async task
        if case .element(var el) = nodes.first {
            let id = EventHandlerRegistry.register {
                // In WASM, we can use Task { } to run async code
                // For non-WASM compilation, this is a no-op
                #if canImport(JavaScriptKit)
                Task { await action() }
                #endif
            }
            el.observers.append(.lifecycle(event: .mount, callbackID: id))
            nodes[0] = .element(el)
        }

        return nodes
    }
}

extension Tag {
    /// Run an async task when this element appears in the DOM.
    public func task(_ action: @escaping @Sendable () async -> Void) -> TaskTag<Self> {
        TaskTag(content: self, action: action)
    }
}
```

**Step 3: Run tests**

Run: `swift test --filter TaskModifierTests`
Expected: PASS

**Step 4: Commit**

```bash
git add Sources/SwiftWUIState/TaskModifier.swift Tests/SwiftWUIStateTests/TaskModifierTests.swift
git commit -m "feat: add .task modifier for async work on element mount"
```

---

### Task 14: .onMutation modifier and .id() modifier

**Files:**
- Modify: `Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift`
- Test: `Tests/SwiftWUIHTMLTests/EventModifiersTests.swift` (extend)

**Step 1: Write failing test for .onMutation**

```swift
@Test("onMutation adds mutation observer")
func onMutationAddsObserver() {
    EventHandlerRegistry.clear()
    let div = Div {}
        .onMutation(.init(childList: true)) { }
    let nodes = resolveTagBody(div)
    guard case .element(let el) = nodes.first else {
        Issue.record("Expected element"); return
    }
    #expect(el.observers.count == 1)
    if case .mutation(let opts, _) = el.observers.first {
        #expect(opts.childList == true)
    } else {
        Issue.record("Expected mutation observer")
    }
}
```

**Step 2: Implement .onMutation**

```swift
/// Observe DOM mutations on this element.
public func onMutation(_ options: MutationOptions, action: @escaping @Sendable () -> Void) -> Self {
    var copy = self
    let id = EventHandlerRegistry.register(action)
    copy.observers.append(.mutation(options: options, callbackID: id))
    return copy
}
```

**Step 3: Implement .id() modifier**

The `.id()` modifier forces element recreation when the ID changes. This is implemented as a special attribute that the Reconciler checks — if the ID changes, the entire element is replaced instead of patched.

Add to `Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift`:

```swift
extension HTMLTag {
    /// Assign a stable identity to this element.
    /// When the ID changes, the element is fully recreated (not patched).
    public func id<ID: CustomStringConvertible>(_ id: ID) -> Self {
        var copy = self
        copy.attributes["data-swiftwui-id"] = id.description
        return copy
    }
}
```

Update Reconciler `diffElements` to check for id changes:

```swift
// At the start of diffElements, before other diffs:
let oldId = old.attributes["data-swiftwui-id"]
let newId = new.attributes["data-swiftwui-id"]
if oldId != newId && (oldId != nil || newId != nil) {
    return .replaceNode(with: .element(new))
}
```

**Step 4: Run tests and commit**

```bash
git add Sources/SwiftWUIHTML/Modifiers/EventModifiers.swift Sources/SwiftWUIRuntime/Reconciler.swift Tests/SwiftWUIHTMLTests/EventModifiersTests.swift
git commit -m "feat: add .onMutation and .id() modifiers"
```

---

## Workstream 2: Vapor Dev Server

### Task 15: Add SwiftWUIDevServer executable target to Package.swift

**Files:**
- Modify: `Package.swift:1-127`
- Create: `Sources/SwiftWUIDevServer/main.swift`

**Step 1: Update Package.swift**

Add Vapor dependency and executable target. Vapor must be conditionally included (it cannot compile to WASM).

Add to dependencies array:
```swift
.package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
```

Add executable target:
```swift
.executableTarget(
    name: "swiftwui-dev",
    dependencies: [
        .product(name: "Vapor", package: "vapor"),
    ],
    path: "Sources/SwiftWUIDevServer"
),
```

**Step 2: Create minimal main.swift**

```swift
// Sources/SwiftWUIDevServer/main.swift
import Foundation

print("SwiftWUI Dev Server")
print("Usage: swift run swiftwui-dev [dev|build] --target <name> [--port <port>] [--sdk <sdk-id>]")
```

**Step 3: Verify it builds**

Run: `swift build --target swiftwui-dev`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Package.swift Sources/SwiftWUIDevServer/main.swift
git commit -m "feat: add swiftwui-dev executable target with Vapor dependency"
```

---

### Task 16: CLI argument parsing

**Files:**
- Create: `Sources/SwiftWUIDevServer/CLI.swift`
- Modify: `Sources/SwiftWUIDevServer/main.swift`

**Step 1: Implement CLI parser**

```swift
// Sources/SwiftWUIDevServer/CLI.swift
import Foundation

enum Command {
    case dev(DevOptions)
    case build(BuildOptions)
}

struct DevOptions {
    var target: String
    var port: Int = 8080
    var sdk: String?
    var watchPath: String = "Sources"
    var openBrowser: Bool = false
}

struct BuildOptions {
    var target: String
    var output: String = "dist"
    var sdk: String?
    var optimize: OptimizeLevel = .default
}

enum OptimizeLevel: String {
    case `default`
    case size
    case aggressive
}

func parseArguments() -> Command {
    let args = Array(CommandLine.arguments.dropFirst())

    var command = "dev"
    var target: String?
    var port = 8080
    var sdk: String?
    var watchPath = "Sources"
    var output = "dist"
    var optimize = OptimizeLevel.default
    var openBrowser = false

    var i = 0
    if let first = args.first, !first.starts(with: "-") {
        command = first
        i = 1
    }

    while i < args.count {
        switch args[i] {
        case "--target":
            i += 1; target = args[i]
        case "--port":
            i += 1; port = Int(args[i]) ?? 8080
        case "--sdk":
            i += 1; sdk = args[i]
        case "--watch":
            i += 1; watchPath = args[i]
        case "--output":
            i += 1; output = args[i]
        case "--optimize":
            i += 1; optimize = OptimizeLevel(rawValue: args[i]) ?? .default
        case "--open":
            openBrowser = true
        default:
            break
        }
        i += 1
    }

    guard let target else {
        print("Error: --target is required")
        exit(1)
    }

    switch command {
    case "build":
        return .build(BuildOptions(target: target, output: output, sdk: sdk, optimize: optimize))
    default:
        return .dev(DevOptions(target: target, port: port, sdk: sdk, watchPath: watchPath, openBrowser: openBrowser))
    }
}
```

**Step 2: Update main.swift**

```swift
// Sources/SwiftWUIDevServer/main.swift
import Foundation

let command = parseArguments()

switch command {
case .dev(let options):
    print("Starting dev server for target '\(options.target)' on port \(options.port)...")
case .build(let options):
    print("Building '\(options.target)' for production (optimize: \(options.optimize.rawValue))...")
}
```

**Step 3: Build and test**

Run: `swift build --target swiftwui-dev`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Sources/SwiftWUIDevServer/CLI.swift Sources/SwiftWUIDevServer/main.swift
git commit -m "feat: add CLI argument parsing for swiftwui-dev"
```

---

### Task 17: WASM Builder

**Files:**
- Create: `Sources/SwiftWUIDevServer/WASMBuilder.swift`

**Step 1: Implement**

```swift
// Sources/SwiftWUIDevServer/WASMBuilder.swift
import Foundation

struct BuildResult {
    let success: Bool
    let output: String
    let duration: TimeInterval
}

class WASMBuilder {
    let target: String
    let sdk: String
    let configuration: String

    init(target: String, sdk: String, configuration: String = "debug") {
        self.target = target
        self.sdk = sdk
        self.configuration = configuration
    }

    /// Run `swift package --swift-sdk <sdk> js -c <config>`
    func build() async -> BuildResult {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "package",
            "--swift-sdk", sdk,
            "js",
            "-c", configuration,
            "--product", target
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return BuildResult(success: false, output: "Failed to start build: \(error)", duration: Date().timeIntervalSince(start))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let success = process.terminationStatus == 0

        return BuildResult(success: success, output: output, duration: Date().timeIntervalSince(start))
    }

    /// Detect available Swift SDK for WASM.
    static func detectSDK() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "sdk", "list"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Find first line containing "wasm" but not "embedded"
        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.contains("wasm") && !$0.contains("embedded") && !$0.isEmpty }
    }

    /// Path to the PackageToJS output directory.
    var outputDirectory: String {
        ".build/plugins/PackageToJS/outputs/Package"
    }
}
```

**Step 2: Build**

Run: `swift build --target swiftwui-dev`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/SwiftWUIDevServer/WASMBuilder.swift
git commit -m "feat: add WASMBuilder for swift package js invocation"
```

---

### Task 18: File Watcher

**Files:**
- Create: `Sources/SwiftWUIDevServer/FileWatcher.swift`

**Step 1: Implement**

```swift
// Sources/SwiftWUIDevServer/FileWatcher.swift
import Foundation

/// Watches a directory for .swift file changes using DispatchSource (FSEvents on macOS).
class FileWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceTimer: DispatchWorkItem?
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "swiftwui.filewatcher")

    init(debounceInterval: TimeInterval = 0.3, onChange: @escaping () -> Void) {
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    /// Start watching a directory recursively for .swift file changes.
    func watch(directory: String) {
        // Use Process with fswatch for recursive watching (available on macOS via Homebrew)
        // Fallback: poll-based approach
        startFSWatchProcess(directory: directory)
    }

    private func startFSWatchProcess(directory: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "fswatch", "-r", "--include", "\\.swift$", "--exclude", ".*",
            "-l", "0.3",  // latency
            directory
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.debounceAndNotify()
        }

        do {
            try process.run()
        } catch {
            print("Warning: fswatch not found, falling back to polling")
            startPolling(directory: directory)
        }
    }

    private func startPolling(directory: String) {
        // Simple polling fallback: check mtime every second
        var lastModified: [String: Date] = [:]

        queue.async { [weak self] in
            while true {
                Thread.sleep(forTimeInterval: 1.0)
                let fm = FileManager.default
                guard let enumerator = fm.enumerator(atPath: directory) else { continue }

                var changed = false
                while let file = enumerator.nextObject() as? String {
                    guard file.hasSuffix(".swift") else { continue }
                    let path = (directory as NSString).appendingPathComponent(file)
                    guard let attrs = try? fm.attributesOfItem(atPath: path),
                          let mtime = attrs[.modificationDate] as? Date else { continue }

                    if let prev = lastModified[path], prev != mtime {
                        changed = true
                    }
                    lastModified[path] = mtime
                }

                if changed {
                    self?.debounceAndNotify()
                }
            }
        }
    }

    private func debounceAndNotify() {
        debounceTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceTimer = item
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        debounceTimer?.cancel()
    }
}
```

**Step 2: Build and commit**

```bash
swift build --target swiftwui-dev
git add Sources/SwiftWUIDevServer/FileWatcher.swift
git commit -m "feat: add FileWatcher with fswatch and polling fallback"
```

---

### Task 19: HTML Template with WebSocket client

**Files:**
- Create: `Sources/SwiftWUIDevServer/HTMLTemplate.swift`

**Step 1: Implement**

```swift
// Sources/SwiftWUIDevServer/HTMLTemplate.swift
import Foundation

struct HTMLTemplate {
    let target: String

    /// Generate index.html for dev mode (includes WebSocket reload client).
    func devHTML(port: Int) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(target) — SwiftWUI Dev</title>
            <script type="module">
                import { init } from "./\(target).js";
                init();
            </script>
        </head>
        <body>
            <div id="app"></div>
            \(devClientScript(port: port))
        </body>
        </html>
        """
    }

    /// Generate index.html for production (no dev tools).
    func productionHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(target)</title>
            <script type="module">
                import { init } from "./\(target).js";
                init();
            </script>
        </head>
        <body>
            <div id="app"></div>
        </body>
        </html>
        """
    }

    private func devClientScript(port: Int) -> String {
        """
        <script>
        (function() {
            var overlay = null;
            var indicator = null;
            function connect() {
                var ws = new WebSocket('ws://localhost:\(port)/_dev');
                ws.onopen = function() {
                    console.log('[SwiftWUI] Dev server connected');
                    if (overlay) { overlay.remove(); overlay = null; }
                };
                ws.onmessage = function(e) {
                    var msg = JSON.parse(e.data);
                    if (msg.type === 'reload') {
                        if (overlay) { overlay.remove(); overlay = null; }
                        location.reload();
                    } else if (msg.type === 'building') {
                        showIndicator('Rebuilding...');
                    } else if (msg.type === 'error') {
                        showErrorOverlay(msg.message);
                    }
                };
                ws.onclose = function() {
                    console.log('[SwiftWUI] Dev server disconnected, reconnecting...');
                    setTimeout(connect, 2000);
                };
            }
            function showIndicator(text) {
                if (!indicator) {
                    indicator = document.createElement('div');
                    indicator.style.cssText = 'position:fixed;top:8px;right:8px;background:#333;color:#fff;padding:6px 12px;border-radius:6px;font:12px system-ui;z-index:99999;opacity:0.9';
                    document.body.appendChild(indicator);
                }
                indicator.textContent = text;
            }
            function showErrorOverlay(message) {
                if (indicator) { indicator.remove(); indicator = null; }
                if (!overlay) {
                    overlay = document.createElement('div');
                    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:32px;overflow:auto;z-index:99999;white-space:pre-wrap';
                    document.body.appendChild(overlay);
                }
                overlay.textContent = 'Build Error:\\n\\n' + message;
            }
            connect();
        })();
        </script>
        """
    }
}
```

**Step 2: Build and commit**

```bash
swift build --target swiftwui-dev
git add Sources/SwiftWUIDevServer/HTMLTemplate.swift
git commit -m "feat: add HTML template with WebSocket dev client and error overlay"
```

---

### Task 20: Vapor Dev Server (HTTP + WebSocket)

**Files:**
- Create: `Sources/SwiftWUIDevServer/DevServer.swift`
- Modify: `Sources/SwiftWUIDevServer/main.swift`

**Step 1: Implement DevServer**

```swift
// Sources/SwiftWUIDevServer/DevServer.swift
import Vapor
import Foundation

class DevServer {
    let options: DevOptions
    let builder: WASMBuilder
    let htmlTemplate: HTMLTemplate
    var connectedClients: [WebSocket] = []

    init(options: DevOptions) {
        let sdk = options.sdk ?? WASMBuilder.detectSDK() ?? "swift-6.2.3-RELEASE_wasm"
        self.options = options
        self.builder = WASMBuilder(target: options.target, sdk: sdk)
        self.htmlTemplate = HTMLTemplate(target: options.target)
    }

    func start() async throws {
        // Initial build
        print("Building \(options.target)...")
        let result = await builder.build()
        if !result.success {
            print("Initial build failed:\n\(result.output)")
            print("Starting server anyway — fix errors and save to rebuild.")
        } else {
            print("Build succeeded in \(String(format: "%.1f", result.duration))s")
        }

        // Start Vapor
        let app = try await Application.make(.detect())
        app.http.server.configuration.port = options.port
        app.http.server.configuration.hostname = "0.0.0.0"

        // Serve index.html
        app.get { [htmlTemplate, options] req -> Response in
            let html = htmlTemplate.devHTML(port: options.port)
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: .init(string: html)
            )
        }

        // Serve static files from PackageToJS output
        let outputDir = builder.outputDirectory
        app.middleware.use(FileMiddleware(publicDirectory: outputDir))

        // WebSocket endpoint for hot reload
        app.webSocket("_dev") { [weak self] req, ws in
            self?.connectedClients.append(ws)
            ws.send(#"{"type":"connected"}"#)
            ws.onClose.whenComplete { [weak self] _ in
                self?.connectedClients.removeAll { $0 === ws }
            }
        }

        // Start file watcher
        let watcher = FileWatcher { [weak self] in
            Task { await self?.rebuild() }
        }
        watcher.watch(directory: options.watchPath)

        print("Dev server running at http://localhost:\(options.port)")

        if options.openBrowser {
            #if os(macOS)
            Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["http://localhost:\(options.port)"])
            #endif
        }

        try await app.execute()
    }

    func rebuild() async {
        print("File changed, rebuilding...")
        broadcast(#"{"type":"building"}"#)

        let result = await builder.build()

        if result.success {
            print("Rebuild succeeded in \(String(format: "%.1f", result.duration))s")
            broadcast(#"{"type":"reload"}"#)
        } else {
            print("Rebuild failed")
            let escaped = result.output
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            broadcast(#"{"type":"error","message":"\#(escaped)"}"#)
        }
    }

    func broadcast(_ message: String) {
        for ws in connectedClients {
            ws.send(message)
        }
    }
}
```

**Step 2: Update main.swift**

```swift
// Sources/SwiftWUIDevServer/main.swift
import Foundation

let command = parseArguments()

switch command {
case .dev(let options):
    let server = DevServer(options: options)
    Task {
        do {
            try await server.start()
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
    RunLoop.main.run()

case .build(let options):
    let prodBuilder = ProductionBuilder(options: options)
    Task {
        do {
            try await prodBuilder.build()
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
    RunLoop.main.run()
}
```

**Step 3: Build**

Run: `swift build --target swiftwui-dev`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Sources/SwiftWUIDevServer/DevServer.swift Sources/SwiftWUIDevServer/main.swift
git commit -m "feat: implement Vapor dev server with WebSocket hot-reload"
```

---

### Task 21: Production Builder

**Files:**
- Create: `Sources/SwiftWUIDevServer/ProductionBuilder.swift`

**Step 1: Implement**

```swift
// Sources/SwiftWUIDevServer/ProductionBuilder.swift
import Foundation

class ProductionBuilder {
    let options: BuildOptions
    let builder: WASMBuilder

    init(options: BuildOptions) {
        let sdk = options.sdk ?? WASMBuilder.detectSDK() ?? "swift-6.2.3-RELEASE_wasm"
        self.options = options
        self.builder = WASMBuilder(target: options.target, sdk: sdk, configuration: "release")
    }

    func build() async throws {
        let start = Date()
        print("Building \(options.target) for production...")

        // 1. Build release
        let result = await builder.build()
        guard result.success else {
            print("Build failed:\n\(result.output)")
            exit(1)
        }
        print("Release build completed in \(String(format: "%.1f", result.duration))s")

        // 2. Copy output to dist/
        let fm = FileManager.default
        let outputDir = options.output
        if fm.fileExists(atPath: outputDir) {
            try fm.removeItem(atPath: outputDir)
        }
        try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        try fm.copyItem(atPath: builder.outputDirectory, toPath: outputDir + "/pkg")

        // 3. Generate production HTML
        let html = HTMLTemplate(target: options.target).productionHTML()
        try html.write(toFile: outputDir + "/index.html", atomically: true, encoding: .utf8)

        // 4. Additional optimizations
        switch options.optimize {
        case .size:
            await optimizeWASM(flags: ["-Oz", "--strip-debug"])
        case .aggressive:
            await optimizeWASM(flags: ["-O3", "--strip-debug"])
            await compressFiles()
        case .default:
            break
        }

        // 5. Print summary
        let totalDuration = Date().timeIntervalSince(start)
        printSummary(duration: totalDuration)
    }

    private func optimizeWASM(flags: [String]) async {
        let wasmPath = options.output + "/pkg/\(options.target).wasm"
        guard FileManager.default.fileExists(atPath: wasmPath) else {
            print("Warning: WASM file not found at \(wasmPath)")
            return
        }

        print("Running wasm-opt with flags: \(flags.joined(separator: " "))...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["wasm-opt"] + flags + [wasmPath, "-o", wasmPath]

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("wasm-opt completed")
            } else {
                print("Warning: wasm-opt failed (is it installed? brew install binaryen)")
            }
        } catch {
            print("Warning: wasm-opt not found, skipping")
        }
    }

    private func compressFiles() async {
        let outputDir = options.output + "/pkg"
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: outputDir) else { return }

        for file in files where file.hasSuffix(".wasm") || file.hasSuffix(".js") {
            let path = outputDir + "/" + file
            // gzip
            let gzipProcess = Process()
            gzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
            gzipProcess.arguments = ["-k", "-9", path]
            try? gzipProcess.run()
            gzipProcess.waitUntilExit()
        }
        print("Pre-compressed .gz files created")
    }

    private func printSummary(duration: TimeInterval) {
        let fm = FileManager.default
        let outputDir = options.output

        print("\n--- Production Build Summary ---")
        print("Output: \(outputDir)/")
        print("Duration: \(String(format: "%.1f", duration))s")

        if let files = try? fm.contentsOfDirectory(atPath: outputDir + "/pkg") {
            for file in files.sorted() {
                let path = outputDir + "/pkg/" + file
                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? Int {
                    let sizeStr = size > 1024 * 1024
                        ? String(format: "%.1f MB", Double(size) / 1024 / 1024)
                        : String(format: "%.1f KB", Double(size) / 1024)
                    print("  \(file): \(sizeStr)")
                }
            }
        }
        print("--- Build complete ---\n")
    }
}
```

**Step 2: Build**

Run: `swift build --target swiftwui-dev`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/SwiftWUIDevServer/ProductionBuilder.swift
git commit -m "feat: add production build with wasm-opt optimization and compression"
```

---

### Task 22: Integration test — end-to-end dev server

**Step 1: Manual smoke test**

```bash
cd Examples/Counter
swift run --package-path ../../ swiftwui-dev --target Counter --port 8080
```

Expected:
- Initial build runs
- HTTP server starts on :8080
- Browser shows counter app
- Editing a .swift file triggers rebuild
- Browser auto-reloads on success

**Step 2: Fix any issues discovered during smoke testing**

This is an iterative step — address compile errors, path issues, Vapor API differences, etc.

**Step 3: Commit fixes**

```bash
git add -A
git commit -m "fix: resolve integration issues with dev server"
```

---

### Task 23: Run full test suite and final commit

**Step 1: Run all tests**

Run: `swift test`
Expected: All tests pass (original 51 + new modifier tests)

**Step 2: Run WASM build**

Run: `swift build --swift-sdk swift-6.2.3-RELEASE_wasm`
Expected: Library builds (dev server target excluded from WASM build)

Note: The `swiftwui-dev` target should NOT be built for WASM. It's only for native macOS/Linux. SwiftPM will only build it when explicitly requested via `swift build --target swiftwui-dev` or `swift run swiftwui-dev`.

**Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore: finalize web modifiers and dev server implementation"
```
