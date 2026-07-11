# Phase 8: Browser APIs & Localization — Design

**Date:** 2026-07-11
**Status:** Approved design (brainstorm complete)
**Decomposition:** one shared design, **three implementation cycles**, executed in order:

| Cycle | Scope | Depends on |
|-------|-------|-----------|
| **8a** | Reactive environment source, `@AppStorage`/`@SceneStorage`, `colorScheme`, `isOnline`, `WebFetch`, file select | — |
| **8b** | Permission model, `LocationManager`, local notifications, full Web Push, clipboard, share, navigator info | 8a (signals, capabilities seam) |
| **8c** | Localization: type-safe codegen, `LocalizedText`, interactive locale switch, per-locale SSG | 8a (locale signal) |

Each cycle gets its own implementation plan (writing-plans) and its own review gate. This document is the spec for all three.

## Context

- Browser-API survey 2026-07-11 (5-agent workflow) produced the P0/P1/P2 catalog. The user pulled the permission wave (originally P2) and localization (new) into this phase.
- v2 currently touches only history/location/title/meta/links via `RendererBackend`. No storage, navigator, fetch, clipboard, matchMedia, or file handling exists.
- v1 (`SwiftWUIBrowser` on `master`) is mistake-reference only: per-instance `@AppStorage` caches diverged, observer `JSClosure`s leaked (keyed by `ObjectIdentifier(JSObject)`), clipboard force-unwrap crashed on `http://`.
- **Already done:** `JavaScriptEventLoop.installGlobalExecutor()` is called first thing in `DOMRuntime.mount` (`Sources/SwiftWUIDOM/DOMRuntime.swift:94`). 8a ships only a regression test/canary, no new wiring.

### Verified integration points (main @ fd0c837)

- Environment: passive snapshot. `EnvironmentValues` = `[ObjectIdentifier: Any]`; `_EnvironmentProperty._inject` runs in the Mirror pass of `StateStore.link` before body eval (`StateStore.swift:71-72`). Env changes do **not** trigger re-render today.
- Observation machinery: `withObservationTracking` in `Resolver.swift:67-72` tracks `@Observable` reads during body eval; `onChange` → `markDirty(componentID)`. Proven on wasm since phase 2.
- Invalidation: `markDirty(id)` + microtask-coalesced `flush()` (`Runtime.swift:75-136`). No public external-invalidation API — new reactive sources must ride Observation or the `_bindInvalidate` graft.
- Events: `DOMBackend.decodePayload(event:jsEvent:)` (`DOMBackend.swift:60-96`) has no `files` case. Payload structs live in `Sources/SwiftWUI/HTML/EventPayloads.swift`.
- Localization today: none. Only `DocumentSerializer.Input.lang` (static `<html lang>`, default `"en"`) and `<track srclang>` passthrough.

## Design principles (apply to all three cycles)

1. **Capabilities live in core, browser code in SwiftWUIDOM** (survey decision, option b — no third module). Core types compile natively; DOM registers real implementations at mount.
2. **Every browser-derived env value ships all three legs or doesn't merge:** a default (native/SSG), hydration correction, and MockBackend recording/scripting for tests.
3. **Reactivity reuses Observation.** No new invalidation mechanism. Signals and stores are `@Observable`; reads during body eval are tracked by the existing `Resolver` machinery; changes invalidate exactly the reader components.
4. **JSClosures are retained by their owning backend/manager and removed symmetrically** (v1 leak lesson).
5. **Graceful degradation:** on native/SSG and in browsers lacking a feature, APIs report `unsupported` / defaults — nothing traps.

---

# Shared mechanism: reactive environment source (ships in 8a)

The one new mechanism everything else builds on.

## EnvironmentSignals

```swift
@MainActor @Observable
public final class EnvironmentSignals {
    public internal(set) var colorScheme: ColorScheme = .light
    public internal(set) var isOnline: Bool = true
    public internal(set) var locale: Locale = .init(identifier: "en") // consumed in 8c
}
```

- One instance per `Runtime`, created in `Runtime.init`, reference stored in the root environment under an internal key (`_signals`).
- Public env keys are **computed** over the reference, so the read happens lazily during body eval and is tracked by Observation:

```swift
extension EnvironmentValues {
    public var colorScheme: ColorScheme { _signals?.colorScheme ?? .light }
    public var isOnline: Bool { _signals?.isOnline ?? true }
}
```

- Retained per-component env snapshots (`StateStore.retain`) hold the *reference*, not a copy of the value — subtree passes always read fresh, no staleness.
- Setters are internal: only the runtime/backend observation path writes signals.

## Backend surface

New `RendererBackend` requirement:

```swift
func beginEnvironmentObservation(_ signals: EnvironmentSignals)
```

- Called once in `mount()` **before the first render pass**.
- **DOMBackend:** reads initial values synchronously (`matchMedia("(prefers-color-scheme: dark)").matches`, `navigator.onLine`), then attaches listeners (`change` on the MediaQueryList, `online`/`offline` on window). All `JSClosure`s stored in backend properties for the backend's lifetime.
- **MockBackend:** records the call and exposes the signals reference so tests mutate values directly and assert re-renders.
- **AdoptingBackend:** forwards to base.
- **SSG/native:** defaults stand; `StaticSite` never calls into browser APIs.

## Hydration

Initial signal values are read before the first client pass, so the first VDOM is built with real values. If they differ from what SSG assumed (e.g. server rendered light, client prefers dark), the existing adoption diff patches the delta. No special-case code.

## Adding a future signal (checklist, goes in docs)

property on `EnvironmentSignals` → computed `EnvironmentValues` key → DOMBackend listener (retained) → Mock scripting → default documented. Five lines of recipe; this is the extension contract.

---

# Cycle 8a — P0 core

## A1. EnvironmentSignals + colorScheme + isOnline

As specified above. `ColorScheme` is a new core enum (`light`, `dark`).

**colorScheme × themes:** `colorScheme` reports the *system* preference only. Manual dark-mode toggles remain the themes system's job (`setTheme` / `data-theme`). No `.preferredColorScheme` modifier (YAGNI — themes cover the use case).

**Tests:** Mock-driven — flip `signals.colorScheme`, assert only reader components re-resolved (resolve counters), assert non-readers untouched; adoption test with mismatched initial scheme.

## A2. @AppStorage / @SceneStorage

**Store:** `StorageStore` (`@MainActor`, one per `Runtime`). Holds **one shared box per (kind, key)**:

```swift
@Observable final class StorageBox { var raw: String? }   // raw string, decode at read
enum StorageKind { case local, session }
```

- v1 failure fixed by construction: all wrappers for the same key share the box; a write through any instance updates every reader.
- Raw string is the source of truth; each wrapper decodes at read with its own type. Decode failure (type collision, corrupt value) → wrapper's default + one console warning.

**Wrapper:**

```swift
@propertyWrapper public struct AppStorage<Value: StorageConvertible> { ... }
@propertyWrapper public struct SceneStorage<Value: StorageConvertible> { ... }
```

- Conforms to a new seam protocol `_StorageProperty { func _connect(_ store: StorageStore) }`; the Mirror pass in `StateStore.link` injects the store exactly like `_EnvironmentProperty._inject`.
- `wrappedValue get`: decode `box.raw` (Observation-tracked read) or default. `set`: encode → `box.raw = new` → `backend.storageWrite`.
- `projectedValue` → `Binding<Value>` (parity with `@State`).

**Supported types (SwiftUI parity):** `Bool`, `Int`, `Double`, `String`, `URL`, `Data` (base64), `RawRepresentable where RawValue == Int | String`, plus `Optional` of each. Expressed as a `StorageConvertible` protocol with those conformances; not user-extensible in this cycle.

**Backend surface:**

```swift
func storageRead(kind: StorageKind, key: String) -> String?
func storageWrite(kind: StorageKind, key: String, value: String?)   // nil = remove
func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void)
```

- DOMBackend: `localStorage`/`sessionStorage`; `storage` event → callback (fires cross-tab for localStorage only; sessionStorage has no cross-tab by platform design). Storage quota/`SecurityError` (disabled storage) → treated as absent storage: reads return nil, writes no-op with one console warning.
- MockBackend: in-memory dictionaries; test helper simulates an external change to exercise the cross-tab path.
- Store hydrates a box lazily on first `_connect` for its key via `storageRead`.

**Namespacing:** keys are used verbatim (SwiftUI parity, interop with existing data). Framework-internal keys use the `__swiftwui.` prefix (already reserved convention).

**SSG/native:** MockBackend-style in-memory storage; values live for the process. `.task(policy:)` interplay unchanged.

## A3. WebFetch (URLSession-shape)

No FoundationNetworking on wasm → own mirror types in core:

```swift
public struct WebRequest {
    public var url: String            // absolute or relative; validated at send
    public var method: HTTPMethod     // get/post/put/patch/delete/head
    public var headers: [String: String]
    public var body: Data?
    public var timeout: Duration?
}
public struct WebResponse {
    public let status: Int
    public let headers: [String: String]
    public var isSuccess: Bool        // 200..<300
}
public final class WebSession {      // @MainActor
    public static let shared: WebSession
    public func data(for request: WebRequest) async throws -> (Data, WebResponse)
    public func data(from url: String) async throws -> (Data, WebResponse)
    // Codable sugar:
    public func json<T: Decodable>(from url: String, as: T.Type = T.self) async throws -> T
    public func send<B: Encodable, T: Decodable>(_ method: HTTPMethod, _ url: String, json body: B) async throws -> T
}
```

- **Transport is injected** (`protocol FetchTransport`): wasm = `fetch()` via JavaScriptKit (`JSPromise` await, `Uint8Array` ↔ `Data`); native = URLSession (FoundationNetworking) so SSG build-time `.task(policy: .build)` fetches work; tests = scripted mock transport.
- **Cancellation:** Task cancellation → `AbortController.abort()` (wasm) / `URLSessionTask.cancel()` (native) → `WebFetchError.cancelled`.
- **Errors:** `WebFetchError { badURL, network(String), cancelled, timeout, decoding(Error), httpStatus(Int, Data) }`. Non-2xx is **not** an error from `data(for:)`/`data(from:)` (URLSession parity). Only the Codable sugar helpers throw `httpStatus` on non-2xx (a typed body is expected there) and `decoding` on parse failure.
- **Explicit non-goals:** no middleware/interceptors, no retry, no streaming bodies, no upload progress, no cookies API (browser handles cookies natively for fetch).

## A4. File select

- New payload in `EventPayloads.swift`:

```swift
public struct FilesEvent { public let files: [WebFile] }
public struct WebFile {
    public let name: String
    public let size: Int
    public let mimeType: String
    public let lastModified: Date
    public func data() async throws -> Data
    public func text() async throws -> String
}
```

- `WebFile` is a core type carrying an injected reader (`_FileReading` existential): DOM reader wraps the JS `File` (retains `JSObject`, reads via `arrayBuffer()`/`text()` promises); Mock reader serves in-memory bytes for native tests.
- `DOMBackend.decodePayload`: `change` event whose target is `input[type=file]` → build `FilesEvent` from `target.files`. Plain `ChangeEvent` handlers on a file input never fire (payload cast fails) — documented behavior.
- Sugar: `.onFileSelection { files in ... }` — registers a `change` handler typed to `FilesEvent`. Works with `multiple` and `accept` attributes (already expressible on `Input`; add typed params if missing).

## A5. EventLoop canary

Regression test asserting `DOMRuntime.mount` installs the global executor before any `Task` use; plus doc note in CLAUDE.md-adjacent docs. No new wiring.

---

# Cycle 8b — permission-gated APIs

## B1. Permission model

```swift
public enum PermissionStatus { case notDetermined, granted, denied, unsupported }
```

- Permissions API mapping: `prompt` → `notDetermined`, `granted` → `granted`, `denied` → `denied`.
- Two distinct kinds of absence: (a) the **query mechanism** is missing but the feature exists (Safari's Permissions API gaps) → `notDetermined` until the feature's own request resolves, then status derived from that result; (b) the **feature itself** is missing (or native/SSG) → `unsupported`. Querying is always safe; requesting on `unsupported` throws the typed error, never traps.

## B2. BrowserCapabilities seam

`protocol BrowserCapabilities` in core: geolocation, notifications, push, clipboard, share primitives as small async methods. Registered by SwiftWUIDOM at mount; native default = `UnsupportedCapabilities` (every status `unsupported`, every request throws); Mock = scriptable per-call results for tests. Managers below take the capabilities handle from the runtime at graft time — components using them compile and test natively.

## B3. LocationManager

```swift
@State private var location = LocationManager()
```

`@MainActor @Observable final class LocationManager`:

- `status: PermissionStatus` (observable)
- `requestLocation() async throws -> GeoLocation` — one-shot `getCurrentPosition`; triggers the permission prompt implicitly (web model: the request *is* the prompt)
- `startUpdating() / stopUpdating()` — `watchPosition`/`clearWatch`; `lastLocation: GeoLocation?` observable, so UI reading it re-renders on every fix
- `GeoLocation`: `latitude`, `longitude`, `accuracy`, `altitude?`, `speed?`, `heading?`, `timestamp`
- Errors: `LocationError { denied, unavailable, timeout, unsupported }`
- Cleanup: `stopUpdating()` clears the watch and releases its `JSClosure`; `deinit` guards against leaks. Requires secure context.

## B4. Local notifications

`@MainActor @Observable final class NotificationManager`:

- `status: PermissionStatus` (observable; seeded from `Notification.permission`)
- `requestAuthorization() async throws -> Bool`
- `show(title:body:icon:tag:onClick:)` — Notification API from the open tab; `onClick` optional closure (retained per shown notification, released on close/click)

## B5. Web Push (full)

Three parts, explicit responsibility boundary:

1. **Service worker (toolchain):** `swiftwui build`/`dev`/`ssg` emit a static `sw.js` at the site root (new reserved name, next to `__swiftwui`). Content is fixed in this phase: `push` event → `self.registration.showNotification(payload)`, `notificationclick` → focus existing client or `openWindow`. Payload contract: JSON `{title, body, icon?, url?}`. No user customization of `sw.js` in this cycle.
2. **Subscription (framework):** `@MainActor @Observable final class PushManager`:
   - `subscription: PushSubscription?` (observable; restored from `pushManager.getSubscription()` at first access)
   - `subscribe(vapidPublicKey: String) async throws -> PushSubscription` — registers `sw.js`, requests notification permission, calls `pushManager.subscribe(userVisibleOnly: true, applicationServerKey:)` (base64url VAPID key decoded to `Uint8Array`)
   - `unsubscribe() async throws`
   - `PushSubscription`: `endpoint: String`, `p256dh: Data`, `auth: Data`, `toJSON() -> String` (standard PushSubscription JSON shape, ready to POST to the app's server via `WebSession`)
3. **Sending (out of framework):** the app's own server pushes via any web-push library. Docs ship a recipe (subscribe → POST subscription → server sends) and state the boundary explicitly.

Requires secure context; `swiftwui dev` on localhost qualifies. Native/SSG: `unsupported`.

## B6. Clipboard, Share, navigator info

- `@Environment(\.clipboard)` → `Clipboard`: `readText() async throws -> String`, `writeText(_:) async throws`. Insecure context → `ClipboardError.secureContextRequired` (v1 crash fixed by typed error, no force-unwrap). Read may prompt (browser-dependent); denial → `denied`.
- `@Environment(\.share)` → `ShareAction`: `callAsFunction(title:text:url:) async throws`; `var canShare: Bool` (false where `navigator.share` absent → callers render fallback UI).
- `@Environment(\.userAgent) -> String` — static env value seeded at mount (not a signal; it never changes).

**Tests:** all managers against scripted `MockCapabilities`: permission state machines, denial paths, watch cleanup, subscription round-trip, insecure-context errors.

---

# Cycle 8c — localization

## C1. Catalogs

`Locales/<lang>.json` per language, flat keys, named placeholders, ICU-style plurals:

```json
{
  "welcome.title": "Привет, {name}!",
  "items.count": "{count, plural, one {# товар} few {# товара} many {# товаров} other {# товара}}"
}
```

- Supported placeholder types: string (default), `{n, plural, ...}` with CLDR cardinal categories (`zero/one/two/few/many/other`), `#` = the number inside plural branches. No `select`/gender, no nested plurals in this cycle.
- Declared locales + default come from app config (same config surface the toolchain already reads; exact key decided in the plan).

## C2. Codegen

`swiftwui l10n generate`, auto-run by `build`/`ssg` and watched by `dev`:

- Emits `Sources/<AppTarget>/Generated/L10n.swift` (committed; regenerated deterministically).
- One `static func` per key on `enum L10n`; placeholder names → labeled parameters (`{name}` → `name: String`, plural variable → `count: Int`); key `welcome.title` → `welcomeTitle` (dots → camelCase; collisions = generation error).
- Embeds **all locales' templates** into the generated Swift (chosen: type-safe codegen; wasm binary carries translations — accepted; lazy per-locale loading is a possible future optimization, design does not block it).
- Emits compact CLDR cardinal-plural rule functions only for declared locales — identical behavior in wasm and native SSG (no `Intl.PluralRules` dependency, no client/prerender divergence).
- **Strictness:** any key missing in any declared locale → generation **error**. `--allow-missing` downgrades to warning + fallback to the default locale's template. Malformed ICU syntax → error with key + locale.

## C3. LocalizedText and rendering

```swift
public struct LocalizedText {
    // key + bound arguments + per-locale template table (generated data)
    public func resolved(for locale: Locale) -> String
}
extension Text { public init(_ localized: LocalizedText) }
```

- `L10n.foo(...)` returns `LocalizedText`, **not** `String` — resolution happens inside `Text` at resolve time against `ctx.environment.locale`.
- The locale read goes through `EnvironmentSignals.locale` → Observation-tracked → locale change re-renders exactly the components that rendered localized text.
- Resolved strings flow through the normal serializer-only `HTMLEscaping` choke point — translations get no special trust.
- Escape hatch for non-Text sinks (attribute values, document titles): `@Environment(\.locale)` + `localized.resolved(for:)` — explicit, still reactive because the env read is tracked.

## C4. Locale switching & detection

```swift
@Environment(\.locale) var locale
@Environment(\.setLocale) var setLocale
Button("RU") { setLocale(Locale(identifier: "ru")) }
```

`setLocale` (env action, runtime-provided):
1. validates against declared locales (unknown → no-op + console warning),
2. writes `signals.locale` (→ reader re-render),
3. persists choice to `localStorage["__swiftwui.locale"]` via `StorageStore`,
4. updates `<html lang>` via new backend method `setDocumentLanguage(_: String)`,
5. under per-locale SSG, `replaceState`s the URL to the same route with the new locale prefix (no reload).

**Initial locale priority (resolved before the first pass):** URL prefix → persisted choice → best match of `navigator.language(s)` against declared locales (exact tag, then primary-subtag) → configured default.

## C5. Per-locale SSG & routing

Config: `locales: ["en", "ru"]`, `defaultLocale: "en"`. When absent, everything below is inert — non-localized apps pay nothing.

- `swiftwui ssg` renders the full page set once per locale: default locale at the site root (`/about/`), others under a prefix (`/ru/about/`).
- Each rendered document gets its locale's `<html lang>` and automatic `<link rel="alternate" hreflang="…">` entries for every variant (+ `x-default` → default locale), emitted through the existing links pipeline.
- Router: locale prefix is stripped before route matching; `navigate`/`Link` preserve the current prefix; `RouteInfo` unchanged.
- Hydration: boot parses the prefix, seeds `signals.locale`, adoption proceeds with zero locale mismatch.

**Tests:** codegen golden tests (JSON → Swift, plural rules incl. Russian one/few/many, strictness errors); runtime switch test (Mock: flip locale, assert re-render + persistence + `setDocumentLanguage`); SSG test (two locales → two trees, lang + hreflang correct); router prefix round-trip; initial-locale priority matrix.

---

# Cross-cutting

## Testing strategy

Native `swift test` is the primary gate for all three cycles (MockBackend + MockCapabilities + mock transport + in-memory storage). Wasm target must stay green per cycle. Browser acceptance per cycle is manual (as in phases 2–7), with a checklist item list in each plan: real matchMedia flip, real cross-tab storage event, real geolocation prompt, real push round-trip (against a scratch VAPID key), real language switch on a two-locale example.

## Documentation & examples

Each cycle updates the Tutorial site or an example app with a minimal demo (8a: theme-aware + persisted counter + fetch list + file preview; 8b: permissions playground page; 8c: the Tutorial itself gains a second language — dogfood).

## Out of scope (recorded, not designed)

Drag & drop, WebSocket, IntersectionObserver `.onVisible`, downloads, `@FocusState`, cookies helper, `scenePhase`/`reducedMotion`/viewport signals (mechanism ready, keys not shipped), custom service-worker logic, push sending server, ICU `select`, lazy locale loading. Raw JavaScriptKit remains the documented escape hatch.

## Risks

- **Web Push is the heaviest 8b item** — SW file in three toolchain commands, secure-context constraints, browser matrix (Safari push quirks). Plan should sequence it last within 8b so the wave can ship a partial review if it stalls.
- **Observation-over-env is load-bearing** — 8a must land a stress test (many readers, rapid signal flips, coalescing) before 8b/8c build on it.
- **Codegen determinism** — generated file is committed; CI should verify `l10n generate` is a no-op on a clean tree.
