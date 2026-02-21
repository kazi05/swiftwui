# CSS Media Queries for SwiftWUI

**Date:** 2026-02-21
**Status:** Approved

## Problem

SwiftWUI uses inline styles exclusively (`ModifiedContent.styles` -> `TagNode.Element.styles` -> `element.style.property`). CSS media queries cannot work with inline styles — they require CSS rules in `<style>` tags with class selectors. Users need responsive designs with breakpoint-dependent styles.

## Solution: Two Complementary Tools

### Tool 1: `.media()` modifier (CSS-based, new)

Declarative modifier that generates CSS classes with `@media` rules. No re-render on resize — the browser applies styles natively via CSS.

**Use for:** responsive styles (font sizes, padding, layout direction, visibility).

```swift
Text("Hello")
    .fontSize(.px(24))
    .media(.compact) {
        $0.fontSize(.px(16))
          .padding(.px(8))
    }
```

### Tool 2: `@Environment(\.screenSize)` (JS runtime, existing)

Observable state that triggers re-render when viewport changes. Already implemented in `SwiftWUIBrowser/MediaQuery.swift`.

**Use for:** conditional rendering (different component trees per breakpoint).

```swift
struct AdaptiveNav: Tag {
    @Environment(\.screenSize) var screenSize
    var body: some Tag {
        if screenSize == .compact {
            MobileNav()
        } else {
            DesktopNav()
        }
    }
}
```

## Design

### 1. MediaQuery type (SwiftWUIStyles)

New file: `Sources/SwiftWUIStyles/MediaQuery.swift`

```swift
public indirect enum MediaQuery: Hashable, Sendable {
    // Size constraints
    case minWidth(CSSUnit)
    case maxWidth(CSSUnit)
    case minHeight(CSSUnit)
    case maxHeight(CSSUnit)

    // User preferences
    case colorScheme(ColorScheme)
    case prefersReducedMotion

    // Combinators
    case and(MediaQuery, MediaQuery)
    case or(MediaQuery, MediaQuery)
    case not(MediaQuery)

    // Predefined breakpoints (match ScreenSize from SwiftWUIBrowser)
    public static let compact  = MediaQuery.maxWidth(.px(767))
    public static let regular  = MediaQuery.and(.minWidth(.px(768)), .maxWidth(.px(1023)))
    public static let expanded = MediaQuery.minWidth(.px(1024))
}
```

`ColorScheme` is already defined in `SwiftWUIBrowser/MediaQuery.swift`. The CSS MediaQuery type references it via import.

The `cssString` computed property renders to valid CSS:

| Case | Output |
|------|--------|
| `.minWidth(.px(768))` | `@media (min-width: 768px)` |
| `.compact` | `@media (max-width: 767px)` |
| `.and(.minWidth(.px(768)), .maxWidth(.px(1023)))` | `@media (min-width: 768px) and (max-width: 1023px)` |
| `.colorScheme(.dark)` | `@media (prefers-color-scheme: dark)` |
| `.not(.prefersReducedMotion)` | `@media not (prefers-reduced-motion: reduce)` |

### 2. StyleProxy — modifier collector

New file: `Sources/SwiftWUIStyles/StyleProxy.swift`

```swift
public struct StyleProxy: Tag, TagNodeConvertible {
    public typealias Body = Never

    public func toTagNodes() -> [TagNode] {
        [.element(.init(tagName: "__proxy__"))]
    }
}
```

StyleProxy is an empty Tag. When style modifiers are applied (`.fontSize()`, `.padding()`, etc.), they produce `ModifiedContent<StyleProxy>`. Converting that to TagNodes merges all accumulated styles into the proxy element's `styles` dictionary — the existing `ModifiedContent.toTagNodes()` already handles this.

### 3. `.media()` modifier on Tag

New file: `Sources/SwiftWUIStyles/ResponsiveModifier.swift`

Extensions on `Tag` and `ModifiedContent`:

```swift
extension Tag {
    public func media(
        _ query: MediaQuery,
        apply: (StyleProxy) -> some Tag
    ) -> ModifiedContent<Self> {
        let styles = extractProxyStyles(apply)
        return ModifiedContent(
            content: self,
            responsiveStyles: [(query, styles)]
        )
    }
}

extension ModifiedContent {
    public func media(
        _ query: MediaQuery,
        apply: (StyleProxy) -> some Tag
    ) -> ModifiedContent<Content> {
        var copy = self
        let styles = extractProxyStyles(apply)
        copy.responsiveStyles.append((query, styles))
        return copy
    }
}

private func extractProxyStyles(
    _ apply: (StyleProxy) -> some Tag
) -> [(String, String)] {
    let result = apply(StyleProxy())
    let nodes = resolveTagBody(result)
    guard case .element(let el) = nodes.first else { return [] }
    return el.styles.sorted(by: { $0.key < $1.key })
                    .map { ($0.key, $0.value) }
}
```

### 4. Storage changes

**ModifiedContent** — add `responsiveStyles` field:

```swift
public struct ModifiedContent<Content: Tag>: Tag {
    public let content: Content
    public var styles: [(String, String)]
    public var classes: [String]
    public var attributes: [(String, String)]
    public var responsiveStyles: [(MediaQuery, [(String, String)])]  // NEW

    public init(
        content: Content,
        styles: [(String, String)] = [],
        classes: [String] = [],
        attributes: [(String, String)] = [],
        responsiveStyles: [(MediaQuery, [(String, String)])] = []  // NEW
    ) { ... }
}
```

**TagNode.Element** — add `responsiveStyles` field:

```swift
public struct Element: Equatable, Sendable {
    public var tagName: String
    public var attributes: [String: String]
    public var styles: [String: String]
    public var classes: [String]
    public var eventListeners: [String: EventListenerID]
    public var children: [TagNode]
    public var responsiveStyles: [String: [String: String]]  // NEW: cssQuery -> styles
}
```

Key: `responsiveStyles` uses `String` keys (the CSS query string) for `Equatable` conformance and deduplication.

**TagNodeConvertible** — merge responsive styles in `ModifiedContent.toTagNodes()`:

```swift
// Inside ModifiedContent.toTagNodes(), after merging inline styles:
for (query, rStyles) in responsiveStyles {
    let queryKey = query.cssString
    var existing = element.responsiveStyles[queryKey, default: [:]]
    for (property, value) in rStyles {
        existing[property] = value
    }
    element.responsiveStyles[queryKey] = existing
}
```

### 5. StyleSheetManager (Runtime)

New file: `Sources/SwiftWUIRuntime/StyleSheetManager.swift`

Manages a single `<style id="swiftwui-responsive">` element in `<head>`. Generates deterministic CSS class names from (mediaQuery + styles) hash.

```swift
final class StyleSheetManager {
    private var styleElement: JSObject?
    private var registeredRules: [String: String] = [:]  // className -> CSS text

    /// Ensure a CSS class exists for the given media query + styles.
    /// Returns the class name to add to the DOM element.
    func ensureClass(
        mediaQuery: String,
        styles: [String: String]
    ) -> String {
        let hash = stableHash(of: mediaQuery, styles: styles)
        let className = "swui-r\(hash)"

        if registeredRules[className] == nil {
            let declarations = styles.sorted(by: { $0.key < $1.key })
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "; ")
            let rule = "\(mediaQuery) { .\(className) { \(declarations) } }"
            registeredRules[className] = rule
            appendRule(rule)
        }

        return className
    }

    /// Remove a class rule if no longer used (optional, v2).
    func removeClassIfUnused(_ className: String) { ... }
}
```

Hash function: FNV-1a or similar lightweight hash producing a short hex string. Must be deterministic and stable across renders for proper reconciliation.

### 6. DOMRenderer changes

In `createDOMNode()` — when creating an element with `responsiveStyles`:

```swift
// After setting inline styles, classes, attributes...
for (cssQuery, rStyles) in element.responsiveStyles {
    let className = styleSheetManager.ensureClass(
        mediaQuery: cssQuery, styles: rStyles
    )
    bridge.addClass(domElement, className: className)
}
```

In `applyPatch()` — the existing `.updateClasses` patch handles class add/remove. The reconciler diffs `responsiveStyles` and translates changes into class additions/removals.

### 7. Reconciler changes

In `diffElements()` — add responsive styles diffing:

```swift
// Diff responsive styles -> translate to class changes
let oldResponsiveClasses = resolveResponsiveClasses(old.responsiveStyles)
let newResponsiveClasses = resolveResponsiveClasses(new.responsiveStyles)
// Merge with regular class diff
```

The reconciler converts `responsiveStyles` into CSS class names (via the same hash function) and diffs them as regular classes. No new patch types needed — reuses `.updateClasses`.

### 8. DOMBridge additions

New methods for `<style>` element management:

```swift
/// Create or get the responsive stylesheet element.
func getOrCreateStyleSheet(id: String) -> JSObject

/// Append a CSS rule string to a style element.
func appendCSSRule(_ styleElement: JSObject, rule: String)
```

### 9. Non-WASM testing support

`StyleSheetManager` needs a non-WASM stub (like DOMRenderer/DOMBridge) for testing on macOS. Unit tests verify:
- `MediaQuery.cssString` output
- `StyleProxy` style extraction
- `ModifiedContent` responsive style merging into `TagNode`
- `Reconciler` diffing of responsive styles
- Hash stability

Integration tests (WASM) verify actual DOM class application.

## File Changes Summary

| Action | File | Description |
|--------|------|-------------|
| Create | `Sources/SwiftWUIStyles/MediaQuery.swift` | MediaQuery enum with cssString |
| Create | `Sources/SwiftWUIStyles/StyleProxy.swift` | Empty Tag for collecting modifier styles |
| Create | `Sources/SwiftWUIStyles/ResponsiveModifier.swift` | `.media()` extensions on Tag + ModifiedContent |
| Create | `Sources/SwiftWUIRuntime/StyleSheetManager.swift` | `<style>` injection, CSS class generation |
| Modify | `Sources/SwiftWUICore/ModifiedContent.swift` | Add `responsiveStyles` field |
| Modify | `Sources/SwiftWUICore/TagNode.swift` | Add `responsiveStyles` to Element |
| Modify | `Sources/SwiftWUICore/TagNodeConvertible.swift` | Merge responsiveStyles in toTagNodes() |
| Modify | `Sources/SwiftWUIRuntime/Reconciler.swift` | Diff responsiveStyles as class changes |
| Modify | `Sources/SwiftWUIRuntime/DOMRenderer.swift` | Use StyleSheetManager for CSS injection |
| Modify | `Sources/SwiftWUIRuntime/DOMBridge.swift` | Add style element management methods |
| Create | `Tests/SwiftWUIStylesTests/MediaQueryTests.swift` | MediaQuery + StyleProxy + ResponsiveModifier tests |
| Create | `Tests/SwiftWUIRuntimeTests/StyleSheetManagerTests.swift` | Class generation + hash stability tests |

## Usage Examples

### Responsive layout

```swift
struct Dashboard: Tag {
    var body: some Tag {
        Div {
            Sidebar()
            MainContent()
        }
        .display(.flex)
        .gap(.px(24))
        .media(.compact) {
            $0.flexDirection(.column)
              .gap(.px(12))
        }
    }
}
```

### Custom breakpoint

```swift
H1 { "Title" }
    .fontSize(.px(48))
    .media(.maxWidth(.px(480))) {
        $0.fontSize(.px(20))
          .textAlign(.center)
    }
```

### Dark mode

```swift
Div { content }
    .backgroundColor(.hex("#ffffff"))
    .foregroundColor(.hex("#000000"))
    .media(.colorScheme(.dark)) {
        $0.backgroundColor(.hex("#1a1a1a"))
          .foregroundColor(.hex("#ffffff"))
    }
```

### Combined with @Environment for conditional rendering

```swift
struct ResponsivePage: Tag {
    @Environment(\.screenSize) var screenSize

    var body: some Tag {
        Div {
            // CSS media query — no re-render on resize
            H1 { "Welcome" }
                .fontSize(.px(48))
                .media(.compact) { $0.fontSize(.px(24)) }

            // JS runtime — conditional component tree
            if screenSize == .compact {
                MobileNavigation()
            } else {
                DesktopSidebar()
            }
        }
    }
}
```

### Reduced motion

```swift
Button(onclick: { toggle() }) { Text("Click") }
    .transition("transform 0.3s ease")
    .media(.prefersReducedMotion) {
        $0.transition("none")
    }
```
