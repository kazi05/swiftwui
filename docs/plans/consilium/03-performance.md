# SwiftWUI Performance Audit

Date: 2026-04-28. Source-grounded review.

## Headline measurements

- **Counter.wasm = 61 MB (debug)** at `Examples/Counter/.build/plugins/PackageToJS/outputs/Package/Counter.wasm`. No release artifact present.
- **No release config.** Build commands all use `-c debug`. No `-Osize`, no `-wmo`, no `wasm-opt`, no strip.
- **Reconciler is positional, unkeyed.** `Reconciler.swift:131-145` walks `0..<max(old.count,new.count)` — prepending an item to a 1000-row list emits 1000 replace patches.
- **Every render reallocates closures.** `DOMRenderer.update():50` calls `EventHandlerRegistry.clear()`; `EventHandlerRegistry.register` returns fresh `UUID().uuidString` per handler; `Reconciler.diffEvents` compares strings, sees them as different, emits patches; `DOMBridge.setTrackedEventListener` removes old `JSClosure`, allocates new one. Bridge crossings scale with handler count *per state mutation*.
- **Existential-heavy hot path.** `[any Tag]` in `TupleTag.children`, `any Tag` in `AnyTag.storage`, `as? TagNodeConvertible` casts at `TagNodeConvertible.swift:25/76/119` on every render — WASM has no method dispatch caching.

---

## Top 5 wins, ranked by ROI

### 1. Ship release builds + `wasm-opt` + strip + drop Foundation (ROI: massive, effort: hours)

**What's slow.** 61 MB binary in dev. Even with brotli debug binary is 8–15 MB on wire. First paint waits on `fetch + compile + instantiate`. `DOMBridge.swift:8`, `StaticRenderer.swift:3`, `EventHandlerRegistry.swift:3` import Foundation purely for `UUID()` and `replacingOccurrences` — pulls ICU, locales, dates, regex (multi-MB).

**Measure.** `wc -c` post-release; `wasm-objdump -h` for section breakdown; Chrome DevTools Performance "Compile Module" timing.

**Fix.**
```bash
swift package --swift-sdk swift-6.2.3-RELEASE_wasm \
  -c release -Xswiftc -Osize -Xswiftc -wmo \
  -Xswiftc -gnone -Xswiftc -disable-reflection-metadata js
wasm-opt -Oz --strip-debug --strip-producers --converge \
  Counter.wasm -o Counter.opt.wasm
brotli -q 11 Counter.opt.wasm
```
Replace `UUID().uuidString` with monotonic `UInt64` counter. Replace `String.replacingOccurrences` with manual UTF-8 walk. Drop `import Foundation` from those three files.

**Expected.** 61 MB → ~1–3 MB → 300–900 KB on wire. First paint ~10x faster on real networks.

---

### 2. Pool/reuse JSClosures, stop clearing registry every render (ROI: high, effort: 1 day)

**What's slow.** `DOMRenderer.update():50` clears registry. New UUIDs per handler → `Reconciler.diffEvents` sees every event as new → `DOMBridge.setTrackedEventListener` removes/recreates `JSClosure`. Each `JSClosure` allocation crosses JS/WASM boundary, allocates `Function` in JS heap, indexes swift retain table. 100-button list = 100 closures rebuilt per state tick.

**Fix.** Two layers:

a) **Stable IDs.** Monotonic per-render counter, reset (not cleared):
```swift
public enum EventHandlerRegistry {
    nonisolated(unsafe) private static var handlers: [String: @Sendable () -> Void] = [:]
    nonisolated(unsafe) private static var counter: UInt64 = 0
    public static func beginRender() { counter = 0 }   // do NOT clear handlers
    public static func register(_ h: @escaping @Sendable () -> Void) -> EventListenerID {
        counter &+= 1
        let id = "h\(counter)"
        handlers[id] = h
        return EventListenerID(id)
    }
}
```
Identical body shapes now produce identical IDs. `Reconciler.diffEvents` returns no-op. Closures stay attached.

b) **JSClosure pool.** `[String: (JSClosure, Box<()->Void>)]` in `DOMBridge`. On re-register, swap Swift handler inside existing closure's box rather than rebuilding `JSClosure`.

**Expected.** Re-renders skip event listener patches entirely. State tick on 100-item list: 100 fewer JS↔WASM crossings.

---

### 3. Keyed reconciliation for ForEach + batch DOM writes (ROI: high, effort: 2-3 days)

**What's slow.** `Reconciler.diffChildren` is positional. Inserting at head of N children emits N replaces. `applyPatch` crosses JS boundary per child via `bridge.childNode(element, at: index)` — three property reads (`childNodes`, `[index]`, `.object`) per child every time. `ForEach` requires `Identifiable` but never propagates `id` into TagNode.

**Fix.**

a) Add `key: String?` to `TagNode.Element`.

b) Make `ForEach` `TagNodeConvertible`:
```swift
extension ForEach: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        data.flatMap { item -> [TagNode] in
            let id = String(describing: item.id)
            return resolveTagBody(content(item)).map { node in
                if case .element(var el) = node { el.key = id; return .element(el) }
                return node
            }
        }
    }
}
```

c) `diffChildren` performs keyed LIS reordering (Vue 3 / Inferno / Solid algorithm). One `.reorderChildren(moves:)` patch.

d) **Batch DOM writes.** `DOMRenderer` keeps parallel `[JSObject]` array indexed identically to virtual children → position lookup = Swift array access (zero JS calls). Use `DocumentFragment` for batch insert.

**Expected.** O(n) → O(n log n) keyed; 1000-row prepend ~3000 boundary crossings → ~5. Visible jank → sub-ms.

---

### 4. Eliminate full-tree rebuild — fine-grained reactivity (ROI: high, effort: 4-7 days)

**What's slow.** `Application.swift:63` wraps *entire* renderCycle in `withObservationTracking`. Mutating any `@State` triggers full `resolveTagBody` over whole route. `resolveTagBody` does `as? TagNodeConvertible` on every node (existential cast through PWT — slow in WASM, no inline caching).

**Fix.**

a) **Cheap.** Memoize per-component. Cache rendered `[TagNode]` keyed on component's `StateStorage` identity. Invalidate only when *that* component's tracked properties fire. Hoist `withObservationTracking` from route level down to per-component level.

b) **Real fix.** Signal-based fine-grained updates (Solid/Preact Signals). Modifiers like `.style(prop, value)` accept reactive expressions. Each modifier installs one-shot DOM mutation subscription on `createDOMNode`. Steady-state updates skip diff entirely — direct `bridge.setStyle` writes. Keep TagNode for initial render and structural changes only.

**Expected.** (a) 50–80% fewer body calls. (b) constant-time updates on point mutations regardless of tree size.

---

### 5. Batch JS-Swift bridge calls + drop existentials in hot path (ROI: medium-high, effort: 2 days)

**What's slow.** Every DOM op is one bridge call. Creating `Div` with 4 styles + 2 classes + 3 children = ~15 boundary crossings. JavaScriptKit per-call overhead ~1–2 µs. `TupleTag.children: [any Tag]` and `AnyTag.storage: any Tag` re-pay existential dispatch on every render.

**Fix.**

a) **Batch via JS-side interpreter.** Encode patches into `Uint8Array` (op codes + offsets), call single `applyPatches(rootEl, ops)` JS function once per render. One boundary crossing per render instead of dozens.

b) **Pre-flatten TupleTag at build time.**
```swift
public struct TupleTag: Tag, TagNodeConvertible {
    let nodes: [TagNode]
    public init<each T: Tag>(_ tags: repeat each T) {
        var n: [TagNode] = []
        repeat n.append(contentsOf: resolveTagBody(each tags))
        self.nodes = n
    }
    public func toTagNodes() -> [TagNode] { nodes }
}
```
Eliminates per-render existential dispatch over `[any Tag]`.

c) **Adjacent fix.** `DOMBridge.removeAllChildren` sets `innerHTML = ""` — leaks `closures` dict entries. Use `replaceChildren()` with explicit listener cleanup.

**Expected.** ~5–10x fewer bridge crossings during update. Major win for list-heavy apps.

---

## Other findings

**Startup latency.** `instantiate.js:115` already uses `WebAssembly.instantiateStreaming` (good). But `Examples/Counter/index.html:11` does `await init()` synchronously inside only `<script>` and has no preload hint. Add `<link rel="preload" href="/Counter.wasm" as="fetch" type="application/wasm" crossorigin>` in `<head>`. Don't `await` at top level — render skeleton synchronously, hydrate when wasm resolves.

**StyleSheetManager perf bug.** `DOMBridge.appendCSSRule:290` does `current = textContent; textContent = current + "\n" + rule` — quadratic concat. Switch to `styleElement.sheet.insertRule(rule, sheet.cssRules.length)` for O(1).

**Redundant CSS hash work.** `Reconciler.diffElements:94-95` calls `responsiveClassNames(for:)` twice and computes FNV hash twice. Cache `[ResponsiveStylesKey: String]` in `Reconciler` or `ResponsiveHash`.

**Tree-shaking.** Umbrella `SwiftWUI` re-exports all 8 modules. Counter doesn't need Router or Browser but still pays. Add `SwiftWUIMinimal` (Core + HTML + Styles + State + Runtime). Apps opt into Router/Browser/Page explicitly.

**Memory.** `EventHandlerRegistry.handlers` dict + `DOMBridge.closures` dict can drift out of sync — fix #2 unifies them. Verify `JSClosure` retention paths via Chrome heap snapshot.

**Reflection metadata.** `-disable-reflection-metadata` cuts another 5–15%. Combine with `-gnone`.

**Embedded Swift.** Long-term R&D. No Foundation, no reflection, no existentials. Counter could plausibly hit <100 KB. Requires removing `any Tag` everywhere, replacing with parameter packs throughout. `@Observable` not yet supported in Embedded mode. Treat as 2026-Q3.

**SSR + hydration.** `StaticRenderer.swift` already produces full HTML. Pair with Vapor server (already in worktree as `SwiftWUIDevServer`): render server-side, ship HTML with `data-swui-id`, wasm hydrates over it. Sub-100ms FCP regardless of wasm size.

**Profiling tooling.**
- Chrome DevTools Performance with WASM profiling enabled (chrome://flags).
- `wasm-objdump -h Counter.wasm` for section breakdown.
- Add `internal func mark(_ label: String)` calling `performance.mark` via `JSObject.global.performance` — sprinkle in `render`, `update`, `applyPatch`.
- `npx vite-bundle-visualizer` for JS side.
- Lighthouse CI with wasm-aware budget.

**Lazy loading per route.** Per-route wasm modules require splitting into separate executable targets sharing SwiftWUI as static dep, lazy-fetched on `Router.navigate`. Defer until binaries cross 500 KB.

---

## Quick wins checklist

1. Release build + `-Osize -wmo` + `wasm-opt -Oz` + brotli → 61 MB → ~1 MB.
2. Replace `UUID()` with monotonic counter; pool `JSClosure`.
3. Drop `import Foundation` from `DOMBridge`, `StaticRenderer`, `EventHandlerRegistry`.
4. `StyleSheetManager`: `sheet.insertRule`; cache `responsiveClassName` results.
5. Pre-flatten `TupleTag` in `init`; drop existentials at render time.
6. `<link rel="preload" as="fetch" type="application/wasm">` in `index.html`.
7. Stop `EventHandlerRegistry.clear()` per render — reset counter only.
8. Cache `responsiveClassNames(for:)` in `Reconciler.diffElements`.

Items 1–3 alone should land first paint under 1s on cold 3G and remove per-render closure-allocation cliff.
