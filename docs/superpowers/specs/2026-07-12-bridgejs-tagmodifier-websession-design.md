# BridgeJS Adoption, TagModifier, and WebSession.shared — Design

**Date:** 2026-07-12
**Status:** Approved (brainstorm complete)
**Scope:** One combined spec, three independent sections, phased implementation.

## Overview

Three additions to SwiftWUI:

1. **BridgeJS (internal):** migrate SwiftWUIDOM's JS interop from dynamic `JSObject` calls to JavaScriptKit BridgeJS typed bindings — hybrid boundary, AOT-vendored codegen, incremental.
2. **TagModifier:** a `ViewModifier`-style protocol for user-defined compositional modifiers, plus a set of built-in interaction modifiers (`onTap`, `onScrollChange`, `onVisibilityChange`, …).
3. **WebSession.shared:** a process-wide default `WebSession` so network calls work from ViewModels and any `@MainActor` code, not only from Tag/Page via `@Environment`.

Public API of the framework is unchanged by section 1; sections 2–3 are additive.

## Decisions log (from brainstorm)

- One combined spec for all three (user choice; decomposition was offered and declined).
- BridgeJS consumer = the framework itself (not user-facing JS-library bindings).
- Migration scope = all of SwiftWUIDOM **except** where BridgeJS is the wrong tool (hybrid; see §1.2 — full-surface migration was requested, research showed the event layer must stay dynamic).
- Event modifiers stay HTMLTag-only; `TagModifier` is purely compositional. No auto-attachment of events to component roots.
- Built-in modifier groups: pointer, keyboard/focus, element observers, window-level — all four in scope.
- WebSession access mechanism = `WebSession.shared` static with explicit `bootstrap`/`resetShared`.

---

## 1. BridgeJS (internal migration, hybrid, AOT-vendored)

### 1.1 Facts (research, JavaScriptKit 0.56.1 — the pinned version)

- BridgeJS is experimental but past MVP (shipped 0.44.1). Two directions: import JS→Swift (from `bridge-js.d.ts` or `@JSClass`/`@JSFunction` macros) and export Swift→JS (`@JS`).
- **No experimental env var exists.** The only opt-ins: register the plugin + `.enableExperimentalFeature("Extern")` in the target's `swiftSettings` (generated code uses `@_extern(wasm)`).
- **Vendoring is first-class:** the `bridge-js` *command* plugin writes generated code into `Sources/<Target>/Generated/`, which is committed; the *build* plugin is then omitted entirely. Downstream consumers need neither the plugin nor any flag on their own targets.
- Structural DOM calls, `classList`/`style.setProperty`, Promises↔async, typed arrays, `throws(JSException)` — all supported.
- Maintainer guidance: **DOM event listeners should stay on dynamic `JSClosure`/`JSObject`** — typed event interfaces are copy-structs serialized per dispatch (a perf regression vs our fire-time-lookup `ListenerRegistry`).
- Open upstream gaps: `T|null` import (#475), TS generics (#398), overload collisions, dynamic `style.x =` assignment.
- Cross-**package** consumption of a BridgeJS-importing library is only demonstrated same-package upstream → must be spiked.

### 1.2 Hybrid boundary

All changes live behind the existing backend seam; no public API change.

**Migrates to BridgeJS typed bindings (as shipped):**
- Structural DOM ops: `createElement`, `createTextNode`, `appendChild`, `insertBefore`, `removeChild`, `setAttribute`, `removeAttribute`.
- `FetchJSTransport` (fetch + Promise↔async).

**N/A — no call sites in the shipped backend, so nothing to migrate:** `classList.add/remove/toggle`, `style.setProperty`, and the typed-array file-reading paths (`DOMFileReader` is left untouched on dynamic `JSObject`).

**Stays on dynamic `JSObject`/`JSClosure`:**
- `addEventListener` wiring and event-object property reads (`ListenerRegistry` fire-time lookup — per maintainer guidance and our own perf design).
- Nullable DOM getters, e.g. `getElementById` (until upstream #475).
- `textContent` writes and dynamic `style`/property assignment; overload-sensitive calls.

### 1.3 Structure

- `Sources/SwiftWUIDOM/bridge-js.global.d.ts` — declaration of the DOM subset we call (`SWDocument`, `SWNode`, and the `document` global; the methods listed above). `bridge-js.d.ts` ships as an **intentionally empty placeholder** (its mere presence is required — JavaScriptKit 0.56.1's command plugin only forwards `--project` to the tool when it exists), and a root `tsconfig.json` works around the same upstream plugin gap.
- `Sources/SwiftWUIDOM/Generated/` — output of `swift package plugin bridge-js`, **committed to git**. The BridgeJS *build* plugin is NOT added to Package.swift.
- Package.swift: SwiftWUIDOM target gains `.enableExperimentalFeature("Extern")`. Nothing else changes for consumers.

**Regeneration rule (goes into CLAUDE.md + contributor docs):** any edit to `bridge-js.global.d.ts` requires re-running the command plugin and committing `Generated/` in the same commit.

### 1.4 Spike (first task, with exit criterion)

An external package (Examples/Counter is already a separate package) must build against SwiftWUIDOM with vendored `Generated/` using the standard toolchain (`swift-6.3.3-RELEASE_wasm`), and the app must boot in a browser.

**Exit criterion:** if cross-package consumption fails and has no reasonable workaround, section 1 is deferred until BridgeJS GA. Sections 2–3 are not blocked by this outcome.

### 1.5 Verification

- Native tests untouched (MockBackend covers reconciler/applier; no JS in native builds).
- WASM build gate: SwiftWUIDOM + examples compile with the pinned SDK.
- Browser acceptance: Counter + TodoMVC run correctly (mount, update, events, fetch).
- Micro-benchmark: mount/update of N nodes before vs after migration (upstream claims "significantly better performance" but publishes no numbers — we measure ourselves). A regression is a blocker for landing the migration commit, not for the spike.

---

## 2. TagModifier + built-in interaction modifiers

### 2.1 TagModifier protocol (SwiftWUI core, zero deps)

```swift
public protocol TagModifier {
    associatedtype Body: Tag
    typealias Content = _ModifierContent<Self>
    @TagBuilder @MainActor func body(content: Content) -> Body
}

public struct ModifiedTag<C: Tag, M: TagModifier>: Tag { /* primitive */ }

extension Tag {
    public func modifier<M: TagModifier>(_ m: M) -> ModifiedTag<Self, M>
}
```

- `ModifiedTag` resolves **as a component**: identity gets a `.type(M.self)` segment, state is grafted before `body` runs → `@State` and `@Environment` inside a modifier work exactly like in a component. This reuses the existing component machinery; no new mechanism.
- `_ModifierContent` is a placeholder tag: on resolve it substitutes the wrapped content at the recorded path. Using `content` more than once in `body` duplicates identity — documented limitation (same as SwiftUI).
- Example:

```swift
struct Card: TagModifier {
    @State private var hovered = false
    func body(content: Content) -> some Tag {
        Div(class: hovered ? "card card-hover" : "card") { content }
            .onHover { hovered = $0 }
    }
}
extension Tag { func card() -> some Tag { modifier(Card()) } }
```

### 2.2 Built-in modifiers

Event modifiers are **HTMLTag-only** (bag path, return `Self`), consistent with the existing `.on(_:perform:)`. Window-level modifiers are element-independent and therefore available on **any Tag** via the wrapper/effect path (like `.task`).

| API | Available on | Mechanism |
|---|---|---|
| `onTap { }` / `onTap { ClickEvent in }` (button, modifier keys) | HTMLTag | existing event layer |
| `onDoubleTap { }` | HTMLTag | `dblclick` |
| `onHover { Bool in }` | HTMLTag | `mouseenter`/`mouseleave` |
| `onLongPress(minimumDuration:) { }` | HTMLTag | `pointerdown`/`pointerup` + timer on the backend JS side |
| `onKeyDown` / `onKeyUp { KeyEvent in }`, plus filtered form `onKeyDown(.enter, modifiers: [.meta]) { }` | HTMLTag | event layer, typed payload |
| `onFocus { }` / `onBlur { }` | HTMLTag | event layer |
| `onSubmit { }` (calls `preventDefault` by default) | HTMLTag (forms) | event layer |
| `onScrollChange { ScrollEvent in }` | HTMLTag | `scroll` + rAF throttle on the backend side |
| `onVisibilityChange(threshold:) { Bool in }` | HTMLTag | IntersectionObserver (new observer infra) |
| `onSizeChange { SizeEvent in }` | HTMLTag | ResizeObserver (same infra) |
| `onWindowScroll { ScrollEvent in }`, `onWindowResize { SizeEvent in }` | any Tag | wrapper effect; window listener owned by the runtime; rAF throttle |

- Typed payloads (`KeyEvent`, `ScrollEvent`, `SizeEvent`) extend the existing `EventPayloads.swift`.
- Custom event helpers: users extend `HTMLTag` with `.on(_:perform:)` (already public); custom compositional modifiers: `TagModifier`. Both are the documented extension points.

### 2.3 Observer infrastructure (new)

- `_AttributeBag` gains observe-request entries (visibility(threshold), size).
- The backend protocol gains attach/detach hooks for observers; DOMBackend creates the observer on mount and disconnects on unmount — same lifecycle discipline as event listeners (retained for page lifetime rules apply).
- MockBackend records observe-requests → native tests assert without a browser.

### 2.4 Naming note

`Button(onClick:)` stays as-is (init param, primary API). `.onTap` is a modifier available on any HTML tag. Docs state the relationship explicitly.

---

## 3. WebSession.shared

### 3.1 API

```swift
extension WebSession {
    @MainActor public private(set) static var shared: WebSession = .unsupported
    /// Called by platform entry points (DOM boot, StaticSite). Repeated calls
    /// overwrite silently (SSG and test runs bootstrap per generate; a dev
    /// reload is a fresh process).
    @MainActor public static func bootstrap(_ session: WebSession)
    /// Back to .unsupported. For tests and dev tooling.
    @MainActor public static func resetShared()
}
```

### 3.2 Rules

- Only platform entry points call `bootstrap`: DOM boot (browser) and StaticSite (SSG). It is the **same instance** seeded into `@Environment(\.webSession)`. Bare `Runtime.init` never touches the global → parallel native tests that construct runtimes don't race on shared state.
- Outside a configured environment every call throws `WebFetchError.unsupported` (existing environment-default behavior; no crashes).
- Validation and security unchanged: same `WebSession.validate` choke point, same same-origin credential policy in transports.
- Docs recipe: inject the session via initializer for unit-testable ViewModels; `WebSession.shared` is the app-code convenience. `@Environment(\.webSession)` remains and is unchanged.

---

## 4. Testing strategy

- **Native suites:**
  - TagModifier: identity stability, `@State` in modifiers survives re-render, `@Environment` reads, `_ModifierContent` substitution, double-use-of-content behavior pinned.
  - Built-in helpers: MockBackend asserts registered listeners / observe-requests / window effects; typed payload decoding.
  - WebSession.shared: bootstrap/reset/unsupported; repeated bootstrap overwrites silently (§3.1); environment and shared are the same instance.
- **WASM gate:** SwiftWUIDOM + examples build with `swift-6.3.3-RELEASE_wasm`.
- **Browser acceptance (manual checklist in the plan):** tap/hover/keyboard/scroll/visibility/size on a live page; fetch from a ViewModel via `WebSession.shared`; BridgeJS micro-benchmark before/after.

## 5. Phase order (implementation plan input)

1. BridgeJS spike (exit criterion §1.4) — first, so a failure doesn't block anything else.
2. TagModifier core (protocol, `ModifiedTag`, `_ModifierContent`, tests).
3. Built-in helpers: event-layer group, then observer infra, then window-level effects.
4. WebSession.shared.
5. BridgeJS migration proper (structural ops → fetch → typed arrays), micro-benchmark gate.
6. Docs: DocC for TagModifier + helpers, ViewModel networking recipe, BridgeJS regeneration rule.

## 6. Risks

| Risk | Mitigation |
|---|---|
| BridgeJS cross-package consumption unproven | Spike first with hard exit criterion (§1.4) |
| BridgeJS API instability (experimental) | Vendored `Generated/` pins behavior; regeneration is deliberate, reviewed |
| Typed event structs would regress dispatch perf | Kept out of scope by design — event layer stays dynamic |
| Observer lifecycle leaks (IntersectionObserver/ResizeObserver) | Same mount/unmount discipline as listeners; MockBackend asserts detach |
| Global `WebSession.shared` breaking test isolation | `bootstrap` only from platform entry points; bare Runtime never writes it; `resetShared()` for tests |
