# Responsive styling — completing the media layer

**Date:** 2026-07-14
**Status:** Approved design (brainstorm complete)
**Branch:** to be created from `main`
**Depends on:** phase-3 styles (`StyleRegistry`, `MediaQuery`, `StyleProxy`, `Rule`), phase-8a environment signals (`EnvironmentSignals`, backend seam).

## Context

SwiftWUI already ships CSS `@media` support: `MediaQuery` (`Styles/MediaQuery.swift`), the
`.media(query){ … }` element modifier (`StyleModifiers+Tag.swift`), `Rule(…, media:)`
(`Rule.swift`), `StyleProxy.media` for `Style` bundles, all emitted through the single
deduplicating `StyleRegistry` into one managed `<style>` (SSR/SSG-correct). What is missing is
a **reactive** media check the user can branch on inside `body`, plus a handful of expressive
gaps (combinators, orientation, height, named breakpoints, responsive values) and container
queries.

This spec completes the responsive layer as **one media vocabulary across five surfaces**. It
is additive — nothing currently shipping changes behavior; the only refactor is a contained
generalization of `StyleRegistry`'s at-rule wrapper (needed for `@container`).

## Goal

One `MediaQuery` type, reused everywhere:

| # | Surface | Strategy | Status |
|---|---------|----------|--------|
| 1 | `Rule(…, media:/container:)` | CSS emission | media exists; **+container** |
| 2 | `.media()` / `.container()` on Tag | CSS emission | media exists; **+container** |
| 3 | `media.matches(query)` in `body` via `@Environment(\.media)` | matchMedia reactive | **new** |
| 4 | `Responsive<Value>` (`.padding(responsive(…))`) | CSS emission (sugar over #2) | **new** |
| 5 | shared `Breakpoint` scale + `MediaQuery.up/.down` | feeds #1–#4 | **new** |

Surfaces 1, 2, 4, 5 are pure CSS emission → correct on first paint before WASM boots, FOUC-free,
SSR/SEO-correct. Surface 3 is the matchMedia reactive path — reserved for **structural**
branching (mount a different subtree), which CSS cannot express.

## Non-goals (YAGNI)

- **No container body-check.** Container size is not a `matchMedia` concept — reactively reading
  a container's size needs `ResizeObserver` per element. Out of scope; CSS `@container` covers the
  need FOUC-free. `matches()` stays viewport/media-feature only.
- **No `GeometryReader` / raw viewport width signal.** A continuous pixel width exposed to `body`
  is a per-resize-tick re-render hot path. Excluded deliberately. Coarse boolean `matches()` only.
- **No `clamp()` fluid value.** Separate concern; can be added to `CSSLength` later.
- **No `horizontalSizeClass` sugar.** `matches(query)` is the chosen body API; a size-class enum
  can be layered on later if wanted.
- **No configurable/theme-injected breakpoint scale.** A static default scale ships; injection is
  a later refinement (`// ponytail`).
- **No `@container` in `matches()` and no per-property container-size responsive values.**

## Section A — `MediaQuery` extensions

`MediaQuery` today (`Styles/MediaQuery.swift`) is a struct with `condition: String` and statics
`maxWidth`, `minWidth`, `prefersColorScheme`, `custom`. Each simple feature is already
individually parenthesized (`"(max-width: 600px)"`). Add:

```swift
public enum Orientation: String { case portrait, landscape }

extension MediaQuery {
    public static func minHeight(_ l: CSSLength) -> MediaQuery { .init(condition: "(min-height: \(l.css))") }
    public static func maxHeight(_ l: CSSLength) -> MediaQuery { .init(condition: "(max-height: \(l.css))") }
    public static func orientation(_ o: Orientation) -> MediaQuery { .init(condition: "(orientation: \(o.rawValue))") }

    // Combinators — each COMPOUND operand wrapped in parens (fixes v1's bug where
    // nested and/or produced invalid, unparenthesized CSS).
    public static func and(_ a: MediaQuery, _ b: MediaQuery) -> MediaQuery {
        .init(condition: "(\(a.condition) and \(b.condition))")
    }
    public static func or(_ a: MediaQuery, _ b: MediaQuery) -> MediaQuery {
        .init(condition: "(\(a.condition) or \(b.condition))")
    }
    public static func not(_ q: MediaQuery) -> MediaQuery {
        .init(condition: "(not \(q.condition))")
    }
}
```

Wrapping compounds in parens keeps `@media`, `@container`, and `matchMedia` all valid under
nesting (e.g. `and(or(a,b), c)` → `(((a) or (b)) and (c))`). Extra outer parens are harmless in
every consumer. The same `condition` string feeds the CSS path and the `matchMedia` path — one
serializer, no divergence.

## Section B — `Breakpoint` scale + `.up`/`.down`

One named scale, defined once, so surfaces #3 and #4 agree with #1/#2 on pixel thresholds:

```swift
public enum Breakpoint: Int, Comparable, CaseIterable {
    case sm, md, lg, xl
    public var minWidthPx: Double {            // default scale
        switch self { case .sm: 640; case .md: 768; case .lg: 1024; case .xl: 1280 }
    }
    public static func < (a: Breakpoint, b: Breakpoint) -> Bool { a.rawValue < b.rawValue }
}

extension MediaQuery {
    /// Mobile-first: matches at/above the breakpoint. `@media (min-width: …)`.
    public static func up(_ bp: Breakpoint) -> MediaQuery { .minWidth(.px(bp.minWidthPx)) }
    /// Matches below the breakpoint. -0.02px avoids the exact-boundary overlap with `up`.
    public static func down(_ bp: Breakpoint) -> MediaQuery { .maxWidth(.px(bp.minWidthPx - 0.02)) }
}
```

`// ponytail: static default scale; a theme-injected scale can replace minWidthPx later without
touching call sites.`

Usable everywhere the type is: `.media(.up(.md))`, `Rule(…, media: .up(.md))`,
`media.matches(.up(.lg))`, and internally by `Responsive` (Section C).

## Section C — `Responsive<Value>` values

A per-breakpoint value accepted by style-modifier overloads; **pure sugar** that desugars to a
base declaration plus one `.media(.up(bp)){ … }` per override — no new emission machinery.

```swift
public struct Responsive<Value> {
    public var base: Value
    public var overrides: [(Breakpoint, Value)]   // ordered ascending sm→xl
}

public func responsive<V>(_ base: V, sm: V? = nil, md: V? = nil,
                          lg: V? = nil, xl: V? = nil) -> Responsive<V> {
    var o: [(Breakpoint, V)] = []
    if let sm { o.append((.sm, sm)) }; if let md { o.append((.md, md)) }
    if let lg { o.append((.lg, lg)) }; if let xl { o.append((.xl, xl)) }
    return Responsive(base: base, overrides: o)
}
```

**Desugar mechanism** — one generic helper + thin per-property wrappers on `Tag` and `_StyledTag`:

```swift
extension Tag {
    func _responsive<V>(_ r: Responsive<V>,
                        _ apply: @escaping (inout StyleProxy, V) -> Void) -> _StyledTag<Self> {
        // 1. base as a normal declaration wrapper
        var acc = _styledProxy { apply(&$0, r.base) }          // base decls, no media
        // 2. one min-width media rule per override (mobile-first cascade)
        for (bp, v) in r.overrides {
            acc = acc.media(.up(bp)) { apply(&$0, v) }
        }
        return acc
    }
    public func padding(_ r: Responsive<CSSLength>) -> _StyledTag<Self> {
        _responsive(r) { $0.padding($1) }
    }
    // …one wrapper per responsive-capable property (below)
}
```

The exact plumbing (how `_responsive` seeds the base wrapper and appends media rules) mirrors the
existing `_styled` / `_styledRule` collapse in `StyleModifiers+Tag.swift`; the implementation plan
resolves the precise builder calls. Output CSS is byte-identical to writing the base modifier plus
N `.media(.up(bp))` calls by hand.

```swift
Div { … }.padding(responsive(.px(16), md: .px(32), lg: .px(48)))
// .swui-x { padding:16px }
// @media (min-width:768px){ .swui-x{ padding:32px } }
// @media (min-width:1024px){ .swui-x{ padding:48px } }
```

**Responsive-capable properties (starter set, both `Tag` and `_StyledTag`):**
`padding(_:)`, `margin(_:)`, `width`, `height`, `minWidth`, `maxWidth`, `fontSize`, `display`,
`flexDirection`, `gap`, `textAlign`, `gridTemplateColumns`. More are mechanical: add a wrapper that
forwards to the matching `StyleProxy` mutator. Non-goal to overload every property up front.

`// ponytail: overload set bounded to layout/typography props that actually vary by width; extend
per demand, not speculatively.`

## Section D — Container queries (`@container`)

CSS-only (surfaces #1 and #2). Two pieces: declaring an element a container, and conditional
styles keyed on the container's size.

**Declaration modifier** (plain CSS declarations — no new machinery):

```swift
public enum ContainerType: String { case inlineSize = "inline-size", size, normal }

// on Tag / _StyledTag:
public func containerType(_ type: ContainerType = .inlineSize, name: String? = nil) -> _StyledTag<Self> {
    // emits container-type: <type>;  (+ container-name: <name> when provided)
}
```

`name`, when provided, is validated with `CSSSanitize.isValidIdent` (same gate as `Rule` names)
before emission; invalid names are dropped with an assert.

**Conditional-styles modifier** (reuses `MediaQuery` for the size condition — the `(min-width: …)`
grammar inside `@container` is identical):

```swift
// on Tag / _StyledTag:
public func container(_ query: MediaQuery, name: String? = nil,
                      _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self>
// → @container [name ](min-width: 400px) { .swui-hash { … } }
```

`MediaQuery.prefersColorScheme` is meaningless inside `@container` (emits an ignored no-op rule);
documented as "put size conditions in `container`." `// ponytail: reuse MediaQuery, document the
ceiling rather than forking a ContainerQuery type.`

**Rule + StyleProxy symmetry:**

```swift
Rule(class: "card", container: .minWidth(.px(400)), containerName: "sidebar") { $0.flexDirection(.row) }
// StyleProxy (for Style bundles), mirroring .media:
public mutating func container(_ query: MediaQuery, name: String? = nil, _ body: (inout StyleProxy) -> Void)
```

`Rule`'s `container:`/`containerName:` are new optional params (default nil, source-compatible).
A rule sets at most one of `media:` / `container:`; both set → assert + prefer `media`.

## Section E — Reactive `matches()` in `body`

### E.1 `MediaMatchStore` (core, per-Runtime)

```swift
@MainActor @Observable
public final class MediaMatchStore {
    // Baseline value captured at registration. NON-observed: it is written during
    // body eval (first read of a new query), which must not invalidate the very
    // read that triggers it. @ObservationIgnored keeps that write inert.
    @ObservationIgnored private var registered: [String: Bool] = [:]
    // Live overrides pushed by the backend change listener, which fires OUTSIDE
    // body eval. Observed → writing it invalidates the components that read it.
    private var changes: [String: Bool] = [:]
    // Backend seam (injected by Runtime): returns the current match synchronously
    // and retains a change listener. Non-browser backends return the SSR default.
    @ObservationIgnored private let observe: (String, @escaping (Bool) -> Void) -> Bool

    public init(observe: @escaping (String, @escaping (Bool) -> Void) -> Bool) {
        self.observe = observe
    }

    func matches(_ condition: String) -> Bool {
        let live = changes[condition]                    // TRACKED read → records dependency
        if let live { return live }
        if let base = registered[condition] { return base }   // same-render repeat read
        let initial = observe(condition) { [weak self] v in self?.update(condition, v) }
        registered[condition] = initial                  // non-observed write — safe during eval
        return initial
    }
    private func update(_ condition: String, _ v: Bool) {
        guard changes[condition] != v else { return }
        changes[condition] = v                           // observed write (post-eval) → re-render
    }
}
```

- **Tracking correctness:** every `matches` call reads the observed `changes` property first, so
  the reading component is registered as a dependent even on the first (nil) read. When the media
  flips, the backend listener calls `update`, writing `changes` → the component re-renders and
  reads the new value.
- **No state-mutation-during-eval hazard:** the only write during body eval is to
  `registered` (`@ObservationIgnored`), which is inert to Observation. `changes` is written solely
  from the change listener, which runs on a DOM event, never inside a render pass.
- **Dedup:** `observe` is called once per distinct `condition` (guarded by `registered`). One
  matchMedia listener per unique query, retained for Runtime lifetime.
  `// ponytail: no sweep — like StyleRegistry; bounded by distinct queries used.`
- **Granularity:** `changes` is one observed dictionary property → Observation tracks it whole, so
  any query flip invalidates every `matches` reader. Worst case one extra coalesced flush.
  `// ponytail: whole-store invalidation; split to per-key observation only if profiling shows it.`

### E.2 Environment exposure

```swift
public struct MediaProxy {
    let store: MediaMatchStore?                 // nil outside a live runtime (native/SSG)
    public func matches(_ q: MediaQuery) -> Bool {
        store?.matches(q.condition) ?? false    // SSR/native default: false (Section F)
    }
}

// EnvironmentValues (Environment.swift), alongside _signals:
struct _MediaStoreKey: EnvironmentKey { static let defaultValue: MediaMatchStore? = nil }
extension EnvironmentValues {
    var _mediaStore: MediaMatchStore? { get { self[_MediaStoreKey.self] } set { self[_MediaStoreKey.self] = newValue } }
    /// Reactive media matching. `media.matches(q)` re-renders the reading component when `q`
    /// crosses. Use for STRUCTURAL branching; for styling prefer `.media()`/`.container()` (no FOUC).
    public var media: MediaProxy { MediaProxy(store: _mediaStore) }
}
```

Usage:

```swift
struct Nav: Tag {
    @Environment(\.media) var media
    var body: some Tag {
        if media.matches(.maxWidth(.px(600))) { Hamburger() } else { FullNav() }
    }
}
```

### E.3 Backend seam

New protocol method on `RendererBackend`, with a default that yields the SSR behavior:

```swift
/// Reactive media matching (spec 2026-07-14). Called lazily the first time a component reads
/// `matches(condition)`. The backend evaluates the condition NOW (synchronous initial value),
/// retains a change listener calling `onChange` on every future flip, and returns the current
/// match. Non-browser backends return `false` and never call `onChange`.
func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool
```

```swift
extension RendererBackend {
    public func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool { false }
}
```

**`DOMBackend`** (`SwiftWUIDOM`):

```swift
private var retainedMediaClosures: [JSClosure] = []   // retained for backend lifetime
func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool {
    let mql = JSObject.global.window.matchMedia(condition).object!
    let closure = JSClosure { _ in onChange(mql.matches.boolean ?? false); return .undefined }
    _ = mql.addEventListener!("change", closure)
    retainedMediaClosures.append(closure)
    return mql.matches.boolean ?? false
}
```

(`matchMedia` addressed via the JSObject path, consistent with `beginEnvironmentObservation`;
`JSClosure` retained per the WASM rule that attached closures must be held Swift-side.)

**`MockBackend`** (test seam):

```swift
public private(set) var mediaObservers: [String: (Bool) -> Void] = [:]
public var mediaMatches: [String: Bool] = [:]                 // pre-seedable by tests
public func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool {
    bump("observeMediaQuery")
    mediaObservers[condition] = onChange
    return mediaMatches[condition] ?? false
}
/// Test helper: simulate a media-condition flip (resize / orientation change).
public func simulateMediaChange(_ condition: String, matches: Bool) {
    mediaMatches[condition] = matches
    mediaObservers[condition]?(matches)
}
```

### E.4 Runtime wiring

`Runtime` owns the `MediaMatchStore` and injects the backend seam as its `observe` closure (the
type-erasing hop from the generic backend to the non-generic core store, same shape as
`EnvironmentSignals.Writer`):

```swift
let mediaStore = MediaMatchStore(observe: { [weak backend] cond, onChange in
    backend?.observeMediaQuery(cond, onChange: onChange) ?? false
})
// injected into the root EnvironmentValues as _mediaStore, next to _signals.
```

No teardown per query; listeners live with the backend and are released when the Runtime/backend
is torn down (existing lifecycle).

## Section F — SSR / hydration / FOUC semantics

- **CSS surfaces (1, 2, 4, 5):** unchanged emission through `StyleRegistry` → `<style>`. Correct
  on first paint, before WASM boots. FOUC-free, SSR/SEO/print correct. No special handling.
- **`matches()` on the client, SPA mount:** the initial `matchMedia` read is synchronous during
  the first body eval, so the first client paint is already correct — no FOUC for surface 3 in a
  pure client-rendered app.
- **`matches()` under SSG/SSR prerender + hydration:** the server has no viewport. `observeMediaQuery`
  on non-DOM backends returns `false`, so the server renders the **base / else** branch. On
  hydration the client re-reads `matchMedia`; if it differs, the subtree swaps via a normal
  reconcile diff. There is a brief mismatch window (server showed the `false` branch). **Documented
  default: `false`.** No configurable assumed viewport (YAGNI).
- **Guidance in docs:** use `matches()` only for genuinely structural branching (different subtree).
  For anything expressible as style, use `.media()`/`.container()`/`responsive()` — zero FOUC.

## Section G — `StyleRegistry` generalization (enables `@container`)

Today `StyleRegistry.Entry` stores `media: String` and `text` wraps it hardcoded as
`@media \(media) { … }` (`StyleRegistry.swift:76-83`). Generalize the wrapper to an arbitrary
at-rule prelude so `@container` reuses the identical dedup/hash/sort/emit path:

- `Entry.media: String` → `Entry.atRule: String` — the full prelude: `""`, `"@media (…)"`, or
  `"@container [name ](…)"`.
- `insert(media:…)` → `insert(atRule:…)`; `text` becomes
  `e.atRule.isEmpty ? e.text : "\(e.atRule) { \(e.text) }"`; sort key `(atRule, hash)` (empty
  sorts first → base rules before conditionals, preserving cascade).
- `registerAnonymous` / `registerSelector` take `atRule: String` instead of `media: String?`.
- `PendingStyleRule.media: String?` → `atRule: String?`; `.media(q)` sets `"@media \(q.condition)"`,
  `.container(q, name)` sets `"@container \(name.map { $0 + " " } ?? "")\(q.condition)"`. `Rule.register`
  builds the prelude the same way.

Contained rename; no behavior change for existing media/pseudo rules (their emitted text is
byte-identical). Determinism (hash order) preserved.

## Testing plan

Native, `MockBackend` — the primary gate. New suites:

**`MediaQueryConditionTests`**
- `and`/`or`/`not` wrap compound operands in parens; nesting `and(or(a,b), c)` yields valid grouped
  CSS (regression on v1's unparenthesized bug).
- `orientation`, `minHeight`, `maxHeight` serialize correctly.
- `Breakpoint.minWidthPx` scale; `.up(bp)` == `minWidth(px)`, `.down(bp)` == `maxWidth(px-0.02)`.

**`ResponsiveValueTests`**
- `.padding(responsive(.px(16), md:.px(32), lg:.px(48)))` emits base decl + mobile-first `min-width`
  media rules in ascending order; thresholds match `Breakpoint` scale.
- A `responsive(base)` with no overrides emits only the base (no media rules).

**`ContainerQueryTests`**
- `.container(.minWidth(.px(400)), name:"sidebar"){ … }` → `@container sidebar (min-width: 400px) { .swui-… { … } }`.
- unnamed `.container(…)` → `@container (…)`.
- `.containerType(.inlineSize, name:"sidebar")` sets `container-type`/`container-name` declarations.
- `Rule(…, container:, containerName:)` emits through `registerSelector`.
- dedup across mixed `@media` + `@container` entries; deterministic order.

**`MediaMatchTests`** (via `MockBackend`)
- reading `media.matches(q)` in a component `body` registers exactly one `observeMediaQuery` per
  distinct condition (dedup across multiple components reading the same query).
- `simulateMediaChange` flips the value → the reading component re-renders and swaps its subtree;
  a component that never read that query does not depend on it.
- `matches()` returns `false` on a fresh (unseeded) `MockBackend` (SSR default).
- no state-mutation-during-eval crash/loop: first read of a new query returns the baseline without
  triggering a spurious immediate re-render (assert render count).

**SSR/serialization**
- `matches()` → base branch in serialized HTML; CSS `@media`/`@container` still present in the
  emitted stylesheet (surfaces 1–2 unaffected by surface 3).

**WASM build gate:** `swift build --swift-sdk swift-6.3.3-RELEASE_wasm` green (DOMBackend
`observeMediaQuery`, JSClosure retention compile-check).

## File-by-file change map

| File | Change |
|------|--------|
| `Sources/SwiftWUI/Styles/MediaQuery.swift` | +`Orientation`, `minHeight`/`maxHeight`/`orientation`, `and`/`or`/`not`. |
| `Sources/SwiftWUI/Styles/Breakpoint.swift` (new) | `Breakpoint` enum + `MediaQuery.up`/`.down`. |
| `Sources/SwiftWUI/Styles/Responsive.swift` (new) | `Responsive<V>`, `responsive(…)`, `_responsive` helper. |
| `Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift` | +`Responsive` overloads, `.container()`, `.containerType()` on `Tag` & `_StyledTag`. |
| `Sources/SwiftWUI/Styles/StyleProxy.swift` | +`container(_:name:_:)` collector (`containerBlocks`). |
| `Sources/SwiftWUI/Styles/Rule.swift` | +`container:`/`containerName:` params; build at-rule in `register`. |
| `Sources/SwiftWUI/Styles/StyleRegistry.swift` | `media`→`atRule` generalization (Section G). |
| `Sources/SwiftWUI/Styles/*` (`PendingStyleRule`, `Style`, resolver call site) | thread `atRule` through; container blocks in bundles. |
| `Sources/SwiftWUI/Environment/MediaMatch.swift` (new) | `MediaMatchStore`, `MediaProxy`. |
| `Sources/SwiftWUI/Environment/Environment.swift` | `_mediaStore` key + `media` computed value. |
| `Sources/SwiftWUI/Render/RendererBackend.swift` | +`observeMediaQuery` + default impl. |
| `Sources/SwiftWUI/Render/MockBackend.swift` | `observeMediaQuery` + `simulateMediaChange`. |
| `Sources/SwiftWUI/Runtime/Runtime.swift` | build `MediaMatchStore`, inject `_mediaStore`. |
| `Sources/SwiftWUIDOM/DOMBackend.swift` | `observeMediaQuery` via `matchMedia`, retained `JSClosure`s. |
| `Tests/SwiftWUITests/{MediaQueryCondition,ResponsiveValue,ContainerQuery,MediaMatch}Tests.swift` | new suites. |

## Risks & ceilings

- **Observation mutation-during-eval** (Section E.1) — mitigated by the `registered`
  (`@ObservationIgnored`) / `changes` (observed) split. This is the load-bearing correctness point;
  the `MediaMatchTests` render-count assertion guards it.
- **Whole-store invalidation granularity** — accepted; ceiling noted, upgrade path is per-key
  observation.
- **Unbounded matchMedia listeners** — bounded by distinct queries; no sweep, matching
  `StyleRegistry`'s documented policy.
- **`StyleRegistry` rename blast radius** — contained; existing emitted CSS is byte-identical, so
  existing style/pseudo/media tests act as the regression net.
