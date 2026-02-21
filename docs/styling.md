# Styling

SwiftWUI provides a type-safe CSS styling system that lets you apply styles directly to tags using chainable modifier methods. The framework offers type-safe enums for common CSS properties, CSS units, and colors, along with a string-based fallback for any property not covered by the type-safe API.

## Table of Contents

- [Overview](#overview)
- [Type-Safe Style Modifiers](#type-safe-style-modifiers)
- [CSS Units](#css-units)
- [CSS Colors](#css-colors)
- [String Fallback](#string-fallback)
- [Class and Attribute Modifiers](#class-and-attribute-modifiers)
- [Custom TagModifier](#custom-tagmodifier)
- [External Stylesheets](#external-stylesheets)
- [Complete Example](#complete-example)
- [Best Practices](#best-practices)

---

## Overview

Styles are applied as inline CSS through chainable modifier methods. Each modifier returns a `ModifiedContent<Self>` wrapper that accumulates style, class, and attribute data.

```swift
Div {
    Text("Hello, SwiftWUI!")
}
.backgroundColor(.hex("#f5f5f5"))
.padding(.px(16))
.borderRadius(.px(8))
.fontSize(.rem(1.2))
.foregroundColor(.hex("#333"))
```

Modifiers can be chained in any order. They are applied as inline `style` attributes on the rendered HTML element.

---

## Type-Safe Style Modifiers

### Layout

Control element display mode, positioning, and sizing.

```swift
Div { content }
    .display(.flex)              // display: flex
    .position(.relative)         // position: relative
    .width(.percent(100))        // width: 100%
    .height(.vh(100))            // height: 100vh
    .minWidth(.px(200))          // min-width: 200px
    .maxWidth(.px(1200))         // max-width: 1200px
    .minHeight(.px(400))         // min-height: 400px
    .maxHeight(.vh(80))          // max-height: 80vh
```

Positioning offsets:

```swift
Div { content }
    .position(.absolute)
    .top(.px(0))                 // top: 0px
    .right(.px(16))              // right: 16px
    .bottom(.auto)               // bottom: auto
    .left(.percent(50))          // left: 50%
```

**Display values:** `block`, `inline`, `flex`, `grid`, `none`, `inlineBlock`, `inlineFlex`, `inlineGrid`, `contents`, `table`, `tableRow`, `tableCell`

**Position values:** `static`, `relative`, `absolute`, `fixed`, `sticky`

### Spacing

Control padding and margin with uniform or axis-specific values.

```swift
// Uniform spacing
Div { content }
    .padding(.px(16))            // padding: 16px
    .margin(.rem(1))             // margin: 1rem

// Vertical and horizontal
Div { content }
    .padding(.px(8), .px(16))   // padding: 8px 16px
    .margin(.px(0), .auto)      // margin: 0px auto

// Individual sides
Div { content }
    .paddingTop(.px(8))
    .paddingRight(.px(16))
    .paddingBottom(.px(8))
    .paddingLeft(.px(16))

// Margin sides
Div { content }
    .marginTop(.px(16))
    .marginRight(.auto)
    .marginBottom(.px(16))
    .marginLeft(.auto)

// Gap (for flex/grid containers)
Div { content }
    .display(.flex)
    .gap(.px(12))                // gap: 12px
```

### Flexbox

Build flexible layouts with the full flexbox API.

```swift
// Flex container
Div {
    Div { Text("Item 1") }
    Div { Text("Item 2") }
    Div { Text("Item 3") }
}
.display(.flex)
.flexDirection(.row)             // flex-direction: row
.flexWrap(.wrap)                 // flex-wrap: wrap
.justifyContent(.spaceBetween)   // justify-content: space-between
.alignItems(.center)             // align-items: center
.gap(.px(16))
```

Flex item properties:

```swift
// Shorthand: flex: grow shrink basis
Div { content }
    .flex(1, 0, .px(200))       // flex: 1 0 200px

// Individual properties
Div { content }
    .flexGrow(1)                 // flex-grow: 1
    .flexShrink(0)               // flex-shrink: 0
    .alignSelf(.flexEnd)         // align-self: flex-end
```

**FlexDirection values:** `row`, `column`, `rowReverse`, `columnReverse`

**FlexWrap values:** `nowrap`, `wrap`, `wrapReverse`

**JustifyContent values:** `flexStart`, `flexEnd`, `center`, `spaceBetween`, `spaceAround`, `spaceEvenly`, `start`, `end`, `stretch`

**AlignItems values:** `flexStart`, `flexEnd`, `center`, `stretch`, `baseline`, `start`, `end`

**AlignSelf values:** `auto`, `flexStart`, `flexEnd`, `center`, `stretch`, `baseline`

### Grid

Build grid layouts using CSS Grid.

```swift
Div {
    Div { Text("Col 1") }
    Div { Text("Col 2") }
    Div { Text("Col 3") }
}
.display(.grid)
.gridTemplateColumns("1fr 1fr 1fr")      // grid-template-columns: 1fr 1fr 1fr
.gridTemplateRows("auto 1fr auto")        // grid-template-rows: auto 1fr auto
.gap(.px(16))
```

Grid item placement:

```swift
Div { content }
    .gridColumn("1 / 3")         // grid-column: 1 / 3
    .gridRow("2 / 4")            // grid-row: 2 / 4

// Grid auto flow
Div { content }
    .gridAutoFlow(.rowDense)     // grid-auto-flow: row dense
```

**GridAutoFlow values:** `row`, `column`, `rowDense`, `columnDense`

### Colors

Apply background and foreground colors using the type-safe `CSSColor` type.

```swift
Div { content }
    .backgroundColor(.hex("#f0f0f0"))
    .foregroundColor(.rgb(51, 51, 51))
    .opacity(0.9)
```

See the [CSS Colors](#css-colors) section below for all the ways to construct colors.

### Typography

Control text appearance with type-safe font and text modifiers.

```swift
P { Text("Styled paragraph") }
    .fontSize(.rem(1.125))       // font-size: 1.125rem
    .fontWeight(.bold)           // font-weight: bold
    .fontFamily("'Inter', system-ui, sans-serif")
    .fontStyle(.italic)          // font-style: italic
    .textAlign(.center)          // text-align: center
    .lineHeight(.rem(1.6))      // line-height: 1.6rem
    .letterSpacing(.px(0.5))    // letter-spacing: 0.5px
    .textDecoration(.underline) // text-decoration: underline
    .textTransform(.uppercase)  // text-transform: uppercase
    .whiteSpace(.nowrap)        // white-space: nowrap
    .wordBreak(.breakWord)      // word-break: break-word
```

**FontWeight values:** `normal`, `bold`, `lighter`, `bolder`, `w100` through `w900`

**FontStyle values:** `normal`, `italic`, `oblique`

**TextAlign values:** `left`, `right`, `center`, `justify`, `start`, `end`

**TextDecoration values:** `none`, `underline`, `overline`, `lineThrough`

**TextTransform values:** `none`, `uppercase`, `lowercase`, `capitalize`

**WhiteSpace values:** `normal`, `nowrap`, `pre`, `preWrap`, `preLine`, `breakSpaces`

**WordBreak values:** `normal`, `breakAll`, `keepAll`, `breakWord`

### Border

Style element borders with type-safe values.

```swift
// Shorthand: border(width, style, color)
Div { content }
    .border(.px(1), .solid, .hex("#ddd"))

// Individual border properties
Div { content }
    .borderWidth(.px(2))
    .borderStyle(.dashed)
    .borderColor(.red)
    .borderRadius(.px(8))

// Bottom border only
Div { content }
    .borderBottom(.px(1), .solid, .lightGray)
```

**BorderStyle values:** `none`, `solid`, `dashed`, `dotted`, `double_`, `groove`, `ridge`, `inset`, `outset`

### Box Model

Control overflow, shadows, sizing, and stacking.

```swift
Div { content }
    .boxSizing(.borderBox)       // box-sizing: border-box
    .overflow(.hidden)           // overflow: hidden
    .overflowX(.scroll)         // overflow-x: scroll
    .overflowY(.auto)           // overflow-y: auto
    .boxShadow("0 2px 4px rgba(0,0,0,0.1)")
    .zIndex(10)                  // z-index: 10
```

**BoxSizing values:** `contentBox`, `borderBox`

**Overflow values:** `visible`, `hidden`, `scroll`, `auto`, `clip`

### Cursor and Interaction

Control cursor appearance and element visibility.

```swift
Button(onclick: { /* ... */ }) { Text("Click") }
    .cursor(.pointer)            // cursor: pointer

Div { content }
    .visibility(.hidden)         // visibility: hidden
    .objectFit(.cover)           // object-fit: cover
```

**Cursor values:** `auto`, `default_`, `pointer`, `wait`, `text`, `move`, `notAllowed`, `crosshair`, `grab`, `grabbing`, `colResize`, `rowResize`, `nResize`, `eResize`, `sResize`, `wResize`, `zoomIn`, `zoomOut`, `help`, `progress`, `none`

**Visibility values:** `visible`, `hidden`, `collapse`

**ObjectFit values:** `contain`, `cover`, `fill`, `none`, `scaleDown`

### Transform and Animation

Apply CSS transforms, transitions, and animations.

```swift
Div { content }
    .transform("rotate(45deg) scale(1.2)")
    .transition("all 0.3s ease")
    .animation("fadeIn 1s ease-in-out")
```

---

## CSS Units

The `CSSUnit` enum provides type-safe CSS measurement units. All style modifiers that accept dimensions use this type.

### Available Units

| Constructor | CSS Output | Description |
|-------------|------------|-------------|
| `.px(16)` | `16px` | Pixels |
| `.rem(1)` | `1rem` | Root em units |
| `.em(1.5)` | `1.5em` | Em units (relative to parent font size) |
| `.percent(50)` | `50%` | Percentage |
| `.vh(100)` | `100vh` | Viewport height percentage |
| `.vw(100)` | `100vw` | Viewport width percentage |
| `.vmin(50)` | `50vmin` | Smaller of vw/vh |
| `.vmax(50)` | `50vmax` | Larger of vw/vh |
| `.fr(1)` | `1fr` | Fractional unit (for CSS Grid) |
| `.auto` | `auto` | Auto sizing |
| `.zero` | `0` | Zero (no unit) |
| `.inherit` | `inherit` | Inherit from parent |
| `.initial` | `initial` | Reset to initial value |
| `.unset` | `unset` | Unset (acts as inherit or initial) |
| `.maxContent` | `max-content` | Intrinsic maximum content size |
| `.minContent` | `min-content` | Intrinsic minimum content size |
| `.fitContent` | `fit-content` | Clamp between min-content and max-content |

### Usage Examples

```swift
Div { content }
    .width(.percent(100))
    .maxWidth(.px(1200))
    .height(.vh(100))
    .padding(.rem(1))
    .margin(.zero, .auto)       // center horizontally
    .gap(.em(1.5))
    .fontSize(.rem(1.125))
    .lineHeight(.em(1.6))
    .borderRadius(.px(8))
```

### Number Formatting

Integer values render without decimals. Floating-point values preserve their precision:

```swift
CSSUnit.px(16).cssValue    // "16px"
CSSUnit.rem(1.5).cssValue  // "1.5rem"
CSSUnit.px(16.0).cssValue  // "16px"  (trailing .0 is stripped)
```

---

## CSS Colors

The `CSSColor` struct provides type-safe color values with multiple construction methods.

### Named Color Constants

SwiftWUI provides pre-defined color constants for common colors:

```swift
.backgroundColor(.white)
.backgroundColor(.black)
.backgroundColor(.red)
.backgroundColor(.green)
.backgroundColor(.blue)
.backgroundColor(.yellow)
.backgroundColor(.orange)
.backgroundColor(.purple)
.backgroundColor(.pink)
.backgroundColor(.gray)
.backgroundColor(.lightGray)
.backgroundColor(.darkGray)
.backgroundColor(.cyan)
.backgroundColor(.magenta)
.backgroundColor(.brown)
.backgroundColor(.navy)
.backgroundColor(.teal)
.backgroundColor(.indigo)
.backgroundColor(.coral)
```

Special values:

```swift
.backgroundColor(.transparent)    // transparent
.foregroundColor(.currentColor)   // currentColor
.foregroundColor(.inherit)        // inherit
```

### Hex Colors

```swift
CSSColor(hex: "#ff6600")
CSSColor(hex: "ff6600")    // # prefix is optional
```

### RGB and RGBA

```swift
CSSColor.rgb(255, 102, 0)           // rgb(255, 102, 0)
CSSColor.rgba(255, 102, 0, 0.5)     // rgba(255, 102, 0, 0.5)
```

### HSL and HSLA

```swift
CSSColor.hsl(24, 100, 50)           // hsl(24, 100%, 50%)
CSSColor.hsla(24, 100, 50, 0.8)     // hsla(24, 100%, 50%, 0.8)
```

### Custom CSS Value

For any valid CSS color string:

```swift
CSSColor(cssValue: "oklch(0.7 0.15 200)")
```

### Usage Examples

```swift
Div { content }
    .backgroundColor(.hex("#f8f9fa"))
    .foregroundColor(.rgb(33, 37, 41))
    .border(.px(1), .solid, .rgba(0, 0, 0, 0.125))
```

---

## String Fallback

For any CSS property not covered by the type-safe API, use the `.style()` modifier with raw property name and value strings:

```swift
Div { content }
    .style("custom-property", "value")
    .style("backdrop-filter", "blur(10px)")
    .style("clip-path", "circle(50%)")
    .style("writing-mode", "vertical-rl")
    .style("scroll-behavior", "smooth")
```

You can mix type-safe modifiers with string fallbacks:

```swift
Div { content }
    .display(.flex)
    .padding(.px(16))
    .style("gap", "12px")                // string fallback for gap
    .style("font-family", "system-ui")   // string fallback for font-family
    .backgroundColor(.white)
```

This is also useful for CSS custom properties (variables):

```swift
Div { content }
    .style("--primary-color", "#0066cc")
    .style("--spacing", "16px")
    .style("color", "var(--primary-color)")
```

---

## Class and Attribute Modifiers

### CSS Classes

Add CSS class names to elements with `.class()`:

```swift
Div { content }
    .class("card")
    .class("card-primary")
    .class("shadow-lg")
```

This is useful when combining SwiftWUI components with external CSS frameworks like Tailwind CSS or Bootstrap.

### HTML Attributes

Add arbitrary HTML attributes with `.attribute()`:

```swift
Div { content }
    .attribute("data-id", "123")
    .attribute("role", "banner")
    .attribute("aria-label", "Main navigation")
    .attribute("data-testid", "header")
```

### Combining All Modifier Types

Style, class, and attribute modifiers can all be chained together:

```swift
Div {
    Text("Card content")
}
.class("card")
.attribute("data-id", "42")
.backgroundColor(.white)
.padding(.px(16))
.borderRadius(.px(8))
.boxShadow("0 2px 8px rgba(0,0,0,0.1)")
```

---

## Custom TagModifier

For reusable style combinations, define a custom `TagModifier`. This is analogous to SwiftUI's `ViewModifier`.

### Defining a TagModifier

```swift
struct CardStyle: TagModifier {
    func body(content: Content) -> some Tag {
        Div { content }
            .backgroundColor(.white)
            .borderRadius(.px(8))
            .padding(.px(16))
            .boxShadow("0 2px 4px rgba(0,0,0,0.1)")
    }
}
```

### Applying a TagModifier

Use the `.modifier()` method on any tag:

```swift
Text("Hello").modifier(CardStyle())

Div {
    H2 { "Featured Article" }
    P { "Article content here..." }
}.modifier(CardStyle())
```

### Convenience Extension

Create a fluent API by adding an extension method on `Tag`:

```swift
extension Tag {
    func cardStyle() -> ModifiedTag<CardStyle> {
        modifier(CardStyle())
    }
}

// Now use it like any other modifier
Text("Hello").cardStyle()

Div {
    H2 { "Article" }
    P { "Content" }
}.cardStyle()
```

### Parameterized TagModifier

Modifiers can accept parameters for configurable styles:

```swift
struct PaddedContainer: TagModifier {
    let size: CSSUnit
    let background: CSSColor

    func body(content: Content) -> some Tag {
        Div { content }
            .padding(size)
            .backgroundColor(background)
            .borderRadius(.px(8))
    }
}

extension Tag {
    func paddedContainer(
        size: CSSUnit = .px(16),
        background: CSSColor = .white
    ) -> ModifiedTag<PaddedContainer> {
        modifier(PaddedContainer(size: size, background: background))
    }
}

// Usage
Text("Hello")
    .paddedContainer(size: .px(24), background: .hex("#f5f5f5"))
```

### Composing TagModifiers

Modifiers compose naturally through chaining:

```swift
struct ShadowStyle: TagModifier {
    func body(content: Content) -> some Tag {
        content.boxShadow("0 4px 6px rgba(0,0,0,0.1)")
    }
}

struct RoundedStyle: TagModifier {
    func body(content: Content) -> some Tag {
        content.borderRadius(.px(12))
    }
}

// Apply multiple modifiers
Div { Text("Styled") }
    .modifier(ShadowStyle())
    .modifier(RoundedStyle())
    .padding(.px(16))
```

---

## External Stylesheets

SwiftWUI supports referencing external CSS through the `StyleSheet` type.

### File Reference

```swift
StyleSheet.file("styles.css")
```

### URL Reference (CDN)

```swift
StyleSheet.url("https://cdn.example.com/framework.css")
```

### Inline CSS

```swift
StyleSheet.inline("""
    body { margin: 0; font-family: system-ui; }
    .container { max-width: 1200px; margin: 0 auto; }
""")
```

---

## Complete Example

Here is a full styled page demonstrating multiple styling techniques:

```swift
import SwiftWUI

// MARK: - Custom Modifiers

struct CardModifier: TagModifier {
    func body(content: Content) -> some Tag {
        Div { content }
            .backgroundColor(.white)
            .borderRadius(.px(12))
            .padding(.px(24))
            .boxShadow("0 2px 8px rgba(0,0,0,0.08)")
    }
}

extension Tag {
    func card() -> ModifiedTag<CardModifier> {
        modifier(CardModifier())
    }
}

// MARK: - Components

struct NavBar: Tag {
    var body: some Tag {
        Div {
            H1 { "My App" }
                .fontSize(.rem(1.5))
                .foregroundColor(.white)

            Div {
                Link("/") { Text("Home") }
                    .foregroundColor(.white)
                    .textDecoration(.none)
                Link("/about") { Text("About") }
                    .foregroundColor(.white)
                    .textDecoration(.none)
            }
            .display(.flex)
            .gap(.px(24))
        }
        .display(.flex)
        .justifyContent(.spaceBetween)
        .alignItems(.center)
        .padding(.px(16), .px(32))
        .backgroundColor(.hex("#1a73e8"))
    }
}

struct HomePage: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            NavBar()

            Div {
                H2 { "Welcome" }
                    .fontSize(.rem(2))
                    .fontWeight(.w700)
                    .foregroundColor(.hex("#333"))

                Div {
                    Text("Count: \(count)")
                        .fontSize(.px(24))

                    Div {
                        Button(onclick: { count -= 1 }) { Text("-") }
                            .padding(.px(8), .px(16))
                            .fontSize(.px(20))
                            .cursor(.pointer)
                            .border(.px(1), .solid, .hex("#ccc"))
                            .borderRadius(.px(4))
                            .backgroundColor(.white)

                        Button(onclick: { count += 1 }) { Text("+") }
                            .padding(.px(8), .px(16))
                            .fontSize(.px(20))
                            .cursor(.pointer)
                            .border(.px(1), .solid, .hex("#ccc"))
                            .borderRadius(.px(4))
                            .backgroundColor(.white)
                    }
                    .display(.flex)
                    .gap(.px(12))
                    .alignItems(.center)
                }
                .card()
            }
            .maxWidth(.px(800))
            .margin(.px(32), .auto)
        }
        .style("font-family", "system-ui, sans-serif")
        .backgroundColor(.hex("#f5f5f5"))
        .minHeight(.vh(100))
    }
}
```

---

## Best Practices

### Use Type-Safe Modifiers When Available

Prefer type-safe modifiers over string fallbacks. They catch typos at compile time and provide autocomplete.

```swift
// Preferred
Div { content }.display(.flex)

// Avoid (unless no type-safe modifier exists)
Div { content }.style("display", "flex")
```

### Extract Reusable Styles into TagModifiers

If you apply the same style combination in multiple places, create a `TagModifier`:

```swift
// Instead of repeating this everywhere:
Div { content }
    .backgroundColor(.white)
    .borderRadius(.px(8))
    .padding(.px(16))
    .boxShadow("0 2px 4px rgba(0,0,0,0.1)")

// Define it once:
struct CardStyle: TagModifier { /* ... */ }
Div { content }.modifier(CardStyle())
```

### Use Consistent Units

Pick a primary unit system and use it consistently. `rem` is recommended for responsive designs because it scales with the root font size:

```swift
// Consistent rem-based spacing
Div { content }
    .padding(.rem(1))
    .margin(.rem(1.5))
    .gap(.rem(0.75))
    .fontSize(.rem(1))
    .borderRadius(.rem(0.5))
```

### Combine Classes with Inline Styles

Use `.class()` for external CSS framework integration and inline styles for component-specific overrides:

```swift
Div { content }
    .class("container")          // from external CSS
    .padding(.px(16))            // component-specific override
    .backgroundColor(.white)     // component-specific
```

---

## API Reference Summary

| Type | Module | Purpose |
|------|--------|---------|
| `ModifiedContent<Content>` | SwiftWUICore | Wraps a tag with inline styles, classes, and attributes |
| `CSSUnit` | SwiftWUIStyles | Type-safe CSS measurement units |
| `CSSColor` | SwiftWUIStyles | Type-safe CSS color values |
| `TagModifier` | SwiftWUICore | Protocol for reusable style/structure modifications |
| `ModifiedTag<Modifier>` | SwiftWUICore | Tag with a `TagModifier` applied |
| `Content` | SwiftWUICore | Placeholder for original content inside a `TagModifier` |
| `StyleSheet` | SwiftWUIStyles | External CSS stylesheet references |
| `Display` | SwiftWUIStyles | CSS display values |
| `Position` | SwiftWUIStyles | CSS position values |
| `FlexDirection` | SwiftWUIStyles | CSS flex-direction values |
| `JustifyContent` | SwiftWUIStyles | CSS justify-content values |
| `AlignItems` | SwiftWUIStyles | CSS align-items values |
| `FontWeight` | SwiftWUIStyles | CSS font-weight values |
| `BorderStyle` | SwiftWUIStyles | CSS border-style values |
| `Overflow` | SwiftWUIStyles | CSS overflow values |
| `Cursor` | SwiftWUIStyles | CSS cursor values |
| `Visibility` | SwiftWUIStyles | CSS visibility values |
