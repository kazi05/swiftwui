# Browser APIs

System signals, persisted storage, fetch, and file selection — reactive
browser capabilities available through ``Environment`` and dedicated
property wrappers.

## Overview

All four capabilities report safe defaults outside a live runtime (light
scheme, online, empty storage, an "unsupported" fetch session) so the same
component compiles, tests, and prerenders on native/SSG without a browser.

### Color scheme and online status

`colorScheme` reflects the OS/browser's `prefers-color-scheme`; `isOnline`
reflects `navigator.onLine`. Both are reactive **only when read inside a
component's `body`** — reads in `.task` closures or event handlers don't
trigger a re-render.

```swift
struct Banner: Tag {
    @Environment(\.colorScheme) var scheme
    @Environment(\.isOnline) var isOnline
    var body: some Tag {
        Div {
            if !isOnline { P { "You're offline." } }
            P { "System theme: \(scheme == .dark ? "dark" : "light")" }
        }
    }
}
```

`colorScheme` is the system preference only — a manual dark-mode toggle is
the themes system's job (`setTheme`, `data-theme`), not this signal.

### Persisted state

`@AppStorage` persists to `localStorage` (survives reloads, syncs across
tabs); `@SceneStorage` persists to `sessionStorage` (per-tab, no cross-tab
sync). Both wrap `Bool`, `Int`, `Double`, `String`, `URL`, `Data`, and
`Optional` of each; a `RawRepresentable` enum opts in with one line:

```swift
enum Theme: String { case light, dark }
extension Theme: StorageConvertible {}

struct Settings: Tag {
    @AppStorage("settings.theme") var theme = Theme.light
    var body: some Tag {
        Button("Theme: \(theme.rawValue)") {
            theme = theme == .light ? .dark : .light
        }
    }
}
```

Web storage is plaintext and readable by any script on the origin — never
store secrets, tokens, or sensitive data in `@AppStorage`/`@SceneStorage`.
The `__swiftwui.` key prefix is reserved for the framework.

### Fetching data

`@Environment(\.webSession)` gives a `WebSession`, shaped like
`URLSession`: `data(for:)`/`data(from:)` return the raw response regardless
of status; the `Codable` sugar (`json(from:)`, `send(_:_:json:)`) throws
`WebFetchError.httpStatus` on a non-2xx response. URLs are absolute
`http`/`https` or origin-relative; requests send same-origin credentials.
`.task(policy: .build)` fetches also run at SSG build time over a real
`URLSession` transport — keep those URLs trusted and static.

```swift
struct ItemList: Tag {
    @Environment(\.webSession) var session
    @State private var items: [String] = []
    struct Payload: Decodable { let items: [String] }

    var body: some Tag {
        Div {
            Button("Load") {
                Task {
                    if let p: Payload = try? await session.json(from: "/data.json") {
                        items = p.items
                    }
                }
            }
            Ul { ForEach(items, id: \.self) { item in Li { Text(item) } } }
        }
    }
}
```

Cancelling the enclosing `Task` aborts the underlying request.

### File selection

`Input(type: .file, accept:, multiple:)` combined with `.onFileSelection`
delivers the picked files as `[WebFile]`. A plain `.onChange` handler never
fires on a file input — `onFileSelection` is the only way to read a
selection.

```swift
struct FilePreview: Tag {
    @State private var preview = ""
    var body: some Tag {
        Div {
            Input(type: .file, accept: ".txt,text/plain")
                .onFileSelection { files in
                    guard let f = files.first, f.size < 1_000_000 else { return }
                    Task { preview = (try? await f.text()) ?? "" }
                }
            Pre { Text(preview) }
        }
    }
}
```

`WebFile.name`, `.mimeType`, `.size`, and `.lastModified` are claims made by
the client, not verified facts — never use `mimeType` to make a security
decision (validate bytes instead), never build a filesystem path from
`name`, and check `size` before calling `data()`/`text()`, which buffer the
whole file into memory.

### See it running

`Examples/Counter` ships a `BrowserAPIDemo` component exercising all four
capabilities together.
