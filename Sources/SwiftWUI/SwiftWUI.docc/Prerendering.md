# Prerendering

Which routes get rendered to static HTML, when, what ends up in their
`<head>`, and what a prerendered page is and isn't safe to put in `@State`.

## Overview

`swiftwui ssg` (and the lower-level `StaticSite.generate`/`StaticSite.render`
it's built on) walks an app's routes and renders each one to a real HTML
document with a fresh `Runtime<MockBackend>` — guards, redirects, effects,
and `@State` all behave exactly as they do in the browser. Which routes it
renders, and how, is controlled by `Prerender` policy values; what ends up
in the document `<head>` is controlled separately, by `Page` and
`.pageMeta`.

Everything in this article is about the **build-time** and **on-demand from
a CLI invocation** paths. There is no render server yet — "on-demand" here
means invoking your app's own `ssg --path <path>` entry point to render one
path when you ask it to, not a process that serves requests. See the
`ssg --path` section below.

## Prerender policy

`Prerender` is a plain value, attached with `Route.prerender(_:)`:

```swift
Route("/routes/:from/:to") { p in RoutePage(from: p["from"], to: p["to"]) }
    .prerender(.paths { try await api.topRoutes() }
                 .allowingOnDemand()
                 .revalidate(.hours(6)))
```

Four starting points:

```swift
Prerender.never       // client-only — never produces a page (private dashboards)
Prerender.build       // rendered at build time; pair with .paths{} for a dynamic pattern
Prerender.onDemand     // not built; rendered on first request (needs a render server — Phase B)
Prerender.paths { ["/routes/mcx/mow", "/routes/led/mow"] }   // build-time enumeration
```

and two modifiers that return a new value, so they chain:

```swift
.allowingOnDemand(_ enabled: Bool = true)   // also serve paths NOT built, on first request
.revalidate(_ d: Duration)                  // cache lifetime before a page is stale (Phase B)
```

`.allowingOnDemand`, not `.onDemand`, on the instance side — `Prerender` has
a static property named `onDemand` and chaining `.onDemand` after another
call would collide with it.

A static route pattern (no `:capture` segments) needs no `.paths` provider —
its one path *is* the pattern. A dynamic pattern with no provider yields
nothing from `.prerender(.build)` alone; you have to tell it which concrete
paths to enumerate, either with `.paths { }` or via `StaticSiteConfig.paths`.

### Resolution and the kill-switch

A route that declares no policy doesn't necessarily opt out — the policy is
resolved most-specific-first:

```swift
Route.prerender ?? App.prerender ?? config.defaultPrerender
```

`Route.prerender(_:)` on the individual route wins; failing that,
`App.prerender` (a static property on your `App` type) is the site-wide
default; failing that, `StaticSiteConfig.defaultPrerender` is what the build
invocation itself passed in. `nil` all the way down falls back to the
pre-policy behavior: static patterns build, dynamic patterns build only for
paths explicitly listed in `StaticSiteConfig.paths`.

Separately, `StaticSiteConfig.prerenderEnabled` is an operational
kill-switch — when `false`, nothing renders and the site ships as an SPA
shell. `PrerenderSwitch.enabled(fromEnvironment:)` reads it from the
`SWIFTWUI_PRERENDER` environment variable with a **fail-closed** grammar:

- unset → prerendering is **on** (the default, unchanged behavior)
- `1`, `true`, `on`, `yes` (case-insensitive, whitespace-trimmed) → **on**
- anything else non-empty → **off**

The asymmetry is deliberate: an operator reaching for this variable mid
incident is trying to turn prerendering *off*, and a typo must never land
them on the opposite of what they meant. There's no ambiguous middle value
that silently keeps rendering.

## `.pageMeta` and why `Page.title` can't do this

`Page` is the simple case — a route's top-level content conforms and
supplies static-ish head values:

```swift
struct AboutPage: Tag, Page {
    var title: String { "About" }
    var meta: [MetaTag] { [.description("Who we are")] }
    var body: some Tag { /* … */ }
}
```

But `Router` snapshots `title`/`meta`/`links` from the route's content
**before** `@State` is grafted onto that subtree and before any
`.staticTask` loader has run. A title computed from state a loader fills in
renders its *initial* value — usually blank or a placeholder — both in the
browser and in SSG output.

`.pageMeta` exists because `Page` structurally cannot express this. It's a
modifier applied *inside* the route subtree, so it resolves after the state
graft and re-resolves on every pass a `.staticTask` write triggers:

```swift
struct RoutePage: Tag {
    @State private var price: Int?
    var body: some Tag {
        Content()
            .staticTask { price = await api.fare() }
            .pageMeta(title: price.map { "From \($0) ₽" },
                     meta: price.map { [.description("From \($0) ₽")] })
    }
}
```

Every `.pageMeta` parameter is optional and means "leave whatever the
baseline had" — pass only the fields you're overriding, where "the baseline"
depends on what else the matched route declares:

- **Both `Page` and `.pageMeta`:** the patch folds over that pass's `Page`
  snapshot (title/meta/links from the `Page` conformance).
- **`.pageMeta` with no `Page` conformance:** the patch folds over an
  *empty* baseline (`title: ""`, no meta, no links) — **not** over the
  previously matched route's head. This is what keeps one route's `.pageMeta`
  from silently inheriting fields the previous page happened to set.
- **Neither `Page` nor `.pageMeta`:** see below.

### A route with no head declaration doesn't clear the head

This is the contract, not a bug: a route whose content declares **neither**
`Page` **nor** `.pageMeta` leaves the previously applied `<head>` exactly as
it was. Navigate from a page with a title to one that sets nothing at all,
and the old title is still what's in the tab. If a route genuinely wants a
blank head, it has to say so explicitly (conform to `Page` with an empty
title, or add a bare `.pageMeta(title: "")`) rather than relying on absence
to mean "clear".

### JSON-LD

`.pageMeta(structuredData:)` takes an array of pre-serialized JSON strings,
each emitted as its own `<script type="application/ld+json">` block:

```swift
Content().pageMeta(structuredData: [#"{"@type":"Offer","price":"4320"}"#])
```

Every block is written through `HTMLEscaping.scriptJSON`, the same
raw-text-sink helper the hydration snapshot uses — never `.text`, which
would corrupt the JSON and miss a `</script>` breakout inside a string
value. In `DEBUG` builds, a structurally malformed block (unbalanced braces,
empty) trips `assertionFailure` at the call site — a JSON typo is an
authoring bug and should fail loudly during development, not ship silently.

If you write a custom `RendererBackend`, note that `setStructuredData(_:)`
has a default no-op implementation — a backend that doesn't forward it
compiles fine and silently drops JSON-LD. See the CHANGELOG entry for this
release.

## Canonical synthesis

When `StaticSiteConfig.siteURL` is set and a rendered page's head declares
no `rel="canonical"` link of its own, the build adds one:

```swift
StaticSiteConfig(outDir: "dist", mode: .staticOnly,
                 siteURL: "https://example.com")
```

`https://example.com/routes/mcx/mow` gets a canonical pointing at itself.
This exists because "the author remembered to set a canonical" is not a
property that holds across tens of thousands of generated pages, and a
query-decorated inbound link (`?utm_source=...`) otherwise serves the exact
same body with no canonical signal at all.

**No `siteURL`, no synthesis** — a relative canonical buys little, and an
app that predates this feature sets no `siteURL`; its output must not move
under it. The same `siteURL` gate also controls sitemap generation, below.

To opt a specific page out while keeping synthesis on everywhere else,
declare your own canonical (via `Page.links` or `.pageMeta(links:)`) — an
explicit canonical is never overwritten. To turn synthesis off entirely,
set `StaticSiteConfig.synthesizeCanonical = false`.

## `@RouteParam`, `.onRouteChange`, and the ordering guarantee

`@RouteParam` reads a matched route's captures without threading them
through init parameters:

```swift
struct RoutePage: Tag {
    @RouteParam("from") var from: String?
    var body: some Tag { Text(from ?? "—") }
}
```

`nil` means the capture is either absent from the URL or failed to parse as
`Value`. For pushing the whole `RouteInfo` (path, query, params) into a
plain model class — which has no position in the render tree to read an
environment value from — use `.onRouteChange`:

```swift
@Observable final class RouteModel {
    var from: String?
    var loadedFor: String?
}

Content()
    .onRouteChange(initial: true) { info in model.from = info.params["from"] }
    .staticTask { model.loadedFor = await api.fare(from: model.from) }
```

`.onRouteChange(initial: true)` fires once on mount (in addition to every
subsequent navigation) and — this is the ordering guarantee — it fires
**before** `.staticTask` loaders run in the same pass. That's what makes
model-driven SSG loading possible at all: without it, a build-time loader
reading route params off the model would see nothing on the very pass that
needs them.

### `staticTask(id:)`'s id is inert during a build

`staticTask(id:)` mirrors `task(id:)`'s signature for symmetry, but the two
only behave alike on the **client** path. During a build, `EffectStore`
dedupes pending `.build` tasks purely on node identity — the same identity a
loader occupies every pass, since it isn't inside a `ForEach` or similar —
so the `id` value plays no role in whether or how often it runs at build
time. The `id` only matters for a client-side re-run after hydration, the
same way `task(id:)`'s id does: a changed id there cancels the running task
and starts a new one.

## `ssg --path`

The `swiftwui` CLI's own `ssg` subcommand only takes `--out`/`--product` — it
just wraps `swift run <App> ssg --out <dir>`. `--path` is a flag each
generated app template's `main.swift` parses itself, on top of the public
`StaticSite.render` primitive, invoked directly as `swift run <App> ssg
--path <path> [--out <dir>]`:

```swift
if let onlyPath {
    let page = try await StaticSite.render(MyApp.self, path: onlyPath,
                                           config: .init(outDir: out, mode: mode,
                                                         prerenderEnabled: prerenderEnabled))
    switch page.outcome {
    case .page:
        try StaticSite.writeDocument(page.html, path: onlyPath, outDir: out)
    case .redirect(let target, _): print("\(onlyPath) redirects to \(target); nothing written")
    case .notFound: print("\(onlyPath) matched no route; nothing written")
    case .error(let m): print("render failed: \(m)")
    }
}
```

`.render` is what `.generate` itself is built on, and what any future
render server would be built on too — but there is no render server yet.
`ssg --path <path>` writing exactly one file, on demand from the CLI, is the
current answer to "render this one path without a full site build." A
`RenderedPage.outcome` is explicit about what happened — `.page`,
`.redirect(to:permanent:)`, `.notFound`, or `.error(_:)` (render failed;
transient, never map it to a 404 — repeated 404s deindex a URL, and an
upstream outage during a build is routine, not permanent).

**`render(path:)`/`ssg --path` does not consult per-route `.prerender`
policy.** It's a manual primitive: it renders whatever `path` you name,
regardless of whether that route declares `.prerender(.never)` or anything
else — resolving route policy is `generate()`'s job, for its own automatic
enumeration, not this call's. `render(path:)` does honour
`StaticSiteConfig.prerenderEnabled`, the operational kill-switch: with it
`false`, it returns `.error(_:)` immediately and writes nothing. If you need
`.never` to actually block a specific path from `ssg --path`, that check has
to live in your own CLI wrapper — the framework doesn't do it for you here.

## Sitemaps

`StaticSite.generate` writes `sitemap.xml` (or a `sitemap.xml` index plus
`sitemap-N.xml` chunks past 45,000 URLs) alongside the generated pages, but
**only when `StaticSiteConfig.siteURL` is set and at least one page rendered
with a `.page` outcome** — the same `siteURL` gate canonical synthesis uses,
because a sitemap of relative or unknown-origin URLs isn't useful to a
crawler, plus a plain "there is nothing to list yet" check: `siteURL` set
with zero `.page` outcomes writes no sitemap. Only pages that actually
rendered with `.page` outcome are listed; a page whose Router fell through
to `notFound` is excluded, so a stale or bad path in
`StaticSiteConfig.paths` can't end up submitted to a search engine as
canonical content.

## Security note: what a prerendered page ships to every visitor

A prerendered page is public, cacheable, and shared — anyone who requests
that URL gets the exact same document. In hydrate mode, that document also
embeds a hydration snapshot that serializes **every `Codable` `@State`
value** reachable in the rendered subtree, not just the fields the body
happens to render.

That means a view model holding a whole upstream DTO — say, a `Codable`
struct decoded straight from an internal API response — ships every field
of that DTO to every visitor of that page, including fields the page never
displays: internal ids, pricing you show to admins only, anything. This is
easy to miss because nothing about it looks wrong in the rendered HTML; the
extra data is only visible in the `<script type="application/swiftwui-state">`
block.

Two rules of thumb for anything rendered on a `.prerender`-enabled route:

- **Bind narrow, display-only types**, not whatever a backend call handed
  you. Project the response down to a small `Codable` struct that holds
  exactly what the page renders before putting it in `@State`.
- **Anything per-user or sensitive gets `.prerender(.never)`.** A private
  dashboard, a page keyed to a logged-in session, anything with
  user-specific pricing or PII has no business being built into a static
  file in the first place — it belongs on the client-only path. This
  protects `generate()`'s automatic enumeration only — as noted above,
  `render(path:)`/`ssg --path <path>` does not consult `.prerender` at all,
  so a manual `ssg --path /account` call still renders and writes a
  `.never` route if you invoke it directly. The kill-switch
  (`prerenderEnabled` / `SWIFTWUI_PRERENDER=off`) is the only thing that
  stops that call from producing output.
