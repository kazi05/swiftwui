# Phase 5: Full HTML, SSG & Hydration — Design

Approved 2026-07-03. Builds on phase 4 (`feature/fable-new-vision`, through
commit `1f29943`). One spec covers the whole phase per user decision; the
implementation plan may stage it internally (tag set → SSG → loaders/snapshot
→ hydration → carry list).

## 1. Scope

**In:**
- Complete HTML tag set (~110 elements, full living standard).
- Static site generation: native pipeline that renders every page of an app
  to `.html` files (+ CSS), riding the real `Runtime`.
- Two output modes: **hydrate** (default; HTML + state snapshot + wasm boot)
  and **static** (plain MPA HTML, no wasm).
- Build-time data loading: `.staticTask` loader + `.task(policy: .build)`
  opt-in, awaited by the SSG driver.
- State snapshot: JSON script tag, restored by the client before first
  resolve.
- Full hydration: the wasm runtime adopts the prerendered DOM instead of
  rebuilding it; listeners attach without DOM churn.
- Phase-4 carry list (Task 0, §13).

**Out (deferred):**
- `swiftwui` CLI tool (phase 6 — phase 5 ships a library API; the user's
  site is an executable target).
- Server-side rendering at request time (SSR daemon). SSG is build-time only.
- Partial/island hydration; streaming.
- Snapshot of non-Codable state (skipped rows fall back to initial values).
- Script/Style/Base tags in the public tag set (head is Page-managed;
  script injection deliberately not offered — v1 sanitization stance).

## 2. Context — what this builds on

- `HTMLRenderer` is a pure `Node → String` fold; **T8 invariant** (its parsed
  DOM ≡ what DOMBackend builds) is already pinned by tests. Hydration stands
  on exactly this guarantee.
- `Runtime` owns location, guards/redirects, effects, `PageHead` diffing.
  SSG reuses it wholesale — no parallel "static resolver" that would drift.
- `StateStore.link` grafts boxes by Mirror order before body evaluation —
  the snapshot-restore hook point (concrete `Value` type is known there).
- Listeners are fire-time lookup (`ListenerRegistry`) — attaching them to
  adopted DOM nodes needs no special path.
- `RendererBackend` has 5 head-management methods from phase 4; the document
  serializer reuses `PageHead`/`MetaTag` semantics (managed set marked
  `data-swiftwui`).

## 3. Output modes

| | hydrate (default) | static |
|---|---|---|
| HTML pages | yes | yes |
| State snapshot script | yes | no |
| wasm `<script>` boot | yes | no |
| Client behavior | adopt DOM, SPA takes over | plain MPA; links are normal `<a>` navigations |
| Interactivity | full | none (`onClick` etc. dead — documented) |

`Link` already renders a real `<a href>`; interception lives in the wasm
runtime, so static pages degrade to MPA links with zero extra work.
`data-swui-link` markers in static output are inert and harmless.

## 4. Entry point & API

Library API only (D1):

```swift
public struct StaticSite {
    public struct Config {
        public var outDir: String
        public var mode: Mode                 // .hydrate(wasmScriptPath:) | .static
        public var paths: [String]            // explicit paths for dynamic patterns
        public var cssFile: Bool              // false = inline <style> (default)
    }
    @MainActor public static func generate<A: App>(_ app: A.Type, config: Config) async throws
}
```

The user's site is a SwiftPM executable target:

```swift
@main struct MySite: App {
    var body: some Tag { ... }
    #if !arch(wasm32)
    static func main() async throws {
        // parse CommandLine.arguments by hand: `ssg --out dist/ [--static] [--css-file]`
        try await StaticSite.generate(Self.self, config: ...)
    }
    #endif
}
```

`swift run MySite ssg --out dist/` — argument parsing is the example's code,
not framework API (no new dependencies). The full CLI wraps this in phase 6.

## 5. SSG pipeline

Per page path, on the host (native build, no browser):

1. Construct `Runtime` with a `StaticBackend` (MockBackend extended per §10
   read API), `initialPath` = the page path; `scheduleMicrotask` = immediate
   queue drained by the driver.
2. `mount()` — guards and redirects run exactly as in the browser.
3. Build-task loop (§6) until quiescent.
4. Serialize: `runtime.current` Node tree → `HTMLRenderer.render(nodes)`
   (existing internal fold) → body fragment; `StyleRegistry.text` → CSS;
   last applied `PageHead` → title/meta; StateStore → snapshot (§7).
5. `DocumentSerializer` (§9) assembles the full document →
   `outDir/<path>/index.html` (`/` → `index.html`, `/about` →
   `about/index.html`).

`StaticSite` + `DocumentSerializer` live in a new **native-only third module
`SwiftWUIStatic`** (depends on core + Foundation for file IO/JSONEncoder;
never built for wasm — the core stays dependency-free and wasm-clean). The
runtime exposes two underscore-public SPI accessors for the driver
(`_current` node tree, `_appliedPageHead`), following the existing
`_AttributeBag`/`_StateProperty` convention. Snapshot **decode** runs on the
client → lives in core using FoundationEssentials' `JSONDecoder` (present in
the wasm SDK).

**Route enumeration (D3):** `ResolveContext` gets a collect-routes flag; when
set, `Router._resolve` reports its `[RoutePattern]` into the context (and
resolves normally otherwise). The driver does one collect pass, then:
- static patterns (no `:param`, no `*`) → auto-enumerated;
- dynamic patterns → generated only for matching entries of `config.paths`;
- dynamic pattern with no matching explicit path → build warning, skipped
  (page reachable only via SPA navigation after hydration).

**Redirects during SSG (D4):** if mounting path P lands on path Q (guard
redirect), emit P as a stub:
`<!doctype html><meta http-equiv="refresh" content="0; url=Q">` — correct
MPA behavior, no duplicate content. Q itself is generated by its own entry
(it is either enumerated or explicitly listed; if not, the target simply has
no static page — no warning is emitted).

**Error policy (fail loud at build):** missing outDir → created; unwritable →
throw with path; loaders are non-throwing (`() async -> Void`) — the failure
modes are the iteration cap (§6; `buildTaskOverflow` carries page + iteration
count) and file IO.

## 6. Build-time data loading

One underlying mechanism, two surface APIs (D5):

```swift
enum TaskPolicy { case client, build }

extension Tag {
    // loader sugar: build-only task
    public func staticTask(_ action: @escaping () async -> Void) -> some Tag
    // opt-in on the existing effect
    public func task(policy: TaskPolicy = .client, _ action: ...) -> some Tag
}
```

Semantics:
- `.client` (default): browser-only, exactly today's behavior; never runs
  during SSG.
- `.build`: runs during the SSG build and is **awaited** before the HTML is
  taken; its writes land in the snapshot. On a hydrated client it does
  **not** re-run (marker: the restored snapshot row covers its identity —
  see below). On a cold SPA start without a snapshot it runs like a normal
  client task (same code works in dev without SSG).

Skip rule on the client: the snapshot carries the explicit list of `.build`
task identities that completed at build time (`"tasks"` array, §7). At boot
the client seeds this set; a `.build` task whose effect identity is in the
set is skipped exactly once (the entry is consumed). Identities not in the
set — including every task mounted later via SPA navigation — run normally.
A row-level decode failure does NOT re-run the task (state falls back to
initial values; debug warning); no snapshot → nothing skipped.
ADDENDUM (final-review I3): a completed `.build` task whose state row could
NOT be encoded (non-Codable / unkeyable) is dropped from the `"tasks"` list
at build time (debug warning names the key) — the client then re-runs the
loader and gets correct data instead of silently keeping initial values.

**Driver loop:** mount → collect scheduled `.build` tasks → await all →
flush → if the flush scheduled new `.build` tasks (a component appeared
because state changed) → repeat. Cap: 10 iterations (mirrors redirect-hop
cap); exceeding it fails the build (`buildTaskOverflow` carries page +
iteration count — see §5 error policy).

`EffectStore`'s task entries carry the policy; the SSG driver is the only
executor of `.build` entries, `DOMRuntime` is the only executor of `.client`
entries (plus un-skipped `.build` fallbacks).

## 7. State snapshot

Emitted only in hydrate mode, after quiescence:

```html
<script type="application/swiftwui-state" data-swiftwui>
{"v":1,"path":"/blog/hello",
 "rows":{"<identity-path>":["<slot0 JSON>", ...]},
 "tasks":["<identity-path of each completed .build task>", ...]}
</script>
```

- **Key:** canonical string form of `NodeIdentity`. `.type` segments carry
  `ObjectIdentifier` (process-local, NOT serializable) — a `@MainActor`
  type-name registry (`ObjectIdentifier → String(reflecting: T.self)`),
  populated by `resolve<T>` for every component boundary, supplies stable
  fully-qualified names; `.keyed` segments serialize via
  `String(describing: base)` (stable for Int/String/UUID keys — hashValue is
  seed-randomized and must never be used). Grammar
  (`c<n>` / `b0|b1` / `k<desc>` / `t<qualified-name>`, joined with `/`) is
  pinned by a golden test. Same-source builder and client produce identical
  names; an unknown key at link time degrades to initial values (safe).
- **Encode:** for each StateStore row, each slot whose boxed value is
  `Encodable` → `JSONEncoder` fragment. A non-Encodable slot drops the whole
  row (partial rows would desync Mirror order); debug build additionally
  warns when a dropped row's identity had a `.build` task ("loader result
  not serializable").
- **Decode (client):** the core stays Foundation-free (standing constraint) —
  `StateStore` holds only raw JSON strings plus an injected decoder hook
  (`(json: String, as: any Decodable.Type) -> (any Decodable)?`);
  `SwiftWUIDOM` injects a `JSONDecoder`-backed implementation
  (FoundationEssentials, present in the wasm SDK), `SwiftWUIStatic` the
  encoder side. `DOMRuntime` reads the script tag before mount and
  seeds `StateStore.pendingSnapshot: [String: [String]]` (canonical-path
  keyed). Inside
  `link()`, when a row is first created and a pending entry exists, each
  slot decodes as the concrete `Value.self`; count mismatch or decode error
  → entire pending row discarded, initial values used, debug warning.
  Consumed or not, the pending entry is removed after first link (no stale
  reuse after route changes).
- Version mismatch → whole snapshot ignored (cold client behavior).
- Escaping: `<script>` content is raw text — HTML entities are NOT decoded
  there, so `HTMLEscaping.text` must NOT be applied. Breakout defense is
  two-layer (ADDENDUM, task-10 review): the JSON encoder escapes `/` as
  `\/`, AND the serializer routes the final payload through
  `HTMLEscaping.scriptJSON` (audited v1 helper), which escapes `<`/`>`/
  U+2028/U+2029 as `\uXXXX` — `\/` alone cannot stop `<!--<script`, which
  flips the HTML tokenizer into script-data-double-escaped state and
  swallows the rest of the document. Pinned by tests with `</script>` and
  `<!--<script` state values.

## 8. Hydration — adopting walk

**Approach (D2): adoption, not reverse-parse reconciliation.** The normal
TreeApplier mount pass runs; a backend adapter claims existing DOM nodes
instead of creating them. Rejected alternative: parsing the DOM back into a
Node tree and diffing — reverse parser, browser attribute normalization,
lost component boundaries; fragile and large.

**Backend read API (§10) + `AdoptingWalk`** (generic over Backend, lives in
core, natively testable via MockBackend):

- Cursor stack over the existing tree, starting at the container's children.
- `createElement(tag)` → next cursor child; element with equal `tagName`
  (case-insensitive) → adopt, push cursor into it; else **mismatch**.
- `createTextNode` → next cursor child is a text node → adopt and SELF-HEAL
  via `setText` (no byte comparison — browser whitespace normalization;
  TreeApplier never setTexts fresh text nodes, so the adopting backend
  corrects the content itself — ADDENDUM task-8 I2); else mismatch.
- `insert(child, into:, before:)` → verify the adopted node is already in
  that position → no-op; else mismatch.
- Cursor exhausted early / leftover nodes when a parent closes → mismatch.

**Attributes/properties/listeners run unmodified:** the mount pass calls
`setAttribute`/`setProperty`/`setEventListener` on adopted nodes with
byte-identical values (T8) — idempotent, no repaint, one code path.
Listener attachment is precisely what hydration must do.

**Mismatch = give up, don't repair (D6):** clear the container → cold mount
(existing code). Debug: `assertionFailure` with identity path + expected vs
actual tag. Release: silent rebuild. Hydration is an optimization, never a
correctness dependency.

**DOMRuntime boot order:** read snapshot script → seed store → resolve with
restored state → adopting mount → remove the snapshot `<script>` element →
normal life. `coalesceText` already merges adjacent text nodes, matching the
HTML parser's view.

## 9. DocumentSerializer

Assembles the full page (SwiftWUIStatic module per D11, pure string building through
`HTMLEscaping`):

```
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" ...>            ← default iff Page's meta lacks one; UNMANAGED, no data-swiftwui (setMetaTags must never strip it at boot; ADDENDUM final-review I1)
  <title>…</title>                       ← PageHead.title
  <meta … data-swiftwui>                 ← PageHead.meta (managed set)
  <style>…</style> | <link rel="stylesheet" href="styles.css">
  <script type="application/swiftwui-state" data-swiftwui>…</script>   ← hydrate only
  <script type="module" src="…"></script>   ← hydrate only (head: deferred by default; ADDENDUM task-13 C2)
</head>
<body>…body fragment, byte-exact — no whitespace text nodes (adoption stream)…</body>
</html>
```

- `<title>` content is raw-text escaped (no child tags) — serializer-only
  concern, same as textarea.
- CSS: inline `<style>` by default (zero config, atomic page);
  `cssFile: true` → single shared `styles.css` = deduplicated union of all
  pages' registry texts (each page's Runtime registers only its matched
  route's styles, so per-page registries differ; the union preserves first-
  seen rule order and dedups by rule text).
- The wasm script path comes from `Mode.hydrate(wasmScriptPath:)` — the
  framework does not build wasm; the user's existing
  `swift package … js` output is referenced.

## 10. Backend surface changes

`RendererBackend` gains a minimal read API (needed by `AdoptingWalk`,
trivially implemented by MockBackend, DOM-backed in DOMBackend):

```swift
func childCount(of node: HostNode) -> Int
func child(of node: HostNode, at index: Int) -> HostNode
func tagName(of node: HostNode) -> String?   // nil for text nodes
func textContent(of node: HostNode) -> String
```

No other protocol changes. `StaticBackend` = MockBackend (already
tree-building) exposed to the SSG driver; possibly the same type.

## 11. Tag set completion

To the full HTML living standard (~110 elements), existing
`_HTMLContainerTag`/`_HTMLVoidTag` templates:

- **Typed params where semantics are real:** Table family
  (`Table/Thead/Tbody/Tfoot/Tr/Th/Td`, col/rowspan), `Select/Option/Optgroup`
  (controlled `value:` + `onChange`, Input pattern), `Fieldset/Legend`,
  `Details/Summary` (`open:`), `Dialog`, `Iframe` (`src:`, `sandbox:`),
  `Video/Audio/Source/Track` (`src:`, `controls:`, `autoplay:`, `loop:`,
  `muted:`), `Picture`, `Canvas` (`width:`/`height:`), `Dl/Dt/Dd`,
  `Blockquote (cite:)`, `Figure/Figcaption`, `Time (datetime:)`,
  `Progress/Meter (value:/max:…)`, `Abbr (title:)`, `Colgroup/Col (span:)`,
  `Output`, `Datalist`, `Address`, `Aside`, `Small`, `Sub/Sup`, `Mark`,
  `Del/Ins (cite:, datetime:)`, `Kbd`, `Cite`, `Q (cite:)`.
- **Bare container/void for the exotic rest** (`Bdi`, `Bdo`, `Ruby/Rt/Rp`,
  `Samp`, `Var`, `Dfn`, `Data`, `Map/Area`, `Wbr`, `Object/Embed/Param`,
  `Hgroup`, `Search`, `Menu`, `U`, `S`, `B`, `I`) — attributes via the
  existing `.attribute()` escape hatch.
- **`Noscript(String)` — text-only init, no child builder.** With scripting
  enabled the parser treats noscript content as raw text; element children
  would parse as one text node and break adoption (T8). One text child
  matches in both worlds.
- **Not offered:** `Script`, `Style`, `Base`, `Head`, `Html`, `Body`,
  `Title`, `Link(rel:)` head-link — head is Page/serializer territory (§1).
  Also not offered: `Template`/`Slot` — the parser puts template children
  into `.content` (not DOM children), which breaks T8 and adoption; both are
  shadow-DOM machinery meaningless without a JS templating API.
- New void elements are already in `HTMLRenderer.voidElements`; the set is
  the single source (assert coverage test).
- SVG/MathML namespaces: out of scope (foreign content needs
  `createElementNS` — new backend surface; a future phase).

## 12. Link & routing in static output

- `Link` output unchanged; static mode simply lacks the intercepting
  runtime → MPA behavior.
- Carry item "Link `#anchor`/relative destinations" (§13) matters doubly
  here: SSG pages live at real URLs, `href` must be correct without a
  JS-side normalizer. Resolution: keep root-relative canonical form in
  `href` at render time (pattern-known), anchors pass through untouched.

## 13. Task 0 — phase-4 carry list

- Link fragment (`#anchor`) + relative destination semantics (root-relative
  today) — needed for correct static `href`s (§12).
- ClickEvent adapter drops `targetValue`/`checked` for `.on(.click)` on
  wasm — map the fields (doc-only fallback if mapping is unsafe).
- `navigate()` debug-assert on scheme-bearing URLs.
- Two-Router assert exit-test.
- T2 pathological matcher items: release `*`-not-last degrade;
  `normalizePath` O(n²).
- Doc: `Page.title` state-driven updates apply only on navigation.

## 14. Testing strategy

Native (primary gate, as always):
1. **DocumentSerializer goldens** — full-page output per mode; `</script`
   break-out pinned; viewport-default rule.
2. **Snapshot round-trip** — encode → decode → `link()` adopts restored
   values; non-Encodable row dropped whole; count-mismatch fallback;
   version gate; row-presence skip rule for `.build` tasks.
3. **Adoption property test** — render fixture → parse into
   MockBackend tree (subset HTML parser for our own compact output only —
   test helper, not product code) → hydrate → assert zero
   structural mutations (create/insert/remove counters), listeners
   dispatchable; then mutate one node (tag/extra/missing) → mismatch →
   rebuild fallback engaged, tree correct.
4. **Build-task loop** — second-iteration `.build` task discovered and
   awaited; cap exceeded → thrown error lists identities.
5. **SSG driver** — static routes auto-enumerated; dynamic served from
   explicit paths; missing dynamic → warning; redirect page → meta-refresh
   stub; guard runs during generate.
6. **Tag set** — spot goldens per family (table, select controlled,
   details `open`), void-set coverage assert.
7. **TodoMVC acceptance** — `generate()` over the example: all static
   routes + `/todo/:id` from explicit paths; hydrate output contains
   snapshot + boot script; static output contains neither.

Wasm gates: Counter + TodoMVC `swift package … js` builds green.
Browser check (manual, non-blocking, Vite): hydrated page — no visual flash,
listeners fire without rebuild (`data-swui-mounted` timing), snapshot script
removed; static page — links navigate as MPA.

## 15. Acceptance

- `swift test` green (native), all new suites above.
- `swift run TodoMVC ssg --out dist/` produces a browsable static site;
  hydrate mode boots without container clear (verified by adoption
  counters in tests; visually in the manual browser pass).
- Both wasm example builds green.
- Carry list closed or explicitly re-triaged.

## 16. Decision log

- **D1** Entry = SwiftPM executable + library `StaticSite.generate`; no CLI
  until phase 6.
- **D2** Hydration = adopting walk over the live mount pass (rejected:
  reverse-parse + reconcile).
- **D3** Route enumeration = collect-routes resolve flag; static patterns
  auto, dynamic via explicit `paths`, else skip + warning.
- **D4** Guard redirect during SSG → meta-refresh stub page.
- **D5** Build-time data = task policy (`.client`/`.build`), `.staticTask`
  sugar; awaited loop capped at 10 iterations.
- **D6** Hydration mismatch → full rebuild fallback; debug assert, release
  silent. Never repair in place.
- **D7** Snapshot = JSON script tag keyed by canonical NodeIdentity strings;
  Encodable-only rows, whole-row drop; version-gated; explicit `"tasks"`
  list of completed `.build` identities drives the client skip rule; JSON
  `\/` escaping prevents `</script` breakout (no HTML escaping in raw-text
  context).
- **D8** Static mode = same HTML minus snapshot + boot script; MPA links by
  construction.
- **D9** Full ~110 tag set; typed params only where semantics are real; no
  Script/Style/Base/head tags; SVG/MathML deferred (namespace backend
  surface).
- **D10** CSS inline per page by default; optional shared `styles.css` =
  deduplicated union of per-page registries.
- **D11** `StaticSite`/`DocumentSerializer` in a new native-only module
  `SwiftWUIStatic` (core stays dependency-free and wasm-clean); snapshot
  decode in core via FoundationEssentials.
