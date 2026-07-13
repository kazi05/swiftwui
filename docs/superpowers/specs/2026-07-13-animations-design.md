# SwiftWUI Animations — Phase Design (WAAPI engine, B→D)

**Date:** 2026-07-13
**Status:** Approved design (brainstorm complete)
**Research:** `docs/superpowers/research/2026-07-13-animations-web-research.md` (referenced below as R§n)

## 1. Goal

SwiftUI-style animations in SwiftWUI:

- `withAnimation(_:completion:) { state changes }` — explicit, transaction-scoped animation of everything that changes in one update pass.
- `.animation(_:value:)` — scoped implicit animation, fires only when `value` changes.
- `.transition(_:)` — enter/exit animations on structural identity insert/remove, with deferred DOM removal.
- Springs by default; interruptible, perceptually smooth retargeting.

Non-goals for this phase (deferred, see §14): FLIP/layout animation, analytic spring velocity retargeting, `matchedGeometryEffect`, View Transitions API, custom `Animatable` data, `appear`-style first-render transitions, `.id()`-forced identity swaps (SwiftWUI has no `.id()` identity analog today — `HTMLTag.id(_:)` is a plain attribute; transitions trigger only on `if`/optional/keyed/type structure and `replaceSelf`).

## 2. Architecture decision

**Candidate B — WAAPI-driven engine** (R§5.B), evolving to **D (hybrid + FLIP)** in a later phase. D minus FLIP == B, so this is an incremental path, not a fork.

- Swift computes per-property keyframes and timing (springs baked to CSS `linear()` easing).
- Backend calls `element.animate` via the JS bridge — **one call per animated property change, zero per-frame bridge traffic**.
- Model value (the style map / DOM attribute) is always written to the **final** target immediately; animations are presentation layers on top (`composite: "add"`, delta→0). This mirrors SwiftUI's own model/presentation split and its additive animation scheme (R§1.1, R§1.5, R§2.5).
- Rejected: A (CSS-transition-first — standing `transition:` declarations reproduce the banned deprecated `.animation(_:)` semantics, no retarget velocity, fragile exits; R§5.A), C (Swift rAF ticker — N×60fps bridge writes; every serious WASM framework rejected it; R§5.C).

### Decisions locked in the brainstorm

| # | Decision | Choice |
|---|---|---|
| 1 | Engine architecture | B now → D later (FLIP is a separate future phase) |
| 2 | Retarget fidelity | Additive WAAPI v1 (perceptually smooth); analytic velocity retarget later — curve metadata is stored from day one |
| 3 | Style representation | Typed style map on `ElementNode`; per-property diffing; serialization in backend |
| 4 | Transform channels | Individual CSS `translate` / `rotate` / `scale` properties; bare `transform` reserved for future FLIP |
| 5 | Transaction carrier | Per-write `[NodeIdentity: Transaction]` captured at `markDirty` |
| 6 | Naming collision | Existing CSS `.transition(String)` renamed to `.cssTransition(String)`; `.transition` belongs to `AnyTransition` |
| 7 | Default animation | iOS-17 parity: smooth spring (duration 0.55, bounce 0), presets `.smooth/.snappy/.bouncy` |
| 8 | Completion handlers | `withAnimation(_:completion:)` ships in v1 |
| 9 | Exit lifecycle | State/listener sweep at exit-start; ghost is `inert`; `onDisappear` fires at exit-start |
| 10 | `.transition` scope | Full set built on the `.modifier(active:identity:)` primitive |
| 11 | Animatable properties | Everything the browser can interpolate; non-interpolable values follow WAAPI discrete rules (end state always correct) |
| 12 | Reduced motion | duration≈0 + completion fires; `\.accessibilityReduceMotion` environment key |
| 13 | Backend surface | Protocol requirements with no-op defaults (observer precedent) |
| 14 | BridgeJS | Dynamic `JSObject.animate` first; typed d.ts only if hot |
| 15 | View Transitions | Deferred to a future route-transitions/MGE spec |
| 16 | Testing bar | MockBackend typed animation records + virtual completion driver for exit orchestration |

## 3. Public API surface

### 3.1 `Animation`

```swift
public struct Animation: Equatable, Sendable {
    // curves
    public static let `default`: Animation          // == .smooth (spring d=0.55, bounce=0)
    public static func linear(duration: Double) -> Animation
    public static func easeIn(duration: Double) -> Animation
    public static func easeOut(duration: Double) -> Animation
    public static func easeInOut(duration: Double) -> Animation
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double) -> Animation
    // springs (solved Swift-side → linear() easing string)
    public static func spring(duration: Double = 0.5, bounce: Double = 0.0) -> Animation
    public static let smooth: Animation             // spring(0.55, 0.0)
    public static let snappy: Animation             // spring(0.4, 0.15)
    public static let bouncy: Animation             // spring(0.5, 0.3)
    // modifiers
    public func delay(_ s: Double) -> Animation
    public func speed(_ factor: Double) -> Animation
    public func repeatCount(_ n: Int, autoreverses: Bool = true) -> Animation
    public func repeatForever(autoreverses: Bool = true) -> Animation
}
```

Internally an `Animation` resolves to `ResolvedTiming { durationMs, easing (CSS string), delayMs, iterations, direction, composite }`. The spring solver is pure math (closed-form damped harmonic oscillator, sampled to a `linear(...)` easing string; R§2.6) — natively unit-testable. Spring parameters (`duration`, `bounce`) follow SwiftUI's convention: `bounce ∈ [-1, 1]`, 0 = critically damped.

### 3.2 `withAnimation` / `Transaction`

```swift
@MainActor
public func withAnimation<T>(_ animation: Animation? = .default, _ body: () throws -> T) rethrows -> T

@MainActor
public func withAnimation<T>(_ animation: Animation? = .default,
                             completion: @escaping () -> Void,
                             _ body: () throws -> T) rethrows -> T

public struct Transaction {
    public var animation: Animation?
}
```

- `withAnimation(nil) { ... }` sets `transaction.animation = nil` for those writes: the ambient transaction carries no animation, but a `.animation(_:value:)` wrapper still overrides per nearest-wins (§3.3). SwiftUI's separate `disablesAnimations` flag (which suppresses even `.animation` overrides) is **not** in the v1 public surface — `Transaction` stays minimal until `withTransaction` ships.
- Calling `withAnimation` during `body` evaluation is illegal — same rule as any state write during resolve (existing `markDirty` assert, Runtime.swift:90). Documented.
- `completion` fires when every animation started by this transaction settles (see §7.4); with reduced motion or `nil` animation it fires on the next microtask after the flush.

### 3.3 `.animation(_:value:)`

```swift
extension Tag {
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some Tag
}
```

Scoped implicit animation: when `value` differs from the previous pass, the subtree's changes in *this* pass animate with `animation`, overriding the ambient transaction (nearest wrapper wins). When `value` is unchanged, the wrapper contributes nothing — unrelated changes to the same elements do **not** animate through it (this is exactly why a standing CSS `transition:` was rejected; R§5.A). `animation: nil` + changed value suppresses animation for the subtree.

### 3.4 `.transition(_:)` / `AnyTransition`

```swift
public struct AnyTransition {
    public static let identity: AnyTransition
    public static let opacity: AnyTransition
    public static func scale(_ scale: Double = 0.0, anchor: UnitPoint = .center) -> AnyTransition
    public static func offset(x: Double = 0, y: Double = 0) -> AnyTransition
    public static func move(edge: Edge) -> AnyTransition
    public static let slide: AnyTransition   // insertion .move(.leading), removal .move(.trailing)
    public static func modifier<M: TagModifier>(active: M, identity: M) -> AnyTransition
    public func combined(with other: AnyTransition) -> AnyTransition
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition
    public func animation(_ animation: Animation?) -> AnyTransition
}

extension Tag {
    public func transition(_ t: AnyTransition) -> some Tag
}
```

- Everything is sugar over the `modifier(active:identity:)` primitive: enter animates active→identity, exit animates identity→active (R§1.7, Tokamak precedent R§3.3).
- The transition's `.animation(_:)` overrides the driving transaction for that transition only; otherwise the transaction that caused the insert/remove drives timing (SwiftUI parity).
- **Rename:** existing CSS shorthand `.transition(String)` becomes `.cssTransition(String)` at **all** Tag-facing sites: StyleModifiers+Tag.swift:76,154 **and** StyleModifiers+HTMLTag.swift:69 (otherwise `Div(...)` keeps the old name while non-HTML tags don't — inconsistent surface). `StyleProxy.transition(String)` (StyleProxy.swift:95, inside `.hover{}`/`.media{}` blocks) **keeps its name** — no `AnyTransition` competition exists in that context (explicit decision). Internal `StyleDeclaration` factory untouched. Pre-1.0 breaking change; CHANGELOG + tutorial-site mentions updated.

### 3.5 Transform modifiers (net-new, strategy per decision #4)

```swift
extension Tag {
    public func offset(x: Double = 0, y: Double = 0) -> some Tag      // CSS translate
    public func scaleEffect(_ s: Double, anchor: UnitPoint = .center) -> some Tag   // CSS scale
    public func rotationEffect(_ degrees: Double, anchor: UnitPoint = .center) -> some Tag  // CSS rotate
}
```

- Map to the individual `translate` / `scale` / `rotate` CSS properties (Baseline since 2022; R§6.7) — each channel animates and retargets independently under its own curve, compositor-eligible.
- `anchor` maps to `transform-origin` (`UnitPoint` → percentages). One `transform-origin` per element: if two channels on the same element need different anchors, that is documented as unsupported (wrapper element is the workaround). Fixed composition order (`translate` → `rotate` → `scale`) documented; exotic SwiftUI modifier-order stacks need nested wrappers.
- Bare `transform` stays free for the future FLIP phase; `.style("transform", ...)` escape hatch remains untouched.
- `UnitPoint` and `Edge` are added as small public types if not present.

## 4. Transaction plumbing

### 4.1 Capture

- A `@MainActor` global static ambient `Transaction._active` holds the currently-active transaction (Tokamak precedent, R§3.3) — `withAnimation` is a free function with no `Runtime` handle, so the ambient cannot live on the instance. `withAnimation` sets/restores it around its closure body; nested `withAnimation` restores the outer on exit — inner wins for writes inside it.
- `Runtime.markDirty` (Runtime.swift:89) reads the ambient and captures it **per write** into `pendingTransactions: [NodeIdentity: Transaction]`. Two `withAnimation` blocks in one event handler produce two entries → two different animations in the same coalesced flush (SwiftUI parity; R§6.3).
- A completion-token accompanies each transaction so `finished` aggregation can group per-`withAnimation`-call (§7.4).

### 4.2 Resolve → apply carrier

The applier consumes transactions **per element identity**, because `.animation(_:value:)` can override the ambient for a sub-region of one pass:

- `flush()` (Runtime.swift:148) drains `pendingTransactions` alongside the dirty set; each dirty root resolves with its own captured transaction as the *ambient* one in `ResolveContext.transaction` (flowing root→leaves lexically through `_resolve` recursion, including through `ModifiedTag` — same preservation rule as `scopeClass`; TagModifier.swift:43-44).
- During resolve, the **effective** transaction for each element is recorded into a per-flush map `effectiveTransactions: [NodeIdentity: Transaction]` (populated for elements under an active transaction; absent = don't animate). `ResolveContext` unwinds before apply-time, so this map — not ctx — is what `TreeApplier` consults per patch.
- Both maps are cleared at the end of the flush — a transaction lives exactly one flush.

### 4.3 `.animation(_:value:)` wrapper

- Primitive wrapper node (pattern: `_OnChangeEffect` + `_StyledTag`): compares `value` against its previous value **during resolve** and, on change, overwrites `ctx.transaction` for its subtree. Nearest-wins falls out of resolve order.
- The previous-value store is a dedicated identity-keyed store on `Runtime` — **not** `EffectStore.onChange`, which compares/updates post-commit (EffectStore.swift:110-118); `.animation` must gate at resolve time. It needs the same collect-pass guard as `link()` (the `ctx.collectedRoutes == nil` gate, Resolver.swift:55) so route enumeration doesn't corrupt live values.
- **Scoped-pass semantics (value-gated, one pass only):** the override is armed for exactly the pass in which `value` changed, then dropped. It is **not** stashed/replayed for later subtree passes — a descendant-only pass where the wrapper didn't run means `value` didn't change, and animating through a stale override would reintroduce the banned valueless-`.animation` behavior (§3.3). This is deliberately the opposite of `RetainedComponent.styleWrappers` (which is an unconditional node transform and must replay); the ctx-seed precedent is `row.scopeClass`/`row.environment` (Runtime.swift:182,187). A value change always dirties at/above the wrapper, so the wrapper is guaranteed to run in any pass where it matters. Regression tests: scoped ≡ full with `.animation` above/below the dirty component; stale-override-must-not-fire.

## 5. Typed style map (prerequisite refactor)

Today `style` is one flattened attribute string (AttributeBag.swift:66-92) — per-property diffing is impossible and animator/differ writes clobber each other (R§6.6).

- `ElementNode` carries `style: OrderedStyle` — an order-preserving list of `(property, value)` pairs with last-wins-per-property merge. All existing style modifiers and `.style(_:_:)` already produce discrete pairs; they now append to the map instead of concatenating strings.
- **Known output change (accepted):** today the wrapper path emits duplicate properties (`mergeStyleText` concatenates base + wrapper without cross-boundary dedupe — AttributeBag.swift:90, documented on purpose at StyledTag.swift:48-50: CSS last-wins resolves it). The typed map collapses duplicates to last-wins at build time — same visual result (outer wrapper still wins), **different serialized bytes** where wrapper and body set the same property. SSG output is therefore not byte-identical in those cases; golden/`serializeHTML` tests are updated accordingly. Per-property diffing requires this collapse (duplicate keys make the diff ambiguous).
- Reconciler diffs styles per property → new patch ops `setStyleProperty(name, value)` / `removeStyleProperty(name)` replace whole-string `setAttribute("style", ...)` writes.
- Backends: DOMBackend uses `style.setProperty`/`removeProperty` per op; HTMLRenderer serializes the map to a `style="..."` string at emit time in map order.
- MockBackend records typed style ops; existing style tests migrate from string asserts to op asserts.
- Escaping: property names/values pass through the existing `HTMLEscaping` choke point at serialization exactly as before; the DOM path uses `setProperty` (no HTML context, no new escaping surface).

## 6. Animation engine (core module, renderer-agnostic)

### 6.1 What animates

During an applier pass with an effective transaction (ambient or `.animation`-overridden), for each element patch:

- **Style property changed** → write the final value (model), then emit `AnimationRequest { property, from: old, to: new, timing, composite: .add }`. The `from/to` are used to build the delta keyframes (`add` mode: animate `old − new` → `0` over the final underlying value, per property type; for non-numeric/composite values fall back to replace-mode keyframes `[from, to]` with implicit fill). Numeric delta vs replace selection lives in one function per CSS type, unit-tested.
- **Style property removed** (`removeStyleProperty` — reverts to computed/inherited default the engine cannot know) → apply instantly, never animated.
- **Attribute/text/other changes** → apply instantly (never animated in v1).
- No transaction (or `nil` animation) → today's behavior, zero overhead: the engine is entirely skipped.
- Property eligibility is delegated to the browser: the engine requests animation for any changed style property; the browser interpolates what it can, and non-interpolable values follow WAAPI discrete rules (swap at 50% of the duration — not instant; the model value is already written to final, so the end state is always correct; e.g. `height: auto → 200px` snaps mid-animation cross-browser, `interpolate-size` being Chromium-only). No curated whitelist to maintain.

### 6.2 Handle registry

`Runtime` gains a running-animation table (joining StateStore/EffectStore/ListenerRegistry):

```
AnimationRegistry: (NodeIdentity, property) → (backendHandle, ResolvedTiming, from, to, startedAt-token)
```

Used for: cancel on element unmount, force-finish (visibility change, parent unmount), completion aggregation bookkeeping, and — later phase — analytic velocity retargeting (metadata is already stored). Entries are swept when their animation settles or their identity unmounts.

Retargeting in v1 is additive: a new write mid-flight simply layers a new `composite: "add"` animation; the old one completes harmlessly on top (R§2.5). The registry still replaces its metadata entry so bookkeeping tracks the latest target.

### 6.3 Spring solver

`SpringTiming.solve(duration:bounce:) -> (durationMs: Double, easing: String)` — closed-form under/critically-damped oscillator sampled into `linear(p0 0%, p1 t1%, ..., 1 100%)` (~2 samples per expected frame at 60fps, capped; R§2.6a). Pure function in core, no bridge, exhaustive unit tests (monotone settle, bounce overshoot values, degenerate durations).

## 7. Transitions & exit orchestration

### 7.1 Trigger points

- `ChildrenPlan.fresh` slots → **enter**; `removedOldIndices` → **exit** (Reconciler.swift, R§4.1).
- `replaceSelf` (same-position identity swap; TreeApplier.swift:162-173) → simultaneous exit (old) + enter (new). The deferred-removal ghost survives as a sibling *after* the new node; anchor logic must treat it as a ghost (§7.3). This is the case only `replaceSelf` sees (R§6.1) — hooked explicitly, with tests.
- Transitions apply only to identities carrying a registered `.transition`; everything else mounts/unmounts synchronously exactly as today.
- **First-pass rule:** cold mount, hydration/adoption first pass never plays enter transitions (SwiftUI does not animate initial appearance; R§6.5). Mechanism: cold mount is automatic — `renderPass` mounts via `applier.mount` (Runtime.swift:278), never through `applyChildren`/`fresh`, so enter hooks cannot fire; adoption sets a one-shot `suppressTransitions` flag on the Runtime, cleared after the first real diff completes. No `appear` opt-in in v1.
- **Same-channel composition rule:** a transition and a `withAnimation` change landing on the same scalar property of the same element (e.g. an `.opacity` enter concurrent with a `withAnimation` opacity write) compose additively like everything else — deltas sum over the final underlying value, each decaying to 0 under its own curve; out-of-range transients (opacity beyond [0,1]) are clamped by the browser at paint. Transforms avoid the question entirely via separate `translate`/`rotate`/`scale` channels (decision #4).

### 7.2 Enter

1. Mount the subtree with the transition's **active** modifier styles applied on top of its identity styles (pre-styled at mount — no flash, no double-rAF).
2. Emit animations active→identity per affected property (engine path, §6.1), driven by the effective transaction (or the transition's own `.animation`).
3. On settle, active styles are dropped; the element is in its plain identity state.

### 7.3 Exit

1. Intercept removal; run `onDisappear` and sweep state/listeners/effects immediately (exit-start) — the ghost is a visual corpse. Fire-time listener lookup already no-ops for swept identities.
2. Mark the ghost `inert` (plain attribute set) so focus/clicks are dead.
3. Animate identity→active; await settle = race(`finished` aggregate, timeout = expected duration + grace, `visibilitychange` force-finish) (R§2.14).
4. `backend.remove` the host; sweep the registry entry and the exit record.
5. **Ghost bookkeeping:** exiting hosts leave the shadow tree immediately (slot freed for anchor correctness) and live in an `ExitRegistry: NodeIdentity → (host, oldNode, animations)`. Anchor computation (`firstHost`, right-to-left slot realization, `moveHosts`; TreeApplier.swift:178-226) skips ghost hosts. `MockBackend.serializeHTML` gains a ghost-aware mode for tests.
6. Parent unmount force-finishes descendant exits (removed elements emit no events; continuations are idempotent).

### 7.4 Completion aggregation

Each transaction's animations register into a completion group; when all settle (or force-finish), the group's `completion` runs once. Timeout + `visibilitychange` guarantee it always fires — hidden-tab lingering ghosts and never-firing completions are the known bug class to test against (R§2.14). Edge rules:

- **Empty group** (animation requested, zero animatable properties changed — e.g. text-only update): completion fires on the next microtask after the flush (SwiftUI parity, R§1.2).
- **`repeatForever`/infinite animations**: excluded from the group (their WAAPI `finished` never resolves and there is no finite expected duration for the timeout race; R§2.14). They count as settled immediately for aggregation purposes — the model value is already final. Documented divergence.

### 7.5 Bidirectional interruption

The registry tracks **both** enter and exit animations per identity (R§6.1):

- **Re-insertion during exit** (toggle back mid-outro): at mount time, applier consults `ExitRegistry`; on hit it **adopts the ghost back** — cancels exit animations, re-diffs the incoming Node against the ghost's retained `oldNode` (normal reconcile), re-runs enter active→identity additively from the current presentation state. No duplicate elements, no snap. State was already swept at exit-start, so `@State` restarts fresh — documented (SwiftUI equally provides no state continuity across removal).
- **Removal during enter**: cancel the enter animations; exit starts from the current presentation state automatically (implicit-from keyframes read current computed style).

### 7.6 Overlap stacking

Old + new coexisting during `replaceSelf`/asymmetric swaps: no built-in z-index management in v1 (SwiftUI also requires explicit `zIndex`). Documented recipe (`.style("z-index", ...)` / position). Vue-style `out-in` sequencing noted as possible future transition option.

## 8. Backend protocol extension

Per the observer precedent (RendererBackend.swift:71-80): new requirements with no-op defaults, so HTMLRenderer/SSG and any minimal backend stay animation-neutral with zero changes.

```swift
// sketch — exact signatures settled in the implementation plan
protocol RendererBackend {
    // existing...
    func setStyleProperty(_ host: HostRef, _ name: String, _ value: String)
    func removeStyleProperty(_ host: HostRef, _ name: String)
    @discardableResult
    func animate(_ host: HostRef, _ request: AnimationRequest,
                 onSettle: @escaping (AnimationSettle) -> Void) -> AnimationHandle?
    func cancelAnimation(_ handle: AnimationHandle)
    func finishAnimation(_ handle: AnimationHandle)   // jump-to-end (force-finish path)
}
```

- `AnimationRequest` is a typed value (property, keyframes, ResolvedTiming, composite) — fully assertable in tests.
- **DOMBackend:** dynamic `JSObject` calls (`element.animate([...], {...})`), `finished.then` via retained `JSOneshotClosure` (retention table keyed by handle, released on settle — existing JSClosure lifetime pattern). `inert` via existing attribute op. Timeout via existing scheduling primitives; `visibilitychange` listener installed once per Runtime.
- **MockBackend:** records `animate` calls typed; exposes a **virtual completion driver** — tests complete/cancel recorded handles manually to drive exit orchestration deterministically (TestScheduler precedent). No wall clock anywhere in core.

## 9. Reduced motion

- `prefers-reduced-motion` becomes an `EnvironmentSignals` input (Writer-closure recipe, DOMBackend media-query precedent; R§4.8), exposed as `\.accessibilityReduceMotion`.
- Engine policy when on: every `ResolvedTiming` collapses to duration≈0 (instant), completions fire with identical semantics; transitions apply final states immediately (exit ghosts removed next tick).
- Any future registry-emitted decorative keyframes must be wrapped in `@media (prefers-reduced-motion: no-preference)` — noted for the Styled/keyframes docs.

## 10. SSG / hydration

- `HTMLRenderer` stays animation-neutral automatically (no-op defaults): final values only, no transitions armed, no ghosts (R§6.5).
- First pass after adoption = "initial render" → no enter transitions (§7.1). Adoption-created nodes must not flash (no `@starting-style` usage in v1 — engine-driven enters don't need it).
- No standing CSS `transition:` declarations are ever emitted (decision #1/A-rejection), so SSG'd HTML cannot animate hydration corrections.

## 11. Testing strategy

Native `swift test` (MockBackend) covers everything except real browser rendering:

1. **Spring solver:** pure-math unit tests (curve shape, settle, presets).
2. **Transaction plumbing:** per-write map (two `withAnimation` in one handler → two timings), nested `withAnimation`, `withAnimation(nil)` overridable by `.animation`, `.animation(_:value:)` gating (value unchanged → no animation; unrelated sibling change → no animation; stale override must not fire on later passes), scoped subtree pass ≡ full pass with `.animation` above/below the dirty component.
3. **Engine:** per-property diff → exact `AnimationRequest`s (keyframes, easing strings, composite) asserted; non-style changes never animate; no transaction → zero engine calls (churn guard).
4. **Transitions:** enter on fresh, exit deferral + ghost removal on driver-completion, `replaceSelf` dual-fire, first-pass suppression, anchors skipping ghosts (`moveHosts` around a ghost), parent-unmount force-finish, re-insertion ghost adoption, removal-during-enter, completion aggregation incl. timeout path.
5. **Reduced motion:** instant application + completion parity.
6. **Regression:** full existing suite green; SSG byte-output unchanged.

Browser acceptance (manual, end of phase): Counter/TodoMVC visual checks — spring feel, interrupt mid-flight, toggle-spam on a transition, hidden-tab exit, reduced-motion in OS settings.

## 12. Implementation notes

- Implementation from this spec: **voltagent agents** (`voltagent-lang:swift-expert` primary), per workflow convention; reviews via voltagent reviewers.
- Suggested task seams: (1) typed style map + patches + backends; (2) Animation/Transaction/spring solver; (3) transaction plumbing + `.animation` wrapper (per-identity carrier, §4.2-4.3); (4) engine + registry + completion; (5) backend `animate` + DOMBackend; (6) transition primitive + AnyTransition sugar; (7) exit orchestration + ghosts + bidirectional interruption; (8) transform modifiers + `.cssTransition` rename; (9) reduced motion + env key; (10) **documentation + Tutorials site update** (new animations tutorial page/section, `.cssTransition` rename mentions, API reference) + browser acceptance. Ordering/detail belongs to the implementation plan; item 10 is a required closing task, not optional polish.

## 13. Risks

- **Typed style map** touches every style-producing path — mitigated by migrating existing style tests first and asserting SSG output changes are limited to duplicate-property collapse (§5).
- **Transaction-carrier plumbing across the scoped/full boundary** (§4.2–4.3) — the project's historically hardest bug class (commit 3324953); mitigated by the dedicated scoped≡full and stale-override regression tests.
- **Exit orchestration** is the riskiest new logic (ghost anchors, adoption, force-finish) — mitigated by the virtual completion driver and the dedicated test list in §11.4.
- **`replaceSelf` × deferred removal** specifically: `replace()` mounts the new node *before* unmounting the old for anchor correctness and reassigns the shadow slot immediately (TreeApplier.swift:170-172) — the exit ghost then lives *after* the new node outside the shadow tree; anchor scans and `moveHosts` must skip it with the slot already gone (R§6.1 calls this a direct conflict). Own test in §11.4.
- **Additive keyframe math per CSS type** (lengths, colors, transforms) — start with numeric+unit and color; fall back to replace-mode for anything unparseable (correct, just less smooth under interruption).
- `linear()` easing is Baseline-everywhere (R§2.15), but a defensive fallback to `ease-out` when the string is rejected costs one line in DOMBackend.

## 14. Future phases (explicitly out)

FLIP layout animation (D-completion; measurement hooks, ghost pop-out); analytic spring velocity retargeting (registry metadata already present); `matchedGeometryEffect` / View Transitions opt-in; custom `Animatable`/rAF escape hatch; `appear` opt-in; PhaseAnimator/KeyframeAnimator; `.contentTransition`.
