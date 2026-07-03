# Phase 4: Pages & Routing — Design

Date: 2026-07-03. Status: approved in brainstorming, pending user spec review.
Branch: `feature/fable-new-vision` (continues; phases 2–3 remain unmerged by
standing user decision — phases accumulate on one branch). D-numbers below are
local to this spec.

## 1. Scope

**In:**
- `Route` + pattern matching: static segments, `:param` captures, `*` catch-all,
  query-string parsing. v1-parity feature set including guards with redirect.
- `Router` tag: matches the current location, resolves the winning route's content
  under a keyed identity segment; `notFound:` fallback.
- SPA navigation: `Link`, `\.navigate` / `\.back` environment actions,
  History API (`pushState`/`replaceState`/`popstate`). No hash mode.
- `Page` protocol (`Tag` + `title` + `meta`): `document.title` and managed `<meta>`
  tags applied on navigation.
- `@QueryParam` property wrapper (read-only, typed via `LosslessStringConvertible`).
- Task 0: phase-3 carry list (§12).

**Out (deferred):** nested routers, scoped invalidation of the Router subtree
(navigation does a full pass; the differ keeps transitions cheap), async route
loaders, scroll restoration, a `.key()` modifier for forced state reset,
`styleSheets`/`scripts` on `Page` (phase 5 SSG — SPA styles already flow through
the phase-3 `StyleRegistry`), `NavigationStack` (duplicates browser history in a
web SPA), SSG route enumeration (phase 5).

## 2. Context — what this builds on

- Environment actions (phase 3): `ctx.environment.setTheme = { … }` injected at
  the root of `renderPass` (Runtime.swift). `\.navigate`, `\.back`, and
  `\.routeInfo` are injected at the same seam.
- `_EnvironmentProperty` seam (phase 2): `@Environment` values injected before
  `body` runs. `@QueryParam` rides the same seam.
- `.keyed(NodeKey)` identity segment (phase 1): ForEach resolves children at
  `path.appending(.keyed(key))`. Router keys matched content the same way.
- `RendererBackend` extension precedent (phase 3): `setStylesheet(_:)`.
  Phase 4 adds the history/head surface (§3); MockBackend records calls, so the
  whole navigation flow is natively testable.
- `markDirty(.root)` → microtask-coalesced full `renderPass` (phase 2).
  Navigation reuses it; no new reactivity primitives.

## 3. Backend surface

`RendererBackend` gains:

```swift
func pushState(path: String)
func replaceState(path: String)
func historyBack()
func setTitle(_ title: String)
func setMetaTags(_ tags: [MetaTag])
```

- `DOMBackend`: `history.pushState`/`replaceState`/`back`, `document.title`,
  and managed `<meta>` elements marked `data-swiftwui` — `setMetaTags` replaces
  only managed tags; hand-written `<meta>` in `index.html` is never touched.
- `MockBackend`: records every call (paths pushed, titles set, tag lists) for
  assertions.
- `DOMRuntime` additionally wires `popstate` → `Runtime.handlePopState(url:)` and
  reads `window.location.pathname + search` at mount for the initial location.
  Native runs pass the initial location via an init parameter (default `"/"`).

## 4. Route & pattern matching

Pattern grammar — path split on `/`, three segment kinds:

| Kind | Example | Semantics |
|---|---|---|
| static | `about` | exact, case-sensitive |
| param | `:id` | captures one segment, percent-decoded |
| catch-all | `*` | matches the remaining tail; only valid as the last segment |

- Trailing slash normalized: `/x/` ≡ `/x` (root `/` untouched).
- Query string (`?a=b&c=d`) parsed separately from the path — pairs split on
  `&`, each pair on the first `=`, both sides percent-decoded — and is available
  on every route, not part of matching.
- Invalid percent sequences: the raw string is kept; matching never traps.
- **Order: first-match-wins in declaration order** (v1 semantics — predictable,
  no specificity ranking).
- No match: `Router(notFound:)` content renders; without it, empty render plus a
  debug-build message.
- Invalid pattern (`*` not last, empty `:` name) → debug assert at `Route`
  construction.

```swift
Route("/") { HomeView() }
Route("/todo/:id") { params in TodoDetail(id: params["id"]!) }
Route("/docs/*") { DocsCatchAll() }
```

## 5. Guards & redirects

v1-parity, sync only:

```swift
public enum RouteGuardResult { case allow, redirect(String) }
Route("/admin", guard: { auth ? .allow : .redirect("/login") }) { AdminPanel() }
```

- Guards run during Router resolution, before a route can win the match; a
  redirecting route is skipped.
- **Redirects never navigate re-entrantly.** Router records `pendingRedirect` in
  `ResolveContext`; after the pass completes, Runtime performs
  `navigate(to:, replace: true)` (replace — redirect hops must not pollute
  history).
- Redirect chains capped at 10 hops: debug assert; release stops at the last
  location and renders its match (or notFound).

## 6. Router tag — resolution & identity

`Router` is a **primitive tag** (like `ForEach` — plain components cannot append
identity segments):

```swift
Router(notFound: { NotFound() }) {
    Route("/") { HomeView() }
    Route("/todo/:id") { params in TodoDetail(id: params["id"]!) }
}
```

`_resolve`: read the current location from `ctx.environment.routeInfo`, run the
match (§4–5), build the winner's content with its params, resolve it at
`path.appending(.keyed(NodeKey(pattern)))`.

**Identity semantics (D2):** the key is the **pattern string**, not the matched
path.

- Route change (`/` → `/active`): different key → clean teardown of the old
  route's @State, fresh mount.
- Param-only change (`/todo/1` → `/todo/2`): same pattern → same identity →
  **@State preserved**, content rebuilt with new params. SwiftUI semantics
  (same identity = same state); a forced-reset `.key()` modifier is backlog.

Params reach content two ways: the builder argument
(`Route("/todo/:id") { params in … }`) and `\.routeInfo.params` from the
environment deeper in the tree.

One `Router` per app; a second Router resolving in the same pass → debug assert.
Nested routers are backlog.

## 7. Navigation flow

Runtime owns `currentLocation: (path: String, query: [String: String])`.

- `Runtime.navigate(to:replace:)`: normalize URL → update `currentLocation` →
  `backend.pushState`/`replaceState` → `markDirty(.root)` → existing
  microtask-coalesced full pass.
- `handlePopState(url:)`: same, minus the pushState step.
- Environment injection at the `renderPass` root (next to `setTheme`):
  - `\.routeInfo` — `path`, `query`, `params` of the matched route;
  - `\.navigate` — `(String, replace: Bool = false) -> Void`;
  - `\.back` — `() -> Void` → `backend.historyBack()`.

`params` in `routeInfo` are written by Router during resolution (Router resolves
before its subtree, so readers below it see the current match; readers outside a
Router see `[:]`).

## 8. Link

`Link("/todo/42") { … }` renders `<a href="/todo/42">` + a click listener that
calls `preventDefault` then `\.navigate`. The browser keeps default behavior
(no interception) when:

- the click is modified (cmd/ctrl/shift/alt, non-primary button) — the click
  payload gains modifier fields if it lacks them;
- the URL is external (has a scheme: `https:`, `mailto:` …) — rendered as a
  plain `<a>`, no listener attached.

## 9. Page protocol & head application

```swift
public protocol Page: Tag {
    var title: String { get }
    var meta: [MetaTag] { get }   // default []
}
```

- `MetaTag`: typed factories ported from v1 (`charset`, `viewport`,
  `description`, `named`, `property`); names/attributes validated by the
  `_AttributeBag` rules.
- Application: Router checks the matched content via `as? any Page` during
  resolution and stores a head snapshot in `ResolveContext`; after the pass,
  Runtime diffs it against the last applied snapshot and calls
  `backend.setTitle` / `setMetaTags` on change.
- A route whose content is not a `Page` leaves `document.title` untouched.
- Phase 5 reuses the same protocol to serialize `<head>` for SSG.

## 10. @QueryParam

```swift
@QueryParam("filter") var filter: String?          // raw
@QueryParam("page") var page: Int?                  // LosslessStringConvertible
```

- Reads from the environment snapshot via the `_EnvironmentProperty` seam
  (exactly like `@Environment`); re-renders on query change come for free from
  the full pass.
- Typed variant returns `nil` when the parameter is absent **or** fails to parse.
- Read-only in phase 4 — writing the query is `navigate`.

## 11. Error handling / security

- Percent-decoding failures keep the raw string; never trap (§4).
- `Link` href: DOM path goes through `setAttribute` (no markup injection
  possible); the phase-5 SSR path flows through the existing `HTMLEscaping`
  choke point.
- Meta values: names validated (§9), values written via DOM APIs.
- Redirect loop cap (§5). Invalid patterns assert at construction (§4).
- No `innerHTML` anywhere; consistent with the v1 security audit.

## 12. Task 0 — phase-3 carry list

- MockBackend textarea child-text golden test.
- ForEach + row-component double-fire test (combined mutation).
- (Deferred by triage, not carried: DOMBackend.setStylesheet JSValue idiom.)

## 13. Testing strategy

Native, MockBackend:

- Table-driven matcher tests: static/param/catch-all/query, trailing slash,
  encoded chars, declaration order, no-match.
- Guards: allow, redirect, chain, 10-hop cap.
- Identity: route change resets @State; param-only change preserves it;
  query change re-renders a `@QueryParam` reader.
- Link: click → dispatch → location + DOM updated, pushState recorded; modified
  click not intercepted; external URL gets no listener.
- popstate simulation: location changes with no pushState call.
- Page: title/meta applied at mount and swapped on navigation; non-Page route
  leaves title alone; managed-meta replacement never touches unmanaged tags.
- Property fixture (phase 3) extended with a Router: scoped ≡ full holds with
  routing in the tree — this pattern caught real bugs in phases 2 and 3.

## 14. Acceptance

- TodoMVC: filters as routes `/`, `/active`, `/completed`, detail page
  `/todo/:id`, per-route titles via `Page`, `Link`s in the footer.
- Gates: `swift test` fully green; TodoMVC wasm js build green.
- Browser check manual (Vite :8080), non-blocking — same as phase 3 §15.

## 15. Decision log

- **D1** Router state lives in Runtime, delivered via environment (setTheme
  pattern). Rejected: @State-based Router component (fragile action plumbing),
  @Observable router (Observation is excluded from the v2 pipeline).
- **D2** Matched-content key = route pattern string → param-only navigation
  preserves @State. Explicitly chosen over key-by-full-path in brainstorming.
- **D3** First-match-wins, declaration order; no specificity ranking.
- **D4** pushState only, no hash mode (roadmap names History API; Vite SPA
  fallback covers dev).
- **D5** Redirects are post-pass `navigate(replace: true)`, never re-entrant;
  capped at 10 hops.
- **D6** `Page` limited to `title` + `meta`; styleSheets/scripts deferred to
  phase 5 (dead surface in an SPA runtime).
- **D7** Navigation triggers a full pass via `markDirty(.root)`; scoped router
  invalidation is a backlog optimization.
- **D8** Router is a primitive tag: keyed identity segments can only be appended
  in `_resolve` (ForEach precedent). Brainstorming initially said "plain
  component"; corrected against the actual identity mechanics, approved
  semantics unchanged.
- **D9** One Router per app, debug-asserted; nested routers backlog.
- **D10** (post-review addendum) A recorded guard redirect is performed
  post-pass even when a later route matched and rendered transiently —
  redirect wins over the transient frame. Pinned by the
  two-redirecting-routes test in GuardAndPageTests.
