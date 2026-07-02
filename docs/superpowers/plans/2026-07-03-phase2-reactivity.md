# SwiftWUI Phase 2 Reactivity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the phase-2 reactivity spec (`docs/superpowers/specs/2026-07-03-phase2-reactivity-design.md`): scoped invalidation, @Observable/@Bindable, @Environment, effects (onChange/task/onAppear/onDisappear), typed event payloads, controlled inputs, review-backlog cleanup, TodoMVC acceptance.

**Architecture:** Everything extends the phase-1 pipeline (resolve → sweep → diff → apply → commit) without changing its shape. New wrapper primitives append one `.type` identity segment each. Payloads are decoded only in the backend. Effects run only post-commit. Scoped passes must be byte-identical to full passes (primary property test).

**Tech Stack:** Swift 6.3.3 (host) + `swift-6.3.3-RELEASE_wasm` SDK, JavaScriptKit ≥ 0.22 (already pinned), Swift Testing (`import Testing`), stock Observation (stdlib).

**Testing workflow (user preference, overrides RED/GREEN step cycling):** per task — write ALL test code first, write ALL implementation code, run the full suite ONCE at the end, fix, commit. No intermediate test runs unless debugging.

## Global Constraints

- Toolchain: Swift **6.3.3** host + `swift-6.3.3-RELEASE_wasm` SDK; versions must match exactly.
- **Never** pass `-disable-reflection-metadata` (breaks Mirror → silently resets all @State).
- No new package dependencies. (`JavaScriptEventLoop` is a product of the already-pinned JavaScriptKit package — allowed.)
- `#if arch(wasm32)` for runtime forks; never `canImport(JavaScriptKit)`.
- Whole pipeline `@MainActor` (module has `.defaultIsolation(MainActor.self)`); no `Sendable` in public pipeline API.
- Escaping only in serializers (`HTMLEscaping` choke point). Payloads decoded only in the backend, never process globals.
- Effects never run during resolve/diff/apply — post-commit only (trap T12).
- Primary gate: native `swift test` — all pre-existing 83 tests plus new ones stay green after every task. Secondary gate (tasks 10–11): `swift build --swift-sdk swift-6.3.3-RELEASE_wasm`.
- Code, commits, docs in English. Commit style: `feat(scope): …` / `fix(scope): …` matching phase-1 history.
- Every commit ends with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Backlog hygiene (@MainActor Tag, vnode removal, replaceSelf assert, .attribute docs)

**Files:**
- Modify: `Sources/SwiftWUI/Core/Tag.swift` (protocol `Tag`)
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift` (MountedNode init, `apply` setText case, `replace`)
- Modify: `Sources/SwiftWUI/HTML/HTMLTag.swift` (doc comment on `attribute(_:_:)`)
- Test: `Tests/SwiftWUITests/ApplierRegressionTests.swift` (append)

**Interfaces:**
- Consumes: existing `MountedNode<N>`, `TreeApplier`, `Tag`.
- Produces: `@MainActor public protocol Tag`; `MountedNode` WITHOUT `vnode` (its init becomes `init(host: N?, hostParent: N)`); all later tasks assume this shape.

- [ ] **Step 1: Write tests**

Append to `ApplierRegressionTests.swift`:

```swift
// M2 (phase-1 review): replaceSelf inside a reuse slot must be unreachable —
// sameIdentity() gates every reuse, and diff() only emits replaceSelf when
// identity/tag mismatch. Pin the two mismatch shapes as fresh+removed plans.
@Test func mismatchProducesFreshNotReplaceSelf() {
    let r = Reconciler()
    let oldE = Node.element(ElementNode(identity: .root.appending(.child(0)), tag: "div",
                                        attributes: [:], listeners: [:], children: [], key: nil))
    let newE = Node.element(ElementNode(identity: .root.appending(.child(0)), tag: "span",
                                        attributes: [:], listeners: [:], children: [], key: nil))
    let plan = r.diffChildren(old: [oldE], new: [newE])
    // tag change at same identity → NOT a reuse slot
    guard case .fresh = plan.slots[0] else { Issue.record("expected fresh slot"); return }
    #expect(plan.removedOldIndices == [0])
}

@Test func textToElementProducesFreshNotReplaceSelf() {
    let r = Reconciler()
    let newE = Node.element(ElementNode(identity: .root.appending(.child(0)), tag: "div",
                                        attributes: [:], listeners: [:], children: [], key: nil))
    let plan = r.diffChildren(old: [.text("x")], new: [newE])
    guard case .fresh = plan.slots[0] else { Issue.record("expected fresh slot"); return }
    #expect(plan.removedOldIndices == [0])
}
```

- [ ] **Step 2: Implementation**

2a. `Tag.swift` — annotate the protocol (body becomes MainActor-isolated; the module already default-isolates, so this only changes the *public contract* for downstream users):

```swift
@MainActor
public protocol Tag {
    associatedtype Body: Tag
    @TagBuilder var body: Body { get }
}
```

Keep `Never: Tag` and `_PrimitiveTag` as they are (the `@MainActor` on `_resolve` requirements is now redundant but harmless — leave existing annotations untouched).

2b. `TreeApplier.swift` — remove the dead `vnode` field (written, never read):
- Delete `var vnode: Node` and the `vnode:` init parameter; init becomes `init(host: N?, hostParent: N)`.
- Update all `MountedNode(vnode: …, host: …, hostParent: …)` construction sites (three in `mount`, one in `TreeApplier.init` for `root`).
- In `apply`, case `.setText`: delete the `m.vnode = .text(s)` line, keep `backend.setText(m.host!, s)`.

2c. `TreeApplier.replace` — document reachability (review item M2):

```swift
private func replace(_ m: MountedNode<Backend.HostNode>, with new: Node,
                     endAnchor: Backend.HostNode?? = nil) {
    // Reachable ONLY from a top-level diff of same-position roots (renderPass /
    // subtree pass). diffChildren never emits replaceSelf into a reuse slot:
    // sameIdentity() gates reuse, and diff() emits replaceSelf only on
    // identity/tag mismatch (pinned by ApplierRegressionTests).
    guard let parent = m.parent else { preconditionFailure("replace at shadow root") }
    …existing body unchanged…
}
```

2d. `HTMLTag.swift` — doc comment on the escape hatch (review item M1):

```swift
/// Raw attribute escape hatch. The NAME is validated ([a-zA-Z_:][a-zA-Z0-9_.:-]*,
/// spec §11); the VALUE is escaped only at serialization time like every other
/// attribute. No URL/scheme sanitization is applied — attributes like `href`
/// set through this API are the caller's responsibility.
public func attribute(_ name: String, _ value: String?) -> Self {
```

- [ ] **Step 3: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass (83 pre-existing + 2 new).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "chore(core): phase-1 review backlog — @MainActor Tag, drop dead MountedNode.vnode, pin replaceSelf unreachability, document .attribute()"
```

---

### Task 2: Typed event payload pipeline

**Files:**
- Create: `Sources/SwiftWUI/HTML/EventPayloads.swift`
- Modify: `Sources/SwiftWUI/HTML/EventName.swift`
- Modify: `Sources/SwiftWUI/Runtime/ListenerRegistry.swift`
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (`dispatch`)
- Modify: `Sources/SwiftWUI/HTML/AttributeBag.swift` (handler storage)
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (`resolveElement` registration)
- Modify: `Sources/SwiftWUI/HTML/HTMLTag.swift` (`.on(_:perform:)`)
- Test: `Tests/SwiftWUITests/EventPayloadTests.swift` (new)

**Interfaces:**
- Consumes: `ListenerID`, `EventName`, `_AttributeBag`, `Runtime.dispatch`.
- Produces (later tasks rely on these exact shapes):
  - `public struct InputEvent { public let value: String; public init(value:) }`
  - `public struct ChangeEvent { public let value: String; public let checked: Bool; public init(value:checked:) }`
  - `public struct KeyEvent { public let key: String; public let repeated: Bool; public init(key:repeated:) }`
  - `public struct SubmitEvent { public init() }`, `public struct FocusEvent { public init() }`
  - `public struct GenericEvent { public let type, targetValue, key, checked …; public init(type:targetValue:key:checked:); init(type:payload:) }`
  - `Runtime.dispatch(_ id: ListenerID, payload: Any? = nil)`
  - `_AttributeBag.addHandler(_ event:, payload: P.Type, _ action: (P) -> Void)` and `addRawHandler(_ event:, _ action: (Any?) -> Void)`
  - `ListenerRegistry.set(_ id:, payloadHandler: @escaping (Any?) -> Void)` and `handler(for:) -> ((Any?) -> Void)?`

- [ ] **Step 1: Write tests** (`Tests/SwiftWUITests/EventPayloadTests.swift`)

```swift
import Testing
@testable import SwiftWUI

private final class Capture { var inputs: [String] = []; var keys: [String] = []
                              var generic: [GenericEvent] = []; var voids = 0 }

private struct PayloadFixture: Tag {
    let cap: Capture
    var body: some Tag {
        Div {
            Input(type: .text)
                .on(.input) { cap.generic.append($0) }
            Button("b") { cap.voids += 1 }
        }
    }
}

@MainActor @Suite struct EventPayloadTests {
    @Test func typedHandlerReceivesPayload() {
        var bag = _AttributeBag()
        var got: [InputEvent] = []
        bag.addHandler(.input, payload: InputEvent.self) { got.append($0) }
        bag.handlers[0].action(InputEvent(value: "hi"))
        #expect(got.map(\.value) == ["hi"])
    }

    // NOTE (no test): payload type mismatch → assertionFailure in debug, drop in
    // release (spec §11). assertionFailure is untestable from Swift Testing in a
    // debug build (it traps the process) — the contract is pinned by this comment
    // and the guard in _AttributeBag.addHandler(payload:).

    @Test func voidHandlersStillWork() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let cap = Capture()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: PayloadFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        let button = findFirst(backend.container, tag: "button")!
        rt.dispatch(button.events["click"]!)                 // no payload
        #expect(cap.voids == 1)
    }

    @Test func onEscapeHatchWrapsAnyPayloadIntoGenericEvent() {
        let backend = MockBackend()
        let sched = TestScheduler()
        let cap = Capture()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: PayloadFixture(cap: cap), scheduleMicrotask: sched.schedule)
        rt.mount()
        let input = findFirst(backend.container, tag: "input")!
        rt.dispatch(input.events["input"]!, payload: InputEvent(value: "abc"))
        #expect(cap.generic.count == 1)
        #expect(cap.generic[0].type == "input")
        #expect(cap.generic[0].targetValue == "abc")
    }
}
```

- [ ] **Step 2: Implementation**

2a. `EventName.swift` — add constants:

```swift
public static let input: EventName = "input"
public static let change: EventName = "change"
public static let keydown: EventName = "keydown"
public static let keyup: EventName = "keyup"
public static let submit: EventName = "submit"
public static let focus: EventName = "focus"
public static let blur: EventName = "blur"
public static let dblclick: EventName = "dblclick"
```

2b. `EventPayloads.swift` (new):

```swift
/// Typed event payloads (spec §6). Decoded ONLY in the backend at fire time
/// (trap T4: never process-global payload slots).
public struct InputEvent  { public let value: String
                            public init(value: String) { self.value = value } }
public struct ChangeEvent { public let value: String; public let checked: Bool
                            public init(value: String, checked: Bool) { self.value = value; self.checked = checked } }
public struct KeyEvent    { public let key: String; public let repeated: Bool
                            public init(key: String, repeated: Bool) { self.key = key; self.repeated = repeated } }
public struct SubmitEvent { public init() {} }   // backend always preventDefault()s submit (spec D10)
public struct FocusEvent  { public init() {} }

/// Escape-hatch payload for `.on(_:perform:)` — common fields of any event.
public struct GenericEvent {
    public let type: String
    public let targetValue: String?
    public let key: String?
    public let checked: Bool?
    public init(type: String, targetValue: String?, key: String?, checked: Bool?) {
        self.type = type; self.targetValue = targetValue; self.key = key; self.checked = checked
    }
    /// Adapts whatever typed payload arrived for `type` into the generic shape.
    init(type: String, payload: Any?) {
        switch payload {
        case let e as InputEvent:   self.init(type: type, targetValue: e.value, key: nil, checked: nil)
        case let e as ChangeEvent:  self.init(type: type, targetValue: e.value, key: nil, checked: e.checked)
        case let e as KeyEvent:     self.init(type: type, targetValue: nil, key: e.key, checked: nil)
        case let e as GenericEvent: self.init(type: type, targetValue: e.targetValue, key: e.key, checked: e.checked)
        default:                    self.init(type: type, targetValue: nil, key: nil, checked: nil)
        }
    }
}
```

2c. `ListenerRegistry.swift` — erased storage, both registration seams:

```swift
@MainActor
public final class ListenerRegistry {
    private var handlers: [ListenerID: (Any?) -> Void] = [:]
    public init() {}

    func set(_ id: ListenerID, handler: @escaping () -> Void) { handlers[id] = { _ in handler() } }
    func set(_ id: ListenerID, payloadHandler: @escaping (Any?) -> Void) { handlers[id] = payloadHandler }
    func handler(for id: ListenerID) -> ((Any?) -> Void)? { handlers[id] }
    // sweep(under:keep:) and count unchanged
}
```

2d. `Runtime.swift`:

```swift
public func dispatch(_ id: ListenerID, payload: Any? = nil) {
    listeners.handler(for: id)?(payload)
}
```

(`DOMRuntime`'s `box.fn: (ListenerID) -> Void` keeps compiling via the default — the wasm backend passes real payloads in Task 10.)

2e. `AttributeBag.swift` — erased handler storage + typed wrapper:

```swift
private(set) var handlers: [(event: EventName, action: (Any?) -> Void)] = []

mutating func addHandler(_ event: EventName, _ action: @escaping () -> Void) {
    handlers.append((event, { _ in action() }))
}
mutating func addHandler<P>(_ event: EventName, payload: P.Type, _ action: @escaping (P) -> Void) {
    handlers.append((event, { any in
        guard let p = any as? P else {
            assertionFailure("payload type mismatch for \(event.rawValue): expected \(P.self), got \(String(describing: any))")
            return                                            // release: drop (spec §11)
        }
        action(p)
    }))
}
mutating func addRawHandler(_ event: EventName, _ action: @escaping (Any?) -> Void) {
    handlers.append((event, action))
}
```

2f. `Resolver.swift` `resolveElement` — registration switches to the erased seam:

```swift
for (event, action) in bag.handlers {
    let lid = ListenerID(owner: path, event: event.rawValue)
    ctx.listeners.set(lid, payloadHandler: action)
    ctx.liveListeners.insert(lid)
    listeners[event.rawValue] = lid
}
```

2g. `HTMLTag.swift` — escape hatch (bag-level, identity-transparent, spec D11):

```swift
public func on(_ event: EventName, perform action: @escaping (GenericEvent) -> Void) -> Self {
    var copy = self
    copy._attributes.addRawHandler(event) { any in
        action(GenericEvent(type: event.rawValue, payload: any))
    }
    return copy
}
```

- [ ] **Step 3: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(events): typed payload pipeline — payload structs, erased registry, dispatch(payload:), .on escape hatch"
```

---

### Task 3: DOM properties end-to-end (native)

**Files:**
- Modify: `Sources/SwiftWUI/Tree/Node.swift` (`PropertyValue`, `ElementNode.properties`)
- Modify: `Sources/SwiftWUI/HTML/AttributeBag.swift` (property storage)
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (`resolveElement` emits properties)
- Modify: `Sources/SwiftWUI/Render/Reconciler.swift` (`Patch.setProperty`, property diff)
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (`setProperty`)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (record + serialize)
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift` (mount + patch case)
- Modify: `Sources/SwiftWUI/Render/HTMLRenderer.swift` (serialize)
- Test: `Tests/SwiftWUITests/PropertyTests.swift` (new)

**Interfaces:**
- Consumes: Task 2 payload machinery (unrelated but merged bag).
- Produces:
  - `public enum PropertyValue: Equatable { case string(String), bool(Bool) }`
  - `ElementNode.properties: [String: PropertyValue]` (defaulted `[:]`, memberwise-compatible)
  - `Patch.setProperty(name: String, value: PropertyValue)` (removal = neutral write: `.string("")` / `.bool(false)`)
  - `RendererBackend.setProperty(_ node: HostNode, name: String, value: PropertyValue)`
  - `_AttributeBag.setProperty(_ name: String, _ value: PropertyValue)` + `flattenedProperties() -> [String: PropertyValue]`
  - Serialization rule (both HTMLRenderer and MockBackend.serializeHTML, MUST stay in lockstep): attributes first (sorted), then properties (sorted); `.string(s)` → `name="s"` (escaped, even when empty), `.bool(true)` → bare `name`, `.bool(false)` → omitted.

- [ ] **Step 1: Write tests** (`Tests/SwiftWUITests/PropertyTests.swift`)

```swift
import Testing
@testable import SwiftWUI

@MainActor @Suite struct PropertyTests {
    private func el(_ props: [String: PropertyValue]) -> Node {
        .element(ElementNode(identity: .root.appending(.child(0)), tag: "input",
                             attributes: ["type": "text"], properties: props,
                             listeners: [:], children: [], key: nil))
    }

    @Test func diffEmitsSetPropertyOnChange() {
        let patches = Reconciler().diff(old: el(["value": .string("a")]),
                                        new: el(["value": .string("b")]))
        #expect(patches == [.setProperty(name: "value", value: .string("b"))])
    }

    @Test func diffNeutralizesRemovedProperties() {
        let p1 = Reconciler().diff(old: el(["value": .string("a")]), new: el([:]))
        #expect(p1 == [.setProperty(name: "value", value: .string(""))])
        let p2 = Reconciler().diff(old: el(["checked": .bool(true)]), new: el([:]))
        #expect(p2 == [.setProperty(name: "checked", value: .bool(false))])
    }

    @Test func mountSetsProperties() {
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        _ = applier.mount(el(["value": .string("x"), "checked": .bool(true)]),
                          hostParent: backend.container, before: nil)
        let node = findFirst(backend.container, tag: "input")!
        #expect(node.props["value"] == .string("x"))
        #expect(node.props["checked"] == .bool(true))
    }

    @Test func serializersAgreeOnProperties() {
        let backend = MockBackend()
        let applier = TreeApplier(backend: backend, container: backend.container)
        let node = el(["value": .string("a<b"), "checked": .bool(true), "off": .bool(false)])
        _ = applier.mount(node, hostParent: backend.container, before: nil)
        let viaMock = backend.serializeHTML()
        let viaRenderer = HTMLRenderer.render([node])
        #expect(viaMock == viaRenderer)
        #expect(viaRenderer == #"<input type="text" checked value="a&lt;b">"#)
    }
}
```

(Adjust the golden string once at implementation time if attribute/property ordering differs — the REQUIREMENT is: both serializers byte-equal, escaped value, `.bool(false)` omitted.)

- [ ] **Step 2: Implementation**

2a. `Node.swift`:

```swift
public enum PropertyValue: Equatable {
    case string(String)
    case bool(Bool)
}
```

Add to `ElementNode` (after `attributes`): `public var properties: [String: PropertyValue] = [:]`. The default keeps every existing memberwise call site compiling; `resolveElement` passes it explicitly.

2b. `AttributeBag.swift`:

```swift
private(set) var properties: [(name: String, value: PropertyValue)] = []
mutating func setProperty(_ name: String, _ value: PropertyValue) { properties.append((name, value)) }
func flattenedProperties() -> [String: PropertyValue] {
    var out: [String: PropertyValue] = [:]
    for (name, value) in properties { out[name] = value }     // last-wins
    return out
}
```

2c. `Resolver.swift` `resolveElement` — emit: `properties: bag.flattenedProperties()` in the `ElementNode(…)` construction.

2d. `Reconciler.swift`:

```swift
enum Patch: Equatable {
    …existing cases…
    case setProperty(name: String, value: PropertyValue)
}
```

In `diff`, element case, after the attribute loops:

```swift
for name in n.properties.keys.sorted() where o.properties[name] != n.properties[name] {
    patches.append(.setProperty(name: name, value: n.properties[name]!))
}
for name in o.properties.keys.sorted() where n.properties[name] == nil {
    // property "removal" = write the neutral value (spec §7: value="" clears, checked=false unchecks)
    switch o.properties[name]! {
    case .string: patches.append(.setProperty(name: name, value: .string("")))
    case .bool:   patches.append(.setProperty(name: name, value: .bool(false)))
    }
}
```

2e. `RendererBackend.swift`: add `func setProperty(_ node: HostNode, name: String, value: PropertyValue)`.

2f. `MockBackend.swift`: `MockNode` gains `public var props: [String: PropertyValue] = [:]`;

```swift
public func setProperty(_ node: MockNode, name: String, value: PropertyValue) {
    bump("setProperty"); node.props[name] = value
}
```

In `serializeHTML`, after the attribute loop, before `">"`:

```swift
for name in n.props.keys.sorted() {
    switch n.props[name]! {
    case .string(let s): out += " \(name)=\"\(HTMLEscaping.text(s))\""
    case .bool(true):    out += " " + name
    case .bool(false):   break
    }
}
```

2g. `TreeApplier.swift` — `mount` element case, after the attribute loop:

```swift
for name in el.properties.keys.sorted() {
    backend.setProperty(h, name: name, value: el.properties[name]!)
}
```

`apply` gains:

```swift
case .setProperty(let name, let value):
    backend.setProperty(m.host!, name: name, value: value)
```

2h. `HTMLRenderer.swift` — element case, after the attribute loop, before `">"` (same rule as MockBackend — these two MUST stay in lockstep; that's the cross-check property):

```swift
for name in el.properties.keys.sorted() {
    switch el.properties[name]! {
    case .string(let s): out += " " + name + "=\"" + HTMLEscaping.text(s) + "\""
    case .bool(true):    out += " " + name
    case .bool(false):   break
    }
}
```

- [ ] **Step 3: Run the full suite** — `swift test 2>&1 | tail -5`, expected PASS (CrossCheckTests must stay green — they prove Mock/HTMLRenderer parity).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(render): DOM properties — PropertyValue, ElementNode.properties, diff/apply/serialize support"
```

---

### Task 4: Controlled inputs (Input/Textarea/Form typed APIs)

**Files:**
- Modify: `Sources/SwiftWUI/HTML/Tags.swift` (`Input` overloads, `Textarea(text:)`, `Form(onSubmit:)`)
- Test: `Tests/SwiftWUITests/ControlledInputTests.swift` (new)

**Interfaces:**
- Consumes: Task 2 (`addHandler(payload:)`, payload structs), Task 3 (`setProperty`), existing `Binding<Value>`.
- Produces:
  - `Input.init(type: InputType = .text, value: Binding<String>, placeholder: String? = nil, disabled: Bool = false, id: String? = nil, class: String? = nil, onInput: ((InputEvent) -> Void)? = nil, onKeyDown: ((KeyEvent) -> Void)? = nil)`
  - `Input.init(checked: Binding<Bool>, name: String? = nil, disabled: Bool = false, id: String? = nil, class: String? = nil, onChange: ((ChangeEvent) -> Void)? = nil)` (sets `type="checkbox"`)
  - `Textarea.init(text: Binding<String>, id: String? = nil, class: String? = nil)` where `Content == EmptyTag`
  - `Form.init(onSubmit: @escaping (SubmitEvent) -> Void, id: String? = nil, class: String? = nil, @TagBuilder content:)`

- [ ] **Step 1: Write tests** (`Tests/SwiftWUITests/ControlledInputTests.swift`)

```swift
import Testing
@testable import SwiftWUI

private struct EchoFixture: Tag {
    @State var text = "start"
    var body: some Tag {
        Div {
            Input(type: .text, value: $text)
            P { text }
        }
    }
}
private struct CheckFixture: Tag {
    @State var done = false
    var body: some Tag {
        Div {
            Input(checked: $done)
            if done { P { "done" } }
        }
    }
}

@MainActor @Suite struct ControlledInputTests {
    @Test func inputEventWritesBindingAndRerenders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: EchoFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let input = findFirst(backend.container, tag: "input")!
        #expect(input.props["value"] == .string("start"))
        rt.dispatch(input.events["input"]!, payload: InputEvent(value: "hello"))
        sched.pump()
        #expect(findFirst(backend.container, tag: "p")!.children[0].text == "hello")
        #expect(input.props["value"] == .string("hello"))     // echo write is a no-op value-wise
    }

    @Test func checkboxTogglesBinding() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: CheckFixture(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let input = findFirst(backend.container, tag: "input")!
        #expect(input.attrs["type"] == "checkbox")
        #expect(input.props["checked"] == .bool(false))
        rt.dispatch(input.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()
        #expect(findFirst(backend.container, tag: "p") != nil)
        #expect(input.props["checked"] == .bool(true))
    }

    @Test func textareaControlled() {
        let html = HTMLRenderer.render(Textarea(text: .constant("hi")))
        #expect(html == #"<textarea value="hi"></textarea>"#)
    }

    @Test func formOnSubmit() {
        var submitted = 0
        let form = Form(onSubmit: { (_: SubmitEvent) in submitted += 1 }) { EmptyTag() }
        form._attributes.handlers[0].action(SubmitEvent())
        #expect(submitted == 1)
    }
}
```

- [ ] **Step 2: Implementation** in `Tags.swift`:

```swift
extension Input {
    /// Controlled text input: DOM `value` property tracks the binding; every
    /// input event writes it back (spec §7).
    public init(type: InputType = .text, value: Binding<String>,
                placeholder: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onInput: ((InputEvent) -> Void)? = nil,
                onKeyDown: ((KeyEvent) -> Void)? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", type.rawValue)
        _attributes.set("placeholder", placeholder)
        if disabled { _attributes.set("disabled", "") }
        _attributes.setProperty("value", .string(value.wrappedValue))
        _attributes.addHandler(.input, payload: InputEvent.self) { e in
            value.wrappedValue = e.value
            onInput?(e)
        }
        if let onKeyDown {
            _attributes.addHandler(.keydown, payload: KeyEvent.self, onKeyDown)
        }
    }

    /// Controlled checkbox.
    public init(checked: Binding<Bool>, name: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onChange: ((ChangeEvent) -> Void)? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", "checkbox")
        _attributes.set("name", name)
        if disabled { _attributes.set("disabled", "") }
        _attributes.setProperty("checked", .bool(checked.wrappedValue))
        _attributes.addHandler(.change, payload: ChangeEvent.self) { e in
            checked.wrappedValue = e.checked
            onChange?(e)
        }
    }
}

extension Textarea where Content == EmptyTag {
    /// Controlled textarea (text-only mode — phase-1 review backlog item 3).
    public init(text: Binding<String>, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.setProperty("value", .string(text.wrappedValue))
        _attributes.addHandler(.input, payload: InputEvent.self) { text.wrappedValue = $0.value }
        content = EmptyTag()
    }
}

extension Form {
    /// Submit-handling form. The backend ALWAYS calls preventDefault() for
    /// submit events (spec D10) — no page reloads.
    public init(onSubmit: @escaping (SubmitEvent) -> Void,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.addHandler(.submit, payload: SubmitEvent.self, onSubmit)
        self.content = content()
    }
}
```

- [ ] **Step 3: Run the full suite** — `swift test 2>&1 | tail -5`, expected PASS.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(html): controlled inputs — Input(value:)/Input(checked:)/Textarea(text:)/Form(onSubmit:)"
```

---

### Task 5: @Environment

**Files:**
- Create: `Sources/SwiftWUI/Environment/Environment.swift`
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (`ResolveContext.environment`, `link` call)
- Modify: `Sources/SwiftWUI/State/StateStore.swift` (`link` signature + injection)
- Test: `Tests/SwiftWUITests/EnvironmentTests.swift` (new)

**Interfaces:**
- Consumes: `ResolveContext`, `StateStore.link`, Mirror pass.
- Produces:
  - `public protocol EnvironmentKey { associatedtype Value; static var defaultValue: Value { get } }`
  - `public struct EnvironmentValues { public init(); public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value { get set } }`
  - `@propertyWrapper public struct Environment<Value>: _EnvironmentProperty { public init(_ keyPath: KeyPath<EnvironmentValues, Value>); public var wrappedValue: Value }`
  - `public protocol _EnvironmentProperty { func _inject(_ values: EnvironmentValues) }`
  - `extension Tag { public func environment<V>(_ kp: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some Tag }`
  - `ResolveContext.environment: EnvironmentValues` (var, defaults to `EnvironmentValues()`)
  - `StateStore.link(_ component:, at:, environment: EnvironmentValues, invalidate:)` ← Task 6 and the resolver depend on this exact signature.

- [ ] **Step 1: Write tests** (`Tests/SwiftWUITests/EnvironmentTests.swift`)

```swift
import Testing
@testable import SwiftWUI

private struct ThemeKey: EnvironmentKey { static let defaultValue = "light" }
extension EnvironmentValues {
    var theme: String { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
}

private struct ThemedLabel: Tag {
    @Environment(\.theme) var theme
    var body: some Tag { P { theme } }
}
private struct EnvFixture: Tag {
    var body: some Tag {
        Div {
            ThemedLabel()                                   // default
            Div { ThemedLabel() }.environment(\.theme, "dark")
        }
    }
}

@MainActor @Suite struct EnvironmentTests {
    @Test func defaultsAndOverridesAndRestore() {
        let html = HTMLRenderer.render(EnvFixture())
        #expect(html.contains("<p>light</p>"))              // outside writer: default
        #expect(html.contains("<p>dark</p>"))               // inside writer: override
    }

    @Test func unlinkedWrapperFallsBackToDefault() {
        let label = ThemedLabel()
        #expect(label.theme == "light")                     // constructed outside runtime
    }

    @Test func writerAppendsOneIdentitySegment() {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(), invalidate: { _ in })
        let nodes = resolve(Div { EmptyTag() }.environment(\.theme, "x"), path: .root, ctx: &ctx)
        guard case .element(let el) = nodes[0] else { Issue.record("expected element"); return }
        #expect(el.identity.segments.count == 1)            // writer's .type segment, div at that path
    }
}
```

- [ ] **Step 2: Implementation**

2a. `Environment/Environment.swift` (new):

```swift
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

/// Resolver-facing seam, injected by StateStore.link's Mirror pass BEFORE body
/// evaluation (spec §4, decision D5). Machinery, not user API.
public protocol _EnvironmentProperty {
    func _inject(_ values: EnvironmentValues)
}

@propertyWrapper
public struct Environment<Value>: _EnvironmentProperty {
    final class Slot { var snapshot: EnvironmentValues? }
    private let keyPath: KeyPath<EnvironmentValues, Value>
    private let slot = Slot()
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) { self.keyPath = keyPath }
    public var wrappedValue: Value {
        (slot.snapshot ?? EnvironmentValues())[keyPath: keyPath]   // defaults when unset
    }
    public func _inject(_ values: EnvironmentValues) { slot.snapshot = values }
}

/// `.environment()` wrapper: one identity segment, save/write/restore around
/// content resolution (spec §4, decision D3).
struct _EnvironmentWriter<V, Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let keyPath: WritableKeyPath<EnvironmentValues, V>
    let value: V
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let saved = ctx.environment
        ctx.environment[keyPath: keyPath] = value
        let nodes = resolve(content, path: path.appending(.type(ObjectIdentifier(Self.self))), ctx: &ctx)
        ctx.environment = saved
        return nodes
    }
}

extension Tag {
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>,
                               _ value: V) -> some Tag {
        _EnvironmentWriter(keyPath: keyPath, value: value, content: self)
    }
}
```

2b. `Resolver.swift` — `ResolveContext` gains `var environment = EnvironmentValues()`; the component branch of `resolve` passes it:

```swift
ctx.store.link(tag, at: id, environment: ctx.environment, invalidate: { inv(id) })
```

2c. `StateStore.swift` — `link` signature + injection in the SAME Mirror loop (env injection must run even when there are no @State props — restructure the early-return):

```swift
func link(_ component: some Tag, at id: NodeIdentity,
          environment: EnvironmentValues, invalidate: @escaping () -> Void) {
    var props: [_StateProperty] = []
    for child in Mirror(reflecting: component).children {
        if let p = child.value as? _StateProperty { props.append(p) }
        if let e = child.value as? _EnvironmentProperty { e._inject(environment) }
    }
    guard !props.isEmpty else { return }
    …rest unchanged…
}
```

Update `StateStoreTests` call sites: add `environment: EnvironmentValues()` to existing `link` calls.

- [ ] **Step 3: Run the full suite** — `swift test 2>&1 | tail -5`, expected PASS.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(state): @Environment — EnvironmentKey/Values, keypath wrapper, .environment() writer, Mirror injection"
```

---

### Task 6: Scoped invalidation

**Files:**
- Modify: `Sources/SwiftWUI/State/StateStore.swift` (`RetainedComponent`, `retain`, `retainedRow`, sweep prunes retained)
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (retain call in component branch)
- Create: `Sources/SwiftWUI/Tree/TreeQuery.swift` (`findNode`, `splicing`)
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift` (`MountedNode.componentIdentity`, `componentIndex`)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (`flush`, `minimalCover`, `subtreePass`)
- Test: `Tests/SwiftWUITests/ScopedInvalidationTests.swift` (new)

**Interfaces:**
- Consumes: Task 5 (`ResolveContext.environment`, `link(environment:)`), `AnyTag`, `isSelfOrDescendant`.
- Produces:
  - `struct RetainedComponent { var tag: AnyTag; var environment: EnvironmentValues }` (internal)
  - `StateStore.retain(_ tag: AnyTag, at: NodeIdentity, environment: EnvironmentValues)`, `StateStore.retainedRow(at:) -> RetainedComponent?`
  - `func findNode(_ node: Node, at id: NodeIdentity) -> Node?` and `func splicing(_ tree: Node, at id: NodeIdentity, with replacement: Node) -> Node` (internal, `Tree/TreeQuery.swift`)
  - `MountedNode.componentIdentity: NodeIdentity?`; `TreeApplier.componentIndex: [NodeIdentity: MountedNode<Backend.HostNode>]`
  - `Runtime.flush()` performs scoped passes; `Runtime._forceFullPasses: Bool` (internal test hook, Task 7 depends on it)

- [ ] **Step 1: Write tests** (`Tests/SwiftWUITests/ScopedInvalidationTests.swift`)

```swift
import Testing
@testable import SwiftWUI

/// Body-evaluation counter: explicit `return` disables the builder transform,
/// so plain statements are allowed before it.
private final class Counters { var byLabel: [String: Int] = [:]
                               func bump(_ l: String) { byLabel[l, default: 0] += 1 } }

private struct LeafCounter: Tag {
    let label: String
    let counters: Counters
    @State var n = 0
    var body: some Tag {
        counters.bump(label)
        return Div(class: label) {
            P { "\(label): \(n)" }
            Button("+") { n += 1 }
        }
    }
}
private struct TwoLeaves: Tag {
    let counters: Counters
    var body: some Tag {
        counters.bump("parent")
        return Div {
            LeafCounter(label: "a", counters: counters)
            LeafCounter(label: "b", counters: counters)
        }
    }
}

@MainActor @Suite struct ScopedInvalidationTests {
    @Test func dirtyLeafRerendersOnlyItself() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TwoLeaves(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(counters.byLabel == ["parent": 1, "a": 1, "b": 1])

        let buttons = findAll(backend.container, tag: "button")
        rt.dispatch(buttons[0].events["click"]!)              // leaf a
        sched.pump()
        #expect(counters.byLabel == ["parent": 1, "a": 2, "b": 1])   // b and parent untouched
        #expect(findAll(backend.container, tag: "p")[0].children[0].text == "a: 1")
    }

    @Test func coalescedDirtSiblingsBothRerenderOnce() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TwoLeaves(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        let buttons = findAll(backend.container, tag: "button")
        rt.dispatch(buttons[0].events["click"]!)
        rt.dispatch(buttons[1].events["click"]!)
        sched.pump()                                          // ONE flush, two survivors
        #expect(counters.byLabel == ["parent": 1, "a": 2, "b": 2])
    }

    @Test func dirtyParentCoversDirtyChild() {
        // parent + child dirty in same flush → minimal cover = parent only
        let ids: Set<NodeIdentity> = {
            let p = NodeIdentity.root.appending(.type(ObjectIdentifier(TwoLeaves.self)))
            let c = p.appending(.child(0)).appending(.type(ObjectIdentifier(LeafCounter.self)))
            return [p, c]
        }()
        let backend = MockBackend()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TwoLeaves(counters: Counters()), scheduleMicrotask: { _ in })
        #expect(rt.minimalCover(ids).count == 1)
    }

    @Test func removedComponentDirtIsSkipped() {
        // toggle removes a subtree; a stale dirty id for it must be a no-op
        struct Host: Tag {
            @State var on = true
            var body: some Tag {
                Div {
                    if on { P { "on" } }
                    Button("t") { on.toggle() }
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Host(), scheduleMicrotask: sched.schedule)
        rt.mount()
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, tag: "p") == nil)   // no crash, subtree gone
    }
}
```

- [ ] **Step 2: Implementation**

2a. `StateStore.swift`:

```swift
struct RetainedComponent {
    var tag: AnyTag
    var environment: EnvironmentValues
}
// StateStore gains:
private var retained: [NodeIdentity: RetainedComponent] = [:]
func retain(_ tag: AnyTag, at id: NodeIdentity, environment: EnvironmentValues) {
    retained[id] = RetainedComponent(tag: tag, environment: environment)
}
func retainedRow(at id: NodeIdentity) -> RetainedComponent? { retained[id] }
```

`sweep(under:reachable:)` additionally prunes `retained` with the same predicate as `rows`.

2b. `Resolver.swift` component branch — retain right after `ctx.reachable.insert(id)`:

```swift
ctx.store.retain(AnyTag(tag), at: id, environment: ctx.environment)
```

2c. `Tree/TreeQuery.swift` (new):

```swift
/// Locates the node with exactly `id`, pruning by identity-prefix descent.
func findNode(_ node: Node, at id: NodeIdentity) -> Node? {
    switch node {
    case .text: return nil
    case .element(let e):
        if e.identity == id { return node }
        guard id.isSelfOrDescendant(of: e.identity) else { return nil }
        for c in e.children { if let f = findNode(c, at: id) { return f } }
        return nil
    case .component(let c):
        if c.identity == id { return node }
        guard id.isSelfOrDescendant(of: c.identity) else { return nil }
        for ch in c.children { if let f = findNode(ch, at: id) { return f } }
        return nil
    }
}

/// Copy-on-write replacement of the subtree rooted at `id` (spec §2.3 step 5).
func splicing(_ tree: Node, at id: NodeIdentity, with replacement: Node) -> Node {
    switch tree {
    case .text: return tree
    case .element(var e):
        if e.identity == id { return replacement }
        guard id.isSelfOrDescendant(of: e.identity) else { return tree }
        e.children = e.children.map { splicing($0, at: id, with: replacement) }
        return .element(e)
    case .component(var c):
        if c.identity == id { return replacement }
        guard id.isSelfOrDescendant(of: c.identity) else { return tree }
        c.children = c.children.map { splicing($0, at: id, with: replacement) }
        return .component(c)
    }
}
```

2d. `TreeApplier.swift`:
- `MountedNode` gains `let componentIdentity: NodeIdentity?` (init param, default `nil`).
- `TreeApplier` gains `private(set) var componentIndex: [NodeIdentity: MountedNode<Backend.HostNode>] = [:]`.
- `mount` `.component` case: `let m = MountedNode(host: nil, hostParent: hostParent, componentIdentity: c.identity)` then `componentIndex[c.identity] = m`.
- `unmount` starts with recursive de-registration:

```swift
func unmount(_ m: MountedNode<Backend.HostNode>) {
    unregister(m)
    tearDownListeners(m)
    removeHosts(m)
}
private func unregister(_ m: MountedNode<Backend.HostNode>) {
    if let id = m.componentIdentity { componentIndex[id] = nil }
    for c in m.children { unregister(c) }
}
```

(`replace` already routes through `mount`+`unmount`, so the index stays correct.)

2e. `Runtime.swift`:

```swift
var _forceFullPasses = false     // test hook (Task 7): bypass scoping

public func flush() {
    scheduled = false
    guard !dirty.isEmpty else { return }
    let ids = dirty
    dirty.removeAll()
    if current == nil || _forceFullPasses || ids.contains(.root) {
        renderPass(); return
    }
    for id in minimalCover(ids) {
        guard let row = store.retainedRow(at: id) else { continue }   // removed this flush
        subtreePass(id, row)
    }
}

/// Drops ids that are descendants of other dirty ids (spec §2.2).
func minimalCover(_ ids: Set<NodeIdentity>) -> [NodeIdentity] {
    var cover: [NodeIdentity] = []
    for id in ids.sorted(by: { $0.segments.count < $1.segments.count }) {
        if !cover.contains(where: { id.isSelfOrDescendant(of: $0) }) { cover.append(id) }
    }
    return cover
}

private func subtreePass(_ id: NodeIdentity, _ row: RetainedComponent) {
    guard let old = findNode(current!, at: id),
          let mounted = applier.componentIndex[id] else {
        renderPass(); return                                  // defensive: fall back to full
    }
    var ctx = ResolveContext(store: store, listeners: listeners,
                             invalidate: { [weak self] in self?.markDirty($0) })
    ctx.environment = row.environment
    isRendering = true
    let parentPath = NodeIdentity(segments: Array(id.segments.dropLast()))
    let nodes = resolve(row.tag, path: parentPath, ctx: &ctx)   // re-appends .type → same id
    isRendering = false
    assert(nodes.count == 1, "component must resolve to exactly one node")
    let new = nodes[0]

    store.sweep(under: id, reachable: ctx.reachable)
    listeners.sweep(under: id, keep: ctx.liveListeners)

    let patches = Reconciler().diff(old: old, new: new)
    applier.apply(patches, to: mounted)          // top-level per pass → shadow anchors safe
    current = splicing(current!, at: id, with: new)
}
```

Note: `renderPass` itself needs NO change — full passes already register `componentIndex` via `mount`, and `store.sweep(under: .root)` now also prunes `retained`.

- [ ] **Step 3: Run the full suite** — `swift test 2>&1 | tail -5`, expected PASS. Every phase-1 e2e test now exercises the scoped path (their fixtures' @State owners are components) — treat any failure there as a scoping bug, not a test to update.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(runtime): component-scoped invalidation — retained tags, minimal cover, subtree passes, componentIndex"
```

---

### Task 7: Scoped ≡ full property test

**Files:**
- Test: `Tests/SwiftWUITests/ScopedEquivalenceTests.swift` (new)

**Interfaces:**
- Consumes: `Runtime._forceFullPasses` (Task 6), `MockBackend.serializeHTML`, `StateStore.rowCount`, `ListenerRegistry.count`.
- Produces: nothing (pure test task).

- [ ] **Step 1: Write the property test**

```swift
import Testing
@testable import SwiftWUI

/// Deterministic PRNG so failures reproduce by seed.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Fixture exercising every structural feature: nested components, keyed
/// ForEach, conditionals, sibling components with independent state.
private struct PropLeaf: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "leaf") {
            P { "n=\(n)" }
            Button("+") { n += 1 }
            if n % 3 == 1 { Span { "mod" } }
        }
    }
}
private struct PropList: Tag {
    @State var items = [1, 2, 3]
    var body: some Tag {
        Div(class: "list") {
            ForEach(items, id: \.self) { _ in PropLeaf() }
            Button("rot") { if let f = items.first { items = Array(items.dropFirst()) + [f] } }
            Button("add") { items.append((items.max() ?? 0) + 1) }
        }
    }
}
private struct PropRoot: Tag {
    @State var showList = true
    var body: some Tag {
        Div {
            PropLeaf()
            if showList { PropList() }
            Button("toggle") { showList.toggle() }
        }
    }
}

@MainActor @Suite struct ScopedEquivalenceTests {
    /// Spec §2.4: a scoped pass must be byte-identical to a full pass.
    @Test(arguments: 0..<20) func scopedEqualsFull(seed: Int) {
        let schedA = TestScheduler(), schedB = TestScheduler()
        let backA = MockBackend(), backB = MockBackend()
        let scoped = Runtime(backend: backA, container: backA.container,
                             root: PropRoot(), scheduleMicrotask: schedA.schedule)
        let full = Runtime(backend: backB, container: backB.container,
                           root: PropRoot(), scheduleMicrotask: schedB.schedule)
        full._forceFullPasses = true
        scoped.mount(); full.mount()

        var rng = SplitMix64(state: UInt64(seed) &+ 1)
        for _ in 0..<25 {
            // identical random event sequence against both runtimes
            let buttonsA = findAll(backA.container, tag: "button")
            let buttonsB = findAll(backB.container, tag: "button")
            #expect(buttonsA.count == buttonsB.count)
            guard !buttonsA.isEmpty else { break }
            let pick = Int(rng.next() % UInt64(buttonsA.count))
            // occasionally batch two dispatches into one flush (coalescing path)
            let batch = rng.next() % 4 == 0 && buttonsA.count > 1
            scoped.dispatch(buttonsA[pick].events["click"]!)
            full.dispatch(buttonsB[pick].events["click"]!)
            if batch {
                let second = (pick + 1) % buttonsA.count
                scoped.dispatch(buttonsA[second].events["click"]!)
                full.dispatch(buttonsB[second].events["click"]!)
            }
            schedA.pump(); schedB.pump()

            #expect(backA.serializeHTML() == backB.serializeHTML(),
                    "diverged at seed \(seed)")
            #expect(scopedStore(scoped).rowCount == scopedStore(full).rowCount)
        }
    }
}

// @testable access helper: expose store/listeners counts for the invariant.
// If Runtime's `store`/`listeners` are private, add `var _storeRowCount: Int`
// and `var _listenerCount: Int` internal accessors to Runtime in this task.
@MainActor private func scopedStore(_ rt: Runtime<MockBackend>) -> StateStore { rt._store }
```

Implementation detail this task IS allowed to touch: add to `Runtime`:

```swift
var _store: StateStore { store }            // test hooks
var _listenerCount: Int { listeners.count }
```

- [ ] **Step 2: Run the full suite** — `swift test 2>&1 | tail -5`, expected PASS. If a seed diverges: reduce the event sequence for that seed by hand, fix the Task-6 bug, keep the reduced case as a named regression test.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "test(runtime): property test — scoped invalidation ≡ full pass across random event sequences"
```

---

### Task 8: @Observable tracking + @Bindable

**Files:**
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (tracking wrap in component branch)
- Create: `Sources/SwiftWUI/State/Bindable.swift`
- Test: `Tests/SwiftWUITests/ObservationTests.swift` (new)

**Interfaces:**
- Consumes: `withObservationTracking` (stdlib Observation), `ctx.invalidate`, Task 6 scoped passes.
- Produces:
  - Component bodies are observation-tracked; a mutation of any `@Observable` property READ during a body dirties exactly that component.
  - `@propertyWrapper @dynamicMemberLookup public struct Bindable<Value: AnyObject & Observable>` with `subscript<T>(dynamicMember kp: ReferenceWritableKeyPath<Value, T>) -> Binding<T>`.

- [ ] **Step 1: Write tests** (`Tests/SwiftWUITests/ObservationTests.swift`)

```swift
import Testing
import Observation
@testable import SwiftWUI

@Observable private final class Model {
    var count = 0
    var unrelated = 0
}

private final class Counters { var byLabel: [String: Int] = [:]
                               func bump(_ l: String) { byLabel[l, default: 0] += 1 } }

private struct Reader: Tag {
    let model: Model
    let counters: Counters
    var body: some Tag {
        counters.bump("reader")
        return P { "count: \(model.count)" }
    }
}
private struct NonReader: Tag {
    let counters: Counters
    var body: some Tag {
        counters.bump("nonreader")
        return P { "static" }
    }
}
private struct ObsHost: Tag {
    @State var model = Model()
    let counters: Counters
    var body: some Tag {
        counters.bump("host")
        return Div {
            Reader(model: model, counters: counters)
            NonReader(counters: counters)
            Button("+") { model.count += 1 }
        }
    }
}

@MainActor @Suite struct ObservationTests {
    @Test func modelWriteDirtiesOnlyReaders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ObsHost(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(counters.byLabel == ["host": 1, "reader": 1, "nonreader": 1])

        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        // host's body reads nothing on the model; only Reader read .count
        #expect(counters.byLabel == ["host": 1, "reader": 2, "nonreader": 1])
        #expect(findAll(backend.container, tag: "p")[0].children[0].text == "count: 1")
    }

    @Test func trackingRearmsAcrossRenders() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ObsHost(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        let button = findFirst(backend.container, tag: "button")!
        for expected in 1...3 {
            rt.dispatch(button.events["click"]!)
            sched.pump()
            #expect(counters.byLabel["reader"] == expected + 1)   // fires every time, not once
        }
    }

    @Test func unrelatedPropertyWriteIsIgnored() {
        let backend = MockBackend(); let sched = TestScheduler()
        let counters = Counters()
        let model = Model()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Reader(model: model, counters: counters),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        model.unrelated += 1                          // never read by any body
        sched.pump()
        #expect(counters.byLabel["reader"] == 1)      // no re-render
    }

    @Test func bindableProducesWritableBinding() {
        let model = Model()
        @Bindable var m = model
        let binding = $m.count
        binding.wrappedValue = 7
        #expect(model.count == 7)
        #expect(binding.wrappedValue == 7)
    }
}
```

- [ ] **Step 2: Implementation**

2a. `Resolver.swift` — component branch, replace direct body access:

```swift
import Observation   // top of file

// Sendable adapter for the @Sendable onChange closure. Safe: every state write
// in the pipeline is @MainActor (module default isolation), so onChange always
// fires on the main actor in practice (spec D4).
private struct _InvalidateBox: @unchecked Sendable {
    let fire: () -> Void
}
```

In `resolve`, component branch — the body evaluation becomes:

```swift
let box = _InvalidateBox(fire: { inv(id) })
let body = withObservationTracking {
    tag.body
} onChange: {
    MainActor.assumeIsolated { box.fire() }
}
let children = resolve(body, path: id.appending(.child(0)), ctx: &ctx)
```

(Note: `onChange` fires at willSet, one-shot; `markDirty` only inserts into the dirty set and schedules the microtask, so the value is final by flush time. Re-arming is automatic — every re-render re-wraps. A stale fire for a removed component hits the `retainedRow == nil` guard in `flush` — harmless.)

2b. `State/Bindable.swift` (new):

```swift
import Observation

/// Bindings into @Observable models (spec §3.2). No runtime integration: the
/// Binding writes into the model, Observation notifies readers.
@propertyWrapper @dynamicMemberLookup
public struct Bindable<Value: AnyObject & Observable> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public var projectedValue: Bindable<Value> { self }
    public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, T>) -> Binding<T> {
        let object = wrappedValue
        return Binding(get: { object[keyPath: keyPath] },
                       set: { object[keyPath: keyPath] = $0 })
    }
}
```

- [ ] **Step 3: Run the full suite** — `swift test 2>&1 | tail -5`, expected PASS (including the Task-7 property test — tracking must not perturb equivalence).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(state): @Observable body tracking + @Bindable — per-component read tracking drives scoped invalidation"
```

---

### Task 9: Effects — onChange, task, onAppear/onDisappear

**Files:**
- Create: `Sources/SwiftWUI/Effects/EffectStore.swift`
- Create: `Sources/SwiftWUI/Effects/EffectModifiers.swift`
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (`ResolveContext.effects`)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (post-commit reconcile in `renderPass` and `subtreePass`)
- Test: `Tests/SwiftWUITests/EffectTests.swift` (new)

**Interfaces:**
- Consumes: identity segments (Task 5 pattern), `ResolveContext`, post-commit points in `Runtime`.
- Produces:
  - `extension Tag`: `onChange(of:initial:_:)`, `task(_:)`, `task(id:_:)`, `onAppear(_:)`, `onDisappear(_:)` — exact signatures from spec §5.1.
  - `enum EffectRequest` with `var id: NodeIdentity` (internal)
  - `ResolveContext.effects: [EffectRequest]` (var, defaults `[]`)
  - `EffectStore.reconcile(_ requests: [EffectRequest], under passRoot: NodeIdentity) -> [() -> Void]` — callbacks the Runtime runs post-commit.

- [ ] **Step 1: Write tests** (`Tests/SwiftWUITests/EffectTests.swift`)

```swift
import Testing
@testable import SwiftWUI

private final class Log { var entries: [String] = [] }

private struct ChangeFixture: Tag {
    let log: Log
    @State var n = 0
    var body: some Tag {
        Div {
            Button("+") { n += 1 }
        }
        .onChange(of: n) { old, new in log.entries.append("change \(old)->\(new)") }
    }
}
private struct AppearFixture: Tag {
    let log: Log
    @State var showChild = true
    var body: some Tag {
        Div {
            if showChild {
                P { "child" }
                    .onAppear { log.entries.append("appear") }
                    .onDisappear { log.entries.append("disappear") }
            }
            Button("t") { showChild.toggle() }
        }
    }
}

@MainActor @Suite struct EffectTests {
    @Test func onChangeFiresWithOldAndNew() {
        let backend = MockBackend(); let sched = TestScheduler()
        let log = Log()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: ChangeFixture(log: log), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(log.entries.isEmpty)                          // initial: false → silent mount
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["change 0->1"])
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["change 0->1", "change 1->2"])
    }

    @Test func onChangeInitialFiresOnMount() {
        struct F: Tag {
            let log: Log
            var body: some Tag {
                P { "x" }.onChange(of: 42, initial: true) { o, n in log.entries.append("\(o)/\(n)") }
            }
        }
        let backend = MockBackend()
        let log = Log()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(log: log), scheduleMicrotask: { _ in })
        rt.mount()
        #expect(log.entries == ["42/42"])
    }

    @Test func appearAndDisappearFireOnStructuralChange() {
        let backend = MockBackend(); let sched = TestScheduler()
        let log = Log()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: AppearFixture(log: log), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(log.entries == ["appear"])
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["appear", "disappear"])
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["appear", "disappear", "appear"])
    }

    @Test func taskStartsAfterCommitAndCancelsOnRemoval() async {
        final class Flags { var started = false; var cancelled = false }
        struct F: Tag {
            let flags: Flags
            @State var show = true
            var body: some Tag {
                Div {
                    if show {
                        P { "p" }.task {
                            flags.started = true
                            await withTaskCancellationHandler {
                                try? await Task.sleep(nanoseconds: 60_000_000_000)
                            } onCancel: {
                                flags.cancelled = true
                            }
                        }
                    }
                    Button("t") { show.toggle() }
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let flags = Flags()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(flags: flags), scheduleMicrotask: sched.schedule)
        rt.mount()
        await Task.yield(); await Task.yield()                // let the Task body begin
        #expect(flags.started)
        #expect(!flags.cancelled)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()                                          // sweep → cancel
        #expect(flags.cancelled)                              // onCancel fires synchronously
    }

    @Test func taskIDRestartsOnIDChange() async {
        final class Count { var starts = 0 }
        struct F: Tag {
            let count: Count
            @State var which = 0
            var body: some Tag {
                Div {
                    P { "p" }.task(id: which) { count.starts += 1 }
                    Button("b") { which += 1 }
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let count = Count()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(count: count), scheduleMicrotask: sched.schedule)
        rt.mount()
        await Task.yield(); await Task.yield()
        #expect(count.starts == 1)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        await Task.yield(); await Task.yield()
        #expect(count.starts == 2)                            // restarted with new id
    }

    @Test func effectsNeverRunDuringResolve() {
        // ordering pin: the callback list is returned by reconcile and run
        // post-commit — the DOM already reflects the new tree when it fires.
        let backend = MockBackend(); let sched = TestScheduler()
        let log = Log()
        struct F: Tag {
            let log: Log; let backend: MockBackend
            @State var n = 0
            var body: some Tag {
                Div {
                    P { "\(n)" }
                    Button("+") { n += 1 }
                }
                .onChange(of: n) { _, new in
                    log.entries.append(findAll(backend.container, tag: "p")[0].children[0].text ?? "?")
                }
            }
        }
        let rt = Runtime(backend: backend, container: backend.container,
                         root: F(log: log, backend: backend), scheduleMicrotask: sched.schedule)
        rt.mount()
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(log.entries == ["1"])                         // DOM committed BEFORE effect ran
    }
}
```

- [ ] **Step 2: Implementation**

2a. `Effects/EffectStore.swift` (new):

```swift
enum EffectRequest {
    case onChange(id: NodeIdentity, newValue: Any,
                  isEqual: (Any, Any) -> Bool, initial: Bool,
                  action: (Any, Any) -> Void)
    case task(id: NodeIdentity, taskID: AnyHashable?, action: () async -> Void)
    case appear(id: NodeIdentity, action: () -> Void)
    case disappear(id: NodeIdentity, action: () -> Void)

    var id: NodeIdentity {
        switch self {
        case .onChange(let id, _, _, _, _), .task(let id, _, _),
             .appear(let id, _), .disappear(let id, _): return id
        }
    }
}

/// Effect lifecycle (spec §5.3–5.4): keyed by wrapper identity; sweep
/// set-difference under the pass root = onDisappear / task cancellation.
@MainActor
final class EffectStore {
    private var previousValues: [NodeIdentity: Any] = [:]
    private var tasks: [NodeIdentity: (task: Task<Void, Never>, id: AnyHashable?)] = [:]
    private var appeared: Set<NodeIdentity> = []
    private var disappearActions: [NodeIdentity: () -> Void] = [:]

    /// Returns callbacks to run post-commit. Order (normative, spec D6):
    /// disappear/cancel first, then appear/task/onChange in document order.
    func reconcile(_ requests: [EffectRequest], under passRoot: NodeIdentity) -> [() -> Void] {
        var queue: [() -> Void] = []
        let requested = Set(requests.map(\.id))

        var known = Set(previousValues.keys)
        known.formUnion(tasks.keys); known.formUnion(appeared); known.formUnion(disappearActions.keys)
        for id in known where id.isSelfOrDescendant(of: passRoot) && !requested.contains(id) {
            if let t = tasks.removeValue(forKey: id) { t.task.cancel() }
            if let d = disappearActions.removeValue(forKey: id) { queue.append(d) }
            previousValues[id] = nil
            appeared.remove(id)
        }

        for request in requests {
            switch request {
            case .onChange(let id, let new, let isEqual, let initial, let action):
                if let old = previousValues[id] {
                    if !isEqual(old, new) { queue.append { action(old, new) } }
                } else if initial {
                    queue.append { action(new, new) }
                }
                previousValues[id] = new
            case .task(let id, let taskID, let action):
                if let existing = tasks[id] {
                    if existing.id != taskID {
                        existing.task.cancel()
                        tasks[id] = (Task { await action() }, taskID)
                    }
                } else {
                    tasks[id] = (Task { await action() }, taskID)
                }
            case .appear(let id, let action):
                if !appeared.contains(id) { appeared.insert(id); queue.append(action) }
            case .disappear(let id, let action):
                if !appeared.contains(id) { appeared.insert(id) }   // presence marker
                disappearActions[id] = action
            }
        }
        return queue
    }
}
```

2b. `Effects/EffectModifiers.swift` (new) — four wrapper primitives, one identity segment each, register-only at resolve (trap T12):

```swift
struct _OnChangeEffect<V: Equatable, Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let value: V
    let initial: Bool
    let action: (V, V) -> Void
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        let act = action
        ctx.effects.append(.onChange(
            id: id, newValue: value,
            isEqual: { ($0 as? V) == ($1 as? V) },
            initial: initial,
            action: { old, new in act(old as! V, new as! V) }))
        return resolve(content, path: id, ctx: &ctx)
    }
}

struct _TaskEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let taskID: AnyHashable?
    let action: () async -> Void
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        ctx.effects.append(.task(id: id, taskID: taskID, action: action))
        return resolve(content, path: id, ctx: &ctx)
    }
}

struct _AppearEffect<Content: Tag>: Tag, _PrimitiveTag {
    typealias Body = Never
    let onAppear: (() -> Void)?
    let onDisappear: (() -> Void)?
    let content: Content
    @MainActor func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        if let onAppear { ctx.effects.append(.appear(id: id, action: onAppear)) }
        if let onDisappear { ctx.effects.append(.disappear(id: id, action: onDisappear)) }
        return resolve(content, path: id, ctx: &ctx)
    }
}

extension Tag {
    public func onChange<V: Equatable>(of value: V, initial: Bool = false,
                                       _ action: @escaping (V, V) -> Void) -> some Tag {
        _OnChangeEffect(value: value, initial: initial, action: action, content: self)
    }
    public func task(_ action: @escaping () async -> Void) -> some Tag {
        _TaskEffect(taskID: nil, action: action, content: self)
    }
    public func task<ID: Hashable>(id: ID, _ action: @escaping () async -> Void) -> some Tag {
        _TaskEffect(taskID: AnyHashable(id), action: action, content: self)
    }
    public func onAppear(_ action: @escaping () -> Void) -> some Tag {
        _AppearEffect(onAppear: action, onDisappear: nil, content: self)
    }
    public func onDisappear(_ action: @escaping () -> Void) -> some Tag {
        _AppearEffect(onAppear: nil, onDisappear: action, content: self)
    }
}
```

(Note: two `_AppearEffect`s stacked nest — each appends its own segment, so `.onAppear{}.onDisappear{}` yields two distinct effect identities. Correct and expected.)

2c. `Resolver.swift` — `ResolveContext` gains `var effects: [EffectRequest] = []`.

2d. `Runtime.swift` — add `private let effects = EffectStore()`. At the END of `renderPass` (after `current = new`):

```swift
let callbacks = effects.reconcile(ctx.effects, under: .root)
for cb in callbacks { cb() }
```

At the END of `subtreePass` (after the `splicing` commit):

```swift
let callbacks = effects.reconcile(ctx.effects, under: id)
for cb in callbacks { cb() }
```

(State writes inside callbacks route through `markDirty` → next microtask flush. `isRendering` is already false here, so the assert holds.)

- [ ] **Step 3: Run the full suite** — `swift test 2>&1 | tail -5`, expected PASS (Task-7 property test must stay green: effect reconcile is part of pass equivalence).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(effects): onChange/task/onAppear/onDisappear — EffectStore reconcile, post-commit queue, sweep cancellation"
```

---

### Task 10: wasm backend — payload decoding, setProperty, async executor

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (dispatch signature, decode table, setProperty)
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (DispatchBox, JavaScriptEventLoop)
- Modify: `Package.swift` (JavaScriptEventLoop product)
- Test: build gate only (this code is `#if arch(wasm32)`; behavior verified in Task 11 browser acceptance)

**Interfaces:**
- Consumes: `Runtime.dispatch(_:payload:)` (Task 2), `PropertyValue` (Task 3), payload structs.
- Produces: `DOMBackend.init(dispatch: @escaping (ListenerID, Any?) -> Void)`; full `RendererBackend` conformance incl. `setProperty`.

- [ ] **Step 1: Implementation**

1a. `Package.swift` — add to SwiftWUIDOM dependencies:

```swift
.product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
```

1b. `DOMBackend.swift`:

- `private let dispatch: (ListenerID, Any?) -> Void` and `public init(dispatch: @escaping (ListenerID, Any?) -> Void)`.
- Listener closure decodes at fire time:

```swift
let closure = JSClosure { [weak self] args in
    guard let self, let current = self.listenerIDs[key] else { return .undefined }
    let payload = args.first?.object.map { Self.decodePayload(event: current.event, jsEvent: $0) }
    self.dispatch(current, payload)
    return .undefined
}
```

- Decode table (spec §6; submit always preventDefaults — spec D10):

```swift
static func decodePayload(event: String, jsEvent e: JSObject) -> Any {
    let target = e.target.object
    switch event {
    case "input":
        return InputEvent(value: target?.value.string ?? "")
    case "change":
        return ChangeEvent(value: target?.value.string ?? "",
                           checked: target?.checked.boolean ?? false)
    case "keydown", "keyup":
        return KeyEvent(key: e.key.string ?? "", repeated: e["repeat"].boolean ?? false)
    case "submit":
        _ = e.preventDefault?()
        return SubmitEvent()
    case "focus", "blur":
        return FocusEvent()
    default:
        return GenericEvent(type: event,
                            targetValue: target?.value.string,
                            key: e.key.string,
                            checked: target?.checked.boolean)
    }
}
```

- Property writes with the equality guard (cursor preservation, spec §7 / D9):

```swift
public func setProperty(_ node: JSObject, name: String, value: PropertyValue) {
    switch value {
    case .string(let s):
        if node[name].string != s { node[name] = .string(s) }
    case .bool(let b):
        if node[name].boolean != b { node[name] = .boolean(b) }
    }
}
```

1c. `DOMRuntime.swift`:

- `import JavaScriptEventLoop` (inside the `#if arch(wasm32)` block).
- `DispatchBox.fn` becomes `(ListenerID, Any?) -> Void = { _, _ in }`.
- In `mount`, FIRST line: `JavaScriptEventLoop.installGlobalExecutor()` (before `assertReflectionAlive()`), then:

```swift
let backend = DOMBackend(dispatch: { box.fn($0, $1) })
…
box.fn = { [weak runtime] in runtime?.dispatch($0, payload: $1) }
```

- [ ] **Step 2: Build gates**

Run: `swift test 2>&1 | tail -3` — native untouched, expected PASS.
Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3` — expected `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(dom): wasm payload decoding, property writes with equality guard, JavaScriptEventLoop executor"
```

---

### Task 11: TodoMVC example + acceptance

**Files:**
- Create: `Examples/TodoMVC/Package.swift`, `Examples/TodoMVC/Sources/main.swift`, `Examples/TodoMVC/index.html`, `Examples/TodoMVC/package.json`
- Test: `Tests/SwiftWUITests/TodoAcceptanceTests.swift` (new — native mirror of the app)

**Interfaces:**
- Consumes: everything from Tasks 2–10.
- Produces: the phase-2 acceptance artifact (spec §9).

- [ ] **Step 1: Native acceptance test** (`Tests/SwiftWUITests/TodoAcceptanceTests.swift`) — mirrors the example's structure so the whole feature set is pinned natively:

```swift
import Testing
import Observation
@testable import SwiftWUI

@Observable private final class TodoStore {
    struct Todo: Identifiable, Equatable { let id: Int; var title: String; var done: Bool }
    var todos: [Todo] = []
    var draft = ""
    private var nextID = 1
    var remaining: Int { todos.filter { !$0.done }.count }
    func add() {
        let title = draft.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        todos.append(Todo(id: nextID, title: title, done: false)); nextID += 1
        draft = ""
    }
    func toggle(_ id: Int) { if let i = todos.firstIndex(where: { $0.id == id }) { todos[i].done.toggle() } }
}
private struct StoreKey: EnvironmentKey { static let defaultValue = TodoStore() }
extension EnvironmentValues {
    fileprivate var todoStore: TodoStore { get { self[StoreKey.self] } set { self[StoreKey.self] = newValue } }
}
private enum Filter: String, CaseIterable { case all, active, completed }

private final class Counters { var byLabel: [String: Int] = [:]
                               func bump(_ l: String) { byLabel[l, default: 0] += 1 } }

private struct TodoRow: Tag {
    let todo: TodoStore.Todo
    let counters: Counters
    @Environment(\.todoStore) var store
    var body: some Tag {
        counters.bump("row-\(todo.id)")
        return Li(class: todo.done ? "done" : "todo") {
            Input(checked: Binding(get: { todo.done }, set: { _ in store.toggle(todo.id) }))
            Span { todo.title }
        }
    }
}
private struct RemainingLabel: Tag {
    @Environment(\.todoStore) var store
    var body: some Tag { P { "\(store.remaining) items left" } }
}
private struct TodoApp: Tag {
    let counters: Counters
    @State var store = TodoStore()
    @State var filter: Filter = .all
    var visible: [TodoStore.Todo] {
        switch filter {
        case .all: store.todos
        case .active: store.todos.filter { !$0.done }
        case .completed: store.todos.filter(\.done)
        }
    }
    var body: some Tag {
        Main {
            H1("todos")
            Input(type: .text, value: Binding(get: { store.draft }, set: { store.draft = $0 }),
                  onKeyDown: { e in if e.key == "Enter" { store.add() } })
            Ul {
                ForEach(visible) { TodoRow(todo: $0, counters: counters) }
            }
            RemainingLabel()
            Div(class: "filters") {
                ForEach(Filter.allCases, id: \.rawValue) { f in
                    Button(f.rawValue) { filter = f }
                }
            }
        }
        .environment(\.todoStore, store)
        .task { store.todos = [.init(id: 1000, title: "seeded", done: false)] }
    }
}

@MainActor @Suite struct TodoAcceptanceTests {
    private func makeApp() -> (Runtime<MockBackend>, MockBackend, TestScheduler, Counters) {
        let backend = MockBackend(); let sched = TestScheduler(); let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TodoApp(counters: counters), scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched, counters)
    }

    @Test func addTodoViaControlledInputAndEnter() async {
        let (rt, backend, sched, _) = makeApp()
        await Task.yield(); await Task.yield(); sched.pump()   // .task seeds one todo
        let input = findFirst(backend.container, tag: "input")!
        rt.dispatch(input.events["input"]!, payload: InputEvent(value: "buy milk"))
        sched.pump()
        rt.dispatch(input.events["keydown"]!, payload: KeyEvent(key: "Enter", repeated: false))
        sched.pump()
        #expect(findAll(backend.container, tag: "li").count == 2)
        #expect(input.props["value"] == .string(""))            // draft cleared
    }

    @Test func toggleDoesNotReevaluateSiblingRows() async {
        let (rt, backend, sched, counters) = makeApp()
        await Task.yield(); await Task.yield(); sched.pump()
        let input = findFirst(backend.container, tag: "input")!
        for title in ["a", "b"] {
            rt.dispatch(input.events["input"]!, payload: InputEvent(value: title)); sched.pump()
            rt.dispatch(input.events["keydown"]!, payload: KeyEvent(key: "Enter", repeated: false)); sched.pump()
        }
        let before = counters.byLabel
        let checkbox = findAll(backend.container, tag: "input").first { $0.attrs["type"] == "checkbox" }!
        rt.dispatch(checkbox.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()
        // spec §9 invalidation acceptance: exactly ONE row re-evaluated…
        let after = counters.byLabel
        let changedRows = after.filter { $0.key.hasPrefix("row-") && before[$0.key] != $0.value }
        #expect(changedRows.count == 1)
        // …and the count label updated (Observation: RemainingLabel read store.todos)
        let counts = findAll(backend.container, tag: "p")
        #expect(counts.contains { ($0.children.first?.text ?? "").contains("items left") })
    }

    @Test func filterSwitchesVisibleRows() async {
        let (rt, backend, sched, _) = makeApp()
        await Task.yield(); await Task.yield(); sched.pump()
        let checkbox = findAll(backend.container, tag: "input").first { $0.attrs["type"] == "checkbox" }!
        rt.dispatch(checkbox.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()
        let completedBtn = findAll(backend.container, tag: "button").first { $0.children.first?.text == "completed" }!
        rt.dispatch(completedBtn.events["click"]!)
        sched.pump()
        #expect(findAll(backend.container, tag: "li").count == 1)
        let activeBtn = findAll(backend.container, tag: "button").first { $0.children.first?.text == "active" }!
        rt.dispatch(activeBtn.events["click"]!)
        sched.pump()
        #expect(findAll(backend.container, tag: "li").isEmpty)
    }
}
```

Note: the sibling-row invalidation assertion depends on `TodoRow` receiving the todo VALUE as a prop — toggling row 1 re-renders `TodoApp` (its body reads `store.todos`), whose subtree pass re-evaluates rows whose props changed. If ALL rows re-evaluate, that is a real finding: it means the parent pass re-runs every child body regardless of prop equality — record it and relax the assertion to `changedRows.count <= 2` ONLY if the reconciler design genuinely implies it (component bodies re-run when the parent re-resolves; phase-2 scoping is per dirty OWNER, not per prop-diff). Read spec §2.1 before touching this test: the expected outcome under the spec is that the PARENT re-render re-evaluates all visible rows (SwiftUI-equivalent semantics), so the honest assertion is on the DOM: exactly one `li` changed class. Prefer asserting DOM stability:

```swift
// honest alternative if body counters prove parent-pass re-evaluation:
// assert li count unchanged and only one li's class flipped to "done"
```

Decide at implementation time, document the choice in the test comment.

- [ ] **Step 2: Example app** — `Examples/TodoMVC/`:

`Package.swift` (copy Counter's, rename `Counter` → `TodoMVC`):

```swift
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "TodoMVC",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(name: "TodoMVC", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        ], path: "Sources", swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
```

`Sources/main.swift` — same structure as the native test fixture (TodoStore/TodoRow/RemainingLabel/TodoApp without counters) plus:

```swift
import SwiftWUI
import SwiftWUIDOM
import Observation
#if arch(wasm32)
import JavaScriptKit
#endif

// …TodoStore / StoreKey / Filter / TodoRow / RemainingLabel exactly as in
// TodoAcceptanceTests (minus Counters), with a real async load:
//   func load() async {
//       try? await Task.sleep(nanoseconds: 300_000_000)
//       todos = [Todo(id: 1, title: "Learn SwiftWUI", done: true),
//                Todo(id: 2, title: "Ship phase 2", done: false)]
//       nextID = 3
//   }
// TodoApp body additionally:
//   .task { await store.load() }
//   .onChange(of: filter) { _, new in
//       #if arch(wasm32)
//       JSObject.global.document.title = .string("todos — \(new.rawValue)")
//       #endif
//   }

@main
struct TodoMVCApp: App {
    var body: some Tag { TodoApp() }
}
```

`index.html`, `package.json` — copy from `Examples/Counter/` verbatim (retitle to "SwiftWUI TodoMVC").

- [ ] **Step 3: Run the gates**

Run: `swift test 2>&1 | tail -5` — expected PASS.
Run: `cd Examples/TodoMVC && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug 2>&1 | tail -3` — expected build success.

- [ ] **Step 4: Browser acceptance** (manual or browser-automation session)

Run: `npm --prefix Examples/TodoMVC install && npm --prefix Examples/TodoMVC run dev -- --port 8080`
Checklist (all must hold):
1. Initial load shows 2 seeded todos after ~300 ms (`.task` + JavaScriptEventLoop works).
2. Typing + Enter adds a todo; the field clears; cursor never jumps while typing (property equality guard).
3. Checkbox toggles line-through class; "N items left" updates (Observation via Environment).
4. Filters all/active/completed show correct subsets; document title updates (`onChange`).
5. No console errors; no listener churn warnings.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(example): TodoMVC — phase-2 acceptance app + native acceptance suite"
```

---

## Plan Self-Review Notes

- **Spec coverage:** §2→Tasks 6–7, §3→Task 8, §4→Task 5, §5→Task 9, §6→Tasks 2+10, §7→Tasks 3–4+10, §8→Tasks 1+4, §9→Task 11, §10→tests in every task + Task 7, §11→Tasks 2 (payload drop), 6 (retained guard), 9 (cooperative cancel).
- **Known judgment calls left to the implementer (explicitly bounded):** golden-string exact ordering in Task 3 (requirement: serializer parity); the sibling-row assertion form in Task 11 (bounded to the two options described there).
- All later-task signatures match their producing task's Interfaces block (checked: `dispatch(_:payload:)`, `link(_:at:environment:invalidate:)`, `PropertyValue`, `EffectRequest`, `RetainedComponent`, `componentIndex`, `_forceFullPasses`).
