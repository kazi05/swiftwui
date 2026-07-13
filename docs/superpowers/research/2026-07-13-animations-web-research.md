# Animations for SwiftWUI — Unified Research (2026-07-13)

Synthesis of four research tracks: SwiftUI animation semantics, web platform primitives (July 2026 state), prior art across declarative frameworks, and SwiftWUI codebase reconnaissance. Feeds the design brainstorm and later spec for `withAnimation { }`, `.animation(_:value:)`, and `.transition(...)`.

All file:line refs are relative to the repo root on branch `main` (post v0.2.0). All browser-support claims are as of 2026-07-13.

---

## 1. SwiftUI semantic target

Sources: WWDC23 "Explore SwiftUI animation" (https://nonstrict.eu/wwdcindex/wwdc2023/10156/), WWDC23 "Animate with springs" (https://nonstrict.eu/wwdcindex/wwdc2023/10158/), objc.io "Transactions and Animations" (https://www.objc.io/blog/2021/11/25/transactions-and-animations/), fatbobman "The Animation Mechanism of SwiftUI" (https://fatbobman.com/en/posts/the_animation_mechanism_of_swiftui/) and "Mastering Transaction" (https://fatbobman.com/en/posts/mastering-transaction/), swiftui-lab "Advanced SwiftUI Animations Part 1" (https://swiftui-lab.com/swiftui-animations-part1/), Apple docs.

### 1.1 The three-legged model

A SwiftUI animation needs exactly three things:
1. **A timing algorithm** — the `Animation` value (a curve/physics function, not an "animation").
2. **A transaction associating a state change with that algorithm** — `withAnimation`, `.animation(_:value:)`, `.transaction(_:)` all just write into the Transaction that flows with the update.
3. **Something animatable** — a view/modifier/shape conforming to `Animatable` (`animatableData: some VectorArithmetic`).

Crucially, animation is **not** "re-run body with interpolated state". The **model value changes instantly**; `if`-conditions, `onChange`, all logic see the final value immediately. Interpolation happens at **animatable attributes** in the attribute graph: each `Animatable` node holds the model value and, when a change arrives with `transaction.animation != nil`, forks a **presentation value** interpolated per frame; only the downstream subgraph of that attribute re-evaluates per frame. Body runs once per state change; frames tick only animatable attributes.

### 1.2 withAnimation / Transaction mechanics

```swift
func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result
// iOS 17+: + completionCriteria: .logicallyComplete | .removed, completion: @escaping () -> Void
```

- `withAnimation(a) { ... }` ≡ `withTransaction(Transaction(animation: a)) { ... }`: sets the animation on the thread's current transaction, runs `body` synchronously; every state write inside is tagged with that transaction. The transaction **lives for exactly one update pass** and is discarded after.
- **Scope is global, not lexical**: every animatable attribute anywhere in the tree whose value changed as a downstream consequence of the writes animates — position, size, opacity, transform, color, shape paths, layout reflow.
- **Nested `withAnimation`**: the innermost block in effect at the time of a given state write wins for that write (two sibling writes in two nested blocks → two different curves in one update).
- **Transaction fields**: `animation: Animation?`, `disablesAnimations: Bool`, `isContinuous: Bool` (gesture-driven), custom `TransactionKey`s (iOS 17).
- **Precedence (objc.io, exact)**: `.animation(_:value:)` on a subtree **overwrites** `transaction.animation` for that subtree — *implicit beats explicit*. `disablesAnimations = true` does **not** kill all animation; it disables the implicit `.animation` override path so the transaction's own animation (possibly nil) wins. Canonical "no animation, period": `withTransaction(Transaction(animation: nil) with disablesAnimations = true)`.
- **Bindings**: `$binding.animation(a)` / `binding.transaction(t)` wrap the setter in a transaction (Toggle/Slider-driven animation).
- **Completion (iOS 17)**: fires exactly once, aggregated across ALL animations spawned by the transaction; fires immediately after `body` if nothing animated. `.logicallyComplete` (spring practically settled) vs `.removed` (fully removed).

### 1.3 `.animation(_:value:)`

```swift
func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View   // iOS 15+
func animation(_ animation: Animation?) -> some View                            // DEPRECATED — do not replicate
func animation<V: Equatable>(_ a: Animation?, body: (PlaceholderContentView<Self>) -> some View) -> some View // iOS 17 scoped
```

- When `value` changes across an update, sets `transaction.animation = a` **for this subtree only**. Classic gotcha: any *other* animatable change in the same subtree in the same update also animates with `a` (transaction is per-update, not per-property).
- `.animation(nil, value: v)` explicitly disables animation in the subtree when `v` changes (overrides outer `withAnimation`).
- Modifier ordering matters: modifiers *below* `.animation` are affected, those above are not. Rule of thumb: **nearest declaration to the animatable attribute wins**.
- The deprecated valueless `.animation(a)` applied to every passing transaction (window resize, rotation → "flying views"); a web replica must implement only the `value:` form.

### 1.4 Animatable / VectorArithmetic

```swift
protocol Animatable { associatedtype AnimatableData: VectorArithmetic; var animatableData: AnimatableData { get set } }
protocol VectorArithmetic: AdditiveArithmetic { mutating func scale(by: Double); var magnitudeSquared: Double { get } }
```

Conformers: `Double/Float/CGFloat`, `EmptyAnimatableData`, nestable `AnimatablePair`, `Angle`, `UnitPoint`, `EdgeInsets`, CG types. Built-in animatable attributes: opacity, offset, frame/layout position+size, scaleEffect, rotationEffect, fill/foregroundColor, blur, shadow, gradients, `Shape.path(in:)` via forwarded animatableData, `GeometryEffect.effectValue(size:)`. Interpolation math: `from + (to - from).scaled(by: progress)`; springs integrate the vector with physics rather than a scalar progress. SwiftUI skips unchanged `AnimatablePair` components — two concurrent animations can drive the two halves with different curves.

### 1.5 Interruption / retargeting / additivity (the hardest-to-fake property)

- Running animations are **per-attribute**. A new transaction reaching an attribute mid-flight consults `CustomAnimation.shouldMerge(previous:value:time:context:)`:
  - **Timing-curve animations → `shouldMerge = false` → additive composition.** Each animation animates a **delta vector** (target change, e.g. `0 → 0.5`, not `1 → 1.5`); simultaneous animations run to completion and their per-frame contributions **sum** onto the latest model value. N rapid taps = smooth compounding motion, no snap.
  - **Springs → `shouldMerge = true` → retarget.** New spring replaces the old but inherits current **presentation position AND velocity** (`velocity(value:time:context:)`). Seamless redirect, no discontinuity.
- `interpolatingSpring` is the additive spring (adds effects of overlapping animations); `spring`/`interactiveSpring` are the merging kind.
- Gesture handoff: springs started at gesture end pick up gesture velocity (`isContinuous`).
- Web mapping preview: CSS transitions natively retarget from the current computed value but with **zero velocity memory**; WAAPI `composite: 'add'` gives additivity; exact velocity-preserving retarget needs analytic velocity or a per-frame integrator (§2.8).
- **v1 scope**: gesture-driven transactions (`isContinuous`, gesture-velocity handoff into springs) are explicitly OUT of the v1 target — SwiftWUI has no gesture system to feed them. Documented here only so the retarget design doesn't foreclose them later (the additive/analytic paths don't); the brainstorm should not relitigate this.

### 1.6 Animation type surface

```swift
.default            // Apple-documented: spring(response: 0.55, dampingFraction: 1.0, blendDuration: 0)
                    // ≡ smooth / spring(duration: 0.55, bounce: 0) in iOS-17 vocabulary.
                    // Pre-17 fallback: easeInOut — Apple docs give NO duration; the oft-quoted
                    // 0.35s is community reverse-engineered, cite it as such.
.linear/.easeIn/.easeOut/.easeInOut (+duration, default 0.35)
.timingCurve(c0x,c0y,c1x,c1y, duration: 0.35)           // cubic Bézier
.spring(duration: 0.5, bounce: 0)                        // iOS 17 vocabulary; bounce = 1 - dampingFraction
.spring(response:dampingFraction:blendDuration:)         // classic vocabulary
.interactiveSpring(...) / .interpolatingSpring(stiffness:damping:initialVelocity:)
.bouncy /* bounce 0.30 */  .smooth /* 0.00 */  .snappy /* 0.15 */   // presets, duration 0.5
.speed(_:) .delay(_:) .repeatCount(_:autoreverses:) .repeatForever(autoreverses:)   // combinators on Animation values
```

Springs are duration-less physically; `duration` is perceptual settle time. iOS 17 `CustomAnimation` protocol (`animate(value:time:context:) -> V?`, nil = finished; `velocity`; `shouldMerge`) is the cleanest spec for a pluggable engine — the `value` passed is the *delta* vector because of the additive scheme. `context.isLogicallyComplete` drives `.logicallyComplete` completion.

### 1.7 `.transition(_:)` / AnyTransition

- Fires **only on structural insertion/removal of a view's identity**: `if/else` flip, `ForEach` item appears/disappears, `.id(x)` change, `switch` branch — never on mere state change.
- The insert/remove must happen **inside an animated transaction**, else it snaps. A per-transition animation self-arms it: `.transition(.opacity.animation(.easeOut(duration: 0.2)))` (overrides the transaction's animation for that transition).
- **Removal keeps the view alive**: the removed view stays rendered until its removal transition finishes, then unmounts. Old+new coexist during overlap → explicit `zIndex` needed to control stacking (classic gotcha).
- Built-ins (https://developer.apple.com/documentation/swiftui/anytransition): `.identity`, `.opacity` (the default when none specified), `.scale(scale:anchor:)`, `.move(edge:)`, `.offset`, `.slide`, `.push(from:)` (iOS 16), `.asymmetric(insertion:removal:)`, `.combined(with:)`, `.animation(_:)`, and the primitive `.modifier(active:identity:)` — a transition is *defined* as a pair of ViewModifiers; SwiftUI animates between the two modifiers' animatable data (opacity = active: `opacity(0)`, identity: `opacity(1)`). iOS 17 typed `Transition` protocol: `body(content:phase:)`, `TransitionPhase ∈ {.willAppear, .identity, .didDisappear}`.
- If both a remove and an insert with the same `matchedGeometryEffect` id land in one transaction → frame interpolation in window space (hero move); MGE links **geometry only, not rendering** (web analog: FLIP / View Transitions).

### 1.8 Newer APIs (later phases)

`PhaseAnimator` / `KeyframeAnimator` (iOS 17; keyframes re-run body per frame — Apple flags the cost), `.contentTransition(.numericText())` (odometer digits), `Text` interpolation. All deferrable.

### 1.9 Ranked minimal subset for "SwiftUI feel"

1. **Transaction-carried implicit interpolation of changed properties** — `withAnimation { state }` animating every changed animatable style/geometry attribute; model instant, presentation per-attribute. Includes `.animation(_:value:)` subtree scoping, nearest-wins precedence, `disablesAnimations`. Without this it's not SwiftUI, it's jQuery.
2. **Insert/remove transitions** — structural-identity triggered, removed node kept alive until exit finishes, `.opacity` default, asymmetric/combined, only-under-animated-transaction rule. SwiftWUI's structural `NodeIdentity` maps directly onto reconciler insert/remove patches.
3. **Interruptible retargeting** — new target mid-flight departs from current presentation value (CSS gives position-continuity free; velocity continuity needs additive WAAPI or analytic springs).
4. **Springs as first-class default** — `duration/bounce` vocabulary + `smooth/snappy/bouncy` presets. This is 80% of "feels like iOS".
5. **Layout animation** — animating reflow-caused position/size changes (web: FLIP, `interpolate-size` progressive enhancement). Expensive but extremely high perceived value.
6. **Completion handlers** — cheap once an engine owns timing; needed for choreography.
7. **Animatable protocol for user shapes/modifiers** — power feature; defer.
8. **matchedGeometryEffect / contentTransition / Phase/KeyframeAnimator** — later; MGE ≈ FLIP or View Transitions API.

### 1.10 Gotchas checklist for the web replica

- Implicit `.animation(_:value:)` overrides explicit `withAnimation` for its subtree; `disablesAnimations` only mutes the implicit-override path.
- Two state changes in one update under one `.animation(value:)`: BOTH animate.
- Transition needs an animation in the transaction at insert/remove time; `.transition(t.animation(a))` self-arms.
- Removal transition ⇒ delayed unmount ⇒ old+new coexist ⇒ zIndex control.
- Do NOT replicate valueless `.animation(_:)`.
- Timing curves compose additively (delta-based); springs merge (velocity-preserving retarget).
- Completion fires exactly once, immediately if nothing animated.
- Repeat/autoreverse/speed/delay are `Animation` combinators, not separate APIs.

---

## 2. Web primitive toolbox (July 2026)

### 2.1 CSS Transitions

- **What it gives**: automatic interpolation whenever the computed value of a transitionable property changes across a style recalc; the framework only needs the `transition` declaration in place and a property mutation. Property animation-type reference: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_animated_properties (lengths/colors/numbers/transforms/shadows/filters = by computed value; `display`/`visibility`/keywords = discrete or not animatable; mismatched units via `calc()`; mismatched transform lists via matrix decomposition).
- **Interruption**: retargets automatically **from the current computed value** — position-continuous, **velocity-discontinuous** (visible kink with eased curves). Special case: exact reversals shorten via the *reversing-adjusted start value / shortening factor* (hover-in 25% then out takes ~25% of the duration) — https://drafts.csswg.org/css-transitions/#reversing. Retarget toward a third value = fresh full-duration transition.
- **The #1 orchestration trap**: setting from-style and to-style in the same JS task = one recalc = no transition. Only affects *newly inserted* elements (existing elements already render the old value). Fixes: forced style flush, double-rAF, or `@starting-style`.
- **Cost via WASM bridge**: near zero — write style strings, browser owns frames.
- **Support**: universal.
- *Color-space footnote*: transitions/WAAPI interpolate colors per computed value — legacy syntaxes (`#hex`, `rgb()`, named) in gamma sRGB; `color-mix()`/relative-color and other CSS Color 4 syntaxes default to oklab (https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#interpolation). SwiftUI's `Color` animation interpolates in its own space, so fill/foregroundColor animations (§1.4 list) won't be bit-identical — visually negligible, but a fidelity asterisk, not a bug.

### 2.2 `@starting-style` + `transition-behavior: allow-discrete`

- `@starting-style { opacity: 0 }` defines the "before" style for the **first style update after the element is rendered** (insertion or `display:none→block`) — entry animations with no reflow-forcing, no double-rAF. Does NOT re-trigger on re-renders (good: no accidental re-entry on VDOM patch). https://developer.mozilla.org/en-US/docs/Web/CSS/@starting-style — **Baseline Newly Available since Aug 2024** (Chrome 117, Safari 17.5, Firefox 129); https://web.dev/blog/baseline-entry-animations
- `transition-behavior: allow-discrete` lets discrete props transition (flip at 50% — except `display`/`content-visibility`: visible value holds the whole duration going to `none`). Pure-CSS exit *fade-to-display:none* works — but `display:none` ≠ DOM removal; a VDOM framework still owns removal and needs JS-side end detection. https://developer.mozilla.org/en-US/docs/Web/CSS/transition-behavior
- Together: the modern platform-native insert/remove-visibility mechanism. There is **no pure-CSS exit-with-DOM-removal**.

### 2.3 `interpolate-size` / `calc-size()` (height: auto)

- `interpolate-size: allow-keywords` (inherited, opt-in at `:root`) makes transitions to/from `auto/min-content/max-content/fit-content/stretch` interpolable; `calc-size(auto, size + 2rem)` for math over intrinsic sizes. https://developer.mozilla.org/en-US/docs/Web/CSS/interpolate-size , https://developer.mozilla.org/en-US/docs/Web/CSS/calc-size
- **Chromium-only (Chrome/Edge 129+); Firefox and Safari not shipped** (https://caniuse.com/mdn-css_properties_interpolate-size). Graceful degradation (snap). Use as free progressive enhancement; cross-browser auto-size animation needs FLIP/measurement or the `grid-template-rows: 0fr→1fr` trick (interpolable everywhere).

### 2.4 CSS `@keyframes` + `animation-composition`

- Better than transitions for: multi-step choreography, looping, auto-run on insertion, pause (`animation-play-state`), alternate direction. Cascade gotcha: running CSS animations override inline style for animated properties and suppress transitions on the same property.
- `animation-composition: replace | add | accumulate` — Baseline since July 2023 (Chrome 112, Firefox 115, Safari 16). https://developer.mozilla.org/en-US/docs/Web/CSS/animation-composition , https://developer.chrome.com/docs/css-ui/css-animation-composition
- Framework verdict: dynamic per-instance `@keyframes` = stylesheet churn + unique-name management; **WAAPI is the same engine with a JS handle** — supersedes `@keyframes` for anything dynamic. Keep `@keyframes` for static author-declared effects (rides `StyleRegistry.registerRaw`, see §4.2).
- Typed custom properties (`@property`, Baseline July 2024 — https://developer.mozilla.org/en-US/docs/Web/CSS/@property) enable smooth custom-prop interpolation but invalidate style of all readers per frame — niche tool, not an engine.

### 2.5 WAAPI (Web Animations API) — the workhorse

Refs: https://developer.mozilla.org/en-US/docs/Web/API/Web_Animations_API , https://drafts.csswg.org/web-animations-1/ . **Baseline**: core Widely Available for years; composite modes / implicit keyframes / commitStyles completed the set as Baseline *Newly* available Sep 2022 (Safari 16) and reached *Widely* only ~Mar 2025 — irrelevant for July-2026 targeting, but don't quote "Widely (2022)".

- `el.animate(keyframes, { duration, delay, easing, fill, composite, iterations, direction, id })` → `Animation` handle: `.play/.pause/.reverse/.finish/.cancel/.currentTime/.startTime/.playbackRate/.playState/.finished (Promise)/.ready/.effect/.commitStyles()/.persist()`.
- **Implicit keyframes**: omit the from (or to) keyframe → missing endpoint = element's underlying computed value at effect-apply time. "Transition-like" animation on demand.
- **`composite: "add"`** — THE retargeting primitive (https://developer.mozilla.org/en-US/docs/Web/API/KeyframeEffect/composite , pattern write-up https://css-tricks.com/additive-animation-web-animations-api/):
  ```js
  // animating toward X1; user retargets to X2:
  el.animate([{ transform: `translateX(${X1 - X2}px)` }, { transform: "translateX(0)" }],
             { duration, composite: "add", easing });
  el.style.transform = `translateX(${X2}px)`;   // underlying/model value jumps to the new target
  ```
  Old and new additive layers run simultaneously and sum ⇒ smooth overlap-blended retarget, no velocity bookkeeping. This is *structurally identical* to SwiftUI's additive delta-vector scheme (§1.5): underlying = model value, additive layers = per-animation deltas.
- **Automatic replacement**: finished filling animations fully covered by newer ones are auto-removed (`replaceState: "removed"`, `onremove`); `persist()` opts out. Prevents unbounded layer buildup. https://developer.mozilla.org/en-US/docs/Web/API/Animation/persist
- **fill-forwards leak**: indefinite `fill: "forwards"` overrides inline style forever; MDN recommends `anim.finished.then(() => { anim.commitStyles(); anim.cancel(); })`. `commitStyles()` **throws `InvalidStateError` on non-rendered targets** (display:none / disconnected) — guard exit paths. https://developer.mozilla.org/en-US/docs/Web/API/Animation/commitStyles
- **`el.getAnimations({ subtree: true })`** returns ALL active animations incl. CSS-transition/animation-backed objects — aggregate "everything animating under this node" before unmount: `await Promise.allSettled(node.getAnimations({subtree:true}).map(a => a.finished)); node.remove();` (allSettled, not all — `finished` **rejects with AbortError on `cancel()`**).
- **`finished` resolves even if the element was removed from the DOM** (timeline-based, not render-based) — a decisive robustness advantage over `transitionend` for exit orchestration.
- Live mutation: `anim.effect.setKeyframes([...])` / `updateTiming({...})`; readback via `currentTime` + `effect.getComputedTiming().progress`.
- **Compositor execution**: animations touching only `transform` (incl. individual `translate/rotate/scale`) and `opacity` run off-main-thread at full frame rate in **all engines** even when the main thread (or WASM) is busy. `filter`/`backdrop-filter` acceleration is Chromium (and largely WebKit) only — Gecko's off-main-thread animation covers transform-like properties + opacity, so filter animations run on Firefox's main thread. One non-compositable property in the keyframes drags the whole effect to the main thread. Start/cancel/retarget still round-trips the main thread; steady-state playback is jank-immune.
- CSS Typed OM: Chrome + Safari 16.4+, **Firefox still lacks it** — do not build readback on Typed OM; string parsing of computed styles stays the portable route.
- **Bridge cost**: one call to start, one callback at end; zero per-frame traffic.

### 2.6 Springs on the web

**No native spring timing function in any stable browser (2026).** CSS `spring()` was WebKit-STP-only in 2016 and never shipped (https://github.com/w3c/csswg-drafts/issues/280 , folded into https://github.com/w3c/csswg-drafts/issues/229).

- **(a) `linear()` easing with a sampled spring curve** — `linear(0, 0.05 1.5%, …, 1.001, 1)`; values may exceed [0,1] ⇒ overshoot works. **Baseline: Chrome 113, Firefox 112, Safari 17.2 — universal in 2026.** https://developer.chrome.com/docs/css-ui/css-linear-easing-function , deep-dive https://www.joshwcomeau.com/animation/linear-timing-function/ . Generation: solve the damped-harmonic-oscillator closed form `x(t) = 1 − e^(−ζωt)(cos(ω_d t) + (ζω/ω_d) sin(ω_d t))`, pick effective duration (amplitude < ε), sample ~60–100 points, emit `"550ms linear(0, 0.0159, …)"`. Motion does exactly this (https://motion.dev/docs/spring , https://motion.dev/docs/css); tutorial https://pqina.nl/blog/css-spring-animation-with-linear-easing-function/ ; standalone lib https://github.com/okikio/spring-easing . Works in both `transition-timing-function` and WAAPI `easing`.
- **(b) WAAPI keyframes sampled from a spring solver** — equivalent power; per-keyframe values allow different physics per property in one effect.
- **(c) rAF-driven numeric integration** — the only *true* spring: exact velocity-preserving retarget, dynamic targets, gesture-coupling. Costs §2.9.
- Baked curves encode v₀ = 0 — interruption loses velocity **unless** you (i) re-derive the curve with `initialVelocity` from the closed form (needs current velocity — §2.8), or (ii) use additive WAAPI composition, which sums overlapping v₀=0 layers into a perceptually smooth (C¹-ish) result with zero velocity math.
- **Recommended hierarchy (matches Motion's own architecture)**: baked `linear()`/keyframe springs for fire-and-forget (compositor-eligible); rAF integration reserved for gesture-coupled/velocity-critical cases.

### 2.7 View Transitions API (same-document)

Refs: https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API , https://developer.mozilla.org/en-US/docs/Web/API/Document/startViewTransition

- `document.startViewTransition(async () => { mutateDOM() })`: snapshots old state as **static bitmaps** (root + every `view-transition-name`d element), suppresses rendering during the callback, builds `::view-transition-*` pseudo tree, default cross-fade + geometry morph per named group. `vt.finished/.ready/.updateCallbackDone`, `skipTransition()`. `view-transition-class` (Chrome 125, Safari 18.2, Firefox 144) and `view-transition-name: match-element` (Chrome 137, Safari ~18.4, Firefox 144) remove the uniqueness pain.
- Solves what nothing else does cheaply: **layout morphs and shared-element transitions across arbitrary DOM restructuring** (reparenting, reorder, route change) with browser-computed geometry diffing.
- Hard limits: **page-global** (no subtree scoping; scoped VT is an unshipped proposal), **one transition at a time per document**, old content frozen as an image, **input frozen** for the duration, rendering suppressed during the callback.
- Verdict: opt-in route-level / explicit-morph tool (≈ `matchedGeometryEffect` + navigation transition), **never** the engine for `withAnimation` (can't run two independent component animations; freezing input per counter increment is absurd).
- **Support**: same-doc = Baseline Newly Available — Chrome 111+, Safari 18+, Firefox 144+ (Oct 2025); https://web.dev/blog/same-document-view-transitions-are-now-baseline-newly-available . Cross-doc: Chrome 126+, Safari 18.2+, Firefox in development. Trivially clean degradation (`if (!document.startViewTransition) { update(); }`).

### 2.8 Reading interpolated state back / velocity

- `getComputedStyle(el).prop` mid-flight returns the current animated value (`transform` → matrix string; decompose via `DOMMatrix`). Forces style recalc — fine at interruption time, not per-frame×N.
- **Velocity is never reported by the platform.** Options: (1) **analytic** — you generated the curve, so differentiate it at `anim.currentTime` (for `linear()` springs: slope between adjacent samples × range / duration) — Motion does this; (2) numeric — two-frame sampling; (3) own the state — rAF integrator. A design that keeps *curve + start time + from/to* per running animation retargets with velocity using pure arithmetic, no sampling.
- CSS transitions expose the least, but `el.getAnimations()` fishes out the `CSSTransition` object (has `currentTime`, `effect.getComputedTiming()`).

### 2.9 rAF-driven JS/WASM animation

- Required only for: live-velocity springs, gesture-following, per-frame derived values, animating non-CSS state (SwiftUI can animate arbitrary `Animatable` data — on the web only rAF can drive e.g. animated text content), layout projection (nested FLIP).
- Cost: per frame = callback + style writes → main-thread style recalc (+ layout if geometry). For SwiftWUI: **each frame crosses the WASM bridge**; OK if per-frame work writes styles directly and never runs the reconciler; scales badly with element count; loses to compositor animations under main-thread contention.
- **rAF is fully paused in hidden tabs** (all engines); an integrator must clamp Δt on resume (~32ms cap) or explode. WAAPI/CSS animations advance on the document timeline through hiddenness.
- Always timestamp-driven (`performance.now()`), never per-frame constants — 120Hz displays are common.

### 2.10 FLIP

- First-Last-Invert-Play: measure `getBoundingClientRect()` before mutation → mutate → measure → apply inverted `transform` → animate transform → `none` (WAAPI needs no double-rAF: the from-keyframe is explicit). Canonical: https://aerotwist.com/blog/flip-your-animations/
- Cost discipline: batch ALL reads, then ALL writes, then all last-measures (one forced layout total); interleaving = layout thrashing. A VDOM applier is perfectly placed to do this around patch application.
- Gotchas: scale-based size FLIP distorts children/text (counter-scale or animate real size); nested FLIP needs per-frame projection (why Framer Motion runs layout projection in JS); `transform-origin: 0 0` simplifies; borderRadius/boxShadow need per-frame correction (only Motion does it).
- FLIP is the portable answer to auto-size / position-change / reorder animation given §2.3 is Chromium-only and §2.7 is page-global.

### 2.11 Interruption semantics comparison

| Mechanism | On retarget | Velocity | Framework work |
|---|---|---|---|
| CSS transition | automatic from current computed value | lost (kink) | none — write the new value |
| CSS animation | none; restart from keyframe 0 (snap) | — | unsuitable |
| WAAPI replace | cancel (snap!) → read computed → new animate; or commitStyles+cancel | lost unless sampled | moderate; cancel-snap flash hazard |
| WAAPI additive | new delta→0 layer over retargeted underlying; layers sum, auto-replaced | perceptually preserved (C¹-ish) | low; underlying-value + layer hygiene |
| rAF spring | integrator gets new target | exact | highest: own loop, state, visibility |

SwiftUI-fidelity order: rAF spring > WAAPI additive > CSS transition > WAAPI replace.

### 2.12 Performance rules

- Compositor-only props: `transform`/`translate`/`rotate`/`scale` + `opacity` (all engines); `filter`/`backdrop-filter` accelerate on Chromium/WebKit but stay on Gecko's main thread (§2.5). Geometry props (`width/height/top/margin/gap/font-size`) = layout every frame on the main thread. Express motion as transforms whenever equivalent; FLIP converts layout deltas into transforms. The individual `translate`/`rotate`/`scale` properties additionally give per-channel animation composition — see §6.7.
- `will-change`: transient use only (set before, clear after); running compositor animations promote implicitly anyway. Layer explosion with hundreds of promoted elements = GPU memory.
- `content-visibility: auto` skipped subtrees: animations produce no frames, event/`getAnimations` behavior weird — don't orchestrate exits inside skipped subtrees.
- Inline styles / WAAPI effects = O(1)-ish invalidation; animating classes/custom props that many selectors read invalidates broadly.

### 2.13 prefers-reduced-motion

- `matchMedia("(prefers-reduced-motion: reduce)")` + `change` listener (live toggle). https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
- Policy guidance (https://web.dev/articles/prefers-reduced-motion): "reduce" ≠ "none" — replace movement with opacity cross-fades, cut durations to ~0–150ms; keep essential state-change motion as fades; completion callbacks must still fire (best: same orchestration with duration ≈ 0, else reduced-motion users get delayed UI state). Framework-emitted decorative CSS keyframes should sit in `@media (prefers-reduced-motion: no-preference)`.
- SwiftWUI: expose as an `EnvironmentSignals` value mirroring SwiftUI's `accessibilityReduceMotion` (recipe in §4.8).

### 2.14 End-detection reliability (CRITICAL for exit transitions)

Failure modes any "safe to remove node" logic MUST handle:
1. **No-op change ⇒ no event ever** (start==end, property not in transition-property, zero duration). Waiting on `transitionend` deadlocks. Detect: after style write + forced style resolution, check `el.getAnimations()` — none matching ⇒ finish immediately.
2. **`transitionend` fires per-property and per-longhand** (`margin` ⇒ 4 events) — count/filter by `propertyName`.
3. **Cancel paths** (`display:none`, retarget mid-flight, ancestor hidden) ⇒ `transitioncancel`, `transitionend` never fires — listen to both.
4. **Element removed from DOM ⇒ no events at all** (transitions just stop). Parent-level exit coordination must own removal exclusively.
5. **Hidden-tab throttling**: CSS/WAAPI animations advance on the timeline while hidden, but event delivery / promise resolution can be delayed seconds; exiting nodes linger. Mitigation: `visibilitychange` handler force-finishes pending exits.
6. **WAAPI advantage**: `anim.finished` resolves even after DOM detachment; rejects (AbortError) on `cancel()` — use `try/catch` / `allSettled`; never settles while paused or `iterations: Infinity`; `commitStyles()` throws on non-rendered targets.
7. **Belt-and-braces**: every event/promise exit races a `setTimeout(duration + delay + slack)` + the visibilitychange hook. Vue, React Transition Group, Svelte all do this; Vue additionally counts expected `transitionend`s parsed from computed style.

**Recommended exit primitive (2026)**: drive exits via WAAPI (`el.animate`) — unforgeable per-animation `finished`, timeline-based completion surviving detachment and tab hiding, deterministic cancel, `getAnimations({subtree:true})` aggregation — and keep the timeout race anyway.

### 2.15 Support matrix (July 2026)

| Feature | Chrome/Edge | Firefox | Safari | Baseline |
|---|---|---|---|---|
| WAAPI core + composite add + commitStyles | ✅ | ✅ | ✅ | core Widely; composite/commitStyles Newly 2022 → Widely 2025 |
| Individual `translate`/`rotate`/`scale` props | 104+ | 72+ | 14.1+ | Newly 2022 → Widely ~2025 |
| `linear()` easing | 113+ | 112+ | 17.2+ | Widely |
| `animation-composition` | 112+ | 115+ | 16+ | Widely (2023) |
| `@starting-style` / `allow-discrete` | 117+ | 129+ | 17.4/17.5+ | Newly (Aug 2024) |
| `@property` | 85+ | 128+ | 16.4+ | Newly (Jul 2024) |
| Same-doc View Transitions | 111+ | 144+ | 18+ | Newly (Oct 2025) |
| Cross-doc View Transitions | 126+ | ❌ in dev | 18.2+ | No |
| `interpolate-size` / `calc-size()` | 129+ | ❌ | ❌ | No |
| CSS `spring()` | ❌ | ❌ | ❌ (STP 2016) | No |
| CSS Typed OM | ✅ | ❌/partial | 16.4+ | No |

---

## 3. Prior-art pattern catalog

### 3.1 The cross-cutting patterns and who proved them

**(a) Model value vs presentation value — two disjoint families.**
1. *Presentation-in-platform* (Svelte transitions, Vue `<Transition>` classes, Motion's WAAPI path, Angular's new API, Tokamak): model state flips instantly; CSS/WAAPI owns the animated presentation. Cheap, interruption = platform concern; limited to CSS-expressible properties.
2. *Presentation-in-state* (svelte/motion `Spring`/`Tween`, react-spring, dioxus-motion, Flutter/Compose): an animator holds `current` vs `target` and writes `current` into state per frame. Fully general (animate anything, drive layout), pays per-frame framework cost — and in WASM, per-frame **bridge** cost.
SwiftUI is internally family 2 (attribute graph interpolates `animatableData` per frame) but its API doesn't force that implementation; Tokamak implemented the SwiftUI API with family-1 mechanics and it worked.

**(b) Who owns interpolation.** Compiler/CSS (Vue/Solid/Angular-new); framework *bakes* arbitrary code into platform playback (Svelte: user `css(t,u)` closure pre-sampled at ~60 points into WAAPI keyframes at trigger time — the sweet spot); runtime per-frame (react-spring, Flutter, dioxus-motion); **hybrid with acceleration fast-path** (Motion: WAAPI incl. `linear()` springs for transform/opacity/filter, rAF for the rest) = 2026 state of the art. Springs no longer need runtime physics on the hot path: simulate to rest once → duration + `linear()` string (https://developer.chrome.com/docs/css-ui/css-linear-easing-function , https://www.joshwcomeau.com/animation/linear-timing-function/).

**(c) Exit orchestration — the one thing the platform can't do for you.** Every framework invented "keep the node alive until the exit finishes":
- **Svelte 5** (source: https://github.com/sveltejs/svelte/blob/main/packages/svelte/src/internal/client/dom/elements/transitions.js): per-element `TransitionManager { in(), out(fn), stop() }` registered on the owning effect's node list; block destruction calls `out(fn)` on the whole subtree, actual removal runs only in `on_finish`; `element.inert = true` during outro; `outrostart/outroend` events. Docs: "all elements inside it are kept in the DOM until every transition in the block has been completed" (https://svelte.dev/docs/svelte/transition).
- **Vue** `<Transition>`: JS-hook `done()` callback contract, or `transitionend`/`animationend` counted per expected property (parsed from `getComputedStyle` durations) **with a `setTimeout(timeout+1)` fallback** (`whenTransitionEnds`, runtime-dom `Transition.ts`) (https://vuejs.org/guide/built-ins/transition.html). Two more Vue surface decisions worth keeping: `mode="out-in"` / `"in-out"` — declarative exit/enter **sequencing** for same-slot swaps, the most-used answer to the overlap problem (complements Motion's `sync`/`wait`/`popLayout` below; directly relevant to §6.1's zIndex/overlap story); and opt-in `appear` — transitions do NOT run on initial render unless requested, same default as SwiftUI (§6.5).
- **Motion AnimatePresence** (https://motion.dev/docs/react-animate-presence): diffs direct children by `key`; keeps rendering ghosts of removed children from its own state, flags them via PresenceContext, runs `exit`, removes when done. `usePresence() → [isPresent, safeToRemove]` — the framework asks "may I unmount you?", the node answers asynchronously. Modes `sync`/`wait`/`popLayout` (leavers `position:absolute`-popped so siblings reflow immediately).
- **Angular new API**: `animate.leave` adds a class and **delays DOM removal until `animationend`/`transitionend`** — that's the entire framework contract now (https://angular.dev/guide/legacy-animations).
- **Leptos** `<AnimatedShow>`: fixed `hide_delay` timer (must match CSS duration; fragile) (https://github.com/leptos-rs/leptos/issues/1370). **Tokamak**: `setTimeout(duration)`.
- Reliability ladder: WAAPI `Animation.finished` (exact) > end-events + timeout fallback (Vue) > pure timer (Tokamak/Leptos). If the framework starts the animation via WAAPI it gets `finished` for free — a strong argument for WAAPI-first.

**(d) FLIP is the universal layout/list answer.** Svelte `animate:flip` (only on keyed-each reorder; `(node, {from, to: DOMRect})` contract, distance-scaled duration `sqrt(d)*120` — https://svelte.dev/docs/svelte/animate), Vue `<TransitionGroup>` `v-move` class + the documented `.list-leave-active { position: absolute }` trick (https://vuejs.org/guide/built-ins/transition-group.html), Solid TransitionGroup `moveClass` (https://github.com/solidjs-community/solid-transition-group), Motion `layout`/`layoutId` (per-frame JS projection for nested scale correction — https://motion.dev/docs/react-layout-animations), leptos-animated-for (https://github.com/brofrain/leptos-animated-for). Identical skeleton: snapshot rects before mutation → mutate → measure → inverted transform → animate to identity. Requires keyed children + a "before mutation" hook in the reconciler + batched measurement.

**(e) Spring configuration surfaces.** Physics tuples (`stiffness/damping/mass/velocity`: Motion, react-spring, dioxus-motion, SwiftUI `interpolatingSpring`); normalized feel params (Svelte 0..1; SwiftUI `response/dampingFraction` and the designer-friendly iOS-17 `duration/bounce`); presets everywhere (`smooth/snappy/bouncy`; react-spring `gentle/wobbly/stiff`). All implementations reduce to: solve to rest → run per-frame OR bake to keyframes/`linear()`.

**(f) Detecting "what changed in this update".**
- *VDOM prop diffing at commit* (Motion `animate` prop → per-`MotionValue` diff, animations write DOM directly bypassing React render; Tokamak threads `Transaction` into the renderer's `update()`).
- *Structural events only* (Svelte/Vue/Solid/Angular): enter/leave/move are the animated events; attribute changes are never implicitly animated — users write CSS `transition:` for those (the platform's own value-diff detector).
- *Value-level*: `.animation(_:value:)` can literally compile to a `transition: <props> <dur> <easing>` declaration and let the browser detect per-property changes — IF the change manifests as an inline-style/class diff on that element.
- SwiftUI's triggers reduce, at reconciler level, to: "this patch batch carries an Animation; for each changed animatable style, start/retarget an animation instead of a plain write".

### 3.2 Framework-specific highlights worth stealing

- **Svelte bidirectional interruption**: on re-toggle mid-outro, the new animation reads the counterpart's progress `t1` (from a WAAPI `currentTime`), aborts it, and animates `t1 → t2` with `duration * |t2 − t1|`, caching the resolved config "so reversible transitions reverse smoothly". Also its `delay` implementation: a dummy `element.animate(…, {duration: delay})` that simultaneously defers keyframe generation until post-update layout.
- **Svelte deferred transitions** (`crossfade` send/receive): if a transition function returns a function, the runtime waits a microtask so both counterpart elements exist, then measures both rects — the shared-element recipe without View Transitions.
- **Vue's class-swap dance** (the canonical CSS-transition enter): `-from` + `-active` applied *before* insertion → forced reflow → next-frame (nested rAF) swap `-from`→`-to` → cleanup on end. Any CSS-first architecture replicates this or uses `@starting-style`.
- **Motion's hybrid routing**: per-value engine selection (WAAPI for compositable, rAF for the rest and non-DOM targets); independent `x/scaleX/rotate` composed into one `transform` (raw WAAPI can't per-axis); interruption = read live value (+ analytic velocity for springs), cancel, restart from live state; avoids fill-mode traps by committing target styles.
- **react-spring**: duration-less physics on a shared rAF `FrameLoop`; `animated.div` writes styles directly to DOM each frame **without React re-render** — if SwiftWUI ever adds a rAF path, it must equally bypass the reconciler per frame (https://blog.logrocket.com/animations-with-react-spring/ , https://github.com/pmndrs/react-spring/issues/799).
- **React `<ViewTransition>`** (experimental, canary-only July 2026): React calls `document.startViewTransition` itself, auto-assigns names, detects enter/exit/update/share triggers, batches renders landing during an active transition; classes map trigger→`::view-transition-*` styling; only activates inside `startTransition`/Suspense (https://react.dev/reference/react/ViewTransition , https://react.dev/reference/react/addTransitionType , https://react.dev/blog/2025/04/23/react-labs-view-transitions-activity-and-more , https://rebeccamdeprey.com/blog/view-transition-api). Pattern to study for a later route-transition/MGE layer, not for core.
- **Angular — the cautionary tale**: the largest framework that tried "animation as compiled framework metadata → runtime WAAPI engine" (`trigger/state/transition/animate` DSL) **deprecated it in v20.2 (Aug 2025), removal v23**, replaced by `animate.enter`/`animate.leave` class hooks + native CSS (`@starting-style`), with `Element.getAnimations()` replacing `AnimationPlayer` (https://angular.dev/guide/animations/migration , https://blog.ninja-squad.com/2025/08/20/what-is-new-angular-20.2). Lesson: keep the framework's job to *orchestration* (enter/leave, deferred removal, what-changed detection); let the platform own interpolation.
- **Flutter web / Compose Multiplatform — the opposite pole**: per-frame `Ticker` → tween → rebuild → canvas repaint (Skia/canvaskit/skwasm); HTML renderer deprecated 2024, removed in Flutter 3.29 (Feb 2025) (https://docs.flutter.dev/platform-integration/web/renderers , https://github.com/flutter/flutter/issues/145954). Full fidelity, but it pays per-frame cost inside its own memory with ONE surface flush per frame — a DOM framework doing per-frame WASM→JS style writes for N nodes recreates the cost without the control. Compose HTML has **no** animation system at all; Kobweb filled the gap with typed CSS generation (https://github.com/varabyte/kobweb , https://bitspittle.dev/blog/2022/kotlin-site , FLIP still an open discussion https://github.com/varabyte/kobweb/discussions/440).
- **Rust/WASM lesson** (Leptos/Dioxus/Yew): dioxus-motion runs per-frame integration in Rust writing a signal → re-render → diff → bridge write per frame — the expensive shape, fine for one value, scales badly (https://github.com/wheregmis/dioxus-motion , https://wheregmis.github.io/dioxus-motion/); leptos-motion claims a Motion-style hybrid (https://github.com/cloud-shuttle/leptos-motion). **Nobody ships rAF-through-the-bridge as the primary mechanism**; every serious attempt either toggles CSS classes and sleeps, or rebuilds a Motion-style hybrid whose fast path is still WAAPI.

### 3.3 Tokamak — the direct SwiftUI-on-WASM precedent (archived; source read)

https://github.com/TokamakUI/Tokamak (SwiftUI-compatible, JavaScriptKit — same stack as SwiftWUI v1). Proved the whole SwiftUI surface is portable to DOM+WASM:
- `Sources/TokamakCore/Animation/`: `Animation` (curves, springs, `.delay/.speed/.repeatCount/.repeatForever`), `Transaction` with a static `Transaction._active` set for the duration of the `withAnimation` body and read at state-write time; `.animation(_:)` as a `_TransactionModifier` (`if !t.disablesAnimations { t.animation = a }`); `VectorArithmetic`/`Animatable`/`AnimatableModifier`; `_AnimationSolvers.Spring` closed-form solution used to compute spring **duration**.
- DOM mapping (`TokamakDOM/DOMNode.swift`): animated updates route through `update(..., transaction:)` — if the transaction has an animation and `style` changed → `animateStyles`: snapshot current styles, set target `cssText`, then **WAAPI** `ref.animate([start, end], { duration, delay, easing: cubic-bezier | linear, iterations, direction, fill: "both" })`. Springs used a horrific ~100-forced-recalc keyframe-resampling hack — **obsoleted today by `linear()` easing**.
- `.transition(...)`: modifiers producing an *active/identity attribute pair* (exactly SwiftUI's `.modifier(active:identity:)` primitive). Insert: render with active attrs, immediately update to identity under the transaction animation. Remove: apply active with animation, then **`setTimeout(duration) { parent.removeChild(target) }`** — timer-based exit (fragile vs `finished`).
- Interruption: `ref.getAnimations().forEach { $0.cancel() }` before non-animated updates — cancel-and-jump, no velocity carry. Crude vs Motion/Svelte.
- Takeaway: Transaction/withAnimation/Animatable/.transition all port cleanly; the three weak points (spring sampling, timer exits, cancel-snap interruption) each have a 2026 platform fix (`linear()`, `Animation.finished`, additive composition).
- SwiftWebUI (https://github.com/SwiftWebUI/SwiftWebUI): no animation support at all; only the negative result that server-driven diffing makes timing ownership awkward.

---

## 4. SwiftWUI integration map

From codebase reconnaissance (all read from source, branch `main`).

### 4.1 Pipeline and the transaction seam

`Tag` → `resolve()` → `[Node]` → `Reconciler.diff` → `[Patch]` → `TreeApplier.apply` → `RendererBackend` calls.

- Component resolution: `resolve<T: Tag>` Sources/SwiftWUI/Runtime/Resolver.swift:45 — identity mint :50, retain :53, `@State` graft via `StateStore.link` :56, body under `withObservationTracking` :67–72. Elements: `resolveElement` Resolver.swift:102–152 (listeners :115–121, observers :123–137, style-rule classes :140–144, `Styled` scope class :145–147).
- **@State write → flush chain**: `State.wrappedValue.set` → `slot.box.invalidate?()` (Sources/SwiftWUI/State/State.swift:51–57; Binding :59–64) → bound in `StateStore.link` (Sources/SwiftWUI/State/StateStore.swift:120–124) → `Runtime.markDirty(id)` — **Runtime.swift:89–96**: asserts `!isRendering`, inserts into `dirty`, schedules one microtask flush. **This is the exact seam to capture a `withAnimation` transaction**: at markDirty time the ambient transaction (a MainActor slot set/cleared around the closure) is in scope; stash it as `pendingTransaction` alongside `dirty`, consume in `flush()` (Runtime.swift:148–160), thread into the pass. Everything is single-threaded `@MainActor` (Package.swift:18,20,43 `.defaultIsolation(MainActor.self)`), so a plain var is safe; the spec's "no globals" rule governs the resolve pipeline, and SwiftUI itself uses an ambient Transaction. Tokamak's `Transaction._active` is the precedent.
- `ResolveContext` (Resolver.swift:10–42) is a struct built fresh per pass (renderPass Runtime.swift:251, subtreePass :176) — a `transaction` field is trivially addable, but the timing rule stands: **capture at markDirty time, inject at flush time**, because `withAnimation` runs at event-handler time (`Runtime.dispatch` Runtime.swift:85–87, synchronous; flush on the next microtask; multiple writes coalesce — matching SwiftUI's one-transaction-per-update).
- Per-pass order in `renderPass` (Runtime.swift:249–294): resolve+link → **sweep state & listeners (:271–272)** → diff (:275) → apply (:276) → commit (:284) → stylesheet flush (:286–289) → `EffectStore.reconcile` post-commit (:291–292). **Sweep runs BEFORE apply** — state/listeners of removed subtrees are gone before their DOM nodes are removed (§6.1).
- Scheduler: only `scheduleMicrotask` exists, injected at `Runtime.init` (Runtime.swift:63); DOM impl = `queueMicrotask` + `JSOneshotClosure` (Sources/SwiftWUIDOM/DOMRuntime.swift:23–28); tests use `TestScheduler` manual pump (Tests/SwiftWUITests/RuntimeE2ETests.swift:42–46). An animation system needing time wants a similarly injected clock.
- **`markDirty` asserts no writes during body eval** (Runtime.swift:90) — `withAnimation` is handler/effect-only, as in SwiftUI.
- **Two render paths must stay equivalent** ("scoped ≡ full", Runtime.swift:186–208): whatever `withAnimation`/`.animation` does must behave identically under `renderPass` and `subtreePass`; wrappers that post-transform resolved nodes must stash/replay like `_StyledTag` does via `RetainedComponent.styleWrappers` (StateStore.swift:10–19, 61–71; Runtime.swift:196–208).

### 4.2 Node model, patches, and the style-string problem

- `Node` enum — Sources/SwiftWUI/Tree/Node.swift:30; `ElementNode` :12 (identity, tag, `attributes: [String:String]`, properties, listeners, observers, children, key); `ComponentNode` :23 (transparent — no wrapper DOM element).
- **Inline styles are pre-flattened into the `style` attribute string** (`_AttributeBag.flattened()` Sources/SwiftWUI/HTML/AttributeBag.swift:66–79, `mergeStyleText` :82–92 last-wins; `_StyledTag.applyStyleWrapper` Sources/SwiftWUI/Styles/StyledTag.swift:62–87 string-merges into `attributes["style"]`). The reconciler sees ONE opaque string; any style change = one `setAttribute("style", fullText)` (Reconciler.swift:48–53 → DOMBackend.swift:60–62). Consequences: (a) a WAAPI/transition engine that must know *which properties changed* needs per-property diffing — either parse old/new style strings at animation time or restructure the node model to a typed style map; (b) an animator writing `element.style.transform` imperatively gets clobbered by the next full `setAttribute("style", …)` (§6.6).
- Patch ops — Sources/SwiftWUI/Render/Reconciler.swift:1–32: `setText/setAttribute/removeAttribute/setProperty/setListener/removeListener/setObserver/removeObserver/replaceSelf/updateChildren(ChildrenPlan)`. `ChildrenPlan` (Reconciler.swift:14–20): `Slot.reuse(oldIndex:patches:)` / `Slot.fresh(Node)`; **removals = `removedOldIndices`** — the `.transition()` trigger point; moves detected in the applier as out-of-order reuse.
- `diffChildren` Reconciler.swift:107–170: prefix/suffix trim by `sameIdentity` (:98–105), keyed map + positional matching, unmatched old → `removedOldIndices` (:168).
- Structural identity signals: `ConditionalTag._resolve` appends `.branch(true/false)` (Sources/SwiftWUI/Core/Primitives.swift:35–41), `Optional` :44–51, `ForEach` `.keyed(key)` + `node.key` (Sources/SwiftWUI/Core/ForEach.swift:20–43) — `if show { X() }` and keyed list edits surface as exactly the fresh/removed plan entries a transition system needs. `NodeIdentity` segments — Sources/SwiftWUI/Identity/Identity.swift:6–24; prefix compare `isSelfOrDescendant(of:)` :20–23.

### 4.3 TreeApplier — mount/unmount/move, no deferral anywhere

- Shadow tree `MountedNode` (TreeApplier.swift:3–15), `componentIndex` :24. `mount` :33–78 (create → attrs → props → listeners → observers → `backend.insert`). `unmount` :80–100: unregister → `tearDownListeners` (bottom-up backend detach :90–96) → `removeHosts` (`backend.remove` per realized root). **Removal is synchronous and immediate — no deferred-removal concept exists.** An exit animation must either intercept `removedOldIndices` before `unmount`, or wrap the backend `remove` call.
- `apply` :126–156 → `applyChildren` :178–220: **removals first** (:182 `for i in plan.removedOldIndices { unmount(oldChildren[i]) }`), then slots realize right-to-left with anchor threading; out-of-order reuse → `moveHosts` :222–226 (DOM `insertBefore` of an attached node *moves* it, "preserves focus/scroll/animations" — phase-1 spec docs/superpowers/specs/2026-07-02-phase1-core-design.md:623). `moveHosts` is the single choke point for a future FLIP hook; **no rect measurement exists anywhere**.
- `replaceSelf` mounts-before-unmount purely for anchor correctness (:162–173).
- Unmount bookkeeping: `ListenerRegistry.sweep` (Sources/SwiftWUI/Runtime/ListenerRegistry.swift:12–17; called Runtime.swift:211/272), `StateStore.sweep` (StateStore.swift:127–136) — **@State of a removed component is dropped the moment the removing pass commits**; `EffectStore.reconcile` (Sources/SwiftWUI/Effects/EffectStore.swift:95–152) cancels tasks and queues `onDisappear` (:102–108) — which today **fires AFTER the DOM node is already removed**. `.appear` fires once per identity insert (:141–142). The appear/disappear machinery is the closest existing analog to enter/exit transitions; `EffectRequest.onChange` already stores `previousValues[id]` with equality compare (EffectStore.swift:112–118) — exactly the mechanism `.animation(_:value:)` needs.

### 4.4 RendererBackend — the extension recipe

Protocol — Sources/SwiftWUI/Render/RendererBackend.swift:3–69 (createElement/setAttribute/insert/remove/setStylesheet/observe/history/hydration-reads/env-storage-window observation…). **Precedent: new capabilities land as protocol requirements with no-op defaults** (extension :71–80) so MockBackend/HTMLRenderer keep compiling. The observer pipeline is the end-to-end model to copy for animation capabilities: `bag.addObserver` → `resolveElement` registers `ListenerID(owner: path, event: kind.key)` (Resolver.swift:123–137) → `ElementNode.observers` → diff emits `setObserver/removeObserver` (Reconciler.swift:70–77) → applier calls `backend.observe/unobserve` + tracks for unmount (TreeApplier.swift:52–54, 144–149, 94) → DOMBackend builds IntersectionObserver/ResizeObserver, retains `JSClosure`s keyed `"\(uid)#\(kind.key)"`, fire-time ListenerID lookup (DOMBackend.swift:162–205).

- `MockBackend` (Sources/SwiftWUI/Render/MockBackend.swift): full `MockNode` tree (:1–11), **`counts: [String:Int]` bumps every primitive call** (:19–21) — tests assert churn (Tests/SwiftWUITests/ApplierTests.swift:77–94; AdoptionTests.swift:37–39) and `serializeHTML()` cross-checks vs `HTMLRenderer` (:128–156). Animation calls recorded here = deterministic native tests with zero clock.
- `AdoptingBackend<Base>` (Sources/SwiftWUI/Render/AdoptingBackend.swift:33+) is a **decorator backend** (wraps base, intercepts create/insert during hydration) — precedent for an "AnimatingBackend" decorator that defers `remove` / wraps `mount`, should that route be chosen.
- `HTMLRenderer` (Sources/SwiftWUI/Render/HTMLRenderer.swift:4–17) is a pure `Node → String` fold with a throwaway store — **SSG neutrality requirement: animations must contribute nothing there** (final values, no animation).

### 4.5 SwiftWUIDOM specifics / bridge cost

- `HostNode = JSObject` (DOMBackend.swift:13–14); nodes stamped `__swuid` at creation (:49, :54); retention dictionaries keyed `"\(uid)#\(event)"` — never `ObjectIdentifier(JSObject)` (:10–11, CLAUDE.md).
- **BridgeJS vendored surface is tiny and structural-only** — Sources/SwiftWUIDOM/bridge-js.global.d.ts: `SWNode { data; appendChild; insertBefore; removeChild; setAttribute; removeAttribute }`, `SWDocument`, `document`, typed `fetch`. Adding typed `element.animate()` = edit d.ts + regen (`swift package plugin --allow-writing-to-package-directory bridge-js --target SwiftWUIDOM`); or start with dynamic `JSObject` (`node.animate?(keyframes, opts)`) — the fast-path/dynamic split is per-call-site by policy (d.ts header lines 1–3).
- JSClosure lifetime: retain for the attachment's life, remove with the same function object (DOMBackend.swift:75–94, 155–160); `JSOneshotClosure` for promise callbacks / one-shots (DOMRuntime.swift:24, DOMBackend.swift:313, 338, 365) — a WAAPI `finished` continuation fits `JSOneshotClosure` exactly.
- **No `requestAnimationFrame` anywhere in Sources**; `setTimeout` used once (FetchJSTransport.swift:42); delayed work idiom = `Task.sleep(for:)` on MainActor (`onLongPress`, InteractionModifiers.swift:61–79) — fine for exit-timeout races, wrong for frame-locked animation. Bridge-cost note in-source: dynamic JSObject getter = "two bridge crossings and a fresh handle per call" (DOMBackend.swift:17–20). Declarative CSS/WAAPI handoff = zero per-frame traffic; Swift-driven per-frame writes = the expensive design.
- `EventName` is string-backed (EventName.swift:5–20); `transitionend`/`animationend` not predefined but reachable via `HTMLTag.on(EventName("transitionend"))` (HTMLTag.swift:20–26) — though backend-internal listeners outside the registry are the better fit for framework-owned end detection.

### 4.6 Styles / classes / StyleRegistry constraints

- Three channels to the DOM (§4.2 for inline): compiled classes via `StyleRegistry` (Sources/SwiftWUI/Styles/StyleRegistry.swift; FNV-1a dedup, class `swui-<hash36>` :21–23), `Styled` scope class per component (Resolver.swift:74–77, Styled.swift:18–20); stylesheet flush rewrites the whole managed `<style>` (`Runtime.swift:217–220`, :286–289; DOMBackend.swift:221–237).
- **`registerRaw(text)` (StyleRegistry.swift:70–72) is the only path permitting braces** — `@keyframes` blocks and `@starting-style` rules can ride it (themes/FontFace precedent — Theme.swift:52–56); `CSSSanitize.isSafeValue` forbids `{}` in declaration values (CSSValues.swift:151–154).
- **Registry is add-only, never removed** (StyleRegistry.swift:1–3) — per-animation dynamic keyframes accumulate; hash dedup mitigates identical curves, but truly dynamic values (measured px heights) would leak entries.
- **Name collision**: `.transition(_ v: String)` already exists as the raw CSS property modifier — Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift:76 (Tag path) and :154 (collapse path). A SwiftUI-style `.transition(AnyTransition)` overload must coexist or the CSS one gets renamed.
- Attr-name validation `[a-zA-Z_:][a-zA-Z0-9_.:-]*` (AttributeBag.swift:95–106).

### 4.7 Where `.animation(_:value:)` slots into modifier infra

- Three modifier storage mechanisms exist (Sources/SwiftWUI/Core/TagModifier.swift:6–10; ModifiedTag `_resolve` :29–55 — a component boundary that mints a `.type` identity segment but deliberately preserves `ctx.scopeClass` :43–44):
  1. attribute-bag (HTMLTag-only, `Self`-returning, no identity impact) — events/observers/inline styles;
  2. **primitive wrapper structs** (any Tag, one `.type` segment): `_StyledTag`, `_AppearEffect`/`_TaskEffect`/`_OnChangeEffect` (Sources/SwiftWUI/Effects/EffectModifiers.swift:1–46), `_WindowEventEffect`, `_EnvironmentWriter`;
  3. `ModifiedTag` for user modifiers with state.
- `.animation(_:value:)` most naturally = pattern 2: a wrapper that (a) stores the previous `value` EffectStore-style and, when changed, marks the subtree for this pass's transaction, and/or (b) applies CSS `transition:` declarations to element roots the way `applyStyleWrapper` does — **with the subtree-pass stash/replay caveat** (`RetainedComponent.styleWrappers` precedent, §4.1). Element-root semantics inherited from `applyStyleWrapper` (descends transparent component roots, skips text — StyledTag.swift:62–87).
- Any identity-persistent animation state (running-animation table, previous values, exit registrations) must live in a store keyed by `NodeIdentity` — the 4th such store on `Runtime` (fields at Runtime.swift:5–11) after StateStore/EffectStore/ListenerRegistry.

### 4.8 prefers-reduced-motion recipe

Copy the colorScheme pipeline exactly: add `reducedMotion: Bool` to `EnvironmentSignals` (Sources/SwiftWUI/Environment/EnvironmentSignals.swift:13–17) + `Writer` (:26–35), one `matchMedia("(prefers-reduced-motion: reduce)")` block in `beginEnvironmentObservation` (DOMBackend.swift:275–285) + symmetric detach in `endEnvironmentObservation` (DOMBackend.swift:401–434). Env key as computed property (EnvironmentValues.colorScheme precedent :48). CSS side already has `MediaQuery.custom("(prefers-reduced-motion: reduce)")` (MediaQuery.swift:11–17). The engine reads it untracked at transaction time (fine — signal writes only auto-rerender body readers, per CLAUDE.md).

### 4.9 Docs status

Animation was explicitly deferred: phase-3 styles spec "Out (deferred): animations/transitions API and keyframes" (docs/superpowers/specs/2026-07-03-phase3-styles-design.md:19–20; string `transition` factory :81, :308); phase-2 "animations/transactions → not planned" (docs/superpowers/specs/2026-07-03-phase2-reactivity-design.md:28, :392). No `withAnimation`/`requestAnimationFrame`/`keyframes` identifiers exist anywhere in Sources/. This is a new post-phase-8 spec.

---

## 5. Candidate architectures

Shared skeleton assumed by all candidates (from §4): ambient MainActor `Transaction` slot set by `withAnimation`; captured at `Runtime.markDirty` (Runtime.swift:89); consumed in `flush()`; threaded to the applier for that one pass; `.animation(_:value:)` as a primitive wrapper overriding the transaction for its subtree (nearest-wins); `.transition(AnyTransition)` registered per `NodeIdentity`, consulted at `ChildrenPlan.fresh`/`removedOldIndices` execution AND at `replaceSelf` (same-position identity swap = simultaneous exit+enter — §6.1); `prefers-reduced-motion` signal gating the engine; SSG/HTMLRenderer contributes final values only.

### A. CSS-transition-first ("Vue/Angular-new shape")

Backend receives style diffs plus a transaction hint; interpolation is 100% browser-owned CSS transitions.

- **withAnimation**: applier, for each element patch under an active transaction, has the backend ensure a `transition: <props or all> <duration> <easing>` declaration is present on the element *in the same style write* as the new values (transitions trigger off the post-change style, and existing elements already render the old value — no double-rAF needed for updates). Cleanup: remove/neutralize the transition declaration on end or leave it standing until the next non-animated pass.
- **.animation(_:value:)**: compiles to a standing `transition:` declaration on subtree element roots via the `applyStyleWrapper` mechanism — the browser itself is the per-property change detector (§3.1f). Cheapest possible implementation; value-gating done Swift-side (only emit/refresh the declaration when `value` changed, else emit `transition: none`... which itself is a diff — see gap below).
- **.transition (enter)**: `@starting-style` rules via `StyleRegistry.registerRaw` + a per-transition class on fresh mounts; or the Vue class-swap dance driven by the backend. **(exit)**: intercept `removedOldIndices`, keep the node, apply exit class/styles, wait `transitionend` counted per property + timeout race + visibilitychange, then `backend.remove`.
- **Interruption**: position-continuity and exact-reversal shortening free (§2.1); **velocity always lost** — the kink is visible with eased curves; no additive composition.
- **Springs**: `linear()` spring string in `transition-timing-function` — works everywhere (§2.6a); retarget restarts the baked curve with v₀=0.
- **Exit story**: weakest of all candidates — transitionend per-property counting, no-op-change deadlocks, removed-element silence (§2.14 items 1–4) all land on the framework.
- **MockBackend testability**: good-ish — assert the transition declaration text landed in `setAttribute("style", …)`; exit orchestration testable only by simulating end events; no animation-object surface to assert.
- **Bridge cost**: essentially zero beyond today's writes.
- **Fidelity gaps**: no velocity retarget; no additivity; no repeat/repeatForever (transitions can't loop); no completion aggregation primitive (must be synthesized from counted events); `transition: all` under `withAnimation` animates unintended properties incl. layout props on the main thread; per-pass "arm then disarm" of transition declarations churns the style string; `.animation(nil)`/`disablesAnimations` need careful disarm semantics.
- **Internal inconsistency (decisive against A for `.animation(_:value:)`)**: a *standing* `transition:` declaration means the **browser** animates any style-recalc delta on those properties from ANY cause between `value` changes — theme/class swaps, hydration corrections, unrelated state writes hitting the same element — which is exactly the deprecated valueless `.animation(_:)` semantics that §1.3/§1.10 explicitly ban ("flying views"). Swift-side arm/disarm narrows but cannot close the window: the declaration must already be present at the moment an unrelated recalc lands, and disarming only happens on a later pass. A faithful `.animation(_:value:)` therefore cannot be a standing CSS declaration; it must gate per-pass like B/D. This materially changes the A-vs-B/D comparison (see table).

### B. WAAPI-driven engine ("Motion/Tokamak-2026 shape")

Swift computes per-property keyframes + timing (springs baked to `linear()` easing or sampled keyframes); backend calls `element.animate` via bridge; model value (inline style) always written to the **final** target immediately; animations are presentation layers on top.

- **withAnimation**: reconciler/applier per-property-diffs the style change (requires parsing old/new style strings or a typed style map — §6.6); for each changed animatable property: write final value + `backend.animate(host, keyframes, timing)`. Two sub-modes: *replace* (implicit-from or explicit from = old value) or **additive** (delta→0 with `composite: "add"` over the final underlying value — structurally identical to SwiftUI's additive scheme, §2.5). Non-animatable changes apply instantly. Completion = aggregate the pass's `finished` promises → `withAnimation` completion callback.
- **.animation(_:value:)**: wrapper stores previous `value` (EffectStore `previousValues` pattern); when changed, stamps its subtree's patches with the animation for this pass (overriding the ambient transaction — nearest-wins falls out of resolve-order).
- **.transition**: enter = mount, then `animate` from the transition's *active* style to *identity* (Tokamak's attribute-pair model, = SwiftUI's `.modifier(active:identity:)`); exit = defer `unmount`, `animate` to active style, `await finished` raced with timeout + visibilitychange, then remove. `getAnimations({subtree:true})` aggregates nested exits.
- **Interruption**: additive mode = smooth perceptual velocity for free with engine-side auto-replacement hygiene; or keep curve+startTime metadata Swift-side and retarget springs analytically with exact `initialVelocity` (§2.8). Both beat CSS transitions; the analytic path reaches near-SwiftUI spring fidelity. Cancel/retarget/force-finish all presuppose a **per-animation handle registry**: `(NodeIdentity × property) → (JS Animation handle, curve + from/to + startTime metadata)` — one more identity-keyed store on `Runtime` (the running-animation table anticipated in §4.7, joining StateStore/EffectStore/ListenerRegistry/exit-registry), swept when exits complete.
- **Springs**: first-class — Swift-side closed-form solver produces `(durationMs, linear(...) string)` or keyframes; `duration/bounce` + `smooth/snappy/bouncy` presets map directly; solver is pure math, natively unit-testable.
- **MockBackend testability**: excellent — `animate(host:keyframes:timing:)` recorded as typed values; tests assert exact keyframes/curves/durations with no clock; exit deferral driven by manually completing recorded animation handles.
- **Bridge cost**: one call per animated property change + one `JSOneshotClosure` completion; zero per-frame. Dynamic `JSObject.animate` first, typed BridgeJS later if hot.
- **Fidelity gaps**: CSS-expressible properties only (no custom `Animatable` data, no animated text content); layout/reflow animation not covered (needs FLIP); repeat/delay/speed map to WAAPI options natively (better than A); interruption is very good but not physically exact in additive mode.

### C. Swift-side presentation tree + rAF ticker ("Flutter/dioxus-motion shape")

Full `Animatable`/`VectorArithmetic` port; an `AnimationScheduler` ticks on rAF; per-frame interpolated values written as style updates through the backend.

- **withAnimation / .animation / .transition**: all map 1:1 to SwiftUI semantics — per-attribute model/presentation forks, `CustomAnimation.animate(value:time:context:)` protocol verbatim (§1.6), additive timing curves and merging springs implemented exactly, transitions = animating the active↔identity modifier pair per frame.
- **Interruption**: exact — the integrator owns position and velocity.
- **Springs**: true physics, gesture handoff possible.
- **Exit story**: engine owns time, so deferral is trivial (tick until done, then remove) — but hidden-tab rAF pause freezes exits (must clamp Δt and force-finish on `visibilitychange`).
- **MockBackend testability**: excellent with an injected clock (TestScheduler precedent) — fully deterministic frame-by-frame assertions.
- **Bridge cost**: the killer — N properties × 60–120fps wasm→JS style writes; per-frame style-string re-merge or direct `style.setProperty` racing the differ (§6.6); no compositor offload ever; main-thread contention with the reconciler; every serious WASM framework rejected this as the primary mechanism (§3.2 Rust lesson; Flutter pays this only inside its own memory with one surface flush).
- **Fidelity gaps**: none semantically; everything practically (perf, battery, hidden tabs).

### D. Hybrid: WAAPI core + FLIP layout + CSS declarative layer (recommended shape)

B as the engine, plus targeted additions; mirrors Motion's production architecture and the Angular lesson (framework orchestrates, platform interpolates), with C's machinery deferred to an optional later escape hatch.

- **withAnimation**: as B (per-property WAAPI, additive retarget, aggregated completion). Layout-affecting changes (position/size caused by reflow) handled by **FLIP over the patch cycle**: applier measures rects of animation-eligible hosts before applying the plan (batch reads), applies patches (writes), measures after (one layout flush), emits inverted-transform WAAPI animations — hooking `moveHosts` (TreeApplier.swift:222–226) for reorders and the same measurement pass for size changes. `interpolate-size: allow-keywords` sprinkled at `:root` as free Chromium enhancement.
- **.animation(_:value:)**: as B; optionally *also* compile simple cases to standing CSS `transition:` declarations for zero-JS SSG'd pages (progressive layer, not the engine).
- **.transition**: as B (active/identity pairs, WAAPI enter+exit, deferred removal via `finished` + timeout + visibilitychange); `@starting-style` used for SSG/no-JS enter effects only.
- **Interruption**: additive WAAPI default; per-animation curve metadata retained Swift-side enabling analytic velocity retarget for merging springs (`.spring` semantics) vs additive for curves/`interpolatingSpring` — matching SwiftUI's split (§1.5) as closely as the platform allows.
- **Springs**: Swift solver → `linear()` (shared with any CSS layer) — unit-tested pure math.
- **Exit story**: the §2.14 recommended primitive, plus Svelte-style `inert` on exiting subtrees and Vue/Motion `position:absolute` pop-out as a transition option so siblings reflow (pairs with FLIP).
- **MockBackend testability**: B's typed `animate` recording + recorded measure/FLIP calls (Mock returns scripted rects).
- **Bridge cost**: B's near-zero steady-state; FLIP adds 2 batched measurement passes per animated-layout flush (bounded, read-coalesced).
- **Fidelity gaps**: custom `Animatable`/animated non-CSS values still out (future rAF escape hatch); nested-FLIP scale correction imperfect without per-frame projection (accept Svelte/Vue-level quality, not Motion-level); View Transitions reserved as a separate opt-in for route transitions / future `matchedGeometryEffect`.
- **Phasing note**: D minus FLIP == B; FLIP can be a follow-up phase without reworking the engine. That makes B→D an incremental path, not a fork.

### (Non-candidate) View-Transitions-first

Rejected as the core engine: page-global snapshotting, one-at-a-time, input frozen, old content static (§2.7). Retained as a later opt-in layer for route transitions and MGE-style morphs (React `<ViewTransition>` is the pattern to study, §3.2).

### Comparison table

| | A: CSS-first | B: WAAPI | C: Swift rAF | D: Hybrid |
|---|---|---|---|---|
| withAnimation fidelity | medium (all-or-listed props) | high | exact | high |
| `.animation(value:)` semantics | ✗ standing `transition:` = banned valueless-`.animation` behavior (§5.A) | exact (per-pass stamping) | exact | exact |
| Retarget velocity | none | additive/analytic | exact | additive/analytic |
| Mid-exit re-entry / bidirectional interruption (§6.1) | ✗ no handle to reverse; class re-dance | needs exit+enter registry, reversal unspecified | natural (engine owns state) | needs exit+enter registry, reversal unspecified |
| Springs | linear() baked | linear() + metadata | true physics | linear() + metadata |
| Exit reliability | transitionend counting (fragile) | `finished` (robust) | engine-owned | `finished` (robust) |
| Layout animation | interpolate-size only (Chromium) | none | possible but $$$ | FLIP |
| Repeat/loop | ✗ (transitions can't) | ✓ WAAPI options | ✓ | ✓ |
| Completion aggregation | synthesized | Promise.all of finished | native | Promise.all |
| MockBackend tests | style-string asserts | typed animate records | injected clock | typed + rects |
| Bridge cost | ~0 | 1 call/anim | N×fps | 1 call/anim + 2 reads/flush |
| Perf under main-thread load | compositor ✓ | compositor ✓ | ✗ | compositor ✓ |
| Custom Animatable | ✗ | ✗ | ✓ | later hatch |

---

## 6. Hard problems register

### 6.1 Exit orchestration + safe DOM removal

- **Sweep-before-apply ordering** (Runtime.swift:271–272 before :276): state, listeners, and effects of the exiting subtree are already gone when its DOM would start an exit animation. Options: (a) accept — exiting DOM is a non-interactive corpse (set `inert`, Svelte precedent) whose listeners are dead anyway (fire-time ListenerRegistry lookup misses → no-op); (b) keep identities reachable until exit completes (delays `StateStore.sweep` — invasive, interacts with re-insertion). SwiftUI keeps the removed view *rendered and receiving frames* but its interactivity during removal is also limited — (a) is defensible.
- **`onDisappear` currently fires after DOM removal** (EffectStore.swift:102–108, post-commit) — with deferred removal, does it fire at exit-start (matching state sweep) or exit-end (matching DOM)? SwiftUI fires `onDisappear` when the view is removed from the hierarchy (exit-start-ish). Must be specified.
- **Bidirectional interruption — BOTH directions**: (a) *re-insertion during exit* (toggle back mid-outro): identity reappears while its ghost is still exiting — Svelte reverses in place (`t1 → t2`, shortened duration); naive designs mount a duplicate next to the ghost; requires an exit-registry keyed by `NodeIdentity` consulted at mount time. (b) *removal during enter* (the mirror case): a node deleted while its enter transition runs needs that enter animation tracked, cancelled, and the exit taken over from the **current presentation state**, not from the identity endpoint — Svelte's `t1 → t2` mechanism handles both directions symmetrically (§3.2). Consequence: the registry must track *enter* animations too, not just exits. No candidate in §5 currently specifies the reversal mechanics (see comparison-table row).
- **Parent unmount racing child exit**: removal of an ancestor must force-finish descendant exits (removed elements emit no events — §2.14 item 4; WAAPI `finished` still resolves, but the node is gone — ensure continuations are idempotent).
- **Removal-anchor correctness**: `applyChildren` does removals first, then realizes slots right-to-left with anchor threading (TreeApplier.swift:178–220). A deferred-removal node stays in the DOM as a sibling — anchors and `moveHosts` must skip exiting hosts, and `MockBackend.serializeHTML`/hydration reads must account for ghosts.
- **`replaceSelf` = same-position identity swap — a transition trigger the §5 candidates currently dodge**. SwiftUI fires exit+enter **simultaneously** for `.id(x)` changes / switch-branch at a view's root (§1.7). In SwiftWUI, `diff()` emits `replaceSelf` only at the top-level diff of same-position roots (Reconciler.swift:44–45, :85, :93; never into reuse slots — TreeApplier.swift:158–161 comment); identity swaps at child positions surface as `fresh` + `removedOldIndices` instead, so a subtree-pass root branch-flip is the case that ONLY `replaceSelf` sees. The §5 skeleton must therefore hook `replace()` (TreeApplier.swift:162–173) in addition to `applyChildren`. Direct conflict with deferred removal: `replace()` mounts the new node before unmounting the old purely for anchor correctness (insertion marker = `firstHost(m)`), then swaps the shadow slot (:170–172) — with a deferred exit the old host survives as a ghost sibling *after* the new node, its bookkeeping falls out of the shadow tree, and anchor scans/`moveHosts` must skip it (same rule as removal ghosts, harder because the slot is already reassigned). Also unstated until now: SwiftWUI has **no `.id()` analog** — `HTMLTag.id(_:)` (HTMLTag.swift:14) sets the HTML attribute with zero identity effect; identity swaps arise only from branch/optional/keyed/type structure. A SwiftUI-style identity-forcing `.id(_:)` (minting a `.keyed` segment on any Tag) is net-new API surface if transitions are to be user-triggerable this way.
- **Stacking during overlap**: old+new coexist; SwiftUI needs explicit `zIndex` — SwiftWUI needs a story (transition option or documented CSS; Vue's `mode="out-in"/"in-out"` sequencing, §3.1c, sidesteps overlap entirely and is worth considering as an option).
- **Reliability**: `finished` + timeout race + `visibilitychange` force-finish (§2.14 items 5–7). Hidden-tab lingering ghosts are a real bug class.

### 6.2 Animating layout (auto sizes, reflow)

- `height: auto` / intrinsic sizes: `interpolate-size` is Chromium-only (§2.3) — cross-browser needs measurement (FLIP or explicit px pinning) or the `grid-template-rows: 0fr→1fr` trick. Decide whether v1 punts (document "snap on layout") or ships FLIP.
- FLIP in the applier: requires a before-patch measurement hook (batch reads), post-patch measurement (one layout flush), inverted transforms via WAAPI. `moveHosts` (TreeApplier.swift:222–226) covers reorders; size/position changes from sibling insertion/removal need measuring *unchanged* neighbors too — eligibility scoping needed (measure everything = O(page) rects per animated flush).
- Nested FLIP / scale correction: parent scale distorts children; exact correction needs per-frame projection (Motion-only territory). Accept visible distortion for v1 (Svelte/Vue do).
- **FLIP × deferred-removal ghosts (measurement-ordering hazard, candidate D)**: the post-patch "last" measurement runs while exit ghosts still occupy layout flow — sibling rects are only valid until the ghosts finish and collapse, at which point everything shifts again **un-animated**. Fixes: pop ghosts to `position: absolute` pinned at their measured rect BEFORE the last-measure (the §6.1 pop-out option becomes load-bearing here, not optional — Vue `.list-leave-active` / Motion `popLayout` precedent), or re-run FLIP when each ghost completes (two animated shifts instead of one). Must be specified, not discovered.
- Transform composition: FLIP's `transform` fights user-authored transforms in the style string — compose (additive WAAPI transform layers help: `composite: "add"`) or document the conflict; §6.7's channel mapping (user motion on `translate`/`rotate`/`scale`, FLIP alone on `transform`) dissolves it structurally.

### 6.3 Transaction scoping through component boundaries

- The transaction must flow root→leaves through resolution so `.animation(_:value:)` can override it per-subtree (nearest wins) — a `ResolveContext` field naturally scopes lexically through `_resolve` recursion, including through `ModifiedTag` (which deliberately preserves `scopeClass` — TagModifier.swift:43–44 — the same preservation question applies to an animation context).
- **subtreePass equivalence**: a scoped pass re-resolves only the dirty component (Runtime.swift:171–225); ancestors' `.animation(...)` wrappers are NOT re-executed — their effect on the transaction must be stashed and replayed exactly like `RetainedComponent.styleWrappers` (StateStore.swift:10–19, 61–71; Runtime.swift:196–208), or the "scoped ≡ full" invariant breaks (this was v2's hardest recent bug class — commit 3324953).
- Transaction lives exactly one flush; multiple `markDirty`s before the flush may carry *different* transactions (two `withAnimation` blocks in one handler) — SwiftUI resolves per-write; a coalesced-flush design must decide: per-write transaction map (`[NodeIdentity: Transaction]`) vs last-wins pendingTransaction (observable difference in nested-withAnimation cases, §1.2).
- `withAnimation` inside `body` is illegal today (`markDirty` assert Runtime.swift:90) — matches SwiftUI; document it.

### 6.4 Reduced motion

- Signal plumbing is a solved recipe (§4.8). Policy decisions remain: cross-fade replacement vs duration≈0; whether `.transition` collapses to `.opacity`; completion handlers must fire on the reduced path with the same semantics (§2.13); expose `\.accessibilityReduceMotion` to users; wrap any registry-emitted decorative keyframes in `@media (prefers-reduced-motion: no-preference)`.

### 6.5 SSG / hydration

- `HTMLRenderer` must stay animation-neutral: final values, no transitions armed, no exit ghosts (HTMLRenderer.swift:4–17 throwaway store).
- **Hydration must not fire enter transitions**: adoption (`AdoptingBackend`) walks existing DOM — first pass after adoption is "initial render", and SwiftUI does not run transitions on initial appearance. Need an explicit "first pass = no transitions" rule (also for cold mount).
- If `.animation(_:value:)` compiles to standing CSS `transition:` declarations (candidates A/D-layer), SSG'd HTML contains them — a hydration-time style correction would animate visibly on load. Either keep declarations out of SSG output or guarantee no style deltas at adoption.
- `@starting-style` rules in SSG CSS apply on first render of *client-inserted* elements only — safe for SSG'd static content (already rendered), but verify no flash on adoption-created nodes.
- **Initial-appearance policy**: SwiftUI does not animate initial appearance, and the "first pass = no transitions" rule above matches it for cold mount, hydration, and adoption alike. Vue makes enter-on-first-render an explicit opt-in (`appear`, §3.1c) — if SwiftWUI ever wants it, it should be an opt-in flag on `.transition`, never a default; decide whether v1 ships the opt-in at all (cheap to defer).

### 6.6 The style-string problem (cross-cutting)

- One opaque `style` attribute (AttributeBag.swift:66–92) blocks: per-property change detection (WAAPI engine needs it), per-property animation targeting, and safe coexistence of animator-written styles with differ-written strings. Options: (a) parse style strings at animation time (cheap, localized, keeps node model); (b) restructure `ElementNode` to carry a typed style map and serialize at the backend (invasive; better long-term; also fixes clobbering); (c) never write animated properties into the style attribute — keep them exclusively in WAAPI effect layers + `commitStyles`-less final writes (additive scheme makes this coherent: underlying = model = style attribute, layers = presentation).
- StyleRegistry add-only leak for dynamic keyframes (StyleRegistry.swift:1–3) — prefer WAAPI (no stylesheet churn) for anything parametrized; `registerRaw` only for static author-declared `@keyframes`/`@starting-style`.
- API collision: `.transition(String)` (StyleModifiers+Tag.swift:76, :154) vs `.transition(AnyTransition)`.

### 6.7 Transform channels (offset / scale / rotation composition)

- **The clash**: SwiftUI's `.offset`, `.scaleEffect`, `.rotationEffect` are independent animatable attributes — each can animate concurrently under its **own** curve. Naively all three compile to the single CSS `transform` property, whose value is one list: two concurrent animations on the same element (e.g. a transition-driven scale + a `withAnimation`-driven offset, or two channels with different curves) clobber each other in WAAPI keyframes, and a plain `transition: transform` retarget interpolates the whole list at once (matrix decomposition on list mismatch — §2.1). This surfaces in the first hour of any demo.
- **Platform fix — individual transform properties**: `translate`, `rotate`, `scale` are separate CSS properties (https://developer.mozilla.org/en-US/docs/Web/CSS/translate , https://developer.mozilla.org/en-US/docs/Web/CSS/rotate , https://developer.mozilla.org/en-US/docs/Web/CSS/scale — Chrome 104 / Firefox 72 / Safari 14.1; Baseline Newly 2022 → Widely ~2025; safe in 2026, see §2.15). Each animates and retargets independently with its own curve/duration and stays compositor-eligible (§2.12). Caveats: they compose in a **fixed order** (`translate` → `rotate` → `scale`, then `transform`, regardless of declaration order) whereas SwiftUI composes in modifier order (`.rotationEffect().offset()` ≠ `.offset().rotationEffect()`) — exotic stacks need nested wrapper elements or a baked matrix for exact parity; no skew channel; one `rotate` only (axis-angle syntax covers 3D).
- **Anchors**: `.scaleEffect(anchor:)` / `.rotationEffect(anchor:)` map to `transform-origin` — but that is ONE value per element shared by `translate`/`rotate`/`scale` AND `transform` alike. Two channels with different anchors on one element cannot share it: the minority channel must bake the anchor into its value (`rotate about p` = `translate(p) rotate(θ) translate(-p)` compensation) or live on a wrapper element. `UnitPoint` → `transform-origin` percentage mapping is otherwise direct (`.topLeading` = `0% 0%`).
- **Fallback compositions** (if individual properties are rejected): WAAPI additive layers — multiple concurrent `Animation` objects targeting `transform` with `composite: "add"` sum in stacking order, covering retargets and per-curve stacks at the cost of layer hygiene (§2.5); or Motion's shape — per-axis virtual values (`x`, `scaleX`, `rotate`) recomposed into one transform string per rAF frame (§3.2), the expensive per-frame path.
- **SwiftWUI inventory (today: zero transform modifiers)**: `StyleModifiers+Tag.swift:28–77` covers display/position/box/flex/grid/text/color/opacity/shadow — no `transform`, `translate`, `rotate`, `scale`, or `transform-origin` typed modifiers exist; the only route is the string escape hatch `.style("transform", …)` (:13, :92). So `.offset`/`.scaleEffect`/`.rotationEffect` analogs are **net-new API surface**, and the channel strategy must be fixed BEFORE they ship or the engine inherits a single-property bottleneck. Recommended mapping: `.offset` → `translate`, `.scaleEffect` → `scale`, `.rotationEffect` → `rotate`; reserve bare `transform` exclusively for FLIP's inverted transforms (also dissolving the §6.2 FLIP-vs-user-transform conflict).
- Transitions built on transforms (`.scale`, `.offset`, `.slide`, `.move`, `.push`) hit the same question: an exit `.scale` transition concurrent with a `withAnimation` offset on the same element is the canonical composition bug.

---

## 7. Open questions for the brainstorm

1. **Architecture pick**: A (CSS-first), B (WAAPI engine), or D (hybrid, = B + FLIP phase)? C appears dominated. Is B-now/D-later acceptable phasing (layout animation deferred)?
2. **Retarget fidelity bar**: is WAAPI-additive (perceptually smooth, not physically exact) good enough for v1, or do merging springs need analytic velocity retarget (curve metadata + `initialVelocity` re-derivation) from day one?
3. **Per-property style diffing**: parse style strings at animation time vs restructure `ElementNode` to a typed style map (bigger change, fixes clobbering permanently)? (§6.6)
4. **Transaction carrier semantics**: single `pendingTransaction` (last-wins per flush) vs per-write `[NodeIdentity: Transaction]` honoring nested `withAnimation` exactly? (§6.3)
5. **Naming**: rename the existing CSS `.transition(String)` modifier, rely on overload resolution, or name the SwiftUI-style one differently? Same question does NOT arise for `.animation` (free today).
6. **Exit-time lifecycle**: accept state/listener sweep at exit-start + `inert` ghosts (option a), or keep identity alive until exit-end? When does `onDisappear` fire? (§6.1)
7. **Animatable property whitelist**: which CSS properties does v1 animate under `withAnimation` (opacity/transform/color/…)? Everything by-computed-value, or a curated compositor-friendly set with the rest applied instantly?
8. **Default animation**: SwiftUI-17 parity (`smooth` spring, duration 0.55) or web-conventional ease? (Springs-by-default is most of the "iOS feel" — §1.9.)
9. **Completion handlers in v1** (`withAnimation(_:completion:)`)? Cheap with WAAPI `finished` aggregation; adds API surface.
10. **Scope of `.transition` v1**: `.opacity/.scale/.move/.offset/.slide/.combined/.asymmetric/.animation` + the `.modifier(active:identity:)` primitive? zIndex-during-overlap story?
11. **Reduced-motion policy**: crossfade-replacement vs duration≈0; user override API? (§6.4)
12. **Backend surface shape**: patch-level animation hints interpreted by `TreeApplier` + new backend requirements (`animate/defer-remove/measureRect`) with no-op defaults (observer precedent), or an `AnimatingBackend` decorator (AdoptingBackend precedent)? (§4.4)
13. **BridgeJS**: dynamic `JSObject.animate` first, typed d.ts later if hot — agreed?
14. **View Transitions**: reserve for a later route-transition/matchedGeometryEffect spec (recommended), or expose a minimal `withViewTransition {}` escape hatch now?
15. **Testing bar**: MockBackend records typed animation calls + scripted rects; do we also want a native "virtual clock" driver for exit-orchestration unit tests (TestScheduler precedent)?
16. **Transform channel strategy** (§6.7): map future `.offset`/`.scaleEffect`/`.rotationEffect` modifiers to individual `translate`/`scale`/`rotate` properties (fixed composition order, one shared `transform-origin` per element) vs single `transform` + additive WAAPI layers vs Motion-style per-axis rAF recomposition? Must be settled BEFORE any transform modifiers ship (none exist today); the choice also decides what FLIP is allowed to write and how transition `.scale`/`.offset`/`.slide` coexist with `withAnimation` motion on the same element.
