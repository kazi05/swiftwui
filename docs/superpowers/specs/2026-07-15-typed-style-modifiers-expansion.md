# Typed Style Modifiers — Full Expansion

**Status:** Design (awaiting approval). **Date:** 2026-07-15. **Branch target:** `main` (post v0.3.0).

Produced by an 8-module CSS research fan-out (one agent per CSS module, ~214 property
entries) + an adversarial completeness critic grounded against the current source. All
critic findings are resolved inline and logged in §11.

---

## 1. Context & goal

SwiftWUI already types ~55 CSS properties (`StyleDeclaration` factories → `StyleProxy`
methods → `Tag`/`_StyledTag`/`HTMLTag` modifiers), with `.style("prop","val")` as the
sanitized escape hatch (§12 of the phase-3 spec). Audit of a real consumer
(`Boosa/boosa-swiftwui`) found **92 `.style()` fallback sites**; roughly half are genuine
gaps — common CSS a web-app framework should type. This spec catalogs the **entire
plausibly-typeable CSS surface**, decides the Swift shape for each, and sequences the work
into priority waves.

**Goal:** every P0/P1 property becomes a typed modifier; the string escape survives only
for the deliberate long tail (P3). No behavioral change to existing modifiers.

### Non-goals

- Not typing every CSS property in existence. Obsolete/print-only/deeply-combinatorial
  grammars (`border-image`, `mask` shorthand, `grid` shorthand, `contain`, `quotes`) stay
  on `.style()`.
- **CSS `animation` + `@keyframes` are deferred (§9).** They overlap the shipped phase-9
  WAAPI animation engine. Only CSS keyframe *loops* (spinners/marquees) are a genuine gap;
  interim = `.style("animation", …)`, and a stylesheet-level `Keyframes { }` builder is
  built only on demand.
- Not changing the reconciler, `StyleRegistry`, or rule-scoping. Pure additive API surface
  over the existing `StyleDeclaration` pipeline.

---

## 2. Design principles (decision framework)

Applied to every property to pick `apiKind`:

1. **Length-valued** → `CSSLength` (extended, §3.1).
2. **Closed keyword set** → a `String`-backed Swift enum (`swiftCase` → exact css string).
3. **Numeric** → `Double` / `Int`.
4. **Keyword + value mix** (e.g. `vertical-align`, `aspect-ratio`) → small enum with an
   associated-value case (mirrors how `CSSLength` mixes cases).
5. **Multi-value / functional** (gradients, shadows, filters, transforms) → a dedicated
   value type, composed variadically, that renders to one declaration string.
6. **Open-ended / rare** → keep as `.style()` escape; document it, don't fake a type.

**Every declaration value derived from user strings (gradient raw sub-fields, grid track
lists, `content`) MUST pass `CSSSanitize.isSafeValue`** at the factory, exactly as the
existing string escape does. Idents (`container-name`, `grid-area` names) pass
`isValidIdent`.

**Rendering rule:** integer-valued `Double`s render via the existing `cssNumber(_:)` helper
(no trailing `.0`). Applies to `aspect-ratio`, `scale`, angles, etc.

---

## 3. Foundational value types (build FIRST — everything reuses these)

These are prerequisites; several modules block on them. One PR wave (§10, Wave 0).

### 3.1 Extend `CSSLength` (fixes many "already typed" gaps retroactively)

The critic found `width: max-content`, `width: fit-content`, and `100dvh` are currently
**inexpressible** — every sizing property silently lacks them. Fix at the value-type level:

```swift
public enum CSSLength: Equatable, CSSValueConvertible {
    case px(Double), rem(Double), em(Double), ch(Double)
    case percent(Double)
    case vw(Double), vh(Double), vmin(Double), vmax(Double)
    case dvh(Double), svh(Double), lvh(Double)        // dynamic/small/large viewport height
    case dvw(Double), svw(Double), lvw(Double)         // …width — mobile URL-bar safe
    case minContent, maxContent                        // intrinsic sizing
    indirect case fitContent(CSSLength)                // fit-content(<len>)
    case auto, zero
    case variable(String)
    // css: min-content|max-content|fit-content(20px)|100dvh|… (existing cases unchanged)
}
```

> **Do NOT add a `.normal` case to `CSSLength`.** `row-gap`/`column-gap`/`word-spacing`
> default to the `normal` keyword, but `normal` is not legal for most length properties.
> Getting `normal` = omit the modifier (the default). See §11-G.

### 3.2 New shared value types

| Type | Shape (abbreviated) | Reused by |
|---|---|---|
| `CSSAngle` | `enum { case deg(Double), turn(Double), rad(Double), grad(Double) }` | gradients, `rotate`, `hue-rotate`, conic |
| `CSSDuration` | `enum { case s(Double), ms(Double) }` | transition/animation longhands |
| `TimingFunction` | `enum { ease, easeIn, easeOut, easeInOut, linear, stepStart, stepEnd; cubicBezier(4×Double); steps(Int, StepPosition) }` | transition/animation |
| `Shadow` | `struct { offsetX, offsetY, blur=.zero, spread=.zero, color=.black, inset=false }` | **box-shadow AND text-shadow** (text ignores spread/inset) |
| `BlendMode` | 16-case enum (`normal…luminosity`) | **mix-blend-mode AND background-blend-mode** |
| `GridLine` | `enum { auto; line(Int); name(String); span(Int) }` | grid-row/column start/end + shorthands |
| `BorderRadius` | `struct { topLeft, topRight, bottomRight, bottomLeft: CSSLength; init(all:); init(topLeft:…) }` — **no literal conformances** (§11-N) | per-corner radius |
| `FilterFunction` | `enum { blur(CSSLength); brightness/contrast/grayscale/invert/opacity/saturate/sepia(Double); hueRotate(CSSAngle); dropShadow(x,y,blur,color); url(String) }` | **filter AND backdrop-filter** |
| `TransformFunction` | `enum { translate(x,y:CSSLength); translateX/Y/Z(CSSLength); scale(x,y:Double); scaleX/Y/Z(Double); rotate(CSSAngle); rotateX/Y/Z(CSSAngle); skew(x,y:Double); skewX/Y(Double); matrix(6×Double); perspective(CSSLength) }` | `transform` |
| `CSSBackgroundImage` | `indirect enum { none; url(String); linearGradient(angle:CSSAngle?, stops:[CSSGradientStop]); radialGradient(shape/size/at:String?, stops:); conicGradient(angle:CSSAngle?, at:String?, stops:); layered([CSSBackgroundImage]) }` | background-image |
| `CSSGradientStop` | `enum { color(CSSColor); colorAt(CSSColor, CSSLength) }` | gradients |
| `BackgroundPosition` | 9 keyword cases + `custom(x,y:CSSLength)` | background-position |
| `BackgroundSize` | `enum { auto, cover, contain; custom(width:CSSLength, height:CSSLength?) }` | background-size |
| `ObjectPosition` | `struct { x, y: CSSLength }` + `.center/.top/…` statics | object-position |
| `AspectRatio` | `enum { auto; ratio(Double, Double) }` — renders via `cssNumber` (§11-K) | aspect-ratio |

### 3.3 New enums that must NOT reuse an existing one (§11-D)

`justify-items`, `justify-self`, `align-content` have cases (`left`/`right`/`legacy`,
`baseline`, distributions) that `AlignItems`/`JustifyContent` don't. Introduce dedicated
`JustifyItems`, `JustifySelf`, `AlignContent`. `place-*` shorthands compose the correct
pair (never `AlignItems` on the justify axis).

---

## 4. Rollout waves (summary)

| Wave | Contents | Rationale |
|---|---|---|
| **0 — Foundations** | §3 value types + `CSSLength` extension | Unblocks everything; no user-facing modifier yet except sizing keywords |
| **P0** | Boosa-blocking + universal: see §5.P0 | Kills the bulk of the 92 `.style()` sites |
| **P1** | Common web-app props: see §5.P1 | Broad coverage |
| **P2** | Niche-but-useful | On demand |
| **P3 / escape** | Documented long tail on `.style()` | Explicit non-goal |

**~200 candidate properties. Net-new typed modifiers ≈ 150 (P0–P2). P3 stays on escape.**

---

## 5. Property catalog (decided API)

Format: `css-property → swiftModifier(signature) → value` · notes. Enums list cases as
`swiftCase=css-string`. **Fixes flagged `[§11-x]` are mandatory.**

### 5.P0 — Priority 0 (build after Wave 0)

**Sizing / layout**
| CSS | Swift | Value | Notes |
|---|---|---|---|
| `overflow` (fix) | `overflow(_:)` | `Overflow` **+ `.clip` case** | [§11-added] |
| `overflow-x` / `-y` | `overflowX(_:)` / `overflowY(_:)` | `Overflow` (extended) | reuse enum |
| `object-fit` | `objectFit(_:)` | enum `fill, contain, cover, none, scaleDown=scale-down` | image staple |
| `object-position` | `objectPosition(_:)` | `ObjectPosition` | pairs with object-fit |
| `aspect-ratio` | `aspectRatio(_:)` + `aspectRatio(_ w:_ h:)` | `AspectRatio` | `16/9` etc. [§11-K] |
| `display` (fix) | `display(_:)` | `Display` **+ table/list-item/flow-root/inline-grid** | [§11-added] |
| `visibility` | `visibility(_:)` | enum `visible, hidden, collapse` | |
| `z-index` | already typed | `Int` | — |

**Typography**
| CSS | Swift | Value | Notes |
|---|---|---|---|
| `white-space` | `whiteSpace(_:)` | enum `normal, nowrap, pre, preWrap=pre-wrap, preLine=pre-line, breakSpaces=break-spaces` | 4× in Boosa |
| `text-transform` | `textTransform(_:)` | enum `none, capitalize, uppercase, lowercase, fullWidth=full-width, fullSizeKana=full-size-kana` | |
| `text-overflow` | `textOverflow(_:)` | enum `clip, ellipsis` | truncation combo |
| `line-clamp` | `lineClamp(_ lines: Int)` | Int, **bundled** | emits `display:-webkit-box; -webkit-box-orient:vertical; overflow:hidden; -webkit-line-clamp:N; line-clamp:N` [§11-J] |

**Background / border**
| CSS | Swift | Value | Notes |
|---|---|---|---|
| `background-color` | `backgroundColor(_:)` | `CSSColor` | distinct from `background` shorthand [§11-F] |
| `background-image` | `backgroundImage(_:)` | `CSSBackgroundImage` | **gradients + url()** |
| `background-repeat` | `backgroundRepeat(_:)` | enum incl `` `repeat` `` **backticked** [§11-M] | |
| `border-{top,right,bottom,left}` | `border(_ side: Side, width:style:color:)` | Side+`BorderStyle`+`CSSColor` | per-side; can express one side |
| `border-radius` per-corner | `borderRadius(_: BorderRadius)` | `BorderRadius` | overload of existing `(CSSLength)` [§11-N] |

**Effects / transform**
| CSS | Swift | Value | Notes |
|---|---|---|---|
| `filter` | `filter(_ fns: FilterFunction...)` | `FilterFunction` | glass/dim/hover — highest-value single build |
| `transform` | `transform(_ fns: TransformFunction...)` | `TransformFunction` | percent-capable (fixes PX-only `offset`) [§11-transform] |
| individual `translate`/`rotate`/`scale` | keep `offset`/`rotationEffect`/`scaleEffect`, **re-route onto the individual CSS properties** | — | compose without clobbering [§11-transform] |

**Interactivity**
| CSS | Swift | Value | Notes |
|---|---|---|---|
| `pointer-events` | `pointerEvents(_:)` | enum (SVG camelCase values **verbatim** [§11-P]) | |
| `user-select` | `userSelect(_:)` | enum `auto, text, none, all, contain` | |
| `cursor` (fix) | `cursor(_:)` | `Cursor` **+ ~28 cases** (crosshair/grabbing/zoom/*-resize/…) | extend, keep existing 7 |

### 5.P1 — Priority 1

**Sizing / layout**
`inline-size`/`block-size` (CSSLength) · `inset(_ CSSLength)` shorthand · `overflow-wrap`
(enum, typography home [§11-B]) · `row-gap`/`column-gap` (CSSLength) + `gap(row:column:)`
[§11-B] · `order` (Int) · `justify-items` (`JustifyItems`) · `justify-self` (`JustifySelf`)
· `align-content` (`AlignContent`) · `place-content`/`place-items` (compose correct pair)
[§11-D] · `grid-auto-flow` (enum) · `grid-{column,row}[-start/-end]` (`GridLine`) ·
`grid-template-areas` (String) · `grid-area(_ name: String)` (String) ·
`margin-inline`/`margin-block`/`padding-inline`/`padding-block` (CSSLength).

**Typography**
`font-style` (enum) · `text-decoration-line/-color/-style/-thickness` (enum/`CSSColor`/enum/
CSSLength) · `text-indent` (CSSLength) · `text-shadow(_ Shadow...)` (**reuse `Shadow`**
[§11-shadow]) · `word-break` (enum) · `vertical-align` (`VerticalAlign` = keyword+length
enum) · `line-clamp` (also serves excerpts) · `line-height(_ CSSLength)` overload +
`.normal` [§11-lineheight] · `list-style-type` (`ListStyleType` enum incl `custom(String)`
[§11-L]) · `text-wrap` (enum `wrap, nowrap, balance, pretty, stable` — critic add) ·
`font-variant-numeric` (enum incl `tabularNums` — critic add).

**Background / border**
`background-clip` (enum incl `.text`, **bundled -webkit- prefix** [§11-clip]) ·
`border-width`/`border-style`/`border-color` per-side (mirror margin/padding Side overload)
· `outline-offset`/`outline-width`/`outline-style` (CSSLength/CSSLength/enum) · `box-shadow(_
Shadow...)` (structured overload over existing String) · `mix-blend-mode` (`BlendMode`).

**Effects / motion**
`backdrop-filter(_ FilterFunction...)` (reuse `FilterFunction`) · `clip-path` (`ClipPath`
enum) · `transition(property:duration:timingFunction:delay:)` (**named** overload; keep
`cssTransition(String)` escape [§11-transition-name]) · `transition-duration/-timing-
function` (`CSSDuration`/`TimingFunction`).

**Interactivity / misc**
`touch-action` (enum) · `scroll-behavior` (enum) · `scroll-snap-type` (`ScrollSnapType`) ·
`scroll-snap-align` (enum) · `scroll-padding` (CSSLength+Side) · `overscroll-behavior`
(enum + x/y overloads) · `resize` (enum) · `appearance` (enum, **bundled -webkit-** ) ·
`accent-color` (`CSSColor`+`.auto`) · `list-style-position` (enum) · `border-collapse`
(enum) · `table-layout` (enum) · `color-scheme` → **`colorSchemeHint(_:)`** (renamed to
avoid env clash [§11-colorscheme]) · `break-inside`/`break-before`/`break-after` (enum —
critic add).

### 5.P2 — Priority 2 (on demand)

Logical `*-start`/`*-end` insets & margins/paddings · `min/max-inline-size`,
`min/max-block-size` · `float`/`clear`/`isolation` (enum) · `font-variant`/`font-stretch`/
`font-optical-sizing`/`font-smoothing` (enum, **subpixel only on -webkit-** [§11-smooth]) ·
`text-align-last`/`text-underline-offset`/`text-decoration-thickness` · `word-spacing`
(CSSLength, **no `.auto`** [§11-G]) · `hyphens`/`direction` (enum) · `caret-color`
(`CSSColor`+auto) · `-webkit-text-stroke` (`TextStroke`) · `background-attachment`/
`-origin`/`-blend-mode` (enum) · `background-position`/`-size` (typed) · outline-color ·
`transform-style`/`perspective`/`backface-visibility` · `will-change` (`WillChange`) ·
`content-visibility` (+ `contain-intrinsic-size` — critic pairs them) · `scroll-snap-stop`/
`scroll-margin` · `place-self` · `flex(_ FlexShorthand)` + `flex(_ Double)` convenience ·
`flex-flow` · `border-spacing` · `counter-reset`/`-increment`/`-set` (`CounterAction`) ·
`content` (escape-adjacent) · `column-count`/`column-width`/`column-gap` (multicol) ·
`scrollbar-width`/`scrollbar-color` (critic add) · `-webkit-tap-highlight-color` (critic
add) · `fill`/`stroke`/`stroke-width` (SVG icons — **only if inline-SVG is a target**,
critic conditional).

### 5.P3 / leave-as-`.style()` escape (documented non-goals)

`font`/`grid`/`grid-template` shorthands · `border-image` · `mask` shorthand · `contain` ·
`quotes` · `writing-mode` · `tab-size` (length variant) · elliptical (8-value) border-radius
· 3D `perspective-origin` · `columns`/`column-rule*`/`column-span`/`column-fill` ·
`caption-side`/`empty-cells` · `image-rendering` · `all` · `list-style-image`.

---

## 6. Full research artifact

The exhaustive per-property catalog (214 entries: value grammar, `alreadyTyped`, full enum
case lists, `newType` sketches, per-property priority) is the workflow output at:

`~/.claude/projects/…/tasks/w638i3jsh.output` (run `wf_b1e6b373-8e3`).

This spec is the **decided** subset; the artifact is the reference for exact enum cases when
implementing each wave.

---

## 7. Implementation pattern (per property)

Each simple property touches the same 4 sites already used by every existing modifier — copy
the pattern, no new machinery:

1. `StyleDeclaration.swift` — `static func <name>(_:) -> Self { .init(property:"css-name", value:v.css) }`
2. `StyleProxy.swift` — `public mutating func <name>(_ v: T) { _add(.<name>(v)) }`
3. `StyleModifiers+Tag.swift` — `func <name>` on both `Tag` (→ `_StyledTag`) and `_StyledTag` (collapse)
4. `StyleModifiers+HTMLTag.swift` — `func <name>` on `HTMLTag` (→ `_style`)

New enums/value types → add to `CSSValues.swift` (or a new `CSSValues+<Module>.swift` to keep
the file manageable). **Bundled** properties (`line-clamp`, `background-clip:.text`,
`appearance`, `font-smoothing`) emit multiple `StyleDeclaration`s from one modifier — the
`containerType`/responsive helpers already show the multi-declaration pattern.

**Tests:** one `StyleModifierTests` case per property asserting the emitted `property:value`
string (native, via the serializer — no browser). Enums: one round-trip assert per case is
overkill; assert a representative subset + the tricky css-string cases (hyphenated, backticked
`repeat`, prefixed).

---

## 8. Security

- Gradient raw sub-fields (`radial` shape/size/at), `grid-template-*`/`grid-area` track
  strings, `content`, `transition-property` names, `animation-name` → **must** pass
  `CSSSanitize.isSafeValue` (or `isValidIdent` for names) at the factory. Same choke point as
  the existing string escape; assert-in-debug, no-op-in-release.
- Enum/`CSSLength`/`CSSColor`-derived values are constructed from a closed vocabulary → no
  sanitization needed (they can't produce `{`/`}`/control chars).
- The `@container`/`background-image url()` idents keep the existing validate-and-drop guard
  (must hold in release; injection guard, not just debug assert).

---

## 9. Deferred: CSS animation / @keyframes

The `animation` shorthand + `animation-*` longhands + `@keyframes` overlap the shipped phase-9
WAAPI engine (`withAnimation`/`.animation`/`.transition`). Building the full CSS animation set
speculatively duplicates it. Decision:

- **Interim:** `.style("animation", …)` for the one real gap (pure-CSS loops: spinners,
  marquees the WAAPI engine doesn't cover).
- **On demand only:** a stylesheet-level `Keyframes("spin") { 0% {…}; 100% {…} }` builder,
  parallel to the existing `media`/`container` at-rule collectors (it's an at-rule, not a
  modifier). Its own mini-spec when an app needs it.

---

## 10. Sequencing

- **Wave 0 (foundations):** §3 — `CSSLength` extension + all shared value types + the 3 new
  align/justify enums. Ships with tests, no consumer-visible modifiers except sizing keywords.
- **Wave P0:** §5.P0 — one PR, ~20 modifiers. Re-audit Boosa: measure `.style()` reduction.
- **Wave P1:** §5.P1 — broad coverage.
- **Wave P2:** §5.P2 — as demand surfaces (don't build speculatively).
- P3 stays on escape; add a doc page listing what's intentionally string-only + why.

Each wave: implement per §7 → native test pass → wasm build gate → update Boosa audit count.

---

## 11. Critic findings — resolved (mandatory fixes)

Grounded against source by the critic; each MUST be honored by the implementer.

- **§11-M `repeat` is a Swift keyword.** `BackgroundRepeat.repeat` → `` `repeat` ``
  backticked, else the enum won't compile. (Research backticked `super` but missed this.)
- **§11-transition-name naming clash.** Public escape is `cssTransition(String)`;
  `StyleProxy.transition(_:String)` also exists. Add the typed API as a **labeled** overload
  `transition(property:duration:timingFunction:delay:)` — labels disambiguate from the
  unlabeled String. Keep `cssTransition` as the raw escape. Document the split.
- **§11-colorscheme name clash.** CSS `color-scheme` collides with the existing `colorScheme`
  environment key → name the CSS modifier **`colorSchemeHint(_:)`**.
- **§11-D wrong enum reuse.** `place-items`/`place-content`/`place-self` and
  `justify-items`/`justify-self`/`align-content` must use **dedicated** `JustifyItems`/
  `JustifySelf`/`AlignContent` enums (extra `left`/`right`/`legacy`/`baseline`/distribution
  cases), never `AlignItems` on the justify axis.
- **§11-G `.auto` is invalid for `word-spacing`/`row-gap`/`column-gap`.** Grammar is
  `normal | <length>`; `auto` is illegal. `normal` is the default → omit the modifier. Do not
  translate a `.auto`. (Guard: don't add `.normal` to `CSSLength` either — §3.1.)
- **§11-clip `background-clip:.text` needs prefixes.** Emit `-webkit-background-clip:text` +
  `background-clip:text` (+ note that gradient-text also needs
  `-webkit-text-fill-color:transparent`). Otherwise no-ops in Safari.
- **§11-J `line-clamp` is bundled** (5 declarations, §5.P0). A bare `-webkit-line-clamp` does
  nothing alone.
- **§11-smooth `font-smoothing`.** `subpixel-antialiased`/`antialiased` are valid only on
  `-webkit-font-smoothing`; emit those to the prefixed prop only, `auto`/`none` to both.
- **§11-P `pointer-events` camelCase css values are correct** (`visiblePainted`, `fill`, …
  SVG heritage). Add a code comment so nobody "fixes" them.
- **§11-K `aspect-ratio` float rendering.** `ratio(16,9)` must emit `16 / 9`, not
  `16.0 / 9.0` → route through `cssNumber`.
- **§11-L `list-style-type`** models `custom(String)` → real enum with an associated-value
  case, not a `String`-raw enum.
- **§11-N `BorderRadius`** must NOT adopt `ExpressibleBy{Float,Integer}Literal` — else
  `borderRadius(8)` is ambiguous against the existing `borderRadius(_: CSSLength)` overload.
- **§11-transform.** `TransformFunction` (translate via `CSSLength` → percent works) fixes the
  PX-only `offset`. Re-route the existing `offset`/`scaleEffect`/`rotationEffect` sugar onto
  the **individual `translate`/`rotate`/`scale` CSS properties** (compose across modifiers
  without clobbering); the `transform` enum is for explicit multi-function ordering.
- **§11-shadow.** One `Shadow` struct powers both `box-shadow` and `text-shadow` (text ignores
  spread/inset). No separate `TextShadow`.
- **§11-B dedup.** `overflow-wrap` → typography home; `resize`/`overscroll-behavior` →
  interactivity home (with x/y overloads); `aspect-ratio` → sizing home; one unified gap story
  (`gap`, `gap(row:column:)`, `rowGap`, `columnGap` — `column-gap` serves flex/grid AND
  multicol, one modifier).
- **§11-added value-type gaps.** `CSSLength` gains `min-content`/`max-content`/`fit-content`
  + `dvh/svh/lvh/dvw/svw/lvw/vmin/vmax/ch` (§3.1). `Overflow` gains `.clip`. `Display` gains
  table/list-item/flow-root/inline-grid. `Cursor` gains ~28 cases.
- **Critic-added missing properties folded into §5:** `color-scheme`, `text-wrap`,
  individual `translate/rotate/scale`, `font-variant-numeric`, `scrollbar-width/-color`,
  `-webkit-tap-highlight-color`, `break-inside/-before/-after`, `fill/stroke` (SVG, conditional),
  `image-rendering` (P3), `contain-intrinsic-size` (pair with content-visibility),
  `counter-set`.

---

## 12. Decisions (approved 2026-07-15)

1. **Scope ceiling — APPROVED: P0 + P1 + P2 (full).** ~150 net-new typed modifiers; only
   §5.P3 stays on the `.style()` escape. SVG `fill`/`stroke` (§5.P2) **included** (inline-SVG
   is a target).
2. **`transition` naming — APPROVED: labeled overload.** Typed
   `transition(property:duration:timingFunction:delay:)`; `cssTransition(String)` stays as the
   raw escape (no source break). Per §11-transition-name.
3. **File organization — split.** New value types go in `CSSValues+<Module>.swift`
   (`+Layout` / `+Typography` / `+Effects` / `+Interactivity`); `CSSLength`/`Overflow`/
   `Display`/`Cursor` extensions stay in `CSSValues.swift`.
4. **Version.** Additive → minor bump (target v0.4.0) once P0+P1 land; P2 may extend into
   later minors.
5. **Sequencing.** Start with **Wave 0 (foundations, §3)** now.
