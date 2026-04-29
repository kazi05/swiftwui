# SwiftWUI: Production Feature Gap Analysis

Senior frontend perspective. Each item: feature, why, API sketch, approach, effort.

---

## 1. Forms with validation

**Why.** `Form`/`Input` are raw HTML wrappers. Real apps need a typed, schema-driven controller (RHF/Formik analogue).

```swift
public protocol FormSchema: Sendable {
    associatedtype Values: Sendable
    static var initial: Values { get }
    static func validate(_ v: Values) -> [PartialKeyPath<Values>: String]
}

@Observable public final class FormState<S: FormSchema> {
    public var values: S.Values = S.initial
    public var errors: [PartialKeyPath<S.Values>: String] = [:]
    public var touched: Set<PartialKeyPath<S.Values>> = []
    public var isSubmitting = false
    public func bind<V>(_ kp: WritableKeyPath<S.Values, V>) -> Binding<V> { ... }
    public func submit(_ action: @Sendable (S.Values) async throws -> Void) async { ... }
}

Form(state: $form) {
    TextField("Email", text: $form.bind(\.email))
        .formError($form.errors[\.email])
    Button("Sign in") { Task { await form.submit(api.signIn) } }
        .disabled(form.isSubmitting || !form.errors.isEmpty)
}
```

**Approach.** Build `FormState<S>` on top of `@Observable`, reuse existing `Binding`. Validation runs `onChange` (already shipped) plus on submit. `.formError(_:)` modifier renders `<span role="alert" aria-live="polite">`. Server actions: typed `FormAction<Input, Output>` POSTed via `URLSession`/`fetch`. Add `.formAction(myAction)` that wires `<form action method=POST>` for progressive enhancement (no-JS submit works).

**Effort.** L.

---

## 2. Async data loading + boundaries

**Why.** `.task` runs work but has no loading/error UX, no cancellation, no de-duping, no cache. Every team rebuilds this.

```swift
@Observable public final class AsyncResource<T: Sendable> {
    public enum Phase { case idle, loading, success(T), failure(Error) }
    public var phase: Phase = .idle
    public func load(_ op: @Sendable (AbortSignal) async throws -> T) async { ... }
    public func cancel() { signal.abort() }
}

AsyncBoundary(loading: { Spinner() }, error: { e in ErrorView(e) }) {
    let user = useResource(key: "user/\(id)") { signal in
        try await api.fetchUser(id, signal: signal)
    }
    UserCard(user: user)
}

AsyncImage(url: avatarURL, placeholder: { BlurHash(hash) })
```

**Approach.** `AsyncResource` wraps `Task` + `JSObject.global.AbortController`. `AsyncBoundary` is a Tag that walks children, finds resources via environment, picks the right phase. `useResource` is keyed cache (SWR-style) in `EnvironmentValues`. Cancellation on unmount via `lifecycle(.unmount)` observer.

**Effort.** M.

---

## 3. Streaming SSR + hydration

**Why.** `StaticRenderer` produces full strings. For TTFB you need chunked `text/html` and a way to mark "client-only" islands so hydration knows where to attach.

```swift
public protocol Hydratable: Tag { var hydrationID: String { get } }

public struct ClientOnly<T: Tag>: Tag { let id: String; let content: T }
public struct ServerOnly<T: Tag>: Tag { let content: T }

let stream = StreamingRenderer().stream(page)  // AsyncSequence<ByteBuffer>
for try await chunk in stream { try await response.body.write(chunk) }
```

**Approach.**
- During SSR, emit `data-swui-h="<id>"` markers on stateful tags. Persist initial `@State` snapshots into `<script id="__swui_state__" type="application/json">`.
- Streaming renderer flushes after `<head>` and after each top-level `<section>`. Suspense boundary emits placeholder, replaces via `<template>` + tiny inline JS when promise resolves (React-style).
- Client `Application.hydrate(rootID:)` walks DOM, matches `data-swui-h`, restores state, attaches event listeners without re-creating nodes. Mismatch handler logs + falls back to client render of the mismatched subtree only.
- `SwiftWUIDevServer` already has Vapor — add `app.get(streaming:)` route emitting `Response.Body` chunks.

**Effort.** L.

---

## 4. Routing improvements

**Why.** Current `Router` is flat; no nested layouts, no loaders, no guards, no search params. Modern apps need all four.

```swift
Router {
    Route("/", layout: RootLayout.self) {
        Route("", page: HomePage.self)
        Route("dashboard", layout: DashLayout.self) {
            Route("", loader: DashLoader(), page: Dash.self)
                .guard { ctx in ctx.user != nil ? .allow : .redirect("/login") }
            Route("orders/:id", loader: OrderLoader(), page: OrderPage.self)
        }
    }
}

protocol RouteLoader: Sendable {
    associatedtype Data: Sendable
    func load(_ ctx: RouteContext) async throws -> Data
}

@Environment(\.searchParams) var query  // [String: String]
@Environment(\.routeData) var data: OrderData
```

**Approach.** Extend `Route` with `parent`, `layout`, `loader`, `guard`. Match returns chain `[Route]`; render nests layouts. Loaders run in parallel via `TaskGroup`, results injected through `EnvironmentValues`. Search params parsed from `location.search`, hash from `location.hash`. Add `.replace` navigation, scroll restoration via `history.scrollRestoration = "manual"` + saved positions per `popstate`.

**Effort.** L.

---

## 5. Animations / Transitions

**Why.** `Animation`/`TagTransition` cover CSS basics. Missing: shared element transitions, View Transitions API, gestures, FLIP layout animations.

```swift
Image(...).matchedGeometry(id: "hero", in: ns)  // SwiftUI parity

.viewTransition(name: "card-\(id)")  // browser View Transitions API
withTransition(.crossfade) { router.navigate(to: "/detail/\(id)") }

DragGesture()
    .onChanged { v in offset = v.translation }
    .onEnded { v in withAnimation(.spring) { offset = .zero } }

.animation(.spring(response: 0.4, damping: 0.7), value: scale)  // physics
```

**Approach.**
- `matchedGeometry`: emit `view-transition-name: hero-id` and call `document.startViewTransition(...)` from runtime when both sides exist across renders. Falls back to FLIP (measure pre/post bounding rects, animate `transform`).
- Spring physics: solve damped harmonic at render time, interpolate `transform` via WAAPI (`element.animate(...)`) instead of CSS transition for non-linear curves.
- Gestures: pointer-events-based `DragGesture`, `MagnifyGesture` over existing event listeners. Reuse `EventHandlerRegistry`.

**Effort.** L.

---

## 6. Image handling

**Why.** `Img` is a thin `<img>`. Modern apps need `srcset`, lazy loading, LQIP/blurhash, AVIF/WebP picking, aspect ratio reservations.

```swift
Image(src: "/hero.jpg",
      sources: [.avif("/hero.avif"), .webp("/hero.webp")],
      sizes: [.w(400), .w(800), .w(1600)],
      alt: "Hero",
      placeholder: .blurhash("LKO2?U%2Tw=w]~RBVZRi"),
      loading: .lazy,
      aspectRatio: 16/9)
```

**Approach.** Render as `<picture>` with `<source srcset="... 400w, ... 800w" type="image/avif">` + `<img loading="lazy" decoding="async">`. Aspect ratio reserves space (`aspect-ratio: 16/9`) to avoid CLS. Blurhash decoded client-side to canvas, swapped on `load`. Use `WebObserver.intersection` (already shipped) for custom lazy strategies. Server-side `image-optimizer` Vapor route for variants.

**Effort.** M.

---

## 7. Form input components (SwiftUI parity)

**Why.** Apps want `TextField`, `Toggle`, `Picker`, `DatePicker`, `Stepper`, `Slider`, `ColorPicker` with `Binding`, not raw `<input>`.

```swift
TextField("Email", text: $email).keyboardType(.email).autocapitalization(.none)
SecureField("Password", text: $password).textContentType(.newPassword)
Toggle("Notifications", isOn: $on)
Picker("Country", selection: $country) {
    ForEach(countries) { Text($0.name).tag($0.code) }
}
DatePicker("Birthday", selection: $date, in: ...Date.now)
Stepper("\(qty)", value: $qty, in: 1...99)
Slider(value: $vol, in: 0...1)
ColorPicker("Accent", selection: $color)
```

**Approach.** Each is a struct over existing `Input`/`Select`/`Textarea` with `Binding`. Two-way binding via `oninput` reading `InputEventContext.currentValue`. `keyboardType` maps to `inputmode`/`type`. `Picker` chooses `<select>` for short lists, custom popover (see #13) for long. `DatePicker`: native `<input type="date">` on mobile, custom calendar on desktop via media query.

**Effort.** M.

---

## 8. List virtualization

**Why.** Rendering 10k rows kills WASM. Need windowed/virtualized list.

```swift
LazyVStack(spacing: 8) {
    ForEach(items) { row in RowView(row) }
}

VirtualList(items, estimatedRowHeight: 56) { item in RowView(item) }
    .onAppear(of: items.last) { Task { await loadMore() } }
```

**Approach.** `VirtualList` keeps a viewport sentinel `Div` with `WebObserver.resize` on container + `intersection` on rows. Renders only `visibleRange`, pads with `height: <total>px` spacer. `ForEach` already keys by id — reuse for stable patches. Bonus: `LazyVStack` lazy-mounts via intersection observer threshold 0 (defer offscreen children).

**Effort.** M.

---

## 9. Drag-and-drop

**Why.** Kanban/file-upload UIs are common. HTML5 DnD is awkward; pointer events scale better for touch.

```swift
DraggableList($items) { item in RowView(item) }  // reorderable

Card().draggable(payload: card) { GhostCard(card) }
DropZone<Card>(accepts: .types(["card"])) { card in board.move(card) }
    .onDragEnter { ... }.onDragLeave { ... }
```

**Approach.** Two backends. (a) HTML5 DnD via existing event listeners (`dragstart`, `dragover`, `drop`) — works for files. (b) Pointer-events implementation for in-app reordering, computes drop targets via `elementsFromPoint`. `draggable` modifier sets attribute + listeners. `DropZone<T>` is generic over payload, type-checked at compile time; serialize payload via `Codable` to `dataTransfer`.

**Effort.** M.

---

## 10. i18n

**Why.** `LocalizedStringCatalog` exists but lacks plurals, ICU, RTL, lazy locale loading.

```swift
Text(.localized("cart.items", count: items.count))  // ICU plural

let catalog = ICUCatalog.load(from: "/locales/{locale}.json", lazy: true)
let app = App().environment(\.locale, "ru-RU").environment(\.catalog, catalog)

@Environment(\.layoutDirection) var dir  // .ltr / .rtl
```

**Approach.** Adopt MessageFormat 2 (subset). Plural rules from CLDR-lite per locale (just `zero/one/few/many/other`). `LocalizedStringKey` carries args + format. Lazy: `await catalog.load(locale)` on route enter, gate render with `AsyncBoundary`. Auto `dir="rtl"` on `<html>` for `ar`, `he`, `fa`. Logical CSS properties (`margin-inline-start`) instead of left/right in `StyleProxy`.

**Effort.** M.

---

## 11. Theming

**Why.** Designers want token systems; users want dark mode toggle that beats `prefers-color-scheme`.

```swift
struct AppTheme: Theme {
    static let light = AppTheme(bg: .hex(0xFFFFFF), fg: .hex(0x111))
    static let dark  = AppTheme(bg: .hex(0x111), fg: .hex(0xEEE))
    let bg, fg, accent, danger: CSSColor
}

@Environment(\.theme) var theme
.background(theme.bg).foregroundColor(theme.fg)

ThemeProvider(.system) { ContentView() }   // system | .light | .dark | .custom
```

**Approach.** Theme = struct of `CSSColor` (already exist). Emit as CSS custom properties (`:root { --bg: ...; }` and `[data-theme=dark] { --bg: ...; }`) via `StyleSheetManager`. `ColorScheme.system` listens to `MediaQueryState.colorScheme`. User preference persisted via existing `AppStorage`. Token referencing: `.background(.token(\.bg))` → `var(--bg)`.

**Effort.** S.

---

## 12. Accessibility

**Why.** No first-class a11y modifiers. Real apps need ARIA, focus management, keyboard nav, announcements.

```swift
Button("Close").accessibilityLabel("Close dialog").accessibilityHint("Esc")
Image(...).accessibilityHidden(true)
Div { ... }.accessibilityRole(.dialog).accessibilityModal(true)

@FocusState var field: Field?
TextField(...).focused($field, equals: .email)
.onAppear { field = .email }

LiveRegion(.polite) { Text(announcement) }
```

**Approach.** Add `AccessibilityModifier` setting `aria-*` attributes. `@FocusState` + `.focused()` reads/writes via `JSObject.global.document.activeElement` + `element.focus()`. Keyboard nav: `.onKeyPress(.escape)`, focus trap utility for modals. `LiveRegion` is a Tag with `aria-live` + queued mutations. Add automated checks in dev mode (axe-core via JSObject) — surface in error overlay (#19).

**Effort.** M.

---

## 13. Toasts / Modals / Sheets

**Why.** Every app needs them. Without a portal/focus-trap primitive, teams reinvent badly.

```swift
@Environment(\.toaster) var toaster
toaster.show(.success("Saved"))

.sheet(isPresented: $showing, detents: [.medium, .large]) { EditView() }
.alert("Delete?", isPresented: $confirm) { Button("Delete", role: .destructive) {} }
.popover(isPresented: $showing, arrowEdge: .bottom) { Picker(...) }
```

**Approach.** New `OverlayHost` Tag mounted once at app root; renders via portal (append to `document.body`). `OverlayManager` (env value) holds stack. Each overlay: focus-trap (cycle within), `Esc` closes top, restore focus on close, `inert` on background, `<dialog>` element where supported. Sheets reuse `TagTransition.moveUp`. Toasts: stack manager with timeout + swipe-to-dismiss via #5 gestures.

**Effort.** M.

---

## 14. Web Workers

**Why.** Heavy work (parsing, search, image processing) blocks the WASM main thread.

```swift
let worker = WebWorker<SearchAPI>(SearchWorker.self)
let results = try await worker.call(\.search, query: q)
```

**Approach.** Two WASM instances — main + worker — share via `postMessage`. Codegen typed proxy from a `protocol` (Comlink-style) using a macro: each method becomes `postMessage` + awaited reply. Structured-clone bridge in `JSObject`. Worker registry sends `MessagePort` for transferables. Until WASM threads ship in browsers, this is the practical concurrency story.

**Effort.** L.

---

## 15. Service Worker / PWA

**Why.** Offline, installable, push notifications. Core for any consumer app.

```swift
ManifestBuilder()
    .name("My App").themeColor(.hex(0x0A84FF))
    .icons([.png(192), .png(512), .maskable(512)])
    .display(.standalone)
    .build()  // generated by SwiftWUIDevServer at /manifest.webmanifest

ServiceWorker.register(strategy: .networkFirst(["/api/*"]))
PushNotifications.subscribe(vapidKey: "...")
```

**Approach.** `ProductionBuilder` emits `manifest.webmanifest`, precaches build hash list as `__SWUI_PRECACHE__`. Generic JS service worker template (Workbox-lite) parameterized by Swift-declared strategies. `SwiftWUIDevServer` serves correct headers. Push: register via `JSObject`, store subscription, expose `Notification` API surface.

**Effort.** M.

---

## 16. WebSockets / SSE

**Why.** Realtime is table-stakes (chat, dashboards, collab). The dev server already uses WS for HMR — extend.

```swift
@Observable final class ChatChannel: WebSocketClient {
    @Published var messages: [Message] = []
    func onMessage(_ data: Data) { ... }
}

let chat = useWebSocket(URL("/ws/chat"), reconnect: .exponential)
chat.send(.text("hi"))

let events = useEventSource("/sse/notifications")
for await event in events { ... }
```

**Approach.** Wrap `JSObject.global.WebSocket`/`EventSource` with `AsyncStream`. Auto-reconnect with backoff, presence/heartbeat, optional msgpack serialization. Hook into router for per-route lifecycle (close on leave). Server side: Vapor already supports both — provide `WebSocketController` protocol on backend mirroring client.

**Effort.** S.

---

## 17. Optimistic updates

**Why.** Mutations should feel instant. Without primitive, users hand-roll fragile rollback.

```swift
@Optimistic var todos: [Todo]

Button("Toggle") {
    $todos.optimistic { list in list[id].done.toggle() } commit: {
        try await api.toggle(id)
    } onError: { err, prev in toaster.show(.error(err)) }
}
```

**Approach.** `@Optimistic` wraps `@State`, snapshots prior value, applies mutation, kicks server task. On failure restore. On success, server response replaces optimistic value (reconciliation via id). Pairs with #2 cache: mutations invalidate keys.

**Effort.** S.

---

## 18. Error boundaries

**Why.** One throw should not blank the app.

```swift
ErrorBoundary { CrashyView() } fallback: { err, retry in
    VStack { Text(err.localizedDescription); Button("Retry", action: retry) }
} onError: { err, info in Logger.report(err, context: info) }
```

**Approach.** Tag wrapper that wraps body resolution in `do { try ... } catch`. `body` of children rendered through a try-aware path; throws bubble to nearest boundary. Pair with `Result`-typed `AsyncResource`. Top-level boundary in `Application.mount` catches render errors so dev overlay (#19) can show them.

**Effort.** S.

---

## 19. Browser dev experience

**Why.** Fast feedback is what makes Vite/RSC pleasant. Worktree has FileWatcher + WS — finish the loop.

**Add.**
- **Error overlay.** On `{type:"error"}` from dev WS (already broadcast), inject full-screen iframe with stack trace, file/line, code frame. Click line opens editor via `vscode://file/...` URI. Render Swift compile errors verbatim.
- **Source maps Swift→WASM.** Build with `--debug-info-format dwarf` + `wasm-sourcemap` postprocess; serve `.wasm.map`. Devtools shows Swift in the call stack.
- **Hot reload UX.** Currently full reload. Add module-level state preservation: snapshot `StateStorage` to `sessionStorage`, restore after reload. True HMR (patch without reload) is later.
- **Component inspector.** `data-swui-loc="File.swift:42"` attribute in dev; click in inspector opens source.
- **Network panel.** Dev-only middleware logs WASM-originated `fetch` calls with timing.

**Effort.** M.

---

## 20. MVP feature set (table-stakes)

To ship a startup MVP on SwiftWUI you need, beyond the above:

- **Auth.** OAuth2 PKCE flow (provider-agnostic), JWT storage in `httpOnly` cookies (preferred) or `AppStorage`, refresh-token rotation, route guards (#4), `@Environment(\.user)`.

  ```swift
  AuthProvider(.oauth(.google(clientID: "..."))) { ContentView() }
  if let user = useAuth().user { ... } else { LoginButton() }
  ```

- **Payments scaffold.** Stripe Elements wrapper (iframe-isolated, PCI-safe), `PaymentSheet { ... }`, server-side intents via Vapor controller. Swift `StripeKit` already exists for backend.

- **DB integration via Vapor.** Generated client from Fluent models: `@Resource(User.self)` exposes `useResource(.users.byId(id))`. Optimistic mutations (#17). Realtime subscriptions over WS (#16).

- **File uploads.** `FileUpload` component with progress, resumable (tus.io), dropzone (#9), client-side image resize before upload (Web Worker, #14). Server: Vapor `req.fileio` chunked streaming.

- **Email.** Transactional via backend (Vapor + SMTP/Resend). Nothing client-side except verification flow UI.

- **Analytics.** `Analytics.track("event", props: [...])` env value with pluggable backend (PostHog/Plausible). Auto page views via router.

- **Logging/observability.** Browser → `/api/logs` endpoint, structured JSON, sampled. Hook into ErrorBoundary (#18).

- **SEO.** `Page` already has `PageHead`; add OG tags helper, sitemap generation in `ProductionBuilder`, `robots.txt`.

**MVP delivery order (suggest).** 11 (theme) → 7 (form inputs) → 1 (form state) → 2 (async) → 4 (routing) → 18 (errors) → 13 (overlays) → 12 (a11y) → 19 (dev UX) → auth → 20-rest. With theme + form inputs + auth + async + routing + error + overlays you can ship a real product. Everything else is a competitive moat, not a blocker.

---

## Effort summary

| # | Feature | Effort |
|---|---------|--------|
| 1 | Forms + validation | L |
| 2 | Async/Suspense | M |
| 3 | Streaming SSR + hydration | L |
| 4 | Routing (nested/loaders) | L |
| 5 | Animations/Gestures | L |
| 6 | Image handling | M |
| 7 | Typed inputs | M |
| 8 | Virtualization | M |
| 9 | Drag-and-drop | M |
| 10 | i18n (plurals/ICU/RTL) | M |
| 11 | Theming | S |
| 12 | Accessibility | M |
| 13 | Overlays (toast/modal) | M |
| 14 | Web Workers | L |
| 15 | PWA/Service Worker | M |
| 16 | WS/SSE | S |
| 17 | Optimistic updates | S |
| 18 | Error boundaries | S |
| 19 | Dev UX | M |
| 20 | MVP suite | L (sum) |

Ship the S/M tier first — biggest UX deltas per week of work.
