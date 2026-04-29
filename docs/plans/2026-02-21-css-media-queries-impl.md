# CSS Media Queries Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `.media()` modifier to SwiftWUI that generates CSS classes with `@media` rules, injected via a `<style>` tag — enabling responsive styles without re-renders.

**Architecture:** A `StyleProxy` phantom tag collects styles via the existing modifier chain. `.media()` extracts those styles, stores them in `ModifiedContent.responsiveStyles`, which flow through `TagNode` → `Reconciler` → `DOMRenderer`. The renderer generates deterministic CSS class names, injects `@media` rules into a `<style>` element, and applies classes to DOM nodes. Existing `@Environment(\.screenSize)` remains for conditional rendering.

**Tech Stack:** Swift 6.0, SwiftWUICore/Styles/Runtime modules, JavaScriptKit (WASM runtime)

**Baseline:** 115 tests, 18 suites — all passing. Run `swift test` to verify.

---

## Task 1: Make CSSUnit Hashable

`MediaQuery` enum contains `CSSUnit` associated values and needs `Hashable` conformance. `CSSUnit` currently only conforms to `Sendable`.

**Files:**
- Modify: `Sources/SwiftWUIStyles/CSSUnit.swift:6` — add `Hashable, Equatable`
- Test: `Tests/SwiftWUIStylesTests/MediaQueryTests.swift` (created in Task 2)

**Step 1: Add conformances to CSSUnit**

In `Sources/SwiftWUIStyles/CSSUnit.swift`, change line 6 from:
```swift
public enum CSSUnit: Sendable {
```
to:
```swift
public enum CSSUnit: Sendable, Hashable, Equatable {
```

Swift auto-synthesizes `Hashable`/`Equatable` for enums with `Hashable` associated values (`Double` is `Hashable`). No manual implementation needed.

**Step 2: Verify all existing tests still pass**

Run: `swift test 2>&1 | tail -5`
Expected: `Test run with 115 tests in 18 suites passed`

**Step 3: Commit**

```bash
git add Sources/SwiftWUIStyles/CSSUnit.swift
git commit -m "feat: make CSSUnit Hashable and Equatable for MediaQuery support"
```

---

## Task 2: Create MediaQuery enum

The core type representing CSS media queries with cases for size constraints, preferences, and combinators.

**Files:**
- Create: `Sources/SwiftWUIStyles/MediaQuery.swift`
- Create: `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`

**Step 1: Write the failing tests**

Create `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`:

```swift
import Testing
@testable import SwiftWUICore
@testable import SwiftWUIStyles

@Suite("MediaQuery Tests")
struct MediaQueryTests {

    // MARK: - cssString output

    @Test("minWidth produces correct CSS")
    func minWidth() {
        let mq = MediaQuery.minWidth(.px(768))
        #expect(mq.cssString == "@media (min-width: 768px)")
    }

    @Test("maxWidth produces correct CSS")
    func maxWidth() {
        let mq = MediaQuery.maxWidth(.px(767))
        #expect(mq.cssString == "@media (max-width: 767px)")
    }

    @Test("minHeight produces correct CSS")
    func minHeight() {
        let mq = MediaQuery.minHeight(.vh(50))
        #expect(mq.cssString == "@media (min-height: 50vh)")
    }

    @Test("maxHeight produces correct CSS")
    func maxHeight() {
        let mq = MediaQuery.maxHeight(.px(600))
        #expect(mq.cssString == "@media (max-height: 600px)")
    }

    @Test("colorScheme dark produces correct CSS")
    func colorSchemeDark() {
        let mq = MediaQuery.colorScheme(.dark)
        #expect(mq.cssString == "@media (prefers-color-scheme: dark)")
    }

    @Test("colorScheme light produces correct CSS")
    func colorSchemeLight() {
        let mq = MediaQuery.colorScheme(.light)
        #expect(mq.cssString == "@media (prefers-color-scheme: light)")
    }

    @Test("prefersReducedMotion produces correct CSS")
    func prefersReducedMotion() {
        let mq = MediaQuery.prefersReducedMotion
        #expect(mq.cssString == "@media (prefers-reduced-motion: reduce)")
    }

    @Test("and combinator produces correct CSS")
    func andCombinator() {
        let mq = MediaQuery.and(.minWidth(.px(768)), .maxWidth(.px(1023)))
        #expect(mq.cssString == "@media (min-width: 768px) and (max-width: 1023px)")
    }

    @Test("or combinator produces correct CSS")
    func orCombinator() {
        let mq = MediaQuery.or(.maxWidth(.px(480)), .minWidth(.px(1200)))
        #expect(mq.cssString == "@media (max-width: 480px), (min-width: 1200px)")
    }

    @Test("not combinator produces correct CSS")
    func notCombinator() {
        let mq = MediaQuery.not(.prefersReducedMotion)
        #expect(mq.cssString == "@media not (prefers-reduced-motion: reduce)")
    }

    // MARK: - Predefined breakpoints

    @Test("compact breakpoint")
    func compactBreakpoint() {
        #expect(MediaQuery.compact.cssString == "@media (max-width: 767px)")
    }

    @Test("regular breakpoint")
    func regularBreakpoint() {
        #expect(MediaQuery.regular.cssString == "@media (min-width: 768px) and (max-width: 1023px)")
    }

    @Test("expanded breakpoint")
    func expandedBreakpoint() {
        #expect(MediaQuery.expanded.cssString == "@media (min-width: 1024px)")
    }

    // MARK: - Hashable conformance

    @Test("MediaQuery is Hashable — equal values hash equally")
    func hashable() {
        let a = MediaQuery.minWidth(.px(768))
        let b = MediaQuery.minWidth(.px(768))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("MediaQuery is Hashable — different values differ")
    func hashableDiffers() {
        let a = MediaQuery.minWidth(.px(768))
        let b = MediaQuery.minWidth(.px(1024))
        #expect(a != b)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter MediaQueryTests 2>&1 | tail -5`
Expected: compilation error — `MediaQuery` type not found.

**Step 3: Implement MediaQuery**

Create `Sources/SwiftWUIStyles/MediaQuery.swift`:

```swift
// MediaQuery.swift - CSS media query type for responsive styles

import SwiftWUICore

/// Represents a CSS `@media` query for responsive design.
///
/// Use with the `.media()` modifier to apply styles conditionally:
/// ```swift
/// Text("Hello")
///     .fontSize(.px(24))
///     .media(.compact) { $0.fontSize(.px(16)) }
/// ```
///
/// Predefined breakpoints match `ScreenSize` from SwiftWUIBrowser:
/// - `.compact`  — max-width: 767px (mobile)
/// - `.regular`  — 768–1023px (tablet)
/// - `.expanded` — min-width: 1024px (desktop)
public indirect enum MediaQuery: Hashable, Sendable {

    // MARK: - Size Constraints

    case minWidth(CSSUnit)
    case maxWidth(CSSUnit)
    case minHeight(CSSUnit)
    case maxHeight(CSSUnit)

    // MARK: - User Preferences

    /// Color scheme preference. Uses its own enum to avoid
    /// cross-module dependency on SwiftWUIBrowser.
    case colorScheme(ColorSchemeValue)
    case prefersReducedMotion

    // MARK: - Combinators

    case and(MediaQuery, MediaQuery)
    case or(MediaQuery, MediaQuery)
    case not(MediaQuery)

    // MARK: - Predefined Breakpoints

    /// Mobile: max-width 767px. Matches `ScreenSize.compact`.
    public static let compact  = MediaQuery.maxWidth(.px(767))
    /// Tablet: 768–1023px. Matches `ScreenSize.regular`.
    public static let regular  = MediaQuery.and(.minWidth(.px(768)), .maxWidth(.px(1023)))
    /// Desktop: min-width 1024px. Matches `ScreenSize.expanded`.
    public static let expanded = MediaQuery.minWidth(.px(1024))

    // MARK: - Color Scheme

    /// Color scheme values for media queries.
    /// Separate from `SwiftWUIBrowser.ColorScheme` to avoid cross-module dependency.
    public enum ColorSchemeValue: String, Hashable, Sendable {
        case light
        case dark
    }

    // MARK: - CSS Output

    /// The full CSS `@media` string, e.g. `@media (min-width: 768px)`.
    public var cssString: String {
        "@media \(condition)"
    }

    /// The inner condition without the `@media` prefix.
    /// Used for building compound queries.
    var condition: String {
        switch self {
        case .minWidth(let unit):
            return "(min-width: \(unit.cssValue))"
        case .maxWidth(let unit):
            return "(max-width: \(unit.cssValue))"
        case .minHeight(let unit):
            return "(min-height: \(unit.cssValue))"
        case .maxHeight(let unit):
            return "(max-height: \(unit.cssValue))"
        case .colorScheme(let scheme):
            return "(prefers-color-scheme: \(scheme.rawValue))"
        case .prefersReducedMotion:
            return "(prefers-reduced-motion: reduce)"
        case .and(let lhs, let rhs):
            return "\(lhs.condition) and \(rhs.condition)"
        case .or(let lhs, let rhs):
            return "\(lhs.condition), \(rhs.condition)"
        case .not(let query):
            return "not \(query.condition)"
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter MediaQueryTests 2>&1 | tail -5`
Expected: all MediaQuery tests PASS.

**Step 5: Run full test suite**

Run: `swift test 2>&1 | tail -5`
Expected: 115 + 15 = ~130 tests pass.

**Step 6: Commit**

```bash
git add Sources/SwiftWUIStyles/MediaQuery.swift Tests/SwiftWUIStylesTests/MediaQueryTests.swift
git commit -m "feat: add MediaQuery enum with CSS output and predefined breakpoints"
```

---

## Task 3: Add responsiveStyles to ModifiedContent and TagNode

Extend the storage types to carry responsive style data through the pipeline.

**Files:**
- Modify: `Sources/SwiftWUICore/ModifiedContent.swift`
- Modify: `Sources/SwiftWUICore/TagNode.swift`

**Step 1: Write failing test**

Add to `Tests/SwiftWUIStylesTests/MediaQueryTests.swift` (below existing suite):

```swift
@Suite("ModifiedContent Responsive Styles")
struct ModifiedContentResponsiveTests {

    @Test("ModifiedContent can store responsiveStyles")
    func storesResponsiveStyles() {
        let text = Text("Hello")
        let mc = ModifiedContent(
            content: text,
            styles: [("color", "red")],
            responsiveStyles: [("@media (max-width: 767px)", [("font-size", "16px")])]
        )
        #expect(mc.responsiveStyles.count == 1)
        #expect(mc.responsiveStyles[0].0 == "@media (max-width: 767px)")
        #expect(mc.responsiveStyles[0].1 == [("font-size", "16px")])
    }

    @Test("ModifiedContent defaults responsiveStyles to empty")
    func defaultsEmpty() {
        let text = Text("Hello")
        let mc = ModifiedContent(content: text, styles: [("color", "red")])
        #expect(mc.responsiveStyles.isEmpty)
    }
}

@Suite("TagNode Responsive Styles")
struct TagNodeResponsiveTests {

    @Test("Element stores responsiveStyles")
    func elementStoresResponsiveStyles() {
        let el = TagNode.Element(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "16px"]]
        )
        #expect(el.responsiveStyles.count == 1)
        #expect(el.responsiveStyles["@media (max-width: 767px)"] == ["font-size": "16px"])
    }

    @Test("Element defaults responsiveStyles to empty")
    func defaultsEmpty() {
        let el = TagNode.Element(tagName: "div")
        #expect(el.responsiveStyles.isEmpty)
    }

    @Test("Elements with different responsiveStyles are not equal")
    func equalityDiffers() {
        let a = TagNode.Element(tagName: "div", responsiveStyles: ["@media (max-width: 767px)": ["color": "red"]])
        let b = TagNode.Element(tagName: "div", responsiveStyles: [:])
        #expect(a != b)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter "ModifiedContentResponsive|TagNodeResponsive" 2>&1 | tail -10`
Expected: compilation error — `responsiveStyles` argument not found.

**Step 3: Add responsiveStyles to ModifiedContent**

In `Sources/SwiftWUICore/ModifiedContent.swift`, replace the struct and init:

```swift
public struct ModifiedContent<Content: Tag>: Tag {
    public typealias Body = Never

    public let content: Content
    public var styles: [(String, String)]
    public var classes: [String]
    public var attributes: [(String, String)]
    /// Responsive styles keyed by CSS media query string.
    /// Each entry is (cssQueryString, [(property, value)]).
    public var responsiveStyles: [(String, [(String, String)])]

    public init(
        content: Content,
        styles: [(String, String)] = [],
        classes: [String] = [],
        attributes: [(String, String)] = [],
        responsiveStyles: [(String, [(String, String)])] = []
    ) {
        self.content = content
        self.styles = styles
        self.classes = classes
        self.attributes = attributes
        self.responsiveStyles = responsiveStyles
    }
}
```

**Important:** `responsiveStyles` stores `String` keys (the `cssString` output), NOT `MediaQuery` values. This avoids a dependency from SwiftWUICore on SwiftWUIStyles, and keeps `ModifiedContent` in the Core module. The `.media()` modifier (in SwiftWUIStyles) calls `query.cssString` before storing.

**Step 4: Add responsiveStyles to TagNode.Element**

In `Sources/SwiftWUICore/TagNode.swift`, add the field to `Element` and update `init`:

```swift
    public struct Element: Equatable, Sendable {
        public var tagName: String
        public var attributes: [String: String]
        public var styles: [String: String]
        public var classes: [String]
        public var eventListeners: [String: EventListenerID]
        public var children: [TagNode]
        /// Responsive CSS styles. Key = CSS media query string, Value = style declarations.
        public var responsiveStyles: [String: [String: String]]

        public init(
            tagName: String,
            attributes: [String: String] = [:],
            styles: [String: String] = [:],
            classes: [String] = [],
            eventListeners: [String: EventListenerID] = [:],
            children: [TagNode] = [],
            responsiveStyles: [String: [String: String]] = [:]
        ) {
            self.tagName = tagName
            self.attributes = attributes
            self.styles = styles
            self.classes = classes
            self.eventListeners = eventListeners
            self.children = children
            self.responsiveStyles = responsiveStyles
        }
    }
```

**Step 5: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass (existing + new). The new init parameter has a default value, so all existing call sites compile unchanged.

**Step 6: Commit**

```bash
git add Sources/SwiftWUICore/ModifiedContent.swift Sources/SwiftWUICore/TagNode.swift Tests/SwiftWUIStylesTests/MediaQueryTests.swift
git commit -m "feat: add responsiveStyles storage to ModifiedContent and TagNode.Element"
```

---

## Task 4: Merge responsiveStyles in TagNodeConvertible

When `ModifiedContent.toTagNodes()` runs, merge `responsiveStyles` into the underlying `TagNode.Element.responsiveStyles`.

**Files:**
- Modify: `Sources/SwiftWUICore/TagNodeConvertible.swift:71-101`
- Test: `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`

**Step 1: Write failing test**

Add to `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`:

```swift
@Suite("Responsive Style Merging")
struct ResponsiveStyleMergingTests {

    @Test("ModifiedContent merges responsiveStyles into TagNode")
    func mergesIntoTagNode() {
        let text = Text("Hello")
        let mc = ModifiedContent(
            content: text.style("color", "red"),
            responsiveStyles: [("@media (max-width: 767px)", [("font-size", "16px")])]
        )
        let nodes = mc.toTagNodes()

        // The text node gets wrapped by .style("color","red") first, but Text doesn't produce
        // an element node — it produces a text node. So responsiveStyles won't apply to text nodes.
        // Let's test with an element-producing tag instead.
        // Actually, text.style() wraps in ModifiedContent which produces an element? No.
        // ModifiedContent.toTagNodes() maps over baseNodes and only modifies .element nodes.
        // Text produces .text nodes, so styles on Text don't apply to the text node itself.
        // We need to test with a tag that produces an element node.
    }
}
```

Actually, let's write a correct test using the HTML Div tag:

```swift
import SwiftWUIHTML

@Suite("Responsive Style Merging")
struct ResponsiveStyleMergingTests {

    @Test("responsiveStyles merge into TagNode element")
    func mergesResponsiveStyles() {
        let div = Div { Text("Hello") }
        let mc = ModifiedContent(
            content: div,
            responsiveStyles: [("@media (max-width: 767px)", [("font-size", "16px")])]
        )
        let nodes = mc.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.responsiveStyles["@media (max-width: 767px)"] == ["font-size": "16px"])
    }

    @Test("multiple responsiveStyles for same query merge")
    func mergesMultipleForSameQuery() {
        let div = Div { Text("Hello") }
        let mc = ModifiedContent(
            content: div,
            responsiveStyles: [
                ("@media (max-width: 767px)", [("font-size", "16px")]),
                ("@media (max-width: 767px)", [("padding", "8px")]),
            ]
        )
        let nodes = mc.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let responsive = el.responsiveStyles["@media (max-width: 767px)"]!
        #expect(responsive["font-size"] == "16px")
        #expect(responsive["padding"] == "8px")
    }

    @Test("responsiveStyles for different queries stay separate")
    func separateQueries() {
        let div = Div { Text("Hello") }
        let mc = ModifiedContent(
            content: div,
            responsiveStyles: [
                ("@media (max-width: 767px)", [("font-size", "16px")]),
                ("@media (min-width: 1024px)", [("font-size", "32px")]),
            ]
        )
        let nodes = mc.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.responsiveStyles.count == 2)
        #expect(el.responsiveStyles["@media (max-width: 767px)"] == ["font-size": "16px"])
        #expect(el.responsiveStyles["@media (min-width: 1024px)"] == ["font-size": "32px"])
    }
}
```

**Note:** This test needs `import SwiftWUIHTML`. Check the test target dependencies first. Currently `SwiftWUIStylesTests` depends only on `SwiftWUIStyles`. We need to add `SwiftWUIHTML` to the test target dependencies in `Package.swift`.

Add to `Package.swift` — change the SwiftWUIStylesTests line:
```swift
        .testTarget(
            name: "SwiftWUIStylesTests",
            dependencies: ["SwiftWUIStyles", "SwiftWUIHTML"]
        ),
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ResponsiveStyleMerging 2>&1 | tail -10`
Expected: FAIL — `responsiveStyles` is empty because `toTagNodes()` doesn't merge them yet.

**Step 3: Update ModifiedContent.toTagNodes()**

In `Sources/SwiftWUICore/TagNodeConvertible.swift`, replace the `ModifiedContent` extension (lines 71-101):

```swift
extension ModifiedContent: TagNodeConvertible {
    public func toTagNodes() -> [TagNode] {
        // Get the base nodes from the content
        let baseNodes: [TagNode]
        if let convertible = content as? TagNodeConvertible {
            baseNodes = convertible.toTagNodes()
        } else {
            baseNodes = resolveTagBody(content)
        }

        // Apply modifications to each element node
        return baseNodes.map { node in
            guard case .element(var element) = node else { return node }

            // Merge styles
            for (property, value) in styles {
                element.styles[property] = value
            }

            // Merge classes
            element.classes.append(contentsOf: classes)

            // Merge attributes
            for (name, value) in attributes {
                element.attributes[name] = value
            }

            // Merge responsive styles
            for (queryKey, rStyles) in responsiveStyles {
                var existing = element.responsiveStyles[queryKey, default: [:]]
                for (property, value) in rStyles {
                    existing[property] = value
                }
                element.responsiveStyles[queryKey] = existing
            }

            return .element(element)
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass.

**Step 5: Commit**

```bash
git add Sources/SwiftWUICore/TagNodeConvertible.swift Tests/SwiftWUIStylesTests/MediaQueryTests.swift Package.swift
git commit -m "feat: merge responsiveStyles through TagNode pipeline"
```

---

## Task 5: Create StyleProxy

Empty tag that serves as a carrier for style modifiers, enabling `.media()` to extract styles from the modifier chain.

**Files:**
- Create: `Sources/SwiftWUIStyles/StyleProxy.swift`
- Test: `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`

**Step 1: Write failing test**

Add to `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`:

```swift
@Suite("StyleProxy Tests")
struct StyleProxyTests {

    @Test("StyleProxy produces a single proxy element node")
    func producesProxyElement() {
        let proxy = StyleProxy()
        let nodes = proxy.toTagNodes()
        #expect(nodes.count == 1)
        if case .element(let el) = nodes[0] {
            #expect(el.tagName == "__proxy__")
            #expect(el.styles.isEmpty)
        } else {
            Issue.record("Expected element node")
        }
    }

    @Test("StyleProxy with modifiers collects styles")
    func collectsStyles() {
        let modified = StyleProxy()
            .fontSize(.px(16))
            .padding(.px(8))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.styles["font-size"] == "16px")
        #expect(el.styles["padding"] == "8px")
    }

    @Test("StyleProxy with chained modifiers collects all styles")
    func chainsModifiers() {
        let modified = StyleProxy()
            .backgroundColor(.hex("#1a1a1a"))
            .foregroundColor(.white)
            .display(.flex)
            .borderRadius(.px(8))
        let nodes = resolveTagBody(modified)
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.styles.count == 4)
        #expect(el.styles["background-color"] == "#1a1a1a")
        #expect(el.styles["color"] == "#ffffff")
        #expect(el.styles["display"] == "flex")
        #expect(el.styles["border-radius"] == "8px")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter StyleProxyTests 2>&1 | tail -5`
Expected: compilation error — `StyleProxy` not found.

**Step 3: Implement StyleProxy**

Create `Sources/SwiftWUIStyles/StyleProxy.swift`:

```swift
// StyleProxy.swift - Phantom tag for collecting modifier styles

import SwiftWUICore

/// A phantom tag used internally by `.media()` to collect styles from the modifier chain.
///
/// `StyleProxy` is an empty tag that produces a placeholder element. When style
/// modifiers are applied to it, they accumulate in a `ModifiedContent` wrapper.
/// The `.media()` modifier converts the result to `TagNode`s and extracts the
/// collected styles from the placeholder element.
///
/// You don't use `StyleProxy` directly — it is passed as `$0` in the `.media()` closure:
/// ```swift
/// Text("Hello")
///     .media(.compact) { $0.fontSize(.px(16)) }
///     //                  ^^ this is a StyleProxy
/// ```
public struct StyleProxy: Tag, TagNodeConvertible {
    public typealias Body = Never

    public init() {}

    public func toTagNodes() -> [TagNode] {
        [.element(.init(tagName: "__proxy__"))]
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter StyleProxyTests 2>&1 | tail -5`
Expected: all StyleProxy tests PASS.

**Step 5: Run full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass.

**Step 6: Commit**

```bash
git add Sources/SwiftWUIStyles/StyleProxy.swift Tests/SwiftWUIStylesTests/MediaQueryTests.swift
git commit -m "feat: add StyleProxy phantom tag for collecting modifier styles"
```

---

## Task 6: Create ResponsiveModifier (.media() on Tag)

The `.media()` extension on `Tag` and `ModifiedContent` that ties everything together.

**Files:**
- Create: `Sources/SwiftWUIStyles/ResponsiveModifier.swift`
- Test: `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`

**Step 1: Write failing test**

Add to `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`:

```swift
@Suite("ResponsiveModifier Tests")
struct ResponsiveModifierTests {

    @Test(".media() on Tag stores responsive styles")
    func mediaOnTag() {
        let div = Div { Text("Hello") }
        let modified = div.media(.compact) {
            $0.fontSize(.px(16))
        }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let query = MediaQuery.compact.cssString
        #expect(el.responsiveStyles[query] != nil)
        #expect(el.responsiveStyles[query]!["font-size"] == "16px")
    }

    @Test(".media() on ModifiedContent chains correctly")
    func mediaOnModifiedContent() {
        let div = Div { Text("Hello") }
        let modified = div
            .padding(.px(32))
            .media(.compact) {
                $0.padding(.px(16))
                  .fontSize(.px(14))
            }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        // Inline style
        #expect(el.styles["padding"] == "32px")
        // Responsive styles
        let query = MediaQuery.compact.cssString
        #expect(el.responsiveStyles[query]!["padding"] == "16px")
        #expect(el.responsiveStyles[query]!["font-size"] == "14px")
    }

    @Test("Multiple .media() calls for different breakpoints")
    func multipleBreakpoints() {
        let div = Div { Text("Hello") }
        let modified = div
            .fontSize(.px(24))
            .media(.compact) { $0.fontSize(.px(16)) }
            .media(.expanded) { $0.fontSize(.px(32)) }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        #expect(el.responsiveStyles.count == 2)
        #expect(el.responsiveStyles[MediaQuery.compact.cssString]!["font-size"] == "16px")
        #expect(el.responsiveStyles[MediaQuery.expanded.cssString]!["font-size"] == "32px")
    }

    @Test(".media() with custom breakpoint")
    func customBreakpoint() {
        let div = Div { Text("Hello") }
        let modified = div.media(.maxWidth(.px(480))) {
            $0.display(.none)
        }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let query = MediaQuery.maxWidth(.px(480)).cssString
        #expect(el.responsiveStyles[query]!["display"] == "none")
    }

    @Test(".media() with .style() fallback works")
    func styleFallback() {
        let div = Div { Text("Hello") }
        let modified = div.media(.compact) {
            $0.style("gap", "12px")
        }
        let nodes = modified.toTagNodes()
        guard case .element(let el) = nodes.first else {
            Issue.record("Expected element node")
            return
        }
        let query = MediaQuery.compact.cssString
        #expect(el.responsiveStyles[query]!["gap"] == "12px")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ResponsiveModifierTests 2>&1 | tail -5`
Expected: compilation error — no `media` method on Tag.

**Step 3: Implement ResponsiveModifier**

Create `Sources/SwiftWUIStyles/ResponsiveModifier.swift`:

```swift
// ResponsiveModifier.swift - .media() modifier for responsive CSS styles

import SwiftWUICore

// MARK: - Tag Extension

extension Tag {
    /// Apply styles conditionally under a CSS media query.
    ///
    /// The closure receives a `StyleProxy` — apply any style modifiers to it.
    /// Those styles will only take effect when the media query matches.
    ///
    /// ```swift
    /// Text("Hello")
    ///     .fontSize(.px(24))
    ///     .media(.compact) { $0.fontSize(.px(16)) }
    /// ```
    public func media<T: Tag>(
        _ query: MediaQuery,
        apply: (StyleProxy) -> T
    ) -> ModifiedContent<Self> {
        let styles = extractProxyStyles(apply)
        return ModifiedContent(
            content: self,
            responsiveStyles: [(query.cssString, styles)]
        )
    }
}

// MARK: - ModifiedContent Extension

extension ModifiedContent {
    /// Apply styles conditionally under a CSS media query (chainable).
    public func media<T: Tag>(
        _ query: MediaQuery,
        apply: (StyleProxy) -> T
    ) -> ModifiedContent<Content> {
        var copy = self
        let styles = extractProxyStyles(apply)
        copy.responsiveStyles.append((query.cssString, styles))
        return copy
    }
}

// MARK: - Style Extraction

/// Runs the closure with a StyleProxy, converts the result to TagNodes,
/// and extracts the accumulated inline styles from the proxy element.
private func extractProxyStyles<T: Tag>(
    _ apply: (StyleProxy) -> T
) -> [(String, String)] {
    let result = apply(StyleProxy())
    let nodes = resolveTagBody(result)
    guard case .element(let el) = nodes.first else { return [] }
    return el.styles
        .sorted(by: { $0.key < $1.key })
        .map { ($0.key, $0.value) }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ResponsiveModifierTests 2>&1 | tail -5`
Expected: all ResponsiveModifier tests PASS.

**Step 5: Run full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass.

**Step 6: Commit**

```bash
git add Sources/SwiftWUIStyles/ResponsiveModifier.swift Tests/SwiftWUIStylesTests/MediaQueryTests.swift
git commit -m "feat: add .media() modifier for responsive CSS styles"
```

---

## Task 7: Add hash function and Reconciler support

Add FNV-1a hash for deterministic CSS class names. Update Reconciler to diff `responsiveStyles` as class changes.

**Files:**
- Create: `Sources/SwiftWUICore/ResponsiveHash.swift`
- Modify: `Sources/SwiftWUIRuntime/Reconciler.swift`
- Test: `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`

**Step 1: Write failing tests**

Add to `Tests/SwiftWUIStylesTests/MediaQueryTests.swift`:

```swift
@Suite("Responsive Hash Tests")
struct ResponsiveHashTests {

    @Test("Same input produces same hash")
    func deterministic() {
        let a = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        let b = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        #expect(a == b)
    }

    @Test("Different inputs produce different hashes")
    func differs() {
        let a = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        let b = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "24px"])
        #expect(a != b)
    }

    @Test("Class name starts with swui-r prefix")
    func prefix() {
        let name = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px"])
        #expect(name.hasPrefix("swui-r"))
    }

    @Test("Style order does not affect hash")
    func orderIndependent() {
        let a = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["font-size": "16px", "padding": "8px"])
        let b = responsiveClassName(mediaQuery: "@media (max-width: 767px)", styles: ["padding": "8px", "font-size": "16px"])
        #expect(a == b)
    }
}
```

Also add a Reconciler test file. Create `Tests/SwiftWUICoreTests/ReconcilerResponsiveTests.swift`:

```swift
import Testing
@testable import SwiftWUICore

@Suite("Reconciler Responsive Styles")
struct ReconcilerResponsiveTests {

    let reconciler = Reconciler()

    @Test("Adding responsive styles produces class changes")
    func addResponsiveStyles() {
        let old = TagNode.element(.init(tagName: "div"))
        let new = TagNode.element(.init(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "16px"]]
        ))
        let patch = reconciler.diff(old: old, new: new)
        // Should produce updateClasses (or patchChildren containing it)
        #expect(patch != nil)
    }

    @Test("Removing responsive styles produces class changes")
    func removeResponsiveStyles() {
        let old = TagNode.element(.init(
            tagName: "div",
            responsiveStyles: ["@media (max-width: 767px)": ["font-size": "16px"]]
        ))
        let new = TagNode.element(.init(tagName: "div"))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch != nil)
    }

    @Test("Unchanged responsive styles produce no patch")
    func unchangedResponsiveStyles() {
        let styles: [String: [String: String]] = ["@media (max-width: 767px)": ["font-size": "16px"]]
        let old = TagNode.element(.init(tagName: "div", responsiveStyles: styles))
        let new = TagNode.element(.init(tagName: "div", responsiveStyles: styles))
        let patch = reconciler.diff(old: old, new: new)
        #expect(patch == nil)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter "ResponsiveHash|ReconcilerResponsive" 2>&1 | tail -10`
Expected: compilation errors — `responsiveClassName` not found, reconciler doesn't diff responsiveStyles.

**Step 3: Implement hash function**

Create `Sources/SwiftWUICore/ResponsiveHash.swift`:

```swift
// ResponsiveHash.swift - Deterministic CSS class name generation for responsive styles

/// Generates a deterministic CSS class name from a media query string and style declarations.
///
/// Uses FNV-1a hash for fast, stable hashing. The same inputs always produce the same
/// class name, enabling the Reconciler to diff responsive styles as class changes.
///
/// - Parameters:
///   - mediaQuery: The CSS media query string (e.g., `@media (max-width: 767px)`).
///   - styles: Style declarations to include in the hash.
/// - Returns: A class name like `swui-r1a2b3c4d5e6f7g8`.
public func responsiveClassName(mediaQuery: String, styles: [String: String]) -> String {
    let sortedDeclarations = styles
        .sorted(by: { $0.key < $1.key })
        .map { "\($0.key):\($0.value)" }
        .joined(separator: ";")
    let input = "\(mediaQuery){\(sortedDeclarations)}"

    // FNV-1a 64-bit hash
    var hash: UInt64 = 14695981039346656037 // FNV offset basis
    for byte in input.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1099511628211 // FNV prime
    }

    return "swui-r\(String(hash, radix: 16))"
}

/// Convert responsive styles dictionary to a set of CSS class names.
///
/// Used by the Reconciler to translate `TagNode.Element.responsiveStyles`
/// into class names for diffing.
public func responsiveClassNames(for responsiveStyles: [String: [String: String]]) -> Set<String> {
    Set(responsiveStyles.map { (query, styles) in
        responsiveClassName(mediaQuery: query, styles: styles)
    })
}
```

**Step 4: Update Reconciler to diff responsiveStyles**

In `Sources/SwiftWUIRuntime/Reconciler.swift`, in the `diffElements` method (after the existing class diff section around line 93-99), add responsive style diffing. Replace the class diff block:

Find (lines ~93-99):
```swift
        // Diff classes
        let oldClasses = Set(old.classes)
        let newClasses = Set(new.classes)
        let addClasses = Array(newClasses.subtracting(oldClasses))
        let removeClasses = Array(oldClasses.subtracting(newClasses))
        if !addClasses.isEmpty || !removeClasses.isEmpty {
            patches.append(.updateClasses(add: addClasses, remove: removeClasses))
        }
```

Replace with:
```swift
        // Diff classes (including generated responsive style classes)
        let oldResponsiveClasses = responsiveClassNames(for: old.responsiveStyles)
        let newResponsiveClasses = responsiveClassNames(for: new.responsiveStyles)
        let oldAllClasses = Set(old.classes).union(oldResponsiveClasses)
        let newAllClasses = Set(new.classes).union(newResponsiveClasses)
        let addClasses = Array(newAllClasses.subtracting(oldAllClasses))
        let removeClasses = Array(oldAllClasses.subtracting(newAllClasses))
        if !addClasses.isEmpty || !removeClasses.isEmpty {
            patches.append(.updateClasses(add: addClasses, remove: removeClasses))
        }
```

**Step 5: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass.

**Step 6: Commit**

```bash
git add Sources/SwiftWUICore/ResponsiveHash.swift Sources/SwiftWUIRuntime/Reconciler.swift Tests/SwiftWUIStylesTests/MediaQueryTests.swift Tests/SwiftWUICoreTests/ReconcilerResponsiveTests.swift
git commit -m "feat: add responsive hash + reconciler support for responsive styles"
```

---

## Task 8: Create StyleSheetManager and integrate with DOMRenderer

The runtime component that manages `<style>` injection and CSS class application.

**Files:**
- Create: `Sources/SwiftWUIRuntime/StyleSheetManager.swift`
- Modify: `Sources/SwiftWUIRuntime/DOMBridge.swift`
- Modify: `Sources/SwiftWUIRuntime/DOMRenderer.swift`

**Step 1: Add DOMBridge methods for style element management**

In `Sources/SwiftWUIRuntime/DOMBridge.swift`, inside the `#if canImport(JavaScriptKit)` block, before the `#else` line, add:

```swift
    // MARK: - Style Sheet Management

    /// Get or create a `<style>` element with the given ID in `<head>`.
    public func getOrCreateStyleElement(id: String) -> JSObject {
        if let existing = document.getElementById!(id).object {
            return existing
        }
        let style = document.createElement!("style").object!
        _ = style.setAttribute!("id", id)
        let head = document.head.object ?? document.getElementsByTagName!("head").object![0].object!
        _ = head.appendChild!(style)
        return style
    }

    /// Append a CSS rule text to a `<style>` element.
    public func appendCSSRule(_ styleElement: JSObject, rule: String) {
        let current = styleElement.textContent.string ?? ""
        styleElement.textContent = .string(current + "\n" + rule)
    }
```

**Step 2: Create StyleSheetManager**

Create `Sources/SwiftWUIRuntime/StyleSheetManager.swift`:

```swift
// StyleSheetManager.swift - Manages responsive CSS rules via <style> injection

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

import SwiftWUICore

/// Manages a `<style>` element for responsive CSS rules.
///
/// When the DOMRenderer encounters `responsiveStyles` on a TagNode element,
/// it calls `ensureClass()` to get a CSS class name. The manager generates
/// the class deterministically (via FNV-1a hash) and injects the `@media`
/// rule into the `<style>` tag if it hasn't been registered yet.
public final class StyleSheetManager {

    #if canImport(JavaScriptKit)
    private let bridge: DOMBridge
    private var styleElement: JSObject?
    #endif

    /// Tracks registered CSS class names to avoid duplicate rule injection.
    private var registeredRules: Set<String> = []

    #if canImport(JavaScriptKit)
    public init(bridge: DOMBridge) {
        self.bridge = bridge
    }
    #else
    public init() {}
    #endif

    /// Ensure a CSS class exists for the given responsive style.
    ///
    /// If the class has already been registered, returns the same name without
    /// injecting a duplicate rule. Otherwise, generates the CSS rule and appends
    /// it to the `<style>` element.
    ///
    /// - Parameters:
    ///   - mediaQuery: The CSS `@media` query string.
    ///   - styles: The CSS property-value declarations.
    /// - Returns: The CSS class name to apply to the DOM element.
    public func ensureClass(mediaQuery: String, styles: [String: String]) -> String {
        let className = responsiveClassName(mediaQuery: mediaQuery, styles: styles)

        guard !registeredRules.contains(className) else {
            return className
        }

        registeredRules.insert(className)

        let declarations = styles
            .sorted(by: { $0.key < $1.key })
            .map { "  \($0.key): \($0.value) !important;" }
            .joined(separator: "\n")
        let rule = "\(mediaQuery) {\n  .\(className) {\n\(declarations)\n  }\n}"

        #if canImport(JavaScriptKit) && arch(wasm32)
        if styleElement == nil {
            styleElement = bridge.getOrCreateStyleElement(id: "swiftwui-responsive")
        }
        bridge.appendCSSRule(styleElement!, rule: rule)
        #endif

        return className
    }

    /// Generate the CSS rule text for a responsive class (for testing/inspection).
    public func cssRuleText(mediaQuery: String, styles: [String: String]) -> String {
        let className = responsiveClassName(mediaQuery: mediaQuery, styles: styles)
        let declarations = styles
            .sorted(by: { $0.key < $1.key })
            .map { "  \($0.key): \($0.value) !important;" }
            .joined(separator: "\n")
        return "\(mediaQuery) {\n  .\(className) {\n\(declarations)\n  }\n}"
    }
}
```

**Note:** `!important` is used in the generated CSS to ensure media query styles override inline styles (which have higher specificity).

**Step 3: Integrate StyleSheetManager into DOMRenderer**

In `Sources/SwiftWUIRuntime/DOMRenderer.swift`:

Add `styleSheetManager` property. Inside `#if canImport(JavaScriptKit)` block, after line `private var rootDOMNode: JSObject?`, add:

```swift
    private let styleSheetManager: StyleSheetManager
```

Update the init (around line 24-28):
```swift
    public init(container: JSObject) {
        self.bridge = DOMBridge()
        self.reconciler = Reconciler()
        self.container = container
        self.styleSheetManager = StyleSheetManager(bridge: bridge)
    }
```

In `createDOMNode()`, inside the `.element` case, after the event listeners block (after line ~89), add:

```swift
            // Apply responsive styles as CSS classes
            for (cssQuery, rStyles) in element.responsiveStyles {
                let className = styleSheetManager.ensureClass(mediaQuery: cssQuery, styles: rStyles)
                bridge.addClass(domElement, className: className)
            }
```

In the non-WASM stub (after `#else`), update to:
```swift
    // Non-WASM stub
    public init() {}
    public func render(_ rootTag: some Tag) {}
    public func update(_ rootTag: some Tag, animation: Animation? = nil) {}
```

(The non-WASM stub doesn't need StyleSheetManager since it's a no-op.)

**Step 4: Run full test suite**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass.

**Step 5: Commit**

```bash
git add Sources/SwiftWUIRuntime/StyleSheetManager.swift Sources/SwiftWUIRuntime/DOMBridge.swift Sources/SwiftWUIRuntime/DOMRenderer.swift
git commit -m "feat: add StyleSheetManager and integrate responsive styles into DOMRenderer"
```

---

## Task 9: End-to-end integration test and WASM build

Verify the full pipeline works together and the project compiles for WASM.

**Files:**
- Test: run full test suite + WASM build

**Step 1: Run full test suite**

Run: `swift test 2>&1 | tail -10`
Expected: all tests pass (should be ~140+ tests).

**Step 2: Verify WASM build**

Run: `swift build --swift-sdk swift-6.2.3-RELEASE_wasm 2>&1 | tail -5`
Expected: `Build complete!`

**Step 3: Final commit if any fixes were needed**

If all passes, no commit needed. If fixes were required, commit them:
```bash
git add -A && git commit -m "fix: address integration issues for responsive styles"
```

---

## Summary

| Task | Description | New Tests |
|------|------------|-----------|
| 1 | Make CSSUnit Hashable | 0 |
| 2 | Create MediaQuery enum | ~15 |
| 3 | Add responsiveStyles to ModifiedContent + TagNode | ~5 |
| 4 | Merge responsiveStyles in TagNodeConvertible | ~3 |
| 5 | Create StyleProxy | ~3 |
| 6 | Create ResponsiveModifier (.media()) | ~5 |
| 7 | Hash function + Reconciler support | ~7 |
| 8 | StyleSheetManager + DOMRenderer integration | 0 (runtime) |
| 9 | End-to-end verification + WASM build | 0 |

**Total new tests:** ~38
**Total after:** ~153 tests

**Dependencies between tasks:**
```
Task 1 (CSSUnit) ──→ Task 2 (MediaQuery) ──→ Task 6 (ResponsiveModifier)
                                                       ↑
Task 3 (Storage) ──→ Task 4 (Merging) ──→ Task 5 (StyleProxy) ─┘
                                                       ↓
Task 7 (Hash + Reconciler) ──→ Task 8 (StyleSheetManager + DOMRenderer) ──→ Task 9 (E2E)
```

Tasks 1-2 and 3-5 can run in parallel. Task 6 needs both branches. Tasks 7-9 are sequential.
