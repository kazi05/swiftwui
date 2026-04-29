# SwiftWUI Architecture Review

Source under review: `Sources/` in worktree `modifiers-devserver`. Goal: best-in-class Swift web UI framework. Severity: P0 = blocks correctness/scale, P1 = real friction, P2 = polish.

## 1. Module boundaries — P1

`SwiftWUIRuntime` is a god-module: `Application` (lifecycle) + `DOMBridge` (FFI) + `DOMRenderer` (host adapter) + `Reconciler` (pure VDOM diff) + `StaticRenderer` (SSG) + `StyleSheetManager` (CSS injection). 408-line `DOMRenderer` mixes patch application, observer plumbing, typed-event marshalling, and CSS pre-registration. `Reconciler` is pure data; `DOMBridge` is FFI; mixing them prevents testing reconciliation natively without WASM.

Proposed split:
- `SwiftWUIVDOM` (pure, native-testable): `TagNode`, `Patch`, `ChildPatch`, `Reconciler`, `resolveTagBody`. No JSKit.
- `SwiftWUIRenderer` (protocol + host-agnostic): `Renderer` protocol, `Application`, observation loop, `RenderState`, animation context.
- `SwiftWUIDOMHost` (WASM only): `DOMBridge`, `DOMRenderer`, `StyleSheetManager`, observer creation, typed-event extractors.
- `SwiftWUISSR`: `StaticRenderer` + future streaming SSR.
- `SwiftWUICore` should NOT own `WebObserver`/`EventContexts` — those are DOM-specific. Move to a new `SwiftWUIWebPlatform` module; keep `SwiftWUICore` host-agnostic.

Migration: mostly mechanical file moves + `import` updates. No API surface change for users.

## 2. EventHandlerRegistry coupling — P0

```swift
public enum EventHandlerRegistry {
    nonisolated(unsafe) private static var handlers: [String: ...]
    public static func clear() { handlers.removeAll() }
}
```

Hazards: (a) global singleton clobbered by every render — multi-app/iframe/SSR-in-process is impossible; (b) `clear()` on every render then re-registering with new UUIDs causes O(n) churn and breaks identity-based diffing for events (every render produces a new `EventListenerID`, forcing `updateEventListeners` to fire even when handler is semantically identical); (c) leaks observer callbacks across re-mounts since they're keyed by `ObjectIdentifier` of `JSObject` while registry resets; (d) cross-thread when SwiftWUIDevServer (Vapor multi-threaded) lives in same process for SSR.

Proposed: replace global registry with an injected `EventDispatcher` owned by `Application`. Pass through render context. Use stable identity keyed by `(handlerCallSite, contentPath)` (capturing source-location hashes via `#filePath`/`#line` plus structural index) instead of UUID — so same handler at same site reuses ID, enabling correct event-listener diff.

Before:
```swift
let id = EventHandlerRegistry.register { closure() }
```
After:
```swift
@TaskLocal static var dispatcher: EventDispatcher?
let id = dispatcher.register(handler, identity: .siteHash(file: file, line: line))
```

Migration: invasive but contained (8 callsites). Eliminates `nonisolated(unsafe)` static state.

## 3. Tag → TagNode conversion — P1

`resolveTagBody<T: Tag>(_:)` is recursive and unconditional — re-walks the tree on every render with no memoization. Every `ModifiedContent` allocation makes a copy of `[TagNode]` and re-merges dictionaries. `OnChangeStorage` uses `UUID` keys regenerated per `OnChangeTag` instance — re-instantiating the tag (which happens on every render) regenerates the key, **breaking onChange detection across renders**. Same hidden bug in `TaskTag`: `EventHandlerRegistry.register` runs every render, re-firing `mount` repeatedly.

Proposed: introduce a `RenderContext` carrying a per-element identity path (component-type + structural index), used to key `OnChangeStorage`, `TaskTag` mount tracking, and event IDs. Make `toTagNodes` accept `(RenderContext) -> [TagNode]`. Lazy: skip subtrees whose backing `@State` is unchanged (memoization gate via observation deps).

Migration: P0 correctness fix for `.onChange`/`.task`. Add context param; old callsites get default ctx via overload.

## 4. State scope — P1

`@State` works (Observation-backed). `@Environment` uses **a single global `CurrentEnvironment`** — not tree-scoped. `.environment(_:)` modifier doesn't exist. `@ObservedObject` exists but no `@StateObject` (object owned by tag, surviving re-renders) — required for ViewModels. No event bus, no selectors, no derived state.

Proposed:
- `@StateObject` backed by same route-cache mechanism currently used for tag (extend `RenderState.cachedTag` to a per-component identity map of stored objects).
- Tree-scoped environment: thread `EnvironmentValues` through `RenderContext`; add `.environment(_:_:)` modifier writing into the subtree's env.
- Add `Selector<S, V>` type for derived state (memoized, equality-gated re-render trigger) — not required day 1 but high value.
- No event bus needed — Combine-style `Publisher` overlap with Observation.

## 5. Renderer abstraction — P1

`DOMRenderer` is hardcoded; `StaticRenderer` is parallel reimplementation of node walking. There is no `Renderer` protocol.

Proposed protocol:
```swift
public protocol Renderer {
    associatedtype Host
    func mount(_ tree: TagNode, in host: Host)
    func apply(_ patch: Patch, to host: Host, context: RenderContext)
}
```
Implementations: `DOMRenderer` (WASM), `StringRenderer` (SSR/SSG, replaces `StaticRenderer`), `TestRenderer` (snapshot + assertions for CI), `TUIRenderer` (terminal — future), `CanvasRenderer` (native — future). `Application` becomes generic over `Renderer`.

Migration: extract `Renderer` protocol; refactor `DOMRenderer` to conform. `StaticRenderer` deleted, `StringRenderer` uses same `applyPatch` semantics (no diff, just walk). One unified rendering pipeline.

## 6. Plugin architecture — P2

No extension points. Today, third-party tags work because they conform to `Tag` + `TagNodeConvertible`, but new modifier categories or renderer effects (e.g., SSR streaming, custom CSS-in-JS engine) cannot register without forking.

Proposed: `RenderPlugin` protocol with hooks `willRender`, `transformNode`, `didMount`. Register via `Application.use(_:)`. Examples: telemetry, devtools inspector, custom CSS engine, hydration adapter.

## 7. Lifecycle hooks — P1

`LifecycleEvent.{mount,unmount}` exist via `WebObserver`. `mount` fires synchronously during `createObservers`; `unmount` fires on `cleanupObservers(fireUnmount: true)`. Issues: (a) `mount` doesn't fire on first render through `render()` path — only when observers attach, which happens whenever `createDOMNode` is called, but `update()` doesn't go through `createDOMNode` for unchanged elements, so re-mounts after key change are missed when reused via patch; (b) re-render with same identity recreates registry IDs but keeps DOM, leaving stale `unmountCallbacks` map entries (memory leak — keyed by `ObjectIdentifier` of `JSObject`); (c) no `onAppear`/`onDisappear` for non-intersection-based "appeared in tree" — the worktree conflates IntersectionObserver disappearance with tree removal.

Proposed: separate `.onAppear`/`.onDisappear` (tree lifecycle) from `.onIntersect`/`.onDisappearViewport` (visibility). Drive lifecycle from `Reconciler` patch outputs (`createNode` → mount, `removeNode` → unmount), not observer plumbing.

## 8. Component identity — P1

`ForEach` requires `Identifiable` but `Reconciler.diffChildren` does **index-based diffing** — IDs are ignored. `data-swiftwui-id` only forces full replace on change; no key-based reordering. Inserting a row at the top discards all subsequent rows' state. The worktree's `.id()` modifier (referenced in attributes via `data-swiftwui-id`) only triggers replacement, not preservation.

Proposed: keyed reconciliation. When children carry `data-swiftwui-key` (or `Identifiable.id` propagated by `ForEach`), use Inferno/React-style key-matching diff (LIS-based reorder, preserving DOM nodes). Critical for list performance and `@State` continuity inside list items.

## 9. Testing architecture — P1

Tests appear to be unit-only (51 tests). Missing: snapshot rendering tests against `StringRenderer`; integration tests driving `DOMRenderer` against a JSDOM/headless via the DevServer; reconciler property-based tests (random tree → diff → apply → equality).

Proposed:
- `SwiftWUITesting` module with `TestRenderer`, `assertSnapshot(of: tag)`, `assertPatch(from: a, to: b)`.
- DevServer mode `swiftwui-dev test` that builds, serves, and runs Playwright/WebDriver. Reuse `WASMBuilder`.
- Native CI via pure-Swift tests — possible only after extracting VDOM module (item 1).

## 10. Error handling — P2

`Application.mount` swallows errors with `print`. `DOMBridge` calls force-unwrap (`localStorage.object!.getItem!`). Render errors propagate as `fatalError` (`Tag.body where Body == Never`). No error boundaries.

Proposed: `ErrorBoundary` tag that catches downstream render-time errors and shows fallback. Make `Renderer.apply` throwing; `Application` logs via injected `Logger` and renders fallback. Replace `bridge!` force-unwraps with `Result<JSValue, BridgeError>`.

## 11. Async — P1

`TaskModifier` is broken (item 3). No cancellation on unmount. No `.refreshable`. No `Suspense`/loading states. `task(id:)` overload missing (re-fires on id change).

Proposed: `TaskTag` becomes `(id: AnyHashable, priority: TaskPriority, action) -> async`. Stores `Task` handle in render context keyed by structural identity; cancels on unmount or id change. Add `AsyncContent { try await load() } loading: { Spinner() } error: { e in ... }` for Suspense semantics.

## 12. Forms — P1

`Form` is a thin HTML wrapper with no `@FormState`, no validation, no field-level Bindings, no submit-aggregation. Each `Input(oninput:)` is wired manually.

Proposed: `@FormState struct LoginForm { @Field var email = "" }` with derived `$form.email: Binding`, validation rules (`@Field(.email, .required)`), submit gathers values automatically. Build on existing `Binding`. P1 because forms are a primary web use case and missing abstractions push users to manual state plumbing.

## 13. Animation — P1

`Animation` is duration + timing-function — pure CSS transition wrapper. "Spring" is a cubic-bezier approximation, not physics. No phase animations, no keyframes, no scoped transitions for enter/exit.

Proposed: keep CSS-transition path but add `.transition(.opacity, .scale)` enter/exit animations driven by reconciler (insert with `opacity: 0 → 1`, remove deferred until transition end). Real spring via WAAPI (`element.animate()`) — JS-bridged. `PhaseAnimation { phase in ... }` driving CSS variables. CSS containment: do not regenerate `@media`-style classes per render — use deterministic hash (already started via `ResponsiveHash`) for animations too.

## 14. Routing — P1

`Router` is a flat list scanned linearly (`routes.first { $0.match(...) }`). `:param` only — no wildcards, no nested routes, no layout routes, no async data loaders, no guards. `goBack` is a stub.

Proposed: trie-based matcher; `Route("/users", layout: UserLayout()) { Route("/:id") {...} }` for nested layout routes; `loader: () async -> Data` per route returning awaited data via `LoaderContext.value`; `guard: () -> RouteResult` for redirects. Mirror TanStack Router or React Router 6 ergonomics. History API integration in `Application` rather than `Router` (separation: Router = matching, Application = history).

## 15. SSR/SSG + DevServer pipeline — P1

`StaticRenderer` (SSG, fragment HTML) and `SwiftWUIDevServer` (build + serve client-side WASM) currently don't talk. Production HTML template just bootstraps WASM — no pre-rendering, no hydration. There's no streaming SSR.

Proposed unified pipeline:
1. `swiftwui-dev dev` — current behavior plus optional `--ssr` flag pre-renders each route via `StringRenderer`, ships hydration-friendly HTML.
2. `swiftwui-dev build --mode {spa,ssg,ssr}` — single build matrix.
3. SSG: enumerate routes from `Router`, render each to static `.html`.
4. SSR: per-request render in Vapor handler, stream as suspense-boundaries resolve. Reuse `Renderer` abstraction (item 5) — `StringRenderer` works in both Vapor (SSR) and CLI (SSG).
5. Hydration: client's `DOMRenderer` adopts existing DOM instead of `removeAllChildren` — `render(_:hydrate: true)` matches existing tree to TagNode without recreating. Required for SSR.

## 16. API papercuts — top 5

P2 each:
1. **`@Environment` is global, not subtree-scoped** — fix per item 4. Before: `CurrentEnvironment.values.theme = .dark` (anywhere). After: `MyView().environment(\.theme, .dark)`.
2. **`Tag.body` `fatalError` for primitives** — replace with `Never` extension already present, but several internal types (`Link`, `NavigationStack`) declare `Body = Never` and rely on `TagNodeConvertible`. Document or remove dual-conformance pattern.
3. **`ForEach` requires `Identifiable`** — provide `ForEach(_:id:_:)` overload with KeyPath (item already has stub but no useful alternative init).
4. **Tuple `[(String, String)]` in `ModifiedContent`** — uses arrays of tuples to preserve order, then merges into dict in `toTagNodes`. Switch to `OrderedDictionary` (swift-collections) — same ordering, O(1) deduplication, fewer allocations.
5. **`.style("prop", "val")` lives next to typed `.padding(...)`** — keep but add `.style(.padding, .px(16))` typed-key overload to nudge users to typed API.

## 17. Naming: Tag vs View — P2

`Tag` is accurate (HTML-specific) but creates friction for SwiftUI devs. Recommend: **keep `Tag`** as the primitive (HTML element noun matches), expose `public typealias View = Tag` in umbrella module for SwiftUI muscle-memory. Same for `ViewModifier = TagModifier`. Don't rename internals; users get familiar surface.

## 18. Type erasure cost — P2

`AnyTag` uses `any Tag` existential — heap allocation per wrap. `Link.children: [AnyTag]`, `Route.builder: ([String:String]) -> AnyTag`. Hot paths.

Parameter-pack pattern (Swift 5.9+) is partly used in `TagBuilder.buildBlock`. Proposed: replace `[AnyTag]` aggregations with parameter-pack structs (`TagPack<each T>`) where the count is statically knowable. For genuinely heterogeneous storage (Router routes, dynamic ForEach), keep `AnyTag` but add `@inlinable` thin-wrapper init. Realistic gain: ~10–15% allocation reduction in tree construction. Defer until benchmarked.

## 19. DevServer architecture — P1

`SwiftWUIDevServer` uses Vapor for HTTP + WebSocket + a `fswatch`-spawned subprocess for file watching. Issues: (a) Vapor is overkill for a static file + WS endpoint — adds 30+ transitive deps and a Vapor Application booted per dev session; (b) `connectedClients: [WebSocket]` mutation is not synchronized — Vapor is multi-threaded, race condition on `append`/`removeAll`/`broadcast`; (c) no source map / position-preserving error reporting — shows stderr blob; (d) full page reload on every change instead of HMR; (e) `WASMBuilder.outputDirectory` hardcoded; (f) hot reload story: `location.reload()` works but loses runtime state — Vite-style HMR (preserve `@State`) would require shipping module-graph data.

Proposed:
- Replace Vapor with `Network.framework` + `Hummingbird` (lighter), or hand-rolled NIO. P2 unless dep-bloat matters.
- Make `connectedClients` actor-isolated.
- Parse Swift compiler output to overlay source-position errors (file:line:col + caret).
- HMR: on rebuild, send delta module; client re-imports JS module and re-runs `Application.mount(hydrate: true)` against existing DOM, preserving `@State` via render-state cache by route. Realistic v1: just preserve scroll + form state by snapshotting `localStorage`/DOM before reload.

## 20. Observer pattern — P1

`WebObserver` enum (intersection/resize/mutation/lifecycle) + `StateObserver` (the `observe` function) + `EventHandlerRegistry` are three parallel callback systems. Overlap: `lifecycle(.mount)` is fired by DOMRenderer manually, not by an actual JS observer. `observe()` re-registers itself recursively on every change.

Proposed unification: single `Observer` protocol with `subscribe(callback) -> Cancellable`. `WebObserver` cases become concrete implementations (`IntersectionObserverImpl`, `ResizeObserverImpl`, `LifecycleObserverImpl`). `observe()` becomes `StateObserverImpl`. Renderer holds `[ObjectIdentifier: [Cancellable]]` not `[ObjectIdentifier: [JSObject]]` — host-agnostic.

---

## Migration roadmap (prioritized)

| Phase | Work | Severity |
|---|---|---|
| 1 | Fix `OnChangeStorage`/`TaskTag` identity (item 3) — correctness bug | P0 |
| 1 | `EventHandlerRegistry` → injected dispatcher with stable identity (item 2) | P0 |
| 2 | Extract `SwiftWUIVDOM` (pure) + `Renderer` protocol (items 1, 5) | P1 |
| 2 | Keyed reconciliation in `ForEach` (item 8) | P1 |
| 2 | Tree-scoped `@Environment`, `@StateObject` (item 4) | P1 |
| 3 | Lifecycle from reconciler patches (item 7); unified Observer (item 20) | P1 |
| 3 | Async `.task(id:)` cancellation; Suspense (item 11) | P1 |
| 3 | Forms abstraction (item 12); routing rebuild (item 14) | P1 |
| 4 | SSR + hydration via unified renderer (item 15) | P1 |
| 4 | DevServer HMR + Hummingbird/NIO (item 19) | P1 |
| 5 | Plugin protocol (item 6); WAAPI animations (item 13); type-erasure perf (item 18) | P2 |

Projected outcome: ~40% smaller `DOMRenderer`, native-testable VDOM, correct lifecycle/onChange/task semantics, list state preserved across reorders, SSR/SSG/SPA from one binary, hot-reload that doesn't kill state. The framework moves from "working SwiftUI-clone" to "SwiftUI-class for the web".
