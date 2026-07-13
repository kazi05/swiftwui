# SwiftWUI Animations (WAAPI Engine) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SwiftUI-style animations — `withAnimation(_:completion:)`, `.animation(_:value:)`, `.transition(_:)` — on a WAAPI-driven engine per the approved spec `docs/superpowers/specs/2026-07-13-animations-design.md` (read it first; §2 has the 16 locked decisions).

**Architecture:** Swift computes per-property keyframes + timing (springs → CSS `linear()` easing); the backend calls `element.animate` (one bridge call per animated property, zero per-frame). Model values always written to final immediately; animations are additive presentation layers. Exit transitions defer DOM removal via inert ghosts.

**Tech Stack:** Swift 6.3.3, SwiftPM, Swift Testing (`@Test`/`#expect` — match existing test style in `Tests/SwiftWUITests`), JavaScriptKit (WASM only, task 13), no new dependencies.

## Global Constraints

- Module-wide `@MainActor` (both `SwiftWUI` and `SwiftWUIDOM`); no Sendable in the pipeline; no TaskLocal/globals except the documented `Transaction._active` MainActor static.
- Core module (`SwiftWUI`) stays renderer-agnostic and Foundation-light: the spring solver and planner are pure math/string code. **No wall clock, no timers in core** — settle is driven by backends (Mock: test driver).
- `swift build && swift test` must be green after EVERY task. Baseline: 413 tests green on `main`.
- WASM gate (task 13 only): `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM` (note: `--target`, not `--product`).
- Never pass `-disable-reflection-metadata`.
- **Testing workflow (user preference, overrides TDD micro-steps):** write ALL of a task's code (implementation + tests) first, run the suite ONCE at the end, fix, commit. No intermediate red/green runs.
- Doc comments reference the spec as `(anim spec §N)`. Code and commits in English.
- Commit messages: conventional commits, `feat(anim): …` / `refactor(styles): …` etc.

## Interface Registry (shared names — use EXACTLY these)

Defined across tasks; listed here so every task uses identical spellings:

| Name | Kind | Defined in |
|---|---|---|
| `OrderedStyle`, `OrderedStyle.Entry` | struct | Task 1 |
| `ElementNode.style: OrderedStyle` | field | Task 2 |
| `Patch.setStyleProperty(name:value:previous:)`, `Patch.removeStyleProperty(name:)` | cases | Task 2 |
| `RendererBackend.setStyleProperty/removeStyleProperty` | protocol reqs | Task 2 |
| `Animation`, `ResolvedTiming`, `SpringSolver` | struct/enum | Task 3 |
| `Transaction`, `withAnimation`, `CompletionGroup` | API | Task 4 |
| `ResolveContext.transaction/.transactionOverrides/.effectiveTransactions/.animationValues/.transitions` | fields | Tasks 4,5,8 |
| `AnimationValueStore` | class | Task 5 |
| `AnimationRequest`, `AnimationPlanner`, `AnimationToken` | types | Task 6 |
| `RendererBackend.animate/cancelAnimation/finishAnimation` | protocol reqs | Task 6 |
| `MockBackend.animations`, `MockBackend.settleAnimation(at:)` | test driver | Task 6 |
| `AnimationRegistry`, `AnimationPassContext`, `MountedNode.elementIdentity` | engine | Task 7 |
| `AnyTransition`, `_TransitionTag`, `TransitionRegistry` | types | Task 8 |
| `TreeApplier.exiting`, `ExitRecord`, `ChildrenPlan.removedNodes` | exit infra | Task 10 |
| `UnitPoint`, `Edge`, `.offset/.scaleEffect/.rotationEffect`, `.cssTransition` | API | Task 12 |
| `EnvironmentSignals.reduceMotion`, `\.accessibilityReduceMotion` | env | Task 13 |

Task order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 (interruption) → 12 (transforms/rename) → 13 (reduced motion) → 14 (DOMBackend) → 15 (docs/site).

---

### Task 1: `OrderedStyle` type + CSS text parser

**Files:**
- Create: `Sources/SwiftWUI/Styles/OrderedStyle.swift`
- Test: `Tests/SwiftWUITests/OrderedStyleTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct OrderedStyle: Equatable {
      public struct Entry: Equatable {
          public var property: String
          public var value: String
      }
      public private(set) var entries: [Entry]
      public init()
      public init(parsing cssText: String)          // "a: 1; b: 2" → entries; tolerant
      /// Last-wins: existing property updates IN PLACE (keeps position), new appends.
      public mutating func set(_ property: String, _ value: String)
      public mutating func merge(_ declarations: [StyleDeclaration])   // set() each, in order
      public subscript(property: String) -> String? { get }
      public var isEmpty: Bool
      /// "prop: value; prop2: value2" in entry order. Empty → "".
      public var cssText: String
  }
  ```

- [ ] **Step 1: Implement**

Parser rules (anim spec §5): split on `;` **outside parentheses** (guards `url(data:…;base64,…)`), then first `:` splits property/value, both trimmed; entries with empty property or no `:` are dropped. `set` semantics: last-wins value at first-occurrence position — this intentionally collapses today's duplicate-property output (spec §5 "Known output change").

```swift
public struct OrderedStyle: Equatable {
    public struct Entry: Equatable {
        public var property: String
        public var value: String
        public init(property: String, value: String) { self.property = property; self.value = value }
    }
    public private(set) var entries: [Entry] = []
    public init() {}

    public init(parsing cssText: String) {
        var depth = 0, current = ""
        var chunks: [String] = []
        for ch in cssText {
            switch ch {
            case "(": depth += 1; current.append(ch)
            case ")": depth = max(0, depth - 1); current.append(ch)
            case ";" where depth == 0: chunks.append(current); current = ""
            default: current.append(ch)
            }
        }
        chunks.append(current)
        for chunk in chunks {
            guard let colon = chunk.firstIndex(of: ":") else { continue }
            let prop = chunk[..<colon].trimmingCharacters(in: .whitespaces)
            let value = chunk[chunk.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !prop.isEmpty else { continue }
            set(prop, value)
        }
    }

    public mutating func set(_ property: String, _ value: String) {
        if let i = entries.firstIndex(where: { $0.property == property }) {
            entries[i].value = value
        } else {
            entries.append(Entry(property: property, value: value))
        }
    }
    public mutating func merge(_ declarations: [StyleDeclaration]) {
        for d in declarations { set(d.property, d.value) }
    }
    public subscript(property: String) -> String? {
        entries.first(where: { $0.property == property })?.value
    }
    public var isEmpty: Bool { entries.isEmpty }
    public var cssText: String {
        entries.map { "\($0.property): \($0.value)" }.joined(separator: "; ")
    }
}
```

Note: `.trimmingCharacters(in: .whitespaces)` needs Foundation — the core avoids it. Write a tiny local `trim` over `Character.isWhitespace` instead (check how `HTMLEscaping`/`RouteURL` handle this; follow that pattern).

- [ ] **Step 2: Tests** — `OrderedStyleTests.swift`: last-wins-in-place ordering, parser round-trip, `url(data:image/png;base64,x)` value survives, no-colon chunk dropped, empty text → empty, subscript, merge order.

```swift
@Test func lastWinsKeepsPosition() {
    var s = OrderedStyle()
    s.set("color", "red"); s.set("width", "10px"); s.set("color", "blue")
    #expect(s.cssText == "color: blue; width: 10px")
}
@Test func parserIgnoresSemicolonsInsideParens() {
    let s = OrderedStyle(parsing: "background: url(data:image/png;base64,AA); color: red")
    #expect(s["background"] == "url(data:image/png;base64,AA)")
    #expect(s["color"] == "red")
}
```

- [ ] **Step 3: Run** `swift test` — all green.
- [ ] **Step 4: Commit** `refactor(styles): add OrderedStyle typed style map with tolerant CSS parser`

---

### Task 2: Style pipeline migration (typed map end-to-end)

**Files:**
- Modify: `Sources/SwiftWUI/Tree/Node.swift` (ElementNode), `Sources/SwiftWUI/Runtime/Resolver.swift:139-152` (resolveElement), `Sources/SwiftWUI/HTML/AttributeBag.swift` (flattened/mergeStyleText), `Sources/SwiftWUI/Styles/StyledTag.swift:62-87` (applyStyleWrapper), `Sources/SwiftWUI/Render/Reconciler.swift` (Patch + diff), `Sources/SwiftWUI/Render/TreeApplier.swift` (mount + apply), `Sources/SwiftWUI/Render/RendererBackend.swift`, `Sources/SwiftWUI/Render/MockBackend.swift`, `Sources/SwiftWUI/Render/HTMLRenderer.swift`, `Sources/SwiftWUI/Render/AdoptingBackend.swift`
- Test: migrate failing asserts in `InlineStyleTests.swift`, `ApplierTests.swift`, `HTMLRendererTests.swift`, `CrossCheckTests.swift`, `HydrationRoundTripTests.swift` (expect style-string asserts to need updating)

**Interfaces:**
- Produces: `ElementNode.style: OrderedStyle` (and `attributes` never contains `"style"`); patch cases:
  ```swift
  case setStyleProperty(name: String, value: String, previous: String?)  // previous: old value if the property existed (engine fuel, Task 7)
  case removeStyleProperty(name: String)
  ```
  backend requirements (defaults provided so HTMLRenderer-as-backend/3rd-party compile — observer precedent RendererBackend.swift:71-80):
  ```swift
  func setStyleProperty(_ node: HostNode, name: String, value: String)
  func removeStyleProperty(_ node: HostNode, name: String)
  // defaults: extension RendererBackend { … {} }
  ```

- [ ] **Step 1: Implement**

1. `ElementNode` gains `public var style: OrderedStyle = OrderedStyle()`. Keep `Equatable`.
2. `_AttributeBag.flattened()` no longer merges styles into `out["style"]`; delete `mergeStyleText`. Add `func flattenedStyle() -> OrderedStyle`: start from `OrderedStyle(parsing: pairs-last "style" attribute value if any)` (raw `style:` attribute escape hatch keeps working), then `merge(styles)`.
3. `resolveElement` (Resolver.swift:149): pass `style: effectiveBag.flattenedStyle()` into `ElementNode`, and ensure `flattened()` output drops the `style` key (strip after flatten: `attrs["style"] = nil`).
4. `applyStyleWrapper` (StyledTag.swift:66-69): replace `mergeStyleText` with `e.style.merge(declarations)` — outer wins because `set` is last-wins.
5. `Reconciler.diff` element case, after the attribute loops:
   ```swift
   for entry in n.style.entries where o.style[entry.property] != entry.value {
       patches.append(.setStyleProperty(name: entry.property, value: entry.value,
                                        previous: o.style[entry.property]))
   }
   for entry in o.style.entries where n.style[entry.property] == nil {
       patches.append(.removeStyleProperty(name: entry.property))
   }
   ```
6. `TreeApplier.mount(.element)`: after the attribute loop, `for e in el.style.entries { backend.setStyleProperty(h, name: e.property, value: e.value) }`. `TreeApplier.apply`: two new cases calling the backend.
7. `MockBackend`: implement both (bump counts `"setStyleProperty"`/`"removeStyleProperty"`), store in `public private(set) var styles: … ` — simplest: keep a `var style: OrderedStyle` per `MockNode` (new field) and have `serializeHTML` emit `style="…"` (escaped, via `cssText`) when non-empty, positioned among sorted attrs as if it were the `style` attribute (keeps serialized output shape).
8. `HTMLRenderer` (and `SwiftWUIStatic/DocumentSerializer` if it renders ElementNode directly — grep for `attributes["style"]` and `"style"` usages): serialize `style` from `node.style.cssText` when non-empty.
9. `AdoptingBackend`: forwards every backend call — add the two forwards. Check its adoption walk: it compares tags only (`tagName(of:)`), so no style-read changes needed; verify by reading the file.
10. Grep guard: `grep -rn '"style"' Sources/ | grep -v OrderedStyle` — every remaining hit must be reviewed (Theme/StyleRegistry hits are stylesheet-related, untouched).

- [ ] **Step 2: Tests** — new `OrderedStylePipelineTests.swift`:

```swift
@Test @MainActor func styleChangeEmitsPerPropertyPatch() {
    // Runtime + MockBackend, component whose body is Div().style("opacity", flag ? "1" : "0.5")
    // toggle @State flag, pump microtask, assert:
    #expect(backend.counts["setStyleProperty"] == /* initial N + exactly 1 */)
    // and the untouched sibling property produced no call
}
@Test @MainActor func wrapperDuplicateCollapsesToOuterValue() {
    // Foo.body == Div().color(.blue); render Foo().color(.red)
    // serializeHTML must contain style="color: red" exactly once — no "color: blue"
}
```
Also update existing tests that assert whole `style="a; b"` strings (grep `style=` in Tests/) to the collapsed form. `CrossCheckTests` (Mock serializeHTML ≡ HTMLRenderer) must stay green — that property is the real migration guard.

- [ ] **Step 3: Run** `swift test` — all green (expect to fix a handful of string asserts).
- [ ] **Step 4: Commit** `refactor(styles): ElementNode carries typed OrderedStyle; per-property style patches`

---

### Task 3: `Animation` + `ResolvedTiming` + spring solver

**Files:**
- Create: `Sources/SwiftWUI/Animation/Animation.swift`, `Sources/SwiftWUI/Animation/SpringSolver.swift`
- Test: `Tests/SwiftWUITests/AnimationTimingTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct Animation: Equatable {
      // factories (anim spec §3.1): .default == .smooth
      public static let `default`: Animation
      public static func linear(duration: Double) -> Animation
      public static func easeIn(duration: Double) -> Animation
      public static func easeOut(duration: Double) -> Animation
      public static func easeInOut(duration: Double) -> Animation
      public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double) -> Animation
      public static func spring(duration: Double = 0.5, bounce: Double = 0.0) -> Animation
      public static let smooth: Animation   // spring(duration: 0.55, bounce: 0)
      public static let snappy: Animation   // spring(duration: 0.4, bounce: 0.15)
      public static let bouncy: Animation   // spring(duration: 0.5, bounce: 0.3)
      public func delay(_ s: Double) -> Animation
      public func speed(_ factor: Double) -> Animation
      public func repeatCount(_ n: Int, autoreverses: Bool = true) -> Animation
      public func repeatForever(autoreverses: Bool = true) -> Animation
      public func resolved() -> ResolvedTiming
  }
  public struct ResolvedTiming: Equatable {
      public var durationMs: Double
      public var easing: String          // "linear", "ease-in", "cubic-bezier(…)", "linear(…)"
      public var delayMs: Double
      public var iterations: Double      // 1 default; .infinity for repeatForever
      public var autoreverses: Bool
      public var isInfinite: Bool { iterations == .infinity }
  }
  enum SpringSolver {   // internal
      /// Closed-form damped oscillator sampled into a CSS linear() easing.
      /// Returns settle duration (≥ perceptual duration for bounce > 0).
      static func solve(duration: Double, bounce: Double) -> (durationMs: Double, easing: String)
  }
  ```
- Internal storage: `enum Curve: Equatable { case linear, cubicBezier(Double,Double,Double,Double), spring(duration: Double, bounce: Double) }` + `duration`, `delay`, `speed`, `repeatCount: Double`, `autoreverses` fields. `easeIn/Out/InOut` = the standard CSS bezier constants (`cubic-bezier(0.42,0,1,1)` etc. — emit the CSS keywords `ease-in`/`ease-out`/`ease-in-out` directly for those factories).

- [ ] **Step 1: Implement**

Spring math (anim spec §6.3; Apple parameter convention): `ω = 2π / duration`; `ζ = 1 − bounce` for `bounce ∈ [0, 1]` (clamp inputs to `[-1, 1]`; treat `bounce < 0` as overdamped `ζ = 1 − bounce > 1`). Position for underdamped (`ζ < 1`), with `ω_d = ω·√(1−ζ²)`:

```
x(t) = 1 − e^(−ζωt) · (cos(ω_d t) + (ζω/ω_d) · sin(ω_d t))
```

Critically damped (`ζ == 1`): `x(t) = 1 − e^(−ωt)(1 + ωt)`. Overdamped: standard two-exponential form. Settle time = first `t` where `|x−1| < 0.001` AND stays inside thereafter (scan forward in 1ms steps, cap 5× duration). Sample `x` at `N = min(200, max(16, Int(settleSeconds * 120)))` uniform points into `linear(v1 p1%, v2 p2%, …)` — emit value and percentage with 4 decimal places via the existing `cssNumber`-style formatting (see `CSSValues.swift`). `resolved()` applies `speed` (divides duration/delay) and maps `repeatForever` → `iterations = .infinity`.

- [ ] **Step 2: Tests** — pure math, no runtime:

```swift
@Test func criticallyDampedNeverOvershoots() {
    let (_, easing) = SpringSolver.solve(duration: 0.55, bounce: 0)
    #expect(easing.hasPrefix("linear("))
    // parse the sampled values back out of the string: all within [0, 1.0001]
}
@Test func bouncyOvershoots() { /* bounce 0.3: some sample > 1.0 */ }
@Test func settleTimeGrowsWithBounce() { /* solve(0.5, 0.3).durationMs > 500 */ }
@Test func presets() { #expect(Animation.default == .smooth) }
@Test func speedHalvesDuration() {
    #expect(Animation.linear(duration: 1.0).speed(2).resolved().durationMs == 500)
}
@Test func repeatForeverIsInfinite() {
    #expect(Animation.linear(duration: 1).repeatForever().resolved().isInfinite)
}
```

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): Animation type, ResolvedTiming, spring solver -> CSS linear() easing`

---

### Task 4: `Transaction` + `withAnimation` + per-write capture + carrier maps

**Files:**
- Create: `Sources/SwiftWUI/Animation/Transaction.swift`
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (markDirty:89-96, flush:148-160, renderPass, subtreePass), `Sources/SwiftWUI/Runtime/Resolver.swift` (ResolveContext + component resolve + resolveElement)
- Test: `Tests/SwiftWUITests/TransactionTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct Transaction {
      public var animation: Animation?
      public init(animation: Animation? = nil)
      var _group: CompletionGroup?           // internal; nil unless withAnimation(completion:)
      @MainActor static var _active: Transaction?   // ambient (anim spec §4.1)
  }
  @MainActor final class CompletionGroup {   // internal
      private(set) var pending = 0
      private var fired = false
      private var armed = false
      let action: () -> Void
      init(action: @escaping () -> Void)
      func register()                         // pending += 1
      func settle()                           // pending -= 1; fireIfDone()
      func arm(schedule: (@escaping () -> Void) -> Void)  // called post-flush; empty group fires via schedule (next microtask)
  }
  @MainActor public func withAnimation<T>(_ animation: Animation? = .default, _ body: () throws -> T) rethrows -> T
  @MainActor public func withAnimation<T>(_ animation: Animation? = .default,
                                          completion: @escaping () -> Void,
                                          _ body: () throws -> T) rethrows -> T
  // ResolveContext additions:
  var transaction: Transaction? = nil                          // ambient during resolve
  var transactionOverrides: [NodeIdentity: Transaction] = [:]  // input: drained per-write captures
  var effectiveTransactions: [NodeIdentity: Transaction] = [:] // output: element identity → txn
  // Runtime addition:
  private var pendingTransactions: [NodeIdentity: Transaction] = [:]
  var _pendingCompletionGroups: [CompletionGroup] = []          // armed post-flush
  ```

- [ ] **Step 1: Implement**

1. `withAnimation`: save `Transaction._active`, set `Transaction(animation: animation, _group: group)`, `defer` restore (nested = inner wins for inner writes). The completion variant creates the group; both store it into `Runtime`-reachable state ONLY via capture at `markDirty` (the group rides the Transaction value — class ref shared across copies).
2. `markDirty` (Runtime.swift:89): after the assert, `if let t = Transaction._active { pendingTransactions[id] = t; if let g = t._group, !_pendingCompletionGroups.contains(where: { $0 === g }) { _pendingCompletionGroups.append(g) } }`.
3. `flush`: drain both maps into locals before rendering. Full pass (`renderPass`): set `ctx.transactionOverrides = drained` — the component-resolve boundary applies them. Subtree passes: for each cover id, `ctx.transaction = drained[id]`, `ctx.transactionOverrides = drained` (deeper dirty ids under the same cover still override). After ALL passes of this flush: `for g in drainedGroups { g.arm(schedule: scheduleMicrotask) }` — empty groups fire next microtask (anim spec §7.4).
4. Component resolve (Resolver.swift:50-63): alongside `savedOwner`/`savedScope`, save `ctx.transaction`; `if let t = ctx.transactionOverrides[id] { ctx.transaction = t }`; restore in the same `defer`.
5. `resolveElement`: before returning, `if let t = ctx.transaction { ctx.effectiveTransactions[path] = t }`.
6. `renderPass`/`subtreePass`: after diff, hand `ctx.effectiveTransactions` to the applier (stash on a new `applier.animationPass` field — the full context struct lands in Task 7; for THIS task add a minimal `var _lastEffectiveTransactions: [NodeIdentity: Transaction]` test hook on Runtime instead, populated per flush).
7. `withAnimation` from inside `body` must still trap: the existing `markDirty` assert covers it (state write during render) — no new assert needed; document in the `withAnimation` doc comment.

- [ ] **Step 2: Tests**

```swift
@Test @MainActor func perWriteCapture_twoBlocksTwoTransactions() {
    // Two components A (spring) and B (linear) — handler runs:
    // withAnimation(.spring(duration: 1)) { a.toggle() }; withAnimation(.linear(duration: 0.2)) { b.toggle() }
    // pump; assert runtime._lastEffectiveTransactions has A-element → spring, B-element → linear
}
@Test @MainActor func nestedInnerWins() { /* withAnimation(.linear…) { withAnimation(.easeIn…) { x = 1 } ; y = 2 } → x's identity easeIn, y's linear */ }
@Test @MainActor func nilAnimationCaptured() { /* withAnimation(nil) { … } → entry present, animation == nil */ }
@Test @MainActor func noTransactionNoEntries() { /* plain write → _lastEffectiveTransactions.isEmpty */ }
@Test @MainActor func emptyGroupFiresNextMicrotask() { /* withAnimation(completion:) around a write that changes NO styles → completion fired after one extra pump */ }
```
Use the existing Runtime+MockBackend test harness pattern (see `RuntimeE2ETests.swift` for the microtask-pump helper).

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): Transaction ambient, withAnimation, per-write capture, resolve->apply carrier`

---

### Task 5: `.animation(_:value:)` wrapper

**Files:**
- Create: `Sources/SwiftWUI/Animation/AnimationModifier.swift` (`_AnimationTag` + `Tag.animation`), `Sources/SwiftWUI/Animation/AnimationValueStore.swift`
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (own + sweep the store; seed `ctx.animationValues`), `Sources/SwiftWUI/Runtime/Resolver.swift` (ResolveContext field)
- Test: `Tests/SwiftWUITests/AnimationModifierTests.swift`

**Interfaces:**
- Produces:
  ```swift
  extension Tag {
      public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some Tag
  }
  @MainActor final class AnimationValueStore {
      /// Compare-and-update DURING resolve (anim spec §4.3 — NOT EffectStore.onChange, which is post-commit).
      /// Returns true when a previous value existed and differs. First sighting stores and returns false.
      func changed(id: NodeIdentity, newValue: Any, isEqual: (Any, Any) -> Bool) -> Bool
      func sweep(under root: NodeIdentity, reachable: Set<NodeIdentity>)
  }
  // ResolveContext: var animationValues: AnimationValueStore? = nil
  ```

- [ ] **Step 1: Implement**

`_AnimationTag<V: Equatable, Content: Tag>: Tag, _PrimitiveTag` — byte-parallel with `_StyledTag._resolve` (StyledTag.swift:11-39): one `.type` segment, register type name, `ctx.reachable.insert(id)` NOT needed (only components retain) — but the VALUE STORE needs sweeping, so DO track: keep a parallel `reachable` contract by sweeping with the pass's `ctx.reachable` (the id is `path.appending(.type(…))`; element/primitive ids aren't in `reachable`… therefore sweep `AnimationValueStore` by prefix under the pass root using the same `retained`-style bookkeeping as `TransitionRegistry` will use in Task 8: store rows, and in `Runtime.renderPass/subtreePass` call `animationValues.sweep(under: passRoot, reachable: ctx.reachable ∪ {ids seen this pass})`. Simplest correct rule: `changed()` also marks the id "seen this pass"; sweep drops ids under the pass root not seen — mirror `listeners.sweep(under:keep:)` (ListenerRegistry) which already implements exactly this shape; read it and copy).

Resolve body:
```swift
@MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
    _TypeNameRegistry.register(Self.self)
    let id = path.appending(.type(ObjectIdentifier(Self.self)))
    let saved = ctx.transaction
    defer { ctx.transaction = saved }
    if ctx.collectedRoutes == nil,      // collect passes never touch live stores (C1 — Resolver.swift:55)
       let store = ctx.animationValues,
       store.changed(id: id, newValue: value, isEqual: { ($0 as? V) == ($1 as? V) }) {
        ctx.transaction = Transaction(animation: animation)   // nearest-wins; one pass only (anim spec §4.3)
    }
    return resolve(content, path: id, ctx: &ctx)
}
```
The override is NOT persisted anywhere — value-gated per pass (anim spec §4.3: deliberately opposite of `styleWrappers`; a value change always dirties at/above the wrapper because the write that changed `value` invalidates the owning component, which encloses the wrapper).

- [ ] **Step 2: Tests**

```swift
@Test @MainActor func firesOnlyWhenValueChanges() { /* value changed → element in _lastEffectiveTransactions with wrapper's animation */ }
@Test @MainActor func unchangedValueUnrelatedWriteDoesNotAnimate() { /* sibling @State toggles, value same → no entry (the "flying views" guard) */ }
@Test @MainActor func overridesAmbientNearestWins() { /* withAnimation(.linear) around write; wrapper .spring closer → spring wins */ }
@Test @MainActor func nilAnimationSuppresses() { /* .animation(nil, value:) + changed value inside withAnimation(.spring) → entry with animation == nil */ }
@Test @MainActor func scopedEqualsFull() {
    // ScopedEquivalenceTests pattern: same sequence with runtime._forceFullPasses on/off
    // → identical _lastEffectiveTransactions both times, incl. wrapper above the dirty component
}
@Test @MainActor func staleOverrideMustNotFire() { /* pass N changes value (animates); pass N+1 dirties a descendant only → no entry */ }
```

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): .animation(_:value:) wrapper with resolve-time value gating`

---

### Task 6: `AnimationRequest` + planner + backend `animate` surface + Mock driver

**Files:**
- Create: `Sources/SwiftWUI/Animation/AnimationRequest.swift`, `Sources/SwiftWUI/Animation/AnimationPlanner.swift`
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift`, `Sources/SwiftWUI/Render/MockBackend.swift`, `Sources/SwiftWUI/Render/AdoptingBackend.swift` (forwards)
- Test: `Tests/SwiftWUITests/AnimationPlannerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct AnimationRequest: Equatable {
      public enum Mode: Equatable { case additive, replace }
      public var property: String
      public var from: String?      // nil = implicit (current presentation state)
      public var to: String?        // nil = implicit
      public var mode: Mode         // additive: from = delta value, to = zero delta, composite "add"
      public var timing: ResolvedTiming
  }
  open class AnimationToken {}      // opaque handle; backends subclass
  public struct AnimationSettle: Equatable {
      public enum Reason: Equatable { case finished, cancelled, forced }
      public var reason: Reason
  }
  // RendererBackend additions (no-op defaults: animate returns nil):
  @discardableResult
  func animate(_ node: HostNode, request: AnimationRequest,
               onSettle: @escaping (AnimationSettle) -> Void) -> AnimationToken?
  func cancelAnimation(_ token: AnimationToken)   // settle(.cancelled), snap presentation
  func finishAnimation(_ token: AnimationToken)   // settle(.forced), jump to end
  // Planner (pure):
  enum AnimationPlanner {
      /// nil when the change should apply instantly (identical values).
      /// additive when BOTH values parse as number-lists with matching units
      /// ("10px", "0.5", "10px 20px", "45deg"); componentwise delta = old − new.
      /// Everything else (colors, keywords, mismatched shapes) → replace(from: old, to: new).
      static func request(property: String, from old: String?, to new: String,
                          timing: ResolvedTiming) -> AnimationRequest?
  }
  // MockBackend additions:
  public struct RecordedAnimation {
      public let node: MockNode
      public let request: AnimationRequest
      let settle: (AnimationSettle) -> Void
      public let token: AnimationToken
  }
  public private(set) var animations: [RecordedAnimation]
  public func settleAnimation(at index: Int, reason: AnimationSettle.Reason = .finished)  // idempotent
  ```

- [ ] **Step 1: Implement**

Planner value parser: tokenize on spaces/commas; each token → `(number, unitSuffix)` (leading `+-.0-9`, rest = unit); lists match iff same length + same units in order. Delta value string rebuilt with the same separators. `old == nil` (property absent before) → no `previous` → planner returns `replace(from: nil, to: new)`? NO — anim spec §6.1: only CHANGED properties with a previous value animate under `withAnimation`; property additions apply instantly. `request` returns nil when `old == nil` or `old == new`. (Transitions in Task 9 build their requests directly, not through this planner path.)

MockBackend: `animate` bumps `"animate"`, appends `RecordedAnimation` (token = plain `AnimationToken()`), returns token. `settleAnimation` guards double-settle. `cancelAnimation/finishAnimation` locate by token identity and settle with the matching reason.

- [ ] **Step 2: Tests** — planner-only (pure):

```swift
@Test func additiveForMatchingUnits() {
    let r = AnimationPlanner.request(property: "translate", from: "10px 20px", to: "30px 20px",
                                     timing: Animation.linear(duration: 1).resolved())!
    #expect(r.mode == .additive); #expect(r.from == "-20px 0px"); #expect(r.to == "0px 0px")
}
@Test func replaceForColors() { /* from "red" to "blue" → .replace(from: "red", to: "blue") */ }
@Test func nilForNoPrevious() { /* from nil → nil */ }
@Test func nilForIdentical() { /* same strings → nil */ }
@Test func unitlessOpacityAdditive() { /* "0.5" → "1": from "-0.5" to "0" */ }
```

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): AnimationRequest planner (additive/replace) + backend animate surface + Mock recorder`

---

### Task 7: Engine wiring in TreeApplier + `AnimationRegistry` + completions

**Files:**
- Create: `Sources/SwiftWUI/Animation/AnimationRegistry.swift`
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift` (MountedNode + apply), `Sources/SwiftWUI/Runtime/Runtime.swift` (pass context around apply)
- Test: `Tests/SwiftWUITests/AnimationEngineTests.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor final class AnimationRegistry {
      struct Key: Hashable { let identity: NodeIdentity; let property: String }
      struct Running { let token: AnimationToken; let timing: ResolvedTiming; let to: String? }
      private(set) var running: [Key: Running]
      func track(_ key: Key, _ r: Running)
      func remove(_ key: Key)
      func cancelAll(under root: NodeIdentity, using backend: (AnimationToken) -> Void)  // prefix match on identity
  }
  struct AnimationPassContext {                     // internal, built by Runtime per flush
      var transactions: [NodeIdentity: Transaction]
      var reduceMotion: Bool                        // false until Task 13; field exists NOW
      var suppressTransitions: Bool                 // consumed in Task 9; field exists NOW
  }
  // TreeApplier additions:
  //   MountedNode gains `let elementIdentity: NodeIdentity?` (set from ElementNode.identity in mount; nil for text/component)
  //   var animationPass: AnimationPassContext? (set by Runtime before apply, cleared after)
  //   let animationRegistry = AnimationRegistry()
  ```
- Consumes: Task 4's `effectiveTransactions` (replaces the `_lastEffectiveTransactions` test hook — KEEP the hook, tests use it), Task 6's planner/backends.

- [ ] **Step 1: Implement**

`TreeApplier.apply`, case `.setStyleProperty(name, value, previous)`:
```swift
backend.setStyleProperty(m.host!, name: name, value: value)   // model final FIRST (anim spec §6.1)
if let pass = animationPass, !pass.reduceMotion,
   let id = m.elementIdentity, let txn = pass.transactions[id],
   let anim = txn.animation,
   let request = AnimationPlanner.request(property: name, from: previous, to: value,
                                          timing: anim.resolved()) {
    let key = AnimationRegistry.Key(identity: id, property: name)
    txn._group?.register()
    let group = txn._group
    let token = backend.animate(m.host!, request: request) { [weak self] _ in
        self?.animationRegistry.remove(key)
        group?.settle()
    }
    if let token { animationRegistry.track(key, .init(token: token, timing: request.timing, to: request.to)) }
    else { animationRegistry.remove(key); group?.settle() }   // no-op backend: settle immediately
    if request.timing.isInfinite { group?.settle() }          // repeatForever excluded from groups (anim spec §7.4)
}
```
Wait — the infinite case must not double-settle: register/settle pairing rule: `register()` always, then EITHER the onSettle path OR (isInfinite) an immediate `settle()` and the onSettle closure must skip the group (capture `let countsTowardGroup = !request.timing.isInfinite` and use it in both places). Write it that way.

Additive retarget hygiene (anim spec §6.2): before starting, if `running[key]` exists and the new request is `.replace`, `backend.cancelAnimation(old.token)`; if `.additive`, leave the old layer (it decays on its own) but replace the registry entry.

`reduceMotion == true` (wired in Task 13): skip `backend.animate` entirely; `register()`+`settle()` immediately so completion semantics hold.

Runtime: build `AnimationPassContext(transactions: drainedEffective, reduceMotion: false, suppressTransitions: current == nil)` around BOTH `applier.apply` call sites (renderPass:276, subtreePass:214) and the mount path; clear after. On unmount-causing passes nothing extra yet (Task 10). `_pendingCompletionGroups` arming from Task 4 stays as-is — groups now actually accumulate registrations during apply, so arm AFTER apply.

- [ ] **Step 2: Tests**

```swift
@Test @MainActor func withAnimationEmitsAnimateWithFinalWrite() {
    // opacity 0.5 → 1 inside withAnimation(.linear(duration: 1))
    // assert: setStyleProperty called with "1" (model final), backend.animations.count == 1,
    // request == AnimationRequest(property: "opacity", from: "-0.5", to: "0", mode: .additive,
    //                             timing: .init(durationMs: 1000, easing: "linear", …))
}
@Test @MainActor func plainWriteEmitsNoAnimate() { /* churn guard: counts["animate"] == nil */ }
@Test @MainActor func completionFiresAfterAllSettle() {
    // two properties change in one withAnimation(completion:) → completion NOT fired
    // after settling first; fired after settling second + pump
}
@Test @MainActor func repeatForeverExcludedFromGroup() { /* completion fires immediately (one pump) while animation still recorded */ }
@Test @MainActor func retargetReplacesRegistryEntry() { /* second withAnimation on same property: registry has 1 entry, 2 recorded animations (additive stack) */ }
@Test @MainActor func nonStyleChangesNeverAnimate() { /* attribute/text change under withAnimation → no animate call */ }
```

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): WAAPI engine wiring in applier — additive animate on style patches, registry, completion groups`

---

### Task 8: `AnyTransition` + `.transition(_:)` wrapper + registry

**Files:**
- Create: `Sources/SwiftWUI/Animation/AnyTransition.swift`, `Sources/SwiftWUI/Animation/TransitionModifier.swift`, `Sources/SwiftWUI/Animation/TransitionRegistry.swift`
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (ctx field), `Sources/SwiftWUI/Runtime/Runtime.swift` (own + sweep)
- Test: `Tests/SwiftWUITests/TransitionRegistrationTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct AnyTransition {
      // storage: insertionActive / removalActive: [StyleDeclaration], animation: Animation?
      public static let identity: AnyTransition                 // both empty
      public static let opacity: AnyTransition                  // active: [.opacity(0)]
      public static func scale(_ s: Double = 0.0, anchor: UnitPoint = .center) -> AnyTransition
      public static func offset(x: Double = 0, y: Double = 0) -> AnyTransition   // active: translate
      public static func move(edge: Edge) -> AnyTransition      // active: translate ±100% on the edge axis
      public static let slide: AnyTransition                    // asymmetric(insertion: .move(.leading), removal: .move(.trailing))
      /// Primitive (anim spec §3.4, adapted): active styles only — enter animates
      /// active → current presentation, exit animates current → active. The
      /// TagModifier-based .modifier(active:identity:) is DEFERRED (spec §14 note added in Task 15 docs).
      public static func active(_ declarations: [StyleDeclaration]) -> AnyTransition
      public func combined(with other: AnyTransition) -> AnyTransition   // union of both phase lists
      public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition
      public func animation(_ a: Animation?) -> AnyTransition
  }
  extension Tag { public func transition(_ t: AnyTransition) -> some Tag }
  @MainActor final class TransitionRegistry {
      private(set) var byIdentity: [NodeIdentity: AnyTransition]
      func register(_ t: AnyTransition, for id: NodeIdentity)   // marks seen-this-pass like ListenerRegistry
      func transition(for id: NodeIdentity) -> AnyTransition?
      func sweep(under root: NodeIdentity, keep: Set<NodeIdentity>)
  }
  // ResolveContext: var transitions: TransitionRegistry? = nil  (seeded by Runtime; persistent across passes)
  ```
  `UnitPoint`/`Edge` come from Task 12 — to keep this task self-contained, `scale(_:anchor:)`'s anchor lands in Task 12; HERE ship `scale(_ s: Double)` without anchor and extend in Task 12.
- Registration mechanics: `_TransitionTag<Content: Tag>` resolves content then walks resolved nodes exactly like `applyStyleWrapper` (element roots register; component roots descend; text no-op) registering `ctx.transitions?.register(t, for: elementIdentity)`. Persistent registry + sweep by live element ids: collect "seen" ids per pass — Runtime calls `transitions.sweep(under: passRoot, keep: seenThisPass)` mirroring `listeners.sweep` (Runtime.swift:272). Since only `_TransitionTag`-wrapped elements register, a subtree pass that doesn't re-run the wrapper keeps prior registrations for identities OUTSIDE the pass root — sweep only under the pass root, same rule as listeners: registrations under the pass root must be re-asserted by the pass, which happens iff the wrapper is inside the pass root. Wrapper above the pass root → registration untouched (correct). Add a `ScopedEquivalence`-style test.

- [ ] **Step 1: Implement** (as specified above; `move(edge:)` values: `.leading → "translate: -100% 0"`, `.trailing → "100% 0"`, `.top → "0 -100%"`, `.bottom → "0 100%"` — use a plain `Edge` enum defined HERE (leading/trailing/top/bottom) since Task 12 needs it anyway; LTR-only v1, documented).
- [ ] **Step 2: Tests** — registration only (no animation yet): wrapped element identity present in registry; unwrapped absent; sweep drops after conditional removes the wrapper; scoped ≡ full for a wrapper above/below the dirty component.
- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): AnyTransition surface + .transition registration registry`

---

### Task 9: Enter transitions

**Files:**
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift` (mount), `Sources/SwiftWUI/Runtime/Runtime.swift` (pass context: transitions + suppress flag), `Sources/SwiftWUI/Render/AdoptingBackend.swift` or the hydration boot path — grep `AdoptingBackend` usage in `SwiftWUIDOM/SnapshotBoot.swift` for where adoption's first diff happens; the SUPPRESS flag is core-side: `Runtime._suppressTransitionsOnce: Bool` (public SPI, set by boot code before its first flush)
- Test: `Tests/SwiftWUITests/TransitionEnterTests.swift`

**Interfaces:**
- Consumes: `AnimationPassContext.suppressTransitions` (Task 7), `TransitionRegistry` (Task 8).
- Produces: enter behavior — in `TreeApplier.mount(.element)`, AFTER `backend.insert` and children mount:
  ```swift
  if let pass = animationPass, !pass.suppressTransitions, !pass.reduceMotion,
     let t = transitionsRef?.transition(for: el.identity) {
      let anim = t.animation ?? pass.transactions[el.identity]?.animation ?? currentAmbientForPass
      // per active declaration: replace-mode request, from: activeValue, to: nil (implicit current)
  }
  ```
  Driving animation resolution order (anim spec §3.4): transition's own `.animation` → the transaction that caused the insert. "The transaction that caused the insert" = the pass ambient: thread ONE `defaultTransaction: Transaction?` into `AnimationPassContext` (renderPass: the drained `pendingTransactions[.root]` or the single subtree cover's txn; subtreePass: its captured txn). If neither exists → NO enter animation (SwiftUI: unanimated structural change doesn't transition) — EXCEPT when the transition carries its own `.animation`, which always plays. Group registration: same rules as Task 7 (register on the causing transaction's group when it drove the timing).
- Cold mount: `renderPass`'s `current == nil` branch already sets `suppressTransitions: true` (Task 7). Hydration/adoption: `_suppressTransitionsOnce` consumed by the next flush.

- [ ] **Step 1: Implement** (above; keep the mount-path lookup cheap: skip entirely when `transitionsRef?.byIdentity.isEmpty != false`).
- [ ] **Step 2: Tests**

```swift
@Test @MainActor func enterAnimatesFromActiveToImplicit() {
    // if flag { Div().transition(.opacity) } ; flag=false→true inside withAnimation(.linear(duration:1))
    // assert one animate: request.property == "opacity", from == "0", to == nil, mode == .replace
}
@Test @MainActor func noTransactionNoEnter() { /* plain toggle → mount, zero animate calls */ }
@Test @MainActor func transitionOwnAnimationAlwaysPlays() { /* .transition(.opacity.animation(.easeOut(duration:0.2))) + plain toggle → animate with easeOut */ }
@Test @MainActor func coldMountNeverEnters() { /* initial mount() with transitions present → zero animate */ }
@Test @MainActor func suppressOnceFlagSuppressesExactlyOnePass() { /* set flag, toggle (no animate), toggle again inside withAnimation (animates) */ }
@Test @MainActor func combinedTransitionEmitsOneAnimatePerProperty() { /* .opacity.combined(with: .offset(y: 20)) → 2 requests: opacity + translate */ }
```

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): enter transitions with first-pass suppression`

---

### Task 10: Exit orchestration (ghosts, deferred removal, replaceSelf)

**Files:**
- Modify: `Sources/SwiftWUI/Render/Reconciler.swift` (ChildrenPlan), `Sources/SwiftWUI/Render/TreeApplier.swift` (applyChildren, replace, unmount), `Sources/SwiftWUI/Runtime/Runtime.swift`
- Test: `Tests/SwiftWUITests/TransitionExitTests.swift` (extend the existing `ExitTests.swift` naming if that file covers sweep — read it first; do NOT repurpose unrelated tests)

**Interfaces:**
- Produces:
  ```swift
  // ChildrenPlan gains parallel payload for removals (adoption + exit need the Node):
  var removedNodes: [Node]          // same order as removedOldIndices; filled by diffChildren
  // TreeApplier:
  struct ExitRecord {
      let mounted: MountedNode<Backend.HostNode>
      let oldNode: Node
      var tokens: [AnimationToken]
      var settled = 0               // idempotence bookkeeping
  }
  private(set) var exiting: [NodeIdentity: ExitRecord]   // keyed by removed root's identity (element or component)
  /// Returns true when an exit was started (ghost kept); false → caller unmounts normally.
  func beginExit(_ m: MountedNode<Backend.HostNode>, node: Node) -> Bool
  func finishExit(_ id: NodeIdentity)   // idempotent: removeHosts + tearDownListeners + purge record
  ```
- Node-identity helper: `func rootIdentity(of node: Node) -> NodeIdentity?` (element → identity, component → identity, text → nil) — file-private in TreeApplier.

- [ ] **Step 1: Implement**

1. `diffChildren`: build `removedNodes = removed.map { old[$0] }` (it has `old` in scope). `isIdentity` unchanged.
2. `applyChildren` removals loop:
   ```swift
   for (k, i) in plan.removedOldIndices.enumerated() {
       let m = oldChildren[i]
       if animationPass != nil, beginExit(m, node: plan.removedNodes[k]) { continue }
       unmount(m)
   }
   ```
3. `beginExit`: collect exit work by walking the mounted subtree for element hosts whose `elementIdentity` has a registered transition with non-empty `removalActive` (walk `m` recursively; stop descending into a subtree once its root animates — v1 rule: only the OUTERMOST transition-bearing roots animate, matching SwiftUI's outermost-transition behavior). No transition-bearing root found → return false. Else:
   - `unregister(m)` (frees componentIndex; ghost leaves shadow bookkeeping — parent.children rebuild below drops it),
   - `backend.setAttribute(host, name: "inert", value: "")` on each realized top-level host of `m` (anim spec §7.3.2) — do NOT tearDownListeners (registry sweep already killed them; backend listener teardown happens in `finishExit` — anim spec §7.3 + adoption in Task 11 needs them attached),
   - for each animating root/declaration: request `.replace(from: nil, to: activeValue)` with timing = transition's `.animation` ?? pass default (same resolution as Task 9; none → duration 0 → skip animate and `finishExit` immediately after the pass — SwiftUI parity: unanimated remove is instant),
   - `guard let key = rootIdentity(of: node)` (text root → return false), store `ExitRecord`; each token's `onSettle` increments `settled` and when `settled == tokens.count` → `finishExit(key)`. Group registration on the driving transaction as in Task 7.
4. `finishExit`: guard record exists (idempotent — anim spec §7.3.6); `tearDownListeners(record.mounted)`; `removeHosts(record.mounted)`; drop record.
5. **Ghost anchor safety:** ghosts are OUT of `parent.children` after the rebuild, so `firstHost`/`anchor(after:)`/`moveHosts` never see them — new nodes insert before live anchors and may land before OR after a ghost sibling; acceptable (anim spec §7.3.5). `MockBackend.serializeHTML` will show ghosts — tests must settle exits before HTML asserts (or assert ghost presence explicitly).
6. **Parent unmount force-finish (anim spec §7.3.6):** in `unmount(_:)` first line: `forceFinishExits(under: m)` — iterate `exiting` records whose `mounted.hostParent` chain passes through `m`'s hosts; cheaper + sufficient rule: on `removeHosts` of an ancestor the ghost DOM dies anyway, so force-finish by identity prefix: `for (id, rec) in exiting where /* id under any identity in m's subtree */` — implement with the SAME prefix check used by `StateStore.sweep` (`id.isSelfOrDescendant(of:)`) against `m`'s nearest identity (`componentIdentity ?? elementIdentity` walked down). For each hit: `rec.tokens.forEach(backend.cancelAnimation)`, `finishExit(id)`.
7. **replaceSelf (anim spec §7.1):** in `replace()`, before `unmount(m)`: try `beginExit(m, node: oldNodeForM)` — `replace` doesn't HAVE the old Node… extend the patch: `case replaceSelf(with: Node)` stays, but `apply` receives it while `m` still maps 1:1 to the old node — thread the old node in: change `Reconciler.diff` to emit `.replaceSelf(with: new)` as today, and in `TreeApplier.replace`, reconstruct the exit record's `oldNode` REQUIREMENT away: `beginExit` only needs `node` for (a) root identity — derivable from `m` (`componentIdentity` or `elementIdentity`), and (b) Task 11 adoption re-diff. So: change `beginExit(_ m:, node: Node?)` — `node` optional; `replace()` passes nil (adoption after replaceSelf-exit then falls back to force-finish + fresh mount, documented); `applyChildren` passes the real node. Enter side of replaceSelf: the new node mounts through `mount()` → Task 9 path fires automatically.
8. Runtime: nothing new — pass context already set around apply. ADD to renderPass/subtreePass, after `effects` commit: if `pass had no animation context` → applier exits still work (context nil → beginExit never called → today's behavior). Zero-config regression safety.

- [ ] **Step 2: Tests** (drive settles via `MockBackend.settleAnimation`):

```swift
@Test @MainActor func exitDefersRemovalUntilSettle() {
    // toggle off inside withAnimation; assert host still in serializeHTML + inert attr set +
    // one animate(to: "0" /* opacity active */); settle → host gone, counts["remove"] bumped
}
@Test @MainActor func unanimatedRemoveIsInstant() { /* plain toggle, no ambient txn, transition w/o own animation → immediate removal, zero animate */ }
@Test @MainActor func exitWithoutTransitionUnchanged() { /* no .transition → churn identical to main baseline */ }
@Test @MainActor func parentUnmountForceFinishesChildExit() { /* outer branch removes parent while child ghost mid-exit → both gone, cancelAnimation called, no crash on late settle */ }
@Test @MainActor func replaceSelfFiresExitAndEnterSimultaneously() {
    // same-position identity swap at a subtree root (switch-branch): old ghost animating out
    // AFTER new node in DOM order; both animate calls recorded
}
@Test @MainActor func moveAroundGhostDoesNotCrash() { /* keyed reorder while a ghost exists between items */ }
@Test @MainActor func onDisappearFiresAtExitStart() { /* .onDisappear inside exiting subtree fired on the removal pass, before settle */ }
```

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): exit transitions — inert ghosts, deferred removal, replaceSelf dual-fire, force-finish`

---

### Task 11: Bidirectional interruption (ghost adoption + cancel-enter)

**Files:**
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift` (applyChildren fresh path, mount enter tracking), `Sources/SwiftWUI/Animation/AnimationRegistry.swift` (enter tracking uses the same registry — key `(identity, property)` already fits)
- Test: `Tests/SwiftWUITests/TransitionInterruptionTests.swift`

**Interfaces:**
- Consumes: `exiting` (Task 10), enter tokens (Task 9 — TRACK them: Task 9's enter animations must `animationRegistry.track` with their element identity, same as engine animations; revisit Task 9 code while implementing this task if it didn't).
- Produces:
  - **Re-insertion during exit (anim spec §7.5):** in `applyChildren`, `.fresh(node)` case FIRST checks `if let key = rootIdentity(of: node), var rec = exiting[key]`:
    ```swift
    rec.tokens.forEach(backend.cancelAnimation)     // presentation snaps to model (additive layers die)
    exiting[key] = nil                               // before re-diff (settle callbacks are idempotent)
    // ghost back to life:
    reregister(rec.mounted)                          // mirror of unregister: repopulate componentIndex
    remove inert attrs (walk realized roots: backend.removeAttribute(h, name: "inert"))
    let patches = Reconciler().diff(old: rec.oldNode, new: node)
    apply(patches, to: rec.mounted, endAnchor: anchorNode)
    moveHosts(rec.mounted, before: anchorNode, in: hostParent)   // ghost may be out of position
    newChildren[idx] = rec.mounted
    // then re-run the ENTER path for it (Task 9 logic, from current presentation — WAAPI implicit-from)
    ```
    `rec.oldNode == nil` (replaceSelf ghosts) → force-finish + normal fresh mount (documented fallback).
  - **Removal during enter (anim spec §7.5):** in `beginExit`, before starting exit animations: `animationRegistry` entries for the exiting roots' identities → `backend.cancelAnimation(token)` + remove. Exit then starts from current presentation automatically (implicit-from).
  - `reregister(_ m:)`: walk m, `if let id = m.componentIdentity { componentIndex[id] = m }` recursively.
- State note (anim spec §7.5): state was swept at exit-start; adopted subtree gets FRESH `@State` — assert that in a test, document in the doc comment.

- [ ] **Step 1: Implement** (above).
- [ ] **Step 2: Tests**

```swift
@Test @MainActor func toggleBackMidExitAdoptsGhost() {
    // off (exit starts) → on BEFORE settle: no duplicate hosts (serializeHTML has exactly one),
    // cancelAnimation called, inert removed, enter animate recorded
}
@Test @MainActor func removalMidEnterCancelsAndExitsFromCurrent() { /* on → off before enter settle: enter token cancelled, exit request from: nil */ }
@Test @MainActor func adoptedSubtreeStateIsFresh() { /* counter inside transitioned branch: increment, toggle off, back on mid-exit → counter shows 0 */ }
@Test @MainActor func toggleSpamIsStable() { /* 5 rapid toggles with settles interleaved randomly (fixed seed loop) → final state consistent, no crash, exiting.isEmpty at rest */ }
```

- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): bidirectional interruption — ghost adoption and enter cancellation`

---

### Task 12: Transform modifiers + `.cssTransition` rename

**Files:**
- Create: `Sources/SwiftWUI/Styles/TransformModifiers.swift` (UnitPoint + declarations + Tag/HTMLTag modifiers)
- Modify: `Sources/SwiftWUI/Styles/StyleDeclaration.swift` (statics), `Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift:76,154`, `Sources/SwiftWUI/Styles/StyleModifiers+HTMLTag.swift:69` (rename), `Sources/SwiftWUI/Animation/AnyTransition.swift` (scale anchor)
- Test: `Tests/SwiftWUITests/TransformModifierTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct UnitPoint: Equatable {
      public var x: Double; public var y: Double     // 0…1
      public static let center/topLeading/top/topTrailing/leading/trailing/bottomLeading/bottom/bottomTrailing
      var cssTransformOrigin: String                  // "50% 50%" etc.
  }
  // StyleDeclaration statics: translate(x: CSSLength, y: CSSLength), scale(Double), rotate(degrees: Double), transformOrigin(UnitPoint)
  extension Tag {   // + matching HTMLTag Self-returning variants, following StyleModifiers+HTMLTag.swift pattern
      public func offset(x: Double = 0, y: Double = 0) -> some Tag          // translate: Xpx Ypx
      public func scaleEffect(_ s: Double, anchor: UnitPoint = .center) -> some Tag   // scale + transform-origin (only when anchor != .center)
      public func rotationEffect(_ degrees: Double, anchor: UnitPoint = .center) -> some Tag
  }
  ```
- Rename (anim spec §3.4): `.transition(String)` → `.cssTransition(String)` at StyleModifiers+Tag.swift:76,154 AND StyleModifiers+HTMLTag.swift:69. `StyleProxy.transition` (StyleProxy.swift:95) KEEPS its name (explicit decision). `StyleDeclaration.transition(String)` factory (StyleDeclaration.swift:69) keeps its name (internal-ish factory, no Tag-surface collision).
- Grep sites using the old name: `grep -rn '\.transition(' Sources Tests Sites Examples` — update ALL callers (tutorial site sources included; the Sites/Tutorial content rebuild happens in Task 15).
- One `transform-origin` per element (anim spec §3.5): document on both anchored modifiers; bare `transform` intentionally has NO typed modifier (reserved for FLIP).

- [ ] **Step 1: Implement**
- [ ] **Step 2: Tests** — declarations render (`translate: 10px 20px`, `rotate: 45deg`, `scale: 1.2`, origin only when non-center); rename compiles: add one usage `Div().cssTransition("opacity 0.2s")` test + `Div().transition(.opacity)` overload coexistence; independent channels: `.offset` + `.scaleEffect` on one element → two style entries, and under `withAnimation` two separate animate calls (one per property — the §6.7 channel guarantee).
- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): offset/scaleEffect/rotationEffect via individual transform channels; rename cssTransition`

---

### Task 13: Reduced motion (signal + env key + engine gating)

**Files:**
- Modify: `Sources/SwiftWUI/Environment/EnvironmentSignals.swift` (new signal — follow the Writer-closure recipe documented in that file), `Sources/SwiftWUI/Environment/Environment.swift` (`accessibilityReduceMotion` key — copy the `colorScheme` computed-key pattern), `Sources/SwiftWUI/Runtime/Runtime.swift` (AnimationPassContext.reduceMotion = signals value), `Sources/SwiftWUIDOM/DOMBackend.swift` (matchMedia `(prefers-reduced-motion: reduce)` — copy the colorScheme matchMedia block, DOMBackend.swift ~:275-285)
- Test: `Tests/SwiftWUITests/ReducedMotionTests.swift`

**Interfaces:**
- Produces: `EnvironmentSignals.reduceMotion: Bool` (default false), `EnvironmentValues.accessibilityReduceMotion: Bool`.
- Engine policy (anim spec §9): `AnimationPassContext.reduceMotion == true` → Task 7 skips `animate` but keeps `register()/settle()` pairing (instant + completion fires); Task 9 enter skipped; Task 10 exit → `beginExit` returns false (instant removal). All three sites already branch on the flag — this task WIRES it and tests the policy.

- [ ] **Step 1: Implement** (MockBackend: tests flip via `backend.environmentWriter` — the existing `EnvironmentSignalsTests` show the call shape).
- [ ] **Step 2: Tests** — with reduceMotion on: withAnimation change → no animate call, completion still fires; transitioned insert/remove → instant, no ghosts; `\.accessibilityReduceMotion` readable in a body and re-renders on change (signals tracking — mirror an existing colorScheme test).
- [ ] **Step 3: Run** `swift test`.
- [ ] **Step 4: Commit** `feat(anim): prefers-reduced-motion signal, env key, instant-animation policy`

---

### Task 14: DOMBackend `animate` (WASM)

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift`
- Gate: native `swift build && swift test` PLUS `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM`

**Interfaces:**
- Consumes: `AnimationRequest`/`AnimationToken`/`AnimationSettle` (Task 6).
- Produces: real WAAPI calls. Sketch:
  ```swift
  final class DOMAnimationToken: AnimationToken {
      let animation: JSObject               // retained Animation
      var settled = false
      var settle: ((AnimationSettle) -> Void)?
      var timeoutID: JSValue?
  }
  func animate(_ node: JSObject, request: AnimationRequest,
               onSettle: @escaping (AnimationSettle) -> Void) -> AnimationToken? {
      // keyframes: [[String: String]] — one entry per non-nil endpoint:
      //   replace(from,to): [{prop: from, offset: 0}] / [{prop: to}] / both
      //   additive: both endpoints always present
      // options: duration, delay, easing, iterations (Infinity for isInfinite),
      //          direction: autoreverses ? "alternate" : "normal",
      //          composite: additive ? "add" : "replace", fill: "none"
      // let anim = node.animate!(kf.jsValue, options.jsValue).object!
      // finished.then(JSOneshotClosure { settleOnce(.finished) }, catch → .cancelled)
      // setTimeout(durationMs + delayMs + 200) { settleOnce(.forced); anim.cancel() }  // timeout race (anim spec §7.3.3)
      // SKIP the timeout for isInfinite requests
  }
  ```
  `settleOnce`: guards `settled`, clears timeout (`clearTimeout`), releases the closure. `cancelAnimation` → `anim.cancel()` + `settleOnce(.cancelled)`. `finishAnimation` → `anim.finish()` (WAAPI throws InvalidStateError on finish() of an infinite animation — use `cancel()` for `isInfinite`) + `settleOnce(.forced)`.
- `visibilitychange` (anim spec §7.3.3): one document-level listener installed lazily on first `animate` (retained `JSClosure`, page lifetime — the `beginEnvironmentObservation` retention pattern): on `document.hidden == true` → force-finish every live token (walk a `Set`/table of unsettled tokens the backend keeps).
- `linear()` easing fallback (anim spec §13): wrap the `animate` call in a JS-exception check? JavaScriptKit: use `try?`-style `throws` variant if available on the vendored bindings, else pre-test once: `CSS.supports("animation-timing-function", "linear(0, 1)")` cached Bool; unsupported → substitute `"ease-out"`.
- All structural DOM ops stay on BridgeJS; `animate` uses dynamic `JSObject` (decision #14). `#if arch(wasm32)` NOT needed — DOMBackend is WASM-only already (verify how the file guards; follow it).

- [ ] **Step 1: Implement**
- [ ] **Step 2: Native suite** `swift test` (unchanged — DOMBackend isn't in native tests) **+ WASM gate** `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM` — compiles clean.
- [ ] **Step 3: Manual smoke prep** — extend `Examples/Counter` with one animated element (opacity toggle in `withAnimation(.spring…)` + a `.transition(.opacity.combined(with: .offset(y: 12)))` branch); build: `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`. (Browser check itself is Task 15's acceptance.)
- [ ] **Step 4: Commit** `feat(anim): DOMBackend WAAPI animate with finished/timeout/visibilitychange settle`

---

### Task 15: Docs + Tutorials site + CHANGELOG + browser acceptance

**Files:**
- Modify: `CHANGELOG.md` (grep for it; else release notes location used for v0.2.0), `README.md` (feature list), spec §14 (note the `.modifier(active:identity:)` → `.active(_:)` primitive adaptation from Task 8), `Sites/Tutorial/…` (new "Animations" tutorial page — follow the existing page structure; cover withAnimation, springs, .animation(_:value:), .transition, reduced motion; update every `.transition(String)` mention to `.cssTransition`)
- This task is REQUIRED (anim spec §12 item 10) — not optional polish.

- [ ] **Step 1: Write docs + tutorial page**; rebuild the tutorial site the way phase 7 did (check `Sites/Tutorial` README/build script; `swift run … ssg`).
- [ ] **Step 2: Run** `swift test` one last full pass + tutorial site builds.
- [ ] **Step 3: Browser acceptance (manual, user-assisted)** — checklist to hand to the user:
  1. Counter example: spring feel on toggle (smooth, no snap).
  2. Interrupt mid-flight (double-click fast) — no jump, retargets smoothly.
  3. Transition branch: enter fades/slides in, exit animates and element disappears AFTER animation.
  4. Toggle-spam the transition — no duplicate elements, no stuck ghosts (inspect DOM).
  5. Hide the tab mid-exit, return — ghost gone.
  6. OS reduced-motion on → everything instant, no console errors.
- [ ] **Step 4: Commit** `docs(anim): animations tutorial page, changelog, spec sync`

---

## Self-review checklist (ran at plan-write time)

- Spec coverage: §3 API (Tasks 3,4,5,8,12), §4 plumbing (4,5), §5 style map (1,2), §6 engine (6,7), §7 transitions/exit/interruption/completions (8,9,10,11 + 7), §8 backend (2,6,14), §9 reduced motion (13), §10 SSG/hydration (2 serialization, 9 suppression), §11 testing (per-task), §12 docs (15), §13 risks → dedicated tests in 2,5,10,11.
- Known deviation from spec recorded: `AnyTransition.modifier(active:identity:)` (TagModifier-based) → v1 primitive `AnyTransition.active([StyleDeclaration])`; spec §14 updated in Task 15. Rationale: engine animates CSS properties; a TagModifier-based active phase requires double-resolve diffing — deferred.
- Type-consistency: all shared names in the Interface Registry table; `AnimationPassContext.reduceMotion`/`suppressTransitions` created in Task 7 (fields exist before their wiring tasks — intentional).
