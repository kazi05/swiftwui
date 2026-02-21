# State Management

SwiftWUI provides a reactive state management system inspired by SwiftUI. State changes automatically trigger UI re-renders through Swift's Observation framework, giving you a declarative approach to building dynamic web interfaces.

## Table of Contents

- [@State](#state)
- [@State with @Observable Models](#state-with-observable-models)
- [@ObservedObject](#observedobject)
- [Binding](#binding)
- [@Environment](#environment)
- [Reactivity Internals](#reactivity-internals)
- [Best Practices](#best-practices)

---

## @State

The `@State` property wrapper declares mutable state owned by a tag. When the value changes, the framework automatically re-renders the tag's body.

### Basic Usage

```swift
struct Counter: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            P { Text("Count: \(count)") }
            Button(onclick: { count += 1 }) {
                Text("Increment")
            }
        }
    }
}
```

### Multiple State Properties

A tag can have any number of `@State` properties. A change to any one of them triggers a re-render.

```swift
struct LoginForm: Tag {
    @State var username = ""
    @State var password = ""
    @State var rememberMe = false

    var body: some Tag {
        Div {
            Input(type: "text", value: username, oninput: { username = $0 })
            Input(type: "password", value: password, oninput: { password = $0 })
            Text("Remember me: \(rememberMe ? "Yes" : "No")")
            Button(onclick: { rememberMe.toggle() }) {
                Text("Toggle Remember Me")
            }
        }
    }
}
```

### How It Works

Under the hood, `@State` is backed by an `@Observable` class called `StateStorage`. This is a reference type that is shared across struct copies, which means:

1. When Swift copies your `Tag` struct (which happens during re-renders), the `StateStorage` instance is shared -- not duplicated.
2. The `@Observable` macro makes `StateStorage.value` trackable by the Observation framework.
3. The runtime uses `withObservationTracking` to detect which state properties are read during `body` evaluation.
4. When a tracked property changes, the `onChange` callback fires and schedules a re-render via `queueMicrotask`.

```
Tag struct copy 1  --\
                      }--> StateStorage (reference type, @Observable)
Tag struct copy 2  --/         |
                               v
                        value changes --> onChange fires --> re-render scheduled
```

---

## @State with @Observable Models

For more complex state, you can use `@State` with an `@Observable` class. Property accesses on the model are automatically tracked by the Observation framework.

```swift
@Observable
class UserModel {
    var name = ""
    var age = 0
    var email = ""
}

struct ProfileEditor: Tag {
    @State var user = UserModel()

    var body: some Tag {
        Div {
            Text("Name: \(user.name)")    // auto-tracked
            Text("Age: \(user.age)")       // auto-tracked
            Text("Email: \(user.email)")   // auto-tracked

            Button(onclick: { user.name = "Alice" }) {
                Text("Set Name")
            }
            Button(onclick: { user.age += 1 }) {
                Text("Increment Age")
            }
        }
    }
}
```

Because `UserModel` is `@Observable`, the framework tracks exactly which properties of `user` are read in `body`. If only `user.name` changes, the re-render still occurs (the entire body is re-evaluated), but you get the benefit of fine-grained observation -- only changes to properties actually read in the current render cycle trigger the next re-render.

### Nested Observable Objects

You can nest `@Observable` objects for more complex data models:

```swift
@Observable
class Address {
    var street = ""
    var city = ""
    var zip = ""
}

@Observable
class ContactInfo {
    var name = ""
    var address = Address()
}

struct ContactForm: Tag {
    @State var contact = ContactInfo()

    var body: some Tag {
        Div {
            Text("Name: \(contact.name)")
            Text("City: \(contact.address.city)")

            Button(onclick: { contact.address.city = "New York" }) {
                Text("Set City")
            }
        }
    }
}
```

---

## @ObservedObject

Use `@ObservedObject` when an `@Observable` object is owned elsewhere and passed into your tag. Unlike `@State`, `@ObservedObject` does not create or own the storage -- it observes an externally provided object.

```swift
@Observable
class AppModel {
    var username = ""
    var isLoggedIn = false
}

struct Profile: Tag {
    @ObservedObject var model: AppModel

    var body: some Tag {
        Div {
            Text("User: \(model.username)")
        }
    }
}
```

### @ObservedObject vs @State

| Feature | @State | @ObservedObject |
|---------|--------|-----------------|
| Ownership | Tag owns the state | External ownership |
| Initialization | Provide a default value | Inject from outside |
| Storage | Creates `StateStorage` internally | References existing object |
| Projected value (`$`) | `Binding<Value>` | Dynamic member lookup wrapper |

### Binding from @ObservedObject

The `$` prefix on an `@ObservedObject` gives you a dynamic member lookup wrapper. You can drill into properties to get bindings:

```swift
@Observable
class FormModel {
    var name = ""
    var age = 0
}

struct FormEditor: Tag {
    @ObservedObject var model: FormModel

    var body: some Tag {
        Div {
            // $model.name is Binding<String>
            // $model.age is Binding<Int>
            Text("Name: \(model.name)")
        }
    }
}
```

---

## Binding

`Binding<Value>` provides a two-way connection to a mutable value. It is the primary mechanism for passing mutable state to child tags and form inputs.

### Obtaining a Binding

The most common way to get a binding is through the `$` prefix on a `@State` property:

```swift
struct Parent: Tag {
    @State var name = ""

    var body: some Tag {
        // $name is Binding<String>
        NameEditor(name: $name)
    }
}

struct NameEditor: Tag {
    @Binding var name: String

    var body: some Tag {
        Div {
            Text("Current name: \(name)")
            Button(onclick: { name = "Updated" }) {
                Text("Update")
            }
        }
    }
}
```

### Binding to Model Properties

When `@State` wraps an `AnyObject` (class) type, the projected `Binding` supports `@dynamicMemberLookup`. This lets you access sub-bindings with dot syntax:

```swift
@Observable
class FormModel {
    var name = ""
    var age = 0
}

struct Form: Tag {
    @State var model = FormModel()

    var body: some Tag {
        Div {
            // $model returns Binding<FormModel>
            // $model.name returns Binding<String>
            // $model.age returns Binding<Int>
            NameField(name: $model.name)
        }
    }
}
```

### Binding.constant

For previews, testing, or static content, use `Binding.constant(_:)` to create a binding that ignores writes:

```swift
// A binding that always returns "Preview" and discards any set operations
let previewBinding = Binding<String>.constant("Preview")
```

### Binding.map

Transform a binding's value with `map(get:set:)`. This is useful when a child component needs a different type or representation than the parent stores:

```swift
struct AgeEditor: Tag {
    @State var age = 25

    var body: some Tag {
        Div {
            // Convert Int <-> String for a text input
            let ageString = $age.map(
                get: { String($0) },
                set: { Int($0) ?? 0 }
            )
            Text("Age: \(age)")
        }
    }
}
```

### Creating Bindings Manually

You can construct a `Binding` directly with get/set closures:

```swift
let binding = Binding<String>(
    get: { someObject.value },
    set: { someObject.value = $0 }
)
```

---

## @Environment

`@Environment` reads values from a shared environment that flows down the tag tree. This is useful for theme settings, locale preferences, and other cross-cutting concerns.

### Defining a Custom Environment Key

```swift
// 1. Define the key with a default value
struct ThemeKey: EnvironmentKey {
    static var defaultValue: String { "light" }
}

// 2. Extend EnvironmentValues with a computed property
extension EnvironmentValues {
    var theme: String {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

### Reading Environment Values

```swift
struct ThemedCard: Tag {
    @Environment(\.theme) var theme

    var body: some Tag {
        Div {
            Text("Current theme: \(theme)")
        }
        .backgroundColor(theme == "dark" ? .hex("#333") : .white)
        .foregroundColor(theme == "dark" ? .white : .black)
    }
}
```

### Setting Environment Values

Environment values are set through the global `CurrentEnvironment`:

```swift
// Set a value before mounting
CurrentEnvironment.values.theme = "dark"

let app = Application {
    Route("/") { ThemedCard() }
}
app.mount()
```

> **Note:** The current implementation uses a single global `EnvironmentValues` instance. Future versions will support tree-scoped injection where subtrees can override parent values.

### Defining Complex Environment Values

Environment values can be any type -- enums, structs, or classes:

```swift
struct AppConfig {
    var apiBaseURL: String
    var debugMode: Bool
    var maxRetries: Int
}

struct AppConfigKey: EnvironmentKey {
    static var defaultValue: AppConfig {
        AppConfig(apiBaseURL: "https://api.example.com", debugMode: false, maxRetries: 3)
    }
}

extension EnvironmentValues {
    var appConfig: AppConfig {
        get { self[AppConfigKey.self] }
        set { self[AppConfigKey.self] = newValue }
    }
}

struct APIStatusBar: Tag {
    @Environment(\.appConfig) var config

    var body: some Tag {
        Div {
            Text("API: \(config.apiBaseURL)")
            if config.debugMode {
                Text("[DEBUG MODE]")
                    .foregroundColor(.red)
            }
        }
    }
}
```

---

## Reactivity Internals

Understanding how SwiftWUI's reactivity works helps you write more efficient components.

### The Render Cycle

1. **Initial render**: `Application.mount()` calls `withObservationTracking` around the first body evaluation.
2. **Tracking**: The Observation framework records which `@Observable` properties were accessed.
3. **Mutation**: When a tracked property changes, `onChange` fires during `willSet` (before the new value is available).
4. **Deferred re-render**: A `queueMicrotask` callback is scheduled so the re-render happens after the new value is set.
5. **Diffing**: The new tag tree is compared against the previous one via the `Reconciler`, producing `Patch` operations.
6. **DOM update**: Patches are applied to the real DOM through `DOMRenderer`.

### Route Caching

Route tags are cached in `RenderState` to preserve `@State` storage across re-renders. Without caching, each render cycle would create a new tag instance with fresh `@State` values, losing all user state.

The cache is invalidated when the route path changes, creating new tag instances (and fresh state) for the new route.

### Coalesced Updates

Multiple state changes within the same synchronous execution context are coalesced into a single re-render:

```swift
Button(onclick: {
    count += 1
    name = "Updated"
    isVisible = true
    // Only ONE re-render happens (after the microtask)
}) {
    Text("Update All")
}
```

---

## Best Practices

### Keep State Local

Declare `@State` as close to where it is used as possible. Avoid hoisting state to a parent tag unless children genuinely need to share it.

```swift
// Preferred: state is local to the component that uses it
struct ToggleSection: Tag {
    @State var isExpanded = false

    var body: some Tag {
        Div {
            Button(onclick: { isExpanded.toggle() }) {
                Text(isExpanded ? "Collapse" : "Expand")
            }
            if isExpanded {
                Text("Expanded content here")
            }
        }
    }
}
```

### Use @Observable for Shared State

When multiple tags need access to the same mutable data, use an `@Observable` class:

```swift
@Observable
class AppState {
    var user: String = "Guest"
    var itemCount: Int = 0
}

// Share a single instance across tags
let sharedState = AppState()
```

### Prefer Value Types in @State

For simple values (numbers, strings, booleans), use `@State` directly. Reserve `@Observable` classes for complex, multi-property models.

```swift
// Simple state -- use @State directly
@State var count = 0
@State var name = ""
@State var isVisible = true

// Complex state -- use @Observable class
@Observable
class FormData {
    var fields: [String: String] = [:]
    var isValid = false
    var errors: [String] = []
}
@State var form = FormData()
```

### Avoid Side Effects in body

The `body` property may be evaluated multiple times. Do not perform network requests, file I/O, or other side effects inside it.

```swift
// Bad -- side effect in body
var body: some Tag {
    let _ = fetchData() // Do NOT do this
    Text("Hello")
}

// Good -- trigger side effects from event handlers
var body: some Tag {
    Button(onclick: { fetchData() }) {
        Text("Load Data")
    }
}
```

---

## API Reference Summary

| Type | Module | Purpose |
|------|--------|---------|
| `State<Value>` | SwiftWUIState | Mutable state owned by a tag |
| `Binding<Value>` | SwiftWUIState | Two-way connection to mutable state |
| `ObservedObject<T>` | SwiftWUIState | Observes externally owned `@Observable` object |
| `Environment<Value>` | SwiftWUIState | Reads values from the environment |
| `EnvironmentKey` | SwiftWUIState | Protocol for defining environment keys |
| `EnvironmentValues` | SwiftWUIState | Collection of environment values |
| `CurrentEnvironment` | SwiftWUIState | Global access to current environment values |
