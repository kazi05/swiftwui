# BridgeJS + TagModifier + WebSession.shared Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Executor convention (project):** implementation subagents are `voltagent-lang:swift-expert`; per-task review is `voltagent-qa-sec:code-reviewer`. Design questions escalate to the session lead.

**Goal:** Ship three additions from the approved spec: (1) hybrid AOT-vendored BridgeJS bindings inside SwiftWUIDOM, (2) a `ViewModifier`-style `TagModifier` protocol plus built-in interaction modifiers, (3) `WebSession.shared` so networking works from ViewModels and any `@MainActor` code.

**Architecture:** All DOM changes stay behind the `RendererBackend` seam; native tests keep using `MockBackend`. `TagModifier` reuses the existing component machinery (`.type` identity segment, `StateStore` graft, observation tracking). Observers (IntersectionObserver/ResizeObserver) mirror the event-listener pipeline end to end (bag → `ElementNode` → `Reconciler` patches → `TreeApplier` → backend). Window-level events are a new `EffectRequest` kind feeding a runtime-owned hub. BridgeJS codegen is vendored (`Generated/` committed), so framework consumers need no plugin and no experimental flags.

**Tech Stack:** Swift 6.3.3 (swiftly), official SDK `swift-6.3.3-RELEASE_wasm`, JavaScriptKit 0.56.1 (pinned in Package.resolved), Swift Testing, Node.js (BridgeJS codegen only, contributor-side).

**Spec:** `docs/superpowers/specs/2026-07-12-bridgejs-tagmodifier-websession-design.md` (approved). Read it before starting any task.

## Global Constraints

- Tests: Swift Testing (`import Testing`, `@Suite @MainActor struct`, `@Test`, `#expect`) in the single test target `SwiftWUITests`. No XCTest.
- Testing workflow (user preference, overrides stepwise RED/GREEN): write ALL of a task's code + tests first, run `swift test` ONCE at the end of the task, then commit.
- Native gate: `swift test` — 376 tests green before this plan; every task must leave the full suite green.
- Framework wasm gate: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --scratch-path .build-wasm --target SwiftWUIDOM` (**`--target`, NOT `--product`** — product pulls native-only SwiftWUIToolchain into the wasm graph). Dedicated `.build-wasm` scratch dir is mandatory.
- Example wasm gate: `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`.
- Never pass `-disable-reflection-metadata` (breaks Mirror → silently resets all @State).
- No new package dependencies. BridgeJS is part of the already-pinned JavaScriptKit 0.56.1.
- BridgeJS regeneration rule: any edit to `Sources/SwiftWUIDOM/bridge-js.global.d.ts` requires re-running `swift package plugin --allow-writing-to-package-directory bridge-js --target SwiftWUIDOM` and committing `Sources/SwiftWUIDOM/Generated/` in the same commit. Node.js must be on PATH for the codegen (contributor-side only).
- Code, commits, docs in English.
- `JSClosure` must be retained Swift-side while attached; release symmetrically (`endEnvironmentObservation` is the page-teardown seam).
- Every type that mints a `.type(ObjectIdentifier(Self.self))` identity segment MUST call `_TypeNameRegistry.register(Self.self)` first (otherwise snapshot keys silently drop).

## Task order & dependencies

Task 1 (spike) has a hard exit criterion; if it fails, Task 8 is cancelled and its spec section is deferred — Tasks 2–7 and 9 proceed regardless. Tasks 2–7 are sequential but independent of 1/8.

---

### Task 1: BridgeJS spike — vendored codegen + cross-package proof (EXIT-CRITERION GATE)

**Files:**
- Create: `Sources/SwiftWUIDOM/bridge-js.config.json`
- Create: `Sources/SwiftWUIDOM/bridge-js.global.d.ts`
- Create: `Sources/SwiftWUIDOM/Generated/` (tool output, committed)
- Create: `Sources/SwiftWUIDOM/BridgeJSCanary.swift`
- Modify: `Package.swift` (SwiftWUIDOM target: add `swiftSettings`)
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (call canary next to `assertReflectionAlive()`)

**Interfaces:**
- Produces: committed `Sources/SwiftWUIDOM/Generated/{BridgeJS.swift, BridgeJS.Macros.swift, JavaScript/BridgeJS.json}`; module-scope generated symbols `SWDocument`, `SWNode`, `var document: SWDocument` (all internal to SwiftWUIDOM); `func assertBridgeJSAlive()` (internal, wasm-only). Task 8 consumes these.
- Consumes: nothing from other tasks.

**Background for the implementer:** BridgeJS is JavaScriptKit's AOT interop codegen. We use the *command* plugin (verb `bridge-js`) in vendored mode: run once, commit `Generated/`, never add the *build* plugin to Package.swift. Generated code needs `.enableExperimentalFeature("Extern")` on the target (it uses `@_extern(wasm)`); it compiles on native too (non-wasm branches are `fatalError` stubs behind `#if arch(wasm32)`). The command plugin only processes targets that contain a `bridge-js.config.json`. Declarations in `bridge-js.global.d.ts` are read from `globalThis` at runtime and need NO `getImports()` wiring in the app's `index.html` — Counter's `await init()` keeps working unchanged. Generated `@JSClass struct X` synthesizes `let jsObject: JSObject` + `init(unsafelyWrapping:)`; every method/getter/setter is `throws(JSException)`.

- [ ] **Step 1: Check Node.js availability**

Run: `node --version`
Expected: any v18+ version. If Node is missing, stop and surface to the session lead (codegen cannot run).

- [ ] **Step 2: Write the BridgeJS input files**

`Sources/SwiftWUIDOM/bridge-js.config.json`:

```json
{
    "exposeToGlobal": false
}
```

`Sources/SwiftWUIDOM/bridge-js.global.d.ts` — the FULL structural DOM subset (Task 8 migrates call sites onto this; declaring it all now means one codegen run). All return/param types are deliberately non-null — we control this declaration and the DOM guarantees these calls succeed for the tags/arguments SwiftWUI produces:

```typescript
// SwiftWUI structural DOM subset for BridgeJS (spec §1.2 hybrid boundary).
// Event listeners, nullable getters (getElementById), dynamic property
// writes (setProperty, __swuid) and hydration reads stay on dynamic JSObject.
type SWNode = {
    // CharacterData.data — used by setText on text nodes only.
    data: string
    appendChild(child: SWNode): void
    insertBefore(node: SWNode, anchor: SWNode): void
    removeChild(child: SWNode): void
    setAttribute(name: string, value: string): void
    removeAttribute(name: string): void
}

type SWDocument = {
    createElement(tag: string): SWNode
    createTextNode(data: string): SWNode
}

export const document: SWDocument
```

- [ ] **Step 3: Add the Extern feature flag to SwiftWUIDOM**

In `Package.swift`, the SwiftWUIDOM target currently has no `swiftSettings`. Change it to:

```swift
.target(name: "SwiftWUIDOM", dependencies: [
    "SwiftWUI",
    .product(name: "JavaScriptKit", package: "JavaScriptKit"),
    .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
    .product(name: "JavaScriptFoundationCompat", package: "JavaScriptKit"),
], swiftSettings: [
    .enableExperimentalFeature("Extern")   // required by BridgeJS Generated/ code
]),
```

Do NOT add any plugin to the target (vendored mode).

- [ ] **Step 4: Run the AOT codegen and inspect output**

Run:
```bash
swift package plugin --allow-writing-to-package-directory bridge-js --target SwiftWUIDOM
ls -R Sources/SwiftWUIDOM/Generated
```
Expected: `BridgeJS.swift`, `BridgeJS.Macros.swift`, `JavaScript/BridgeJS.json`. Open `BridgeJS.Macros.swift` and confirm it declares `@JSClass struct SWNode`, `@JSClass struct SWDocument`, and `@JSGetter(from: .global) var document: SWDocument` (exact spellings may differ slightly — record what it actually generated; Task 8 depends on the real names).

- [ ] **Step 5: Write the canary**

`Sources/SwiftWUIDOM/BridgeJSCanary.swift` — same spirit as the existing `assertReflectionAlive()` startup canary. It exercises one bridged call end to end at boot; if the PackageToJS glue for a cross-package vendored library ever regresses, apps fail loudly at startup instead of corrupting the DOM later:

```swift
#if arch(wasm32)
/// Startup canary (spike for spec §1.4): proves the vendored BridgeJS glue is
/// alive in this deployment. One bridged createElement + setAttribute round trip.
func assertBridgeJSAlive() {
    do {
        let el = try document.createElement("div")
        try el.setAttribute("data-swui-bridge-canary", "1")
    } catch {
        fatalError("SwiftWUI: BridgeJS bridge is not functional: \(error)")
    }
}
#endif
```

Note: the generated global getter is module-scope `var document` inside SwiftWUIDOM. If this collides with an existing `document` binding in the same file scope, qualify as `SwiftWUIDOM.document` or adjust — but do NOT rename the d.ts export (the name must match `globalThis.document`).

In `Sources/SwiftWUIDOM/DOMRuntime.swift`, inside `mount(...)` directly after the `assertReflectionAlive()` call, add:

```swift
assertBridgeJSAlive()
```

- [ ] **Step 6: Run all gates**

Run, in order:
```bash
swift build && swift test
swift build --swift-sdk swift-6.3.3-RELEASE_wasm --scratch-path .build-wasm --target SwiftWUIDOM
cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug && cd ../..
grep -l "SwiftWUIDOM" Examples/Counter/.build/plugins/PackageToJS/outputs/Package/*.js
```
Expected: native build+tests green (Generated/ compiles natively as stubs); wasm target builds; Counter (a SEPARATE package with a path dependency — this is the cross-package proof) builds through PackageToJS; the generated JS glue references the `SwiftWUIDOM` wasm import module.

Then boot in a browser: `npm --prefix Examples/Counter run dev -- --port 8080`, open the page — the app must mount without console errors (the canary runs on boot; a broken bridge = loud fatalError in console). This browser check may be delegated to the session lead as a manual acceptance item if no browser automation is available.

**EXIT CRITERION (spec §1.4):** if the Counter cross-package build or browser boot fails with no workaround found within a reasonable effort (~half a day), STOP: revert this task's commits, report to the session lead, mark spec section 1 as "deferred until BridgeJS GA" in the spec file, and cancel Task 8. Tasks 2–7 and 9 proceed.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/SwiftWUIDOM/bridge-js.config.json Sources/SwiftWUIDOM/bridge-js.global.d.ts Sources/SwiftWUIDOM/Generated Sources/SwiftWUIDOM/BridgeJSCanary.swift Sources/SwiftWUIDOM/DOMRuntime.swift
git commit -m "feat(dom): BridgeJS spike — vendored AOT bindings, Extern flag, boot canary"
```

---

### Task 2: TagModifier core

**Files:**
- Create: `Sources/SwiftWUI/Core/TagModifier.swift`
- Modify: `Sources/SwiftWUI/State/StateStore.swift` (generalize `link` first parameter)
- Test: `Tests/SwiftWUITests/TagModifierTests.swift`

**Interfaces:**
- Consumes: `_PrimitiveTag`, `resolve(_:path:ctx:)`, `ResolveContext` (fields `store`, `invalidate`, `reachable`, `owner`, `collectedRoutes`, `environment`, `effects`), `NodeIdentity.appending(.type(...))`, `_TypeNameRegistry.register`, `AnyTag`, `_InvalidateBox`, `ComponentNode`, `StateStore.retain/link` — all existing.
- Produces: `public protocol TagModifier` (associatedtype `Body: Tag`, `typealias Content = _ModifierContent<Self>`, `@TagBuilder @MainActor func body(content: Content) -> Body`); `public struct _ModifierContent<M: TagModifier>`; `public struct ModifiedTag<C: Tag, M: TagModifier>: Tag`; `extension Tag { public func modifier<M: TagModifier>(_ m: M) -> ModifiedTag<Self, M> }`; `StateStore.link(_ value: Any, at:environment:invalidate:)` (was `some Tag`).

- [ ] **Step 1: Generalize `StateStore.link`**

In `Sources/SwiftWUI/State/StateStore.swift`, the graft entry point is declared as:

```swift
func link(_ component: some Tag, at id: NodeIdentity,
          environment: EnvironmentValues, invalidate: @escaping () -> Void) {
```

Change ONLY the first parameter type to `Any` (the body uses nothing but `Mirror(reflecting: component)`, which accepts `Any`):

```swift
func link(_ component: Any, at id: NodeIdentity,
          environment: EnvironmentValues, invalidate: @escaping () -> Void) {
```

Grep for other `store.link(`/`\.link(` call sites (`Resolver.swift`, possibly hydration seeding) — they all pass a Tag value, which converts to `Any` implicitly; no caller changes expected.

- [ ] **Step 2: Write `Sources/SwiftWUI/Core/TagModifier.swift`**

```swift
/// SwiftUI's ViewModifier, for Tags. The modifier's `body` composes wrapper
/// structure around a `Content` placeholder; `@State`/`@Environment` declared
/// on the modifier work exactly as in a component (spec 2026-07-12 §2.1).
public protocol TagModifier {
    associatedtype Body: Tag
    typealias Content = _ModifierContent<Self>
    @TagBuilder @MainActor func body(content: Content) -> Body
}

/// Placeholder for the wrapped content inside a modifier body. Resolves the
/// original content at the placeholder's structural position — using `content`
/// more than once in a body duplicates identity (documented limitation, same
/// as SwiftUI).
public struct _ModifierContent<M: TagModifier>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let content: AnyTag
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        resolve(content, path: path, ctx: &ctx)
    }
}

public struct ModifiedTag<C: Tag, M: TagModifier>: Tag, _PrimitiveTag {
    public typealias Body = Never
    let content: C
    let modifier: M

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.reachable.insert(id)
        ctx.store.retain(AnyTag(self), at: id, environment: ctx.environment)
        let inv = ctx.invalidate
        if ctx.collectedRoutes == nil {          // same guard as component resolve (C1)
            ctx.store.link(modifier, at: id, environment: ctx.environment,
                           invalidate: { inv(id) })
        }
        let box = _InvalidateBox(fire: { inv(id) })
        let savedOwner = ctx.owner
        ctx.owner = id
        defer { ctx.owner = savedOwner }
        // Unlike a component boundary, ctx.scopeClass is deliberately preserved:
        // modifier-wrapped content keeps the caller's Styled scope.
        let body = withObservationTracking {
            modifier.body(content: _ModifierContent(content: AnyTag(content)))
        } onChange: {
            MainActor.assumeIsolated { box.fire() }
        }
        let children = resolve(body, path: id.appending(.child(0)), ctx: &ctx)
        return [.component(ComponentNode(identity: id,
                                         typeName: String(describing: Self.self),
                                         key: nil,
                                         children: children))]
    }
}

extension Tag {
    public func modifier<M: TagModifier>(_ m: M) -> ModifiedTag<Self, M> {
        ModifiedTag(content: self, modifier: m)
    }
}
```

This mirrors the component branch of `resolve<T>` in `Runtime/Resolver.swift:45-83` — read it side by side before writing. Differences are intentional: graft target is `modifier` (not the whole tag), and `scopeClass` is NOT reset. The `.component` node + `retain(AnyTag(self))` make `subtreePass` re-resolution work unchanged: it resolves the retained `ModifiedTag` at the parent path, the `.type` segment re-mints the same id.

- [ ] **Step 3: Write `Tests/SwiftWUITests/TagModifierTests.swift`**

Follow house style: `MockBackend` + `TestScheduler` (from `RuntimeE2ETests.swift`) + `findFirst`. Cover:

```swift
import Testing
@testable import SwiftWUI

private struct Card: TagModifier {
    func body(content: Content) -> some Tag {
        Div(class: "card") { content }
    }
}

private struct Toggler: TagModifier {
    @State private var on = false
    func body(content: Content) -> some Tag {
        Div(class: on ? "t-on" : "t-off") {
            Button("toggle", onClick: { on = true })
            content
        }
    }
}

private final class SessionCapture { var seen: WebSession? }
private struct SessionReadingModifier: TagModifier {
    @Environment(\.webSession) var session
    let cap: SessionCapture
    func body(content: Content) -> some Tag {
        cap.seen = session
        return Div { content }
    }
}

@Suite @MainActor struct TagModifierTests {

    @Test func modifierWrapsContent() {
        // Text("hi").modifier(Card()) → <div class="card">hi</div>
        // assert via backend.serializeHTML()
    }

    @Test func extensionSugarEquivalent() {
        // extension Tag { func card() -> some Tag { modifier(Card()) } } fixture;
        // same serialized output as .modifier(Card())
    }

    @Test func stateInModifierSurvivesRerender() {
        // Mount Text("x").modifier(Toggler()); dispatch click on the button;
        // pump; expect class flips to "t-on" AND stays after a second unrelated
        // re-render (dispatch again is idempotent).
    }

    @Test func contentStateSurvivesModifierInvalidation() {
        // Content = a component with its own @State counter; toggling the
        // modifier's state must NOT reset the content's counter
        // (identity path stable through .type(ModifiedTag) + .child(0)).
    }

    @Test func environmentReachesModifier() {
        // runtime._webSession = WebSession(transport: MockTransport-like stub);
        // mount Text("x").modifier(SessionReadingModifier(cap: cap));
        // #expect(cap.seen !== WebSession.unsupported)
        // (precedent: WebFetchTests.runtimeSeedsSessionIntoEnvironment)
    }

    @Test func chainingTwoModifiersNests() {
        // Text("x").modifier(Card()).modifier(Card()) → two nested div.card;
        // distinct identity per link in the chain (types differ by C).
    }
}
```

Write the bodies out fully (the sketches above name the behavior; the implementer writes real assertions with `serializeHTML()`/`findFirst`/`runtime.dispatch`).

- [ ] **Step 4: Run tests once**

Run: `swift test`
Expected: full suite green (376 pre-existing + new).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Core/TagModifier.swift Sources/SwiftWUI/State/StateStore.swift Tests/SwiftWUITests/TagModifierTests.swift
git commit -m "feat(core): TagModifier protocol with component-grade @State/@Environment support"
```

---

### Task 3: Pointer + keyboard/focus interaction modifiers

**Files:**
- Modify: `Sources/SwiftWUI/HTML/EventName.swift` (add `mouseenter`, `mouseleave`)
- Modify: `Sources/SwiftWUI/HTML/EventPayloads.swift` (extend `KeyEvent`; add `KeyEquivalent`, `EventModifiers`)
- Create: `Sources/SwiftWUI/HTML/InteractionModifiers.swift`
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (`decodePayload` keydown/keyup modifier flags)
- Test: `Tests/SwiftWUITests/InteractionModifierTests.swift`

**Interfaces:**
- Consumes: `_AttributeBag.addHandler/addRawHandler` (internal), `EventName`, `ClickEvent`, existing `KeyEvent(key:repeated:)` callers (extend source-compatibly).
- Produces: `HTMLTag` extensions `onTap(_:)` ×2, `onDoubleTap(_:)`, `onHover(_:)`, `onKeyDown(_:)`, `onKeyUp(_:)`, `onKeyDown(_:modifiers:_:)`, `onFocus(_:)`, `onBlur(_:)`, `onSubmit(_:)`; `KeyEvent.metaKey/ctrlKey/shiftKey/altKey: Bool` + `var modifiers: EventModifiers`; `public struct KeyEquivalent`; `public struct EventModifiers: OptionSet`. Task 9 documents these.

- [ ] **Step 1: Extend EventName**

Add to `EventName`:

```swift
public static let mouseenter: EventName = "mouseenter"
public static let mouseleave: EventName = "mouseleave"
```

- [ ] **Step 2: Extend KeyEvent + add key-filter types (EventPayloads.swift)**

Replace `KeyEvent` with (source-compatible — new fields defaulted):

```swift
public struct KeyEvent {
    public let key: String
    public let repeated: Bool
    public let metaKey: Bool
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    public init(key: String, repeated: Bool,
                metaKey: Bool = false, ctrlKey: Bool = false,
                shiftKey: Bool = false, altKey: Bool = false) {
        self.key = key; self.repeated = repeated
        self.metaKey = metaKey; self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey; self.altKey = altKey
    }
    public var modifiers: EventModifiers {
        var m: EventModifiers = []
        if metaKey { m.insert(.meta) }
        if ctrlKey { m.insert(.ctrl) }
        if shiftKey { m.insert(.shift) }
        if altKey { m.insert(.alt) }
        return m
    }
}

/// DOM KeyboardEvent.key values, SwiftUI-KeyEquivalent style.
public struct KeyEquivalent: Equatable, ExpressibleByStringLiteral {
    public let key: String
    public init(key: String) { self.key = key }
    public init(stringLiteral value: String) { key = value }
    public static let enter = KeyEquivalent(key: "Enter")
    public static let escape = KeyEquivalent(key: "Escape")
    public static let space = KeyEquivalent(key: " ")
    public static let tab = KeyEquivalent(key: "Tab")
    public static let delete = KeyEquivalent(key: "Backspace")
    public static let upArrow = KeyEquivalent(key: "ArrowUp")
    public static let downArrow = KeyEquivalent(key: "ArrowDown")
    public static let leftArrow = KeyEquivalent(key: "ArrowLeft")
    public static let rightArrow = KeyEquivalent(key: "ArrowRight")
}

public struct EventModifiers: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let meta  = EventModifiers(rawValue: 1 << 0)
    public static let ctrl  = EventModifiers(rawValue: 1 << 1)
    public static let shift = EventModifiers(rawValue: 1 << 2)
    public static let alt   = EventModifiers(rawValue: 1 << 3)
}
```

- [ ] **Step 3: Write `Sources/SwiftWUI/HTML/InteractionModifiers.swift`**

```swift
/// Built-in interaction modifiers (spec 2026-07-12 §2.2). Event modifiers are
/// HTMLTag-only by design — they ride the attribute-bag path and return Self.
extension HTMLTag {
    public func onTap(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.click, action); return copy
    }
    /// Payload variant. A dispatch without payload (non-DOM backends, tests)
    /// arrives as an unmodified default ClickEvent.
    public func onTap(_ action: @escaping (ClickEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addRawHandler(.click) { any in action(any as? ClickEvent ?? ClickEvent()) }
        return copy
    }
    public func onDoubleTap(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.dblclick, action); return copy
    }
    public func onHover(_ action: @escaping (Bool) -> Void) -> Self {
        var copy = self
        copy._attributes.addRawHandler(.mouseenter) { _ in action(true) }
        copy._attributes.addRawHandler(.mouseleave) { _ in action(false) }
        return copy
    }
    public func onKeyDown(_ action: @escaping (KeyEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.keydown, payload: KeyEvent.self, action)
        return copy
    }
    public func onKeyUp(_ action: @escaping (KeyEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.keyup, payload: KeyEvent.self, action)
        return copy
    }
    /// Filtered form: fires only when key AND the exact modifier set match.
    public func onKeyDown(_ key: KeyEquivalent, modifiers: EventModifiers = [],
                          _ action: @escaping () -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.keydown, payload: KeyEvent.self) { e in
            if e.key == key.key && e.modifiers == modifiers { action() }
        }
        return copy
    }
    public func onFocus(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.focus, action); return copy
    }
    public func onBlur(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.blur, action); return copy
    }
    /// The DOM backend always calls preventDefault() on submit (spec D10).
    public func onSubmit(_ action: @escaping () -> Void) -> Self {
        var copy = self; copy._attributes.addHandler(.submit, action); return copy
    }
}
```

- [ ] **Step 4: Decode key modifiers in DOMBackend**

In `Sources/SwiftWUIDOM/DOMBackend.swift`, `static func decodePayload`, the `"keydown", "keyup"` case currently builds `KeyEvent(key:repeated:)`. Extend:

```swift
case "keydown", "keyup":
    return KeyEvent(key: e.key.string ?? "", repeated: e["repeat"].boolean ?? false,
                    metaKey: e.metaKey.boolean ?? false,
                    ctrlKey: e.ctrlKey.boolean ?? false,
                    shiftKey: e.shiftKey.boolean ?? false,
                    altKey: e.altKey.boolean ?? false)
```

(`mouseenter`/`mouseleave` need no decode case — the `GenericEvent` default branch is fine; `onHover` ignores the payload.)

- [ ] **Step 5: Write `Tests/SwiftWUITests/InteractionModifierTests.swift`**

House pattern (MockBackend + TestScheduler + findFirst + `runtime.dispatch(node.events["..."]!, payload:)`). Cover, with full assertions:

- `onTap` void form fires on click dispatch; payload form receives a `ClickEvent(button: 1)` payload and receives default `ClickEvent()` when payload is nil.
- `onDoubleTap` registers `"dblclick"`.
- `onHover` receives `true` on `"mouseenter"` dispatch and `false` on `"mouseleave"`.
- `onKeyDown` unfiltered receives the full `KeyEvent` including modifier flags.
- Filtered `onKeyDown(.enter, modifiers: [.meta])`: fires for `KeyEvent(key: "Enter", repeated: false, metaKey: true)`; does NOT fire for plain Enter, for Enter+meta+shift, or for Escape+meta (exact-match semantics).
- `onFocus`/`onBlur`/`onSubmit` fire on their events.
- Composition: `.onTap {}` on a `Button(onClick:)` — both handlers fire in registration order (chaining precedent in `resolveElement`).

- [ ] **Step 6: Run tests once**

Run: `swift test`
Expected: full suite green.

- [ ] **Step 7: Commit**

```bash
git add Sources/SwiftWUI/HTML/EventName.swift Sources/SwiftWUI/HTML/EventPayloads.swift Sources/SwiftWUI/HTML/InteractionModifiers.swift Sources/SwiftWUIDOM/DOMBackend.swift Tests/SwiftWUITests/InteractionModifierTests.swift
git commit -m "feat(html): onTap/onDoubleTap/onHover/onKey*/onFocus/onBlur/onSubmit interaction modifiers"
```

---

### Task 4: onLongPress + onScrollChange

**Files:**
- Modify: `Sources/SwiftWUI/HTML/EventName.swift` (add `pointerdown`, `pointerup`, `pointercancel`, `pointerleave`, `scroll`)
- Modify: `Sources/SwiftWUI/HTML/EventPayloads.swift` (add `ScrollEvent`)
- Modify: `Sources/SwiftWUI/HTML/InteractionModifiers.swift` (add the two modifiers)
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (`decodePayload` scroll case; passive listener option for scroll)
- Test: extend `Tests/SwiftWUITests/InteractionModifierTests.swift`

**Interfaces:**
- Consumes: Task 3's file layout.
- Produces: `HTMLTag.onLongPress(minimumDuration:_:)`, `HTMLTag.onScrollChange(_:)`; `public struct ScrollEvent { x, y: Double }`. Task 6 reuses `ScrollEvent` for window scroll.

- [ ] **Step 1: EventName + payload additions**

```swift
// EventName.swift
public static let pointerdown: EventName = "pointerdown"
public static let pointerup: EventName = "pointerup"
public static let pointercancel: EventName = "pointercancel"
public static let pointerleave: EventName = "pointerleave"
public static let scroll: EventName = "scroll"
```

```swift
// EventPayloads.swift
public struct ScrollEvent: Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}
```

Naming note (spec deviation, cosmetic): spec §2.2 sketched `ScrollOffset`/`Size`; this plan uses `ScrollEvent`/`SizeEvent` for consistency with the existing `*Event` payload family.

- [ ] **Step 2: The two modifiers (InteractionModifiers.swift)**

```swift
extension HTMLTag {
    /// Fires after the pointer stays down for `minimumDuration`.
    /// Known limitation: a re-render mid-press replaces the handlers and their
    /// press tracker; the in-flight timer from before the re-render can no
    /// longer be cancelled by the new pointerup handler.
    public func onLongPress(minimumDuration: Duration = .milliseconds(500),
                            _ action: @escaping () -> Void) -> Self {
        final class PressState { var task: Task<Void, Never>? }
        let state = PressState()
        var copy = self
        copy._attributes.addRawHandler(.pointerdown) { _ in
            state.task?.cancel()
            state.task = Task { @MainActor in
                try? await Task.sleep(for: minimumDuration)
                guard !Task.isCancelled else { return }
                state.task = nil
                action()
            }
        }
        let cancel: (Any?) -> Void = { _ in state.task?.cancel(); state.task = nil }
        copy._attributes.addRawHandler(.pointerup, cancel)
        copy._attributes.addRawHandler(.pointercancel, cancel)
        copy._attributes.addRawHandler(.pointerleave, cancel)
        return copy
    }

    /// Element scroll offset. No explicit throttle: browsers already coalesce
    /// scroll events to one per frame (spec §2.2's "rAF throttle" is satisfied
    /// by the platform; the DOM listener is registered passive).
    public func onScrollChange(_ action: @escaping (ScrollEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.scroll, payload: ScrollEvent.self, action)
        return copy
    }
}
```

- [ ] **Step 3: DOMBackend — scroll decode + passive option**

`decodePayload` new case:

```swift
case "scroll":
    return ScrollEvent(x: target?.scrollLeft.number ?? 0,
                       y: target?.scrollTop.number ?? 0)
```

In `setEventListener`, register scroll listeners passive (they never preventDefault). Where the closure is attached:

```swift
if event == "scroll" {
    let opts = JSObject.global.Object.function!.new()
    opts.passive = .boolean(true)
    _ = node.addEventListener?(event, closure, opts)
} else {
    _ = node.addEventListener?(event, closure)
}
```

`removeEventListener` needs no options (removal matches by function identity + capture flag; passive doesn't participate).

- [ ] **Step 4: Tests (extend InteractionModifierTests.swift)**

- `onScrollChange` receives `ScrollEvent(x: 0, y: 42)` on `"scroll"` dispatch.
- `onLongPress` fires: use `minimumDuration: .milliseconds(20)`; async test — dispatch `"pointerdown"`, `try await Task.sleep(for: .milliseconds(80))`, expect fired == true.
- `onLongPress` cancelled by pointerup: dispatch `"pointerdown"`, sleep 5ms, dispatch `"pointerup"`, sleep 80ms, expect fired == false. Same for `"pointercancel"`.

- [ ] **Step 5: Run tests once**

Run: `swift test`
Expected: full suite green.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI/HTML/EventName.swift Sources/SwiftWUI/HTML/EventPayloads.swift Sources/SwiftWUI/HTML/InteractionModifiers.swift Sources/SwiftWUIDOM/DOMBackend.swift Tests/SwiftWUITests/InteractionModifierTests.swift
git commit -m "feat(html): onLongPress and onScrollChange modifiers, passive scroll listeners"
```

---

### Task 5: Observer infrastructure — onVisibilityChange / onSizeChange

**Files:**
- Create: `Sources/SwiftWUI/HTML/ObserverModifiers.swift` (`ObserverKind` + public API)
- Modify: `Sources/SwiftWUI/HTML/EventPayloads.swift` (add `SizeEvent`)
- Modify: `Sources/SwiftWUI/HTML/AttributeBag.swift` (observer requests)
- Modify: `Sources/SwiftWUI/Tree/Node.swift` (`ElementNode.observers`)
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (`resolveElement` registers observers)
- Modify: `Sources/SwiftWUI/Render/Reconciler.swift` (Patch cases + element diff)
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift` (mount/teardown/apply)
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (`observe`/`unobserve` + default no-ops)
- Modify: `Sources/SwiftWUI/Render/AdoptingBackend.swift` (forwarders)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (recording)
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (IntersectionObserver/ResizeObserver impls + teardown)
- Test: `Tests/SwiftWUITests/ObserverModifierTests.swift`

**Interfaces:**
- Consumes: listener pipeline shapes from `resolveElement`, `Patch`, `MountedNode`, `TreeApplier` (this task mirrors them 1:1 for observers).
- Produces: `public enum ObserverKind: Hashable { case visibility(threshold: Double); case size }` with internal `var key: String`; `RendererBackend.observe(_:kind:id:)/unobserve(_:kind:)`; `ElementNode.observers: [ObserverKind: ListenerID]`; `MockNode.observers`; `HTMLTag.onVisibilityChange(threshold:_:)`, `HTMLTag.onSizeChange(_:)`; `public struct SizeEvent { width, height: Double }`. Task 6 reuses `SizeEvent`.

- [ ] **Step 1: Kind + payload + public API (`ObserverModifiers.swift`, `EventPayloads.swift`)**

```swift
// EventPayloads.swift
public struct SizeEvent: Equatable {
    public let width: Double
    public let height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}
```

```swift
// ObserverModifiers.swift
/// Element observers (spec 2026-07-12 §2.3). Same lifecycle discipline as
/// event listeners: attach on mount/patch, detach on unmount/patch.
public enum ObserverKind: Hashable {
    case visibility(threshold: Double)
    case size

    /// Reserved "event" namespace for ListenerID routing. Threshold is part of
    /// the key so two visibility observers with different thresholds coexist.
    var key: String {
        switch self {
        case .visibility(let t): return "swui:visibility:\(t)"
        case .size: return "swui:size"
        }
    }
}

extension HTMLTag {
    /// Fires with `true`/`false` as the element enters/leaves the viewport
    /// (IntersectionObserver).
    public func onVisibilityChange(threshold: Double = 0.0,
                                   _ action: @escaping (Bool) -> Void) -> Self {
        var copy = self
        copy._attributes.addObserver(.visibility(threshold: threshold)) { any in
            action(any as? Bool ?? false)
        }
        return copy
    }
    /// Fires with the element's content size on every resize (ResizeObserver).
    public func onSizeChange(_ action: @escaping (SizeEvent) -> Void) -> Self {
        var copy = self
        copy._attributes.addObserver(.size) { any in
            guard let s = any as? SizeEvent else { return }
            action(s)
        }
        return copy
    }
}
```

- [ ] **Step 2: Bag storage (`AttributeBag.swift`)**

Next to `handlers`:

```swift
private(set) var observers: [(kind: ObserverKind, action: (Any?) -> Void)] = []

mutating func addObserver(_ kind: ObserverKind, _ action: @escaping (Any?) -> Void) {
    observers.append((kind, action))
}
```

- [ ] **Step 3: Node + resolveElement**

`Tree/Node.swift` — add to `ElementNode` (after `listeners`):

```swift
let observers: [ObserverKind: ListenerID]
```

Update its init and ALL construction sites (grep `ElementNode(`) — everywhere except `resolveElement` pass `observers: [:]`.

`Runtime/Resolver.swift`, in `resolveElement` after the listener registration loop, mirroring its duplicate-composition behavior:

```swift
var observers: [ObserverKind: ListenerID] = [:]
var byKind: [ObserverKind: [(Any?) -> Void]] = [:]
var kindOrder: [ObserverKind] = []
for (kind, action) in bag.observers {
    if byKind[kind] == nil { kindOrder.append(kind) }
    byKind[kind, default: []].append(action)
}
for kind in kindOrder {
    let lid = ListenerID(owner: path, event: kind.key)
    let chain = byKind[kind]!
    ctx.listeners.set(lid, payloadHandler: { payload in
        for handler in chain { handler(payload) }
    })
    ctx.liveListeners.insert(lid)
    observers[kind] = lid
}
```

and thread `observers:` into the `ElementNode(...)` construction. (`liveListeners` membership means the existing registry sweep covers observer handlers with zero extra work.)

- [ ] **Step 4: Reconciler diff + Patch cases**

`Render/Reconciler.swift` — extend `Patch`:

```swift
case setObserver(kind: ObserverKind, id: ListenerID)
case removeObserver(kind: ObserverKind)
```

In the `.element` diff branch, directly after the listener diff loops (sort by `key` for determinism):

```swift
for kind in n.observers.keys.sorted(by: { $0.key < $1.key })
    where o.observers[kind] != n.observers[kind] {
    patches.append(.setObserver(kind: kind, id: n.observers[kind]!))
}
for kind in o.observers.keys.sorted(by: { $0.key < $1.key })
    where n.observers[kind] == nil {
    patches.append(.removeObserver(kind: kind))
}
```

- [ ] **Step 5: TreeApplier**

`MountedNode` — add `var observerKinds: Set<ObserverKind> = []`.

In `mount`, `.element` case, after the listener loop:

```swift
for kind in el.observers.keys.sorted(by: { $0.key < $1.key }) {
    backend.observe(h, kind: kind, id: el.observers[kind]!)
}
```
and after `m.events = ...`: `m.observerKinds = Set(el.observers.keys)`.

In `tearDownListeners` (it already recurses children), extend the host branch:

```swift
if let h = m.host {
    for e in m.events { backend.removeEventListener(h, event: e) }
    for k in m.observerKinds { backend.unobserve(h, kind: k) }
}
```

In `apply`, next to the listener cases:

```swift
case .setObserver(let kind, let id):
    backend.observe(m.host!, kind: kind, id: id)
    m.observerKinds.insert(kind)
case .removeObserver(let kind):
    backend.unobserve(m.host!, kind: kind)
    m.observerKinds.remove(kind)
```

- [ ] **Step 6: Backend protocol + AdoptingBackend + MockBackend**

`RendererBackend.swift` — add requirements (grouped, commented "Element observers (spec 2026-07-12)"):

```swift
func observe(_ node: HostNode, kind: ObserverKind, id: ListenerID)
func unobserve(_ node: HostNode, kind: ObserverKind)
```

plus default no-ops in the existing extension (so `HTMLRenderer`/SSG need no changes — observers are invisible to serialization by construction).

`AdoptingBackend.swift` — 1:1 forwarders like every other method:

```swift
func observe(_ node: Base.HostNode, kind: ObserverKind, id: ListenerID) { base.observe(node, kind: kind, id: id) }
func unobserve(_ node: Base.HostNode, kind: ObserverKind) { base.unobserve(node, kind: kind) }
```

`MockBackend.swift` — `MockNode` gains `var observers: [ObserverKind: ListenerID] = [:]`; implement with count bumps:

```swift
public func observe(_ node: MockNode, kind: ObserverKind, id: ListenerID) {
    bump("observe"); node.observers[kind] = id
}
public func unobserve(_ node: MockNode, kind: ObserverKind) {
    bump("unobserve"); node.observers[kind] = nil
}
```

Tests fire observer callbacks the same way they fire events: `runtime.dispatch(node.observers[.size]!, payload: SizeEvent(width: 10, height: 20))` — no extra simulate helper needed.

- [ ] **Step 7: DOMBackend implementation**

Retention dictionaries mirror the listener `closures` pattern, keyed `"\(uid)#\(kind.key)"`:

```swift
private var domObservers: [String: JSObject] = [:]
private var observerClosures: [String: JSClosure] = [:]
private var observerIDs: [String: ListenerID] = [:]

private func observerKey(_ node: JSObject, _ kind: ObserverKind) -> String {
    "\(Int(node.__swuid.number ?? -1))#\(kind.key)"
}

public func observe(_ node: JSObject, kind: ObserverKind, id: ListenerID) {
    let key = observerKey(node, kind)
    observerIDs[key] = id
    guard domObservers[key] == nil else { return }   // fire-time lookup, reusable
    let closure: JSClosure
    let observer: JSObject?
    switch kind {
    case .visibility(let threshold):
        closure = JSClosure { [weak self] args in
            guard let self, let current = self.observerIDs[key] else { return .undefined }
            let visible = args.first?.object?[0].object?.isIntersecting.boolean ?? false
            self.dispatch(current, visible)
            return .undefined
        }
        let opts = JSObject.global.Object.function!.new()
        opts.threshold = .number(threshold)
        observer = JSObject.global.IntersectionObserver.function?.new(closure, opts)
    case .size:
        closure = JSClosure { [weak self] args in
            guard let self, let current = self.observerIDs[key] else { return .undefined }
            let rect = args.first?.object?[0].object?.contentRect.object
            self.dispatch(current, SizeEvent(width: rect?.width.number ?? 0,
                                             height: rect?.height.number ?? 0))
            return .undefined
        }
        observer = JSObject.global.ResizeObserver.function?.new(closure)
    }
    guard let observer else { return }               // API absent (old browser) → no-op
    _ = observer.observe?(node)
    domObservers[key] = observer
    observerClosures[key] = closure                  // Swift retention = lifetime
}

public func unobserve(_ node: JSObject, kind: ObserverKind) {
    let key = observerKey(node, kind)
    observerIDs[key] = nil
    guard let observer = domObservers.removeValue(forKey: key) else { return }
    _ = observer.disconnect?()
    observerClosures[key] = nil
}
```

Teardown symmetry: in `endEnvironmentObservation()`, disconnect every entry of `domObservers` and clear all three dictionaries.

- [ ] **Step 8: Tests (`ObserverModifierTests.swift`)**

- Mount `Div().onSizeChange { ... }` → `findFirst(..., tag: "div")!.observers[.size]` is non-nil; `runtime.dispatch(id, payload: SizeEvent(width: 10, height: 20))` delivers the payload.
- `onVisibilityChange(threshold: 0.5)` → key present as `.visibility(threshold: 0.5)`; dispatch `true`/`false` delivered.
- Two visibility observers with different thresholds on one element → two distinct entries, both fire.
- Conditional unmount (`if show { Div().onSizeChange{...} }`, flip `show` via a button) → `counts["unobserve"] == 1` after re-render and the node's observers cleared.
- Observer + listener on the same element coexist.
- Re-render with unchanged observer → no extra `observe` call (`counts["observe"]` stable — Reconciler emits no patch when `ListenerID` is unchanged).

- [ ] **Step 9: Run tests once + wasm gate**

Run: `swift test`
Expected: full suite green.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --scratch-path .build-wasm --target SwiftWUIDOM`
Expected: builds (DOMBackend changed).

- [ ] **Step 10: Commit**

```bash
git add Sources/SwiftWUI Sources/SwiftWUIDOM Tests/SwiftWUITests/ObserverModifierTests.swift
git commit -m "feat(core,dom): element observer pipeline — onVisibilityChange/onSizeChange"
```

---

### Task 6: Window-level effects — onWindowScroll / onWindowResize

**Files:**
- Create: `Sources/SwiftWUI/Effects/WindowEvents.swift`
- Modify: `Sources/SwiftWUI/Effects/EffectStore.swift` (new request case + subscriptions)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (hub ownership + backend wiring)
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (+AdoptingBackend, MockBackend)
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (window listeners)
- Test: `Tests/SwiftWUITests/WindowEventTests.swift`

**Interfaces:**
- Consumes: `ScrollEvent`/`SizeEvent` (Tasks 4–5), `EffectRequest` extension recipe (`EffectStore.swift` sweep union + `_cancelAll`), wrapper-effect recipe (`_TaskEffect` shape).
- Produces: `public enum WindowEventKind: Hashable { case scroll, resize }`; `WindowEventHub` (internal class); `EffectRequest.windowEvent(id:kind:action:)`; `EffectStore._windowHub`; `RendererBackend.beginWindowEventObservation(_:)`; `MockBackend.windowEventSink`; `Tag.onWindowScroll(_:)`, `Tag.onWindowResize(_:)`.

- [ ] **Step 1: Hub + wrapper + public API (`WindowEvents.swift`)**

```swift
public enum WindowEventKind: Hashable {
    case scroll, resize
}

/// Runtime-owned fan-out for window-level events. The backend attaches real
/// window listeners lazily, on the first subscription ever (page lifetime,
/// like environment observation — never detached).
@MainActor
final class WindowEventHub {
    private var subscribers: [NodeIdentity: (kind: WindowEventKind, action: (Any) -> Void)] = [:]
    var onFirstSubscriber: (() -> Void)?
    private var began = false

    func subscribe(id: NodeIdentity, kind: WindowEventKind, action: @escaping (Any) -> Void) {
        subscribers[id] = (kind, action)
        if !began { began = true; onFirstSubscriber?() }
    }
    func unsubscribe(id: NodeIdentity) { subscribers[id] = nil }
    func dispatch(_ kind: WindowEventKind, payload: Any) {
        for (_, sub) in subscribers where sub.kind == kind { sub.action(payload) }
    }
}

struct _WindowEventEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let kind: WindowEventKind
    let action: (Any) -> Void
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        _TypeNameRegistry.register(Self.self)
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.windowEvent(id: id, kind: kind, action: action))
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    /// Window (page) scroll. Element-independent, so available on any Tag —
    /// unlike element-bound event modifiers (HTMLTag-only).
    public func onWindowScroll(_ action: @escaping (ScrollEvent) -> Void) -> some Tag {
        _WindowEventEffect(kind: .scroll,
                           action: { any in if let e = any as? ScrollEvent { action(e) } },
                           content: self)
    }
    public func onWindowResize(_ action: @escaping (SizeEvent) -> Void) -> some Tag {
        _WindowEventEffect(kind: .resize,
                           action: { any in if let e = any as? SizeEvent { action(e) } },
                           content: self)
    }
}
```

- [ ] **Step 2: EffectStore**

Follow the documented new-effect-kind recipe exactly (see `EffectStore.swift` structure):

1. `EffectRequest` — add `case windowEvent(id: NodeIdentity, kind: WindowEventKind, action: (Any) -> Void)`; extend the `var id` switch.
2. State: `var _windowHub: WindowEventHub?` (internal — `WindowEventHub` is an internal type, so this member must NOT be `public` even though `EffectStore` is a public class; Runtime sets it from within the module) and `private var windowSubscriptions: Set<NodeIdentity> = []`.
3. `reconcile`: include `windowSubscriptions` in the `known` union; in the sweep-removal loop add `if windowSubscriptions.remove(id) != nil { _windowHub?.unsubscribe(id) }`. In the per-request switch: `.windowEvent` → `windowSubscriptions.insert(id); _windowHub?.subscribe(id: id, kind: kind, action: action)` (re-subscribing every pass overwrites the closure — intended, keeps captures fresh).
4. `_cancelAll()`: unsubscribe every id in `windowSubscriptions`, then clear it.
5. `_buildMode`: no special-casing — subscribing against a MockBackend/SSG hub is a harmless no-op (its backend never fires).

- [ ] **Step 3: Runtime + backend seam**

`RendererBackend.swift`:

```swift
// Window-level events (spec 2026-07-12)
func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void)
```
+ default no-op in the extension; `AdoptingBackend` forwarder; `MockBackend`:

```swift
public private(set) var windowEventSink: ((WindowEventKind, Any) -> Void)?
public func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void) {
    bump("beginWindowEventObservation"); windowEventSink = sink
}
```

`Runtime.swift`: own the hub and wire lazily:

```swift
let windowEvents = WindowEventHub()          // near `private let effects = EffectStore()`
```
In `init` (after effects exists):
```swift
effects._windowHub = windowEvents
windowEvents.onFirstSubscriber = { [weak self] in
    guard let self else { return }
    self.applier.backend.beginWindowEventObservation { [weak self] kind, payload in
        self?.windowEvents.dispatch(kind, payload: payload)
    }
}
```

`DOMBackend.swift`:

```swift
private var windowScrollClosure: JSClosure?
private var windowResizeClosure: JSClosure?

public func beginWindowEventObservation(_ sink: @escaping (WindowEventKind, Any) -> Void) {
    guard windowScrollClosure == nil, let window = JSObject.global.window.object else { return }
    let scroll = JSClosure { _ in
        sink(.scroll, ScrollEvent(x: JSObject.global.window.scrollX.number ?? 0,
                                  y: JSObject.global.window.scrollY.number ?? 0))
        return .undefined
    }
    let opts = JSObject.global.Object.function!.new()
    opts.passive = .boolean(true)
    _ = window.addEventListener?("scroll", scroll, opts)
    let resize = JSClosure { _ in
        sink(.resize, SizeEvent(width: JSObject.global.window.innerWidth.number ?? 0,
                                height: JSObject.global.window.innerHeight.number ?? 0))
        return .undefined
    }
    _ = window.addEventListener?("resize", resize)
    windowScrollClosure = scroll
    windowResizeClosure = resize
}
```

Teardown symmetry: in `endEnvironmentObservation()` remove both listeners and nil the closures (mirror the `online`/`offline` handling there).

- [ ] **Step 4: Tests (`WindowEventTests.swift`)**

- Mount a tag with `.onWindowScroll { … }` → `backend.windowEventSink != nil` (lazy begin fired). Mount WITHOUT any window modifier → sink stays nil.
- `backend.windowEventSink!(.scroll, ScrollEvent(x: 0, y: 42))` → action received the payload; a `.resize` dispatch does NOT hit the scroll subscriber.
- Two subscribers (scroll + resize on different subtrees) both routed by kind.
- Conditional unmount: subscriber inside `if show { … }`; flip `show` off via button + pump; sink dispatch no longer reaches the removed action (effect sweep unsubscribed it).
- `onWindowResize` payload delivery.

- [ ] **Step 5: Run tests once + wasm gate**

Run: `swift test`
Expected: full suite green.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --scratch-path .build-wasm --target SwiftWUIDOM`
Expected: builds.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI Sources/SwiftWUIDOM Tests/SwiftWUITests/WindowEventTests.swift
git commit -m "feat(core,dom): window-level effects — onWindowScroll/onWindowResize via WindowEventHub"
```

---

### Task 7: WebSession.shared

**Files:**
- Modify: `Sources/SwiftWUI/Fetch/WebFetch.swift` (statics)
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (bootstrap in `finishMount`)
- Modify: `Sources/SwiftWUIStatic/StaticSite.swift` (single session + bootstrap)
- Modify: `docs/superpowers/specs/2026-07-12-bridgejs-tagmodifier-websession-design.md` (one-line amendment, see Step 1)
- Test: `Tests/SwiftWUITests/WebSessionSharedTests.swift`

**Interfaces:**
- Consumes: `WebSession`, `WebSession.unsupported`, `Runtime._webSession`, `FetchJSTransport`, `URLSessionTransport`, `StaticSite.generate` internals (`probe` construction + `renderPage`).
- Produces: `WebSession.shared` (`@MainActor public private(set) static`), `WebSession.bootstrap(_:)`, `WebSession.resetShared()`.

- [ ] **Step 1: Spec amendment (silent overwrite)**

The spec (§3.1) says repeated `bootstrap` warns on the console. SSG bootstraps once per `generate()` call, and test suites call `generate()` many times — a warning would be routine noise, not signal. Amend the spec sentence to: "Repeated calls overwrite silently (SSG and test runs bootstrap per generate; a dev reload is a fresh process)." Commit together with this task.

- [ ] **Step 2: Statics (`WebFetch.swift`)**

```swift
extension WebSession {
    /// Process-wide default, set by platform entry points (DOM boot, StaticSite).
    /// Bare Runtime construction never touches it — parallel native tests that
    /// build their own runtimes cannot race on this global.
    @MainActor public private(set) static var shared: WebSession = .unsupported
    /// Called by platform entry points; repeated calls overwrite silently.
    @MainActor public static func bootstrap(_ session: WebSession) {
        shared = session
    }
    /// Back to .unsupported. For tests and dev tooling.
    @MainActor public static func resetShared() {
        shared = .unsupported
    }
}
```

- [ ] **Step 3: Platform call sites**

`DOMRuntime.swift`, inside `finishMount` (runs exactly once per surviving runtime — NOT in `makeRuntime`, which runs twice on a hydration mismatch): add near the top:

```swift
if let session = runtime._webSession { WebSession.bootstrap(session) }
```

`StaticSite.swift`: today two independent `WebSession(transport: URLSessionTransport())` constructions exist (enumeration probe and `renderPage`). Refactor: construct ONE session at the top of `generate()`, `WebSession.bootstrap(session)` there, and pass that instance to both existing seeding points (`probe._webSession = session`, and thread it into `renderPage` — parameter or stored property, whichever is the smaller diff). Behavior for `@Environment(\.webSession)` is unchanged (same-instance guarantee, spec §3.2).

- [ ] **Step 4: Tests (`WebSessionSharedTests.swift`)**

Mark the suite `.serialized` (it mutates process-global state) and write races-proof: capture `WebSession.shared` into a local synchronously before any `await`.

```swift
@Suite(.serialized) @MainActor struct WebSessionSharedTests {

    @Test func defaultsToUnsupportedAndThrows() async {
        WebSession.resetShared()
        let s = WebSession.shared                      // capture before await
        #expect(s === WebSession.unsupported)
        await #expect(throws: WebFetchError.unsupported) {
            _ = try await s.data(from: "/api/x")
        }
    }

    @Test func bootstrapSetsAndResetClears() {
        let t = MockTransport()                        // reuse WebFetchTests pattern
        let session = WebSession(transport: t)
        WebSession.bootstrap(session)
        #expect(WebSession.shared === session)
        WebSession.resetShared()
        #expect(WebSession.shared === WebSession.unsupported)
    }

    @Test func sharedWorksFromPlainCode() async throws {
        // The ViewModel story: no Tag/Page anywhere in sight.
        let t = MockTransport()
        t.queue = [.success((Data("{\"ok\":true}".utf8),
                             WebResponse(status: 200, headers: [:])))]
        WebSession.bootstrap(WebSession(transport: t))
        defer { WebSession.resetShared() }
        struct R: Decodable { let ok: Bool }
        let s = WebSession.shared
        let r: R = try await s.json(from: "/api/x")
        #expect(r.ok)
    }

    @Test func ssgGenerateBootstrapsShared() throws {
        WebSession.resetShared()
        defer { WebSession.resetShared() }
        // Minimal StaticSite.generate run — copy the fixture from
        // WebFetchTests.ssgRuntimeSeesConfiguredSession.
        // After generate:
        #expect(WebSession.shared !== WebSession.unsupported)
    }
}
```

(`MockTransport` is `private` to `WebFetchTests.swift` — duplicate the 9-line class in this file rather than widening its access.)

- [ ] **Step 5: Run tests once + wasm gate**

Run: `swift test`
Expected: full suite green.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --scratch-path .build-wasm --target SwiftWUIDOM`
Expected: builds (DOMRuntime changed).

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI/Fetch/WebFetch.swift Sources/SwiftWUIDOM/DOMRuntime.swift Sources/SwiftWUIStatic/StaticSite.swift Tests/SwiftWUITests/WebSessionSharedTests.swift docs/superpowers/specs/2026-07-12-bridgejs-tagmodifier-websession-design.md
git commit -m "feat(fetch): WebSession.shared with platform bootstrap and resetShared"
```

---

### Task 8: BridgeJS migration of structural DOM ops (depends on Task 1 passing its gate)

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (structural ops → bridged calls)
- Modify: `Sources/SwiftWUIDOM/FetchJSTransport.swift` (typed fetch entry — optional sub-step with exit hatch)
- Modify: `Sources/SwiftWUIDOM/bridge-js.global.d.ts` + regenerate `Generated/` (ONLY if the fetch sub-step needs new declarations)

**Interfaces:**
- Consumes: Task 1's generated `SWDocument`/`SWNode`/`document` (verify real generated names in `Generated/BridgeJS.Macros.swift` first), `init(unsafelyWrapping:)`, `.jsObject`.
- Produces: no API changes — everything behind `RendererBackend`.

**Hybrid boundary reminder (spec §1.2):** listeners/observers/`decodePayload`, `setProperty` (dynamic property names), `__swuid` stamping, `getElementById` (nullable), hydration reads (`childCount`/`child`/`tagName`) all STAY dynamic. Note: the spec lists `classList`/`style.setProperty` as migration targets, but SwiftWUI writes classes/styles via `setAttribute` — there are no such call sites; record this as N/A in the task report.

- [ ] **Step 1: Migrate DOMBackend structural ops**

If DOMBackend has its own `document` binding for dynamic calls, rename it `jsDocument` first (the generated global getter is also named `document`; keep dynamic uses like `getElementById` on `jsDocument`).

```swift
public func createElement(_ tag: String) -> JSObject {
    let el = try! document.createElement(tag).jsObject
    el.__swuid = .number(Double(nextUID)); nextUID += 1
    return el
}
public func createTextNode(_ text: String) -> JSObject {
    let n = try! document.createTextNode(text).jsObject
    n.__swuid = .number(Double(nextUID)); nextUID += 1
    return n
}
public func setText(_ node: JSObject, _ text: String) {
    try! SWNode(unsafelyWrapping: node).setData(text)
}
public func setAttribute(_ node: JSObject, name: String, value: String) {
    try! SWNode(unsafelyWrapping: node).setAttribute(name, value)
}
public func removeAttribute(_ node: JSObject, name: String) {
    try! SWNode(unsafelyWrapping: node).removeAttribute(name)
}
public func insert(_ child: JSObject, into parent: JSObject, before anchor: JSObject?) {
    let p = SWNode(unsafelyWrapping: parent)
    if let anchor { try! p.insertBefore(SWNode(unsafelyWrapping: child),
                                        SWNode(unsafelyWrapping: anchor)) }
    else { try! p.appendChild(SWNode(unsafelyWrapping: child)) }
}
public func remove(_ child: JSObject, from parent: JSObject) {
    try! SWNode(unsafelyWrapping: parent).removeChild(SWNode(unsafelyWrapping: child))
}
```

`try!` is deliberate: these calls failing means a framework bug, identical severity to the current `document.createElement(tag).object!` force-unwraps. Exact setter names (`setData`, `setAttribute` arg labels) MUST be read off `Generated/BridgeJS.Macros.swift`, not assumed.

- [ ] **Step 2: FetchJSTransport typed entry (bounded; with exit hatch)**

Add to `bridge-js.global.d.ts`:

```typescript
type SWResponse = {
    readonly status: number
    arrayBuffer(): Promise<any>
}
export function fetch(url: string, options: any): Promise<SWResponse>
```

Regenerate (`swift package plugin --allow-writing-to-package-directory bridge-js --target SwiftWUIDOM`), commit `Generated/` with this task. In `FetchJSTransport.perform`, replace the `JSObject.global.fetch!` + `JSPromise` dance with the bridged async call: `let resp = try await fetch(request.url, .object(options))`, `let status = Int(try resp.status)`, `let buf = try await resp.arrayBuffer()` → `_dataFromArrayBuffer(buf)`. Keep: options building, AbortController, setTimeout, headers `forEach` iteration (all dynamic — that's the hybrid boundary). Map `JSException` into `WebFetchError.network` in the existing catch, preserving the timeout/cancel precedence checks.

**Exit hatch:** if TS2Swift rejects `any` params / `Promise<any>` or the JSException-vs-abort error mapping loses the timeout/cancelled distinction (native tests + the manual fetch check must stay truthful), revert this sub-step only, leave FetchJSTransport fully dynamic, and record the reason in the task report + one line in the spec's §1.2.

- [ ] **Step 3: Gates**

```bash
swift build && swift test
swift build --swift-sdk swift-6.3.3-RELEASE_wasm --scratch-path .build-wasm --target SwiftWUIDOM
cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug && cd ../..
```
Expected: all green. Browser acceptance (manual, session lead): Counter and TodoMVC mount, update, click, fetch — no console errors; micro-benchmark per Final Verification below.

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUIDOM
git commit -m "feat(dom): migrate structural DOM ops and fetch entry to BridgeJS typed bindings"
```

---

### Task 9: Documentation

**Files:**
- Create: `Sources/SwiftWUI/SwiftWUI.docc/Modifiers.md`
- Modify: `Sources/SwiftWUI/SwiftWUI.docc/BrowserAPIs.md` (WebSession.shared section)
- Modify: `Sources/SwiftWUI/SwiftWUI.docc/SwiftWUI.md` (topic list)
- Modify: `CLAUDE.md` (Core architecture bullets)

**Interfaces:** consumes the final public API of Tasks 2–7 — write docs against the code as merged, not against this plan.

- [ ] **Step 1: `Modifiers.md`**

Same header style as `BrowserAPIs.md` (`# Title`, `## Overview`, `###` per capability, code examples, double-backtick symbol links). Cover: `TagModifier` protocol with a custom-modifier example (Card + `extension Tag` sugar + @State-in-modifier note + the "use `content` once" limitation); every built-in from Tasks 3–6 grouped as pointer / keyboard & focus / element observers / window-level; the HTMLTag-only rule for event modifiers vs any-Tag for window-level; `Button(onClick:)` vs `.onTap` relationship note (spec §2.4).

- [ ] **Step 2: `BrowserAPIs.md` — "Networking from anywhere" section**

Document `WebSession.shared` / `bootstrap` / `resetShared`, the unsupported-outside-runtime behavior, and the ViewModel recipe (init-injection for unit testability, `.shared` as app-code default; `@Environment(\.webSession)` unchanged).

- [ ] **Step 3: `SwiftWUI.md` topics**

Add `- <doc:Modifiers>` next to the existing `<doc:BrowserAPIs>` entry.

- [ ] **Step 4: CLAUDE.md — Core architecture bullets**

Add two lines (match existing bullet voice):
- TagModifier: compositional `ViewModifier` analog; `ModifiedTag` is a component boundary (@State/@Environment work, Styled scope preserved); event modifiers are HTMLTag-only, window-level effects Tag-wide.
- BridgeJS: SwiftWUIDOM structural DOM ops use vendored BridgeJS bindings (`bridge-js.global.d.ts` → committed `Generated/`, regen via `swift package plugin bridge-js --target SwiftWUIDOM`; `Extern` feature flag on the target); events/nullable/dynamic-property paths stay on JSObject. Skip this bullet if Task 1's exit criterion fired.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/SwiftWUI.docc CLAUDE.md
git commit -m "docs: TagModifier + interaction modifiers article, WebSession.shared, BridgeJS notes"
```

---

## Final verification (session lead)

- [ ] `swift test` — full suite green.
- [ ] Framework wasm gate + Counter `swift package js` gate green.
- [ ] Browser acceptance checklist (manual, dev server `npm --prefix Examples/Counter run dev`):
  - tap / double-tap / hover / long-press / key filters on a scratch page
  - element scroll offset + visibility toggle (scroll a tall list) + size change (resize a textarea)
  - window scroll/resize modifiers fire; no console errors
  - fetch from a plain class via `WebSession.shared`
  - BridgeJS canary silent on boot (no fatalError in console)
- [ ] BridgeJS micro-benchmark (spec §1.5): on a scratch branch, temporary `console.time` around mounting ~2000 `Div`s in Counter, compare against `main`. A regression blocks the Task 8 merge, not the rest.
- [ ] Update memory status file per project convention.
