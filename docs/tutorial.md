# SwiftWUI Tutorial: Building a Todo App

This step-by-step tutorial walks you through building progressively more complex applications with SwiftWUI. You will start with a simple counter, evolve it into a full Todo app, add multi-page routing, and finish with animations.

**Prerequisites:**

- Swift 6.0+ toolchain with WebAssembly support
- The `swift-6.3.3-RELEASE_wasm` SDK installed
- Basic familiarity with Swift and SwiftUI concepts

---

## Table of Contents

1. [Part 1: Counter (Basics)](#part-1-counter-basics)
2. [Part 2: Todo App](#part-2-todo-app)
3. [Part 3: Multi-Page with Routing](#part-3-multi-page-with-routing)
4. [Part 4: Adding Animations](#part-4-adding-animations)

---

## Part 1: Counter (Basics)

In this section you will learn the core building blocks of SwiftWUI: the `Tag` protocol, `@State` for reactivity, event handling, and style modifiers.

### 1.1 Project Setup

Create a new Swift package for your app:

```bash
mkdir MyApp && cd MyApp
swift package init --type executable
```

Update your `Package.swift` to depend on SwiftWUI:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        // SwiftWUI is not yet published to a public registry; depend on your
        // local checkout. `swiftwui init` writes this path for you.
        .package(name: "SwiftWUI", path: "/path/to/SwiftWUI"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "SwiftWUI", package: "SwiftWUI"),
            ]
        ),
    ]
)
```

### 1.2 Your First Tag

The `Tag` protocol is the foundation of SwiftWUI, analogous to SwiftUI's `View`. Every component you create conforms to `Tag` and provides a `body` property that describes its content.

Create `Sources/main.swift`:

```swift
import SwiftWUI

struct Counter: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            H1 { "My Counter" }

            P {
                Text("Count: \(count)")
            }

            Button(onclick: { count += 1 }) {
                Text("Increment")
            }
        }
    }
}

let app = Application {
    Route("/") { Counter() }
}
app.mount()
```

**Key concepts introduced:**

- **`Tag` protocol** -- All components conform to `Tag` and declare a `body` property.
- **`@State`** -- A property wrapper that provides reactive mutable state. When `count` changes, the framework automatically re-renders the component.
- **`@TagBuilder`** -- A result builder (applied implicitly to `body`) that lets you compose multiple tags declaratively.
- **HTML tags** -- `Div`, `H1`, `P`, `Button`, and `Text` map directly to their HTML counterparts.
- **`Button(onclick:)`** -- The `onclick` parameter accepts a closure that runs when the button is clicked.
- **`Application`** and **`Route`** -- The entry point that mounts your app to the DOM.

### 1.3 Adding Style Modifiers

SwiftWUI provides type-safe CSS modifiers that you chain onto any `Tag`. Let's style the counter:

```swift
struct Counter: Tag {
    @State var count = 0

    var body: some Tag {
        Div {
            H1 { "My Counter" }
                .foregroundColor(.navy)
                .marginBottom(.px(16))

            P {
                Text("Count: \(count)")
            }
            .fontSize(.px(24))
            .fontWeight(.bold)

            Div {
                Button(onclick: { count -= 1 }) {
                    Text("-")
                }
                .padding(.px(8), .px(16))
                .fontSize(.px(20))
                .cursor(.pointer)
                .backgroundColor(.lightGray)
                .borderRadius(.px(4))

                Button(onclick: { count += 1 }) {
                    Text("+")
                }
                .padding(.px(8), .px(16))
                .fontSize(.px(20))
                .cursor(.pointer)
                .backgroundColor(.lightGray)
                .borderRadius(.px(4))
            }
            .display(.flex)
            .style("gap", "12px")
            .style("align-items", "center")
        }
        .padding(.px(32))
        .style("font-family", "system-ui, sans-serif")
    }
}
```

**Modifier highlights:**

| Modifier | Description | Example |
|---|---|---|
| `.padding(_:)` | CSS padding with type-safe units | `.padding(.px(16))` |
| `.padding(_:_:)` | Vertical and horizontal padding | `.padding(.px(8), .px(16))` |
| `.fontSize(_:)` | Font size | `.fontSize(.rem(1.5))` |
| `.fontWeight(_:)` | Font weight | `.fontWeight(.bold)` |
| `.cursor(_:)` | Mouse cursor | `.cursor(.pointer)` |
| `.backgroundColor(_:)` | Background color | `.backgroundColor(.red)` |
| `.foregroundColor(_:)` | Text color | `.foregroundColor(.navy)` |
| `.borderRadius(_:)` | Border radius | `.borderRadius(.px(8))` |
| `.display(_:)` | CSS display mode | `.display(.flex)` |
| `.opacity(_:)` | Opacity (0.0 to 1.0) | `.opacity(0.5)` |
| `.style(_:_:)` | Escape hatch for any CSS property | `.style("gap", "12px")` |

**CSS units available:**

- `.px(16)` -- pixels
- `.em(1.5)` -- relative to parent font size
- `.rem(1)` -- relative to root font size
- `.percent(50)` -- percentage
- `.vw(100)`, `.vh(100)` -- viewport width/height
- `.auto`, `.zero` -- special values

### 1.4 Building and Running

Build for WebAssembly and start the development server:

```bash
swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
npm run dev -- --port 8080
```

Open `http://localhost:8080` in your browser. You should see the counter with working increment and decrement buttons.

---

## Part 2: Todo App

Now let's build something more substantial: a Todo application with an input field, a list of items, and the ability to add and delete todos.

### 2.1 Data Model

Since `ForEach` requires `Identifiable` elements, define a simple `TodoItem` struct:

```swift
struct TodoItem: Identifiable {
    let id: String
    var text: String
}
```

### 2.2 The Complete Todo App

```swift
import SwiftWUI

struct TodoItem: Identifiable {
    let id: String
    var text: String
}

struct TodoApp: Tag {
    @State var todos: [TodoItem] = []
    @State var newTodo = ""

    var body: some Tag {
        Div {
            // -- Header --
            H1 { "Todo List" }
                .foregroundColor(.indigo)
                .marginBottom(.px(24))

            // -- Input row --
            Div {
                Input(
                    type: .text,
                    placeholder: "What needs to be done?",
                    value: newTodo,
                    oninput: {
                        // In a full binding scenario, this updates newTodo.
                        // See Section 2.3 for the binding pattern.
                    }
                )
                .style("flex", "1")
                .padding(.px(8))
                .fontSize(.px(16))
                .border(.px(1), .solid, .lightGray)
                .borderRadius(.px(4))

                Button(onclick: { addTodo() }) {
                    Text("Add")
                }
                .padding(.px(8), .px(16))
                .fontSize(.px(16))
                .cursor(.pointer)
                .backgroundColor(.indigo)
                .foregroundColor(.white)
                .border(.px(0), .none, .transparent)
                .borderRadius(.px(4))
            }
            .display(.flex)
            .style("gap", "8px")
            .marginBottom(.px(16))

            // -- Todo count --
            P {
                Text("\(todos.count) item\(todos.count == 1 ? "" : "s")")
            }
            .foregroundColor(.gray)
            .marginBottom(.px(12))

            // -- Todo list --
            if todos.isEmpty {
                P { "No todos yet. Add one above!" }
                    .foregroundColor(.gray)
                    .style("font-style", "italic")
            } else {
                Ul {
                    ForEach(todos) { todo in
                        Li {
                            Div {
                                Span { Text(todo.text) }
                                    .style("flex", "1")
                                    .fontSize(.px(16))

                                Button(onclick: { deleteTodo(id: todo.id) }) {
                                    Text("Delete")
                                }
                                .padding(.px(4), .px(12))
                                .fontSize(.px(14))
                                .cursor(.pointer)
                                .backgroundColor(.red)
                                .foregroundColor(.white)
                                .border(.px(0), .none, .transparent)
                                .borderRadius(.px(4))
                            }
                            .display(.flex)
                            .style("align-items", "center")
                            .style("gap", "12px")
                        }
                        .padding(.px(12), .zero)
                        .borderBottom(.px(1), .solid, .lightGray)
                        .style("list-style", "none")
                    }
                }
                .padding(.zero)
                .margin(.zero)
            }
        }
        .padding(.px(32))
        .style("max-width", "600px")
        .margin(.zero, .auto)
        .style("font-family", "system-ui, sans-serif")
    }

    // MARK: - Actions

    func addTodo() {
        let trimmed = newTodo.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let item = TodoItem(
            id: UUID().uuidString,
            text: trimmed
        )
        todos.append(item)
        newTodo = ""
    }

    func deleteTodo(id: String) {
        todos.removeAll { $0.id == id }
    }
}

// -- Entry point --

let app = Application {
    Route("/") { TodoApp() }
}
app.mount()
```

### 2.3 Understanding the Input Binding Pattern

SwiftWUI uses an `oninput` event handler on the `Input` tag. The `value` parameter sets the initial HTML `value` attribute, and the `oninput` closure fires on every keystroke so you can update your `@State`:

```swift
Input(
    type: .text,
    placeholder: "Enter text...",
    value: newTodo,
    oninput: {
        // The oninput handler fires on each keystroke.
        // In the WASM runtime, the event provides the new value
        // through the DOM bridge. You update your @State here.
    }
)
```

The `@State` property wrapper returns a `Binding` through its projected value (`$newTodo`). Bindings provide a `get`/`set` pair that reads and writes the underlying state:

```swift
@State var newTodo = ""

// $newTodo is Binding<String>
// $newTodo.wrappedValue reads the current value
// $newTodo.wrappedValue = "new" writes a new value
```

### 2.4 Conditional Rendering

The `@TagBuilder` supports `if/else` statements directly:

```swift
var body: some Tag {
    if todos.isEmpty {
        P { "No items yet." }
    } else {
        Ul {
            ForEach(todos) { todo in
                Li { Text(todo.text) }
            }
        }
    }
}
```

When the condition changes, SwiftWUI diffs the virtual DOM and efficiently swaps the rendered content.

### 2.5 ForEach and Collections

`ForEach` iterates over any `RandomAccessCollection` whose elements conform to `Identifiable`:

```swift
ForEach(todos) { todo in
    Li {
        Text(todo.text)
    }
}
```

Each element must have a stable `id` property so the reconciler can track additions, removals, and reordering efficiently.

### 2.6 Styling Best Practices

SwiftWUI offers two styling approaches:

**Type-safe modifiers** for common CSS properties:

```swift
Div { ... }
    .padding(.px(16))
    .backgroundColor(.white)
    .borderRadius(.px(8))
    .display(.flex)
```

**String-based escape hatch** for any CSS property not covered by type-safe modifiers:

```swift
Div { ... }
    .style("gap", "12px")
    .style("box-shadow", "0 2px 4px rgba(0,0,0,0.1)")
    .style("max-width", "600px")
```

**CSS classes** for external stylesheet integration:

```swift
Div { ... }
    .class("container")
    .class("mt-4")
```

**HTML attributes** for arbitrary attributes:

```swift
Input(type: .text)
    .attribute("aria-label", "Search")
    .attribute("data-testid", "search-input")
```

---

## Part 3: Multi-Page with Routing

SwiftWUI includes a built-in router for client-side navigation. You define routes declaratively and use `Link` for navigation between pages.

### 3.1 Defining Routes

The `Application` initializer accepts a `@RouteBuilder` block where you declare your routes:

```swift
import SwiftWUI

let app = Application {
    Route("/") { HomePage() }
    Route("/about") { AboutPage() }
    Route("/todos") { TodoApp() }
}
app.mount()
```

Each `Route` maps a URL path pattern to a Tag. When the browser URL matches a route pattern, that route's content is rendered.

### 3.2 Creating Pages

Define each page as a struct conforming to `Tag`:

```swift
struct HomePage: Tag {
    var body: some Tag {
        Div {
            H1 { "Welcome to SwiftWUI" }
                .foregroundColor(.indigo)

            P { "A Swift-native web UI framework powered by WebAssembly." }
                .fontSize(.px(18))
                .foregroundColor(.gray)

            Div {
                Link("/todos") {
                    Text("Open Todo App")
                }
                .padding(.px(8), .px(16))
                .backgroundColor(.indigo)
                .foregroundColor(.white)
                .borderRadius(.px(4))
                .style("text-decoration", "none")

                Link("/about") {
                    Text("About")
                }
                .padding(.px(8), .px(16))
                .backgroundColor(.teal)
                .foregroundColor(.white)
                .borderRadius(.px(4))
                .style("text-decoration", "none")
            }
            .display(.flex)
            .style("gap", "12px")
            .marginTop(.px(24))
        }
        .padding(.px(32))
        .style("font-family", "system-ui, sans-serif")
    }
}
```

### 3.3 Navigation with Link

The `Link` component renders an `<a>` tag that performs client-side navigation without a full page reload:

```swift
// With child content
Link("/about") {
    Text("About Us")
}

// With a title string
Link("About Us", destination: "/about")
```

Under the hood, `Link` uses the History API (`pushState`) so the browser URL updates and back/forward buttons work correctly.

### 3.4 Route Parameters

Routes support dynamic path segments using the `:param` syntax. Matched parameters are passed as a dictionary to the route builder:

```swift
let app = Application {
    Route("/") { HomePage() }
    Route("/users/:id") { params in
        AnyTag(UserProfile(userId: params["id"]!))
    }
    Route("/posts/:postId/comments") { params in
        AnyTag(Comments(postId: params["postId"]!))
    }
}
app.mount()
```

The `UserProfile` component receives the parameter as a regular property:

```swift
struct UserProfile: Tag {
    let userId: String

    var body: some Tag {
        Div {
            H1 { "User Profile" }
            P { Text("User ID: \(userId)") }

            Link("/") {
                Text("Back to Home")
            }
        }
        .padding(.px(32))
    }
}
```

### 3.5 Building a Navigation Layout

Create a reusable navigation bar by composing it with page content:

```swift
struct NavBar: Tag {
    var body: some Tag {
        Div {
            Link("/") { Text("Home") }
                .foregroundColor(.white)
                .style("text-decoration", "none")
                .marginRight(.px(16))

            Link("/todos") { Text("Todos") }
                .foregroundColor(.white)
                .style("text-decoration", "none")
                .marginRight(.px(16))

            Link("/about") { Text("About") }
                .foregroundColor(.white)
                .style("text-decoration", "none")
        }
        .display(.flex)
        .padding(.px(16))
        .backgroundColor(.indigo)
    }
}

struct PageLayout: Tag {
    let content: AnyTag

    init<T: Tag>(@TagBuilder content: () -> T) {
        self.content = AnyTag(content())
    }

    var body: some Tag {
        Div {
            NavBar()
            Div { content }
                .padding(.px(32))
        }
    }
}
```

### 3.6 Full Multi-Page Example

```swift
import SwiftWUI

struct HomePage: Tag {
    var body: some Tag {
        PageLayout {
            H1 { "Home" }
            P { "Welcome to our multi-page SwiftWUI app." }
        }
    }
}

struct AboutPage: Tag {
    var body: some Tag {
        PageLayout {
            H1 { "About" }
            P { "Built with SwiftWUI and WebAssembly." }
        }
    }
}

struct UserPage: Tag {
    let userId: String

    var body: some Tag {
        PageLayout {
            H1 { Text("User \(userId)") }
            P { "Viewing user profile." }
            Link("/") { Text("Back to Home") }
        }
    }
}

let app = Application {
    Route("/") { HomePage() }
    Route("/about") { AboutPage() }
    Route("/todos") { TodoApp() }
    Route("/users/:id") { params in
        AnyTag(UserPage(userId: params["id"]!))
    }
}
app.mount()
```

---

## Part 4: Adding Animations

SwiftWUI provides two mechanisms for animating UI changes: the imperative `withAnimation` function and the declarative `.animation()` modifier.

### 4.1 withAnimation

The `withAnimation` function wraps a state mutation so that any CSS style changes produced during the subsequent re-render are automatically transitioned:

```swift
struct AnimatedCard: Tag {
    @State var isExpanded = false

    var body: some Tag {
        Div {
            Button(onclick: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                Text(isExpanded ? "Collapse" : "Expand")
            }
            .padding(.px(8), .px(16))
            .cursor(.pointer)

            Div {
                P { "This content expands and collapses with a smooth animation." }
            }
            .height(isExpanded ? .auto : .zero)
            .opacity(isExpanded ? 1.0 : 0.0)
            .style("overflow", "hidden")
        }
        .padding(.px(24))
        .border(.px(1), .solid, .lightGray)
        .borderRadius(.px(8))
    }
}
```

**How it works:**

1. `withAnimation(.easeInOut(duration: 0.3))` sets a global `AnimationContext` before executing the closure.
2. The state mutation (`isExpanded.toggle()`) triggers a re-render on the next microtask.
3. During reconciliation, the `DOMRenderer` detects the active animation context and applies CSS `transition` properties to all elements whose styles have changed.
4. The browser smoothly transitions the old style values to the new ones.

### 4.2 Animation Presets

SwiftWUI provides several built-in animation presets:

```swift
// Default (0.3s ease-in-out)
withAnimation { isVisible.toggle() }

// Linear
withAnimation(.linear(duration: 0.5)) { ... }

// Ease-in
withAnimation(.easeIn(duration: 0.2)) { ... }

// Ease-out
withAnimation(.easeOut(duration: 0.4)) { ... }

// Ease-in-out with custom duration
withAnimation(.easeInOut(duration: 0.3)) { ... }

// Spring (cubic-bezier approximation with slight overshoot)
withAnimation(.spring) { ... }

// Bouncy spring (more pronounced overshoot)
withAnimation(.bouncy) { ... }

// Custom timing function
withAnimation(.custom(
    duration: 0.4,
    timingFunction: .cubicBezier(0.68, -0.55, 0.27, 1.55),
    delay: 0.1
)) { ... }
```

### 4.3 The .animation() Modifier

The `.animation()` modifier applies a permanent CSS `transition` to an element. Any future style changes on that element will be animated, regardless of whether `withAnimation` was used:

```swift
struct FadeButton: Tag {
    @State var isHovered = false

    var body: some Tag {
        Button(onclick: { }) {
            Text("Hover me")
        }
        .padding(.px(12), .px(24))
        .backgroundColor(isHovered ? .indigo : .lightGray)
        .foregroundColor(isHovered ? .white : .black)
        .borderRadius(.px(8))
        .animation(.easeInOut(duration: 0.3))
    }
}
```

The `.animation()` modifier translates to a CSS `transition: all 0.3s ease-in-out` on the element, so browsers handle the interpolation natively.

### 4.4 Animation Modifiers

Animations can be further customized with modifier methods:

```swift
// Add a delay before the animation starts
withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
    isVisible.toggle()
}

// Speed up or slow down an animation
withAnimation(.spring.speed(1.5)) {
    isExpanded.toggle()
}
```

### 4.5 Animated Todo App

Let's combine everything to add animations to the Todo app. The key changes are wrapping state mutations in `withAnimation` and adding `.animation()` modifiers to elements that should transition smoothly:

```swift
struct AnimatedTodoApp: Tag {
    @State var todos: [TodoItem] = []
    @State var newTodo = ""

    var body: some Tag {
        Div {
            H1 { "Animated Todos" }
                .foregroundColor(.indigo)
                .marginBottom(.px(24))

            // Input row
            Div {
                Input(
                    type: .text,
                    placeholder: "Add a todo...",
                    value: newTodo
                )
                .style("flex", "1")
                .padding(.px(10))
                .fontSize(.px(16))
                .border(.px(2), .solid, .lightGray)
                .borderRadius(.px(6))
                .animation(.easeInOut(duration: 0.2))

                Button(onclick: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        addTodo()
                    }
                }) {
                    Text("Add")
                }
                .padding(.px(10), .px(20))
                .fontSize(.px(16))
                .cursor(.pointer)
                .backgroundColor(.indigo)
                .foregroundColor(.white)
                .border(.px(0), .none, .transparent)
                .borderRadius(.px(6))
                .animation(.easeInOut(duration: 0.2))
            }
            .display(.flex)
            .style("gap", "10px")
            .marginBottom(.px(20))

            // Todo list
            Ul {
                ForEach(todos) { todo in
                    Li {
                        Div {
                            Span { Text(todo.text) }
                                .style("flex", "1")

                            Button(onclick: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    deleteTodo(id: todo.id)
                                }
                            }) {
                                Text("Delete")
                            }
                            .padding(.px(4), .px(12))
                            .cursor(.pointer)
                            .backgroundColor(.red)
                            .foregroundColor(.white)
                            .border(.px(0), .none, .transparent)
                            .borderRadius(.px(4))
                            .opacity(0.8)
                            .animation(.easeInOut(duration: 0.15))
                        }
                        .display(.flex)
                        .style("align-items", "center")
                    }
                    .padding(.px(12))
                    .marginBottom(.px(8))
                    .backgroundColor(.white)
                    .borderRadius(.px(6))
                    .style("box-shadow", "0 1px 3px rgba(0,0,0,0.1)")
                    .style("list-style", "none")
                    .animation(.easeInOut(duration: 0.3))
                }
            }
            .padding(.zero)
            .margin(.zero)
        }
        .padding(.px(32))
        .style("max-width", "600px")
        .margin(.zero, .auto)
        .style("font-family", "system-ui, sans-serif")
        .backgroundColor(.init(hex: "#f5f5f5"))
        .style("min-height", "100vh")
    }

    func addTodo() {
        let trimmed = newTodo.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        todos.append(TodoItem(id: UUID().uuidString, text: trimmed))
        newTodo = ""
    }

    func deleteTodo(id: String) {
        todos.removeAll { $0.id == id }
    }
}
```

### 4.6 Summary of Animation APIs

| API | Purpose | Scope |
|---|---|---|
| `withAnimation(_:_:)` | Wrap a state mutation so the resulting re-render applies CSS transitions | One-shot; applies only to the changes from that mutation |
| `.animation(_:)` | Apply a permanent CSS transition to an element | Persistent; all future style changes on that element are animated |
| `.spring` | Spring-like cubic-bezier preset | Duration: 0.5s |
| `.bouncy` | Bouncier spring preset | Duration: 0.6s |
| `.easeInOut(duration:)` | Smooth ease-in-out curve | Custom duration |
| `.delay(_:)` | Add a delay before animation starts | Modifier on any `Animation` |
| `.speed(_:)` | Scale the duration by a multiplier | Modifier on any `Animation` |

---

## Next Steps

- Read the [Architecture Guide](./architecture.md) to understand how SwiftWUI works internally.
- Explore the `SwiftWUIBrowser` module for `@AppStorage` (localStorage), `Geolocation`, `Clipboard`, and `MediaQuery` APIs.
- Check the `SwiftWUIState` module for `@ObservedObject` and `@Environment` patterns.
- Look at the `Examples/Counter` directory in the repository for a working reference project.
