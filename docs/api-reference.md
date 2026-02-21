# API Reference

Complete public API reference for all SwiftWUI modules.

---

## SwiftWUICore

### Tag Protocol

The fundamental building block, analogous to SwiftUI's `View`.

```swift
public protocol Tag {
    associatedtype Body: Tag
    @TagBuilder var body: Body { get }
}
```

Concrete HTML tags (`Div`, `Button`, etc.) set `Body = Never` and conform to `TagNodeConvertible` instead.

### TagBuilder

Result builder for composing tag trees.

```swift
@resultBuilder
public struct TagBuilder {
    static func buildBlock(_ components: some Tag...) -> [AnyTag]
    static func buildOptional(_ component: (some Tag)?) -> [AnyTag]
    static func buildEither(first: some Tag) -> [AnyTag]
    static func buildEither(second: some Tag) -> [AnyTag]
    static func buildArray(_ components: [some Tag]) -> [AnyTag]
}
```

### AnyTag

Type-erased wrapper for any `Tag`.

```swift
public struct AnyTag: Tag, TagNodeConvertible {
    public init(_ tag: some Tag)
}
```

### TagNode

Virtual DOM node representation.

```swift
public enum TagNode: Equatable {
    case text(String)
    case element(ElementNode)
    case fragment([TagNode])
}

public struct ElementNode: Equatable {
    public var tagName: String
    public var attributes: [(String, String)]
    public var styles: [(String, String)]
    public var classes: [String]
    public var eventListeners: [(String, String)]  // (event, listenerID)
    public var children: [TagNode]
}
```

### TagNodeConvertible

Protocol for types that can convert directly to `TagNode` arrays.

```swift
public protocol TagNodeConvertible {
    func toTagNodes() -> [TagNode]
}
```

### TagModifier

Protocol for reusable custom modifiers (like SwiftUI's `ViewModifier`).

```swift
public protocol TagModifier {
    associatedtype Body: Tag
    @TagBuilder func body(content: Content) -> Body
}

public struct Content: Tag, TagNodeConvertible { ... }
public struct ModifiedTag<Modifier: TagModifier>: Tag, TagNodeConvertible { ... }
```

**Tag extension:**

```swift
extension Tag {
    func modifier<M: TagModifier>(_ modifier: M) -> ModifiedTag<M>
}
```

### ModifiedContent

Wraps a tag with inline styles, classes, and attributes.

```swift
public struct ModifiedContent<Content: Tag>: Tag, TagNodeConvertible {
    public var styles: [(String, String)]
    public var classes: [String]
    public var attributes: [(String, String)]
}
```

**Generic modifiers on Tag:**

```swift
extension Tag {
    func style(_ property: String, _ value: String) -> ModifiedContent<Self>
    func className(_ name: String) -> ModifiedContent<Self>
    func attribute(_ name: String, _ value: String) -> ModifiedContent<Self>
}
```

### Text

Plain text content node.

```swift
public struct Text: Tag, TagNodeConvertible {
    public init(_ content: String)
}
```

### Functions

```swift
/// Resolve a tag's body into a flat array of TagNode.
public func resolveTagBody(_ tag: some Tag) -> [TagNode]
```

---

## SwiftWUIHTML

All HTML tags conform to `HTMLTag` protocol (which sets `Body = Never`). They accept content via `@TagBuilder` closures and HTML attributes as parameters.

### Container Tags

| Tag | HTML | Notes |
|-----|------|-------|
| `Div { }` | `<div>` | Generic container |
| `Span { }` | `<span>` | Inline container |
| `Section { }` | `<section>` | Section |
| `Article { }` | `<article>` | Article |
| `Header { }` | `<header>` | Header |
| `Footer { }` | `<footer>` | Footer |
| `Nav { }` | `<nav>` | Navigation |
| `Main { }` | `<main>` | Main content |
| `Aside { }` | `<aside>` | Sidebar |

### Text Tags

| Tag | HTML |
|-----|------|
| `H1 { }` ... `H6 { }` | `<h1>` ... `<h6>` |
| `P { }` | `<p>` |
| `Strong { }` | `<strong>` |
| `Em { }` | `<em>` |
| `Small { }` | `<small>` |

### Interactive Tags

| Tag | HTML | Key Parameters |
|-----|------|----------------|
| `Button(onclick:) { }` | `<button>` | `onclick: () -> Void` |
| `A(href:) { }` | `<a>` | `href: String` |
| `Input(type:value:)` | `<input>` | `type: InputType`, `value: Binding<String>?` |
| `Form(onsubmit:) { }` | `<form>` | `onsubmit: () -> Void` |
| `Select { }` | `<select>` | |
| `Option(value:) { }` | `<option>` | `value: String` |
| `Textarea { }` | `<textarea>` | |

### List Tags

| Tag | HTML |
|-----|------|
| `Ul { }` | `<ul>` |
| `Ol { }` | `<ol>` |
| `Li { }` | `<li>` |

### Media Tags

| Tag | HTML | Key Parameters |
|-----|------|----------------|
| `Img(src:alt:)` | `<img>` | `src: String`, `alt: String` |
| `Video(src:) { }` | `<video>` | `src: String` |
| `Audio(src:) { }` | `<audio>` | `src: String` |

---

## SwiftWUIStyles

### CSSUnit

Type-safe CSS length/size values.

```swift
public enum CSSUnit: Equatable {
    case px(Double)
    case rem(Double)
    case em(Double)
    case percent(Double)
    case vh(Double)
    case vw(Double)
    case auto
    case zero
    case custom(String)

    public var cssValue: String { ... }
}
```

### CSSColor

Type-safe CSS color values.

```swift
public enum CSSColor: Equatable {
    case hex(String)
    case rgb(Int, Int, Int)
    case rgba(Int, Int, Int, Double)
    case hsl(Int, Int, Int)
    case hsla(Int, Int, Int, Double)
    case named(String)
    case transparent
    case currentColor
    case custom(String)

    public var cssValue: String { ... }
}
```

### Style Modifiers

All modifiers are available on both `Tag` and `ModifiedContent` for chaining.

**Layout:** `display(_:)`, `position(_:)`, `width(_:)`, `height(_:)`, `minWidth(_:)`, `maxWidth(_:)`, `minHeight(_:)`, `maxHeight(_:)`, `top(_:)`, `right(_:)`, `bottom(_:)`, `left(_:)`

**Spacing:** `padding(_:)`, `padding(_:_:)`, `paddingTop(_:)`, `paddingRight(_:)`, `paddingBottom(_:)`, `paddingLeft(_:)`, `margin(_:)`, `margin(_:_:)`, `marginTop(_:)`, `marginRight(_:)`, `marginBottom(_:)`, `marginLeft(_:)`, `gap(_:)`

**Flexbox:** `flexDirection(_:)`, `flexWrap(_:)`, `justifyContent(_:)`, `alignItems(_:)`, `alignSelf(_:)`, `flex(_:_:_:)`, `flexGrow(_:)`, `flexShrink(_:)`

**Grid:** `gridTemplateColumns(_:)`, `gridTemplateRows(_:)`, `gridColumn(_:)`, `gridRow(_:)`, `gridAutoFlow(_:)`

**Colors:** `backgroundColor(_:)`, `foregroundColor(_:)`, `opacity(_:)`

**Typography:** `fontSize(_:)`, `fontWeight(_:)`, `fontFamily(_:)`, `fontStyle(_:)`, `lineHeight(_:)`, `textAlign(_:)`, `textDecoration(_:)`, `textTransform(_:)`, `letterSpacing(_:)`, `whiteSpace(_:)`, `wordBreak(_:)`

**Border:** `border(_:_:_:)`, `borderRadius(_:)`, `borderColor(_:)`, `borderWidth(_:)`, `borderStyle(_:)`, `borderBottom(_:_:_:)`

**Box:** `boxSizing(_:)`, `overflow(_:)`, `overflowX(_:)`, `overflowY(_:)`, `boxShadow(_:)`, `zIndex(_:)`

**Cursor:** `cursor(_:)`, `visibility(_:)`, `objectFit(_:)`

**Transform:** `transform(_:)`, `transition(_:)` (String), `animation(_:)` (String)

### CSS Enum Types

`Display`, `Position`, `FlexDirection`, `FlexWrap`, `JustifyContent`, `AlignItems`, `AlignSelf`, `GridAutoFlow`, `FontWeight`, `FontStyle`, `TextAlign`, `TextDecoration`, `TextTransform`, `WhiteSpace`, `WordBreak`, `BorderStyle`, `BoxSizing`, `Overflow`, `Cursor`, `Visibility`, `ObjectFit`

### Animation

```swift
public struct Animation: Sendable, Equatable {
    public let duration: Double
    public let timingFunction: TimingFunction
    public let delay: Double

    // Presets
    static let `default`: Animation          // 0.3s ease-in-out
    static let spring: Animation             // 0.5s cubic-bezier
    static let bouncy: Animation             // 0.6s with overshoot
    static func linear(duration:) -> Animation
    static func easeIn(duration:) -> Animation
    static func easeOut(duration:) -> Animation
    static func easeInOut(duration:) -> Animation
    static func custom(duration:timingFunction:delay:) -> Animation

    // Modifiers
    func delay(_ delay: Double) -> Animation
    func speed(_ multiplier: Double) -> Animation

    // CSS
    var cssTransitionAll: String
    func cssTransitionValue(for properties: [String]) -> String
}
```

### TimingFunction

```swift
public enum TimingFunction: Sendable, Equatable {
    case linear, ease, easeIn, easeOut, easeInOut
    case cubicBezier(Double, Double, Double, Double)
    case steps(Int, StepPosition)

    var cssValue: String
}

public enum StepPosition: Sendable, Equatable {
    case start, end
}
```

### TagTransition

```swift
public struct TagTransition: Sendable, Equatable {
    public let enterFrom: [String: String]
    public let exitTo: [String: String]
    public let animation: Animation

    // Presets
    static let opacity: TagTransition
    static let scale: TagTransition
    static let slide: TagTransition
    static let moveUp: TagTransition
    static let moveDown: TagTransition

    // Modifiers
    func animation(_ animation: Animation) -> TagTransition
    func combined(with other: TagTransition) -> TagTransition
}
```

### AnimationContext

```swift
public enum AnimationContext {
    nonisolated(unsafe) static var current: Animation?
}

public func withAnimation(_ animation: Animation = .default, _ body: () -> Void)
```

### Type-Safe Animation Modifiers

```swift
extension Tag {
    func animation(_ animation: Animation) -> ModifiedContent<Self>
    func transition(_ transition: TagTransition) -> ModifiedContent<Self>
}
```

---

## SwiftWUIState

### @State

```swift
@propertyWrapper
public struct State<Value>: @unchecked Sendable {
    public init(wrappedValue: Value)
    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }  // $property syntax
}
```

### Binding

```swift
@dynamicMemberLookup
@propertyWrapper
public struct Binding<Value> {
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void)
    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }

    public static func constant(_ value: Value) -> Binding<Value>
    public func map<T>(get: (Value) -> T, set: (T) -> Value) -> Binding<T>
}

// For @Observable class models:
extension Binding where Value: AnyObject {
    subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, T>) -> Binding<T>
}
```

### @Environment

```swift
@propertyWrapper
public struct Environment<Value> {
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>)
    public var wrappedValue: Value { get }
}
```

### EnvironmentKey & EnvironmentValues

```swift
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues: @unchecked Sendable {
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value { get set }
}

public enum CurrentEnvironment {
    nonisolated(unsafe) static var values: EnvironmentValues
}
```

---

## SwiftWUIRouter

### Router

```swift
@Observable
public final class Router: @unchecked Sendable {
    public var currentPath: String
    public private(set) var routes: [Route]
    public private(set) var currentParams: [String: String]

    public init(initialPath: String = "/", @RouteBuilder routes: () -> [Route])
    public func navigate(to path: String)
    public func goBack()
    public func matchedRoute(for path: String) -> Route?
    public func matchedTag(for path: String) -> AnyTag?
}
```

### Route

```swift
public struct Route {
    public init(_ pattern: String, @TagBuilder content: @escaping () -> some Tag)
    public init(_ pattern: String, content: @escaping ([String: String]) -> AnyTag)
    public func match(_ path: String) -> [String: String]?
}
```

### RouteBuilder

```swift
@resultBuilder
public struct RouteBuilder {
    static func buildBlock(_ routes: Route...) -> [Route]
}
```

### Link

```swift
public struct Link: Tag, TagNodeConvertible {
    public init(_ destination: String, @TagBuilder content: () -> some Tag)
    public init(_ title: String, destination: String)
}
```

---

## SwiftWUIRuntime

### Application

```swift
public struct Application {
    public init(@RouteBuilder routes: () -> [Route])
    public init(page: @Sendable @escaping () -> some Tag)
    public func mount(on elementId: String = "app")
}
```

### DOMRenderer

```swift
public final class DOMRenderer {
    public init(container: JSObject)  // WASM only
    public func render(_ rootTag: some Tag)
    public func update(_ rootTag: some Tag, animation: Animation? = nil)
}
```

### DOMBridge

```swift
public final class DOMBridge {
    // Element creation
    func createElement(_ tagName: String) -> JSObject
    func createTextNode(_ text: String) -> JSObject

    // Attributes & styles
    func setAttribute(_:name:value:)
    func removeAttribute(_:name:)
    func setStyle(_:property:value:)
    func removeStyle(_:property:)
    func addClass(_:className:)
    func removeClass(_:className:)

    // Tree operations
    func appendChild(_:child:)
    func removeChild(_:child:)
    func replaceChild(_:newChild:oldChild:)
    func removeAllChildren(_:)

    // Events
    func setTrackedEventListener(_:event:handler:)
    func removeTrackedEventListener(_:event:)

    // History API
    func pushState(path:)
    func currentPathname() -> String
    func onPopState(handler: (String) -> Void)

    // Web Animations API
    func animate(_:keyframes:duration:easing:fill:) -> JSObject?
    func requestAnimationFrame(_: () -> Void)
    func setTimeout(_: () -> Void, milliseconds: Int)
}
```

### Reconciler

```swift
public struct Reconciler {
    public func diff(old: TagNode?, new: TagNode?) -> Patch?
}

public enum Patch {
    case createNode(TagNode)
    case removeNode
    case replaceNode(TagNode)
    case updateText(String)
    case updateAttributes(add: [(String, String)], remove: [String])
    case updateStyles(add: [(String, String)], remove: [String])
    case updateClasses(add: [String], remove: [String])
    case updateEventListeners(add: [(String, String)], remove: [String])
    case patchChildren([ChildPatch])
}
```

---

## SwiftWUIBrowser

### @AppStorage

```swift
@propertyWrapper
public struct AppStorage<Value: LosslessStringConvertible>: @unchecked Sendable {
    public init(wrappedValue: Value, _ key: String)
    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }
}
```

### @SessionStorage

Same API as `@AppStorage`, but backed by `sessionStorage` (cleared on tab close).

### GeolocationManager

```swift
@Observable
public final class GeolocationManager: @unchecked Sendable {
    public var lastLocation: Coordinate?
    public var error: String?
    public var isLoading: Bool

    public func requestLocation()
}

public struct Coordinate: Sendable {
    public let latitude: Double
    public let longitude: Double
    public let accuracy: Double?
}
```

### ClipboardManager

```swift
public enum ClipboardManager: Sendable {
    public static func writeText(_ text: String)
    public static func readText(completion: @escaping @Sendable (String?) -> Void)
}
```

### MediaQueryState

```swift
@Observable
public final class MediaQueryState: @unchecked Sendable {
    public var colorScheme: ColorScheme      // .light, .dark
    public var screenWidth: Double
    public var screenHeight: Double
    public var screenSize: ScreenSize        // .compact, .regular, .expanded
    public var prefersReducedMotion: Bool

    public func startListening()
}

public enum ColorScheme: String, Sendable { case light, dark }
public enum ScreenSize: Sendable { case compact, regular, expanded }
```

### LocalizedStringCatalog

```swift
public struct LocalizedStringCatalog: Sendable {
    public mutating func add(locale: String, key: String, value: String)
    public mutating func add(locale: String, translations: [String: String])
    public func localized(_ key: String, locale: String) -> String
    public var availableLocales: [String]
}
```

### Browser Environment Values

```swift
extension EnvironmentValues {
    var locale: String              // browser language, default "en"
    var colorScheme: ColorScheme    // default .light
    var screenSize: ScreenSize      // default .regular
    var prefersReducedMotion: Bool  // default false
}
```
