# Browser APIs

SwiftWUI provides Swift wrappers around common browser APIs through the `SwiftWUIBrowser` module. These wrappers integrate with the Observation framework so that changes to browser state automatically trigger re-renders.

## Table of Contents

- [@AppStorage (localStorage)](#appstorage-localstorage)
- [@SessionStorage](#sessionstorage)
- [GeolocationManager](#geolocationmanager)
- [ClipboardManager](#clipboardmanager)
- [MediaQueryState](#mediaquerystate)
- [LocalizedStringCatalog](#localizedstringcatalog)
- [Environment Values](#environment-values)
- [Platform Notes](#platform-notes)

---

## @AppStorage (localStorage)

`@AppStorage` is a property wrapper that reads and writes values to the browser's `localStorage`. Values persist across browser sessions -- they survive page reloads and browser restarts.

```swift
struct Settings: Tag {
    @AppStorage("username") var username = "Guest"
    @AppStorage("theme") var theme = "light"

    var body: some Tag {
        Text("Hello, \(username)")
        Button(onclick: { username = "User" }) { Text("Change Name") }
    }
}
```

### How It Works

1. On first read, `@AppStorage` checks `localStorage` for an existing value under the given key.
2. If a stored value exists, it is parsed and returned. Otherwise, the default value is used.
3. On write, the new value is saved to `localStorage` and the in-memory cache is updated.
4. Because the backing storage class is `@Observable`, any write triggers the Observation framework's change tracking, causing affected views to re-render.

### API

```swift
@propertyWrapper
public struct AppStorage<Value: LosslessStringConvertible> {
    public init(wrappedValue: Value, _ key: String)

    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }
}
```

### Binding Support

Access a `Binding<Value>` through the `$` prefix. This is useful for passing two-way data to input components:

```swift
struct NameEditor: Tag {
    @AppStorage("username") var username = "Guest"

    var body: some Tag {
        Input(type: "text", value: $username)
        Text("Current: \(username)")
    }
}
```

### Value Type Requirement

The stored value must conform to `LosslessStringConvertible`. This includes all standard Swift types that can be losslessly converted to and from strings:

| Type | Example Default |
|---|---|
| `String` | `"Guest"` |
| `Int` | `0` |
| `Double` | `3.14` |
| `Bool` | `true` |

For complex types, consider serialising to a JSON string and storing that:

```swift
@AppStorage("settings") var settingsJSON = "{}"
```

### Storage Key Namespacing

Keys are stored directly in `localStorage` without any prefix. Choose descriptive, unique keys to avoid collisions with other libraries or parts of your application:

```swift
@AppStorage("app.user.name") var username = "Guest"
@AppStorage("app.user.theme") var theme = "light"
```

---

## @SessionStorage

`@SessionStorage` works identically to `@AppStorage` but uses the browser's `sessionStorage` instead of `localStorage`. Data persists only for the current browser session and is cleared when the tab or window is closed.

```swift
struct WizardStep: Tag {
    @SessionStorage("step") var currentStep = 1

    var body: some Tag {
        Text("Step \(currentStep)")
        Button(onclick: { currentStep += 1 }) { Text("Next") }
    }
}
```

### API

```swift
@propertyWrapper
public struct SessionStorage<Value: LosslessStringConvertible> {
    public init(wrappedValue: Value, _ key: String)

    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }
}
```

### When to Use @SessionStorage vs @AppStorage

| Criteria | @AppStorage | @SessionStorage |
|---|---|---|
| Persistence | Survives browser restart | Cleared when tab closes |
| Scope | Shared across all tabs | Isolated per tab |
| Use case | User preferences, saved state | Wizard progress, temp data |
| Storage backend | `localStorage` | `sessionStorage` |

### Binding Support

Just like `@AppStorage`, `@SessionStorage` provides binding access via the `$` prefix:

```swift
@SessionStorage("query") var searchQuery = ""

// In body:
Input(type: "text", value: $searchQuery)
```

---

## GeolocationManager

`GeolocationManager` wraps the browser's Geolocation API. It is an `@Observable` class, so property changes automatically trigger re-renders.

```swift
struct LocationView: Tag {
    @State var geo = GeolocationManager()

    var body: some Tag {
        if let loc = geo.lastLocation {
            Text("Lat: \(loc.latitude), Lon: \(loc.longitude)")
            if let acc = loc.accuracy {
                Text("Accuracy: \(acc)m")
            }
        }
        if geo.isLoading { Text("Loading...") }
        if let error = geo.error { Text("Error: \(error)") }
        Button(onclick: { geo.requestLocation() }) { Text("Get Location") }
    }
}
```

### Properties

| Property | Type | Description |
|---|---|---|
| `lastLocation` | `Coordinate?` | The most recently obtained location, or `nil` |
| `error` | `String?` | A human-readable error message, or `nil` |
| `isLoading` | `Bool` | Whether a location request is in progress |

### Coordinate

The `Coordinate` struct holds geographic data returned by the browser:

```swift
public struct Coordinate: Sendable {
    public let latitude: Double    // Decimal degrees
    public let longitude: Double   // Decimal degrees
    public let accuracy: Double?   // Metres (if available)
}
```

### requestLocation()

Triggers a one-shot location request. The browser will prompt the user for permission if it has not been granted.

```swift
geo.requestLocation()
```

The method is asynchronous on the browser side. Results arrive through the observable properties:

- On success: `lastLocation` is set, `isLoading` becomes `false`.
- On error: `error` is set with a message (e.g., "User denied Geolocation"), `isLoading` becomes `false`.

### Error Handling

Common error scenarios:

| Error | Cause |
|---|---|
| "User denied Geolocation" | User rejected the permission prompt |
| "Geolocation is not supported by this browser" | Browser lacks Geolocation API |
| "Position unavailable" | Device could not determine position |
| "Geolocation is only available in WASM environment" | Running on macOS (non-WASM) |

### Usage Pattern

Because `GeolocationManager` is `@Observable`, wrap it in `@State` to preserve the instance across re-renders:

```swift
@State var geo = GeolocationManager()
```

Do not create a new `GeolocationManager()` directly in the `body` -- this would lose the state on every re-render.

---

## ClipboardManager

`ClipboardManager` provides static methods for reading and writing text via the browser's async Clipboard API.

### Writing to Clipboard

```swift
Button(onclick: {
    ClipboardManager.writeText("Copied!")
}) {
    Text("Copy")
}
```

### Reading from Clipboard

Reading is asynchronous because the browser may prompt the user for permission:

```swift
ClipboardManager.readText { text in
    if let text {
        print("Clipboard: \(text)")
    } else {
        print("Read failed or permission denied")
    }
}
```

### API

```swift
public enum ClipboardManager: Sendable {
    /// Write text to the clipboard. No-op on non-WASM platforms.
    public static func writeText(_ text: String)

    /// Read text from the clipboard. Calls completion with nil on failure.
    public static func readText(
        completion: @escaping @Sendable (String?) -> Void
    )
}
```

### Complete Example

```swift
struct CopyPasteDemo: Tag {
    @State var pastedText = ""
    @State var copyMessage = ""

    var body: some Tag {
        Div {
            Button(onclick: {
                ClipboardManager.writeText("Hello from SwiftWUI!")
                copyMessage = "Copied!"
            }) { Text("Copy to Clipboard") }

            Text(copyMessage)

            Button(onclick: {
                ClipboardManager.readText { text in
                    pastedText = text ?? "(empty)"
                }
            }) { Text("Paste from Clipboard") }

            Text("Pasted: \(pastedText)")
        }
    }
}
```

### Browser Permissions

- **writeText** generally works without a permission prompt in response to a user gesture (button click).
- **readText** may trigger a browser permission prompt. If the user denies permission, the completion handler receives `nil`.
- Clipboard access requires a **secure context** (HTTPS or localhost).

---

## MediaQueryState

`MediaQueryState` tracks browser viewport and preference changes for responsive design. It is `@Observable`, so property changes trigger automatic re-renders.

```swift
struct ResponsiveView: Tag {
    @State var media = MediaQueryState()

    var body: some Tag {
        if media.screenSize == .compact {
            MobileLayout()
        } else if media.screenSize == .regular {
            TabletLayout()
        } else {
            DesktopLayout()
        }
    }
}
```

### Properties

| Property | Type | Description |
|---|---|---|
| `colorScheme` | `ColorScheme` | `.light` or `.dark` based on user preference |
| `screenWidth` | `Double` | Viewport width in CSS pixels |
| `screenHeight` | `Double` | Viewport height in CSS pixels |
| `screenSize` | `ScreenSize` | Computed breakpoint category (read-only) |
| `prefersReducedMotion` | `Bool` | Whether the user prefers reduced motion |

### ScreenSize Breakpoints

The `screenSize` property is computed from `screenWidth`:

| ScreenSize | Width Range | Typical Device |
|---|---|---|
| `.compact` | < 768px | Mobile phones |
| `.regular` | 768 -- 1024px | Tablets |
| `.expanded` | > 1024px | Desktops |

### ColorScheme

```swift
public enum ColorScheme: String, Sendable {
    case light
    case dark
}
```

Reflects the user's OS-level dark mode preference via the `prefers-color-scheme` media query.

### startListening()

You must call `startListening()` once during application setup to initialise the state and attach event listeners:

```swift
let media = MediaQueryState()
media.startListening()
```

This method:

1. Reads the initial `colorScheme` from `(prefers-color-scheme: dark)`.
2. Reads the initial `prefersReducedMotion` from `(prefers-reduced-motion: reduce)`.
3. Reads the initial `screenWidth` and `screenHeight` from `window.innerWidth` / `window.innerHeight`.
4. Attaches a `resize` event listener to track viewport changes.
5. Attaches a `change` listener on the dark mode media query to track scheme changes.

### Responsive Design Example

```swift
struct AdaptiveLayout: Tag {
    @State var media = MediaQueryState()

    var body: some Tag {
        Div {
            if media.screenSize == .compact {
                // Single column, stacked layout
                Div {
                    Sidebar()
                    MainContent()
                }
                .flexDirection(.column)
            } else {
                // Side-by-side layout
                Div {
                    Sidebar()
                        .width(.px(250))
                    MainContent()
                        .flex(1, 1, .auto)
                }
                .display(.flex)
            }
        }
    }
}
```

### Respecting Reduced Motion

```swift
struct AnimatedWidget: Tag {
    @State var media = MediaQueryState()
    @State var isActive = false

    var body: some Tag {
        Div { Text("Widget") }
            .animation(
                media.prefersReducedMotion
                    ? .linear(duration: 0)  // Instant, no animation
                    : .spring
            )
            .opacity(isActive ? 1.0 : 0.5)
    }
}
```

---

## LocalizedStringCatalog

`LocalizedStringCatalog` is a lightweight internationalization system for managing translated strings. It uses a dictionary-based approach with locale fallback.

```swift
var strings = LocalizedStringCatalog()
strings.add(locale: "en", key: "greeting", value: "Hello")
strings.add(locale: "ru", key: "greeting", value: "Привет")
strings.add(locale: "es", key: "greeting", value: "Hola")

strings.localized("greeting", locale: "ru")   // "Привет"
strings.localized("greeting", locale: "es")   // "Hola"
strings.localized("greeting", locale: "fr")   // "Hello" (falls back to "en")
```

### Adding Translations

Add strings one at a time:

```swift
strings.add(locale: "en", key: "save", value: "Save")
strings.add(locale: "ru", key: "save", value: "Сохранить")
```

Or add all translations for a locale at once:

```swift
strings.add(locale: "en", translations: [
    "greeting": "Hello",
    "farewell": "Goodbye",
    "save": "Save",
    "cancel": "Cancel"
])
```

### Fallback Chain

When looking up a translation, the catalog tries these sources in order:

1. **Exact locale match** -- e.g., `"en-US"` matches `"en-US"` translations.
2. **Base locale** -- e.g., `"en-US"` falls back to `"en"` translations.
3. **English** -- always falls back to `"en"` as the last language.
4. **Key itself** -- if no translation exists at all, the key string is returned.

```swift
strings.add(locale: "en", key: "hello", value: "Hello")
strings.add(locale: "en-GB", key: "hello", value: "Hello, mate")

strings.localized("hello", locale: "en-GB")  // "Hello, mate" (exact)
strings.localized("hello", locale: "en-US")  // "Hello" (base "en")
strings.localized("hello", locale: "fr")     // "Hello" (English fallback)
strings.localized("missing", locale: "en")   // "missing" (key fallback)
```

### Available Locales

Query which locales have at least one translation:

```swift
strings.availableLocales  // ["en", "es", "ru"] -- sorted alphabetically
```

### Integration with Environment

Use `@Environment(\.locale)` to get the browser's current language and pass it to the catalog:

```swift
struct LocalizedView: Tag {
    @Environment(\.locale) var locale

    var body: some Tag {
        Text(strings.localized("greeting", locale: locale))
    }
}
```

### Complete Example

```swift
// Define translations (typically at app level)
var catalog = LocalizedStringCatalog()

func setupLocalization() {
    catalog.add(locale: "en", translations: [
        "nav.home": "Home",
        "nav.about": "About",
        "nav.contact": "Contact",
        "welcome": "Welcome to our site"
    ])
    catalog.add(locale: "ru", translations: [
        "nav.home": "Главная",
        "nav.about": "О нас",
        "nav.contact": "Контакты",
        "welcome": "Добро пожаловать на наш сайт"
    ])
}

// Use in components
struct Navigation: Tag {
    @Environment(\.locale) var locale

    var body: some Tag {
        Div {
            Anchor(href: "/") { Text(catalog.localized("nav.home", locale: locale)) }
            Anchor(href: "/about") { Text(catalog.localized("nav.about", locale: locale)) }
            Anchor(href: "/contact") { Text(catalog.localized("nav.contact", locale: locale)) }
        }
    }
}
```

---

## Environment Values

SwiftWUI extends the `@Environment` system with browser-specific values. These are read-only properties that reflect the current browser state.

### Available Browser Environment Values

#### Locale

```swift
@Environment(\.locale) var locale
```

Returns the browser's primary language as a string (e.g., `"en-US"`, `"ru"`, `"ja"`). Sourced from `navigator.language`.

Default value (non-WASM): `"en"`

#### Color Scheme

```swift
@Environment(\.colorScheme) var colorScheme
```

Returns `.light` or `.dark` based on the user's OS-level preference.

Default value: `.light`

#### Screen Size

```swift
@Environment(\.screenSize) var screenSize
```

Returns the current breakpoint category: `.compact`, `.regular`, or `.expanded`.

Default value: `.regular`

#### Prefers Reduced Motion

```swift
@Environment(\.prefersReducedMotion) var prefersReducedMotion
```

Returns `true` if the user has enabled the "reduce motion" accessibility setting in their OS.

Default value: `false`

### Usage Example

```swift
struct ThemeAwareCard: Tag {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.screenSize) var screenSize

    var body: some Tag {
        Div {
            Text("Themed content")
        }
        .backgroundColor(colorScheme == .dark ? .hex("#1a1a1a") : .hex("#ffffff"))
        .foregroundColor(colorScheme == .dark ? .hex("#ffffff") : .hex("#000000"))
        .padding(screenSize == .compact ? .px(8) : .px(24))
        .borderRadius(.px(8))
    }
}
```

### Defining Custom Environment Values

You can extend the environment system with your own keys:

```swift
// 1. Define a key
struct AccentColorKey: EnvironmentKey {
    static var defaultValue: String { "#007AFF" }
}

// 2. Extend EnvironmentValues
extension EnvironmentValues {
    var accentColor: String {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}

// 3. Use in components
struct StyledButton: Tag {
    @Environment(\.accentColor) var accentColor

    var body: some Tag {
        Button(onclick: { /* ... */ }) {
            Text("Action")
        }
        .backgroundColor(.hex(accentColor))
    }
}
```

To set a custom environment value globally:

```swift
CurrentEnvironment.values.accentColor = "#FF6600"
```

---

## Platform Notes

All browser API wrappers in the `SwiftWUIBrowser` module use conditional compilation to handle both WASM and native (macOS/Linux) platforms:

- **WASM (production):** Full browser API access via JavaScriptKit.
- **Native (testing):** Stubs that return default values or no-op. This allows your components to compile and run tests on macOS without browser dependencies.

The conditional compilation uses `#if arch(wasm32)` or `#if canImport(JavaScriptKit)` guards. You do not need to add any platform checks in your own code -- the wrappers handle this transparently.

### Memory Management

- `JSOneshotClosure` is used for one-shot callbacks (e.g., geolocation, clipboard read). These are automatically deallocated after firing.
- `JSClosure` is used for long-lived event listeners (e.g., resize, media query changes). These are retained by the `DOMBridge` closure storage to prevent premature deallocation.
- All browser API classes are marked `@unchecked Sendable` because WebAssembly is single-threaded. This is safe in the WASM environment but should not be relied upon if the code is ever ported to a multi-threaded context.
