# SwiftWUI Consilium Roadmap

Date: 2026-04-28. Synthesis of 6 expert reports.

Source reports:
- [`01-swift-language.md`](01-swift-language.md) — Swift 6.x features (macros, packs, ~Copyable, Embedded, @WebMain)
- [`02-web-trends.md`](02-web-trends.md) — modern web framework patterns (signals, Islands, RSC, View Transitions)
- [`03-performance.md`](03-performance.md) — perf wins (release build, JSClosure pool, keyed reconciler)
- [`04-architecture.md`](04-architecture.md) — system design (P0 bugs, module split, Renderer protocol)
- [`05-frontend-features.md`](05-frontend-features.md) — production gaps (forms, SSR, routing, a11y)
- [`06-infrastructure.md`](06-infrastructure.md) — CI/CD, build pipeline, hosting, distribution

## Verdict

Worktree `modifiers-devserver` adds substantial value (Vapor dev server, typed events, lifecycle, observers, .task, .onChange, .id). But three correctness bugs silently break those features, and 61MB debug WASM blocks any production claim. Foundation needs surgical fix, then framework is positioned to outclass Tokamak as the only Swift→Web framework with SSR, signals, and Embedded mode on roadmap.

---

## Phase 0 — Correctness fixes (P0, this week)

These bugs make worktree features silently wrong. Fix before merging worktree to master.

| # | Bug | Source | Fix |
|---|-----|--------|-----|
| 0.1 | `OnChangeStorage.key = UUID()` regenerated per render → `.onChange` never fires across renders | [04 §3](04-architecture.md#3-tag--tagnode-conversion--p1) | Key by `RenderContext` (component-type + structural index) |
| 0.2 | `TaskTag` re-registers `mount` callback per render → `.task` re-fires on every state change | [04 §3](04-architecture.md), [04 §11](04-architecture.md) | Same `RenderContext` keying + cancel-on-unmount |
| 0.3 | `EventHandlerRegistry.clear()` per render → fresh `EventListenerID` every render forces listener replacement | [04 §2](04-architecture.md), [03 §2](03-performance.md) | Stable IDs via `(file, line, structural-path)` hash; do NOT clear, reset counter only; pool `JSClosure` |
| 0.4 | DOM `removeAllChildren` via `innerHTML = ""` leaks `closures` dict | [03 §5c](03-performance.md) | `replaceChildren()` + explicit listener cleanup |
| 0.5 | `connectedClients` in `DevServer` not synchronized — Vapor multi-thread race | [04 §19](04-architecture.md), [06 §2](06-infrastructure.md) | Wrap in actor or NIO `EventLoopGroup`-pinned dispatch |

**Effort total: 2-3 days.** Without these, worktree merge ships with regressions.

---

## Phase 1 — v0.1.0 release blockers (next sprint)

Ship a real `0.1.0` tag. Target: working dev/build pipeline + CI.

### 1A. Build pipeline
[06 §1](06-infrastructure.md), [03 §1](03-performance.md)

- Release flags: `-Osize -wmo -gnone -disable-reflection-metadata` to `WASMBuilder` release path.
- `wasm-opt -Oz --strip-debug --strip-producers --converge`.
- Brotli `-q 11` + gzip `-9` parallel outputs.
- SHA-384 SRI emission.
- Drop `import Foundation` from `DOMBridge.swift`, `StaticRenderer.swift`, `EventHandlerRegistry.swift`. Replace `UUID()` with monotonic `UInt64`, `replacingOccurrences` with manual UTF-8 walk.
- `Makefile` at root with `dev`/`build`/`release`/`test`/`clean` targets.

**Expected: 61MB → ~1MB → 300-900KB on wire.** Single biggest perf win.

### 1B. Unified CLI
[06 §3](06-infrastructure.md)

- Merge `swiftwui-init` + `swiftwui-dev` into single `swiftwui` binary using `swift-argument-parser`.
- Subcommands: `init`, `dev`, `build`, `test`, `deploy`, `doctor`.
- Drop hand-rolled `CLI.swift:29-81` parser.

### 1C. Drop dual dev server
[06 §2](06-infrastructure.md)

- Remove Vite from `Templates.packageJSON` (`Templates.swift:121-139`). Vapor `swiftwui-dev` is the canonical pipeline.
- Update `swiftwui init` next-steps output to `swiftwui dev`.
- Vite stays as opt-in `--mode vite` for advanced users.

### 1D. CI
[06 §4](06-infrastructure.md)

- `.github/workflows/ci.yml` — macOS + Linux matrix, SPM cache, WASM SDK cache, `swift test --parallel`, lint via `swift format`.
- `.github/workflows/wasm-build.yml` — release Counter, size budget gate (`<512KB brotlied`).
- `.github/workflows/release.yml` — tag-driven binary release.
- `.github/workflows/docs.yml` — DocC deploy to GitHub Pages.

### 1E. Hot reload protocol
[06 §7](06-infrastructure.md)

- Better WS protocol: send manifest with hashes, only reload on `.wasm` change.
- File-change debounce 0.3s → 0.5s after first reload.
- Defer state preservation (P2).

**v0.1.0 effort: 1-2 weeks.** Makes the framework production-installable.

---

## Phase 2 — v0.2.0 architectural foundation (1 month)

Refactor before adding more features. Locks in extensibility.

### 2A. Module split
[04 §1](04-architecture.md), [04 §5](04-architecture.md)

```
SwiftWUIVDOM      → TagNode, Patch, ChildPatch, Reconciler, resolveTagBody (pure, native-testable)
SwiftWUIRenderer  → Renderer protocol, Application, observation loop, RenderState
SwiftWUIDOMHost   → DOMBridge, DOMRenderer, StyleSheetManager, JS observers (WASM-only)
SwiftWUISSR       → StringRenderer (replaces StaticRenderer), streaming SSR
SwiftWUIWebPlatform → WebObserver, EventContexts, WebEventTypes (DOM-specific, off Core)
```

Migration: file moves + `import` updates. No public API change.

### 2B. Renderer protocol
[04 §5](04-architecture.md)

```swift
public protocol Renderer {
    associatedtype Host
    func mount(_ tree: TagNode, in host: Host)
    func apply(_ patch: Patch, to host: Host, context: RenderContext)
}
```

Implementations: `DOMRenderer` (WASM), `StringRenderer` (SSR/SSG, replaces `StaticRenderer`), `TestRenderer` (snapshot CI). `Application` becomes generic over `Renderer`.

### 2C. Keyed reconciliation
[03 §3](03-performance.md), [04 §8](04-architecture.md)

- Add `key: String?` to `TagNode.Element`.
- `ForEach: TagNodeConvertible` propagates `Identifiable.id`.
- `Reconciler.diffChildren` switches to LIS-based keyed reorder (Vue 3 / Inferno algorithm).
- `applyPatch` adds `.reorderChildren(moves:)` patch type.
- Parallel `[JSObject]` array in `DOMRenderer` indexed identically to virtual children → zero JS for position lookup.

**Expected: 1000-row prepend ~3000 boundary crossings → ~5.** Critical for list state preservation.

### 2D. JSClosure pool
[03 §2](03-performance.md), [04 §2](04-architecture.md)

- Stable IDs via render-context (Phase 0.3).
- `DOMBridge` keeps `[String: (JSClosure, Box<()->Void>)]`. Re-register swaps Swift handler inside existing closure's box; never reallocates `JSClosure`.

### 2E. Tree-scoped environment + @StateObject
[04 §4](04-architecture.md)

- Thread `EnvironmentValues` through `RenderContext`.
- Add `.environment(_:_:)` modifier writing into subtree env.
- `@StateObject` backed by route-cache (extend `RenderState.cachedTag` to per-component identity map).

### 2F. Lifecycle from reconciler
[04 §7](04-architecture.md)

- Drive `.onAppear`/`.onDisappear` from reconciler patch outputs (`createNode` → mount, `removeNode` → unmount).
- Separate from `.onIntersect`/`.onDisappearViewport` (visibility).

### 2G. Error boundaries
[05 §18](05-frontend-features.md), [04 §10](04-architecture.md)

```swift
ErrorBoundary { CrashyView() } fallback: { err, retry in ... } onError: { err, info in ... }
```

Top-level boundary in `Application.mount` catches render errors; surfaces in dev overlay.

**v0.2.0 effort: 2-3 weeks.** Architecture solid, all subsequent work compounds.

---

## Phase 3 — v0.3.0 production features (6 weeks)

Make it usable for real apps.

### 3A. Async + Suspense
[05 §2](05-frontend-features.md), [04 §11](04-architecture.md)

```swift
AsyncBoundary(loading: { Spinner() }, error: { e in ErrorView(e) }) {
    let user = useResource(key: "user/\(id)") { signal in
        try await api.fetchUser(id, signal: signal)
    }
    UserCard(user: user)
}
```

`AsyncResource` wraps `Task` + `JSObject.global.AbortController`. `useResource` keyed cache (SWR-style) in `EnvironmentValues`. Cancel on unmount via `lifecycle(.unmount)`.

### 3B. Forms
[05 §1](05-frontend-features.md), [04 §12](04-architecture.md), [05 §7](05-frontend-features.md)

- `FormState<Schema>` with `bind`, validation, submit.
- Typed input components: `TextField`, `SecureField`, `Toggle`, `Picker`, `DatePicker`, `Stepper`, `Slider`, `ColorPicker` over existing `Input`/`Select`/`Textarea`.
- Server actions: `Form(action: "/api/signup", method: .post)` — progressive enhancement.

### 3C. Routing
[05 §4](05-frontend-features.md), [04 §14](04-architecture.md), [02 §10](02-web-trends.md)

- Nested layouts: `Route("/", layout: RootLayout) { Route("dashboard") { ... } }`.
- Route loaders: `loader: () async -> Data`, parallel `TaskGroup`, results via `EnvironmentValues`.
- Route guards: `.guard { ctx in ctx.user != nil ? .allow : .redirect("/login") }`.
- `@QueryParam` property wrapper backed by `URLSearchParams`, observable.
- Trie-based matcher replacing linear scan. History API in `Application`.

### 3D. SSR + hydration
[05 §3](05-frontend-features.md), [04 §15](04-architecture.md), [02 §4](02-web-trends.md)

- Streaming SSR via Vapor: `app.get(streaming:)` chunked `text/html`.
- `data-swui-h` markers on stateful tags during SSR.
- `<script id="__swui_state__" type="application/json">` initial state snapshot.
- Client `Application.hydrate(rootID:)` matches DOM to TagNode without recreating.
- `swiftwui build --mode {spa,ssg,ssr}` matrix.

### 3E. Theme + dark mode
[05 §11](05-frontend-features.md), [02 §15](02-web-trends.md)

```swift
struct AppTheme: Theme {
    static let light = AppTheme(...)
    static let dark = AppTheme(...)
    let bg, fg, accent, danger: CSSColor
}
ThemeProvider(.system) { ContentView() }
.background(.token(\.bg))  // → var(--bg)
```

`StyleSheetManager` emits `:root { --bg: ... }` + `[data-theme=dark] { --bg: ... }`. Persist via existing `AppStorage`.

### 3F. Accessibility
[05 §12](05-frontend-features.md), [02 §9](02-web-trends.md)

- Typed ARIA modifiers over `.attribute()`: `.aria(label:)`, `.aria(role:)`, `.aria(live:)`.
- `@FocusState` + `.focused()` via `JSObject.global.document.activeElement`.
- `LiveRegion(.polite) { Text(announcement) }`.
- `Image(src: String, alt: String)` — required parameter (compile-time enforcement).

### 3G. View Transitions API
[02 §6](02-web-trends.md), [05 §5](05-frontend-features.md)

- `DOMBridge.startViewTransition` wrapper.
- Wrap update path's `renderCycle()` in `bridge.startViewTransition`.
- `.viewTransitionName(String)` modifier.
- `withTransition(.crossfade) { router.navigate(...) }`.

### 3H. Overlays
[05 §13](05-frontend-features.md)

- `OverlayHost` mounted at app root via portal (`document.body`).
- `.sheet(isPresented:detents:)`, `.alert`, `.popover` modifiers.
- Focus-trap utility, `<dialog>` element where supported, `Esc` to dismiss.

**v0.3.0 effort: 6-8 weeks.** Framework now ships real apps.

---

## Phase 4 — v0.4.0 dev experience (2-3 weeks)

### 4A. Source maps Swift→WASM
[06 §8](06-infrastructure.md)

- Keep DWARF in dev (no strip).
- `swiftwui build --source-map`: copy `Sources/` to `dist/_sources/`, emit `Counter.wasm.map`.
- Document Chrome C/C++ DevTools extension in `swiftwui doctor`.

### 4B. Runtime error overlay
[06 §9](06-infrastructure.md)

- `window.onerror` / `unhandledrejection` → overlay.
- WASM trap stack via DWARF.
- WASI `proc_exit` non-zero → overlay with stderr.

### 4C. Component inspector
[05 §19](05-frontend-features.md)

- `data-swui-loc="File.swift:42"` in dev builds.
- Click in browser inspector opens source via `vscode://file/...` URI.

### 4D. State preservation HMR
[06 §7 stage 3](06-infrastructure.md)

- Snapshot `StateStorage` to `sessionStorage` before reload, rehydrate on mount.
- `Codable` constraint on stored values.
- Behind `--preserve-state` flag.

### 4E. Macro infrastructure
[01 §1](01-swift-language.md), [01 §13](01-swift-language.md)

- `@HTMLElement("div")` member+extension macro generating `HTMLTag` conformance.
- WHATWG codegen build plugin reading `Resources/whatwg-elements.json`, emitting all 100+ HTML5 elements with typed attributes.

---

## Phase 5 — v0.5.0+ optimization (4 weeks)

### 5A. @WebMain global actor
[01 §9](01-swift-language.md)

- Define `@globalActor WebMain`.
- Mark `EventHandlerRegistry`, `OnChangeStorage`, all `EventContext`s isolated to `@WebMain`.
- Removes ~80 lines of `#if !arch(wasm32)` NSLock branches.
- On WASM compiles to no-op (single thread).

### 5B. Parameter packs in TupleTag
[01 §5](01-swift-language.md), [01 §4](01-swift-language.md)

```swift
public struct TupleTag<each Child: Tag>: Tag, TagNodeConvertible {
    public let children: (repeat each Child)
}
```

Eliminates per-child existential boxing. `buildPartialBlock` for monomorphic dispatch. -10-20% render time.

### 5C. ~Copyable JS observers
[01 §7](01-swift-language.md)

- `OwnedJSObserver: ~Copyable` for unique JS observer handles.
- `consuming func disconnect(via: DOMBridge)`.
- Compiler enforces single-ownership; eliminates leak class.

### 5D. Span<T> reconciler
[01 §8](01-swift-language.md)

- Reconciler children diff via `Span<TagNode>` borrow-only iteration.
- Buffer-pooled `OutputSpan<ChildPatch>`.
- -20-40% reconciliation time.

### 5E. CSS innovations
[02 §7](02-web-trends.md)

- Container Queries: extend `MediaQuery` enum cases.
- Cascade Layers: replace `!important` with `@layer utilities { }` wrapping in `cssRuleText`.
- `StyleSheetManager`: `sheet.insertRule` instead of quadratic textContent concat.

### 5F. Performance budgets
[06 §13](06-infrastructure.md)

- Lighthouse CI as PR gate. Budgets: FCP <1.5s, TTI <3s, total bytes <600KB.
- `pkgsize` PR comment for bundle-size diff.

---

## Phase 6 — Long-term moonshots

### 6A. Embedded Swift mode (~10x binary reduction)
[01 §12](01-swift-language.md), [03 Embedded](03-performance.md)

- Carve out `SwiftWUIEmbedded` core compiling in `--embedded` mode.
- `EmbeddedState` closure-based reactivity (no `@Observable`).
- Replace `[String: ...]` with linear-scan tuple arrays in hot paths.
- Counter target: <100KB. Differentiator vs Tokamak.

### 6B. Signal-based fine-grained reactivity
[02 §1](02-web-trends.md), [03 §4](03-performance.md)

- Opt-in `@SignalState` for leaf components.
- `SignalNode` with stable DOM ref + render closure.
- `withObservationTracking` `onChange` targets specific `SignalNode`s instead of global render cycle.
- Constant-time updates regardless of tree size.

### 6C. Islands architecture
[02 §3](02-web-trends.md)

- `Island<Content>(strategy: .visible)` boundary tag.
- Per-island WASM bundles via separate executable targets.
- `IntersectionObserver`-driven on-demand loading.

### 6D. Resumability (Qwik model)
[02 §2](02-web-trends.md)

- Serialize `StateStorage` + event handler closures into HTML.
- `mountResumable()` skips initial render, attaches listeners by walking DOM.
- Defer WASM load until first interaction.

### 6E. Web Workers
[05 §14](05-frontend-features.md)

- `WebWorker<API>` typed proxy generated by macro (Comlink-style).
- Two WASM instances + `postMessage` bridge.
- Practical concurrency until WASM threads ship in browsers.

### 6F. PWA / Service Worker
[05 §15](05-frontend-features.md)

- `ManifestBuilder` DSL → `manifest.webmanifest`.
- `ServiceWorker.register(strategy: .networkFirst([...]))`.
- Push notifications via VAPID.

### 6G. DevTools browser extension
[02 §13](02-web-trends.md), [05 §19](05-frontend-features.md)

- `window.__swiftwui_devtools` global in debug builds.
- Component tree, state inspector, time-travel via stored `TagNode` snapshots.

---

## Cross-cutting recommendations

### Naming
[04 §17](04-architecture.md)

Keep `Tag` as primitive (HTML-accurate) but expose SwiftUI muscle-memory aliases in umbrella:
```swift
public typealias View = Tag
public typealias ViewModifier = TagModifier
```

### Distribution
[06 §5](06-infrastructure.md)

- Homebrew tap `homebrew-swiftwui/swiftwui.rb` — prebuilt CLI binary.
- Docker `ghcr.io/<org>/swiftwui-builder:6.2.3` for CI.
- npm `@swiftwui/cli` postinstall wrapper for JS-first teams.
- `.swift-sdk-version` pin file at repo root.

### Hosting
[06 §10](06-infrastructure.md)

Cloudflare Pages default. Critical headers:
```
/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000, immutable
  Cross-Origin-Resource-Policy: same-origin
```
Hash-fingerprint output filenames (`Counter.${sha256:8}.wasm`).

### Security
[06 §19](06-infrastructure.md)

- SwiftWasm SDK SHA pin.
- SRI on served WASM.
- Dependabot for `Package.resolved` + Actions.
- OSV-Scanner in CI.

---

## Effort summary

| Phase | Scope | Effort | Outcome |
|---|---|---|---|
| 0 | Correctness P0 bugs | 2-3 days | Worktree mergeable |
| 1 | v0.1.0 release pipeline | 1-2 weeks | Production-installable |
| 2 | v0.2.0 architecture | 2-3 weeks | Locked-in extensibility |
| 3 | v0.3.0 features | 6-8 weeks | Ships real apps |
| 4 | v0.4.0 dev experience | 2-3 weeks | Polished daily UX |
| 5 | v0.5.0 optimization | 4 weeks | Best-in-class perf |
| 6 | Moonshots | quarters | Differentiators |

Total to v0.4.0 stable: ~3 months engineering. To v0.5.0 + Embedded mode + signals: ~6 months. After 6 months, SwiftWUI is positioned as the only Swift-first web framework with SSR, fine-grained reactivity, Embedded-mode (<100KB), and View Transitions — features Tokamak does not have.

## Top 3 actions this week

1. Fix Phase 0 bugs (`OnChangeStorage`, `TaskTag`, `EventHandlerRegistry` identity).
2. Land Phase 1A release pipeline (`Makefile`, `-Osize`, `wasm-opt`, brotli, drop Foundation imports).
3. Land Phase 1D CI (`ci.yml` macOS+Linux matrix, SPM cache, size budget gate).

After those three, worktree is mergeable to master and the framework has a viable v0.1.0 path.
