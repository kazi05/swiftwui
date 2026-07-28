# Responsive styling

One media vocabulary — ``MediaQuery`` — spent across five surfaces: a reactive
environment read, per-element `@media` and `@container` blocks, per-breakpoint
``Responsive`` values, and scoped ``Rule``s.

## Overview

Every responsive API in SwiftWUI takes the same value type. `MediaQuery.up(.md)`
is the same query whether you hand it to `@Environment(\.media)`, to
`.media(_:_:)`, to a `Rule`, or let `responsive(_:sm:md:lg:xl:)` build it for
you. What differs is **who evaluates it**:

- `@Environment(\.media)` — *Swift* evaluates it, during `body`. A flip
  re-renders the component, so the tree itself can change shape.
- `.media(_:_:)`, `.container(_:name:_:)`, `responsive(…)`,
  `Rule(class:media:)` — *the browser* evaluates it, from the generated
  stylesheet. The tree is identical at every width; only the declarations that
  win differ.

That split is the whole decision. Use the environment when a narrow viewport
needs *different markup*; use the CSS surfaces when it needs *different values
for the same markup*. Reaching for the environment to do styling costs you
correctness on first paint, for reasons the next section spells out.

## Structural branching with `@Environment(\.media)`

`@Environment(\.media)` gives a ``MediaProxy``; `matches(_:)` answers a query
and registers the component as a reader of it:

```swift
struct SiteNav: Tag {
    @Environment(\.media) var media
    var body: some Tag {
        Div {
            if media.matches(.down(.md)) {
                Button("Menu") { }
            } else {
                A(href: "/docs") { "Docs" }
                A(href: "/blog") { "Blog" }
            }
        }
    }
}
```

Like every environment signal, this is reactive **only when read inside a
component's `body`** — a `matches` call in an event handler or a `.task`
closure answers correctly but registers no dependency, so a later flip won't
re-render anything. When the condition does cross, only the components that
read *that* condition re-render; a sibling reading a different query is
untouched. Registration is deduplicated per condition string, so a thousand
components asking `.down(.md)` share one `matchMedia` listener.

### Why this is the wrong tool for pure styling

`MediaProxy.matches(_:)` returns `false` for every query when there is no live
runtime behind it — native builds, unit tests, and every page rendered by
`swiftwui ssg`. The default is not "unknown", it is a plain `false`, so in the
example above a prerendered page always ships the desktop branch.

A phone visitor then gets the desktop markup in the HTML document, sees it
painted, and watches it swap to the mobile branch once the Wasm module boots
and runs the first client render. That is a content flash on every load, and no
amount of CSS fixes it — the wrong elements are genuinely in the document.

The CSS-backed surfaces have no such gap: their conditions live in the
stylesheet the browser parses before it paints anything, so they are correct on
first paint on every path, prerendered or not. Reserve `\.media` for branching
that changes *what is in the tree*, and prefer `.media()`, `.container()`, and
`responsive()` for everything that only changes values. If a structural branch
on a prerendered route is unavoidable, make the `false` branch the one that
degrades gracefully at any width.

## Building queries

``MediaQuery`` covers the width, height, orientation and color-scheme features
directly:

```swift
MediaQuery.minWidth(.px(640))
MediaQuery.maxWidth(.px(1024))
MediaQuery.minHeight(.px(480))
MediaQuery.maxHeight(.px(720))
MediaQuery.orientation(.landscape)
MediaQuery.prefersColorScheme(.dark)
```

and composes them with `and`, `or`, and `not`:

```swift
let wideLandscape = MediaQuery.and(.up(.lg), .orientation(.landscape))
let notDark = MediaQuery.not(.prefersColorScheme(.dark))
let compact = MediaQuery.or(.maxWidth(.px(420)), .maxHeight(.px(480)))
```

Each combinator parenthesizes its own result, so nesting stays valid CSS at any
depth — `.and(.or(.up(.md), .orientation(.landscape)), .up(.sm))` emits
`(((min-width: 768px) or (orientation: landscape)) and (min-width: 640px))`.
You never add parentheses yourself, and there is no depth at which the emitted
condition silently stops parsing. (v1 emitted unparenthesized combinators and
broke exactly this way.)

`MediaQuery.custom(_:)` is the escape hatch for a feature the type doesn't
model:

```swift
MediaQuery.custom("(prefers-reduced-motion: reduce)")
```

The string is checked with the same `CSSSanitize.isSafeValue` guard the rest of
the style layer uses. An unsafe string trips `assertionFailure` in debug and
becomes `not all` — which matches nothing — in release: a condition that can't
be validated must never turn into a rule that applies everywhere. Write your
own parentheses around the feature; `custom` stores the string verbatim, and an
unparenthesized one corrupts any `and`/`or` you later wrap it in.

## Breakpoints

``Breakpoint`` is the named mobile-first scale — `.sm` 640px, `.md` 768px,
`.lg` 1024px, `.xl` 1280px — and it is `Comparable`, so ranges and sorts work
on it. Two `MediaQuery` factories turn a breakpoint into a query:

```swift
MediaQuery.up(.lg)     // (min-width: 1024px)   — at or above
MediaQuery.down(.md)   // (max-width: 767.98px) — below
```

`down` subtracts 0.02px rather than using the breakpoint value itself. Without
it, `.up(.md)` and `.down(.md)` would both match at exactly 768px and fight
over that one column. Fractional viewport widths are real (browser zoom,
non-integer device pixel ratios), and 0.02px sits below anything a browser
reports, so the pair stays exhaustive with no gap between them.

Prefer `.up`/`.down` over raw `minWidth`/`maxWidth` pixel literals: the scale is
one place to change, and — see *Rule ordering* below — the generated conditions
are in pixels, which is what the stylesheet's ordering assumes.

## Responsive values

``Responsive`` is a base value plus mobile-first overrides. Build one with
`responsive(_:sm:md:lg:xl:)` and pass it to a style modifier:

```swift
Div {
    H1 { "SwiftWUI" }
        .fontSize(responsive(.rem(1.75), md: .rem(2.5), lg: .rem(3.5)))
    P { "Ships without a JS bundle." }
}
.display(responsive(.block, md: .flex))
.gap(.px(16))
.padding(responsive(.px(16), sm: .px(24), lg: .px(48)))
```

Only the breakpoints you pass become overrides, in any order — the initializer
sorts them ascending. The base value is the unconditional one and applies below
the first override.

This desugars to stylesheet rules, never to inline styles: the base becomes an
unconditional class rule, and each override becomes a `@media` block over a
**non-overlapping** `[bp, nextBp)` range, with the last override left
open-ended. Non-overlapping matters because it means exactly one override
matches at any width, so the result never depends on which rule the stylesheet
happens to emit last.

### The overload set is bounded

`Responsive` is not a general mechanism. These modifiers accept one today:

| Modifier | Value |
| --- | --- |
| `padding`, `margin`, `width`, `height`, `minWidth`, `maxWidth`, `fontSize`, `gap` | `Responsive<CSSLength>` |
| `display` | `Responsive<Display>` |
| `flexDirection` | `Responsive<FlexDirection>` |
| `textAlign` | `Responsive<TextAlign>` |
| `gridTemplateColumns` | `Responsive<String>` |

That's the layout and typography properties that actually vary by width; the
set is deliberately small and grows on demand. For anything else, write the
`@media` blocks yourself with `.media(_:_:)`:

```swift
Div { }
    .backgroundColor(.hex("#fff"))
    .media(.up(.lg)) { wide in
        wide.boxShadow(Shadow(offsetX: .zero, offsetY: .px(2), blur: .px(8),
                              color: .hex("#00000022")))
    }
```

### Never stack a plain modifier on the same property

This is the one rule that will cost you an afternoon if you break it:

```swift
// Wrong — the padding never changes at any width.
Div { }
    .padding(.px(16))                             // inline style
    .padding(responsive(.px(16), lg: .px(48)))    // class rules, always outranked
```

Plain style modifiers merge into the element's inline `style` attribute.
`Responsive` (and `.media()`, and `.container()`) emit class-based stylesheet
rules. An inline declaration beats any class selector, so the plain call
silently defeats every breakpoint override, at every width, with no warning and
no visible symptom other than "the responsive value does nothing". Put the base
value in `responsive`'s first argument — that is what it is for — and never set
the same property twice on one element by two different routes.

## Container queries

A container query branches on an element's own box instead of the viewport.
Establish a containment context on an ancestor with `.containerType(_:name:)`,
then query it from a descendant with `.container(_:name:_:)`:

```swift
struct Sidebar: Tag {
    var body: some Tag {
        Aside {
            Div { "Filters" }
                .display(.flex)
                .flexDirection(.column)
                .gap(.px(8))
                .container(.minWidth(.px(360)), name: "sidebar") { wide in
                    wide.flexDirection(.row)
                }
        }
        .containerType(.inlineSize, name: "sidebar")
    }
}
```

`.inlineSize` (the default) contains the inline axis only and is the usual
choice; `.size` queries both axes, which also applies size containment on both,
so the element stops growing with its contents and needs an explicit height;
`.normal` opts out. An element never queries itself — the
`containerType` has to be on an ancestor, which is why the example wraps.

The `name:` argument is validated as a CSS ident. On `.container`, an invalid
name is **silently dropped** and the rule is emitted in its unnamed form, which
matches the nearest container instead of the one you meant. That drop is the
injection guard, not a debug convenience: the `@container` prelude is written
into the stylesheet raw, with no escaping sink downstream, so it has to hold in
release builds too and cannot be an assert. The practical consequence is that a
typo'd name doesn't fail — it silently retargets. Keep container names literal
string constants; never interpolate one from data. `.containerType(name:)` is
louder about the same mistake (`assertionFailure` in debug) but still drops the
name.

## Scoped rules

``Rule`` carries the same two conditions as init parameters, for
component-scoped stylesheets via ``Styled`` and for `App.globalStyles`:

```swift
struct Panel: Tag, Styled {
    @RulesBuilder var styles: [Rule] {
        Rule(class: "panel", media: .up(.lg)) { s in
            s.border(.right, width: .px(1), style: .solid, color: .hex("#ddd"))
        }
        Rule(class: "panel-body", container: .minWidth(.px(360)),
             containerName: "sidebar") { s in
            s.flexDirection(.row)
        }
    }
    var body: some Tag {
        Div(class: "panel") {
            Div(class: "panel-body") { "Filters" }
        }
    }
}
```

`media:` and `container:` are mutually exclusive on a single `Rule` — passing
both trips `assert(media == nil || container == nil)`. One rule produces one
at-rule; wrap the selector in a second `Rule` if you need both conditions.

`containerName:` is dropped the same way `.container(name:)`'s is when it isn't
a valid ident, with the same consequence: the rule applies against the nearest
container rather than not applying at all.

Note that the nesting form — `$0.media { }` / `$0.container { }` inside a build
closure — is a `Style` bundle feature, not a `Rule` one. Blocks nested inside a
`Rule`'s closure are collected and then never registered; only the closure's
plain declarations and pseudo blocks reach the stylesheet. Use the `media:` and
`container:` parameters on `Rule`, and save the nested form for `Style.build`:

```swift
struct CardStyle: Style {
    func build(_ s: inout StyleProxy) {
        s.padding(.px(8))
        s.container(.minWidth(.px(400)), name: "sidebar") { $0.flexDirection(.row) }
    }
}
```

## Rule ordering

The stylesheet used to order its `@media` blocks by a lexicographic sort of the
condition string, which put `(min-width: 1024px)` before `(min-width: 640px)`
and inverted every mobile-first stack at wide viewports; blocks now sort by
width semantics (min-width ascending, then max-width descending, then the
width-less conditions), so the block that should win is emitted last. That
comparison reads the number and ignores the unit, so a hand-written
`.custom("(min-width: 40rem)")` sorts its bare `40` against pixel values —
don't mix units within one breakpoint stack.
