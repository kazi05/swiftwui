# Phase 8a: Browser APIs Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reactive environment source (`EnvironmentSignals`), `@AppStorage`/`@SceneStorage`, `colorScheme`/`isOnline` env values, `WebFetch` (URLSession-shape over fetch), and file-select payloads — per approved spec `docs/superpowers/specs/2026-07-11-phase8-browser-apis-l10n-design.md` (cycle 8a).

**Architecture:** One new mechanism: `@Observable EnvironmentSignals` owned by `Runtime`, reference seeded into the root environment; computed `EnvironmentValues` keys read it lazily during body eval, so the existing `withObservationTracking` in `Resolver.swift:67` invalidates exactly the reader components. Storage rides the same idea with `@Observable` per-key boxes in a `StorageStore`. Backends deliver browser events through closures (`EnvironmentSignals.Writer`, storage-observation callback) — signal setters never leave core. WebFetch is transport-injected (`FetchTransport`): DOM = `fetch()`, SSG = URLSession, tests = mock.

**Tech Stack:** Swift 6.3.3, swift-testing (`@Suite`/`@Test`/`#expect`), Observation framework, JavaScriptKit 0.22 (+ `JavaScriptFoundationCompat` product, same package), wasm SDK `swift-6.3.3-RELEASE_wasm`.

## Global Constraints

- Toolchain: Swift **6.3.3** (swiftly) + wasm SDK `swift-6.3.3-RELEASE_wasm` — versions must match exactly.
- Native gate: `swift test` (346 tests green before this plan; every task adds to that). Wasm gate (tasks touching SwiftWUIDOM): `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM`.
- Core module (`Sources/SwiftWUI`) imports Foundation ONLY via `#if canImport(FoundationEssentials) import FoundationEssentials #else import Foundation #endif` — never the bare umbrella (57 MB wasm vs 16 MB). `Duration` is stdlib, no import.
- No new package dependencies. `JavaScriptFoundationCompat` is a new *product* of the already-pinned JavaScriptKit package — allowed (spec 8a).
- Everything `@MainActor` (module `defaultIsolation(MainActor.self)`); no `Sendable` in the pipeline.
- Every browser-derived env value ships three legs: default (native/SSG), hydration correction, MockBackend recording/scripting — or doesn't merge.
- Reactivity read-site constraint (spec, shared mechanism): Observation tracks ONLY reads inside the user component's `body`. Never wire a new consumer that reads signals in primitive `_resolve`/handlers and expects auto re-render.
- All `JSClosure`s retained by their owning backend/manager for its lifetime; `#if arch(wasm32)` for runtime forks, never `canImport(JavaScriptKit)`.
- Testing workflow (user preference): per task — write ALL test + implementation code first, ONE `swift test` run at the end, then commit. No step-by-step RED/GREEN.
- Code, commits, docs in English.

## File Structure

| File | Responsibility |
|---|---|
| `Sources/SwiftWUI/Environment/EnvironmentSignals.swift` (new) | `ColorScheme`, `EnvironmentSignals` + `Writer`, `_signals`/`colorScheme`/`isOnline` env keys |
| `Sources/SwiftWUI/State/Storage.swift` (new) | `StorageKind`, `StorageConvertible` + conformances, `StorageStore`, `@AppStorage`, `@SceneStorage`, `_storageStore` env key |
| `Sources/SwiftWUI/Fetch/WebFetch.swift` (new) | `HTTPMethod`, `WebRequest`, `WebResponse`, `WebFetchError`, `FetchTransport`, `WebSession`, `webSession` env key |
| `Sources/SwiftWUI/HTML/WebFile.swift` (new) | `_FileReading`, `WebFile`, `FilesEvent`, `Input.onFileSelection` |
| `Sources/SwiftWUI/Render/RendererBackend.swift` | +4 protocol methods with no-op protocol-extension defaults |
| `Sources/SwiftWUI/Render/MockBackend.swift` | recording/scripting impls for all new methods |
| `Sources/SwiftWUI/Render/AdoptingBackend.swift` | forwards for all new methods |
| `Sources/SwiftWUI/Runtime/Runtime.swift` | owns signals + storage store + `_webSession`; mount wiring; renderPass env seeding |
| `Sources/SwiftWUI/HTML/Tags.swift` | `Input` gains `accept`/`multiple` params |
| `Sources/SwiftWUIDOM/DOMBackend.swift` | env observation (matchMedia/online), storage read/write/event, `change`-on-file-input decode |
| `Sources/SwiftWUIDOM/JSInterop.swift` (new) | ArrayBuffer↔Data helper shared by fetch transport and file reader |
| `Sources/SwiftWUIDOM/FetchJSTransport.swift` (new) | fetch() transport (same-origin credentials, abort, timeout) |
| `Sources/SwiftWUIDOM/DOMFileReader.swift` (new) | JS `File` reader (arrayBuffer/text promises) |
| `Sources/SwiftWUIDOM/DOMRuntime.swift` | inject `WebSession(FetchJSTransport())` in `makeRuntime` |
| `Sources/SwiftWUIStatic/URLSessionTransport.swift` (new) | build-time fetch transport (ephemeral, no cookies) |
| `Package.swift` | SwiftWUIDOM += `JavaScriptFoundationCompat` |
| Tests | `EnvironmentSignalsTests.swift`, `StorageTests.swift`, `WebFetchTests.swift`, `FileSelectTests.swift`, `SignalsStressTests.swift` (new) |

Existing anchors (verified at main `8a59cb9`): `Resolver.swift:67-72` tracking window; `StateStore.link` Mirror pass `StateStore.swift:71-72` (`_EnvironmentProperty._inject`); `Runtime.renderPass` env seeding `Runtime.swift:226-231`; `Runtime.mount` `Runtime.swift:84-89`; `DOMBackend.decodePayload` `DOMBackend.swift:60-96`; `DOMRuntime.mount` executor install `DOMRuntime.swift:94`; test scaffolding pattern `Tests/SwiftWUITests/StateStoreTests.swift` / `AdoptionTests.swift` (`sched.schedule`).

---

### Task 1: EnvironmentSignals + colorScheme/isOnline (core)

**Files:**
- Create: `Sources/SwiftWUI/Environment/EnvironmentSignals.swift`
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (append to protocol + new extension)
- Modify: `Sources/SwiftWUI/Render/AdoptingBackend.swift` (forward)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (record writer)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (own signals, mount hook, renderPass seed)
- Test: `Tests/SwiftWUITests/EnvironmentSignalsTests.swift`

**Interfaces:**
- Consumes: `EnvironmentKey`/`EnvironmentValues` (`Environment.swift`), `withObservationTracking` (already in Resolver — no Resolver changes).
- Produces: `enum ColorScheme { case light, dark }`; `final class EnvironmentSignals` with `colorScheme: ColorScheme`, `isOnline: Bool` (public read, core-internal `_setColorScheme(_:)`/`_setOnline(_:)`), `struct Writer { let setColorScheme: (ColorScheme) -> Void; let setOnline: (Bool) -> Void }`, internal `var writer: Writer`; `EnvironmentValues.colorScheme`/`.isOnline` (public computed), internal `._signals`; `RendererBackend.beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer)` (no-op default); `Runtime._signals: EnvironmentSignals` (SPI); `MockBackend.environmentWriter: EnvironmentSignals.Writer?`.

- [ ] **Step 1: Write the new file**

`Sources/SwiftWUI/Environment/EnvironmentSignals.swift`:

```swift
import Observation

/// System color scheme as reported by `prefers-color-scheme`. Manual dark-mode
/// toggles remain the themes system's job (`setTheme`) — this is the signal only.
public enum ColorScheme: String, Equatable, Sendable {
    case light, dark
}

/// Browser-derived reactive environment values (phase-8 spec, shared mechanism).
/// One instance per Runtime; env keys are computed over this REFERENCE, so the
/// read happens lazily during body eval and is Observation-tracked — a write
/// invalidates exactly the reader components via the same path as @Observable
/// models. Read-site constraint: reads outside the component `body` (primitive
/// _resolve, event handlers, .task closures) are NOT tracked.
@MainActor @Observable
public final class EnvironmentSignals {
    public private(set) var colorScheme: ColorScheme = .light
    public private(set) var isOnline: Bool = true
    public init() {}

    func _setColorScheme(_ v: ColorScheme) { colorScheme = v }
    func _setOnline(_ v: Bool) { isOnline = v }

    /// Cross-module write surface: setters stay core-private; backends receive
    /// closures via `RendererBackend.beginEnvironmentObservation`.
    public struct Writer {
        public let setColorScheme: (ColorScheme) -> Void
        public let setOnline: (Bool) -> Void
    }
    var writer: Writer {
        Writer(setColorScheme: { [weak self] in self?._setColorScheme($0) },
               setOnline: { [weak self] in self?._setOnline($0) })
    }
}

struct _SignalsKey: EnvironmentKey {
    static let defaultValue: EnvironmentSignals? = nil
}

extension EnvironmentValues {
    var _signals: EnvironmentSignals? {
        get { self[_SignalsKey.self] }
        set { self[_SignalsKey.self] = newValue }
    }
    /// System color-scheme preference. `.light` outside a live runtime (native/SSG).
    public var colorScheme: ColorScheme { _signals?.colorScheme ?? .light }
    /// `navigator.onLine`. `true` outside a live runtime.
    public var isOnline: Bool { _signals?.isOnline ?? true }
}
```

Note: if the `@Observable` macro rejects `public private(set)` on this toolchain, fall back to `internal` computed public accessors — do NOT make the setters public.

- [ ] **Step 2: Backend protocol + conformers**

`RendererBackend.swift` — append inside the protocol (after the hydration section):

```swift
    // MARK: Environment signals (phase 8a)
    /// Called once by Runtime.mount() BEFORE the first render pass. Backends
    /// read initial values synchronously, then attach change listeners. Every
    /// listener closure must be retained by the backend for its lifetime.
    func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer)
```

Same file, after the protocol — no-op default so SSG serializer and other passive conformers stay untouched:

```swift
extension RendererBackend {
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {}
}
```

`AdoptingBackend.swift` — add a forward next to the existing forwarded methods (match the file's existing forwarding style; the wrapped backend property is used by every other forward — reuse its name):

```swift
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {
        base.beginEnvironmentObservation(writer)
    }
```

`MockBackend.swift` — add:

```swift
    public private(set) var environmentWriter: EnvironmentSignals.Writer?
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {
        bump("beginEnvironmentObservation")
        environmentWriter = writer
    }
```

- [ ] **Step 3: Runtime ownership + seeding**

`Runtime.swift` — add stored property next to `store` (line ~6):

```swift
    private let signals = EnvironmentSignals()
```

SPI accessor next to `_store` (line ~27):

```swift
    public var _signals: EnvironmentSignals { signals }   // SPI: backend wiring + tests
```

`mount()` (line 84) — first line, before style registration:

```swift
    public func mount() {
        applier.backend.beginEnvironmentObservation(signals.writer)
        for face in fontFaces { styleRegistry.registerRaw(face.ruleText) }
        ...
```

`renderPass()` — after `ctx.environment.setTheme = ...` (line 226):

```swift
        ctx.environment._signals = signals
```

(`_collectRoutes` keeps its fresh context — collect-pass bodies see defaults; output discarded. `subtreePass` replays `row.environment`, which holds the signals *reference* → always fresh.)

- [ ] **Step 4: Tests**

`Tests/SwiftWUITests/EnvironmentSignalsTests.swift`. Reuse the existing manual-scheduler helper if one exists in the test target (`grep -rn "func schedule" Tests/SwiftWUITests/ | head`); otherwise define locally:

```swift
import Testing
@testable import SwiftWUI

@MainActor
private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

@MainActor private final class RenderCounter { var n = 0 }

private struct SchemeReader: Tag {
    let counter: RenderCounter
    @Environment(\.colorScheme) var scheme
    var body: some Tag {
        counter.n += 1
        return Div { Text(scheme == .dark ? "dark" : "light") }
    }
}

private struct Bystander: Tag {
    let counter: RenderCounter
    @State var n = 0
    var body: some Tag {
        counter.n += 1
        return Text("bystander")
    }
}

private struct SignalsRoot: Tag {
    let reader: RenderCounter
    let bystander: RenderCounter
    var body: some Tag {
        Div {
            SchemeReader(counter: reader)
            Bystander(counter: bystander)
        }
    }
}

@Suite @MainActor struct EnvironmentSignalsTests {

    private func makeRuntime(reader: RenderCounter, bystander: RenderCounter)
        -> (Runtime<MockBackend>, MockBackend, Sched) {
        let backend = MockBackend()
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SignalsRoot(reader: reader, bystander: bystander),
                              scheduleMicrotask: sched.schedule)
        runtime.mount()
        sched.drain()
        return (runtime, backend, sched)
    }

    @Test func defaultsOutsideRuntime() {
        #expect(EnvironmentValues().colorScheme == .light)
        #expect(EnvironmentValues().isOnline == true)
    }

    @Test func mountHandsWriterToBackend() {
        let (_, backend, _) = makeRuntime(reader: RenderCounter(), bystander: RenderCounter())
        #expect(backend.environmentWriter != nil)
        #expect(backend.counts["beginEnvironmentObservation"] == 1)
    }

    @Test func colorSchemeFlipRerendersOnlyReaders() {
        let reader = RenderCounter(); let bystander = RenderCounter()
        let (_, backend, sched) = makeRuntime(reader: reader, bystander: bystander)
        #expect(backend.serializeHTML().contains("light"))
        #expect(reader.n == 1); #expect(bystander.n == 1)

        backend.environmentWriter!.setColorScheme(.dark)
        sched.drain()
        #expect(backend.serializeHTML().contains("dark"))
        #expect(reader.n == 2)
        #expect(bystander.n == 1)   // non-reader untouched — precision claim of the spec
    }

    @Test func initialValueSeededBeforeFirstPass() {
        // Backend sets values inside beginEnvironmentObservation → first VDOM
        // already reflects them (hydration-correction leg). Simulate with a
        // backend subclass? No — MockBackend records; drive via a pre-mount writer:
        let backend = MockBackend()
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: SignalsRoot(reader: RenderCounter(), bystander: RenderCounter()),
                              scheduleMicrotask: sched.schedule)
        // beginEnvironmentObservation runs first inside mount(); DOMBackend
        // writes initial values there. Emulate by setting through the runtime's
        // signals BEFORE renderPass — mount() order guarantees this window:
        runtime._signals._setColorScheme(.dark)
        runtime.mount()
        sched.drain()
        #expect(backend.serializeHTML().contains("dark"))
    }

    @Test func isOnlineFlip() {
        struct OnlineReader: Tag {
            @Environment(\.isOnline) var online
            var body: some Tag { Text(online ? "on" : "off") }
        }
        let backend = MockBackend(); let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: OnlineReader(), scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        #expect(backend.serializeHTML().contains("on"))
        backend.environmentWriter!.setOnline(false)
        sched.drain()
        #expect(backend.serializeHTML().contains("off"))
        _ = runtime   // keep alive
    }

    @Test func adoptingBackendForwards() {
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting.beginEnvironmentObservation(EnvironmentSignals().writer)
        #expect(base.environmentWriter != nil)
    }
}
```

Note for the implementer: `runtime._signals._setColorScheme` is core-internal — the test target uses `@testable import SwiftWUI`, so it's reachable. If `AdoptingBackend`'s initializer signature differs (`grep -n "init" Sources/SwiftWUI/Render/AdoptingBackend.swift`), match it.

- [ ] **Step 5: Run the full native suite once**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass (previous count + 6 new).

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI Tests/SwiftWUITests/EnvironmentSignalsTests.swift
git commit -m "feat(env): reactive EnvironmentSignals — colorScheme/isOnline via Observation"
```

---

### Task 2: DOMBackend environment observation (wasm)

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift`

**Interfaces:**
- Consumes: `EnvironmentSignals.Writer` (Task 1), `beginEnvironmentObservation` protocol slot.
- Produces: live matchMedia/online observation on wasm. No new API.

- [ ] **Step 1: Implement observation in DOMBackend**

Add stored properties next to `closures` (line ~13):

```swift
    private var envClosures: [JSClosure] = []      // retained for backend lifetime (v1 leak lesson)
    private var colorSchemeQuery: JSObject?        // keep the MediaQueryList alive with its listener
```

Add the method (near `setLinks`):

```swift
    public func beginEnvironmentObservation(_ writer: EnvironmentSignals.Writer) {
        let window = JSObject.global.window.object
        // prefers-color-scheme: initial read BEFORE the first render pass, then change listener.
        if let mql = window?.matchMedia?("(prefers-color-scheme: dark)").object {
            writer.setColorScheme(mql.matches.boolean == true ? .dark : .light)
            let onSchemeChange = JSClosure { args in
                let matches = args.first?.object?.matches.boolean == true
                writer.setColorScheme(matches ? .dark : .light)
                return .undefined
            }
            _ = mql.addEventListener?("change", onSchemeChange)
            envClosures.append(onSchemeChange)
            colorSchemeQuery = mql
        }
        // navigator.onLine + online/offline events.
        if let nav = JSObject.global.navigator.object {
            writer.setOnline(nav.onLine.boolean ?? true)
        }
        let onOnline = JSClosure { _ in writer.setOnline(true); return .undefined }
        let onOffline = JSClosure { _ in writer.setOnline(false); return .undefined }
        _ = window?.addEventListener?("online", onOnline)
        _ = window?.addEventListener?("offline", onOffline)
        envClosures.append(onOnline)
        envClosures.append(onOffline)
    }
```

No `DOMRuntime.swift` changes: `Runtime.mount()` calls this on whatever backend it has — the `AdoptingBackend` forward (Task 1) reaches the raw `DOMBackend` on the hydration path too, so initial values are seeded before the first pass and the adoption diff corrects any SSG mismatch (light-vs-dark) with zero special-case code.

- [ ] **Step 2: Native suite + wasm gate**

Run: `swift test 2>&1 | tail -3` — expected: unchanged pass count (file is `#if arch(wasm32)`).
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM 2>&1 | tail -3` — expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/SwiftWUIDOM/DOMBackend.swift
git commit -m "feat(dom): matchMedia + online/offline environment observation"
```

---

### Task 3: StorageStore + @AppStorage/@SceneStorage (core)

**Files:**
- Create: `Sources/SwiftWUI/State/Storage.swift`
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (+3 methods + defaults)
- Modify: `Sources/SwiftWUI/Render/AdoptingBackend.swift` (forwards)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (in-memory storage + external-change helper)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (own store, mount wiring, renderPass seed)
- Test: `Tests/SwiftWUITests/StorageTests.swift`

**Interfaces:**
- Consumes: `_EnvironmentProperty._inject` graft (StateStore.swift:72 — NO StateStore changes), `EnvironmentKey`, `Binding`, Task-1 test scaffolding.
- Produces: `enum StorageKind { case local, session }`; `protocol StorageConvertible { static func _decodeStorage(_ raw: String) -> Self?; var _encodeStorage: String? { get } }` (nil encode = remove key) with conformances `Bool/Int/Double/String/URL/Data/Optional` + `RawRepresentable` default impls (enums opt in: `extension MyEnum: StorageConvertible {}`); `final class StorageStore` with `box(kind:key:) -> Box` (`Box.raw: String?` @Observable), `write(kind:key:raw:)`, `externalChange(kind:key:raw:)`, wiring vars `readBacking`/`writeBacking`; `@AppStorage<Value: StorageConvertible>`/`@SceneStorage<Value: StorageConvertible>` (both `_EnvironmentProperty`, `projectedValue: Binding<Value>`); backend methods `storageRead(kind:key:) -> String?`, `storageWrite(kind:key:value:)`, `beginStorageObservation(onExternalChange:)`; `Runtime._storage: StorageStore`; `MockBackend.localStorage`/`.sessionStorage: [String: String]`, `.simulateExternalStorageChange(kind:key:value:)`.

- [ ] **Step 1: Write `Sources/SwiftWUI/State/Storage.swift`**

```swift
import Observation
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - Kind & conversion

public enum StorageKind: Hashable, Sendable { case local, session }

/// Raw-string codec for web storage. Encode returning nil = remove the key
/// (Optional.none). SECURITY: web storage is plaintext, origin-scoped, and
/// readable by any script on the origin — never store secrets or tokens.
public protocol StorageConvertible {
    static func _decodeStorage(_ raw: String) -> Self?
    var _encodeStorage: String? { get }
}

extension String: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> String? { raw }
    public var _encodeStorage: String? { self }
}
extension Bool: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Bool? {
        raw == "true" ? true : raw == "false" ? false : nil
    }
    public var _encodeStorage: String? { self ? "true" : "false" }
}
extension Int: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Int? { Int(raw) }
    public var _encodeStorage: String? { String(self) }
}
extension Double: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Double? { Double(raw) }
    public var _encodeStorage: String? { String(self) }
}
extension URL: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> URL? { URL(string: raw) }
    public var _encodeStorage: String? { absoluteString }
}
extension Data: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Data? { Data(base64Encoded: raw) }
    public var _encodeStorage: String? { base64EncodedString() }
}
extension Optional: StorageConvertible where Wrapped: StorageConvertible {
    public static func _decodeStorage(_ raw: String) -> Wrapped?? {
        Wrapped._decodeStorage(raw).map { Optional($0) }   // inner decode failure → nil → wrapper default
    }
    public var _encodeStorage: String? { self?._encodeStorage }
}
/// RawRepresentable enums opt in with `extension MyEnum: StorageConvertible {}` —
/// Swift cannot conform them retroactively; these supply the implementations.
public extension StorageConvertible where Self: RawRepresentable, RawValue == String {
    static func _decodeStorage(_ raw: String) -> Self? { Self(rawValue: raw) }
    var _encodeStorage: String? { rawValue }
}
public extension StorageConvertible where Self: RawRepresentable, RawValue == Int {
    static func _decodeStorage(_ raw: String) -> Self? { Int(raw).flatMap(Self.init(rawValue:)) }
    var _encodeStorage: String? { String(rawValue) }
}

// MARK: - Store

/// ONE shared @Observable box per (kind, key) — every wrapper for the same key
/// shares it, so a write through any instance re-renders every reader (v1's
/// per-instance-cache divergence is impossible by construction). Raw string is
/// the source of truth; each wrapper decodes at read with its own type.
@MainActor
public final class StorageStore {
    @Observable
    public final class Box {
        public internal(set) var raw: String?
        init(_ raw: String?) { self.raw = raw }
    }
    private struct SlotKey: Hashable { let kind: StorageKind; let key: String }
    private var boxes: [SlotKey: Box] = [:]
    private var warnedKeys: Set<String> = []
    /// Wired by Runtime.mount() to the backend BEFORE the first render pass.
    var readBacking: (StorageKind, String) -> String? = { _, _ in nil }
    var writeBacking: (StorageKind, String, String?) -> Void = { _, _, _ in }
    public init() {}

    func box(kind: StorageKind, key: String) -> Box {
        let sk = SlotKey(kind: kind, key: key)
        if let b = boxes[sk] { return b }
        let b = Box(readBacking(kind, key))         // lazy hydrate from the backing store
        boxes[sk] = b
        return b
    }
    func write(kind: StorageKind, key: String, raw: String?) {
        box(kind: kind, key: key).raw = raw         // Observation fires for readers
        writeBacking(kind, key, raw)
    }
    /// storage event (cross-tab) → update the box only; never echo a write back.
    public func externalChange(kind: StorageKind, key: String, raw: String?) {
        boxes[SlotKey(kind: kind, key: key)]?.raw = raw   // nobody linked it yet → nothing to update
    }
    func warnOnce(forKey key: String, _ message: @autoclosure () -> String) {
        guard warnedKeys.insert(key).inserted else { return }
        print("SwiftWUI storage: \(message())")
    }
}

struct _StorageStoreKey: EnvironmentKey {
    static let defaultValue: StorageStore? = nil
}
extension EnvironmentValues {
    var _storageStore: StorageStore? {
        get { self[_StorageStoreKey.self] }
        set { self[_StorageStoreKey.self] = newValue }
    }
}

// MARK: - Wrappers

@MainActor
final class _StorageSlot {
    var store: StorageStore?
    var box: StorageStore.Box?
}

@MainActor
private func _storageRead<Value: StorageConvertible>(
    _ slot: _StorageSlot, key: String, default defaultValue: Value) -> Value {
    guard let raw = slot.box?.raw else { return defaultValue }   // tracked @Observable read
    if let v = Value._decodeStorage(raw) { return v }
    slot.store?.warnOnce(forKey: key,
        "value for '\(key)' failed to decode as \(Value.self) — using the wrapper default")
    return defaultValue
}

/// localStorage-backed persistent value. SwiftUI-parity types; RawRepresentable
/// enums opt in via `extension MyEnum: StorageConvertible {}`. Requires a live
/// runtime (link injects the store); outside one, reads return the default and
/// writes are dropped. Never store secrets (see StorageConvertible doc).
@propertyWrapper
public struct AppStorage<Value: StorageConvertible>: _EnvironmentProperty {
    private let key: String
    private let defaultValue: Value
    private let slot = _StorageSlot()

    public init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        if key.hasPrefix("__swiftwui.") {
            print("SwiftWUI @AppStorage: key '\(key)' uses the reserved __swiftwui. prefix")
        }
    }
    public func _inject(_ values: EnvironmentValues) {
        guard let store = values._storageStore else { return }
        slot.store = store
        slot.box = store.box(kind: .local, key: key)
    }
    public var wrappedValue: Value {
        get { _storageRead(slot, key: key, default: defaultValue) }
        nonmutating set { slot.store?.write(kind: .local, key: key, raw: newValue._encodeStorage) }
    }
    public var projectedValue: Binding<Value> {
        let slot = self.slot; let key = self.key; let def = self.defaultValue
        return Binding(
            get: { _storageRead(slot, key: key, default: def) },
            set: { slot.store?.write(kind: .local, key: key, raw: $0._encodeStorage) })
    }
}

/// sessionStorage-backed per-tab value. Same semantics as @AppStorage minus
/// cross-tab events (sessionStorage has none by platform design).
@propertyWrapper
public struct SceneStorage<Value: StorageConvertible>: _EnvironmentProperty {
    private let key: String
    private let defaultValue: Value
    private let slot = _StorageSlot()

    public init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        if key.hasPrefix("__swiftwui.") {
            print("SwiftWUI @SceneStorage: key '\(key)' uses the reserved __swiftwui. prefix")
        }
    }
    public func _inject(_ values: EnvironmentValues) {
        guard let store = values._storageStore else { return }
        slot.store = store
        slot.box = store.box(kind: .session, key: key)
    }
    public var wrappedValue: Value {
        get { _storageRead(slot, key: key, default: defaultValue) }
        nonmutating set { slot.store?.write(kind: .session, key: key, raw: newValue._encodeStorage) }
    }
    public var projectedValue: Binding<Value> {
        let slot = self.slot; let key = self.key; let def = self.defaultValue
        return Binding(
            get: { _storageRead(slot, key: key, default: def) },
            set: { slot.store?.write(kind: .session, key: key, raw: $0._encodeStorage) })
    }
}
```

- [ ] **Step 2: Backend surface**

`RendererBackend.swift` — append to the protocol:

```swift
    // MARK: Web storage (phase 8a)
    func storageRead(kind: StorageKind, key: String) -> String?
    /// nil value = remove the key.
    func storageWrite(kind: StorageKind, key: String, value: String?)
    /// Cross-document `storage` events (localStorage only by platform design).
    /// The backend retains the callback for its lifetime.
    func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void)
```

Extension defaults (same extension as Task 1's):

```swift
    public func storageRead(kind: StorageKind, key: String) -> String? { nil }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {}
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {}
```

`AdoptingBackend.swift` — forwards:

```swift
    public func storageRead(kind: StorageKind, key: String) -> String? {
        base.storageRead(kind: kind, key: key)
    }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {
        base.storageWrite(kind: kind, key: key, value: value)
    }
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {
        base.beginStorageObservation(onExternalChange: onExternalChange)
    }
```

`MockBackend.swift`:

```swift
    public var localStorage: [String: String] = [:]        // pre-seedable by tests
    public var sessionStorage: [String: String] = [:]
    public private(set) var storageObserver: ((StorageKind, String, String?) -> Void)?
    public func storageRead(kind: StorageKind, key: String) -> String? {
        bump("storageRead")
        return kind == .local ? localStorage[key] : sessionStorage[key]
    }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {
        bump("storageWrite")
        switch kind {
        case .local:   localStorage[key] = value
        case .session: sessionStorage[key] = value
        }
    }
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {
        bump("beginStorageObservation")
        storageObserver = onExternalChange
    }
    /// Test helper: simulate another tab's localStorage write (storage event).
    public func simulateExternalStorageChange(kind: StorageKind, key: String, value: String?) {
        switch kind {
        case .local:   localStorage[key] = value
        case .session: sessionStorage[key] = value
        }
        storageObserver?(kind, key, value)
    }
```

- [ ] **Step 3: Runtime wiring**

`Runtime.swift` — stored property next to `signals`:

```swift
    private let storage = StorageStore()
```

SPI next to `_signals`:

```swift
    public var _storage: StorageStore { storage }
```

`mount()` — after the `beginEnvironmentObservation` line, before style registration:

```swift
        storage.readBacking = { [weak self] kind, key in
            self?.applier.backend.storageRead(kind: kind, key: key)
        }
        storage.writeBacking = { [weak self] kind, key, value in
            self?.applier.backend.storageWrite(kind: kind, key: key, value: value)
        }
        applier.backend.beginStorageObservation { [weak self] kind, key, raw in
            self?.storage.externalChange(kind: kind, key: key, raw: raw)
        }
```

`renderPass()` — after the `_signals` seed:

```swift
        ctx.environment._storageStore = storage
```

- [ ] **Step 4: Tests — `Tests/SwiftWUITests/StorageTests.swift`**

```swift
import Testing
@testable import SwiftWUI

@MainActor
private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

private enum Flavor: String, StorageConvertible { case vanilla, mint }

private struct Counter: Tag {
    @AppStorage("count") var count = 0
    var body: some Tag {
        Div {
            Text("count:\(count)")
            Button("inc") { count += 1 }
        }
    }
}

private struct TwinA: Tag {
    @AppStorage("shared") var v = "a"
    var body: some Tag { Text("A:\(v)") }
}
private struct TwinB: Tag {
    @AppStorage("shared") var v = "b"
    var body: some Tag { Div { Text("B:\(v)"); Button("setB") { v = "written" } } }
}
private struct Twins: Tag { var body: some Tag { Div { TwinA(); TwinB() } } }

@Suite @MainActor struct StorageTests {

    private func mounted<R: Tag>(_ root: R, seed: [String: String] = [:])
        -> (Runtime<MockBackend>, MockBackend, Sched) {
        let backend = MockBackend()
        backend.localStorage = seed
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: root, scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        return (runtime, backend, sched)
    }

    private func clickFirstButton(_ runtime: Runtime<MockBackend>, _ backend: MockBackend,
                                  _ sched: Sched) {
        // Find the first registered click listener and dispatch it (existing
        // pattern: walk MockNode tree for events["click"]).
        func firstClick(_ n: MockNode) -> ListenerID? {
            if let id = n.events["click"] { return id }
            for c in n.children { if let id = firstClick(c) { return id } }
            return nil
        }
        let lid = firstClick(backend.container)!
        runtime.dispatch(lid)
        sched.drain()
    }

    @Test func persistedValueLoadsBeforeFirstRender() {
        let (_, backend, _) = mounted(Counter(), seed: ["count": "5"])
        #expect(backend.serializeHTML().contains("count:5"))
    }

    @Test func writePersistsAndRerenders() {
        let (runtime, backend, sched) = mounted(Counter())
        #expect(backend.serializeHTML().contains("count:0"))
        clickFirstButton(runtime, backend, sched)
        #expect(backend.serializeHTML().contains("count:1"))
        #expect(backend.localStorage["count"] == "1")
    }

    @Test func sameKeySharesOneBoxAcrossComponents() {
        let (runtime, backend, sched) = mounted(Twins())
        // Both render their own defaults until a value exists.
        clickFirstButton(runtime, backend, sched)          // TwinB writes "written"
        let html = backend.serializeHTML()
        #expect(html.contains("A:written"))                // TwinA re-rendered from the SHARED box
        #expect(html.contains("B:written"))
    }

    @Test func externalChangeRerendersReaders() {
        let (_, backend, sched) = mounted(Counter(), seed: ["count": "1"])
        backend.simulateExternalStorageChange(kind: .local, key: "count", value: "42")
        sched.drain()
        #expect(backend.serializeHTML().contains("count:42"))
    }

    @Test func decodeFailureFallsBackToDefault() {
        let (_, backend, _) = mounted(Counter(), seed: ["count": "not-a-number"])
        #expect(backend.serializeHTML().contains("count:0"))   // no crash, wrapper default
    }

    @Test func rawRepresentableOptIn() {
        struct FlavorView: Tag {
            @AppStorage("flavor") var flavor = Flavor.vanilla
            var body: some Tag { Text("f:\(flavor.rawValue)") }
        }
        let (_, backend, _) = mounted(FlavorView(), seed: ["flavor": "mint"])
        #expect(backend.serializeHTML().contains("f:mint"))
    }

    @Test func optionalNilRemovesKey() {
        struct OptView: Tag {
            @AppStorage("opt") var v: String? = nil
            var body: some Tag { Div { Text(v ?? "none"); Button("clear") { v = nil } } }
        }
        let (runtime, backend, sched) = mounted(OptView(), seed: ["opt": "x"])
        #expect(backend.serializeHTML().contains("x"))
        clickFirstButton(runtime, backend, sched)
        #expect(backend.localStorage["opt"] == nil)
        #expect(backend.serializeHTML().contains("none"))
    }

    @Test func sceneStorageUsesSessionNamespace() {
        struct SceneView: Tag {
            @SceneStorage("tab") var tab = "home"
            var body: some Tag { Div { Text("tab:\(tab)"); Button("go") { tab = "settings" } } }
        }
        let (runtime, backend, sched) = mounted(SceneView())
        clickFirstButton(runtime, backend, sched)
        #expect(backend.sessionStorage["tab"] == "settings")
        #expect(backend.localStorage["tab"] == nil)
    }

    @Test func bindingProjection() {
        struct BindView: Tag {
            @AppStorage("text") var text = ""
            var body: some Tag { Input(type: .text, value: $text) }
        }
        let (runtime, backend, sched) = mounted(BindView())
        func firstInputListener(_ n: MockNode) -> ListenerID? {
            if let id = n.events["input"] { return id }
            for c in n.children { if let id = firstInputListener(c) { return id } }
            return nil
        }
        let lid = firstInputListener(backend.container)!
        runtime.dispatch(lid, payload: InputEvent(value: "hello"))
        sched.drain()
        #expect(backend.localStorage["text"] == "hello")
    }
}
```

- [ ] **Step 5: Run the full native suite once**

Run: `swift test 2>&1 | tail -5`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI Tests/SwiftWUITests/StorageTests.swift
git commit -m "feat(state): @AppStorage/@SceneStorage — shared per-key observable boxes"
```

---

### Task 4: DOM storage backend (wasm)

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift`

**Interfaces:**
- Consumes: `StorageKind`, backend protocol slots (Task 3).
- Produces: real localStorage/sessionStorage + `storage`-event observation on wasm.

- [ ] **Step 1: Implement**

Add to `DOMBackend`:

```swift
    private func storageObject(_ kind: StorageKind) -> JSObject? {
        let window = JSObject.global.window.object
        return kind == .local ? window?.localStorage.object : window?.sessionStorage.object
    }
    public func storageRead(kind: StorageKind, key: String) -> String? {
        storageObject(kind)?.getItem?(key).string
    }
    public func storageWrite(kind: StorageKind, key: String, value: String?) {
        guard let s = storageObject(kind) else { return }
        if let value {
            // setItem can throw (QuotaExceededError, disabled storage). Use the
            // throwing call so a full/blocked store degrades to a warning, not a trap.
            if let setItem = s.setItem.function {
                do { _ = try setItem.throws(key, value, this: s) }
                catch { print("SwiftWUI storage: write for '\(key)' failed — \(error)") }
            }
        } else {
            _ = s.removeItem?(key)
        }
    }
    public func beginStorageObservation(onExternalChange: @escaping (StorageKind, String, String?) -> Void) {
        let closure = JSClosure { args in
            guard let e = args.first?.object else { return .undefined }
            // The storage event fires cross-document for localStorage. key == null
            // means clear() — no per-key delivery; ignored (ledgered residual).
            guard let key = e.key.string else { return .undefined }
            onExternalChange(.local, key, e.newValue.string)
            return .undefined
        }
        _ = JSObject.global.window.object?.addEventListener?("storage", closure)
        envClosures.append(closure)
    }
```

Implementer note: verify the JavaScriptKit 0.22 throwing-call spelling (`JSFunction.throws` / `JSThrowingFunction`) against the pinned checkout (`grep -rn "throws" .build/checkouts/JavaScriptKit/Sources/JavaScriptKit/ | grep -i function | head`). If no throwing variant exists in 0.22, fall back to plain `_ = s.setItem?(key, value)` and record quota behavior as a browser-acceptance checklist item.

- [ ] **Step 2: Native suite + wasm gate**

Run: `swift test 2>&1 | tail -3` — unchanged.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM 2>&1 | tail -3` — `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/SwiftWUIDOM/DOMBackend.swift
git commit -m "feat(dom): localStorage/sessionStorage backing + storage-event observation"
```

---

### Task 5: WebFetch core (types, session, env)

**Files:**
- Create: `Sources/SwiftWUI/Fetch/WebFetch.swift`
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (`_webSession` SPI + renderPass seed)
- Test: `Tests/SwiftWUITests/WebFetchTests.swift`

**Interfaces:**
- Consumes: `EnvironmentKey`.
- Produces: `enum HTTPMethod: String { get/post/put/patch/delete/head }` (rawValues UPPERCASE); `struct WebRequest { var url: String; var method: HTTPMethod; var headers: [String: String]; var body: Data?; var timeout: Duration?; init(url: String) }`; `struct WebResponse { let status: Int; let headers: [String: String]; var isSuccess: Bool }` with public memberwise init; `enum WebFetchError: Error, Equatable { badURL(String), invalidHeader(String), network(String), cancelled, timeout, decoding(String), httpStatus(Int, Data), unsupported }`; `protocol FetchTransport: AnyObject { func perform(_ request: WebRequest) async throws -> (Data, WebResponse) }`; `final class WebSession { init(transport:); data(for:); data(from:); json(from:as:); send(_:_:json:) }` + `static let unsupported`; `EnvironmentValues.webSession: WebSession` (default = unsupported), internal `._webSessionOptional`; `Runtime._webSession: WebSession?` (SPI, seeded into env).

- [ ] **Step 1: Write `Sources/SwiftWUI/Fetch/WebFetch.swift`**

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum HTTPMethod: String, Sendable {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH"
    case delete = "DELETE", head = "HEAD"
}

/// URLRequest-shaped value (no FoundationNetworking on wasm). URL may be
/// absolute http(s) or origin-relative ("/api/x", "api/x", "?q=1").
public struct WebRequest {
    public var url: String
    public var method: HTTPMethod = .get
    public var headers: [String: String] = [:]
    public var body: Data? = nil
    /// Enforced by the transport (fetch: abort timer; URLSession: timeoutInterval).
    public var timeout: Duration? = nil
    public init(url: String) { self.url = url }
}

public struct WebResponse: Equatable {
    public let status: Int
    public let headers: [String: String]
    public var isSuccess: Bool { (200..<300).contains(status) }
    public init(status: Int, headers: [String: String]) {
        self.status = status; self.headers = headers
    }
}

public enum WebFetchError: Error, Equatable {
    case badURL(String)
    case invalidHeader(String)
    case network(String)
    case cancelled
    case timeout
    case decoding(String)
    /// Thrown ONLY by the Codable sugar on non-2xx (URLSession parity:
    /// data(for:) never treats status as an error).
    case httpStatus(Int, Data)
    case unsupported
}

/// Injected per platform: SwiftWUIDOM = fetch(), SwiftWUIStatic = URLSession,
/// tests = scripted mock. Core ships only the unconfigured default (throws).
public protocol FetchTransport: AnyObject {
    func perform(_ request: WebRequest) async throws -> (Data, WebResponse)
}

final class _UnsupportedTransport: FetchTransport {
    func perform(_ request: WebRequest) async throws -> (Data, WebResponse) {
        throw WebFetchError.unsupported
    }
}

/// Per-runtime fetch session, delivered via @Environment(\.webSession) — never
/// a process global (test isolation). Credential policy is a transport-level
/// security invariant: same-origin only, both platforms.
@MainActor
public final class WebSession {
    public static let unsupported = WebSession(transport: _UnsupportedTransport())
    private let transport: FetchTransport
    public init(transport: FetchTransport) { self.transport = transport }

    public func data(for request: WebRequest) async throws -> (Data, WebResponse) {
        try Self.validate(request)
        return try await transport.perform(request)
    }
    public func data(from url: String) async throws -> (Data, WebResponse) {
        try await data(for: WebRequest(url: url))
    }
    public func json<T: Decodable>(from url: String, as type: T.Type = T.self) async throws -> T {
        let (data, resp) = try await data(from: url)
        guard resp.isSuccess else { throw WebFetchError.httpStatus(resp.status, data) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw WebFetchError.decoding(String(describing: error)) }
    }
    public func send<B: Encodable, T: Decodable>(
        _ method: HTTPMethod, _ url: String, json body: B) async throws -> T {
        var req = WebRequest(url: url)
        req.method = method
        req.headers["Content-Type"] = "application/json"
        do { req.body = try JSONEncoder().encode(body) }
        catch { throw WebFetchError.decoding(String(describing: error)) }
        let (data, resp) = try await data(for: req)
        guard resp.isSuccess else { throw WebFetchError.httpStatus(resp.status, data) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw WebFetchError.decoding(String(describing: error)) }
    }

    /// Boundary validation (spec 8a security): http/https only — narrower than
    /// sanitizeURL's attribute allowlist; CR/LF/NUL rejected in header names AND values.
    static func validate(_ request: WebRequest) throws {
        let url = request.url
        let beforePathOrQuery = url.prefix { $0 != "/" && $0 != "?" && $0 != "#" }
        if beforePathOrQuery.contains(":") {                       // has a scheme
            let scheme = url.prefix { $0 != ":" }.lowercased()
            guard scheme == "http" || scheme == "https" else {
                throw WebFetchError.badURL(url)
            }
        }                                                           // else: relative — OK
        for (name, value) in request.headers {
            for scalar in name.unicodeScalars where scalar == "\r" || scalar == "\n" || scalar == "\0" {
                _ = scalar; throw WebFetchError.invalidHeader(name)
            }
            for scalar in value.unicodeScalars where scalar == "\r" || scalar == "\n" || scalar == "\0" {
                _ = scalar; throw WebFetchError.invalidHeader(name)
            }
        }
    }
}

struct _WebSessionKey: EnvironmentKey {
    static let defaultValue: WebSession? = nil
}
extension EnvironmentValues {
    /// The runtime's fetch session. Outside a configured runtime every request
    /// throws WebFetchError.unsupported.
    public var webSession: WebSession {
        self[_WebSessionKey.self] ?? WebSession.unsupported
    }
    var _webSessionOptional: WebSession? {
        get { self[_WebSessionKey.self] }
        set { self[_WebSessionKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Runtime seed**

`Runtime.swift` — SPI property next to `_signals`:

```swift
    /// Set by the platform layer (DOMRuntime / SSG driver) BEFORE mount().
    public var _webSession: WebSession?
```

`renderPass()` — after the `_storageStore` seed:

```swift
        ctx.environment._webSessionOptional = _webSession
```

- [ ] **Step 3: Tests — `Tests/SwiftWUITests/WebFetchTests.swift`**

```swift
import Foundation
import Testing
@testable import SwiftWUI

@MainActor
private final class MockTransport: FetchTransport {
    var queue: [Result<(Data, WebResponse), WebFetchError>] = []
    private(set) var requests: [WebRequest] = []
    func perform(_ request: WebRequest) async throws -> (Data, WebResponse) {
        requests.append(request)
        return try queue.removeFirst().get()
    }
}

private struct Item: Codable, Equatable { let id: Int; let name: String }

@Suite @MainActor struct WebFetchTests {

    @Test func schemeValidation() async {
        let session = WebSession(transport: MockTransport())
        await #expect(throws: WebFetchError.badURL("javascript:alert(1)")) {
            _ = try await session.data(from: "javascript:alert(1)")
        }
        await #expect(throws: WebFetchError.badURL("data:text/html,x")) {
            _ = try await session.data(from: "data:text/html,x")
        }
    }

    @Test func relativeURLsPass() async throws {
        let t = MockTransport()
        t.queue = [.success((Data(), WebResponse(status: 200, headers: [:]))),
                   .success((Data(), WebResponse(status: 200, headers: [:])))]
        let session = WebSession(transport: t)
        _ = try await session.data(from: "/api/items?tag=a:b")   // colon after "/" is fine
        _ = try await session.data(from: "https://example.com/x")
        #expect(t.requests.count == 2)
    }

    @Test func headerCRLFRejected() async {
        var req = WebRequest(url: "/x")
        req.headers["X-Bad"] = "a\r\nInjected: yes"
        let session = WebSession(transport: MockTransport())
        await #expect(throws: WebFetchError.invalidHeader("X-Bad")) {
            _ = try await session.data(for: req)
        }
    }

    @Test func jsonSugarDecodes() async throws {
        let t = MockTransport()
        let payload = try JSONEncoder().encode(Item(id: 1, name: "a"))
        t.queue = [.success((payload, WebResponse(status: 200, headers: [:])))]
        let session = WebSession(transport: t)
        let item: Item = try await session.json(from: "/api/item")
        #expect(item == Item(id: 1, name: "a"))
    }

    @Test func jsonSugarThrowsHttpStatusOnNon2xx() async throws {
        let t = MockTransport()
        let body = Data("nope".utf8)
        t.queue = [.success((body, WebResponse(status: 404, headers: [:])))]
        let session = WebSession(transport: t)
        await #expect(throws: WebFetchError.httpStatus(404, body)) {
            let _: Item = try await session.json(from: "/missing")
        }
    }

    @Test func dataForDoesNotTreatStatusAsError() async throws {
        let t = MockTransport()
        t.queue = [.success((Data(), WebResponse(status: 500, headers: [:])))]
        let session = WebSession(transport: t)
        let (_, resp) = try await session.data(from: "/x")
        #expect(resp.status == 500)
        #expect(!resp.isSuccess)
    }

    @Test func sendEncodesBodyAndContentType() async throws {
        let t = MockTransport()
        let respBody = try JSONEncoder().encode(Item(id: 2, name: "b"))
        t.queue = [.success((respBody, WebResponse(status: 201, headers: [:])))]
        let session = WebSession(transport: t)
        let created: Item = try await session.send(.post, "/api/items", json: Item(id: 2, name: "b"))
        #expect(created.id == 2)
        #expect(t.requests[0].method == .post)
        #expect(t.requests[0].headers["Content-Type"] == "application/json")
        #expect(t.requests[0].body != nil)
    }

    @Test func unconfiguredDefaultThrowsUnsupported() async {
        await #expect(throws: WebFetchError.unsupported) {
            _ = try await EnvironmentValues().webSession.data(from: "/x")
        }
    }

    @Test func runtimeSeedsSessionIntoEnvironment() {
        @MainActor final class Probe { var configured: Bool? = nil }
        struct FetchReader: Tag {
            let probe: Probe
            @Environment(\.webSession) var session
            var body: some Tag {
                probe.configured = (session !== WebSession.unsupported)
                return Text("x")
            }
        }
        let probe = Probe()
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: FetchReader(probe: probe), scheduleMicrotask: { $0() })
        runtime._webSession = WebSession(transport: MockTransport())
        runtime.mount()
        #expect(probe.configured == true)
    }
}
```

- [ ] **Step 4: Run the full native suite once**

Run: `swift test 2>&1 | tail -5` — all pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI Tests/SwiftWUITests/WebFetchTests.swift
git commit -m "feat(fetch): WebSession/WebRequest URLSession-shape core with injected transport"
```

---

### Task 6: DOM fetch transport (wasm)

**Files:**
- Modify: `Package.swift` (SwiftWUIDOM += JavaScriptFoundationCompat)
- Create: `Sources/SwiftWUIDOM/JSInterop.swift`
- Create: `Sources/SwiftWUIDOM/FetchJSTransport.swift`
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (inject session in `makeRuntime`)

**Interfaces:**
- Consumes: `FetchTransport`, `WebRequest/WebResponse/WebFetchError` (Task 5), `Runtime._webSession`.
- Produces: `final class FetchJSTransport: FetchTransport` (wasm-only); `func _dataFromArrayBuffer(_ buffer: JSValue) -> Data` in `JSInterop.swift` (reused by Task 9).

- [ ] **Step 1: Package.swift**

Add to the SwiftWUIDOM target's dependencies:

```swift
            .product(name: "JavaScriptFoundationCompat", package: "JavaScriptKit"),
```

Implementer note: verify the product exists in the pinned JavaScriptKit (`grep -n "JavaScriptFoundationCompat" .build/checkouts/JavaScriptKit/Package.swift`). If absent in 0.22, skip the product and rely solely on the hand-rolled helper below (it is self-sufficient).

- [ ] **Step 2: `Sources/SwiftWUIDOM/JSInterop.swift`**

```swift
#if arch(wasm32)
import JavaScriptKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// ArrayBuffer → Data. Wraps the buffer in a Uint8Array and copies through
/// JSTypedArray (bulk copy — never a per-byte boxed loop).
@MainActor
func _dataFromArrayBuffer(_ buffer: JSValue) -> Data {
    guard let bufObject = buffer.object,
          let u8 = JSObject.global.Uint8Array.function?.new(bufObject),
          let typed = JSTypedArray<UInt8>(u8) else { return Data() }
    return Data(typed.toArray())
}

/// Data → Uint8Array (request bodies).
@MainActor
func _uint8Array(from data: Data) -> JSObject {
    let typed = JSTypedArray<UInt8>([UInt8](data))
    return typed.jsObject
}
#endif
```

Implementer note: `JSTypedArray` API names (`toArray()`, `init?(_ jsObject:)`, `jsObject`) must be verified against the pinned 0.22 checkout (`ls .build/checkouts/JavaScriptKit/Sources/JavaScriptKit/BasicObjects/`). If `JavaScriptFoundationCompat` shipped (Step 1), prefer its `Data.jsTypedArray` / `JSTypedArray.data` equivalents and delete the manual copies.

- [ ] **Step 3: `Sources/SwiftWUIDOM/FetchJSTransport.swift`**

```swift
#if arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// fetch()-backed transport. Security invariants (spec 8a): credentials
/// "same-origin"; scheme/header validation already ran in WebSession.
final class FetchJSTransport: FetchTransport {
    func perform(_ request: WebRequest) async throws -> (Data, WebResponse) {
        let options = JSObject.global.Object.function!.new()
        options.method = .string(request.method.rawValue)
        options.credentials = .string("same-origin")
        if !request.headers.isEmpty {
            let headers = JSObject.global.Object.function!.new()
            for (k, v) in request.headers { headers[k] = .string(v) }
            options.headers = .object(headers)
        }
        if let body = request.body {
            options.body = .object(_uint8Array(from: body))
        }
        guard let controller = JSObject.global.AbortController.function?.new() else {
            throw WebFetchError.unsupported
        }
        options.signal = controller.signal

        final class TimeoutFlag { var fired = false }
        let timedOut = TimeoutFlag()
        var timeoutHandle: JSValue?
        if let timeout = request.timeout {
            let ms = Double(timeout.components.seconds) * 1000
                   + Double(timeout.components.attoseconds) / 1e15
            timeoutHandle = JSObject.global.setTimeout!(JSOneshotClosure { _ in
                timedOut.fired = true
                _ = controller.abort?()
                return .undefined
            }, ms)
        }
        defer { if let t = timeoutHandle { _ = JSObject.global.clearTimeout?(t) } }

        do {
            let fetched = JSObject.global.fetch!(request.url, options)
            guard let promise = JSPromise(fetched.object ?? JSObject()) else {
                throw WebFetchError.network("fetch did not return a promise")
            }
            let respValue = try await withTaskCancellationHandler {
                try await promise.value
            } onCancel: {
                // nonisolated @Sendable — safe on single-threaded wasm.
                MainActor.assumeIsolated { _ = controller.abort?() }
            }
            guard let resp = respValue.object else {
                throw WebFetchError.network("no response object")
            }
            let status = Int(resp.status.number ?? 0)
            final class HeaderBox { var dict: [String: String] = [:] }
            let box = HeaderBox()
            let collect = JSClosure { args in
                if let v = args.first?.string, args.count > 1, let k = args[1].string {
                    box.dict[k] = v
                }
                return .undefined
            }
            _ = resp.headers.object?.forEach?(collect)   // synchronous iteration
            guard let bufPromise = JSPromise((resp.arrayBuffer!()).object ?? JSObject()) else {
                throw WebFetchError.network("arrayBuffer did not return a promise")
            }
            let buf = try await bufPromise.value
            return (_dataFromArrayBuffer(buf), WebResponse(status: status, headers: box.dict))
        } catch let e as WebFetchError {
            throw e
        } catch {
            if timedOut.fired { throw WebFetchError.timeout }
            if Task.isCancelled { throw WebFetchError.cancelled }
            throw WebFetchError.network(String(describing: error))
        }
    }
}
#endif
```

- [ ] **Step 4: Inject in `DOMRuntime.makeRuntime` (DOMRuntime.swift:40-47)**

```swift
    private static func makeRuntime<B: RendererBackend>(
        root: some Tag, backend: B, container: B.HostNode, initialPath: String,
        globalStyles: [Rule], themes: [ThemeDefinition], fontFaces: [FontFace]
    ) -> Runtime<B> {
        let runtime = Runtime(backend: backend, container: container, root: root,
                              initialPath: initialPath,
                              scheduleMicrotask: jsMicrotask, globalStyles: globalStyles,
                              themes: themes, fontFaces: fontFaces)
        runtime._webSession = WebSession(transport: FetchJSTransport())
        return runtime
    }
```

(Single choke point — both the adoption and cold-mount paths go through `makeRuntime`.)

- [ ] **Step 5: Native suite + wasm gate**

Run: `swift test 2>&1 | tail -3` — unchanged.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM 2>&1 | tail -3` — `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/SwiftWUIDOM
git commit -m "feat(dom): fetch() transport — same-origin credentials, abort, timeout"
```

---

### Task 7: URLSession transport for SSG builds

**Files:**
- Create: `Sources/SwiftWUIStatic/URLSessionTransport.swift`
- Modify: `Sources/SwiftWUIStatic/StaticSite.swift` (inject after Runtime construction)
- Test: `Tests/SwiftWUITests/WebFetchTests.swift` (append one test)

**Interfaces:**
- Consumes: `FetchTransport`, `WebSession`, `Runtime._webSession` (Task 5).
- Produces: `final class URLSessionTransport: FetchTransport` (internal to SwiftWUIStatic); SSG-rendered bodies see a configured `webSession`.

- [ ] **Step 1: Write the transport**

`Sources/SwiftWUIStatic/URLSessionTransport.swift`:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // corelibs (Linux); on Darwin URLSession is in Foundation
#endif
import SwiftWUI

/// Build-time transport for `.task(policy: .build)` fetches. SECURITY (spec 8a):
/// runs with the builder's network position — URLs must be trusted/static.
/// Ephemeral session, no cookie storage: the same-origin credential invariant.
final class URLSessionTransport: FetchTransport {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        session = URLSession(configuration: config)
    }
    func perform(_ request: WebRequest) async throws -> (Data, WebResponse) {
        guard let url = URL(string: request.url),
              url.scheme == "http" || url.scheme == "https" else {
            // Relative URLs need a document origin — build-time has none.
            throw WebFetchError.badURL(request.url)
        }
        var req = URLRequest(url: url)
        req.httpMethod = request.method.rawValue
        req.httpBody = request.body
        for (k, v) in request.headers { req.setValue(v, forHTTPHeaderField: k) }
        if let t = request.timeout { req.timeoutInterval = Double(t.components.seconds) }
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw WebFetchError.network("non-HTTP response")
            }
            var headers: [String: String] = [:]
            for (k, v) in http.allHeaderFields {
                if let ks = k as? String, let vs = v as? String { headers[ks] = vs }
            }
            return (data, WebResponse(status: http.statusCode, headers: headers))
        } catch let e as WebFetchError { throw e }
        catch is CancellationError { throw WebFetchError.cancelled }
        catch { throw WebFetchError.network(String(describing: error)) }
    }
}
```

- [ ] **Step 2: Inject in the SSG driver**

Find every `Runtime(` construction in SwiftWUIStatic: `grep -n "Runtime(" Sources/SwiftWUIStatic/*.swift`. Immediately after each construction (before `mount()`), add:

```swift
        runtime._webSession = WebSession(transport: URLSessionTransport())
```

(Adjust the variable name to the local one. If constructions share a helper, add it once there — mirror what Task 6 did with `makeRuntime`.)

- [ ] **Step 3: Append a wiring test to `WebFetchTests.swift`**

The SSG driver's entry point is `StaticSite` — locate its render entry (`grep -n "public func\|public static func" Sources/SwiftWUIStatic/StaticSite.swift | head`) and reuse whatever existing SSG test fixture pattern `Tests/SwiftWUITests` already has for StaticSite (`grep -rln "StaticSite" Tests/SwiftWUITests | head -2` — follow that file's setup). The test:

```swift
    @Test func ssgRuntimeSeesConfiguredSession() throws {
        @MainActor final class Probe { var configured: Bool? = nil }
        struct FetchProbePage: Tag {
            let probe: Probe
            @Environment(\.webSession) var session
            var body: some Tag {
                probe.configured = (session !== WebSession.unsupported)
                return Text("ok")
            }
        }
        let probe = Probe()
        // Render FetchProbePage through the same StaticSite entry the existing
        // SSG tests use; then:
        #expect(probe.configured == true)
    }
```

If StaticSite's fixture overhead is disproportionate, the fallback assertion is direct: construct the runtime the way StaticSite does, set the transport, mount with MockBackend, probe — the wiring line itself is then covered by a `grep`-verifiable review note in the task report.

- [ ] **Step 4: Run the full native suite once**

Run: `swift test 2>&1 | tail -5` — all pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUIStatic Tests/SwiftWUITests/WebFetchTests.swift
git commit -m "feat(ssg): URLSession transport for build-time fetches — ephemeral, no cookies"
```

---

### Task 8: File select core (WebFile, FilesEvent, onFileSelection)

**Files:**
- Create: `Sources/SwiftWUI/HTML/WebFile.swift`
- Modify: `Sources/SwiftWUI/HTML/Tags.swift` (Input base init += `accept`/`multiple`)
- Test: `Tests/SwiftWUITests/FileSelectTests.swift`

**Interfaces:**
- Consumes: `_AttributeBag.addHandler(_:payload:_:)`, `EventName.change`, `Binding`.
- Produces: `protocol _FileReading: AnyObject { func data() async throws -> Data; func text() async throws -> String }`; `struct WebFile { name, size, mimeType, lastModified; init(name:size:mimeType:lastModified:reader:); data(); text() }`; `struct FilesEvent { let files: [WebFile] }`; `Input.onFileSelection(_ action: @escaping ([WebFile]) -> Void) -> Input`; `Input.init` gains `accept: String? = nil, multiple: Bool = false`.

- [ ] **Step 1: Write `Sources/SwiftWUI/HTML/WebFile.swift`**

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Backend-injected reader: DOM wraps the JS File; tests serve memory bytes.
public protocol _FileReading: AnyObject {
    func data() async throws -> Data
    func text() async throws -> String
}

/// A user-picked file. TRUST: `name`/`mimeType`/`size`/`lastModified` are
/// client claims — attacker-controlled. Never make a security/content decision
/// on `mimeType` (validate bytes); never build a filesystem path from `name`;
/// `data()`/`text()` buffer the ENTIRE file — check `size` before reading.
public struct WebFile {
    public let name: String
    public let size: Int
    public let mimeType: String
    public let lastModified: Date
    private let reader: any _FileReading

    public init(name: String, size: Int, mimeType: String, lastModified: Date,
                reader: any _FileReading) {
        self.name = name; self.size = size; self.mimeType = mimeType
        self.lastModified = lastModified; self.reader = reader
    }
    public func data() async throws -> Data { try await reader.data() }
    public func text() async throws -> String { try await reader.text() }
}

/// `change` payload for input[type=file]. The backend emits THIS instead of
/// ChangeEvent for file inputs — a plain ChangeEvent handler on a file input
/// never fires (documented; payload cast drops it).
public struct FilesEvent {
    public let files: [WebFile]
    public init(files: [WebFile]) { self.files = files }
}

extension Input {
    /// Selected files on change. Only meaningful on `Input(type: .file)`.
    public func onFileSelection(_ action: @escaping ([WebFile]) -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.change, payload: FilesEvent.self) { e in
            action(e.files)
        }
        return copy
    }
}
```

- [ ] **Step 2: Input attributes**

`Tags.swift:99-108` — extend the base init (defaulted params keep source compatibility):

```swift
    public init(type: InputType = .text, name: String? = nil, value: String? = nil,
                placeholder: String? = nil, disabled: Bool = false,
                accept: String? = nil, multiple: Bool = false,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", type.rawValue)
        _attributes.set("name", name)
        _attributes.set("value", value)
        _attributes.set("placeholder", placeholder)
        if disabled { _attributes.set("disabled", "") }
        _attributes.set("accept", accept)
        if multiple { _attributes.set("multiple", "") }
    }
```

- [ ] **Step 3: Tests — `Tests/SwiftWUITests/FileSelectTests.swift`**

```swift
import Foundation
import Testing
@testable import SwiftWUI

private final class InMemoryReader: _FileReading {
    let bytes: Data
    init(_ s: String) { bytes = Data(s.utf8) }
    func data() async throws -> Data { bytes }
    func text() async throws -> String { String(decoding: bytes, as: UTF8.self) }
}

@Suite @MainActor struct FileSelectTests {

    private func makeFile(_ name: String, _ content: String) -> WebFile {
        WebFile(name: name, size: content.utf8.count, mimeType: "text/plain",
                lastModified: Date(timeIntervalSince1970: 0),
                reader: InMemoryReader(content))
    }

    @Test func onFileSelectionReceivesFiles() {
        @MainActor final class Box { var names: [String] = [] }
        let box = Box()
        struct Picker: Tag {
            let box: Box
            var body: some Tag {
                Input(type: .file, multiple: true)
                    .onFileSelection { files in box.names = files.map(\.name) }
            }
        }
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Picker(box: box), scheduleMicrotask: { $0() })
        runtime.mount()
        func firstChange(_ n: MockNode) -> ListenerID? {
            if let id = n.events["change"] { return id }
            for c in n.children { if let id = firstChange(c) { return id } }
            return nil
        }
        let lid = firstChange(backend.container)!
        runtime.dispatch(lid, payload: FilesEvent(files: [makeFile("a.txt", "hi"),
                                                          makeFile("b.txt", "yo")]))
        #expect(box.names == ["a.txt", "b.txt"])
    }

    @Test func webFileReadsThroughReader() async throws {
        let file = makeFile("a.txt", "hello")
        #expect(try await file.text() == "hello")
        #expect(try await file.data() == Data("hello".utf8))
        #expect(file.size == 5)
    }

    @Test func acceptAndMultipleSerialize() {
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Input(type: .file, accept: ".png,image/*", multiple: true),
                              scheduleMicrotask: { $0() })
        runtime.mount()
        let html = backend.serializeHTML()
        #expect(html.contains(#"accept=".png,image/*""#))
        #expect(html.contains("multiple"))
        _ = runtime
    }
}
```

- [ ] **Step 4: Run the full native suite once**

Run: `swift test 2>&1 | tail -5` — all pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI Tests/SwiftWUITests/FileSelectTests.swift
git commit -m "feat(html): WebFile/FilesEvent + Input file-select surface"
```

---

### Task 9: DOM file decode + reader (wasm)

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (decodePayload change case)
- Create: `Sources/SwiftWUIDOM/DOMFileReader.swift`

**Interfaces:**
- Consumes: `WebFile`/`FilesEvent`/`_FileReading` (Task 8), `_dataFromArrayBuffer` (Task 6).
- Produces: `change` on `input[type=file]` → `FilesEvent` on wasm; `final class DOMFileReader: _FileReading`.

- [ ] **Step 1: `Sources/SwiftWUIDOM/DOMFileReader.swift`**

```swift
#if arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Wraps a JS `File`. Retains the JSObject; reads via its promise APIs.
final class DOMFileReader: _FileReading {
    private let file: JSObject
    init(file: JSObject) { self.file = file }

    func data() async throws -> Data {
        guard let promise = JSPromise((file.arrayBuffer!()).object ?? JSObject()) else {
            throw WebFetchError.network("File.arrayBuffer did not return a promise")
        }
        let buf = try await promise.value
        return _dataFromArrayBuffer(buf)
    }
    func text() async throws -> String {
        guard let promise = JSPromise((file.text!()).object ?? JSObject()) else {
            throw WebFetchError.network("File.text did not return a promise")
        }
        return try await promise.value.string ?? ""
    }
}
#endif
```

- [ ] **Step 2: decodePayload (`DOMBackend.swift:65-67`)**

Replace the `change` case:

```swift
        case "change":
            if let t = target, t.type.string == "file", let files = t.files.object {
                let n = Int(files.length.number ?? 0)
                var out: [WebFile] = []
                out.reserveCapacity(n)
                for i in 0..<n {
                    guard let f = files.item?(i).object else { continue }
                    out.append(WebFile(
                        name: f.name.string ?? "",
                        size: Int(f.size.number ?? 0),
                        mimeType: f.type.string ?? "",
                        lastModified: Date(timeIntervalSince1970: (f.lastModified.number ?? 0) / 1000),
                        reader: DOMFileReader(file: f)))
                }
                return FilesEvent(files: out)
            }
            return ChangeEvent(value: target?.value.string ?? "",
                               checked: target?.checked.boolean ?? false)
```

Add the Foundation-essentials import block at the top of `DOMBackend.swift` (for `Date`), matching the idiom used elsewhere in the module.

- [ ] **Step 3: Native suite + wasm gate**

Run: `swift test 2>&1 | tail -3` — unchanged.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM 2>&1 | tail -3` — `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUIDOM
git commit -m "feat(dom): decode input[type=file] change into FilesEvent with JS File readers"
```

---

### Task 10: Stress test, example demo, docs, acceptance checklist

**Files:**
- Test: `Tests/SwiftWUITests/SignalsStressTests.swift`
- Modify: `Examples/Counter/Sources/**` (demo page — locate main view: `grep -rln "struct.*: App" Examples/Counter/Sources`)
- Create: `Examples/Counter/public/data.json` (fetch-demo fixture; `public/` is the URL-root convention from the assets slice)
- Modify: `CLAUDE.md` (3 lines)

**Interfaces:**
- Consumes: everything above. Produces: no new API.

- [ ] **Step 1: Stress test (spec risk gate — must land before 8b/8c build on the mechanism)**

`Tests/SwiftWUITests/SignalsStressTests.swift`:

```swift
import Testing
@testable import SwiftWUI

@MainActor
private final class Sched {
    var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func drain() { while !queue.isEmpty { queue.removeFirst()() } }
}

@MainActor private final class Tally { var bodies = 0 }

private struct StressReader: Tag {
    let tally: Tally
    @Environment(\.colorScheme) var scheme
    var body: some Tag {
        tally.bodies += 1
        return Span { Text(scheme == .dark ? "d" : "l") }
    }
}
private struct StressRoot: Tag {
    let tally: Tally
    var body: some Tag {
        Div {
            ForEach(0..<50, id: \.self) { _ in StressReader(tally: tally) }
        }
    }
}

@Suite @MainActor struct SignalsStressTests {

    @Test func fiftyReadersAllUpdate_flipsCoalesce() {
        let tally = Tally()
        let backend = MockBackend()
        let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: StressRoot(tally: tally), scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        #expect(tally.bodies == 50)

        // 10 rapid flips BEFORE the microtask drains → coalesced into one flush.
        let writer = backend.environmentWriter!
        for i in 0..<10 { writer.setColorScheme(i % 2 == 0 ? .dark : .light) }
        sched.drain()
        #expect(backend.serializeHTML().contains("l"))     // final value wins
        // One coalesced re-render of the 50 readers, not 10×50.
        #expect(tally.bodies == 100)
        _ = runtime
    }

    @Test func storageAndSignalsInterleaved() {
        struct Mixed: Tag {
            @Environment(\.colorScheme) var scheme
            @AppStorage("n") var n = 0
            var body: some Tag { Text("\(scheme == .dark ? "d" : "l"):\(n)") }
        }
        let backend = MockBackend(); let sched = Sched()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: Mixed(), scheduleMicrotask: sched.schedule)
        runtime.mount(); sched.drain()
        backend.environmentWriter!.setColorScheme(.dark)
        backend.simulateExternalStorageChange(kind: .local, key: "n", value: "7")
        sched.drain()
        #expect(backend.serializeHTML().contains("d:7"))
        _ = runtime
    }
}
```

Implementer note: check `ForEach`'s exact signature in `Sources/SwiftWUI` (`grep -n "struct ForEach" -A 5 Sources/SwiftWUI/**/*.swift`) — adjust the `id:` parameter to the real API. If Observation `onChange` proves one-shot-per-registration under 10 synchronous writes (only the first write fires before re-tracking), relax the `tally.bodies == 100` assertion to `tally.bodies >= 100 && tally.bodies <= 150` and record the measured behavior in the task report — the load-bearing assertions are the final HTML and the coalesced flush count.

- [ ] **Step 2: Demo in Examples/Counter**

Add to the example's main view (adapt to its actual structure): a scheme-aware banner, a persisted counter, a fetch demo against the static `public/data.json`, and a file preview.

`Examples/Counter/public/data.json`:

```json
{ "items": ["alpha", "beta", "gamma"] }
```

Demo section (shape — merge into the existing example view):

```swift
struct BrowserAPIDemo: Tag {
    @Environment(\.colorScheme) var scheme
    @Environment(\.webSession) var session
    @AppStorage("demo.count") var count = 0
    @State var items: [String] = []
    @State var preview = ""

    struct Payload: Decodable { let items: [String] }

    var body: some Tag {
        Div {
            H2("Browser APIs (phase 8a)")
            P("System scheme: \(scheme == .dark ? "dark" : "light")")
            Button("Persisted count: \(count)") { count += 1 }
            Button("Load items") {
                Task {
                    if let p: Payload = try? await session.json(from: "/data.json") {
                        items = p.items
                    }
                }
            }
            Ul { ForEach(items, id: \.self) { Li { Text($0) } } }
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

Verify the example still builds for wasm: `cd Examples/Counter && swift build --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3`.

- [ ] **Step 3: CLAUDE.md**

Append to the "Core architecture" section:

```markdown
- **Reactive env signals (phase 8a):** `EnvironmentSignals` (@Observable, per-Runtime) → computed `EnvironmentValues` keys; tracked ONLY when read inside a component `body` — primitive/_resolve/handler reads get no auto re-render (locale in 8c uses `markDirty(.root)` instead). New signals follow the Writer-closure recipe in EnvironmentSignals.swift.
- **Web storage:** `@AppStorage`/`@SceneStorage` share one observable box per key; plaintext + origin-readable — never store secrets. `__swiftwui.` key prefix reserved.
```

- [ ] **Step 4: Run everything once**

Run: `swift test 2>&1 | tail -5` — all pass.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM 2>&1 | tail -3` — green.

- [ ] **Step 5: Commit**

```bash
git add Tests/SwiftWUITests/SignalsStressTests.swift Examples/Counter CLAUDE.md
git commit -m "test+docs: signals stress gate, browser-APIs demo, CLAUDE.md notes"
```

---

## Browser acceptance checklist (manual, post-implementation)

Run the Counter example (`swiftwui dev` or Vite per CLAUDE.md) and verify:

1. macOS System Settings appearance toggle → banner text flips live (matchMedia leg).
2. DevTools → Application → Local Storage: `demo.count` persists across reload; edit the value in a SECOND tab → first tab re-renders (storage event).
3. Network offline toggle in DevTools → any `isOnline` reader updates (add one temporarily if the demo lacks it).
4. "Load items" renders alpha/beta/gamma; DevTools shows `credentials: same-origin` on the request.
5. Pick a small .txt file → preview renders; pick a >1 MB file → ignored (size guard).
6. SSG page prerendered light + OS in dark mode → first paint corrects to dark without console errors (hydration leg).
7. `.task`-driven fetch works (EventLoop canary: `installGlobalExecutor` at DOMRuntime.swift:94 — if this regresses, every await silently hangs).

## Out of scope (8b/8c — do not implement here)

Permission model, LocationManager, notifications, Web Push, clipboard, share, localization. `scenePhase`/`reducedMotion` signals (mechanism ready; keys not shipped).
