# Routing

SwiftWUI includes a built-in client-side router that maps URL paths to tags, enabling single-page application (SPA) navigation without full page reloads. The routing system integrates with the browser's History API so that back/forward buttons work as expected.

## Table of Contents

- [Basic Setup](#basic-setup)
- [Single Page (No Routing)](#single-page-no-routing)
- [Route Parameters](#route-parameters)
- [Link Navigation](#link-navigation)
- [Programmatic Navigation](#programmatic-navigation)
- [NavigationStack](#navigationstack)
- [History API Integration](#history-api-integration)
- [Route Matching Rules](#route-matching-rules)
- [Complete Example](#complete-example)
- [Best Practices](#best-practices)

---

## Basic Setup

Create an `Application` with routes defined using the `@RouteBuilder` result builder. Each `Route` maps a URL path pattern to a tag.

```swift
import SwiftWUI

let app = Application {
    Route("/") { HomePage() }
    Route("/about") { AboutPage() }
    Route("/contact") { ContactPage() }
}
app.mount()
```

The `mount()` call attaches the application to a DOM element with `id="app"` by default. You can specify a different container:

```swift
app.mount(on: "my-container")
```

Your HTML file should include a matching container element:

```html
<!DOCTYPE html>
<html>
<body>
    <div id="app"></div>
    <script type="module" src="main.js"></script>
</body>
</html>
```

---

## Single Page (No Routing)

If your application does not need routing, use the `page:` initializer. This creates a single-route application mounted at `/`.

```swift
let app = Application(page: { CounterApp() })
app.mount()
```

This is equivalent to:

```swift
let app = Application {
    Route("/") { CounterApp() }
}
app.mount()
```

---

## Route Parameters

Routes support dynamic segments prefixed with `:`. These segments extract values from the URL and pass them as a `[String: String]` dictionary to the route builder.

### Single Parameter

```swift
Route("/users/:id") { params in
    AnyTag(UserPage(id: params["id"]!))
}
```

### Multiple Parameters

```swift
Route("/posts/:postId/comments/:commentId") { params in
    AnyTag(CommentPage(
        postId: params["postId"]!,
        commentId: params["commentId"]!
    ))
}
```

### Parameter Route Initializer

The parameterized route initializer expects a closure that takes `[String: String]` and returns `AnyTag`:

```swift
Route("/users/:id", content: { params in
    AnyTag(UserProfile(userId: params["id"] ?? ""))
})
```

### Static Routes (No Parameters)

Static routes use the `@TagBuilder` closure syntax and do not receive parameters:

```swift
Route("/") { HomePage() }
Route("/about") { AboutPage() }
Route("/settings") { SettingsPage() }
```

---

## Link Navigation

The `Link` component renders an `<a>` tag that triggers client-side navigation instead of a full page reload.

### Link with Content Builder

```swift
Link("/about") {
    Text("About Us")
}
```

This renders:

```html
<a href="/about" data-swiftwui-link="true">About Us</a>
```

### Link with Title String

For simple text links, use the convenience initializer:

```swift
Link("Go to About", destination: "/about")
```

### Link with Styled Content

You can put any tag content inside a `Link`:

```swift
Link("/dashboard") {
    Div {
        H2 { "Dashboard" }
        P { "View your analytics" }
    }
    .padding(.px(16))
    .backgroundColor(.hex("#f0f0f0"))
    .borderRadius(.px(8))
}
```

### Navigation Behavior

`Link` components are intercepted by the SwiftWUI runtime. When clicked:

1. The default browser navigation is prevented.
2. `router.navigate(to:)` is called with the destination path.
3. The browser URL is updated via `history.pushState`.
4. The matched route's tag is rendered.

The `data-swiftwui-link="true"` attribute is how the runtime identifies links that should be handled client-side.

---

## Programmatic Navigation

The `Router` class provides methods for navigating programmatically from event handlers and business logic.

### Router.navigate(to:)

```swift
// Inside a tag with access to the router
Button(onclick: {
    router.navigate(to: "/settings")
}) {
    Text("Go to Settings")
}
```

### Router API

```swift
// Navigate to a path
router.navigate(to: "/users/42")

// Read the current path
let path = router.currentPath  // e.g., "/users/42"

// Read extracted parameters from the current route
let params = router.currentParams  // e.g., ["id": "42"]

// Find the matching route for a path
let route = router.matchedRoute(for: "/about")  // Route?

// Get the matched tag for a path
let tag = router.matchedTag(for: "/about")  // AnyTag?
```

---

## NavigationStack

`NavigationStack` is a container component that renders the currently matched route's content. It is used internally by `Application`, but you can also use it directly for more control.

### Basic Usage

```swift
struct App: Tag {
    let router: Router

    var body: some Tag {
        Div {
            NavBar()
            NavigationStack(router: router)
        }
    }
}
```

### With Fallback (404 Page)

Provide a fallback tag that renders when no route matches the current path:

```swift
NavigationStack(router: router) {
    Div {
        H1 { "404 - Page Not Found" }
        P { "The page you are looking for does not exist." }
        Link("/") { Text("Go Home") }
    }
}
```

If no fallback is provided, `NavigationStack` renders a default "Page not found" message with the unmatched path.

---

## History API Integration

SwiftWUI integrates with the browser's History API to provide a native-feeling navigation experience.

### How It Works

- **Link clicks**: When a `Link` is clicked, the runtime calls `history.pushState` to update the URL without reloading the page.
- **Back/forward buttons**: The runtime listens for `popstate` events and calls `router.navigate(to:)` with the restored path.
- **Initial load**: The application reads `window.location.pathname` to determine the initial route.

### URL Updates

When `router.navigate(to:)` is called (either from a `Link` click or programmatically), the browser URL bar updates to reflect the new path. No server request is made -- the new route's tag is rendered client-side.

### Server-Side Considerations

Since all routes are handled client-side, your web server must be configured to serve your `index.html` for all paths. This is sometimes called "fallback" or "history mode" routing.

With Vite (the recommended dev server):

```js
// vite.config.js
export default {
    appType: 'spa',
    // Vite serves index.html for all routes by default in SPA mode
}
```

For production servers (nginx example):

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

---

## Route Matching Rules

The router matches URL paths against route patterns using the following rules:

1. **Exact segment count**: The URL and pattern must have the same number of path segments.
2. **Static segments**: Non-parameter segments must match exactly.
3. **Parameter segments**: Segments starting with `:` match any value and extract it as a named parameter.
4. **First match wins**: Routes are tested in declaration order. The first matching route is used.

### Examples

| Pattern | URL | Match? | Parameters |
|---------|-----|--------|------------|
| `/` | `/` | Yes | `{}` |
| `/about` | `/about` | Yes | `{}` |
| `/about` | `/contact` | No | -- |
| `/users/:id` | `/users/42` | Yes | `{"id": "42"}` |
| `/users/:id` | `/users/42/posts` | No | -- |
| `/posts/:id/comments` | `/posts/5/comments` | Yes | `{"id": "5"}` |
| `/posts/:postId/comments/:commentId` | `/posts/5/comments/12` | Yes | `{"postId": "5", "commentId": "12"}` |

### Route Priority

Since the router uses first-match ordering, place more specific routes before general ones:

```swift
let app = Application {
    Route("/users/me") { MyProfilePage() }        // Specific: must come first
    Route("/users/:id") { params in                // General: matches any /users/X
        AnyTag(UserPage(id: params["id"]!))
    }
    Route("/") { HomePage() }
}
```

---

## Complete Example

Here is a full multi-page application with routing, navigation links, and route parameters:

```swift
import SwiftWUI

// MARK: - Pages

struct HomePage: Tag {
    var body: some Tag {
        Div {
            H1 { "Welcome to SwiftWUI" }
            P { "A Swift-based web framework using WebAssembly." }
            Link("/users") {
                Text("View Users")
            }
        }
        .padding(.px(32))
    }
}

struct UserListPage: Tag {
    let users = ["Alice", "Bob", "Charlie"]

    var body: some Tag {
        Div {
            H1 { "Users" }
            ForEach(users.indices) { i in
                Link("/users/\(i)") {
                    P { Text(users[i]) }
                }
            }
            Link("/") { Text("Back to Home") }
        }
        .padding(.px(32))
    }
}

struct UserDetailPage: Tag {
    let id: String

    var body: some Tag {
        Div {
            H1 { "User Profile" }
            P { Text("User ID: \(id)") }
            Link("/users") { Text("Back to Users") }
        }
        .padding(.px(32))
    }
}

// MARK: - App

let app = Application {
    Route("/") { HomePage() }
    Route("/users") { UserListPage() }
    Route("/users/:id") { params in
        AnyTag(UserDetailPage(id: params["id"]!))
    }
}
app.mount()
```

---

## Best Practices

### Organize Routes Clearly

For applications with many routes, group related routes together with comments:

```swift
let app = Application {
    // Public pages
    Route("/") { HomePage() }
    Route("/about") { AboutPage() }
    Route("/contact") { ContactPage() }

    // User pages
    Route("/users") { UserListPage() }
    Route("/users/:id") { params in
        AnyTag(UserDetailPage(id: params["id"]!))
    }

    // Settings
    Route("/settings") { SettingsPage() }
}
```

### Validate Route Parameters

Always handle missing or invalid parameters gracefully:

```swift
Route("/users/:id") { params in
    if let id = params["id"], !id.isEmpty {
        AnyTag(UserDetailPage(id: id))
    } else {
        AnyTag(Text("Invalid user ID"))
    }
}
```

### Preserve State Across Navigation

Route tags are cached by the runtime to preserve `@State` storage when the same route re-renders. However, navigating away from a route and back creates a new tag instance with fresh state. If you need persistent state across navigation, store it in a shared `@Observable` model rather than in `@State`.

---

## API Reference Summary

| Type | Module | Purpose |
|------|--------|---------|
| `Application` | SwiftWUIRuntime | Main entry point; mounts the app to the DOM |
| `Router` | SwiftWUIRouter | Manages current path, route matching, and navigation |
| `Route` | SwiftWUIRouter | Maps a URL path pattern to a tag builder |
| `RouteBuilder` | SwiftWUIRouter | Result builder for declaring routes |
| `Link` | SwiftWUIRouter | Client-side navigation anchor element |
| `NavigationStack` | SwiftWUIRouter | Renders the current route's content with optional fallback |
