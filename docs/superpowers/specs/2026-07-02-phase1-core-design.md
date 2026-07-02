# SwiftWUI v2 — Phase 1 Core Design (Vertical Slice)

**Date:** 2026-07-02
**Status:** Approved design, pending user spec review
**Branch:** `feature/fable-new-vision` (clean-slate rewrite; v1 lives on `master` as reference)

---

## 1. Context

SwiftWUI is a Swift web UI framework: SwiftUI-inspired declarative API, compiled to WebAssembly, DOM access via JavaScriptKit. The v1 implementation (branch `master`: 8 modules, ~9.3k LOC, 51 tests, Showcase site) proved the concept but accumulated architectural debt — chiefly a structural-identity system bolted on retroactively, which caused every major state bug. v2 is a clean-slate rewrite that re-derives what worked and designs identity in from day one.

This spec was produced by a design panel (3 independent architects + v1 forensics + adversarial critic); all critic findings are resolved inline and logged in §14.

### Approved decisions (do not relitigate)

1. **Clean slate + lessons.** New code from scratch; `master` is reference material only.
2. **Renderer-agnostic core.** The Tag tree knows nothing about the DOM. Two backends from day one: `HTMLRenderer` (string, for tests/SSG) and a DOM backend (WASM).
3. **SwiftUI-style API.** Protocols + structs, value semantics. No class inheritance for Page/App.
4. **VDOM + invalidation-ready identity.** Virtual node tree + reconciler diffing; structural identity and state slots designed in from the start so phase 2 can add component-scoped invalidation with **no API change**. Phase 1 re-renders from root.
5. **Naming: `Tag` stays.** Collision with `Testing.Tag` is contained by a test-support `typealias`. Recorded here so it is not relitigated at 1.0.

### Phase 1 scope (vertical slice)

**In:** `Tag` protocol, `@TagBuilder`, ~30 base HTML tags, custom components via `body`, node tree + structural identity, `HTMLRenderer`, DOM backend + reconciler, minimal `@State` + `Binding`, `App` protocol + `@main`, Counter example.

**Out (deferred):** styles/modifiers, router, Page metadata, full HTML tag set, event payloads (`onInput` etc.), controlled inputs, `@Environment`/`onChange`/`task`, Observation, SSR/hydration, BridgeJS, CLI/hot-reload.

**Success criteria:**
- Counter clicks in the browser; state survives re-render.
- The same page renders to an HTML string in native unit tests without a browser.
- Two sibling `Counter()`s hold independent counts.
- `if` branch toggle resets contained state (SwiftUI semantics).
- `ForEach` reorder preserves per-item state by key.
- Zero DOM listener add/remove calls during a normal re-render (asserted by a counting mock).

The **native test gate is primary**; the browser demo is contingent on toolchain install (§13).

### Roadmap (each later phase gets its own brainstorm + spec)

| # | Phase | Contents |
|---|-------|----------|
| 1 | Core vertical slice | this spec |
| 2 | Reactivity | full @State/@Binding/@Observable/@Environment, onChange, task, typed event payloads, component-scoped invalidation, controlled inputs |
| 3 | Styles | modifier system, typed CSS, `Style` protocol, themes, media queries |
| 4 | Pages & routing | `Page` metadata, Router-as-Tag, SPA navigation, history API |
| 5 | Full HTML + SSG/embedded | complete tag set, static generation, no-WASM embedded mode |
| 6 | Toolchain | `swiftwui` CLI, dev server, hot-reload, MVVM/TCA templates, containers |
| 7 | Documentation site | built with SwiftWUI itself |

---

## 2. Module layout

Two targets (v1's 8 modules were ahead of need):

```
Package.swift                 // swift-tools-version: 6.2 (needed for .defaultIsolation), Swift 6.3.3
Sources/
  SwiftWUI/       // THE library. Renderer-agnostic, zero dependencies, builds natively.
                  // Tag, TagBuilder, primitives, Text, ForEach, AnyTag,
                  // ~30 HTML tags, _AttributeBag, EventName,
                  // State, Binding, App protocol,
                  // Node tree + structural identity, resolver, StateStore,
                  // ListenerRegistry, Reconciler, TreeApplier, MockBackend seam,
                  // HTMLRenderer, HTMLEscaping
  SwiftWUIDOM/    // depends: SwiftWUI + JavaScriptKit. WASM only in practice.
                  // DOMBackend, microtask scheduler, DOMRuntime.mount, App.main extension
Tests/
  SwiftWUITests/  // native `swift test`, no browser
Examples/
  Counter/        // wasm executable; imports SwiftWUI + SwiftWUIDOM
```

The core keeps the flagship name `SwiftWUI`; the only user file importing `SwiftWUIDOM` is the app entry point. No umbrella target.

Concurrency posture: **the entire runtime is `@MainActor`-confined; no `Sendable` requirements anywhere in the render pipeline.** WASM is single-threaded, JavaScriptKit is main-thread-only, native tests run `@MainActor`. Use `.defaultIsolation(MainActor.self)` where it helps. No TaskLocal, no process globals (v1 traps T4/T17).

---

## 3. Public API

### 3.1 Tag protocol

```swift
public protocol Tag {
    associatedtype Body: Tag
    @TagBuilder var body: Body { get }
}

extension Never: Tag {
    public typealias Body = Never
    public var body: Never { fatalError("unreachable") }
}

extension Tag where Body == Never {
    public var body: Never { fatalError("\(Self.self) is a primitive and has no body") }
}
```

`Body == Never` types are **primitives** — the resolver special-cases them instead of recursing into `body`. The single internal seam (exactly ONE recursion entry point — v1 had two, trap T3):

```swift
/// Underscore-public so later phases can add primitives. Not user API.
public protocol _PrimitiveTag: Tag where Body == Never {
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node]
}
```

Phase-1 primitive vocabulary (closed set): `Text`, `EmptyTag`, `TupleTag`, `ConditionalTag`, `Optional`, `Array`, `ForEach`, `AnyTag`, and all HTML element tags. (`ResolveContext` is defined in §6; `NodeIdentity`/`Node` in §§4–5.)

### 3.2 @TagBuilder

```swift
@resultBuilder
public enum TagBuilder {
    public static func buildExpression<T: Tag>(_ tag: T) -> T { tag }
    public static func buildExpression(_ text: String) -> Text { Text(text) }   // Div { "Count: \(n)" }

    public static func buildBlock() -> EmptyTag { EmptyTag() }
    public static func buildBlock<T: Tag>(_ tag: T) -> T { tag }
    public static func buildBlock<each T: Tag>(_ tags: repeat each T) -> TupleTag<repeat each T> {
        TupleTag(repeat each tags)
    }

    public static func buildOptional<T: Tag>(_ tag: T?) -> T? { tag }
    public static func buildEither<F: Tag, S: Tag>(first t: F) -> ConditionalTag<F, S> { .first(t) }
    public static func buildEither<F: Tag, S: Tag>(second t: S) -> ConditionalTag<F, S> { .second(t) }
    public static func buildArray<T: Tag>(_ tags: [T]) -> [T] { tags }          // positional; use ForEach for keys
    public static func buildLimitedAvailability<T: Tag>(_ tag: T) -> AnyTag { AnyTag(tag) }
}
```

`TupleTag` uses parameter packs (no existential boxing; v1-proven on WASM). Fallback if pack `buildBlock` hurts compile times: 10 fixed-arity overloads, call-site compatible.

`ForEach` stores its closure and evaluates it **lazily during resolution** inside the per-item identity frame (eager evaluation at init breaks per-row state — v1 lesson):

```swift
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    public init(_ data: Data, id: KeyPath<Data.Element, ID>,
                @TagBuilder content: @escaping (Data.Element) -> Content)
}
extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @TagBuilder content: @escaping (Data.Element) -> Content)
}
extension ForEach where Data == Range<Int>, ID == Int {
    public init(_ data: Range<Int>, @TagBuilder content: @escaping (Int) -> Content)
}
```

The public surface uses `KeyPath`; internal storage may convert to a closure — pick one representation in code, this spec mandates the public `KeyPath` inits only. No overload may ignore its parameters (v1's `ForEach(_:id:)` lied — trap T19).

`AnyTag` erases only at genuine dynamism points (`buildLimitedAvailability`, heterogeneous collections). Identity contract: `AnyTag` is transparent itself but the *wrapped* dynamic type still contributes its `.type` segment — swapping the wrapped type replaces the subtree and resets its state.

### 3.3 HTML tags (hybrid style)

One protocol so renderers/reconciler have exactly one element code path:

```swift
public protocol HTMLTag: Tag, _PrimitiveTag where Body == Never {
    static var tagName: String { get }
    var _attributes: _AttributeBag { get set }
}
```

`_AttributeBag`: ordered `[(name, value)]` internally; flattens to `[String: String]` with **last-wins per name, except `class` which accumulates space-joined**. Attribute names are validated against `[a-zA-Z_:][a-zA-Z0-9_.:-]*` at `set` time (debug assert, drop in release) — name injection is otherwise unescapable (v1 finding). Beside the attribute pairs, the bag carries an internal listener list `[(EventName, () -> Void)]` (phase 1: `Button.onClick` is its only writer).

Every container tag's `_resolve` delegates to **one shared generic helper** — `resolveElement(tagName:bag:content:path:ctx:)` — which registers the bag's listeners under `ListenerID(owner: path, event:)`, resolves `content` under `path + .child(0)`, and emits the `ElementNode`. Tag structs stay ~20-line data shells; there is exactly one element resolution code path.

Container tags are generic over `Content` (static structure feeds identity; never erase children — trap T16). Void tags are non-generic. Representatives:

```swift
public struct Div<Content: Tag>: HTMLTag {
    public static var tagName: String { "div" }
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content)
}

extension H1 where Content == Text {
    public init(_ text: String, id: String? = nil, class classes: String? = nil)  // H1("Count: \(n)")
}

public struct A<Content: Tag>: HTMLTag {
    // init(href:) runs sanitizeURL (§11) on href. target: LinkTarget enum.
}

public struct Button<Content: Tag>: HTMLTag {
    public init(type: ButtonType = .button, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onClick: (() -> Void)? = nil,
                @TagBuilder content: () -> Content)
}
extension Button where Content == Text {
    public init(_ title: String, /* … */ onClick: @escaping () -> Void)   // Button("+") { count += 1 }
}

/// Void element; attributes only in phase 1. NO onInput — event payloads are phase 2.
public struct Input: HTMLTag {
    public init(type: InputType = .text, name: String? = nil, value: String? = nil,
                placeholder: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil)
}
```

Phase-1 tag set (~30): `Div, Span, P, H1–H6, A, Button, Input, Label, Form, Img, Br, Hr, Ul, Ol, Li, Main, Header, Footer, Nav, Section, Article, Strong, Em, Code, Pre, Textarea` (Textarea static). Each is the same ~20-line pattern; macro generation is a later optimization.

Universal attributes without the modifier system: `id:`/`class:` init params on every tag, plus bag-mutating methods defined once on `HTMLTag`:

```swift
extension HTMLTag {
    public func attribute(_ name: String, _ value: String?) -> Self
    public func id(_ value: String) -> Self
    public func classes(_ names: String...) -> Self     // appends
}
```

These mutate the value's own bag — **no wrapper nodes, identity-transparent by construction**. Rule recorded for phase 3: bag-mutating methods never affect identity; future `ModifiedContent` wrappers do participate in identity.

**Cut from phase 1** (critic findings 6/21/22): `.on(_:perform:)`, `.data()`, `.aria()`, `Input(onInput:)`, value-carrying handlers, interactive `Textarea`. The phase-1 event pipeline carries `() -> Void` only; Counter needs clicks only. Payloads arrive in phase 2 as typed `(EventPayload) -> Void` decoded in the backend — never via process globals (v1 trap T4, the cause of v1's test flake and segfault).

Boolean attributes: convention `value == ""` ⇒ serializer emits bare name (`disabled`). Uniform rule, no per-attribute table.

`EventName` (`RawRepresentable`, `ExpressibleByStringLiteral`, statics `.click` etc.) is the public event vocabulary; node tree and `ListenerID` store `rawValue: String`.

### 3.4 Component model

```swift
struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
            if count >= 10 { P { "Double digits." } }
        }
    }
}
```

`some Tag` fixes an opaque static `Body` type per component; the resolver recurses `body` until it bottoms out at primitives. That static type chain is what structural identity hashes — component identity works with zero user annotations.

Documented semantic (SwiftUI parity): changing a container's generic content type (e.g. `H1("x")` → `H1 { Span {…} }`) replaces the content subtree and resets state below it; the container element itself is reused (same identity, same tag ⇒ patched in place).

### 3.5 App and @main

```swift
// SwiftWUI (core) — no main() here.
public protocol App {
    associatedtype Content: Tag
    init()
    @TagBuilder var body: Content { get }
}
```

```swift
// SwiftWUIDOM — the only module that touches the browser.
@MainActor
public enum DOMRuntime {
    public static func mount(_ root: some Tag, selector: String = "body")
}
extension App {
    @MainActor public static func main() { DOMRuntime.mount(Self().body) }
}
```

`main()` is an **extension, never a protocol requirement** (native builds of core must not link the DOM runtime). Router arrives in phase 4 as content (`Router { Route("/") { … } }` inside `body`) — zero breaking change to `App`.

**Limitation (recorded):** `@State` declared on the `App` struct itself is not linked in phase 1 (the App value is not resolved as a component). State belongs in components. Revisit in phase 2.

### 3.6 @State and Binding

```swift
@propertyWrapper
public struct State<Value> {
    public init(wrappedValue: Value)
    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }     // $count
}

@propertyWrapper
public struct Binding<Value> {
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void)
    public static func constant(_ value: Value) -> Binding<Value>
    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { self }
}
```

`Binding` ships in phase 1 (25 lines; `projectedValue`'s type can't change later without a source break). No `Sendable` annotations anywhere (MainActor-confined; add only if a diagnostic forces it).

---

## 4. Node tree

Pure value types. Diffing needs two immutable trees; value semantics make "old tree" trivially correct. Reference types exist only in runtime bookkeeping (`StateStore`, `MountedNode`, `ListenerRegistry`).

```swift
public enum Node: Equatable {
    case text(String)
    case element(ElementNode)
    case component(ComponentNode)   // boundary marker — the key v2 addition
}

public struct ElementNode: Equatable {
    public var identity: NodeIdentity           // stamped by the resolver (critic finding 12)
    public var tag: String                      // "div"
    public var attributes: [String: String]     // raw, unescaped (escaping is serializer-only)
    public var listeners: [String: ListenerID]  // event → stable ID; closures live in the registry
    public var children: [Node]
    public var key: NodeKey?                    // reconciler key for keyed children (ForEach)
}

/// Transparent component boundary: contributes NO host node itself.
public struct ComponentNode: Equatable {
    public let identity: NodeIdentity
    public let typeName: String                 // debug only, not identity
    public var key: NodeKey?
    public var children: [Node]                 // resolved body (may spread to n nodes)
}

public struct ListenerID: Hashable {
    public let owner: NodeIdentity
    public let event: String
}

/// Wraps any Hashable key (ForEach ids, composite keys). Hashable for
/// IdentitySegment, Equatable for the node structs.
public struct NodeKey: Hashable {
    public let base: AnyHashable
    public init(_ base: some Hashable) { self.base = AnyHashable(base) }
}
```

No `.fragment` case (v1's fragment `<div>` wrapper caused the patch-target bug class — trap T7). Adjacent text nodes are **coalesced at resolve time** so the string-serialized tree parses back node-for-node identical to what the DOM backend builds (trap T8; prerequisite for phase-4 hydration).

---

## 5. Structural identity

**Identity is part of the tree, not a side channel.** Typed path from root:

```swift
public enum IdentitySegment: Hashable {
    case child(Int)        // structural slot in parent (builder tuple position), NOT flattened output index
    case branch(Bool)      // if/else — ConditionalTag
    case keyed(NodeKey)    // ForEach item id; `.id(_:)` later reuses this
    case type(ObjectIdentifier)  // component boundary: concrete Tag type
}

public struct NodeIdentity: Hashable {
    public private(set) var segments: [IdentitySegment]
    public static let root: NodeIdentity
    public func appending(_ s: IdentitySegment) -> NodeIdentity
    public func isSelfOrDescendant(of p: NodeIdentity) -> Bool   // prefix test → scoped GC & phase-2 scoped render
}
```

### Assignment rules (exhaustive; every structural descent appends exactly ONE segment)

| Construct | Segment appended |
|---|---|
| Element content | element resolves children under `path + .child(0)`; `TupleTag` then spreads `.child(i)` beneath (critic finding 11: prevents parent/child path collision for single-child chains) |
| `TupleTag` slot *i* | `.child(i)` |
| Custom component of type `T` at path P | component identity = `P + .type(ObjectIdentifier(T.self))`; its body resolves under `identity + .child(0)` |
| `ConditionalTag` | `.branch(true)` / `.branch(false)` — branch switch ⇒ new identity ⇒ state reset (SwiftUI parity, including same-type-in-both-branches) |
| `Optional` (if without else) | `.branch(true)` when present; absent ⇒ nothing (identity vanishes → swept) |
| `Array` (for-loops) | array occupies its slot; item *i* resolves at `slot + .child(i)` — positional by design, documented "use ForEach for keyed identity" |
| `ForEach` item | `.keyed(NodeKey(item.id))` under the ForEach's slot |
| `AnyTag` | nothing for the erasure; wrapped type's `.type` still applies |

**Same node across renders ⇔ equal `NodeIdentity`.** Elements additionally require equal `tag` to patch in place. Sibling state collision (v1's flagship bug) is impossible by construction — there is no call-site keying anywhere in v2.

`ObjectIdentifier` of metatypes: Hashable, process-stable (all state is in-process), collision-free across modules — unlike v1's type-name strings.

ForEach duplicate ids: debug `assert`, documented programmer error (same as SwiftUI).

### Worked example (normative — uses the fixed `.child(0)` element-content scheme)

```swift
struct Row: Tag { @State var open = false; var body: some Tag { … } }

// Inside the root component's body (root component R = /type(App)):
Div {                              // element at  R/child(0)
    H1("Title")                    //             R/child(0)/child(0)/child(0)   (Div content → child(0), tuple slot 0)
    if showRows {                  // conditional R/child(0)/child(0)/child(1)
        Row()                      //             …/child(1)/branch(true)/type(Row)
    }
    ForEach(items) { _ in          // ForEach at  R/child(0)/child(0)/child(2)
        Row()                      //             …/child(2)/keyed(item.id)/type(Row)
    }
    Row()                          //             R/child(0)/child(0)/child(3)/type(Row)
    Row()                          //             R/child(0)/child(0)/child(4)/type(Row)   ← distinct sibling
}
```

Two trailing `Row()`s: different `.child` slots ⇒ distinct state. `items` reorder: identity contains `.keyed(id)` ⇒ state follows the item. `showRows` false→true: `.branch(true)` identity reappears fresh ⇒ fresh state (SwiftUI parity). **Do not consult the worked example in the panel documents** (`panel-identity.md` §2) — it predates the `.child(0)` collision fix and shows wrong paths.

Identity-related invariants carried from forensics: deterministic IDs on ALL platforms — **no `#if arch` forks in identity logic** (trap T9).

---

## 6. State storage and linking

Two-level indirection (wrapper → `Slot` → `StateBox`), forced by mechanics: `Mirror` yields copies, so adoption works only by retargeting a shared reference cell — visible to all copies **including closures captured before the graft** (v1-proven ordering: link BEFORE `body` evaluation).

```swift
@propertyWrapper
public struct State<Value> {
    final class Slot { var box: StateBox<Value> }
    private let slot: Slot
    public var wrappedValue: Value {
        get { slot.box.value }
        nonmutating set {
            slot.box.value = newValue
            slot.box.invalidate?()      // didSet-style: value already written when invalidation runs
        }                                // (v1's willSet ordering pain designed out)
    }
}

final class StateBox<Value> {
    var value: Value
    var invalidate: (() -> Void)?       // bound at link time to runtime.markDirty(ownerIdentity)
}                                        // ← this closure IS the phase-2 scoped-invalidation hook

public protocol _StateProperty {        // resolver-facing seam
    var _box: AnyObject { get }
    func _adopt(_ box: AnyObject) -> Bool          // false on type mismatch → reset, don't crash
    func _bindInvalidate(_ f: @escaping () -> Void)
}
```

`StateStore` (`@MainActor`): `[NodeIdentity: [AnyObject]]`, boxes in declaration order. `link(component:at:invalidate:)` runs Mirror over the freshly constructed struct, grafts persisted boxes (or registers fresh ones on first mount), rebinds `invalidate` every render. Shape mismatch (count/type) ⇒ reset row, never crash.

**No Observation in phase 1.** For `@State`, the box owner fully determines the dirty scope (children see values via re-rendered props or `Binding` writes routed to the same box) — owner-identity dirty marking is exact; read-tracking adds nothing. Observation returns with `@Observable` model support (phase 2+), as a separate wrapper.

**Mirror hazard (critic finding 13):** `-disable-reflection-metadata` in release WASM silently breaks Mirror → every `@State` would reset each render. Mitigations, all mandatory:
(a) build config must never pass that flag (documented in the example's build instructions);
(b) startup canary in `DOMRuntime.mount`: `Mirror(reflecting: _ReflectionProbe())` must find one `_StateProperty` or `fatalError` with a clear message;
(c) the wasm example build joins CI acceptance once the toolchain is installed.

**Context threading: explicit `ResolveContext` parameter.** Not TaskLocal (v1's `@unchecked Sendable` spread), not globals. Nothing in v2 needs ambient context: `@State.init` doesn't look it up (fresh throwaway box; graft happens before `body`), handlers don't (each box carries its bound `invalidate`), only the resolver recursion needs it — one function, one parameter.

```swift
public struct ResolveContext {
    let store: StateStore
    let listeners: ListenerRegistry
    let invalidate: (NodeIdentity) -> Void
    var reachable: Set<NodeIdentity> = []       // component identities seen this pass
}
```

### Slot lifecycle (GC)

A state row lives from first `link` until a committed pass whose root is a prefix of its identity completes without visiting it: `sweep(under:reachable:)` removes rows where `id.isSelfOrDescendant(of: passRoot) && !reachable.contains(id)`. Phase 1: `passRoot == .root` (plain mark-and-sweep). The prefix rule is **already scoped-render-correct** for phase 2.

The listener registry sweeps with the same prefix rule but a **different keep-set: the set of `ListenerID`s present in the newly resolved tree** (collected during resolve or by a tree walk). NOT `ctx.reachable` — that set holds component identities only; listener owners are element paths, so using it would empty the registry every pass and kill all events after the first render. The sweep's set-difference is the future `onDisappear`/task-cancellation hook point — recorded, not implemented.

---

## 7. Resolver and render pass

```swift
@MainActor
func resolve<T: Tag>(_ tag: T, path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
    if let primitive = tag as? _PrimitiveTag { return primitive._resolve(path: path, ctx: &ctx) }
    let id = path.appending(.type(ObjectIdentifier(T.self)))
    ctx.reachable.insert(id)
    let inv = ctx.invalidate
    ctx.store.link(tag, at: id, invalidate: { inv(id) })          // graft BEFORE body
    let children = resolve(tag.body, path: id.appending(.child(0)), ctx: &ctx)
    return [.component(ComponentNode(identity: id, typeName: "\(T.self)", key: nil, children: children))]
}
```

Element `_resolve`: registers listeners as `ListenerID(owner: path, event:)` (same ID every render → registry swap, zero DOM churn), resolves content under `path + .child(0)`, emits `ElementNode(identity: path, …)`.

```swift
@MainActor
public final class Runtime<Backend: RendererBackend> {
    /// Event entry point: DOMBackend's JS closures call this with the fired
    /// ListenerID; tests call it directly to simulate clicks (§10.5).
    func dispatch(_ id: ListenerID) { listeners[id]?() }

    func markDirty(_ id: NodeIdentity) {
        assert(!isRendering, "State write during body evaluation")
        dirty.insert(id)
        if !scheduled { scheduled = true; scheduleMicrotask { self.flush() } }   // injected scheduler:
    }                                                                            // JS microtask on wasm, manual pump in tests
    func flush() {
        scheduled = false
        dirty.removeAll()          // phase 1 ignores WHICH ids are dirty — full pass from root.
        renderPass()               // phase 2 reads the set, computes minimal identity cover,
    }                              // runs one subtree pass per survivor. No API change.
    func renderPass() {
        // 1. RESOLVE + LINK (one pass)   → new tree
        // 2. SWEEP state + listeners (prefix rule, §6)
        // 3. DIFF old vs new             → ChildrenPlan / patches
        // 4. APPLY via TreeApplier<Backend>
        // 5. COMMIT (current = new)
    }
}
```

Ordering guarantees: didSet-invalidate (values final when `flush` resolves); N synchronous writes coalesce into one microtask flush; microtask is **coalescing only**, not a correctness crutch (no Observation/willSet hazard exists in this design). Mount = same pass with `current == nil`.

Phase-2 readiness checklist (all present in phase-1 types): component boundaries in the tree; `StateStore` keyed by identity, never render order; `resolve` accepts an arbitrary starting path; `markDirty` already receives precise owner identity; prefix-scoped sweep. The one phase-2 addition is internal only: `retained: [NodeIdentity: AnyTag]` so a dirty component's body can re-evaluate without re-running parents.

---

## 8. Renderer layer

Two backends, **deliberately different interfaces** (v1 discovered this empirically — its `Renderer`/`StringRendering` split was correct):

```
Tag tree ──resolve──▶ Node tree ──▶ HTMLRenderer.render(Node) → String     (pure fold: tests/SSG)
                          │
                          ▼
             Reconciler.diff(old:new:) → plan/patches                        (pure, unit-testable)
                          │
                          ▼
             TreeApplier<Backend: RendererBackend>                           (generic interpreter, owns MountedNode shadow tree)
                          ├── DOMBackend  (JSObject/JSClosure, wasm32)       ← only piece needing a browser
                          └── MockBackend (plain Swift, native tests, counts primitive calls)
```

### 8.1 RendererBackend

```swift
public protocol RendererBackend: AnyObject {
    associatedtype HostNode          // named HostNode, not Node — avoids shadowing the virtual `Node` enum
    func createElement(_ tag: String) -> HostNode
    func createTextNode(_ text: String) -> HostNode
    func setText(_ node: HostNode, _ text: String)
    func setAttribute(_ node: HostNode, name: String, value: String)
    func removeAttribute(_ node: HostNode, name: String)
    func setEventListener(_ node: HostNode, event: String, id: ListenerID)   // fire-time: dispatch(id), NEVER a captured closure
    func removeEventListener(_ node: HostNode, event: String)
    func insert(_ child: HostNode, into parent: HostNode, before anchor: HostNode?)  // nil ⇒ append
    func remove(_ child: HostNode, from parent: HostNode)
}
```

Deliberately dumb: no diffing, no bookkeeping, no handler storage. No `replaceChild` (= insert + remove). Dispatch flows out via a dispatcher injected at backend construction.

### 8.2 HTMLRenderer

Pure `Node → String` fold. Rules:
- Escaping **only here** (build-time escaping = double-escape + corrupts the DOM path — critic finding 7). One audited function `HTMLEscaping.text` for text nodes AND attribute values.
- Attributes serialized in sorted-key order (deterministic goldens).
- Void elements (13-element set: `area base br col embed hr img input link meta source track wbr`): no closing tag; children asserted empty in debug.
- Boolean attributes: `value == ""` ⇒ bare name.
- **No pretty-print.** Compact output whose parsed DOM is node-for-node identical to what `DOMBackend` builds (trap T8; hydration prerequisite). Whitespace text nodes broke v1.
- `.component` serializes as its children (transparent). Listeners ignored (hydration is phase 4+).
- Two entry points: public `HTMLRenderer.render(_ tag: some Tag) -> String` (resolves with a throwaway `StateStore`/registry — initial state values) wrapping the internal node fold `render(_ node: Node) -> String`. Stateful *sequences* are tested via `Runtime` + `MockBackend.serializeHTML()` instead (critic finding 17).

### 8.3 Reconciler

Patch-as-data (v1's "strong half", re-derived):

```swift
enum Patch {
    case setText(String)
    case setAttribute(name: String, value: String), removeAttribute(name: String)
    case setListener(event: String, id: ListenerID), removeListener(event: String)
    case replaceSelf(with: Node)
    case updateChildren(ChildrenPlan)
}

/// Desired end-state of a child list. No index-shifting insert/remove ops:
/// index-invalidation bugs (v1 H2) are unrepresentable.
struct ChildrenPlan {
    enum Slot { case reuse(oldIndex: Int, patches: [Patch]); case fresh(Node) }
    var slots: [Slot]              // new children, final order
    var removedOldIndices: [Int]   // torn down
}
```

Sameness rules:
- `.text` vs `.text`: `setText` if the strings differ, else no patch.
- Any node-kind mismatch (text/element/component) → replace.
- `.element` vs `.element`: **same `identity` ∧ same `tag`** → patch in place; else replace. (Identity on ElementNode makes if/else branch switches replace the DOM subtree, consistent with the state sweep — critic finding 12. Positional lists: a prepend shifts `.child(i)` → state resets by sweep → DOM replaces to match. Keyed items keep identity across reorder.)
- `.component` vs `.component`: same identity → recurse into children; different → replace subtree (state already swept — replacement and state reset key off the same NodeIdentity, automatically consistent).
- Keyed **components** (ForEach of custom components): match by `key` first, then the same-identity rule decides reuse vs replace (keyed identity contains `.keyed`, not positions, so reorders reuse).
- Listener diff **by ID only** (same ID ⇒ no patch even though the closure is fresh — fire-time lookup makes that safe).

Child algorithm: prefix trim → suffix trim → middle keyed-map (`[key: oldIndex]`; keyed match requires same tag; keyless match positionally among remaining keyless; else fresh). ~80 lines, snabbdom-family. **No LIS** move-minimization (pure optimization; types accommodate it later). Duplicate keys: debug assert, last-wins in release.

ForEach stamps the reconciler `key` on **every** root node of an item (multi-root items get composite `(key, i)`) — v1 stamped only the first, silently disabling keyed diff.

### 8.4 TreeApplier and the component-flattening algorithm

`MountedNode` shadow tree = the single owner of virtual-identity → host-node mapping and listener bookkeeping (kills v1's `__swev_*` expando scans and the `ObjectIdentifier(JSObject)` leak — traps T5/T10):

```swift
final class MountedNode<N> {
    var vnode: Node
    let host: N?                    // nil for component shadow nodes (transparent)
    let hostParent: N               // nearest enclosing realized element (or container at root)
    weak var parent: MountedNode<N>?   // shadow parent — needed by the anchor recursion below
    var indexInParent: Int
    var children: [MountedNode<N>]
    var events: Set<String>         // listeners installed on `host`
}
```

**Anchor algorithm** (the critic's "single riskiest unspecified piece" — normative):

```
firstHost(m):                       // depth-first first realized descendant
    if m.host != nil: return m.host
    for c in m.children: if let h = firstHost(c): return h
    return nil

anchor(parentShadow, slotIndex):    // host node before which to insert slot i's subtree
    for j in (slotIndex+1)..<parentShadow.children.count:
        if let h = firstHost(parentShadow.children[j]): return h
    if parentShadow.host != nil: return nil                      // real element: append
    return anchor(parentShadow.parent, parentShadow.indexInParent + 1)  // component: continue in enclosing scope
```

All host mutations use `insert(child, into: hostParent, before: anchor(...))`. Unmount of a component shadow node = bottom-up listener teardown walk, then remove each **top-level realized** host descendant from `hostParent` (one host removal per realized root). Flattened host order equals depth-first order of shadow-tree leaves; anchors preserve it by construction. Moves: DOM `insertBefore` on an attached node *moves* it (preserves focus/scroll/animations); children snapshots taken before move loops (live-index shift — v1 lesson).

**Application order (normative):** `applyChildren` first replaces the shadow parent's `children` array with the new slot order, then realizes/attaches slots **right-to-left** (last slot first). This guarantees that when `anchor()` scans later siblings, every already-processed sibling is attached — anchoring against the stale old order would insert after the intended position. The root of the shadow tree is a `MountedNode` **wrapping the container element (`host != nil`)**, which is also the anchor recursion's termination guarantee (the recursion stops at the first host-bearing ancestor; a nil-parent case is unreachable).

Root handling: **no fragment wrapper**. The app body resolves to `[Node]`; the user's container element is the root `hostParent`; top level is diffed as a `ChildrenPlan`. v1's "patched container instead of fragment root" bug class is unrepresentable.

### 8.5 Events end-to-end

`ListenerRegistry` (`@MainActor`): `[ListenerID: () -> Void]`. Resolve replaces entries under stable IDs; sweep uses the identity prefix rule. `DOMBackend.setEventListener` installs ONE `JSClosure` per (element, event) capturing only the `ListenerID`; fire ⇒ `dispatch(id)` ⇒ registry lookup ⇒ current closure. Re-render swaps registry entries — **zero `addEventListener`/`removeEventListener` on a normal update** (v1's accumulation bug and its tracked-removal machinery both structurally unnecessary).

JSClosure lifetime invariants:
1. Retained Swift-side (backend's dict) exactly while attached; deinit-before-invoke crashes, orphaning leaks.
2. `removeEventListener` requires the same function object — the dict keeps the instance.
3. One-shots (microtask scheduling) use `JSOneshotClosure`.
4. Bookkeeping key = monotonic int stamped on the element (`__swuid` expando, set once at creation) — never `ObjectIdentifier(JSObject)` (trap T5).

Effects never run during tree construction (trap T12) — phase 1 has no effects; the rule is recorded for phase 2.

---

## 9. Counter example (acceptance shape)

```swift
// Examples/Counter/Sources/main.swift
import SwiftWUI
import SwiftWUIDOM

struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
            if count >= 10 { P { "Double digits." } }
        }
    }
}

@main
struct CounterApp: App {
    var body: some Tag { Counter() }
}
```

---

## 10. Testing plan

All layers except ~150 lines of JSObject glue test natively (`swift test`, no browser):

1. **Reconciler** — table-driven pure tests: text/attr/bool-attr changes, listener ID stable ⇒ no patch, tag change ⇒ replace, identity change ⇒ replace, keyed append/prepend/delete/reorder, keyless positional, empty↔nonempty.
2. **The load-bearing invariant — "patch ≡ rebuild"** (MockBackend): `mount(old); apply(diff(old,new))` produces a host tree identical to `mount(new)` from scratch. Runs over the same table + nasty hand-built pairs; fuzzable later with no new infrastructure.
3. **HTMLRenderer goldens** — escaping attack strings in text/attributes, `sanitizeURL` cases (incl. `java\tscript:` control-char smuggling), void elements, boolean attrs, nesting. Port v1's `HTMLEscapingTests` as-is.
4. **Cross-check property**: after any apply, `MockBackend.serializeHTML() == HTMLRenderer.render(newTree)` — the two backends validate each other.
5. **Counter e2e native**: mount on MockBackend → `dispatch(buttonID)` → manual pump → text is `"1"`; MockBackend call counters assert **zero** listener add/remove during the update.
6. **Identity behavior specs** (transplant v1's `NestedStateIdentityTests` intent): sibling Counters independent; `if` toggle resets state; ForEach reorder keeps per-item state; parent/child single-child chains don't collide (regression for critic finding 11).
7. **Browser (non-blocking)**: manual Counter click-through + DevTools check that 100 clicks don't grow listener count. Playwright smoke later; no browser CI in phase 1.

Error handling posture: `assert` for programmer errors in debug (state write during render, duplicate ForEach ids, void-element children, invalid attribute names), degrade gracefully in release (reset state row on shape mismatch, drop invalid attribute, last-wins keys). `fatalError` only for the Mirror canary (§6) and unreachable `Never` bodies.

---

## 11. Security requirements (normative, carried from v1's audited Phase-0 work)

1. **Single escaping choke point**: one `HTMLEscaping` enum; every string sink routes through it. Port v1's implementation near-verbatim (it survived a security review): `text(_:)` escapes `& < > " '` (text nodes AND attribute values); `scriptJSON(_:)` (`<`,`>`,U+2028/9); `rawTextElement(_:)` (`</` → `<\/`); `cssToken(_:)`; `sanitizeURL(_:)` (scheme allowlist `http https mailto tel ftp`, strip ASCII controls before scheme detection, else `#`).
2. `sanitizeURL` applied in `A`/`Img` inits, not the renderer.
3. Attribute-name validation `[a-zA-Z_:][a-zA-Z0-9_.:-]*` in `_AttributeBag.set`.
4. `scriptJSON`/`rawTextElement` ship (audited) even though phase 1 has no raw-text elements; no generic raw-text path may be added without them.
5. Never `innerHTML` for user content anywhere in the framework.

---

## 12. Explicitly deferred (add when)

- Event payloads / `onInput` / controlled inputs → phase 2 (typed `(EventPayload) -> Void`, decoded in backend; **never** process-global payload slots).
- `.on()/.data()/.aria()` helpers → phase 2 (with the modifier-system decision).
- Component-scoped invalidation → phase 2 (internal change; hooks in place per §7).
- Observation/`@Observable` models, `@Environment`, `onChange`, `task` → phase 2.
- LIS move-minimization, rAF batching, pretty-print, identity-hash caching, macro-generated tags → when profiling/need demands.
- Router, Page metadata → phase 4. SSG entry point → phase 5 (HTMLRenderer already is the mechanism).

## 13. Toolchain

- Swift **6.3.3** host toolchain (swiftly; 6.3.2 currently installed — upgrade) + official Swift.org WASM SDK `swift-6.3.3-RELEASE_wasm`. **Host and SDK versions must match exactly.** As of 2026-07-02 no SDK is installed (`swift sdk list` empty) — installation is an implementation-plan step; the native test gate never blocks on it.
- JavaScriptKit latest (≥ 0.22); Vite dev server for the wasm example (`@bjorn3/browser_wasi_shim`).
- `#if arch(wasm32)` for runtime behavior forks, never `canImport(JavaScriptKit)` (trap T18). No identity/ID logic behind platform conditionals (trap T9).

## 14. Resolved design questions (decision log)

| # | Question | Decision |
|---|----------|----------|
| 1 | Event handler ownership | Registry model (identity architect); closures never in the node tree; no `Sendable` |
| 2 | Invalidation mechanism | didSet → `markDirty` → microtask coalesce; **no Observation in phase 1** |
| 3 | Node type unification | `Node`/`NodeKey`/`ComponentNode` (identity architect); applier handles components via anchor algorithm §8.4 |
| 4 | `_PrimitiveTag` shape | `_resolve(path:ctx:) -> [Node]` |
| 5 | Attribute storage | ordered bag → dict, last-wins except `class` appends |
| 6 | Handler signatures | `() -> Void` only in phase 1 |
| 7 | Escaping location | serializer-only; raw strings in the tree |
| 8 | `EventName` | public API type; raw strings internally |
| 9 | ForEach id | public `KeyPath` inits |
| 10 | Sendable | none in the pipeline |
| 11 | Path collision | element content always descends `.child(0)` |
| 12 | Element replacement semantics | `identity` stamped on `ElementNode`; same identity ∧ tag ⇒ patch, else replace |
| 13 | Mirror in release WASM | canary + build-flag prohibition + wasm CI acceptance |
| 14 | `Tag` vs `Testing.Tag` | keep `Tag`; test-support alias |
| 15 | `Array` identity | slot + `.child(i)`, positional, documented |
| 16 | App-level `@State` | unsupported in phase 1, documented |
| 17 | HTMLRenderer state entry | throwaway store; stateful sequences via MockBackend |
| 18 | Adjacent text nodes | coalesced at resolve time |
| 19 | Attribute-name injection | validated in `_AttributeBag` |
| 20 | Browser demo risk | native MockBackend e2e is the phase-1 gate |
| 21 | Listener sweep keep-set | `ListenerID`s present in the newly resolved tree — never `ctx.reachable` (component ids only; would empty the registry) |
| 22 | ChildrenPlan application order | shadow children updated to new order first; slots realized right-to-left; root shadow node wraps the container (`host != nil`) |
