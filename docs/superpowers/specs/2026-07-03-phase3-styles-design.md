# Phase 3: Styles — Design

Date: 2026-07-03. Status: approved in brainstorming, pending user spec review.
Branch: `feature/fable-new-vision` (continues; phase 2 remains unmerged by decision).

## 1. Scope

**In:**
- Typed CSS value layer (`CSSLength`, `CSSColor`, property enums, string fallback).
- Style modifiers on HTML tags (inline path) and on any `Tag` (wrapper path).
- Generated stylesheet: pseudo-classes (`hover`/`focus`/`active`), media queries,
  content-hashed rule dedup, one backend-managed `<style>`.
- `Styled` protocol + `Rule`: component-scoped selector rules (class/id/element);
  `App.globalStyles` for global rules.
- Themes: `StyleToken` + CSS custom properties, `data-theme` switching.
- `Style` protocol: reusable named style bundles.
- Task 0: full phase-2 carry list (§13).

**Out (deferred):** animations/transitions API and keyframes (raw `transition`
property is in the curated set; a typed animation system is not planned, per
phase 2 §12), combinator/descendant selectors in `Rule`, container queries,
stylesheet rule sweeping (registry is monotonic), LIS/rAF (unchanged), SSG
emission of the stylesheet (phase 5 — but the registry exposes its text now).

## 2. Context — what this builds on

- `_AttributeBag` (phase 1): bag-mutating methods on `HTMLTag` return `Self`,
  never affect identity. Styles extend this bag.
- Effect modifiers (phase 2): wrapper primitives on any `Tag`, identity via
  `.type(ObjectIdentifier)` segment (D3). `_StyledTag` follows this pattern.
- `ResolveContext`: explicit context threaded through resolution — gains the
  `StyleRegistry`.
- `RendererBackend`: deliberately dumb host primitives — gains exactly one
  method, `setStylesheet(_ text: String)`.
- Scoped ≡ full invariant (phase 2 §2.4): extends to styles — style attributes
  are already covered by tree comparison; registry text equality is added to
  the property test.

## 3. Value layer

All types are small value types in `Sources/SwiftWUI/Styles/`. No new module —
the v2 two-module rule holds. Rendering to text goes through one protocol:

```swift
public protocol CSSValueConvertible { var css: String { get } }
```

- `CSSLength`: `.px(_:)`, `.rem(_:)`, `.em(_:)`, `.percent(_:)`, `.vw(_:)`,
  `.vh(_:)`, `.auto`, `.zero`. Numeric payloads are `Double`; integers render
  without trailing `.0`.
- `CSSColor`: `.hex("#1a1a2e")` (validated: `#RGB`/`#RRGGBB`/`#RRGGBBAA`),
  `.rgb(_:_:_:)`, `.rgba(_:_:_:_:)`, named cases (`.white`, `.black`,
  `.transparent`, `.current`, small curated set), `.token(ColorToken)` →
  `var(--name)`.
- Property-specific enums where the domain is closed: `Display` (`.block`,
  `.inline`, `.inlineBlock`, `.flex`, `.grid`, `.none`, …), `Position`,
  `FlexDirection`, `JustifyContent`, `AlignItems`, `TextAlign`, `FontWeight`
  (keywords + `.custom(Int)`), `Cursor`, `Overflow`, `BorderStyle`.
- `StyleDeclaration = (property: String, value: String)` — the normalized unit
  everything reduces to at collection time.

## 4. Modifier surface

Curated, ~40 properties. CSS names, not SwiftUI names (decision Q3). Each
modifier exists in three places with one shared implementation:

1. `extension HTMLTag` — mutates the bag, returns `Self` (inline path, §5).
2. `extension Tag` — returns `_StyledTag<Self>` (wrapper path, §6).
3. `StyleProxy` — collects declarations for rules/`Style` bundles (§7–§10).

Swift overload resolution picks the `HTMLTag` variant for concrete HTML tags
automatically (more specific protocol wins), so HTML tags stay on the fast
path with no wrapper nodes.

| Group | Properties |
|---|---|
| Layout | `display`, `position`, `top`, `right`, `bottom`, `left`, `width`, `height`, `minWidth`, `minHeight`, `maxWidth`, `maxHeight`, `margin` (all sides / per side), `padding` (same), `gap`, `overflow`, `zIndex`, `boxSizing` |
| Flex/Grid | `flexDirection`, `justifyContent`, `alignItems`, `alignSelf`, `flexWrap`, `flexGrow`, `flexShrink`, `flexBasis`, `gridTemplateColumns` (string), `gridTemplateRows` (string) |
| Typography | `fontSize`, `fontWeight`, `fontFamily` (string), `lineHeight`, `textAlign`, `textDecoration`, `letterSpacing`, `color` |
| Box | `background` (color), `border` (width/style/color), `borderColor`, `borderRadius`, `boxShadow` (string), `opacity`, `outline` |
| Misc | `cursor`, `transition` (string), `listStyle` (string) |

Margin/padding ergonomics: `.margin(.px(8))` (all sides), `.margin(.top, .px(8))`
(one side), `.padding(vertical:horizontal:)`.

Escape hatch (recorded user preference): `.style("backdrop-filter", "blur(4px)")`
on all three surfaces. Property name validated (reuse `_AttributeBag.isValidName`
shape adapted to CSS idents); see §12 for value handling.

## 5. Inline path (HTML tags)

`_AttributeBag` gains `styles: [StyleDeclaration]`. Modifiers append. At
resolve, declarations flatten into `attributes["style"]` in call order; on a
duplicate property the last call wins (matching `set(_:_:)` semantics for
attributes). A raw `.attribute("style", …)` combined with modifiers: the
attribute value comes first, modifier declarations append after it.

The reconciler and `TreeApplier` see an ordinary string attribute. **Zero new
patch primitives; zero changes to Reconciler/TreeApplier for this path.**
Escaping: existing attribute escaper at the serializer choke point, unchanged.

## 6. Wrapper path (`_StyledTag`)

```swift
struct _StyledTag<Content: Tag>: Tag, _PrimitiveTag {
    var content: Content
    var declarations: [StyleDeclaration]
    // .hover/.focus/.media called on a component: on application their
    // swui-<hash> classes append to the same element roots as declarations (§7)
    var rules: [StyleRule]
}
```

- Identity: one `.type` segment per wrapper, exactly like effect wrappers.
  Consequence (documented): adding/removing a style modifier on a component
  changes subtree identity → state resets. Same rule as `onAppear` today.
- Consecutive style modifiers on an already-wrapped value collapse into the
  existing wrapper (append to `declarations`) instead of nesting a second
  wrapper — `MyCard().padding(…).margin(…)` costs one segment, not two.
- Application semantics: resolve `content`, then walk its top-level nodes;
  for each `.element` root, append `declarations` **after** the element's own
  style declarations (outer wins — caller adjusts the component); descend
  through `.component` roots into their children; skip `.text` roots silently
  (documented; debug `assertionFailure` to surface the no-op).
- Nested wrappers (via components): inner applies first, outer appends later →
  outer wins. Consistent with the caller-adjusts intuition.
- Multi-root content: declarations apply to every element root (SwiftUI-group
  semantics).

## 7. Generated stylesheet

Needed by pseudo-classes, media queries, `Styled` rules, and themes.

**API (proxy closure — same naming surface as modifiers):**

```swift
Button("+") { count += 1 }
    .padding(.px(8))                                   // inline
    .hover { $0.background(.hex("#eee")) }             // rule
    .focus { $0.outline(.none) }
    .active { $0.opacity(0.8) }
    .media(.maxWidth(.px(600))) { $0.display(.none) }  // rule under @media
```

`StyleProxy` is a small struct collecting `[StyleDeclaration]` plus nested
pseudo blocks; modifiers on it mirror §4 names via the shared implementation.
`MediaQuery` is typed: `.maxWidth/.minWidth(CSSLength)`, `.prefersColorScheme(.dark)`,
`.custom(String)` fallback.

**Mechanics:**

- A rule = (selector part, declarations, optional media condition). Its
  canonical text is content-hashed (stable FNV-1a over normalized text) →
  class name `swui-<hash>`. The class is appended to the element's classes;
  the rule is registered in `StyleRegistry`.
- `StyleRegistry` lives on `ResolveContext` (owned by the runtime, like
  StateStore). Keyed by hash — identical rules from any number of elements
  register once. Monotonic: rules are never removed (bounded by the number of
  distinct rules in the app; sweeping is deferred until profiling demands).
- Flush integration: after commit, if the registry grew during this pass, the
  runtime calls `backend.setStylesheet(registry.text)` — full text of one
  managed `<style>`. DOMBackend lazily creates `<style id="swiftwui-styles">`
  in `<head>` and replaces its `textContent` (incremental `insertRule` is a
  later optimization). MockBackend records the text for tests. HTMLRenderer
  exposes `registry.text` so phase 5 SSG can emit it.
- Rule emission order in the stylesheet text is **canonical, not registration
  order**: sorted by (media condition, hash). Registration order differs
  between a scoped pass and a full pass when dynamic rules appear (dirty-cover
  order vs document order), so canonical ordering is what makes registry text
  byte-identical — the property test pins this after each flush. Consequence
  (documented): rule source order is not a specificity tiebreaker; generated
  rules each target a unique `swui-<hash>` class, and inline styles override
  rules anyway, so ties arise only between two `Styled` rules matching the
  same element — resolved by CSS specificity, not order.

## 8. `Styled` protocol / `Rule` — component-scoped selector rules

Motivating case: style several elements inside one component via a shared
class instead of repeating modifiers.

```swift
struct SearchForm: Tag, Styled {
    @RulesBuilder var styles: [Rule] {
        Rule(class: "field") { s in
            s.padding(.px(8))
            s.border(.px(1), .solid, .hex("#ccc"))
            s.hover { $0.borderColor(.token(.accent)) }
        }
        Rule(id: "submit") { $0.fontWeight(.bold) }
        Rule(element: "input") { $0.outline(.none) }
    }
    var body: some Tag {
        Form {
            Input(type: .text).classes("field")
            Button("Go").classes("field").id("submit")
        }
    }
}
```

- `Styled` is a standalone protocol (`protocol Styled { @RulesBuilder var
  styles: [Rule] { get } }`), adopted alongside `Tag` only by components that
  need it. The resolver checks `as? Styled` once per component resolve —
  **before** body evaluation.
- Because rule presence is known up front, the scope marker is applied to
  elements **at emission** during that component's body resolution — no
  post-pass subtree walk exists. Only `Styled` components pay the marker.
- `styles` evaluates in the same observation-tracking window as `body`
  (immediately before it), so rules may read `self`'s stored properties,
  `@State`, and `@Observable` models; `@RulesBuilder` supports `if`/`switch`;
  re-registration across re-renders is absorbed by registry dedup.
- `Rule` selector forms in phase 3: `class:`, `id:`, `element:` — one simple
  selector per rule. Pseudo-classes via the proxy (`s.hover { … }`), media via
  `Rule(class:"x", media: .maxWidth(.px(600)))`. Combinators deferred.
- **Scoping: Vue-style, always on for `Styled`.** Every element resolved in
  the component's body gets a marker class `swui-s<TypeHash>` (hash of the
  component type name — stable across instances and passes). Selectors compile
  with the marker attached: `.field.swui-s3f2 { … }`, `#submit.swui-s3f2 { … }`,
  `input.swui-s3f2 { … }`. Rules do not leak into child components (their
  bodies resolve in their own pass, unmarked) or outward. Builder-closure
  children passed in by a parent resolve in the parent's pass → they carry the
  parent's marker (or none). Matches where the code is written.
- **Global rules live on the `App`:** `@RulesBuilder static var globalStyles:
  [Rule]` (default empty via extension), registered once at mount, unscoped,
  emitted as written. The home for resets (`Rule(element: "body") { … }`).
  Same hash dedup. There is no per-component opt-out of scoping.
- Same rule registered by N instances of the component: one registry entry
  (hash includes the scope marker, which is per-type, not per-instance).

## 9. Themes

CSS custom properties; no macros, no Mirror.

```swift
extension ColorToken {
    static let accent  = ColorToken("accent")
    static let surface = ColorToken("surface")
}

let light = ThemeDefinition(default: true) { t in
    t.set(.accent,  .hex("#e94560"))
    t.set(.surface, .hex("#ffffff"))
}
let dark = ThemeDefinition(name: "dark") { t in
    t.set(.surface, .hex("#16213e"))
}
```

- `StyleToken<Value: CSSValueConvertible>` — a validated CSS ident name.
  `typealias ColorToken = StyleToken<CSSColor>`; `LengthToken` likewise.
  Reference from any surface: `.color(.token(.accent))` → `color: var(--accent)`.
- `ThemeDefinition`: the default theme emits `:root { --accent: …; }`, named
  themes emit `[data-theme="name"] { … }` — through the same `StyleRegistry`
  (registered at mount from `App`-level declaration: `static var themes:
  [ThemeDefinition]` with a default-empty extension).
- Switching: `setTheme("dark")` / `setTheme(nil)` on the runtime — sets/removes
  `data-theme` on the mount container. One attribute write, zero re-render.
  Exposed to components via an environment action (`\.setTheme`), following
  the phase-2 environment seam.
- `prefers-color-scheme` auto-darkness: expressible today by registering the
  dark assignments under `.media(.prefersColorScheme(.dark))` instead of a
  named theme; a convenience flag on `ThemeDefinition` is deferred.

## 10. `Style` protocol — reusable bundles

```swift
struct CardStyle: Style {
    func build(_ s: inout StyleProxy) {
        s.padding(.px(24))
        s.borderRadius(.px(12))
        s.hover { $0.boxShadow("0 4px 16px rgba(0,0,0,.12)") }
    }
}

Div { … }.style(CardStyle())        // HTML tag: inline decls + rules via bag
MyCard().style(CardStyle())         // component: via _StyledTag
```

One protocol requirement, `build(_:)`, on the same proxy used everywhere.
Declarations land on the inline path; nested pseudo/media blocks land in the
registry. `.style(_ style: some Style)` exists on both surfaces (§4 rules).

## 11. Identity & reconciliation impact

- Inline path and `swui-*` classes: ordinary attributes — reconciler unchanged.
- `_StyledTag`: one `.type` segment; add/remove of a component style modifier
  is an identity change (state reset), same as effect wrappers. Documented.
- Scope markers are deterministic per component type → byte-identical between
  scoped and full passes.
- `setStylesheet` is called at most once per flush, only on registry growth.
- Scoped ≡ full: property test gains styled fixtures (inline, hover, `Styled`
  component, wrapper on component) and asserts registry text equality
  alongside the existing tree comparison.

## 12. Error handling / security

- `.style(name, value)` fallback: name must be a valid CSS ident
  (letters/digits/hyphen, not starting with a digit) — debug
  `assertionFailure`, dropped in release.
- Inline values reach the DOM only via `attributes["style"]` → existing
  attribute escaper (single choke point preserved).
- Registry rule serialization is the new sink: any declaration value containing
  `{`, `}`, or control characters is rejected (debug `assertionFailure`, drop
  in release). Typed values are safe by construction; this guards only the
  string fallback and string-typed properties (`fontFamily`, `boxShadow`,
  `gridTemplate*`, `transition`, `listStyle`).
- Token names, theme names, class/id selector arguments: validated as CSS
  idents at construction (same rule as above). `Rule(class:)` rejects strings
  with spaces/combinator characters (`>`, `+`, `~`, `,`) — one simple selector
  per rule is enforced, not parsed.
- `.hex` colors validated by pattern; invalid → debug assert, `.transparent`
  in release.

## 13. Task 0 — phase-2 carry list

Land before styles, separate commits:

1. **ForEach closure Observation tracking** (spec promise, phase 2 §14):
   thread `withObservationTracking` through primitive content resolution so
   @Observable reads inside ForEach row closures invalidate the owning
   component.
2. Property-test fixture extension: environment writers, effects, observables.
3. `Input(value:)` gains `name:` parameter.
4. Textarea SSR: serialize value as child text (real HTML), not `value=""`.
5. `componentIndex` clobber hardening in `replace()` (remove only when
   `componentIndex[id] === m`).
6. Property test: divergent button counts clean-fail via `#require` instead of
   crashing; drop stale `_storeRowCount` comment; assert
   `scoped._listenerCount == full._listenerCount` (partially landed in
   8161cb2 — verify, close the rest).
7. `_AppearEffect` appear-before-disappear ordering comment.
8. Dead test fields cleanup (`Capture.inputs/keys` in EventPayloadTests;
   `captured` scaffolding in ResolverTests).
9. TodoMVC: filter test with mixed todos.

## 14. Testing strategy

Native-first (`swift test`, MockBackend), per project workflow (all task code
first, one test run at the end; no stepwise RED/GREEN):

- Value layer: `css` rendering for every type incl. numeric formatting, hex
  validation, `var()` tokens.
- Bag flatten: call order, last-wins, interaction with `style:`/`attribute`.
- Wrapper: single/multi root, text root no-op, component-root descent,
  collapse of consecutive modifiers, outer-wins ordering, identity segment.
- Registry: hash stability, dedup across elements and instances, monotonic
  growth, deterministic text, `setStylesheet` called only on growth.
- Pseudo/media rule text; `Styled` scoping (marker on all body elements at
  emission, absent inside child components' bodies, absent on non-`Styled`
  components); `App.globalStyles` unscoped emission at mount; dynamic rules
  (state-dependent `if` in `@RulesBuilder`) re-register and dedup.
- Themes: `:root` vs `[data-theme]` emission, `setTheme` attribute write,
  token reference rendering.
- `Style` protocol on both surfaces.
- Property test: styled fixtures + registry text equality (scoped ≡ full).

## 15. Acceptance

Restyle TodoMVC with SwiftWUI styles: tokens for the palette, a `Styled`
conformance with class rules for rows, `App.globalStyles` reset, `hover` on
buttons, one `media(.maxWidth)` rule, and a dark-theme toggle via `setTheme`.
Gates:

1. `swift test` green (native, full suite incl. new style tests).
2. `swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug` green for
   TodoMVC.
3. Browser check manual (Chrome extension connectivity unreliable — user runs
   Vite and verifies visually; not a merge blocker, consistent with phase 2).

## 16. Decision log

| # | Question | Decision |
|---|----------|----------|
| D1 | Branch | Continue on `feature/fable-new-vision`; phase 2 stays unmerged |
| D2 | Scope | Styles + full phase-2 carry list as Task 0 |
| D3 | CSS delivery | Hybrid: inline `style=""` for plain modifiers; generated `<style>` for pseudo/media/`Styled` rules/themes |
| D4 | Naming | CSS property names (`.margin(.top, .px(44))`), typed values, `.style("prop","val")` fallback |
| D5 | Themes | CSS custom properties; `StyleToken` statics; `data-theme` switching, zero re-render |
| D6 | Mechanism | Both paths: bag mutation on `HTMLTag` (fast, identity-transparent) + `_StyledTag` wrapper on any `Tag` (identity via `.type` segment) |
| D7 | Rule scoping | Vue-style scoped, always on for `Styled` (per-type marker class on body elements, compiled `.field.swui-s<hash>`); globals are unscoped by construction |
| D8 | Backend surface | Exactly one new method: `setStylesheet(_ text: String)`; DOM = one managed `<style>` textContent replace |
| D9 | Registry lifecycle | Monotonic, content-hash dedup; sweeping deferred until profiling demands |
| D10 | Rule declaration | `Styled` protocol field (`@RulesBuilder var styles: [Rule]`) for scoped + `App.globalStyles` for global; `Stylesheet`-as-Tag rejected (phantom node, post-pass marking, in-body `.global()` footgun) |
| D11 | Pipeline architecture | Early collapse into existing primitives: inline → `style` attribute at resolve, rules → classes + side-table registry. First-class styles in `Node`/patch ops (per-property diff, ref-counted rules) rejected as pay-ahead; additive upgrade path kept. Atomic-CSS-only rejected (rule explosion on dynamic values) |
