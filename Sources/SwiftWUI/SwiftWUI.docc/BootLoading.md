# Boot Loading

Declared UI for the window between first paint and a live WebAssembly
runtime — a loader, a skeleton, and a reachable failure state, all authored
in Swift.

## Overview

A SwiftWUI binary is around 2.45 MB compressed. On a 1.5 Mbit/s connection
that is roughly thirteen seconds, and on 3G it approaches a minute. For the
whole of that window a prerendered page is a trap: the text and the styles
are on screen, every `Button` is dead, and nothing on the page says why. A
page with no prerender is simply blank, and a download that fails — offline,
a 404 after a redeploy, a dropped connection — leaves a page that is dead
permanently, with no way back.

Boot loading closes that window. You declare what the page shows while the
binary is in flight; the framework renders it natively at build time and
ships it inert inside a `<template>`; a small shim in `dist/app/` fetches the
wasm itself, so the progress it reports is bytes actually delivered rather
than a guess.

The whole feature is opt-in. An app that never declares a `bootUI` and never
calls `.whileBooting` boots through the same inline `import { init }` it
always did, gets no boot markup and no shim, and pays no extra build step.

### Four states, one attribute

Everything is carried by one attribute on `<html>` plus one CSS custom
property:

| `<html>` | meaning |
| --- | --- |
| `data-swui-boot="downloading"` | the wasm is streaming in |
| `data-swui-boot="starting"` | bytes in; compiling, `main()`, hydration |
| `data-swui-boot="failed"` | network error, non-2xx, a throw, or a stall |
| *(attribute absent)* | ready |

```
--swui-boot-progress: 0…0.99     on <html>, while the size is known
data-swui-boot-progress="unknown"  on <html>, when it is not
```

**The absence of the attribute is what "ready" means**, and that polarity is
the single most important decision in the design. The attribute is never in
the served HTML; only the shim, which is JavaScript, ever sets it. So a
client that runs no JavaScript — a text-extracting crawler, a link-preview
fetcher, reader mode, a user with scripting off — sees no boot attribute, no
boot CSS applies, and the `<template>` is never instantiated. It gets the
ordinary static page. The inverse polarity would have served those clients a
document whose real content is `display: none` behind skeletons.

The progress value is a unitless number rather than a percentage string, so a
progress bar is pure CSS (`transform: scaleX(var(--swui-boot-progress))`) and
the shim touches no element per chunk. **It is clamped to 0.99 and never
reaches 1** — so that stale HTML paired with a newer binary degrades instead
of overshooting; do not hang a "complete" style off the value. The `starting`
state is what says the bytes are all in. It is counted against a size stamped
into the HTML at build time, never against `Content-Length`: under brotli
that header is the compressed length while the stream yields decompressed
bytes, which reports about 390%.

## Declaring boot UI

### App level

``App/bootUI`` is the site-wide declaration. It defaults to ``BootUI/none``,
and ``BootUI/overlay(after:content:)`` opts in:

```swift
let bootSpin = Keyframes("boot-spin") {
    $0.from { $0.transform(.rotate(.deg(0))) }
    $0.to { $0.transform(.rotate(.deg(360))) }
}

struct MyApp: App {
    static var bootUI: BootUI {
        .overlay(after: .ms(300)) {
            Div {
                Div()
                    .width(.px(28)).height(.px(28))
                    .borderRadius(.percent(50))
                    .border(.px(3), .solid, .hex("#d8d8d8"))
                    .border(.top, width: .px(3), style: .solid, color: .hex("#4a4a4a"))
                    .animation(bootSpin, duration: .s(0.8),
                               timingFunction: .linear, iterations: .infinite)
                P { "Loading…" }
            }
            .position(.fixed).inset(.px(0)).zIndex(9999)
            .display(.flex).flexDirection(.column)
            .alignItems(.center).justifyContent(.center).gap(.px(12))
            .backgroundColor(.rgba(255, 255, 255, 0.92))
        }
    }

    var body: some Tag { RootApp() }
}
```

`after:` is how long boot must still be running before anything is shown. The
default of 300 ms is what keeps a cached wasm — which instantiates in tens of
milliseconds — from flashing a loader at every returning visitor. `.ms(0)`
shows the overlay as soon as the module executes: right for a site with no
prerender, wrong for a prerendered one, where it produces a
content-then-overlay flash.

Once shown, the boot UI stays for at least 300 ms. That is an internal
constant, not a knob, and it is enforced upstream by holding the download
stream open rather than by delaying the attribute removal — so it costs up to
300 ms of extra latency, and only for boots that land inside that band.

**Your `Sources/Entry.swift` needs a `boot-shell` subcommand.** `swiftwui
build` learns the shell by running `swift run <App> boot-shell` and reading
one tagged JSON line off stdout; `swiftwui init` scaffolds it. A project
created before this feature answers an unknown subcommand by printing usage
and exiting 0, so the CLI identifies the answer by content rather than by
exit status, prints

```
note: could not run 'MyApp boot-shell' — if this project predates boot UI, regenerate Sources/Entry.swift; building without boot UI
```

and builds with no boot markup at all. If you declared an overlay and never
see it, that note is the first thing to look for.

**Your `index.html` needs the boot markers.** The current template carries

```html
  <!--swiftwui:boot--><!--/swiftwui:boot-->
</head>
```

directly under the import map, and `swiftwui build` replaces everything
between them on every build. A project scaffolded before this feature has
neither marker, so the build falls back to inserting its block at `</head>`
and, in the same pass, deletes the `<script type="module">import { init } …
await init();</script>` the old template inlined in `<body>` — otherwise the
wasm would instantiate twice and the app would mount twice. It prints a note
when it does. Add the markers to keep the block where you can see it; a
module script of your own is never touched.

That host build is a new build axis — nothing else in the CLI compiles for
the host — so it is skipped outright when no source file under `Sources/`
so much as spells `bootUI`, and memoized on a hash of your sources
otherwise. A project that never opts in never pays it.

### Page level

``Page/bootUI`` overrides the app's declaration for one page, and defaults to
``BootUI/inherit``:

```swift
struct ArticlePage: Tag, Page {
    var title: String { "…" }
    // A text-first page: covering the words is worse than leaving them
    // briefly non-interactive.
    var bootUI: BootUI { .none }
    var body: some Tag { … }
}
```

`.none` on a page suppresses the app's overlay for that page: no shell, no
boot stylesheet and no shim in that document. It does not suppress
`.whileBooting`, which emits its placeholder regardless — see below, where
that combination turns out to do nothing at all. `.inherit` on an `App` reads
as `.none` — there is nothing above it to inherit from.

Selection happens per rendered document, once per `(path, locale)` pair, and
the shell is rendered through that document's own `Runtime`. That is what
makes localization work: an overlay may use `L10n` and ``LocalizedText``
normally, and the `ru` document ships the `ru` string rather than the default
locale's.

**A rendered `.notFound` page gets the app's overlay too**, and that is
deliberate. A 404 produced by the `Router`'s `notFound:` closure is a real
document — same wasm, same snapshot, same hydration — and it is the page most
likely to be hit cold by someone following a stale link. Suppressing the
overlay there would leave exactly the audience least likely to have a warm
cache staring at a dead page. A page that wants otherwise says
`bootUI: .none` like any other.

## Placeholders for one subtree

An overlay covers the page. ``Tag/whileBooting(_:)`` does the opposite: it
leaves the page alone and swaps a single subtree for a placeholder.

```swift
Div {
    H2("Availability")
    BookingWidget()
        .whileBooting {
            Div()
                .height(.px(320))
                .borderRadius(.px(8))
                .backgroundColor(.hex("#eee"))
        }
}
```

In a prerendered document this emits the placeholder inside a `<template>`
immediately before the real subtree, and stamps `data-swui-boot-veil` on the
real subtree's root. While `<html>` carries any boot state the veiled element
is `display: none` and the placeholder stands in its place; at mount the
framework removes the placeholder and drops the veil in the same paintless
turn, so the swap back is never an observable frame.

Five things to know before using it:

- **It needs the page to have a declared `bootUI`.** The veil rule ships in
  the boot stylesheet and the shim ships with the boot config, and a document
  gets neither unless its `App` or `Page` declares an overlay. On a page that
  declares none, `.whileBooting` still emits the placeholder and the veil
  attribute, but nothing ever sets `data-swui-boot` on `<html>` to act on
  them: the placeholder stays hidden inside its `<template>`, the real subtree
  stays visible, and you get inert extra bytes and no diagnostic. Declare an
  overlay — `.overlay { Div() }` with no visible content is enough — or drop
  the `.whileBooting`.
- **It only does anything on a prerendered page.** With no prerender there is
  no real subtree to stand in for, so `.whileBooting` contributes nothing and
  only `App`/`Page` overlays apply.
- **The real subtree's root must be a single element.** That element is where
  the veil attribute lives. A wrapped tag that renders several element
  siblings veils each of them; a bare text root cannot carry an attribute at
  all and stays visible, which trips a debug assertion so you see it.
- **It never wraps primary indexable copy.** A veiled subtree is
  `display: none` for the whole boot window, including for a JavaScript-executing
  crawler that snapshots mid-boot. This is for heavy interactive widgets, not
  for article text.
- **It doubles the markup** of every widget it wraps. A handful of heavy
  widgets is the intended use; blanket use grows the HTML measurably.

Do not put `.pageMeta` inside a placeholder. It resolves after its ancestor's
and clobbers the page head — in the build render only, which makes it a
prerender-only corruption that never reproduces in the browser.

## The failed state

`failed` is entered on a non-2xx response, a thrown `fetch`, a thrown
`init()` or instantiation, or a **stall** — thirty seconds with no byte
delivered. There is deliberately no wall-clock timeout: a 3G client
legitimately spends a minute on this download, and failing it mid-transfer
would be a self-inflicted outage. A stall that later recovers walks back out
of the failure UI on its own.

``BootRetry`` is the control that gets a user out of it:

```swift
static var bootUI: BootUI {
    .overlay {
        Div {
            P { "Loading…" }
            Div(class: "boot-failed-only") {
                P { "Couldn't load the app." }
                BootRetry { Span { "Try again" } }
            }
        }
    }
}
```

Showing the failure branch only in the failed state is a CSS job — one
`html[data-swui-boot="failed"] .boot-failed-only` rule in a stylesheet the
document already links; see *Styling the boot UI* for why it cannot be a typed
modifier.

`BootRetry` renders a `<button data-swui-boot-retry>`, and the shim delegates a
click listener on that attribute which reloads the current URL **minus** the
`swui-boot` debug parameter. It carries no Swift closure and cannot: the
failure state is precisely the state in which there is no runtime to run one.

The failure UI is reachable even after `main()` has started. The shim retains
the `<template>` elements before it ever calls `init()`, so a Swift trap
during the first `body` evaluation — which rejects `init()` after the boot
markup has already been stripped from the document — re-instantiates from
those retained references instead of leaving a visually complete, permanently
dead page.

## What boot UI can do, and what it cannot

Boot UI is rendered **once, natively, at build time**. Inside a `bootUI`,
a `.whileBooting` placeholder, or a ``BootRetry``:

- `@State` never re-renders. It is grafted, rendered once, and that value is
  what ships.
- `.task`, `.staticTask`, `.onAppear`, `.onDisappear`, `.onChange`,
  `.onRouteChange`, `.onWindowScroll`/`.onWindowResize` and
  `.preventsAccidentalDropNavigation` never run.
- Event handlers never fire. No Swift closure can run before the runtime that
  owns it exists.
- Localization *does* work — the shell renders against the document's own
  locale.
- Markup, typed styles and CSS ``Keyframes`` all work normally, which covers
  spinners and shimmers.

A build-time probe reports violations, and it is **narrow on purpose**. It is
exact for three things, because all three are directly observable in the
context a render returns:

- registered event handlers,
- `@State` rows,
- effects.

Those produce a stderr diagnostic and a **non-zero exit** — never an
`assert`, because `swiftwui build` defaults to `-c release` where assertions
are stripped and the check would silently do nothing in the one configuration
you ship. ``Link`` is the one exemption: it registers an internal click
handler but navigates perfectly well through its own `<a href>`, including in
the failed state, so it is downgraded to a warning.

Everything else is **unenforced, and documented as unenforced**:

- `@Environment`
- `@AppStorage` and `@SceneStorage`
- `@Dependency`
- the WAAPI engine — `withAnimation`, `.animation(value:)`, `.transition(_:)`

These are injected or resolved outside anything the build render can see. A
check that half works is worse than a documented limitation, because it
advertises a guarantee it does not provide — which is exactly why the probe
is narrow rather than aspirational. Read the list as: if you reach for one of
these inside boot UI, nothing will tell you, and it will not work.

## Styling the boot UI

Two framework rules do all the work, and they ship in their own
`<style data-swui-boot>` block:

```css
html:not([data-swui-boot]) [data-swui-boot-ui]{display:none!important}
html[data-swui-boot] [data-swui-boot-veil]{display:none!important}
```

The `!important` is not defensive habit. Every typed style modifier in this
framework emits an *element-attached* declaration — the renderer writes
`el.style.cssText` — and element-attached declarations outrank every
selector-matched author rule. Without `!important`, an overlay authored as
`.position(.fixed).display(.flex)` would never hide: it would be on screen
from first paint, before the delay threshold, and would stay there forever on
a page where Swift never mounts.

Note the polarity: the boot UI is hidden *only* in the ready state. In the
three non-ready states no framework rule matches it at all, so your own
layout stands untouched — no `display: revert` rolling a `flex` container
back to the UA's `block`.

**A progress bar is one inline style:**

```swift
Div()
    .height(.px(3))
    .backgroundColor(.hex("#4a4a4a"))
    .style("transform", "scaleX(var(--swui-boot-progress, 0))")
    .style("transform-origin", "left")
```

**State-dependent styling needs a plain stylesheet.** ``Rule`` builds
class, id and element selectors only, so `html[data-swui-boot="failed"] .x`
is not expressible through the typed API. Put those rules in a stylesheet and
link it from your own `index.html` — a `<link rel="stylesheet">` sitting in
the served document is applied by the browser whether or not any wasm ever
arrives, which is the property that matters here. ``LinkTag/stylesheet(_:)``
in ``Page/links`` works too, but only on a prerendered page: on an SPA route
the runtime applies the page's links at mount, which is after boot is over.

Two more things about what CSS exists during boot:

- The shell's own registered rules — anything from `.style { }` blocks,
  pseudo blocks, media blocks, `Keyframes` — land in `<style data-swui-boot>`
  and are available. `App.globalStyles` does **not**: it is registered by the
  client runtime at mount.
- On a prerendered page the app's whole stylesheet is already in the
  document, so the page around the overlay is fully styled. On a page with no
  prerender there is no app stylesheet at all until mount, and the boot UI's
  own block plus whatever your `index.html` links is everything you have.

When the binary size was not stamped — see *Caching and deployment* below —
the shim writes `data-swui-boot-progress="unknown"` on `<html>` and never
writes the custom property, so style an indeterminate spinner off that
attribute rather than showing a progress value that would be a lie.

## What ships in the page

**Boot markup is in the HTML of every page that declares it, and it is public
by construction.** It is rendered at build time into a `<template>` that any
visitor can read in devtools or in view-source, on every route, in every
locale. Never put anything in boot UI that is not safe for everyone — the
same rule that applies to ``DragPayload``, and for the same reason: it is
markup in a document you serve to the world.

Two structural notes:

- **The `<template>` is inert.** Its content is not rendered, not styled, and
  not surfaced to accessibility or to text extraction until the shim clones
  it. With JavaScript disabled the boot UI does not exist at all, rather than
  existing and being hidden.
- **A bare-text placeholder gets wrapped in a `<span>` at runtime.**
  `.whileBooting { Text("Loading…") }` resolves to a text node, which cannot
  carry the marker attribute that both the framework's DOM cleanup at mount
  and its own CSS select on — so the shim wraps it in a stamped `<span>`. If you
  inspect the DOM mid-boot you will see an element you did not write. Wrap
  bare text in an element yourself if the extra node matters to your layout.

## Form state across hydration

The shim records `input` and `change` events in the capture phase and
replays them after `init()` resolves, keyed by the element reference itself —
adoption reuses the existing DOM nodes, so no id scheme is needed. Text typed
during the download survives, along with the caret position, and a radio
group toggled A→B→A restores A.

Three limits worth knowing:

- **A restored value is invisible to `@State`** until the next real input
  event. The runtime believes it just rendered that tree; your `.onChange`
  and binding wiring fires on the next genuine event. Dispatching a synthetic
  event instead was rejected deliberately — it would run author code with a
  value the author never saw typed, and fire side effects twice.
- **File inputs are skipped**, by type. Assigning a non-empty value to one
  throws.
- **Focus is restored only if the user has not moved on.** If they have
  already focused something else, yanking the caret back would be worse than
  losing the restore.

Elements that a cold-boot fallback replaced — the path taken when adoption
fails — are skipped; their state was lost either way.

## Dev and production take different paths

This is the difference most likely to send you debugging a phantom:

- **`swiftwui dev` uses the shim** for every project, whether or not it
  declared any `bootUI`. So a dev page sets `data-swui-boot` on `<html>`
  while the production build of that same project — with no `bootUI` — emits
  the legacy inline `import { init }` and never sets the attribute at all.
  Boot attributes you see in dev are not evidence that a build will emit
  them. (The one dev page without the shim is one with no wasm to name yet:
  before the first successful build, dev falls back to the inline boot too.)
- **Dev never renders your shell.** It does not run `boot-shell`: on
  localhost the boot finishes well inside the delay so nothing would be
  shown, and a host compile on every hot-reload cycle would roughly double
  rebuild latency. Dev ships the shim with an *empty* shell, so your declared
  overlay appears only in a `swiftwui build`.
- **Dev never stamps a size**, so progress in dev is always the indeterminate
  path.

`?swui-boot=slow|fail|stall` forces the shim into a throttled download, an
immediate failure, or a stalled stream. It is honoured **only** when the dev
flag is present in the document, which `swiftwui dev` injects and a built
`dist/` never carries. That gate is not paranoia: `https://site/checkout?swui-boot=fail`
against a production build would show the site's own failure UI with the real
content veiled behind it. (Retry additionally strips the parameter, so a
forced failure cannot trap a user in a reload loop.)

To preview the boot states against a real build:

```sh
swiftwui serve dist --boot-debug
```

That sets the dev flag over the built directory. The same flag also skips
service-worker registration, so a PWA project served this way is **not** a
faithful preview of what it does in production — the CLI prints a warning
saying so.

### The examples stay on the inline boot

`Examples/Counter`, `Examples/Localized`, `Examples/TodoMVC` and
`Examples/DragDrop` are served by Vite and import the bundle by relative path
with no `/app/` URL space; none of them can reach the toolchain's resources
to get a copy of the shim, and nothing would stamp their `?v=` anyway. They
stay on the inline `import { init }` boot deliberately, which pins that path
as a supported contract rather than a legacy one. A hand-written
`index.html` that boots the app directly remains entirely valid — it just
gets no loader and no progress.

## Caching and deployment

The wasm URL the shim requests carries a version token:

```
/app/MyApp.wasm?v=a3f9c1e2
```

The file itself is **not** renamed — `index.js` hardcodes
`new URL("App.wasm", import.meta.url)` as its default, and renaming would 404
any consumer that boots without the shim.

The generated `dist/nginx.conf` turns that token into a cache policy:

```nginx
map $arg_v $swui_wasm_cc {
    default "no-cache";
    "~."    "public, max-age=31536000, immutable";
}
location ~ ^/app/.*\.wasm$ {
    types {}
    default_type application/wasm;
    add_header Cache-Control $swui_wasm_cc;
}
```

Only a request that actually carries a version is pinned. A request without
one did not boot through the shim — a hand-written `index.html`, or a build
that had nowhere to splice — and pinning an unversioned binary for a year
would be the worst outcome this feature can produce. The rest of `/app/`
stays `no-cache` on purpose: `index.js` imports its siblings by relative
path, a query string is not inherited by those imports, and one deploy under
`immutable` would strand half the bundle in caches permanently.

Four operational consequences:

- **A CDN that strips query strings silently makes this inert.** With `?v=`
  gone, the `map` answers `no-cache` for every request and every visitor
  revalidates the binary. Nothing breaks — that is today's behaviour — but
  the second visit stops being free. The same is true of any host with no
  header control (GitHub Pages, a bare S3 bucket): nothing in the design
  depends on `immutable` for correctness, only for speed.
- **Run `build` and `ssg` together, in that order.** The token identifies the
  bytes only as long as the HTML naming it was rendered against the same
  binary. `swiftwui build` rewrites only `dist/index.html`, so a dist holding
  prerenders from an earlier run has sub-pages naming the previous token. The
  build warns when it sees that, and the `immutable` header is emitted only
  when every document in `dist` agrees on one token.
- **A hand-written `index.html` that boots without the shim must add its own
  cache-busting query** if it wants the versioned header, since nothing else
  will stamp one for it.
- **PWA projects are unaffected.** The scaffolded `sw.js` matches on
  `url.pathname`, which excludes the query, so `/app/App.wasm?v=…` hits the
  precached entry rather than downloading again. A regression test pins that,
  because switching to a request-keyed match would silently double every PWA
  user's download.

If the wasm is missing entirely — a bare `swift run App ssg` before any wasm
build — the document emits no boot config at all and falls back to the inline
boot. The page still loads, just without a loader. The build does not fail.
If only the *size* is unknown, progress degrades to indeterminate; a wrong
*URL* would be a dead page, which is why one degrades and the other does not
happen.

### Known limitation: the scaffolded Docker deploy

`Dockerfile.deploy` copies the **project-root** `nginx.conf` — the scaffolded,
user-owned one — into the image, not the generated `dist/nginx.conf`. That
root config still says "SwiftWUI ships unhashed filenames: every asset must
revalidate" and carries no `/app/` wasm block, so **a site deployed through
the framework's own Docker path gets none of the caching described above**
(and no `gzip_static` either — see <doc:Deployment>).

The workaround is one line in your `Dockerfile.deploy`: copy
`dist/nginx.conf` instead of the project-root one. Both files are yours to
edit; `dist/nginx.conf` is rewritten on every release build, which is exactly
why the scaffold does not point at it by default.
