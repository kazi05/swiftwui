# SwiftWUI

Swift web UI framework: SwiftUI-inspired declarative API compiled to WebAssembly. Build websites in pure Swift — `Tag` protocol (analog of SwiftUI's `View`), `@TagBuilder` result builder, `@State` reactivity, DOM via JavaScriptKit.

## Project status

**v2 clean-slate rewrite in progress** on `feature/fable-new-vision`. The working tree was deliberately emptied on 2026-07-02 (commit "Clear for empty"). The full v1 implementation (8 modules, 51 tests, Showcase site) lives on branch `master` — **reference material only**: known bugs, WASM workarounds, audited security code. Do not port v1 code wholesale; re-derive per the spec.

- Phase 1 spec (approved design): `docs/superpowers/specs/2026-07-02-phase1-core-design.md`
- Roadmap: 7 phases (core slice → reactivity → styles → routing → full HTML/SSG → toolchain/CLI → docs site). Each phase gets its own brainstorm + spec before implementation.

## Core architecture (v2, phase 1)

- **Two modules only:** `SwiftWUI` (renderer-agnostic core, zero deps, builds natively) and `SwiftWUIDOM` (JavaScriptKit backend, WASM).
- **SwiftUI-style API:** protocols + structs, value semantics. No class inheritance. `struct Counter: Tag { @State …; var body: some Tag { … } }`, `@main struct App: App`.
- **Hybrid tag style:** uppercase tag names, HTML attributes as typed init params: `Div(class: "x") { H1("Hi"); Button("+") { count += 1 } }`.
- **VDOM + structural identity in the tree:** `Node` enum (text/element/component), `NodeIdentity` = typed segment path (`child/branch/keyed/type`). Identity is part of the tree, never a side table — v1's biggest failure was retrofitted identity.
- **State:** `@State` → Slot → StateBox; `StateStore` keyed by `NodeIdentity`; graft before `body` evaluation; didSet invalidation; **no Observation in phase 1**.
- **Events:** closures in a `ListenerRegistry` keyed by `ListenerID(owner: identity, event)`; DOM listeners do fire-time lookup — zero listener churn on re-render.
- **Explicit `ResolveContext` parameter** — no TaskLocal, no globals, no Sendable in the pipeline. Everything `@MainActor`.
- **Escaping:** single `HTMLEscaping` choke point, serializer-only. Port from v1 verbatim (audited).
- **Reactive env signals (phase 8a):** `EnvironmentSignals` (@Observable, per-Runtime) → computed `EnvironmentValues` keys; tracked ONLY when read inside a component `body` — primitive/_resolve/handler reads get no auto re-render (locale in 8c uses `markDirty(.root)` instead). New signals follow the Writer-closure recipe in EnvironmentSignals.swift.
- **Web storage:** `@AppStorage`/`@SceneStorage` share one observable box per key; plaintext + origin-readable — never store secrets. `__swiftwui.` key prefix reserved.
- **PWA (opt-in):** `swiftwui init --pwa` / `swiftwui pwa init` scaffold user-owned manifest+icons+sw.js; build/ssg regenerate `dist/sw-assets.js` (SHA-256 precache manifest, `sw-assets.js` is a reserved name); update surfaced via `\.appUpdateAvailable` + `\.reloadToUpdate`; SW never registers in dev. Per-route ssg prerenders are never precached (SEO artifact only).
- **TagModifier:** compositional `ViewModifier` analog; `ModifiedTag` is a component boundary (@State/@Environment work, Styled scope preserved); event modifiers are HTMLTag-only, window-level effects Tag-wide.
- **CSS keyframes:** `Keyframes` is a value attached at the use site via `.animation(_:duration:…)` (all three style paths); `PendingStyleRule.keyframes` carries it and the two existing rule-registration loops call `registerRaw`. Hash-suffixed CSS name (dedup + no name collisions), gated on `@media (prefers-reduced-motion: no-preference)` unless opted out. No `App.keyframes`, no boot plumbing. Orthogonal to the WAAPI engine.
- **View transitions:** opt-in, native same-document VT API. Navigation/`withViewTransition` flushes commit inside `backend.performViewTransition` (old frame is captured before the update callback), serialized by `vtInFlight` with an idempotent `ran` guard + deferred tail flush; `_disableViewTransitions` for builds. `.matchedTransition(id:)` = one `view-transition-name` inline declaration (3 style surfaces); `root`/`-ua-` rejected. Presets → `registerRaw` CSS keyed on `<html data-swui-vt/data-swui-nav>`; NEVER set `animation-name` on `::view-transition-group()` (deletes the UA morph). Exits are suppressed on VT flushes via `beginExit`'s `suppressTransitions` guard. FLIP fallback lives entirely in `DOMBackend` (`?swui-vt=flip`).
- **BridgeJS:** SwiftWUIDOM structural DOM ops use vendored BridgeJS bindings (`bridge-js.global.d.ts` → committed `Generated/`, regen via `swift package plugin --allow-writing-to-package-directory bridge-js --target SwiftWUIDOM`; one-time `npm install` inside `.build/checkouts/JavaScriptKit/Plugins/BridgeJS/Sources/TS2Swift/JavaScript/` first, or codegen fails with `ERR_MODULE_NOT_FOUND: typescript`; `Extern` feature flag on the target); events/nullable/dynamic-property paths stay on JSObject.
- **DnD + files:** attribute-driven HTML5 DnD (`data-swui-drag*` contract, decode-layer preventDefault/acceptance); `.draggable`/`.dropDestination` (HTMLTag-only), `.fileImporter` (TagModifier + `swui:cmd:` property-command channel), `ForEach.onMove` (row decoration), `\.dragSession` env signal. `FileType` = UTType analog; payloads via `DragPayload` (Codable, visible in DOM — no secrets).
- **DI (lite swift-dependencies):** `@Dependency(\.key)` works anywhere (not render-tree-bound); `DependencyKey` = liveValue + optional testValue (auto-picked via one-time dlsym probe for `swt_abiv0_getEntryPoint`); resolution = init-snapshot → global overrides → cached default (singletons); `withDependencies` sync save/restore, `prepareDependencies` permanent; store implicitly MainActor-isolated (module default isolation, compiler-checked); NOT reactive; built-ins: \.webSession, \.navigate, \.webStorage, \.logger (navigate/webStorage runtime-wired via bootstrapDependencies at DOM boot — entry points only, never mount(); env channels preferred in body).
- **Boot loading:** `data-swui-boot` on `<html>` (absent = ready, so no-JS clients get the static page); boot UI declared in Swift (`App/Page.bootUI`, `.whileBooting`, `BootRetry`), rendered natively per (page, locale) through the document's own `Runtime`, shipped in an inert `<template>`; `swiftwui-boot.js` fetches the wasm itself for byte-accurate progress and hands a re-wrapped `Response` to `init({module:})`. Import map MUST precede every `modulepreload`. Boot CSS lives in `<style data-swui-boot>`, never the managed block. Opt-in: no source spelling `bootUI` → no `boot-shell` host compile and the legacy inline `import { init }`; `BootProbe` is exact only for listeners/@State/effects (blind to @Environment/@AppStorage/@Dependency/WAAPI) and reports via stderr + non-zero exit, never `assert` (release strips it).

## Build & test

- Native (primary gate): `swift build` / `swift test` — no browser needed; reconciler/applier tested via MockBackend.
- Toolchain: Swift **6.3.3** (swiftly) + official Swift.org WASM SDK `swift-6.3.3-RELEASE_wasm`. Host and SDK versions must match exactly. Never pass `-disable-reflection-metadata` (breaks Mirror → silently resets all @State; runtime has a startup canary).
- WASM example: `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`; Vite as dev server.
- wasm gates: run a clean build (`rm -rf .build/wasm32-unknown-wasip1`) before release-critical checks — stale .o files have masked real wasm-only compile breaks.
- Release gate: `swift build -c release --product swiftwui` — the brew formula's build, and the only place the core is optimized for an Apple target. Debug and wasm are both blind to it.
- **Never `import Foundation` (umbrella) in `SwiftWUI`/`SwiftWUIDOM`** — always `#if canImport(FoundationEssentials)` / `#else`. Autolink entries are emitted per MODULE, so one umbrella import anywhere makes every consumer link `_FoundationICU` and adds **~36 MB** of `icudt` data to every wasm bundle (this shipped in v0.9.1: 8.4 MB → 45 MB). `FoundationImportGuardTests` fails on a bare import; `swiftwui build -c release` warns when an app's own sources do it. `String(format:)` is umbrella-only — hand-roll it; `Data` → `_FoundationData`.
- **Every class in `SwiftWUI`/`SwiftWUIStatic` needs `nonisolated deinit { }`.** `.defaultIsolation(MainActor.self)` makes the implicit deinit MainActor-isolated, and Swift 6.3.2/6.3.3 crash the SIL inliner optimizing one for an Apple target. `IsolatedDeinitGuardTests` fails if a new class forgets.

## Hard-won WASM knowledge (from v1 — still true)

- `#if arch(wasm32)` for runtime forks, never `canImport(JavaScriptKit)`.
- `JSClosure` must be retained Swift-side while attached; `JSOneshotClosure` for one-shots.
- Never key a dictionary by `ObjectIdentifier(JSObject)` — JavaScriptKit makes a new wrapper per access.
- Microtask-deferred re-render; coalesce N writes into one flush.

## Workflow conventions

- Communicate with the user in Russian; code, commits, and docs in English.
- Design/review/research: Fable-tier agents. Implementation from an approved spec: voltagent agents (e.g. `voltagent-lang:swift-expert`).
- Each phase: brainstorm → spec in `docs/superpowers/specs/` → implementation plan → code with tests.
- No new dependencies without discussion (v1's Vapor-in-framework pinned 32 packages on every contributor).
