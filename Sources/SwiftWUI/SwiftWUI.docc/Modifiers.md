# Modifiers

Compositional wrappers around a `Tag`'s content — a custom `TagModifier`
protocol for your own reusable styling/behavior bundles, plus a built-in
catalog of pointer, keyboard, element-observer, and window-level modifiers.

## Overview

``TagModifier`` is the `Tag` analog of SwiftUI's `ViewModifier`: instead of
subclassing or wrapping views by hand, you describe how to transform a
placeholder for "whatever content this is applied to." Built-in interaction
and observer modifiers (`onTap`, `onKeyDown`, `onVisibilityChange`, …) are
ordinary functions built the same way, layered directly onto `HTMLTag` or
`Tag` depending on whether they need a live DOM element underneath.

### Custom modifiers with `TagModifier`

Conform to ``TagModifier`` and describe the wrapped structure in `body`,
using `content` as a placeholder for whatever `Tag` the modifier is applied
to:

```swift
struct Card: TagModifier {
    func body(content: Content) -> some Tag {
        Div(class: "card") { content }
            .style(.padding(.px(16)))
            .style(.borderRadius(.px(8)))
    }
}

extension Tag {
    func card() -> some Tag { modifier(Card()) }
}
```

```swift
Text("Hello").card()
```

`content` resolves the original tag at the placeholder's structural
position. Using `content` more than once in a single `body` duplicates that
tag's identity — same documented limitation as SwiftUI's `content`.

`ModifiedTag` (the type `.modifier(_:)` produces) is a component boundary:
`@State` and `@Environment` declared on the modifier itself work exactly as
they do on a regular component, with their own identity keyed to the
modified tag's position in the tree. `@State` inside a modifier participates
in SSG/hydration snapshots under the same constraint as component state —
the modifier type and the content type it wraps both need to be non-private,
top-level types, because `String(reflecting:)` only yields a stable name for
those; a modifier or content type nested in a function or marked `private`
produces a per-binary address instead and won't survive hydration.

Unlike an ordinary component boundary, a modifier's body does **not** reset
the enclosing `Styled` scope — elements resolved inside `content` still
carry the caller's scoped class, so wrapping a `Styled` component's content
in a modifier doesn't detach its scoped selectors.

## Built-in modifiers

### Pointer

Event modifiers below are declared on `HTMLTag`, not the general `Tag`
protocol — they ride the element's attribute bag and need a live DOM element
to attach a listener to, so they're unavailable on plain composition types.

```swift
Div { Text("Click me") }
    .onTap { print("tapped") }
    .onDoubleTap { print("double") }
    .onHover { isHovering in print(isHovering) }
```

- `onTap(_:)` — plain and `(ClickEvent) -> Void` payload overloads. A
  dispatch without a payload (non-DOM backends, tests) arrives as a default
  `ClickEvent()`.
- `onDoubleTap(_:)`
- `onHover(_:)` — `true` on `mouseenter`, `false` on `mouseleave`.
- `onLongPress(minimumDuration:_:)` — fires after the pointer stays down for
  `minimumDuration` (default `.milliseconds(500)`); cancelled by
  `pointerup`/`pointercancel`/`pointerleave`. **Known limitation:** a
  re-render mid-press replaces the element's handlers and their press
  tracker — the in-flight timer from before the re-render can no longer be
  cancelled by the new `pointerup` handler.

### Keyboard and focus

```swift
Input(type: .text)
    .onKeyDown(.enter) { submit() }
    .onFocus { isEditing = true }
    .onBlur { isEditing = false }
```

- `onKeyDown(_:)` / `onKeyUp(_:)` — raw `(KeyEvent) -> Void`.
- `onKeyDown(_:modifiers:_:)` — filtered form; fires only when both the
  ``KeyEquivalent`` and the exact ``EventModifiers`` set match.
- `onFocus(_:)` / `onBlur(_:)`
- `onSubmit(_:)` — the DOM backend always calls `preventDefault()` on the
  underlying `submit` event.

### Element observers

```swift
Div { /* … */ }
    .onVisibilityChange(threshold: 0.5) { isVisible in print(isVisible) }

TextArea()
    .onSizeChange { size in print(size.width, size.height) }
```

- `onVisibilityChange(threshold:_:)` — backed by `IntersectionObserver`;
  delivers `true`/`false` as the element enters/leaves the viewport.
- `onSizeChange(_:)` — backed by `ResizeObserver`; delivers a ``SizeEvent``
  on every resize.

Both fire once immediately on mount with the element's initial state —
`IntersectionObserver` and `ResizeObserver` deliver an initial callback as
soon as they start observing, not only on the next change.

### Element scroll

```swift
Div { /* tall content */ }
    .onScrollChange { offset in print(offset.x, offset.y) }
```

`onScrollChange(_:)` delivers a ``ScrollEvent`` on the element's own
`scroll` event. No explicit throttling is applied — browsers already
coalesce scroll events to one per animation frame, and the DOM listener is
registered passive.

### Window-level effects

```swift
Div { /* … */ }
    .onWindowScroll { offset in print(offset.y) }
    .onWindowResize { size in print(size.width) }
```

`onWindowScroll(_:)` and `onWindowResize(_:)` are declared on `Tag`, not
`HTMLTag` — they track the page's `window`, not a specific element, so
they're available on any tag, including plain composition. The real
`window` listener attaches lazily, once, on the first subscription anywhere
in the app, and is never detached.

## `Button(onClick:)` and `.onTap`

`Button`'s `onClick:` init parameter is sugar for the same attribute-bag
path `.onTap` uses — both register a handler for the element's `click`
event. They compose rather than conflict: a `Button(onClick:)` that also has
`.onTap(_:)` applied fires both handlers on click, in registration order.
Prefer `onClick:` for a button's primary action and reach for `.onTap` when
attaching click behavior generically across tag types (or a second handler
alongside `onClick:`).
