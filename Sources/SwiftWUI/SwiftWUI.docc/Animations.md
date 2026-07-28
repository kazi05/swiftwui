# Animations

Property animations on the Web Animations API — a transaction that scopes
every state write inside it, a value-scoped implicit animation, and
mount/unmount transitions with a real exit phase.

## Overview

SwiftWUI never emits a standing CSS `transition:` declaration. Every
animation is an explicit `element.animate` call issued during the same flush
that changed the value, one call per changed style property, with no
per-frame traffic across the JS bridge. The consequence to keep in mind is
the useful one: a property animates *because you asked for it on that
write*, so an unrelated later write to the same property is instant.

The decision layer — what changed, what animates, with what timing — lives
in the renderer-agnostic core and is exercised natively through `MockBackend`;
`DOMBackend` only turns a resolved request into a WAAPI call. Outside a live
runtime (SSG, native tests) the animation path is inert: `HTMLRenderer`
writes final values and nothing else.

Three entry points, ordered by how tightly each one scopes:

- ``withAnimation(_:_:)`` — every state write made inside the closure
- `.animation(_:value:)` — everything under a subtree, but only on the pass
  where `value` changed
- `.transition(_:)` — one element's arrival and departure

## Animating a state write

`withAnimation` installs an ambient ``Transaction`` for the dynamic extent of
its closure. Every state write the closure makes — directly, or through
anything it calls — is tagged with that animation, and the coalesced flush
that follows animates the style properties those writes changed.

```swift
struct Panel: Tag {
    @State private var expanded = false
    var body: some Tag {
        Div {
            Div { "Details" }
                .opacity(expanded ? 1 : 0)
                .scaleEffect(expanded ? 1 : 0.96)
            Button(expanded ? "Collapse" : "Expand") {
                withAnimation(.snappy) { expanded.toggle() }
            }
        }
    }
}
```

Two `withAnimation` blocks in one event handler produce two transactions in
the same coalesced flush, each animating its own writes with its own timing.
Nested calls save and restore, so the innermost block wins for writes made
inside it.

The scope is dynamic extent, not lexical. The closure is synchronous, so a
write made after an `await` — inside a `Task { }` started in the closure —
runs long after `withAnimation` restored the previous ambient, and is not
animated. Await first, then wrap only the write:

```swift
struct Feed: Tag {
    @State private var items: [String] = []
    var body: some Tag {
        Div {
            Ul { ForEach(items, id: \.self) { item in Li { Text(item) } } }
            Button("Load") {
                Task {
                    let loaded = await fetchItems()
                    withAnimation(.smooth) { items = loaded }
                }
            }
        }
    }
}
```

Calling `withAnimation` during `body` evaluation is illegal for the same
reason any state write during body evaluation is: the write routes through
`Runtime.markDirty`, whose "State write during body evaluation" assertion
traps it.

### Completion

The `completion:` overload fires once every animation this transaction
started has settled:

```swift
struct SaveButton: Tag {
    @State private var saved = false
    var body: some Tag {
        Div {
            Span { "✓ Saved" }
                .opacity(saved ? 1 : 0)
                .animation(.smooth, value: saved)
            Button("Save") {
                withAnimation(.smooth, completion: { saved = false }) {
                    saved = true
                }
            }
        }
    }
}
```

Two edges are worth knowing before you build a sequence on top of it. A
transaction that started no animations at all (a text-only update, or
reduced motion) fires `completion` on the next microtask after the flush
rather than never firing. And an animation carrying `.repeatForever` is
excluded from the group — its WAAPI `finished` never resolves, so it counts
as settled immediately; a completion waiting on an infinite animation would
otherwise be a permanent leak.

## Scoping to one value

`.animation(_:value:)` overrides the ambient transaction for its subtree,
but only on a pass where `value` differs from the value it saw last time:

```swift
Div { "●" }
    .opacity(pulsed ? 1 : 0.3)
    .scaleEffect(pulsed ? 1.2 : 1.0)
    .animation(.spring(duration: 0.4, bounce: 0.3), value: pulsed)
```

Nearest wrapper wins, and the override lives for exactly one pass — it is
never replayed. That is the whole point of requiring `value`: a later pass
that dirties something inside this subtree without touching `pulsed` gets no
animation, which is what a valueless `.animation` would get wrong. Passing
`nil` for the animation with a changed `value` suppresses animation for the
subtree, including an ambient `withAnimation` from above.

First sighting of a value stores it and reports no change, so a fresh mount
never animates through this wrapper.

**`.animation(_:value:)` drives enter transitions but not removal
transitions.** A removed identity no longer resolves under the wrapper, so
the wrapper cannot supply the exit's timing. Drive removals with
`withAnimation`, or give the transition its own `.animation(_:)`.

## Curves and springs

```swift
Animation.linear(duration: 0.2)
Animation.easeIn(duration: 0.2)
Animation.easeOut(duration: 0.2)
Animation.easeInOut(duration: 0.25)
Animation.timingCurve(0.2, 0, 0, 1, duration: 0.5)
Animation.spring(duration: 0.4, bounce: 0.3)
```

Springs are solved Swift-side: a closed-form damped oscillator sampled into a
CSS `linear(…)` easing string, so the browser plays a real spring curve with
no per-frame bridge calls. `bounce` follows SwiftUI's convention — `0` is
critically damped, positive overshoots, negative is overdamped — and is
clamped to `[-1, 1]`. Three presets and a default:

```swift
Animation.smooth   // spring(duration: 0.55, bounce: 0)
Animation.snappy   // spring(duration: 0.4,  bounce: 0.15)
Animation.bouncy   // spring(duration: 0.5,  bounce: 0.3)
Animation.default  // == .smooth, and the default argument of withAnimation
```

**A spring's `duration` is a perceptual parameter, not a wall-clock length.**
It sets the oscillator's natural frequency; the animation actually runs until
the curve settles inside a 0.1% band, which for `bounce > 0` is longer than
`duration` (capped at 5×). `.spring(duration: 0.4, bounce: 0.3)` does not
finish in 400 ms, and a `completion` attached to it fires when the spring
settles. Use `.linear`/`.easeInOut` when you need an exact length.

Four modifiers return a new value, so they chain:

```swift
Animation.easeInOut(duration: 0.25).delay(0.1)
Animation.linear(duration: 1).repeatForever(autoreverses: true)
Animation.spring(duration: 0.5).speed(1.5)          // 1.5× faster
Animation.linear(duration: 0.2).repeatCount(3, autoreverses: true)
```

`.speed(_:)` divides both duration and delay by its factor, so `> 1` is
faster. A non-finite or non-positive factor is coerced to `1` at resolve time
rather than trapping: `element.animate` throws on an invalid number, and a
throw across the JS bridge is a wasm trap, so an arithmetic slip degrades to
an unscaled animation instead of killing the runtime.

## Transform channels

`.offset`, `.scaleEffect`, and `.rotationEffect` each write a *different* CSS
property — `translate`, `scale`, and `rotate` — not three functions crammed
into one `transform` string:

```swift
Div { "●" }
    .offset(y: lifted ? -8 : 0)
    .rotationEffect(spun ? 180 : 0)
    .scaleEffect(pressed ? 0.94 : 1)
```

Because the engine diffs and animates per property, each channel gets its own
animation, its own curve, and its own retarget. A drag can move the element
while a separate spring is still settling its scale, and neither snaps the
other — which a shared `transform` string cannot express, since every write
would clobber the whole value.

Two constraints follow from CSS itself:

- **Composition order is fixed**: `translate`, then `rotate`, then `scale`.
  SwiftUI's "modifier order changes the result" stacking needs nested
  wrapper elements here.
- **One `transform-origin` per element.** `anchor:` only emits
  `transform-origin` when it differs from `.center`, so combining
  `.scaleEffect(_:anchor:)` and `.rotationEffect(_:anchor:)` with two
  *different* non-center anchors on the same element is unsupported — the
  last one written wins for both. Wrap in an extra element if you need that.

Bare `transform` has no typed modifier and stays free for a future FLIP
implementation; `.style("transform", …)` still works as an escape hatch, but
a value written that way is one property and animates as one channel.

## Mount and unmount transitions

``AnyTransition`` describes the off-stage styling of an element: enter
animates from the insertion-active declarations to the element's normal
presentation, exit animates from the current presentation to the
removal-active ones.

```swift
struct Banner: Tag {
    @State private var show = false
    var body: some Tag {
        Div {
            Button(show ? "Hide" : "Show") {
                withAnimation(.snappy) { show.toggle() }
            }
            if show {
                P { "Saved to your library." }
                    .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
    }
}
```

The built-ins are `.identity`, `.opacity`, `.scale(_:anchor:)`,
`.offset(x:y:)`, `.move(edge:)`, `.slide`, and the
`.active([StyleDeclaration])` primitive that all of them are built from.
`.combined(with:)` unions both phase lists; `.asymmetric(insertion:removal:)`
takes the insertion half from one and the removal half from the other.

**A transition with no animation to drive it does nothing.** Timing is
resolved per element in this order: the transition's own `.animation(_:)`,
then the transaction in effect for that element, then the pass's default
transaction. If all three are absent — a bare `show.toggle()` in a click
handler, with no `withAnimation` around it — the element mounts and unmounts
instantly, exactly as it did before you added `.transition`. This matches
SwiftUI, and it is the single most common reason a transition "doesn't fire".

A transition driven by its **own** `.animation(_:)` never joins a
`withAnimation` completion group — it carries no transaction, so nothing
registers against the group:

```swift
P { "Undo" }
    .transition(.move(edge: .bottom)
        .animation(.spring(duration: 0.45, bounce: 0.2)))
```

`.asymmetric` drops both halves' animation overrides. It reads only
`insertion.insertionActive` and `removal.removalActive`, and returns a value
with `animation: nil` — so an `.animation(.snappy)` attached to the
`insertion:` argument is silently lost. Attach the override to the composed
result instead:

```swift
P { "Undo" }
    .transition(.asymmetric(insertion: .scale(0.9).combined(with: .opacity),
                            removal: .opacity)
                .animation(.snappy))
```

`.combined(with:)` keeps the receiver's animation, falling back to the
other's.

### The exit guarantee, and what dies first

An element with a removal transition is not removed when its branch goes
away. The applier keeps the host as a *ghost*: state, listeners, and effects
are swept immediately (`onDisappear` runs at exit start), the host is marked
`inert` so it cannot be clicked or focused, and only when the removal
animations settle is it actually removed from the DOM. A ghost is a visual
corpse — it will not respond to input while it fades.

Two structural rules around it:

- **Outermost transition wins.** The exit walk stops descending as soon as it
  finds an element with a removal transition, so nested `.transition`s under
  a transitioning ancestor don't play their own exits.
- **No z-index management.** During a same-position swap the old ghost lives
  as a sibling *after* the new element in DOM order. If they overlap and the
  stacking is wrong, set it yourself with `.zIndex(_:)` — the framework does
  not do this for you (SwiftUI requires the same).

A cold mount never plays enter transitions, and neither does the first pass
after hydration adoption. Initial appearance is not animated; there is no
`appear` opt-in.

Note the rename that shipped with this feature: the CSS shorthand modifier
formerly called `.transition(String)` is now `.cssTransition(String)` on both
`Tag` and `HTMLTag`. `.transition(_:)` refers exclusively to `AnyTransition`.
`StyleProxy.transition(String)` inside `.hover { }` / `.media { }` blocks
keeps its old name — no `AnyTransition` competes for it in that context.

## Interruption and retargeting

Running animations are tracked per `(element identity, property)`, which is
what makes a mid-flight change well-defined instead of a stack of fighting
animations.

- **A new write to a property already animating** retargets. In additive mode
  — both values parse as matching number lists, like `"10px"` or
  `"10px 20px"` — the new animation layers on and the old one decays
  harmlessly on top of it. In replace mode (colors, keywords, mismatched
  shapes) the old animation is cancelled first.
- **Removal during enter** cancels the in-flight enter animations under that
  subtree, so the exit starts from the presentation the element actually has
  at that instant rather than snapping to its final value first.
- **Re-insertion during exit** adopts the ghost back: exit animations are
  cancelled, `inert` is dropped, the incoming node re-diffs against the
  ghost's retained tree, and the enter path replays from the current
  presentation. No duplicate element, no snap.

**Ghost adoption does not restore `@State`.** State was swept at exit start,
so an adopted subtree comes back with fresh initial values. SwiftUI provides
no state continuity across removal either; if a value has to survive a
toggle, it belongs in the parent, not in the element being removed.

One adoption case falls back: a ghost created by a same-position identity
swap has no retained old node to re-diff against, so re-insertion during its
exit force-finishes the ghost and mounts fresh instead of adopting.

## Reduced motion

`\.accessibilityReduceMotion` mirrors the `prefers-reduced-motion: reduce`
media query, read once before the first render pass and kept live by a change
listener — so a mid-session toggle in OS settings takes effect on the next
flush, without a reload.

```swift
struct MotionNote: Tag {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some Tag {
        Text(reduceMotion ? "Motion reduced" : "Full motion")
    }
}
```

When it is on, the engine gates itself — you do not have to branch on the
value to get correct behavior:

- Style changes write their final value and issue **no** `animate` call.
- Enter and exit transitions are skipped entirely; a removed element leaves
  the DOM synchronously, with no ghost.
- Completion handlers still fire, with identical semantics, so a sequence
  built on `withAnimation(completion:)` does not stall.

Like the other environment signals, it is reactive **only when read inside a
component's `body`** — a read in a `.task` closure or an event handler is not
tracked and will not re-render anything. It is `false` outside a live runtime
(native, SSG), which is what makes prerendered output identical for
reduced-motion and full-motion visitors.

The gate covers the WAAPI engine, and `.animation(_:duration:…)` applies the
same policy to CSS `Keyframes`. It does **not** cover a hand-written
`.style("animation", …)` — that string needs its own
`@media (prefers-reduced-motion: no-preference)` wrapper.

## What never animates

Worth stating plainly, because each of these looks like a bug the first time:

- **A property with no previous value.** A style property appearing for the
  first time on an element applies instantly — there is nothing to
  interpolate from.
- **A removed property.** `removeStyleProperty` reverts to a computed or
  inherited default the engine cannot know, so it applies instantly.
- **Attributes, text, and structure.** Only style properties animate; text
  content and attribute changes are instant.
- **Non-interpolable values are the browser's business.** The engine requests
  an animation for any changed property and lets WAAPI decide; a
  non-interpolable pair follows the discrete rule and swaps at 50% of the
  duration rather than animating. `height: auto → 200px` snaps mid-flight.
  The model value is written to final first, so the end state is always
  correct regardless.

For animating *across* a route change — where there is no live element to
interpolate because the old subtree is gone — see <doc:ViewTransitions>,
which is orthogonal to everything here.
