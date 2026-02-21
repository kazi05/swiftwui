# Animations

SwiftWUI provides a declarative animation system that maps SwiftUI-style APIs to CSS transitions and the Web Animations API. Animations are expressed in Swift and compiled to efficient CSS at render time.

## Table of Contents

- [withAnimation](#withanimation)
- [.animation() Modifier](#animation-modifier)
- [Animation Presets](#animation-presets)
- [Animation Modifiers](#animation-modifiers)
- [TimingFunction](#timingfunction)
- [TagTransition (Enter/Exit)](#tagtransition-enterexit)
- [.transition() Modifier](#transition-modifier)
- [Web Animations API (Advanced)](#web-animations-api-advanced)
- [How It Works](#how-it-works)

---

## withAnimation

The `withAnimation` function wraps a state mutation so that all visual changes caused by that mutation are animated. This is the primary way to trigger one-off animations in response to user actions.

```swift
Button(onclick: {
    withAnimation(.easeInOut(duration: 0.3)) {
        isVisible.toggle()
    }
}) { Text("Toggle") }
```

You can omit the animation parameter to use the default (0.3s ease-in-out):

```swift
Button(onclick: {
    withAnimation {
        count += 1
    }
}) { Text("Increment") }
```

### Function Signature

```swift
public func withAnimation(
    _ animation: Animation = .default,
    _ body: () -> Void
)
```

### How withAnimation Works

The execution flow follows these steps:

1. `withAnimation` sets `AnimationContext.current` to the provided animation.
2. The `body` closure runs, mutating `@State` or `@Observable` properties.
3. The state mutation triggers an observation change callback.
4. The change callback schedules a re-render via `queueMicrotask` (deferred so the new value is available).
5. When the render cycle runs, it captures `AnimationContext.current` and clears it.
6. `DOMRenderer.update()` receives the animation and passes it to patch application.
7. For every `updateStyles` patch, the renderer sets a CSS `transition` property on the affected element before applying the new style values.
8. The browser smoothly interpolates between the old and new CSS values.

This means only style properties that actually change during that render cycle are animated. Attributes, classes, and structural DOM changes are applied immediately.

---

## .animation() Modifier

The `.animation()` modifier sets a persistent CSS `transition` on an element. Any style change on that element -- whether triggered by `withAnimation` or by a normal re-render -- will be animated.

```swift
Div { content }
    .animation(.spring)
    .opacity(isExpanded ? 1.0 : 0.0)
```

This is equivalent to setting `transition: all 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275)` in CSS.

### When to Use .animation() vs withAnimation

| Scenario | Recommended Approach |
|---|---|
| Animate a specific user action | `withAnimation { ... }` |
| Always animate style changes on an element | `.animation(.easeInOut(duration: 0.3))` |
| Different animations for different actions | `withAnimation` with different presets |
| Hover/focus CSS-driven transitions | `.animation()` on the element |

### Chaining with Style Modifiers

The `.animation()` modifier can be chained with any style modifier. Place it before the style modifiers that should animate:

```swift
Div { Text("Card") }
    .animation(.easeInOut(duration: 0.2))
    .opacity(isHovered ? 1.0 : 0.8)
    .transform(isHovered ? "scale(1.05)" : "scale(1.0)")
    .backgroundColor(isActive ? .hex("#007AFF") : .hex("#CCCCCC"))
```

---

## Animation Presets

SwiftWUI provides several built-in animation presets that cover common use cases.

### .default

Standard animation suitable for most UI transitions.

```swift
withAnimation(.default) { /* ... */ }
```

- Duration: 0.3s
- Timing: ease-in-out

### .linear(duration:)

Constant speed from start to finish. Useful for progress bars and loading indicators.

```swift
.animation(.linear(duration: 1.0))
```

### .easeIn(duration:)

Starts slow and accelerates. Good for elements entering the viewport.

```swift
.animation(.easeIn(duration: 0.25))
```

### .easeOut(duration:)

Starts fast and decelerates. Natural for elements coming to rest.

```swift
.animation(.easeOut(duration: 0.25))
```

### .easeInOut(duration:)

Slow start and end with faster middle. The most natural-feeling curve for general UI.

```swift
withAnimation(.easeInOut(duration: 0.3)) {
    isExpanded.toggle()
}
```

### .spring

Simulates a spring effect using a CSS cubic-bezier approximation. Adds a slight overshoot for a lively, physical feel.

```swift
.animation(.spring)
```

- Duration: 0.5s
- Timing: `cubic-bezier(0.175, 0.885, 0.32, 1.275)`

### .bouncy

A more dramatic spring with stronger overshoot. Use for playful or attention-grabbing interactions.

```swift
.animation(.bouncy)
```

- Duration: 0.6s
- Timing: `cubic-bezier(0.34, 1.56, 0.64, 1)`

### .custom(duration:timingFunction:delay:)

Full control over all animation parameters.

```swift
let wobble = Animation.custom(
    duration: 0.4,
    timingFunction: .cubicBezier(0.25, 0.8, 0.25, 1.2),
    delay: 0.1
)

withAnimation(wobble) {
    isShaking.toggle()
}
```

---

## Animation Modifiers

Animation presets can be further customised with modifier methods. Each modifier returns a new `Animation` value (animations are value types).

### .delay(_:)

Adds a delay before the animation begins. The parameter is in seconds.

```swift
withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
    isVisible = true
}
```

This produces: `transition: all 0.3s ease-in-out 0.2s`

### .speed(_:)

Adjusts the animation speed by dividing the duration by the multiplier. A value of `2.0` makes the animation twice as fast; `0.5` makes it twice as slow.

```swift
withAnimation(.spring.speed(2.0)) {
    isExpanded.toggle()
}
```

With `.spring` (0.5s base), `.speed(2.0)` yields a 0.25s duration.

### Chaining Modifiers

Modifiers can be chained:

```swift
let staggered = Animation.easeOut(duration: 0.4)
    .delay(0.1)
    .speed(1.5)
// Result: duration = 0.4 / 1.5 = 0.267s, delay = 0.1s, timing = ease-out
```

---

## TimingFunction

The `TimingFunction` enum maps directly to CSS timing functions. It is used as the `timingFunction` parameter of `Animation`.

### Predefined Functions

| SwiftWUI | CSS Output |
|---|---|
| `.linear` | `linear` |
| `.ease` | `ease` |
| `.easeIn` | `ease-in` |
| `.easeOut` | `ease-out` |
| `.easeInOut` | `ease-in-out` |

### .cubicBezier(x1, y1, x2, y2)

Define a custom cubic bezier curve. The four parameters correspond to the two control points of the curve.

```swift
let customTiming = TimingFunction.cubicBezier(0.68, -0.55, 0.27, 1.55)

let animation = Animation.custom(
    duration: 0.5,
    timingFunction: customTiming
)
```

CSS output: `cubic-bezier(0.68, -0.55, 0.27, 1.55)`

### .steps(count, position)

Creates a step function that divides the animation into a fixed number of equal intervals. Useful for sprite animations or typewriter effects.

```swift
let typewriter = Animation.custom(
    duration: 2.0,
    timingFunction: .steps(20, .end)
)
```

The `StepPosition` parameter controls when each step change occurs:

| Position | Behaviour |
|---|---|
| `.start` | Change occurs at the start of each interval |
| `.end` | Change occurs at the end of each interval |

CSS output: `steps(20, end)`

---

## TagTransition (Enter/Exit)

`TagTransition` defines how elements animate when they appear in or disappear from the DOM. Each transition specifies an `enterFrom` state (initial styles before the element animates in) and an `exitTo` state (target styles before the element is removed).

```swift
if isVisible {
    Div { Text("Hello") }
        .transition(.opacity)
}
```

### Transition Presets

#### .opacity

Fades the element in and out.

```swift
.transition(.opacity)
```

- Enter from: `opacity: 0`
- Exit to: `opacity: 0`

#### .scale

Scales the element up on entry and down on exit, combined with a fade.

```swift
.transition(.scale)
```

- Enter from: `transform: scale(0.8); opacity: 0`
- Exit to: `transform: scale(0.8); opacity: 0`

#### .slide

Slides in from the left and out to the right.

```swift
.transition(.slide)
```

- Enter from: `transform: translateX(-100%); opacity: 0`
- Exit to: `transform: translateX(100%); opacity: 0`

#### .moveUp

Slides upward from below on entry.

```swift
.transition(.moveUp)
```

- Enter from: `transform: translateY(20px); opacity: 0`
- Exit to: `transform: translateY(-20px); opacity: 0`

#### .moveDown

Slides downward from above on entry.

```swift
.transition(.moveDown)
```

- Enter from: `transform: translateY(-20px); opacity: 0`
- Exit to: `transform: translateY(20px); opacity: 0`

### Combining Transitions

Use `.combined(with:)` to merge two transitions. The CSS properties from both are applied together.

```swift
.transition(.opacity.combined(with: .scale))
```

This combines the opacity fade with the scale transform, producing an element that fades and scales simultaneously.

When combining, the animation configuration from the first transition is used. If both transitions define the same CSS property, the second transition's value takes precedence.

### Custom Animation for Transitions

Override the default animation on any transition with `.animation()`:

```swift
.transition(.opacity.animation(.spring))
```

```swift
.transition(
    .scale
        .animation(.easeOut(duration: 0.5).delay(0.1))
)
```

### Building Custom Transitions

Create entirely custom transitions by specifying `enterFrom` and `exitTo` style dictionaries:

```swift
let flipIn = TagTransition(
    enterFrom: [
        "transform": "rotateY(90deg)",
        "opacity": "0"
    ],
    exitTo: [
        "transform": "rotateY(-90deg)",
        "opacity": "0"
    ],
    animation: .easeInOut(duration: 0.6)
)

if isVisible {
    Div { Text("Card") }
        .transition(flipIn)
}
```

---

## .transition() Modifier

The `.transition()` modifier on a `Tag` applies the transition's animation as a CSS `transition` property. This sets up the element so that any future style change is animated according to the transition's configuration.

```swift
Div { content }
    .transition(.scale)
```

This is functionally equivalent to:

```swift
Div { content }
    .animation(.default)  // .default because .scale uses Animation.default
```

The `.transition()` modifier is most useful when you want to express intent clearly -- the element is expected to appear and disappear rather than merely change styles.

---

## Web Animations API (Advanced)

For animations that go beyond CSS transitions -- such as multi-step keyframe animations, imperative animation control, or frame-by-frame rendering -- `DOMBridge` provides direct access to browser animation APIs.

These are lower-level APIs. Prefer `withAnimation` and `.animation()` for typical use cases.

### animate(_:keyframes:duration:easing:fill:)

Wraps the browser's `element.animate()` method (Web Animations API). Creates a multi-step keyframe animation on a DOM element.

```swift
// Requires access to DOMBridge and a JSObject element
bridge.animate(
    element,
    keyframes: [
        ["opacity": "0", "transform": "translateY(-20px)"],
        ["opacity": "1", "transform": "translateY(0)"]
    ],
    duration: 300,   // milliseconds
    easing: "ease-out",
    fill: "forwards"
)
```

#### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `element` | `JSObject` | (required) | The DOM element to animate |
| `keyframes` | `[[String: String]]` | (required) | Array of keyframe style dictionaries |
| `duration` | `Double` | (required) | Duration in milliseconds |
| `easing` | `String` | `"ease"` | CSS easing function |
| `fill` | `String` | `"none"` | Fill mode: `"none"`, `"forwards"`, `"backwards"`, `"both"` |

Returns the browser `Animation` object (`JSObject?`) which can be used for further control (pause, cancel, etc.).

### requestAnimationFrame(_:)

Wraps the browser's `requestAnimationFrame`. The callback fires once before the next repaint. Useful for smooth, frame-synced updates.

```swift
bridge.requestAnimationFrame {
    // Update DOM or calculate next animation frame
}
```

The callback is wrapped in a `JSOneshotClosure`, so it fires exactly once and is automatically deallocated. For continuous animation loops, call `requestAnimationFrame` again inside the callback:

```swift
func animationLoop() {
    bridge.requestAnimationFrame {
        // perform frame work
        animationLoop()  // schedule next frame
    }
}
```

### setTimeout(_:milliseconds:)

Wraps `window.setTimeout` for delayed execution. Useful for sequencing animations or delayed cleanup.

```swift
bridge.setTimeout({
    // runs after 500ms
}, milliseconds: 500)
```

Like `requestAnimationFrame`, this uses `JSOneshotClosure` for automatic memory management.

---

## How It Works

### Architecture Overview

The animation system bridges Swift's declarative API to CSS transitions through the render cycle:

```
withAnimation(.spring)          .animation(.spring)
       |                               |
       v                               v
AnimationContext.current       "transition" CSS property
set before state mutation      set directly on element
       |                               |
       v                               v
   @State mutation              Style modifier
       |                        (e.g., .opacity())
       v                               |
 queueMicrotask                        v
 (defers render)               TagNode with styles
       |                               |
       v                               v
  Render cycle              Reconciler diffs trees
  captures animation                   |
       |                               v
       v                        Patch: updateStyles
  DOMRenderer.update()                 |
       |                               v
       v                    Browser CSS transition
  applyPatch sets                 interpolates
  CSS transition on               old -> new values
  changed properties
```

### CSS Generation

The `Animation` struct generates CSS `transition` values:

```swift
Animation.easeInOut(duration: 0.3)
// CSS: "all 0.3s ease-in-out"

Animation.spring.delay(0.1)
// CSS: "all 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275) 0.1s"

Animation.custom(duration: 0.4, timingFunction: .steps(5, .end))
// CSS: "all 0.4s steps(5, end)"
```

When used with `withAnimation`, only the specific CSS properties that changed are included in the transition (instead of `all`), which is more performant:

```swift
// If only "opacity" and "transform" changed during the render:
// CSS: "opacity 0.3s ease-in-out, transform 0.3s ease-in-out"
```

### Performance Notes

- **CSS transitions are GPU-accelerated** for `transform` and `opacity` properties. Prefer animating these over layout properties like `width` or `margin`.
- **withAnimation scopes are short-lived.** The animation context is captured and cleared at the start of the render cycle, so it only affects the immediately following re-render.
- **The .animation() modifier is persistent.** It adds a `transition` CSS property that remains on the element across re-renders.
- **Reduced motion.** Use `MediaQueryState.prefersReducedMotion` or `@Environment(\.prefersReducedMotion)` to respect the user's accessibility preference and conditionally disable animations.

### Complete Example

```swift
struct AnimatedCard: Tag {
    @State var isExpanded = false
    @State var isVisible = true

    var body: some Tag {
        Div {
            Button(onclick: {
                withAnimation(.spring) {
                    isExpanded.toggle()
                }
            }) { Text(isExpanded ? "Collapse" : "Expand") }

            Button(onclick: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible.toggle()
                }
            }) { Text(isVisible ? "Hide" : "Show") }

            if isVisible {
                Div {
                    Text("Card content goes here")
                }
                .animation(.easeInOut(duration: 0.3))
                .opacity(isExpanded ? 1.0 : 0.6)
                .height(isExpanded ? .px(200) : .px(80))
                .overflow(.hidden)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}
```
