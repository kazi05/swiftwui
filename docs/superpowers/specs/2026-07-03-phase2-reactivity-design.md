# SwiftWUI v2 — Phase 2 Reactivity Design

Status: approved design (brainstorm 2026-07-03). Implements roadmap phase 2 on top of the
phase-1 core (`docs/superpowers/specs/2026-07-02-phase1-core-design.md`). Work continues on
`feature/fable-new-vision`.

## 1. Context and scope

Phase 1 shipped the vertical slice: Tag/@TagBuilder, structural identity in the tree, @State
with graftable boxes, ListenerRegistry, Reconciler + TreeApplier, HTMLRenderer, DOMBackend,
Counter acceptance. Every phase-2 hook it promised is in place: precise owner identity in
`markDirty`, prefix-scoped sweeps, `resolve` from an arbitrary path, component boundaries in
the node tree.

**In (this spec):**
- Component-scoped invalidation (dirty set → minimal cover → subtree passes)
- `@Observable` model support via Swift Observation + `@Bindable`
- `@Environment` (EnvironmentKey / EnvironmentValues / `.environment(_:_:)`)
- Effects: `.onChange(of:)`, `.task {}` / `.task(id:)`, `.onAppear {}` / `.onDisappear {}`
- Typed event payloads decoded in the backend; generic `.on(_:perform:)` escape hatch
- Controlled inputs (`Input(value:)`, `Input(checked:)`, `Textarea(text:)`) via DOM properties
- Review backlog: replaceSelf-in-reuse assert, `MountedNode.vnode` cleanup, `@MainActor` on
  `Tag`, `.attribute()` sanitize documentation
- TodoMVC acceptance example (wasm + Vite)

**Out (deferred, §12):** style modifiers / typed CSS (phase 3, per roadmap decision
2026-07-03), router/Page (phase 4), SSG entry point (phase 5), `@Environment(Model.self)`
type-keyed lookup, Combine-style `onReceive`, animations/transactions.

Approach decision: **SwiftUI-faithful** (option A of the brainstorm) — stock Observation,
keypath Environment, typed payload structs, scoped invalidation now.

## 2. Scoped invalidation

### 2.1 Retained components

The resolver records, for every component it resolves:

```swift
struct RetainedComponent {
    var tag: AnyTag                      // struct as constructed by the parent's last render
    var environment: EnvironmentValues   // snapshot the component was resolved under
}
// StateStore gains: retained: [NodeIdentity: RetainedComponent]
```

Props inside `tag` are from the parent's most recent render. If the parent did not re-render,
its props did not change — SwiftUI semantics, exact by construction. `retained` rows are swept
together with state rows (same prefix rule, same `reachable` set).

### 2.2 Flush

```swift
func flush() {
    scheduled = false
    guard !dirty.isEmpty else { return }
    let survivors = minimalCover(dirty)   // drop ids that are descendants of other dirty ids
    dirty.removeAll()
    for id in survivors {
        guard let row = store.retained[id] else { continue }  // removed by an earlier
        subtreePass(id, row)                                   // survivor this flush — skip
    }
}
```

`minimalCover` uses the existing `NodeIdentity.isSelfOrDescendant(of:)`. Root dirt (or
`current == nil`) degenerates to the phase-1 full pass — same code path with `passRoot == .root`.

### 2.3 Subtree pass

For survivor `X` with retained row `(tag, env)`:

1. **RESOLVE + LINK** — `resolve(tag, path: parent(X), ctx)` with `ctx.environment = env`.
   `resolve` re-appends the `.type` segment itself, so it is called with X's parent path.
2. **SWEEP** — `store.sweep(under: X, reachable:)`, `listeners.sweep(under: X, keep:)`,
   `effects` reconcile under X (§5.4). Prefix rule already supports non-root `passRoot`.
3. **DIFF** — old subtree of X (located in `current` by identity path) vs new subtree.
4. **APPLY** — patches go to X's `MountedNode`. TreeApplier maintains
   `mountedIndex: [NodeIdentity: MountedNode]` for **component** nodes, updated on
   mount/unmount; the subtree pass looks up `mountedIndex[X]`.
5. **COMMIT** — splice the new subtree into `current` at X's path (value tree,
   copy-on-write descent along identity segments).
6. **EFFECTS** — run the post-commit queue (§5.3).

### 2.4 Invariant (normative)

After any scoped pass, `current`, the mounted tree, the state store, the listener registry and
the effect store are **byte-for-byte identical** to what a full pass from root would have
produced. This is the primary property test (§10).

Edge cases: `markDirty` during apply or effects → normal path, next microtask flush. A dirty
id whose component vanished → skipped via the `retained` guard.

## 3. @Observable models and @Bindable

### 3.1 Tracking

Stock Swift Observation (stdlib; proven on wasm by v1). The resolver wraps every component
body evaluation:

```swift
let body = withObservationTracking {
    tag.body                              // reads of @Observable properties are recorded
} onChange: { [invalidate] in
    invalidate(componentID)               // fires at willSet, one-shot
}
```

- **Precision:** only components whose body actually read the mutated property get dirty.
  Granularity is per property, not per object.
- **willSet hazard closed by construction:** `onChange` fires before the new value is written,
  but `markDirty` only inserts an id and schedules a microtask — by flush time the value is
  final. N synchronous writes coalesce exactly like @State writes.
- **Re-arm:** tracking is one-shot; every re-render re-wraps the body. No registrar
  bookkeeping.
- **Stale fires:** a removed component's tracking may still fire once → `markDirty` of a dead
  id → flush skips it (no `retained` row). Harmless, tested.

Model ownership is orthogonal: `@State var store = TodoStore()` (box persistence already
works — the box holds the reference), a prop, or an environment value. Tracking catches reads
from any source.

### 3.2 @Bindable

Sugar producing bindings into observable models (TodoMVC: `Input(value: $store.draft)`):

```swift
@propertyWrapper @dynamicMemberLookup
public struct Bindable<Value: AnyObject & Observable> {
    public var wrappedValue: Value
    public var projectedValue: Bindable<Value> { self }
    public subscript<T>(dynamicMember kp: ReferenceWritableKeyPath<Value, T>) -> Binding<T> {
        Binding(get: { wrappedValue[keyPath: kp] },
                set: { wrappedValue[keyPath: kp] = $0 })   // Observation reports the write
    }
}
```

No runtime integration: the Binding writes into the model; Observation notifies readers.

**Not building:** custom observation protocol/macro; read-tracking outside `body` (handlers
and effects don't need it).

## 4. @Environment

SwiftUI-shaped, keypath-based:

```swift
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}
// User extension pattern (documented):
// extension EnvironmentValues { var theme: Theme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } } }

@propertyWrapper
public struct Environment<Value> {
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>)
    public var wrappedValue: Value    // (snapshot ?? EnvironmentValues())[keyPath: kp]
}

extension Tag {
    public func environment<V>(_ kp: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some Tag
}
```

**Threading.** `ResolveContext` gains `var environment: EnvironmentValues`. `.environment()`
returns the primitive wrapper `_EnvironmentWriter`: save `ctx.environment`, apply the write,
resolve content, restore (ctx is already `inout`; plain var save/restore).

**Injection.** The same Mirror pass that grafts @State: `StateStore.link` gains an
`environment:` parameter and fills a new seam before `body` runs:

```swift
public protocol _EnvironmentProperty { func _inject(_ values: EnvironmentValues) }
```

The wrapper holds `(keyPath, snapshot: EnvironmentValues?)`; reads resolve the keypath against
the snapshot, falling back to defaults when constructed outside the runtime. One Mirror pass
per component, not two.

**Identity.** `_EnvironmentWriter` is a structural descent → appends exactly one segment:
`.type(ObjectIdentifier(_EnvironmentWriter<V>.self))` (rule "every descent appends exactly one
segment" preserved; no new segment kind — decision D3).

**Scoped re-render correctness.** The `RetainedComponent.environment` snapshot (§2.1) is what
makes subtree passes see the right values. A *changed* environment value always arrives via a
re-render of the writer (the parent re-rendered to call `.environment` with a new value), so
snapshots can never go stale.

Observable objects placed in the environment compose for free: body reads a model property →
§3 tracking catches it.

## 5. Effects: onChange, task, onAppear/onDisappear

### 5.1 API

```swift
extension Tag {
    public func onChange<V: Equatable>(of value: V, initial: Bool = false,
                                       _ action: @escaping (V, V) -> Void) -> some Tag  // (old, new)
    public func task(_ action: @escaping () async -> Void) -> some Tag
    public func task<ID: Equatable>(id: ID, _ action: @escaping () async -> Void) -> some Tag
    public func onAppear(_ action: @escaping () -> Void) -> some Tag
    public func onDisappear(_ action: @escaping () -> Void) -> some Tag
}
```

### 5.2 Resolve-time behavior

Wrappers are primitives (`_OnChangeEffect`, `_TaskEffect`, `_AppearEffect`,
`_DisappearEffect`), each appending one `.type(...)` identity segment (as §4). Resolving one
**executes nothing** (trap T12) — it appends an `EffectRequest` (carrying its identity, kind,
erased values, comparison closure, action) to `ctx.effects` and resolves its content.

### 5.3 Post-commit reconcile

`renderPass`/`subtreePass` step 6 feeds requests to the new `EffectStore` (`@MainActor`,
keyed by wrapper identity):

```
reconcile(requests, under: passRoot):
  removed  = stored ids under passRoot − requested ids     // set difference
  for removed: cancel stored Task; run stored onDisappear action
  for requests, in document (resolve) order:
    onChange: old = store[id]
              if old == nil && initial          → queue action(new, new)
              else if let old, old != new       → queue action(old, new)
              store[id] = new
    task:     first appearance                  → start Task { await action() }, store handle
              task(id:) with changed id         → cancel old, start new
    appear:   first appearance                  → queue action
    disappear: store action for later removal
  run queue                                     // synchronously, after COMMIT
```

Ordering (normative): disappear/cancellation first, then appear/task/onChange in document
order. Effects run after COMMIT within the same microtask; state writes inside an effect go
through `markDirty` → next microtask flush. Effects never run during resolve/diff/apply.

### 5.4 Cancellation = sweep

`EffectStore` rows follow the prefix rule like state rows; a scoped pass reconciles only under
its `passRoot`. Removal cancels the Task cooperatively — effect bodies must survive
`CancellationError` (documented). This is the "onDisappear hook point" recorded in phase 1 §6,
now implemented.

### 5.5 Async runtime

wasm: `JavaScriptEventLoop.installGlobalExecutor()` once in `DOMRuntime.mount`, before first
render. Native: plain MainActor executor; tests pump tasks manually.

## 6. Typed event payloads

Payload structs, decoded **only in the backend** (phase-1 normative rule; never process
globals — trap T4):

```swift
public struct InputEvent  { public let value: String }
public struct ChangeEvent { public let value: String; public let checked: Bool }
public struct KeyEvent    { public let key: String; public let repeated: Bool }
public struct SubmitEvent {}     // backend always calls preventDefault() for submit (documented)
public struct FocusEvent  {}     // focus / blur
public struct GenericEvent {     // escape-hatch payload for .on(_:perform:)
    public let type: String
    public let targetValue: String?
    public let key: String?
    public let checked: Bool?
}
```

**Registry.** `ListenerRegistry` stores `(Any?) -> Void` internally; typed registration seams
wrap the cast. Void handlers (`Button("+") { }`) keep working unchanged. Dispatch becomes:

```swift
public func dispatch(_ id: ListenerID, payload: Any? = nil)
```

Tests construct payloads by hand and call `dispatch` directly. `DOMBackend`'s per-(element,
event) `JSClosure` reads the JS event's fields at fire time (`target.value`, `key`, …) into
the matching struct via a static event-name → decoder table, then calls `dispatch`. Payload
type mismatch at the handler: drop + `assertionFailure` in debug (§11).

**Tag API** — typed init params, phase-1 hybrid style:

```swift
Input(type: .text, value: $store.draft, onKeyDown: { e in if e.key == "Enter" { store.add() } })
Input(type: .checkbox, checked: $todo.done)
Textarea(text: $draft)
Form(onSubmit: { _ in ... }) { ... }
Button("×") { store.remove(todo) }        // () -> Void unchanged
```

**Escape hatch** at the attribute-bag level (identity-transparent, like `.style()`):

```swift
.on(.dblclick) { (e: GenericEvent) in store.startEditing(todo) }
```

Owner is the element path + event name — the existing `ListenerID` scheme; zero listener churn
property preserved.

## 7. Controlled inputs

`value:` / `checked:` / `text:` take a `Binding`. Mechanics:

1. The resolver auto-registers the matching listener (`input` for value/text, `change` for
   checked) that writes the binding.
2. `ElementNode` gains `properties: [String: PropertyValue]` — DOM **properties**, distinct
   from attributes: `enum PropertyValue: Equatable { case string(String), bool(Bool) }`.
3. `RendererBackend` gains `func setProperty(_ node: HostNode, name: String, value: PropertyValue)`.
   `DOMBackend` writes only when the current DOM value differs (guard inside the backend — no
   protocol-level read needed; preserves cursor/selection). `MockBackend` records the call.
4. `Reconciler` diffs `properties` exactly like attributes → property patches.
5. `HTMLRenderer` serializes properties to their attribute forms for initial/SSG HTML:
   `value` → `value="…"` (escaped via the existing choke point), `checked: true` → bare
   `checked`. Phase 5 SSG inherits this for free.

Data cycle: input → event → binding write → `markDirty(owner)` → flush → property write
(equal by then ⇒ DOM no-op). No echo loop by construction.

## 8. Review backlog (phase-1 carry-over)

1. **replaceSelf-in-reuse assert** → handle the case correctly instead of asserting
   (reconciler emits replace for a reused component slot; applier must rebuild in place).
2. **`MountedNode.vnode` cleanup** — remove the unused field (nothing reads it; the node
   tree is the source of truth).
3. **`Textarea(text:)`** — closed by §7.
4. **`@MainActor` on `Tag`** — annotate the protocol so component `body` is MainActor-isolated
   and can call MainActor API without ceremony. Aligns with the all-@MainActor pipeline.
5. **`.attribute()` sanitize escape-hatch** — documentation only: URL/event-name attributes
   pass the existing sanitizer; `.attribute()` is the documented raw bypass, caller's
   responsibility.

## 9. TodoMVC acceptance (`Examples/TodoMVC`)

wasm + Vite, same harness as phase-1 Counter. Exercises every feature:

- add via `Input(value:onKeyDown:)` on Enter — controlled input + `KeyEvent`
- toggle via `Input(type: .checkbox, checked:)` — binding + `ChangeEvent`
- edit on `.on(.dblclick)` — escape hatch
- All/Active/Completed filters — `@State` + keyed `ForEach`
- `@Observable final class TodoStore` — model; "N items left" counter reads the store from
  `@Environment`
- `.task {}` — simulated async initial load
- `.onChange(of: filter)` — visible side effect (e.g. document title)

**Invalidation acceptance:** toggling one todo does not re-evaluate sibling rows' bodies
(body-evaluation counters in the native test).

## 10. Testing plan

Native-first via MockBackend + Runtime (phase-1 pattern); browser run is acceptance only.

- **Property test (primary):** scoped pass ≡ full pass from root (§2.4) — random trees,
  random dirty sets; compare `current`, mounted tree, store/registry/effect contents.
- Observation: model write dirties exactly the readers; re-arm after re-render; stale
  onChange fire is harmless.
- Environment: save/restore nesting, retained snapshots drive subtree passes, defaults when
  unset, injection before body.
- Effects: post-commit ordering, task cancel on sweep, `task(id:)` restart, onChange old/new
  pairs, `initial:`, no effect runs during resolve (asserted via EffectStore).
- Events: typed dispatch, decoder-table coverage (unit-level, native), controlled-input echo
  (property write is a DOM no-op after binding write).
- Sweep regressions: scoped passes never touch state/listeners/effects outside their prefix.
- Body-evaluation counters: fixtures count `body` calls to assert invalidation scope (§9).

## 11. Error handling

- StateStore shape mismatch: phase-1 rule unchanged — reset row, never crash.
- Payload type mismatch (handler expects `InputEvent`, got other): drop the event;
  `assertionFailure` in debug builds.
- Task cancellation is cooperative; effect bodies must tolerate `CancellationError`
  (documented; the runtime never force-kills).
- Dirty id with no retained row: skip silently (legitimate: removed earlier in the same flush).

## 12. Explicitly deferred

- Style modifiers, typed CSS (`.margin(.top, .px(44))`), `Style` protocol, themes, media
  queries → **phase 3** (confirmed 2026-07-03; phase 2's wrapper-modifier identity rules are
  the architecture styles will plug into).
- `@Environment(Model.self)` type-keyed lookup → phase 3+.
- Router, `Page` → phase 4. SSG entry point → phase 5 (§7's property serialization feeds it).
- `onReceive`/Combine, animations, transactions → not planned.
- LIS move minimization, rAF batching → when profiling demands (unchanged from phase 1).

## 13. Decision log

| # | Question | Decision |
|---|----------|----------|
| D1 | Overall approach | SwiftUI-faithful (stock Observation, keypath Environment, typed payloads, scoped invalidation now) |
| D2 | Scoped re-render source of truth | `retained: [NodeIdentity: RetainedComponent]` (tag + environment snapshot), swept with state rows |
| D3 | Wrapper identity segments | reuse `.type(ObjectIdentifier)` — one segment per descent, no new segment kind |
| D4 | Observation wiring | `withObservationTracking` around each component body; onChange → `markDirty(owner)`; microtask flush closes the willSet hazard |
| D5 | Environment injection | same Mirror pass as @State grafting (`link` gains `environment:`), `_EnvironmentProperty` seam |
| D6 | Effect execution point | post-COMMIT queue, same microtask; disappear/cancel first, then document order (T12 upheld) |
| D7 | Effect lifecycle | EffectStore keyed by wrapper identity; sweep set-difference = onDisappear/cancellation |
| D8 | Payload transport | typed structs decoded in DOMBackend at fire time; registry stores `(Any?) -> Void`; `dispatch(_:payload:)` |
| D9 | Controlled inputs | DOM properties (`ElementNode.properties`), backend-internal equality guard, auto-registered binding listener |
| D10 | `onSubmit` | backend always `preventDefault()` (documented) |
| D11 | Generic events | `.on(_:perform:)` bag-level with `GenericEvent`; identity-transparent |
| D12 | Lifecycle modifiers | `onAppear`/`onDisappear` included — machinery required by `task` anyway |
| D13 | Async executor | `JavaScriptEventLoop.installGlobalExecutor()` in `DOMRuntime.mount` (wasm only) |
| D14 | Acceptance app | TodoMVC (single example; async simulated via `.task`) |
| D15 | Branch strategy | continue on `feature/fable-new-vision`; no merge before phase 2 |

## 14. Post-review addenda (2026-07-03, final whole-branch review)

- **D6 clarification:** within a multi-survivor flush, effects run per subtree
  pass (after that pass's commit), not batched after all passes. Effects may
  observe intermediate DOM states a single full pass would not produce; final
  states converge.
- **Known limitation (fix in phase 3):** @Observable reads inside ForEach row
  closures are not tracked (they execute outside the component body's tracking
  window). Constraint: reads belong in a component's `body`; ForEach rows that
  read models must be components. Phase 3 threads tracking through primitive
  content resolution.
- **Constraint:** @Observable model writes must occur on the main actor;
  off-main writes trap in the invalidation path by design (all-@MainActor
  pipeline).
- Same-event handlers on one element compose in registration order (auto-
  registered controlled-input writers first, then `.on(...)` handlers).
