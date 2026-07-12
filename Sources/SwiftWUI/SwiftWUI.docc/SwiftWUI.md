# ``SwiftWUI``

Build websites in pure Swift with a SwiftUI-inspired declarative API,
compiled to WebAssembly.

## Overview

SwiftWUI components are value types conforming to ``Tag`` — the analog of
SwiftUI's `View`. A component declares its content in `body` using typed
HTML elements, stores local state in ``State``, and re-renders automatically
when that state changes:

```swift
struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
        }
    }
}
```

An application is a type conforming to ``App``. In the browser it mounts via
the `SwiftWUIDOM` backend (`@main struct MyApp: App`); on macOS/Linux the
same tree renders to HTML strings with ``HTMLRenderer`` or to a prerendered
static site with the `SwiftWUIStatic` module.

See <doc:GettingStarted> for toolchain setup and your first project.

## Topics

### Essentials

- <doc:GettingStarted>
- ``Tag``
- ``App``
- ``TagBuilder``
- ``Text``
- ``ForEach``
- ``AnyTag``
- ``EmptyTag``

### State

- ``State``
- ``Binding``
- ``Bindable``

### Environment

- ``Environment``
- ``EnvironmentKey``
- ``EnvironmentValues``

### HTML elements and events

- ``HTMLTag``
- ``EventName``
- ``ClickEvent``
- ``InputEvent``
- ``ChangeEvent``
- ``KeyEvent``
- ``SubmitEvent``
- ``FocusEvent``
- ``GenericEvent``

### Styling and themes

- ``Style``
- ``StyleProxy``
- ``Rule``
- ``RulesBuilder``
- ``MediaQuery``
- ``ThemeDefinition``
- ``StyleToken``
- ``CSSColor``
- ``CSSLength``

### Routing

- ``Router``
- ``Route``
- ``RouteBuilder``
- ``RouteGuardResult``
- ``Link``
- ``Page``
- ``MetaTag``
- ``RouteInfo``
- ``NavigateAction``
- ``QueryParam``

### Effects

- ``TaskPolicy``

### Browser APIs

- <doc:BrowserAPIs>
- ``ColorScheme``
- ``AppStorage``
- ``SceneStorage``
- ``StorageConvertible``
- ``WebSession``
- ``WebRequest``
- ``WebResponse``
- ``WebFetchError``
- ``HTTPMethod``
- ``WebFile``
- ``FilesEvent``

### PWA

- <doc:PWA>

### Rendering and advanced

- ``HTMLRenderer``
- ``Runtime``
- ``RendererBackend``
- ``MockBackend``
- ``NodeIdentity``
- ``ResolveContext``
