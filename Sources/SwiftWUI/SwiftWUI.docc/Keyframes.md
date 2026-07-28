# Keyframes

A CSS `@keyframes` block as a Swift value — built with a stops DSL, attached
where you use it, and gated on `prefers-reduced-motion` by default.

## Overview

``Keyframes`` describes motion that runs on its own clock: a spinner, a
pulsing badge, a skeleton shimmer, a marquee. That is the class of animation
with no "before" and "after" to interpolate between, and the one the WAAPI
animation engine (`withAnimation` / `.animation(_:value:)`) deliberately does
not cover.

The value carries nothing but its stops. Nothing is emitted until some
`.animation(_:duration:…)` call references it, and what is emitted goes
through the normal stylesheet path — so SSG output, hydration, and the live
DOM all get the same CSS out of one resolve. There is no `App.keyframes`
array and no registration step; a `Keyframes` value that no `.animation` call
references produces no CSS at all.

### Building the value

`Keyframes(_:_:)` takes an optional name and a closure that collects stops.
`from`/`to` emit the CSS keywords; `at(_:)` takes a percentage:

```swift
let spin = Keyframes("spin") {
    $0.from { $0.transform(.rotate(.deg(0))) }
    $0.to { $0.transform(.rotate(.deg(360))) }
}

let pulse = Keyframes("pulse") {
    $0.at(0) { $0.opacity(1) }
    $0.at(50) { $0.opacity(0.4) }
    $0.at(100) { $0.opacity(1) }
}
```

Each stop body is a `StyleProxy` — the same builder `.style { }` uses — so
every typed declaration modifier is available inside a stop, plus the
`$0.style("property", "value")` fallback for anything untyped. Stops keep the
order you wrote them in (CSS accepts any order), and `at(_:)` clamps its
argument to `0...100`, so `at(180)` is `100%` and `at(-30)` is `0%`.

Two things a stop can't do. Nested blocks — `$0.hover { }`, `$0.media(_:_:)`,
`$0.container(_:name:_:)` — aren't valid CSS inside `@keyframes` and are
dropped: an assertion in debug builds, silently in release. And a stop whose
body adds no declarations is skipped entirely, so
`Keyframes("x") { $0.from { _ in } }` is an empty value that emits nothing.

`from`/`to` and `at(0)`/`at(100)` animate identically but are not the same
value: the identity hash covers the serialized text, so the two spellings
register as two separate blocks.

### Attaching it

`.animation(_:duration:…)` ships on all three style surfaces — `HTMLTag`,
`Tag`, and a chain already returning `_StyledTag`:

```swift
struct Loading: Tag {
    var body: some Tag {
        Div {
            // HTMLTag
            Div().animation(spin, duration: .s(0.8), timingFunction: .linear,
                            iterations: .infinite)
            // Tag
            Badge().animation(pulse, duration: .s(2), iterations: .infinite)
            // _StyledTag — a component with another modifier already applied
            Badge().opacity(0.8).animation(pulse, duration: .s(2), iterations: .infinite)
        }
    }
}
```

The full parameter list, identical on all three:

```swift
func animation(_ keyframes: Keyframes, duration: CSSDuration,
               timingFunction: TimingFunction = .ease,
               delay: CSSDuration = .ms(0),
               iterations: AnimationIterations = .count(1),
               direction: AnimationDirection = .normal,
               fillMode: AnimationFillMode = .none,
               respectsReducedMotion: Bool = true) -> …
```

`duration` is the only argument you have to pass. Note that `iterations`
defaults to `.count(1)` — a loop needs `.infinite` spelled out:

```swift
struct Spinner: Tag {
    var body: some Tag {
        Div()
            .width(.px(20))
            .height(.px(20))
            .borderRadius(.percent(50))
            .border(.px(2), .solid, .current)
            .animation(spin, duration: .s(0.8), timingFunction: .linear,
                       iterations: .infinite)
    }
}
```

### The emitted name

The CSS name is always `<your name>-<hash>` — FNV-1a over the serialized
stops, base 36 — or `swui-kf-<hash>` when you pass no name:

```css
@keyframes spin-2zs8ngyuefeox { from { transform: rotate(0deg) } to { transform: rotate(360deg) } }
@media (prefers-reduced-motion: no-preference) {
  .swui-sgb8eh8ge7ix { animation: spin-2zs8ngyuefeox 0.8s linear 0ms infinite normal none }
}
```

The suffix buys two things. Identical stops hash identically, so one
`Keyframes` value used on twenty elements registers exactly one block.
And `@keyframes` is last-wins *by name*: two different values both named
`"fade"` would otherwise contend for a single CSS name, with the winner
decided by the style registry's sort order rather than by anything you wrote.
With the hash they are two blocks that cannot overwrite each other. The hash
is computed from the text, so it is stable across builds and SSG output stays
deterministic.

The name is validated as a CSS ident; anything else is dropped and the value
falls back to `swui-kf-<hash>`. That validation is the injection guard — the
name lands raw in an at-rule prelude with no downstream sanitizing step — so
it holds in release builds too, silently, rather than trapping. One gap worth
knowing: the validator accepts a leading hyphen, so `Keyframes("-3d")` passes
here and is then rejected by the browser as an invalid ident, taking the whole
at-rule with it and leaving an animation that never runs. Start names with a
letter.

### Reduced motion

`.animation` does not write an inline declaration. It registers a class rule
wrapped in `@media (prefers-reduced-motion: no-preference)`. The condition
reads `no-preference` rather than `reduce` because CSS can only *enable*
under a condition, never disable — "animate when the user has expressed no
preference" is the only way to spell this. The `@keyframes` definition itself
is never wrapped: an unreferenced definition is inert, and wrapping it would
break a hand-written `.style("animation", …)` naming the same block.

The gate is pure CSS. It costs no environment read and no re-render, and it
follows the OS setting changing without a reload. It is independent of the
WAAPI engine's own reduce-motion handling, which reads
`accessibilityReduceMotion` from `EnvironmentSignals` and gates itself.

`respectsReducedMotion: false` emits the rule unwrapped. That is defensible
when the animation carries information rather than decoration — a spinner
that is the only signal work is in flight, an indeterminate progress bar with
no numeric equivalent. It is not defensible for an entrance flourish, a hover
pulse, or a background sweep. When you do opt out, keep the motion small and
away from large-area movement, which is what triggers vestibular symptoms.

## Keyframes or `.animation(_:value:)`

Two modifiers named `animation` ship in the framework. They are not
alternatives to each other:

- ``Keyframes`` with `.animation(_:duration:…)` drives CSS. Use it for
  motion that **loops or runs independent of state** — spinners, skeletons,
  pulses, marquees. The block starts when the element mounts and runs on the
  browser's clock; no Swift code is involved after the first render.
- `.animation(_:value:)` and `withAnimation` drive the Web Animations API
  engine. Use them for motion that **interpolates between two states** —
  a panel expanding, a color changing on toggle, a row settling into a new
  position. Nothing happens until `value` changes.

```swift
struct Panel: Tag {
    @State private var expanded = false
    var body: some Tag {
        Div {
            Button("Details") { expanded.toggle() }
            Div { Text("…") }.opacity(expanded ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.2), value: expanded)
    }
}
```

The two overloads differ in the type of their first argument (`Keyframes` vs
`Animation?`) and in every label after it, so a call site never resolves
ambiguously between them.

The infinite loop is the sharpest edge of the split: the WAAPI engine has no
concept of a declarative forever-animation, and giving it one would mean
keeping a live JS animation object per spinner for the lifetime of the page.
The state transition is the mirror image: a `@keyframes` block has no access
to the previous value, so "animate from whatever it was to whatever it is
now" isn't expressible in one.

## Caveats

### A running CSS animation swallows state-driven changes to the same property

CSS animations sit above normal author declarations in the cascade —
including inline styles. The WAAPI engine writes the settled value inline
first and then plays the animation with no fill, so while a keyframe
animation is running on the same property, both the interpolated value and
the settled inline value are outranked. A `withAnimation` opacity change on
an element already running an opacity loop produces nothing visible, and it
does not recover when the transition finishes: the CSS animation keeps
winning for as long as it runs.

Don't drive one property from both engines. Pick one, or split them across
elements — the loop on a wrapper, the state transition on the child.

### `fillMode: .forwards` plus the reduced-motion gate hides content

The "fade in and stay" idiom is a base style of `opacity: 0`, a keyframes
block ending at `opacity: 1`, and `fillMode: .forwards` to hold the last
frame. Under the default gate, a reduce-motion user never receives that rule
at all — the element keeps its base style, which for this idiom is invisible.
The animation exists to reveal content, and its absence hides it, from exactly
the users the gate is there to protect.

Write the resting state as the base style and let the keyframes describe the
departure from it, so the un-animated result is the visible one. Where that
genuinely isn't possible, `respectsReducedMotion: false` on a short,
low-movement animation beats invisible content. Either way, load the page
with reduce-motion turned on before shipping it.

### An inline `.style("animation", …)` wins over the modifier

The rule lands in a generated class, with the same specificity as every other
generated rule, so a hand-written inline `.style("animation", "…")` on the
same element outranks it — and, being inline, it is also outside the
reduced-motion gate. This is the framework-wide inline-beats-generated-class
behavior, not something specific to this modifier, but it is easy to trip when
migrating off the pre-`Keyframes` pattern of an inline `animation` shorthand
plus a hand-injected block.

### Every `.animation` call registers a rule

Unlike most typed style modifiers, `.animation` registers its rule
unconditionally, and the style registry is monotonic — entries are never
evicted. Timing arguments computed from state (`duration: .ms(Double(step) * 100)`)
therefore add a permanent registry entry for every distinct value they take.
Keep the timing arguments constant per call site; state-varying timing belongs
to the WAAPI engine.

### See also

<doc:ViewTransitions> — `.custom(old:new:)` builds a page transition out of
two `Keyframes` values, which register and dedupe exactly like any other.
