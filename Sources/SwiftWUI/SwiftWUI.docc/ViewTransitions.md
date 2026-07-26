# View Transitions

Animated, shared-element morphs across a route change or an in-page state
change, built on the browser's native View Transitions API.

## Overview

A cross-route navigation in SwiftWUI tears down the old subtree and mounts a
new one — there is no live element to interpolate. View transitions solve
this at the browser level: `document.startViewTransition()` captures the old
frame, lets the DOM change, captures the new frame, and animates between
them by matching elements on a `view-transition-name`, not by node identity.
SwiftWUI's API is a thin, typed orchestrator over that mechanism.

The feature is entirely opt-in. An app that never calls `.pageTransition`,
never passes `transition:` to `navigate`, and never calls
`withViewTransition` sees no behavior change at all — no extra CSS, no
`<html>` attributes, no different navigation timing. Two more APIs are
opt-in the same way, just not covered by that list: `Route(transition:)`
registers its CSS eagerly during `Router._resolve` (whether or not that
route is ever navigated to), and `.matchedTransition` always emits an
inline `view-transition-name` the moment it's called.

Orthogonal to `withAnimation`/`.animation(value:)`/`.transition(_:)` (which
animate properties of one live element) and to CSS `@keyframes`, whose
`Keyframes` value this feature reuses for custom transitions.

### Quick start

Two lines: an ambient default on the `Router`, and the same shared-element
id on both pages.

```swift
Router {
    Route("/") { HomePage() }
    Route("/search") { SearchPage() }
}
.pageTransition(.fade)
```

```swift
// HomePage
SearchForm().matchedTransition(id: "search-form")

// SearchPage
SearchForm().matchedTransition(id: "search-form")
```

Navigating between the two pages now cross-fades, and the two `SearchForm`
elements — unrelated DOM nodes on unrelated pages — morph into each other,
because the browser matches by name, not by identity.

## Choosing a transition

`PageTransition` is a plain value with four presets:

```swift
public static let fade: PageTransition
public static func slide(edge: Edge = .trailing) -> PageTransition
public static func zoom(sourceID: String, in namespace: TransitionNamespace? = nil) -> PageTransition
public static func custom(old: Keyframes, new: Keyframes) -> PageTransition
```

and three tuning modifiers, each returning a new value:

```swift
.duration(_ d: CSSDuration)                 // default .ms(220)
.timingFunction(_ f: TimingFunction)        // default .ease
.respectsReducedMotion(_ flag: Bool)        // default true — see Caveats
```

A transition can be declared at four different places, and only the
**most specific one that's present** wins:

1. **Explicit, at the call site** — `navigate("/search", transition: .zoom(sourceID: "card-7"))`.
2. **On the destination route** — `Route("/search", transition: .slide()) { SearchPage() }`.
3. **On the nearest ambient `.pageTransition`** — a `Link`, a subtree, anything
   between the call site and the `Router`.
4. **On the `Router` itself** — the app-wide default; it also doubles as the
   ambient value read by level 3 when nothing closer is set.

No transition at any of these levels means an instant swap — today's
behavior, unchanged.

`Route`'s `transition:` only applies when *that* route resolves as the
navigation's destination; it has no effect on the page navigated *away*
from. Back/forward navigation (the browser back/forward buttons) has no call
site to be "explicit" at, so it resolves the destination route's own
transition or the `Router`'s default — an ambient `.pageTransition` on some
in-between subtree is not consulted, since there's nothing analogous to a
`Link` click to read it from.

A redirect performed with `navigate(_:replace: true)` does not itself
animate unless you pass `transition:` explicitly — the user is meant to see
one animated hop straight to wherever the redirect lands, not two.

### `@Environment(\.navigate)` vs `@Dependency(\.navigate)`

Both read from the same underlying action and accept the same
`transition:` argument, but only one of them can see an ambient value:
`@Environment(\.navigate)` picks up the nearest ambient `.pageTransition`
automatically, because it's resolved from the current position in the
render tree. `@Dependency(\.navigate)` is deliberately not
render-tree-bound (there's no "current position" for a plain service
object to read one from), so it has no ambient channel — but a destination
`Route(transition:)` still applies to it exactly as it would to any other
call site. Only an ambient `.pageTransition` with nothing more specific set
is invisible to it.

## In-page transitions

Route changes are not the only case. `withViewTransition` wraps any block
of state writes so the resulting re-render also commits inside a view
transition — a tab switch, expanding a card, changing a filter, re-sorting a
list:

```swift
Button("Starred") {
    withViewTransition {
        selectedTab = .starred
    }
}
```

A block that writes no state arms nothing — there's no transition to skip
into if nothing changed. Nested calls save and restore the enclosing one;
two calls in the same turn resolve last-write-wins, same as any other
transaction in this codebase.

## `contentFit:` — when a group resizes

```swift
public func matchedTransition(id: String, in namespace: TransitionNamespace? = nil,
                              duration: CSSDuration? = nil,
                              timingFunction: TimingFunction? = nil,
                              contentFit: TransitionContentFit? = nil) -> Self
```

This is not decoration — read it before shipping any transition where a
named element's aspect ratio changes substantially between the two pages.

The browser sizes each snapshot in a matched group as `inline-size: 100%;
block-size: auto`, which **preserves that snapshot's own aspect ratio**. A
hero image that's 70vh tall on the home page and 160px tall on the search
results page is interpolating between two very different aspect ratios, so
mid-transition the snapshot shows underfilled or doubled content — text
repeats, images look stretched or letterboxed.

```swift
// Home: tall hero holding the search form.
Section {
    H1("Find a hotel")
    SearchForm().matchedTransition(id: "search-form")
}
.minHeight(.vh(70))
.matchedTransition(id: "hero", contentFit: TransitionContentFit.none)

// Search results: same id, much shorter.
Section {
    SearchForm().matchedTransition(id: "search-form")
}
.minHeight(.px(160))
.matchedTransition(id: "hero", contentFit: TransitionContentFit.none)
```

`.none` (the framework's own choice for this worked example) keeps content
at its natural size and clips instead of stretching it; `.cover` crops to
fill the group; `.fill` stretches; `nil` (the default) leaves the UA's own
behavior in place. There's no universally right default, which is why the
parameter exists rather than the framework picking one for you.

Note the spelled-out `TransitionContentFit.none` above: the parameter's type
is `TransitionContentFit?`, so a bare `.none` binds to `Optional.none` (nil,
"leave the UA's behavior in place") instead of the `.none` case, and no
`object-fit` rule is emitted at all — the exact failure this section exists
to prevent.

`contentFit:` is available on the `HTMLTag`/`Tag` surfaces of
`matchedTransition`; the `StyleProxy` form used inside `.style { }` has no
rule sink to register per-group tuning into, so it only takes `id:`/`in:`.

## Custom transitions with `Keyframes`

`.custom(old:new:)` takes two `Keyframes` values — one for the outgoing
root snapshot, one for the incoming one — and reuses the CSS `@keyframes`
machinery directly:

```swift
let fadeAndDrop = Keyframes("vt-fade-drop-out") {
    $0.to { $0.opacity(0); $0.style("translate", "0 12px") }
}
let fadeAndRise = Keyframes("vt-fade-drop-in") {
    $0.from { $0.opacity(0); $0.style("translate", "0 -12px") }
}

Router { /* … */ }.pageTransition(.custom(old: fadeAndDrop, new: fadeAndRise))
```

Both keyframes register and dedupe exactly like any other `Keyframes`
value; `.duration`/`.timingFunction`/`.respectsReducedMotion` still apply on
top.

## `.zoom` and the SwiftUI-parity spelling

`.zoom(sourceID:)` does not name anything by itself — it only tunes the
*group* for a card→page morph (a hook for an app-supplied
`::view-transition-group` rule, see below). It has no handle on the new
page's root, so naming the destination with the same id is still your job,
done the normal way with `.matchedTransition(id:)`:

```swift
struct HotelList: Tag {
    @Environment(\.navigate) var navigate
    let hotels: [Hotel]
    var body: some Tag {
        ForEach(hotels) { hotel in
            Button(onClick: {
                navigate("/hotel/\(hotel.id)", transition: .zoom(sourceID: "hotel-\(hotel.id)"))
            }) {
                HotelCard(hotel)
            }
            .matchedTransition(id: "hotel-\(hotel.id)")
        }
    }
}

// On the destination page's root — same id as the card above, or the
// browser has nothing to morph the source rect into.
struct HotelDetail: Tag {
    let hotel: Hotel
    var body: some Tag {
        DetailPage(hotel).matchedTransition(id: "hotel-\(hotel.id)")
    }
}
```

The SwiftUI-parity spelling is the same mechanism under a familiar name —
`matchedTransitionSource` on the card, `navigationTransition` on the
destination page's root, which does that naming for you:

```swift
let hotels = TransitionNamespace("hotel")

HotelCard(hotel)
    .matchedTransitionSource(id: "\(hotel.id)", in: hotels)

// on the destination page's root
DetailPage(hotel)
    .navigationTransition(.zoom(sourceID: "\(hotel.id)", in: hotels))
```

The framework emits `border-radius: inherit; overflow: clip` on this
group's `::view-transition-old`/`::view-transition-new` snapshots, but that
alone does not turn a rounded card into a rounded transition — `inherit`
pulls the value down from the *group* pseudo-element, and `border-radius`
isn't an inherited property, so with nothing else set it resolves to `0`.
To keep rounded corners through the zoom, add your own rule targeting the
group in a plain stylesheet (there's no typed modifier for a
`::view-transition-*` selector, since it targets a document-level
pseudo-element, not a `Tag`):

```css
::view-transition-group(hotel-42) { border-radius: 12px; }
```

## Caveats

Three ways a transition dies **silently** — the DOM still updates, nothing
animates, and nothing is logged:

- **Two rendered elements share a `view-transition-name`.** The browser
  rejects the transition outright. A `DEBUG`-only build emits a console
  warning after a committed render if it spots a duplicate — but only for
  elements that are actually in the tree at once (a mobile nav and a desktop
  nav both named `"logo"`, one hidden by a media query, is legal and
  invisible to this check).
- **The name is `root`.** The user-agent's own stylesheet already declares
  `:root { view-transition-name: root }`; reusing it collides with that and
  kills every transition in the app, not just the one that used it.
  `matchedTransition` rejects `root` (and any `-ua-`-prefixed name) and
  drops the declaration rather than emitting broken CSS.
- **An exit ghost from `.transition(...)` keeps the same name.** A `.transition`
  (the WAAPI enter/exit engine)'s exit animation keeps its element — and its
  `view-transition-name` — in the DOM for the duration of the exit. If the
  new page mounts an element with that same name, there are now two live
  elements sharing it, same failure as the first bullet. SwiftWUI suppresses
  both enter *and* exit transitions on any flush that commits inside a view
  transition specifically to avoid this.

A `view-transition-name` is never inert, transition or not: the element
permanently forms a stacking context, is flattened if a `transform-style:
preserve-3d` ancestor relied on it staying 3D, and forms a backdrop root (so
a descendant `backdrop-filter` samples inside the element, not the page
behind it). Applying `matchedTransition` can change how an element paints
even outside any transition.

Everything else worth knowing before shipping a transition:

- **A property animation and a group morph can run on the same element at
  once.** `withAnimation` isn't suppressed by a view transition — only enter/exit
  are — so it keeps playing inside the live `::view-transition-new`
  snapshot. Avoid combining the two on one element.
- **`withAnimation(completion:)` does not span a transition.** With
  enter/exit suppressed, a group whose only work was an enter/exit
  registers nothing and its completion fires on the next microtask, before
  anything is visible onscreen.
- **Effects run between the two captures.** `onAppear`/`onChange` fire
  after the old frame is captured and before the new one is. Measuring
  (`getBoundingClientRect`) or scrolling from inside one of these lands
  mid-transition.
- **Scroll isn't managed.** `Router` doesn't reset scroll position, and this
  feature doesn't change that. A scroll between the two captures misaligns
  the frames; a user scroll *during* the animation slides the live page
  under a stationary overlay. Suppress scrolling for the duration in app
  code, or accept it.
- **`position: fixed`/`sticky` cuts both ways.** A *named* fixed element is
  hoisted into the transition overlay and stops tracking the viewport for
  the duration. An *unnamed* fixed header is painted into the root snapshot
  and slides away with the page under `.slide()` — the more common surprise.
  Give a header its own name if it should stay put.
- **Ancestor clipping is lost.** A named element inside an `overflow:
  hidden` ancestor is captured un-clipped, so content that was half
  scrolled out of view can appear whole in the transition overlay.
- **`display: contents`, fragmented boxes, and `content-visibility: hidden`
  subtrees** can't be captured. The name simply has no effect for that one
  element — it doesn't fail the rest of the transition.
- **`Edge` (used by `.slide(edge:)`) is LTR-only** — most visible on a
  full-page slide.
- **A hidden tab skips the transition** (the platform throws
  `InvalidStateError`) but still runs the DOM update, so the page is
  correct when the tab becomes visible again — it just didn't animate.
- **A second navigation mid-animation aborts the first,** rather than
  queueing behind it — the same feel as clicking a second native browser
  link before the first page finishes loading.
- **Reduced motion respects an OS setting read once per transition**, not
  continuously: `.respectsReducedMotion(true)` (the default) skips arming
  a transition entirely when the setting is already on, and a kill switch
  handles the setting flipping mid-transition too, falling back to an
  instant swap rather than the UA's default cross-fade.
- **A media-query flip during the capture window** (e.g. a resize crossing
  a breakpoint) can restart a running CSS `@keyframes` animation elsewhere
  on the page, since the whole managed stylesheet gets replaced between the
  two captures.
- **SSG and hydration.** `view-transition-name` shows up as an ordinary
  inline style in prerendered HTML — harmless, and preserved through
  hydration. Builds (`swiftwui build`/`ssg`) disable the feature outright
  (`_disableViewTransitions`), so no static build ever serializes a page
  mid-transition. Separately, the hydration SPI that already suppressed enter
  animations on the very first live flush after adopting prerendered HTML now
  also suppresses exit animations on that same flush — see the CHANGELOG.

## Fallback for unsupporting browsers

Browsers without `document.startViewTransition` get a bounded FLIP
("First, Last, Invert, Play") fallback instead of nothing: every tracked
named element's rect is measured before the DOM update and after, and the
delta is played back with `element.animate` (`translate`/`scale`).

It is deliberately partial, not a general animation engine:

- The outgoing page disappears at once — only named elements travel.
  There's no "old frame" to fade out the way native view transitions provide
  one for free.
- A traveling element stays in normal document flow for the duration, so an
  ancestor `overflow: hidden` still clips it and a higher-stacked sibling
  can paint over it — a bug class that exists *only* in the fallback; native
  view transitions paint in a top layer above everything.
- Size changes are faked with CSS `scale`, which distorts text, border
  widths, `border-radius`, and shadows rather than reflowing them.
- **A named element nested inside another named element rides its
  ancestor's morph instead of animating independently.** CSS transforms
  compound down a subtree, so giving both elements their own `scale` would
  double-transform the inner one; the fallback skips the descendant and lets
  it travel along with its ancestor. Native view transitions avoid this by
  flattening every name into its own sibling layer, which a flat FLIP has no
  way to reproduce.
- `translate`/`scale` are reserved for the duration of the animation, so a
  `Keyframes` or `withAnimation` animation on those two properties gets
  overridden while it plays — use `transform` instead if it needs to survive
  a fallback transition.
- A `.custom(old:new:)` transition's `@keyframes` never apply here — there
  are no `::view-transition-*` pseudo-elements to attach them to — so its
  real timing only shows up on the native path; the fallback always uses a
  plain FLIP animation of the matched duration instead.
- `.zoom(sourceID:)` degrades to a plain FLIP of the source element's rect.
- Reduced motion never reaches the fallback at all: when the setting
  applies, no transition is armed in the first place.

Append `?swui-vt=flip` to any URL to force the fallback in a browser that
does support the native API — the only practical way to exercise this path
by hand during development.
