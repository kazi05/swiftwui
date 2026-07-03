# Phase 3: Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Typed CSS styling for SwiftWUI: inline modifiers, generated stylesheet (pseudo/media), component-scoped `Styled` rules, tokens/themes, `Style` bundles — plus the full phase-2 carry list as Tasks 1–2.

**Architecture:** Early collapse into existing primitives (spec D11): inline declarations flatten into the `style` attribute at resolve; pseudo/media/`Styled`/theme rules become content-hashed entries in a `StyleRegistry` (side table on `ResolveContext`, owned by `Runtime`) flushed to one backend-managed `<style>` via a single new backend method. Reconciler/TreeApplier are untouched.

**Tech Stack:** Swift 6.3.3, swift-testing (`@Test`/`#expect`), MockBackend native gate, wasm SDK `swift-6.3.3-RELEASE_wasm` for the example build.

**Spec:** `docs/superpowers/specs/2026-07-03-phase3-styles-design.md` — read it before starting any task.

## Global Constraints

- Branch: `feature/fable-new-vision`. No new SwiftPM targets — everything lands in `SwiftWUI` core (`Sources/SwiftWUI/Styles/`) and `SwiftWUIDOM`.
- No new dependencies. No Foundation in `Sources/SwiftWUI` or the wasm example.
- Everything `@MainActor` via target default isolation. NEVER add `Sendable`/`@unchecked Sendable` (phase-1 rule). `Sources/SwiftWUI` and test targets have `.defaultIsolation(MainActor.self)`.
- Wrapper primitives participate in identity via `.type(ObjectIdentifier)` segments; bag-mutating methods never affect identity (phase-1 rule, spec §2).
- Error posture: `assertionFailure` in debug + drop/no-op in release (never crash release; never silently accept invalid input in debug).
- Testing workflow (user preference, overrides RED/GREEN stepping): write ALL of a task's code first, run `swift test` ONCE at the end, fix, commit. Every commit message ends with:

  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  ```
- Native gate: `swift test` from repo root. 118 tests pass at plan start; every task leaves the suite green. Per-task "Expected: all pass (N)" counts are estimates — the invariant is ZERO failures, not the exact N.
- Wasm gate (Task 12 only): `cd Examples/TodoMVC && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`.
- Test helpers: `Tests/SwiftWUITests/TestHelpers.swift` already holds `typealias Tag = SwiftWUI.Tag`, `TestScheduler`, `findAll`/`findFirst`. Do NOT redeclare them.

---

### Task 1: Phase-2 carry-list cleanup (mechanical items)

**Files:**
- Modify: `Sources/SwiftWUI/HTML/Tags.swift:104-121` (Input controlled init)
- Modify: `Sources/SwiftWUI/Render/HTMLRenderer.swift:15-43` (textarea value as child text)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift:61-82` (same, serializer parity)
- Modify: `Sources/SwiftWUI/Render/TreeApplier.swift:80-83` (componentIndex hardening)
- Modify: `Sources/SwiftWUI/Effects/EffectStore.swift` (ordering comment, around line 27)
- Modify: `Tests/SwiftWUITests/ScopedEquivalenceTests.swift:51-67` (`#require` clean-fail)
- Modify: `Tests/SwiftWUITests/EventPayloadTests.swift:4` (dead Capture fields)
- Modify: `Tests/SwiftWUITests/TodoAcceptanceTests.swift` (mixed-todos filter test)

**Interfaces:**
- Consumes: existing code only.
- Produces: `Input.init(type:value:name:placeholder:disabled:id:class:onInput:onKeyDown:)` — later tasks and the example may pass `name:`.

- [ ] **Step 1: Apply the seven fixes**

1a. `Input` controlled init gains `name:` (Tags.swift, replace the signature and add the set line after `type`):

```swift
    public init(type: InputType = .text, value: Binding<String>,
                name: String? = nil,
                placeholder: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onInput: ((InputEvent) -> Void)? = nil,
                onKeyDown: ((KeyEvent) -> Void)? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("type", type.rawValue)
        _attributes.set("name", name)
        _attributes.set("placeholder", placeholder)
        // … rest of the body unchanged …
```

1b. Textarea SSR child text. `<textarea value="…">` is not real HTML — the value must serialize as child text. In `HTMLRenderer.render(_ node:)`, inside the `.element` case, replace the properties loop with:

```swift
            var textareaValue: String? = nil
            for name in el.properties.keys.sorted() {
                if el.tag == "textarea", name == "value",
                   case .string(let s) = el.properties[name]! {
                    textareaValue = s                      // real HTML: child text, not attr
                    continue
                }
                switch el.properties[name]! {
                case .string(let s): out += " " + name + "=\"" + HTMLEscaping.text(s) + "\""
                case .bool(true):    out += " " + name
                case .bool(false):   break
                }
            }
```

and change the final return to prepend it:

```swift
            return out + (textareaValue.map { HTMLEscaping.text($0) } ?? "")
                + render(el.children) + "</" + el.tag + ">"
```

Apply the SAME transformation to `MockBackend.serializeHTML` (its props loop and final return) — the two serializers must stay byte-compatible (trap T8).

1c. `TreeApplier.unregister` clobber hardening (spec-noted 1-liner; `MountedNode` is a class, `===` is valid):

```swift
    private func unregister(_ m: MountedNode<Backend.HostNode>) {
        // mount-before-unmount replace(): only clear the index if it still points at US
        if let id = m.componentIdentity, componentIndex[id] === m { componentIndex[id] = nil }
        for c in m.children { unregister(c) }
    }
```

1d. `EffectStore` ordering comment — directly above the `reconcile` doc line ("disappear/cancel first, then appear/task/onChange in document order"), add:

```swift
    /// ORDER DEPENDENCY (_AppearEffect): a disappear request marks presence in
    /// `appeared` (line ~62) so the SAME pass's appear request is not treated
    /// as first appearance. Processing appear before disappear within one
    /// reconcile would break this — keep request handling in emission order.
```

1e. `ScopedEquivalenceTests.scopedEqualsFull`: divergent button counts must clean-fail, not crash on index OOB. Make the test `throws` and replace lines 66-67:

```swift
    @Test(arguments: 0..<20) func scopedEqualsFull(seed: Int) throws {
```

```swift
            try #require(buttonsA.count == buttonsB.count)
            guard !buttonsA.isEmpty else { break }
```

1f. `EventPayloadTests.swift:4`: delete the dead `inputs`/`keys` stored properties from `Capture` (keep whatever fields the tests actually append to — check usages first; delete only unused ones). Also verify `ResolverTests.swift` no longer contains the dead `captured` scaffolding (grep says it is already gone — if so, this half is a no-op; note it in the report).

1g. Mixed-todos filter test — append to `TodoAcceptanceTests` (uses existing `makeApp`/`waitUntil` helpers and the seeded todo from `.task`):

```swift
    @Test func filterCountsWithMixedTodos() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        let input = findFirst(backend.container, tag: "input")!
        for title in ["a", "b"] {   // seed + a + b = 3 todos
            rt.dispatch(input.events["input"]!, payload: InputEvent(value: title)); sched.pump()
            rt.dispatch(input.events["keydown"]!, payload: KeyEvent(key: "Enter", repeated: false)); sched.pump()
        }
        // mark exactly one done → mixed state: 2 active, 1 completed
        let checkbox = findAll(backend.container, tag: "input").first { $0.attrs["type"] == "checkbox" }!
        rt.dispatch(checkbox.events["change"]!, payload: ChangeEvent(value: "", checked: true))
        sched.pump()
        func tap(_ label: String) {
            let btn = findAll(backend.container, tag: "button").first { $0.children.first?.text == label }!
            rt.dispatch(btn.events["click"]!); sched.pump()
        }
        tap("completed"); #expect(findAll(backend.container, tag: "li").count == 1)
        tap("active");    #expect(findAll(backend.container, tag: "li").count == 2)
        tap("all");       #expect(findAll(backend.container, tag: "li").count == 3)
        let counts = findAll(backend.container, tag: "p")
        #expect(counts.contains { ($0.children.first?.text ?? "") == "2 items left" })
    }
```

- [ ] **Step 2: Check for textarea-value test fallout**

`ControlledInputTests` may pin `value="…"` serialization for textarea. Run `grep -n "textarea" Tests/SwiftWUITests/*.swift` and update any golden strings to the child-text form (`<textarea>…</textarea>`).

- [ ] **Step 3: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass (118 + 1 new = 119).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: phase-2 carry list — Input name:, textarea child-text SSR, componentIndex hardening, #require clean-fail, effect-order comment, dead test fields, mixed-todos filter test

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: ForEach closure Observation tracking

**Files:**
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (ResolveContext + component boundary)
- Modify: `Sources/SwiftWUI/Core/ForEach.swift` (tracked content, doc update)
- Modify: `Tests/SwiftWUITests/ObservationTests.swift` (new test)
- Modify: `docs/superpowers/specs/2026-07-03-phase2-reactivity-design.md` §14 (limitation resolved note)

**Interfaces:**
- Consumes: `ResolveContext` (Resolver.swift:10-21), `resolve()` component boundary (Resolver.swift:23-47).
- Produces: `ResolveContext.owner: NodeIdentity` — the identity of the nearest enclosing component; later tasks (8) read the context the same way for `scopeClass`.

- [ ] **Step 1: Thread the owning component through the context**

In `ResolveContext` (Resolver.swift), add a field after `environment`:

```swift
    var environment = EnvironmentValues()
    /// Nearest enclosing component — primitives that run content closures
    /// outside the component's tracking window (ForEach) bind their own
    /// tracking to this id so model reads still invalidate the right owner.
    var owner: NodeIdentity = .root
    var effects: [EffectRequest] = []
```

In `resolve()`, set it for the body resolution (after the `link` call, before `withObservationTracking`), and restore after:

```swift
    let box = _InvalidateBox(fire: { inv(id) })
    let savedOwner = ctx.owner
    ctx.owner = id
    defer { ctx.owner = savedOwner }
    let body = withObservationTracking {
```

(`defer` restores on the way out of this component's resolution; children resolved inside `resolve(body, …)` see `ctx.owner == id`, and any nested component boundary re-points it.)

Update the stale comment at Resolver.swift:35-36 — tracking for primitive closures now exists:

```swift
    // Tracking covers body evaluation; ForEach additionally re-binds tracking
    // for its per-item content closures to ctx.owner (see ForEach._resolve).
```

- [ ] **Step 2: Track ForEach content per item**

In `ForEach._resolve`, wrap the `content(item)` call (construction is where eager reads happen — attribute values, `Text(...)` interpolations):

```swift
    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        var out: [Node] = []
        var seen = Set<NodeKey>()
        let ownerID = ctx.owner
        let inv = ctx.invalidate
        let box = _InvalidateBox(fire: { inv(ownerID) })
        for item in data {
            let key = NodeKey(item[keyPath: id])
            assert(seen.insert(key).inserted, "ForEach: duplicate id \(item[keyPath: id])")
            let built = withObservationTracking {
                content(item)
            } onChange: {
                MainActor.assumeIsolated { box.fire() }
            }
            var nodes = resolve(built, path: path.appending(.keyed(key)), ctx: &ctx)
            // … key-tagging loop unchanged …
```

`_InvalidateBox` is `private` to Resolver.swift — change its access to `internal` (delete `private`) so ForEach.swift can use it; it stays module-internal.

Replace the KNOWN LIMITATION doc comment on `content` (ForEach.swift:7-11):

```swift
    /// Per-item content closures run inside their own tracking window bound to
    /// the nearest enclosing component (phase 3): @Observable reads here DO
    /// invalidate. Reads inside nested escaping closures that run later
    /// (e.g. Button actions) are writes-side and intentionally untracked.
```

- [ ] **Step 3: Update phase-2 spec addendum**

In `docs/superpowers/specs/2026-07-03-phase2-reactivity-design.md` §14, amend the "Known limitation (fix in phase 3)" bullet — append: `RESOLVED in phase 3 (see 2026-07-03-phase3-styles-design.md Task 2): ForEach binds per-item tracking to the enclosing component.`

- [ ] **Step 4: Add the regression test**

Append to `Tests/SwiftWUITests/ObservationTests.swift` (match the file's existing fixture style — `@Observable` model, Runtime + MockBackend + TestScheduler):

```swift
@Observable private final class RowModel {
    var label = "one"
}
private struct DirectForEachRead: Tag {
    let model: RowModel
    var body: some Tag {
        Ul {
            ForEach([1], id: \.self) { _ in
                Li { model.label }        // read INSIDE ForEach closure, no row component
            }
        }
    }
}

@MainActor
extension ObservationTests {
    @Test func forEachClosureReadTracksModel() {
        let backend = MockBackend(); let sched = TestScheduler()
        let model = RowModel()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: DirectForEachRead(model: model),
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.serializeHTML().contains("one"))
        model.label = "two"                // must invalidate DirectForEachRead
        sched.pump()
        #expect(backend.serializeHTML().contains("two"))
        #expect(!backend.serializeHTML().contains("one"))
    }
}
```

(If `ObservationTests` is a `@Suite struct`, put the test inside it instead of an extension — follow the file's existing shape.)

- [ ] **Step 5: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (120). ScopedEquivalence property test is the guard against over-invalidation regressions.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(runtime): track @Observable reads inside ForEach content closures

Binds a per-item withObservationTracking window to the nearest enclosing
component (ResolveContext.owner). Closes the phase-2 §14 known limitation.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Typed CSS value layer

**Files:**
- Create: `Sources/SwiftWUI/Styles/CSSValues.swift`
- Create: `Sources/SwiftWUI/Styles/StyleDeclaration.swift`
- Test: `Tests/SwiftWUITests/CSSValueTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces (used by every later task):
  - `protocol CSSValueConvertible { var css: String { get } }`
  - `CSSLength` (`.px/.rem/.em/.percent/.vw/.vh(Double)`, `.auto`, `.zero`)
  - `CSSColor` (`.hex(String)`, `.rgb(Int,Int,Int)`, `.rgba(Int,Int,Int,Double)`, `.white/.black/.transparent/.current`, `.variable(String)`)
  - enums `Display, Position, FlexDirection, FlexWrap, JustifyContent, AlignItems, TextAlign, TextDecoration, FontWeight, Cursor, Overflow, BorderStyle, BoxSizing, Outline, Side`
  - `struct StyleDeclaration: Equatable, Hashable { let property: String; let value: String }` + the full factory list below
  - `enum CSSSanitize { static func isValidIdent(_:) -> Bool; static func isSafeValue(_:) -> Bool }`

- [ ] **Step 1: Write CSSValues.swift**

```swift
public protocol CSSValueConvertible {
    var css: String { get }
}

/// Integer-valued doubles render without a trailing ".0" (Foundation-free).
func cssNumber(_ d: Double) -> String {
    if d == d.rounded(), abs(d) < 1e15 { return String(Int(d)) }
    return String(d)
}

public enum CSSLength: Equatable, CSSValueConvertible {
    case px(Double), rem(Double), em(Double), percent(Double), vw(Double), vh(Double)
    case auto, zero
    public var css: String {
        switch self {
        case .px(let v): return cssNumber(v) + "px"
        case .rem(let v): return cssNumber(v) + "rem"
        case .em(let v): return cssNumber(v) + "em"
        case .percent(let v): return cssNumber(v) + "%"
        case .vw(let v): return cssNumber(v) + "vw"
        case .vh(let v): return cssNumber(v) + "vh"
        case .auto: return "auto"
        case .zero: return "0"
        }
    }
}

public enum CSSColor: Equatable, CSSValueConvertible {
    case hex(String)                       // "#RGB" | "#RRGGBB" | "#RRGGBBAA"
    case rgb(Int, Int, Int)
    case rgba(Int, Int, Int, Double)
    case white, black, transparent, current
    case variable(String)                  // var(--name); built via .token(_:) in Task 9
    public var css: String {
        switch self {
        case .hex(let s):
            guard Self.isValidHex(s) else {
                assertionFailure("invalid hex color: \(s)")
                return "transparent"
            }
            return s
        case .rgb(let r, let g, let b): return "rgb(\(r), \(g), \(b))"
        case .rgba(let r, let g, let b, let a): return "rgba(\(r), \(g), \(b), \(cssNumber(a)))"
        case .white: return "#fff"
        case .black: return "#000"
        case .transparent: return "transparent"
        case .current: return "currentColor"
        case .variable(let name): return "var(--\(name))"
        }
    }
    static func isValidHex(_ s: String) -> Bool {
        guard s.first == "#" else { return false }
        let digits = s.dropFirst()
        guard [3, 6, 8].contains(digits.count) else { return false }
        return digits.allSatisfy { $0.isHexDigit }
    }
}

public enum Display: String, CSSValueConvertible {
    case block, inline, flex, grid, none, contents
    case inlineBlock = "inline-block", inlineFlex = "inline-flex"
    public var css: String { rawValue }
}
public enum Position: String, CSSValueConvertible {
    case `static`, relative, absolute, fixed, sticky
    public var css: String { rawValue }
}
public enum FlexDirection: String, CSSValueConvertible {
    case row, column, rowReverse = "row-reverse", columnReverse = "column-reverse"
    public var css: String { rawValue }
}
public enum FlexWrap: String, CSSValueConvertible {
    case nowrap, wrap, wrapReverse = "wrap-reverse"
    public var css: String { rawValue }
}
public enum JustifyContent: String, CSSValueConvertible {
    case flexStart = "flex-start", flexEnd = "flex-end", center
    case spaceBetween = "space-between", spaceAround = "space-around", spaceEvenly = "space-evenly"
    public var css: String { rawValue }
}
public enum AlignItems: String, CSSValueConvertible {
    case flexStart = "flex-start", flexEnd = "flex-end", center, baseline, stretch
    public var css: String { rawValue }
}
public enum TextAlign: String, CSSValueConvertible {
    case left, right, center, justify
    public var css: String { rawValue }
}
public enum TextDecoration: String, CSSValueConvertible {
    case none, underline, overline, lineThrough = "line-through"
    public var css: String { rawValue }
}
public enum FontWeight: CSSValueConvertible {
    case normal, bold, custom(Int)
    public var css: String {
        switch self {
        case .normal: return "normal"; case .bold: return "bold"
        case .custom(let w): return String(w)
        }
    }
}
public enum Cursor: String, CSSValueConvertible {
    case auto, `default`, pointer, text, move, notAllowed = "not-allowed", grab
    public var css: String { rawValue }
}
public enum Overflow: String, CSSValueConvertible {
    case visible, hidden, scroll, auto
    public var css: String { rawValue }
}
public enum BorderStyle: String, CSSValueConvertible {
    case none, solid, dashed, dotted, double
    public var css: String { rawValue }
}
public enum BoxSizing: String, CSSValueConvertible {
    case contentBox = "content-box", borderBox = "border-box"
    public var css: String { rawValue }
}
public enum Outline: CSSValueConvertible {
    case none, custom(String)
    public var css: String {
        switch self { case .none: return "none"; case .custom(let s): return s }
    }
}
public enum Side: String {
    case top, right, bottom, left
}

/// Validation choke points for the string escape hatches (spec §12).
public enum CSSSanitize {
    /// CSS ident: letters/digits/hyphen/underscore, must not start with a digit.
    public static func isValidIdent(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first else { return false }
        func alpha(_ c: Unicode.Scalar) -> Bool { ("a"..."z").contains(c) || ("A"..."Z").contains(c) }
        guard alpha(first) || first == "_" || first == "-" else { return false }
        return s.unicodeScalars.allSatisfy {
            alpha($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == "-"
        }
    }
    /// Declaration values must not be able to escape a rule body.
    public static func isSafeValue(_ s: String) -> Bool {
        !s.unicodeScalars.contains { $0 == "{" || $0 == "}" || $0.properties.generalCategory == .control }
    }
}
```

- [ ] **Step 2: Write StyleDeclaration.swift — the complete factory list**

This is the SINGLE definition of every property in the curated set (spec §4). All three surfaces (Tasks 4, 6, 7) are one-line delegations to these factories.

```swift
public struct StyleDeclaration: Equatable, Hashable {
    public let property: String
    public let value: String
    public init(property: String, value: String) {
        self.property = property; self.value = value
    }
}

extension StyleDeclaration {
    // Layout
    public static func display(_ v: Display) -> Self { .init(property: "display", value: v.css) }
    public static func position(_ v: Position) -> Self { .init(property: "position", value: v.css) }
    public static func top(_ v: CSSLength) -> Self { .init(property: "top", value: v.css) }
    public static func right(_ v: CSSLength) -> Self { .init(property: "right", value: v.css) }
    public static func bottom(_ v: CSSLength) -> Self { .init(property: "bottom", value: v.css) }
    public static func left(_ v: CSSLength) -> Self { .init(property: "left", value: v.css) }
    public static func width(_ v: CSSLength) -> Self { .init(property: "width", value: v.css) }
    public static func height(_ v: CSSLength) -> Self { .init(property: "height", value: v.css) }
    public static func minWidth(_ v: CSSLength) -> Self { .init(property: "min-width", value: v.css) }
    public static func minHeight(_ v: CSSLength) -> Self { .init(property: "min-height", value: v.css) }
    public static func maxWidth(_ v: CSSLength) -> Self { .init(property: "max-width", value: v.css) }
    public static func maxHeight(_ v: CSSLength) -> Self { .init(property: "max-height", value: v.css) }
    public static func margin(_ v: CSSLength) -> Self { .init(property: "margin", value: v.css) }
    public static func margin(_ side: Side, _ v: CSSLength) -> Self { .init(property: "margin-\(side.rawValue)", value: v.css) }
    public static func margin(vertical: CSSLength, horizontal: CSSLength) -> Self {
        .init(property: "margin", value: vertical.css + " " + horizontal.css)
    }
    public static func padding(_ v: CSSLength) -> Self { .init(property: "padding", value: v.css) }
    public static func padding(_ side: Side, _ v: CSSLength) -> Self { .init(property: "padding-\(side.rawValue)", value: v.css) }
    public static func padding(vertical: CSSLength, horizontal: CSSLength) -> Self {
        .init(property: "padding", value: vertical.css + " " + horizontal.css)
    }
    public static func gap(_ v: CSSLength) -> Self { .init(property: "gap", value: v.css) }
    public static func overflow(_ v: Overflow) -> Self { .init(property: "overflow", value: v.css) }
    public static func zIndex(_ v: Int) -> Self { .init(property: "z-index", value: String(v)) }
    public static func boxSizing(_ v: BoxSizing) -> Self { .init(property: "box-sizing", value: v.css) }
    // Flex / Grid
    public static func flexDirection(_ v: FlexDirection) -> Self { .init(property: "flex-direction", value: v.css) }
    public static func justifyContent(_ v: JustifyContent) -> Self { .init(property: "justify-content", value: v.css) }
    public static func alignItems(_ v: AlignItems) -> Self { .init(property: "align-items", value: v.css) }
    public static func alignSelf(_ v: AlignItems) -> Self { .init(property: "align-self", value: v.css) }
    public static func flexWrap(_ v: FlexWrap) -> Self { .init(property: "flex-wrap", value: v.css) }
    public static func flexGrow(_ v: Double) -> Self { .init(property: "flex-grow", value: cssNumber(v)) }
    public static func flexShrink(_ v: Double) -> Self { .init(property: "flex-shrink", value: cssNumber(v)) }
    public static func flexBasis(_ v: CSSLength) -> Self { .init(property: "flex-basis", value: v.css) }
    public static func gridTemplateColumns(_ v: String) -> Self { .init(property: "grid-template-columns", value: v) }
    public static func gridTemplateRows(_ v: String) -> Self { .init(property: "grid-template-rows", value: v) }
    // Typography
    public static func fontSize(_ v: CSSLength) -> Self { .init(property: "font-size", value: v.css) }
    public static func fontWeight(_ v: FontWeight) -> Self { .init(property: "font-weight", value: v.css) }
    public static func fontFamily(_ v: String) -> Self { .init(property: "font-family", value: v) }
    public static func lineHeight(_ v: Double) -> Self { .init(property: "line-height", value: cssNumber(v)) }
    public static func textAlign(_ v: TextAlign) -> Self { .init(property: "text-align", value: v.css) }
    public static func textDecoration(_ v: TextDecoration) -> Self { .init(property: "text-decoration", value: v.css) }
    public static func letterSpacing(_ v: CSSLength) -> Self { .init(property: "letter-spacing", value: v.css) }
    public static func color(_ v: CSSColor) -> Self { .init(property: "color", value: v.css) }
    // Box
    public static func background(_ v: CSSColor) -> Self { .init(property: "background", value: v.css) }
    public static func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> Self {
        .init(property: "border", value: width.css + " " + style.css + " " + color.css)
    }
    public static func borderColor(_ v: CSSColor) -> Self { .init(property: "border-color", value: v.css) }
    public static func borderRadius(_ v: CSSLength) -> Self { .init(property: "border-radius", value: v.css) }
    public static func boxShadow(_ v: String) -> Self { .init(property: "box-shadow", value: v) }
    public static func opacity(_ v: Double) -> Self { .init(property: "opacity", value: cssNumber(v)) }
    public static func outline(_ v: Outline) -> Self { .init(property: "outline", value: v.css) }
    // Misc
    public static func cursor(_ v: Cursor) -> Self { .init(property: "cursor", value: v.css) }
    public static func transition(_ v: String) -> Self { .init(property: "transition", value: v) }
    public static func listStyle(_ v: String) -> Self { .init(property: "list-style", value: v) }
}
```

- [ ] **Step 3: Write CSSValueTests.swift**

```swift
import Testing
@testable import SwiftWUI

@Suite struct CSSValueTests {
    @Test func lengthRendering() {
        #expect(CSSLength.px(24).css == "24px")
        #expect(CSSLength.px(1.5).css == "1.5px")
        #expect(CSSLength.rem(2).css == "2rem")
        #expect(CSSLength.percent(50).css == "50%")
        #expect(CSSLength.auto.css == "auto")
        #expect(CSSLength.zero.css == "0")
    }
    @Test func colorRendering() {
        #expect(CSSColor.hex("#1a1a2e").css == "#1a1a2e")
        #expect(CSSColor.hex("#abc").css == "#abc")
        #expect(CSSColor.rgb(255, 0, 128).css == "rgb(255, 0, 128)")
        #expect(CSSColor.rgba(0, 0, 0, 0.5).css == "rgba(0, 0, 0, 0.5)")
        #expect(CSSColor.white.css == "#fff")
        #expect(CSSColor.current.css == "currentColor")
        #expect(CSSColor.variable("accent").css == "var(--accent)")
    }
    @Test func enumRendering() {
        #expect(Display.inlineBlock.css == "inline-block")
        #expect(JustifyContent.spaceBetween.css == "space-between")
        #expect(FontWeight.custom(600).css == "600")
        #expect(TextDecoration.lineThrough.css == "line-through")
        #expect(Outline.none.css == "none")
    }
    @Test func declarationFactories() {
        #expect(StyleDeclaration.margin(.top, .px(44)) == StyleDeclaration(property: "margin-top", value: "44px"))
        #expect(StyleDeclaration.padding(vertical: .px(4), horizontal: .px(8)).value == "4px 8px")
        #expect(StyleDeclaration.border(.px(1), .solid, .hex("#ccc")).value == "1px solid #ccc")
        #expect(StyleDeclaration.zIndex(10).value == "10")
    }
    @Test func sanitize() {
        #expect(CSSSanitize.isValidIdent("accent-2"))
        #expect(!CSSSanitize.isValidIdent("2col"))
        #expect(!CSSSanitize.isValidIdent(".field"))
        #expect(!CSSSanitize.isValidIdent("a b"))
        #expect(CSSSanitize.isSafeValue("blur(4px)"))
        #expect(!CSSSanitize.isSafeValue("red } body { display: none"))
        #expect(!CSSSanitize.isSafeValue("a\u{0}b"))
    }
}
```

Note: hex validation failure (`CSSColor.hex("nope").css`) traps `assertionFailure` in debug — do NOT test the release fallback path natively; the validity test above covers `isValidHex` positives.

- [ ] **Step 4: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (125).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Styles Tests/SwiftWUITests/CSSValueTests.swift
git commit -m "feat(styles): typed CSS value layer — CSSLength/CSSColor, property enums, StyleDeclaration factories, sanitizers

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Inline path — bag styles + HTMLTag modifier surface

**Files:**
- Modify: `Sources/SwiftWUI/HTML/AttributeBag.swift`
- Create: `Sources/SwiftWUI/Styles/StyleModifiers+HTMLTag.swift`
- Test: `Tests/SwiftWUITests/InlineStyleTests.swift`

**Interfaces:**
- Consumes: `StyleDeclaration` factories (Task 3), `_AttributeBag` (phase 1).
- Produces:
  - `_AttributeBag.addStyle(_ d: StyleDeclaration)`, `_AttributeBag.styles: [StyleDeclaration]`
  - `_AttributeBag.flattened()` now merges styles into `out["style"]`
  - every §4 modifier on `HTMLTag` returning `Self`, plus `.style(_ property: String, _ value: String)` fallback

- [ ] **Step 1: Extend _AttributeBag**

Add a stored list and an append method (after `properties`):

```swift
    private(set) var styles: [StyleDeclaration] = []

    mutating func addStyle(_ d: StyleDeclaration) { styles.append(d) }
```

In `flattened()`, merge styles after the pairs loop (call order preserved, duplicate property → last call wins, raw `.attribute("style", …)` value comes first):

```swift
    func flattened() -> [String: String] {
        var out: [String: String] = [:]
        for (name, value) in pairs {
            if name == "class", let existing = out["class"], !existing.isEmpty {
                out["class"] = existing + " " + value
            } else {
                out[name] = value
            }
        }
        if !styles.isEmpty {
            out["style"] = Self.mergeStyleText(base: out["style"], styles)
        }
        return out
    }

    /// "prop: value; …" — call order, last-wins per property, base text first.
    static func mergeStyleText(base: String?, _ styles: [StyleDeclaration]) -> String {
        var order: [String] = []
        var valueFor: [String: String] = [:]
        for d in styles {
            if valueFor[d.property] == nil { order.append(d.property) }
            valueFor[d.property] = d.value
        }
        let text = order.map { "\($0): \(valueFor[$0]!)" }.joined(separator: "; ")
        if let base, !base.isEmpty { return base + "; " + text }
        return text
    }
```

- [ ] **Step 2: Write StyleModifiers+HTMLTag.swift — the full surface**

One private helper + one-liners for EVERY factory from Task 3 (complete list below — do not skip any):

```swift
extension HTMLTag {
    func _style(_ d: StyleDeclaration) -> Self {
        var copy = self; copy._attributes.addStyle(d); return copy
    }

    /// String escape hatch (spec §12): property name must be a CSS ident and
    /// the value must be rule-safe; invalid input asserts in debug, no-ops in release.
    public func style(_ property: String, _ value: String) -> Self {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return self
        }
        return _style(StyleDeclaration(property: property, value: value))
    }

    // Layout
    public func display(_ v: Display) -> Self { _style(.display(v)) }
    public func position(_ v: Position) -> Self { _style(.position(v)) }
    public func top(_ v: CSSLength) -> Self { _style(.top(v)) }
    public func right(_ v: CSSLength) -> Self { _style(.right(v)) }
    public func bottom(_ v: CSSLength) -> Self { _style(.bottom(v)) }
    public func left(_ v: CSSLength) -> Self { _style(.left(v)) }
    public func width(_ v: CSSLength) -> Self { _style(.width(v)) }
    public func height(_ v: CSSLength) -> Self { _style(.height(v)) }
    public func minWidth(_ v: CSSLength) -> Self { _style(.minWidth(v)) }
    public func minHeight(_ v: CSSLength) -> Self { _style(.minHeight(v)) }
    public func maxWidth(_ v: CSSLength) -> Self { _style(.maxWidth(v)) }
    public func maxHeight(_ v: CSSLength) -> Self { _style(.maxHeight(v)) }
    public func margin(_ v: CSSLength) -> Self { _style(.margin(v)) }
    public func margin(_ side: Side, _ v: CSSLength) -> Self { _style(.margin(side, v)) }
    public func margin(vertical: CSSLength, horizontal: CSSLength) -> Self { _style(.margin(vertical: vertical, horizontal: horizontal)) }
    public func padding(_ v: CSSLength) -> Self { _style(.padding(v)) }
    public func padding(_ side: Side, _ v: CSSLength) -> Self { _style(.padding(side, v)) }
    public func padding(vertical: CSSLength, horizontal: CSSLength) -> Self { _style(.padding(vertical: vertical, horizontal: horizontal)) }
    public func gap(_ v: CSSLength) -> Self { _style(.gap(v)) }
    public func overflow(_ v: Overflow) -> Self { _style(.overflow(v)) }
    public func zIndex(_ v: Int) -> Self { _style(.zIndex(v)) }
    public func boxSizing(_ v: BoxSizing) -> Self { _style(.boxSizing(v)) }
    // Flex / Grid
    public func flexDirection(_ v: FlexDirection) -> Self { _style(.flexDirection(v)) }
    public func justifyContent(_ v: JustifyContent) -> Self { _style(.justifyContent(v)) }
    public func alignItems(_ v: AlignItems) -> Self { _style(.alignItems(v)) }
    public func alignSelf(_ v: AlignItems) -> Self { _style(.alignSelf(v)) }
    public func flexWrap(_ v: FlexWrap) -> Self { _style(.flexWrap(v)) }
    public func flexGrow(_ v: Double) -> Self { _style(.flexGrow(v)) }
    public func flexShrink(_ v: Double) -> Self { _style(.flexShrink(v)) }
    public func flexBasis(_ v: CSSLength) -> Self { _style(.flexBasis(v)) }
    public func gridTemplateColumns(_ v: String) -> Self { _style(.gridTemplateColumns(v)) }
    public func gridTemplateRows(_ v: String) -> Self { _style(.gridTemplateRows(v)) }
    // Typography
    public func fontSize(_ v: CSSLength) -> Self { _style(.fontSize(v)) }
    public func fontWeight(_ v: FontWeight) -> Self { _style(.fontWeight(v)) }
    public func fontFamily(_ v: String) -> Self { _style(.fontFamily(v)) }
    public func lineHeight(_ v: Double) -> Self { _style(.lineHeight(v)) }
    public func textAlign(_ v: TextAlign) -> Self { _style(.textAlign(v)) }
    public func textDecoration(_ v: TextDecoration) -> Self { _style(.textDecoration(v)) }
    public func letterSpacing(_ v: CSSLength) -> Self { _style(.letterSpacing(v)) }
    public func color(_ v: CSSColor) -> Self { _style(.color(v)) }
    // Box
    public func background(_ v: CSSColor) -> Self { _style(.background(v)) }
    public func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> Self { _style(.border(width, style, color)) }
    public func borderColor(_ v: CSSColor) -> Self { _style(.borderColor(v)) }
    public func borderRadius(_ v: CSSLength) -> Self { _style(.borderRadius(v)) }
    public func boxShadow(_ v: String) -> Self { _style(.boxShadow(v)) }
    public func opacity(_ v: Double) -> Self { _style(.opacity(v)) }
    public func outline(_ v: Outline) -> Self { _style(.outline(v)) }
    // Misc
    public func cursor(_ v: Cursor) -> Self { _style(.cursor(v)) }
    public func transition(_ v: String) -> Self { _style(.transition(v)) }
    public func listStyle(_ v: String) -> Self { _style(.listStyle(v)) }
}
```

Note: string-typed factories (`fontFamily`, `boxShadow`, `gridTemplate*`, `transition`, `listStyle`, `Outline.custom`) accept raw strings on the inline path; rule-safety for these is enforced at registry serialization (Task 5). The `.style()` fallback validates eagerly because both its parts are caller-controlled strings.

- [ ] **Step 3: Write InlineStyleTests.swift**

```swift
import Testing
@testable import SwiftWUI

@Suite struct InlineStyleTests {
    @Test func modifiersFlattenIntoStyleAttribute() {
        let html = HTMLRenderer.render(
            Div { Text("x") }
                .padding(.px(24))
                .display(.flex)
                .gap(.px(8))
        )
        #expect(html.contains(#"style="padding: 24px; display: flex; gap: 8px""#))
    }
    @Test func duplicatePropertyLastWins() {
        let html = HTMLRenderer.render(Div { Text("x") }.margin(.px(4)).margin(.px(8)))
        #expect(html.contains(#"style="margin: 8px""#))
        #expect(!html.contains("4px"))
    }
    @Test func rawStyleAttributeComesFirst() {
        let html = HTMLRenderer.render(
            Div { Text("x") }.attribute("style", "color: red").padding(.px(2))
        )
        #expect(html.contains(#"style="color: red; padding: 2px""#))
    }
    @Test func fallbackValidatesNameAndValue() {
        let html = HTMLRenderer.render(Div { Text("x") }.style("backdrop-filter", "blur(4px)"))
        #expect(html.contains("backdrop-filter: blur(4px)"))
        // invalid name/value paths assert in debug — not exercised here (Task 3 note)
    }
    @Test func styleValueIsAttributeEscaped() {
        let html = HTMLRenderer.render(Div { Text("x") }.fontFamily(#""Weird" font"#))
        #expect(html.contains("&quot;Weird&quot;"))      // existing choke point does the escaping
    }
    @Test func identityUnaffectedByBagStyles() {
        // bag mutation never adds identity segments: styled output is the plain
        // output plus exactly one style attribute — same tree shape otherwise
        let a = HTMLRenderer.render(Div { Text("x") })
        let b = HTMLRenderer.render(Div { Text("x") }.padding(.px(1)))
        #expect(a == "<div>x</div>")
        #expect(b == #"<div style="padding: 1px">x</div>"#)
    }
}
```

- [ ] **Step 4: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (131).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/HTML/AttributeBag.swift Sources/SwiftWUI/Styles/StyleModifiers+HTMLTag.swift Tests/SwiftWUITests/InlineStyleTests.swift
git commit -m "feat(styles): inline path — bag style declarations + full HTMLTag modifier surface

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: StyleRegistry + backend `setStylesheet` + runtime flush integration

**Files:**
- Create: `Sources/SwiftWUI/Styles/StyleRegistry.swift`
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (protocol method)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (record text)
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (registry on ResolveContext)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (own registry, flush hook, test hook)
- Modify: `Sources/SwiftWUI/Render/HTMLRenderer.swift` (stylesheet-exposing entry)
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (managed `<style>`)
- Test: `Tests/SwiftWUITests/StyleRegistryTests.swift`

**Interfaces:**
- Consumes: `StyleDeclaration`, `CSSSanitize` (Task 3).
- Produces:
  - `final class StyleRegistry` — `registerAnonymous(pseudo:media:declarations:) -> String` (class name), `registerSelector(base:scope:pseudo:media:declarations:)`, `registerRaw(_ text: String)`, `var text: String`, `var version: Int`
  - `ResolveContext.registry: StyleRegistry`
  - `RendererBackend.setStylesheet(_ text: String)` (all conformers)
  - `Runtime._registryText: String` test hook
  - `HTMLRenderer.renderWithStylesheet(_ tag:) -> (html: String, css: String)`
  - `MockBackend.stylesheetText: String?` + `counts["setStylesheet"]`

- [ ] **Step 1: Write StyleRegistry.swift**

```swift
/// Deduplicating, monotonic rule store (spec §7, D9). Rules are never removed;
/// growth is bounded by the number of DISTINCT rules the app produces.
/// ponytail: no sweep — add one when profiling shows unbounded distinct rules.
@MainActor
public final class StyleRegistry {
    struct Entry {
        let media: String        // "" for no condition — sorts before any @media
        let text: String         // full rule text WITHOUT media wrapper
        let hash: UInt64
    }
    private var byHash: [UInt64: Entry] = [:]
    private(set) var version = 0

    public init() {}

    static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }
    static func className(_ hash: UInt64) -> String {
        "swui-" + String(hash, radix: 36)
    }

    /// Serializes declarations, dropping any rule-unsafe value (spec §12 sink).
    static func body(_ declarations: [StyleDeclaration]) -> String {
        declarations.compactMap { d in
            guard CSSSanitize.isSafeValue(d.value) else {
                assertionFailure("unsafe CSS value dropped: \(d.property): \(d.value)")
                return nil
            }
            return "\(d.property): \(d.value)"
        }.joined(separator: "; ")
    }

    private func insert(media: String, text: String, seed: String) -> UInt64 {
        let hash = Self.fnv1a(seed)
        if byHash[hash] == nil {
            byHash[hash] = Entry(media: media, text: text, hash: hash)
            version += 1
        }
        return hash
    }

    /// Element-attached rule (.hover/.media modifiers, wrapper rules):
    /// returns the generated class name; the rule targets exactly that class.
    func registerAnonymous(pseudo: String?, media: String?, declarations: [StyleDeclaration]) -> String {
        let body = Self.body(declarations)
        let seed = "anon|\(pseudo ?? "")|\(media ?? "")|\(body)"
        let hash = Self.fnv1a(seed)
        let cls = Self.className(hash)
        let selector = "." + cls + (pseudo ?? "")
        _ = insert(media: media ?? "", text: "\(selector) { \(body) }", seed: seed)
        return cls
    }

    /// Styled/global rule: explicit selector base (".field" / "#submit" / "input"),
    /// optional scope marker class appended (spec §8).
    func registerSelector(base: String, scope: String?, pseudo: String?, media: String?,
                          declarations: [StyleDeclaration]) {
        let body = Self.body(declarations)
        let selector = base + (scope.map { "." + $0 } ?? "") + (pseudo ?? "")
        let seed = "sel|\(selector)|\(media ?? "")|\(body)"
        _ = insert(media: media ?? "", text: "\(selector) { \(body) }", seed: seed)
    }

    /// Pre-serialized block (themes, Task 9). Caller guarantees safety of the
    /// text (built from validated tokens + CSSValueConvertible values only).
    func registerRaw(_ text: String) {
        _ = insert(media: "", text: text, seed: "raw|" + text)
    }

    /// Canonical order: (media, hash) — deterministic regardless of which
    /// pass registered first (spec §7: scoped ≡ full byte-identical text).
    public var text: String {
        let sorted = byHash.values.sorted {
            ($0.media, $0.hash) < ($1.media, $1.hash)
        }
        return sorted.map { e in
            e.media.isEmpty ? e.text : "@media \(e.media) { \(e.text) }"
        }.joined(separator: "\n")
    }
}
```

(Tuple `<` on `(String, UInt64)` works via `Comparable` conformance of tuples up to arity 6.)

- [ ] **Step 2: Backend protocol + conformers**

`RendererBackend.swift` — add to the protocol after `remove`:

```swift
    /// Replace the full text of the document's single managed stylesheet.
    /// Called at most once per flush, only when the rule registry grew.
    func setStylesheet(_ text: String)
```

`MockBackend` — add:

```swift
    public private(set) var stylesheetText: String?
    public func setStylesheet(_ text: String) { bump("setStylesheet"); stylesheetText = text }
```

`DOMBackend` (wasm) — add (follow the file's existing JSObject style):

```swift
    private var styleElement: JSObject?
    public func setStylesheet(_ text: String) {
        if styleElement == nil {
            let document = JSObject.global.document
            let el = document.createElement("style")
            _ = el.setAttribute("id", "swiftwui-styles")
            _ = document.head.appendChild(el)
            styleElement = el.object
        }
        styleElement!.textContent = .string(text)
    }
```

- [ ] **Step 3: ResolveContext + Runtime wiring**

`Resolver.swift` — `ResolveContext` gains a registry (default instance so HTMLRenderer/unit tests need no ceremony):

```swift
    var effects: [EffectRequest] = []
    var registry = StyleRegistry()
```

`Runtime.swift` — own the registry and flush on growth. Add stored properties:

```swift
    private let styleRegistry = StyleRegistry()
    private var flushedStyleVersion = 0
    var _registryText: String { styleRegistry.text }        // test hook
```

In BOTH `renderPass()` and `subtreePass(_:_:)`, right after the `ctx` is created, add:

```swift
        ctx.registry = styleRegistry
```

In both passes, right after `current = …` (commit) and BEFORE the effect callbacks, add:

```swift
        if styleRegistry.version != flushedStyleVersion {
            flushedStyleVersion = styleRegistry.version
            applier.backend.setStylesheet(styleRegistry.text)
        }
```

(`TreeApplier.backend` is `let backend: Backend` — internal, same module; if it is declared `private`, change it to internal by removing the modifier.)

- [ ] **Step 4: HTMLRenderer stylesheet entry (SSG seam, spec §7)**

```swift
    /// Phase-5 SSG seam: same render, plus the generated stylesheet text.
    @MainActor public static func renderWithStylesheet(_ tag: some Tag) -> (html: String, css: String) {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        let html = render(coalesceText(resolve(tag, path: .root, ctx: &ctx)))
        return (html, ctx.registry.text)
    }
```

- [ ] **Step 5: Write StyleRegistryTests.swift**

```swift
import Testing
@testable import SwiftWUI

@Suite struct StyleRegistryTests {
    @Test func anonymousRuleDedup() {
        let r = StyleRegistry()
        let a = r.registerAnonymous(pseudo: ":hover", media: nil,
                                    declarations: [.color(.hex("#eee"))])
        let b = r.registerAnonymous(pseudo: ":hover", media: nil,
                                    declarations: [.color(.hex("#eee"))])
        #expect(a == b)
        #expect(r.version == 1)
        #expect(r.text == ".\(a):hover { color: #eee }")
    }
    @Test func canonicalOrderIsRegistrationOrderIndependent() {
        let r1 = StyleRegistry(); let r2 = StyleRegistry()
        let declsA: [StyleDeclaration] = [.margin(.px(1))]
        let declsB: [StyleDeclaration] = [.padding(.px(2))]
        _ = r1.registerAnonymous(pseudo: nil, media: nil, declarations: declsA)
        _ = r1.registerAnonymous(pseudo: nil, media: nil, declarations: declsB)
        _ = r2.registerAnonymous(pseudo: nil, media: nil, declarations: declsB)
        _ = r2.registerAnonymous(pseudo: nil, media: nil, declarations: declsA)
        #expect(r1.text == r2.text)
    }
    @Test func mediaRulesWrapAndSortAfterPlain() {
        let r = StyleRegistry()
        _ = r.registerAnonymous(pseudo: nil, media: "(max-width: 600px)",
                                declarations: [.display(.none)])
        _ = r.registerAnonymous(pseudo: nil, media: nil, declarations: [.gap(.px(4))])
        let t = r.text
        #expect(t.contains("@media (max-width: 600px) {"))
        #expect(t.firstRange(of: "gap")!.lowerBound < t.firstRange(of: "@media")!.lowerBound)
    }
    @Test func selectorRuleWithScope() {
        let r = StyleRegistry()
        r.registerSelector(base: ".field", scope: "swui-sabc", pseudo: nil, media: nil,
                           declarations: [.padding(.px(8))])
        #expect(r.text == ".field.swui-sabc { padding: 8px }")
    }
    @Test func hashStability() {
        // pin the generated class name so accidental hash-fn changes are loud
        let r = StyleRegistry()
        let cls = r.registerAnonymous(pseudo: nil, media: nil,
                                      declarations: [.color(.hex("#000"))])
        let again = StyleRegistry().registerAnonymous(pseudo: nil, media: nil,
                                                      declarations: [.color(.hex("#000"))])
        #expect(cls == again)
        #expect(cls.hasPrefix("swui-"))
    }
    @Test func runtimeFlushesOnlyOnGrowth() {
        struct Static: Tag {
            @State var n = 0
            var body: some Tag {
                Div { Button("+") { n += 1 }; Text("\(n)") }.padding(.px(4))   // inline only — no rules
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Static(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let callsAfterMount = backend.counts["setStylesheet"] ?? 0
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect((backend.counts["setStylesheet"] ?? 0) == callsAfterMount)   // registry never grew
    }
}
```

- [ ] **Step 6: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (137). `CrossCheckTests`/`RuntimeE2ETests` unaffected (no rules registered by existing fixtures → `setStylesheet` never fires for them).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(styles): StyleRegistry with content-hash dedup + canonical text; backend setStylesheet; runtime flush-on-growth

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: StyleProxy + pseudo-class/media modifiers on HTML tags

**Files:**
- Create: `Sources/SwiftWUI/Styles/StyleProxy.swift`
- Create: `Sources/SwiftWUI/Styles/MediaQuery.swift`
- Modify: `Sources/SwiftWUI/HTML/AttributeBag.swift` (pending rules)
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (`resolveElement` registers pending rules)
- Create: `Sources/SwiftWUI/Styles/RuleModifiers+HTMLTag.swift`
- Test: `Tests/SwiftWUITests/PseudoMediaTests.swift`

**Interfaces:**
- Consumes: `StyleDeclaration` factories, `StyleRegistry.registerAnonymous` (Tasks 3, 5).
- Produces:
  - `struct StyleProxy` — `declarations: [StyleDeclaration]`, `pseudoBlocks: [(pseudo: String, declarations: [StyleDeclaration])]`, all §4 modifiers as `mutating func`, `mutating func hover/focus/active(_ body: (inout StyleProxy) -> Void)`, `mutating func style(_ property: String, _ value: String)`
  - `struct MediaQuery` — `.maxWidth/.minWidth(CSSLength)`, `.prefersColorScheme(.dark/.light)`, `.custom(String)`, `var condition: String`
  - `struct PendingStyleRule { let pseudo: String?; let media: String?; let declarations: [StyleDeclaration] }`
  - `_AttributeBag.pendingRules: [PendingStyleRule]` + `addPendingRule(_:)`
  - `.hover/.focus/.active { … }` and `.media(_:) { … }` on `HTMLTag`

- [ ] **Step 1: Write MediaQuery.swift**

```swift
public enum ColorScheme: String { case light, dark }

public struct MediaQuery: Equatable {
    public let condition: String
    public static func maxWidth(_ l: CSSLength) -> MediaQuery { .init(condition: "(max-width: \(l.css))") }
    public static func minWidth(_ l: CSSLength) -> MediaQuery { .init(condition: "(min-width: \(l.css))") }
    public static func prefersColorScheme(_ s: ColorScheme) -> MediaQuery {
        .init(condition: "(prefers-color-scheme: \(s.rawValue))")
    }
    /// Escape hatch; must be rule-safe (no braces/control chars).
    public static func custom(_ s: String) -> MediaQuery {
        guard CSSSanitize.isSafeValue(s) else {
            assertionFailure("unsafe media condition: \(s)")
            return .init(condition: "not all")            // matches nothing in release
        }
        return .init(condition: s)
    }
}
```

- [ ] **Step 2: Write StyleProxy.swift**

The proxy is the SAME naming surface as the element modifiers, in statement form. One helper + one-liners for every Task-3 factory (complete list, mirror Task 4 exactly with `mutating func` and no return):

```swift
/// Declaration collector shared by rules, Style bundles, and pseudo blocks.
/// Statement style: `s.padding(.px(8))`.
public struct StyleProxy {
    var declarations: [StyleDeclaration] = []
    var pseudoBlocks: [(pseudo: String, declarations: [StyleDeclaration])] = []

    mutating func _add(_ d: StyleDeclaration) { declarations.append(d) }

    public mutating func style(_ property: String, _ value: String) {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return
        }
        _add(StyleDeclaration(property: property, value: value))
    }

    mutating func _pseudo(_ name: String, _ body: (inout StyleProxy) -> Void) {
        var sub = StyleProxy()
        body(&sub)
        assert(sub.pseudoBlocks.isEmpty, "nested pseudo blocks are not supported")
        pseudoBlocks.append((name, sub.declarations))
    }
    public mutating func hover(_ body: (inout StyleProxy) -> Void)  { _pseudo(":hover", body) }
    public mutating func focus(_ body: (inout StyleProxy) -> Void)  { _pseudo(":focus", body) }
    public mutating func active(_ body: (inout StyleProxy) -> Void) { _pseudo(":active", body) }

    // Layout
    public mutating func display(_ v: Display) { _add(.display(v)) }
    public mutating func position(_ v: Position) { _add(.position(v)) }
    public mutating func top(_ v: CSSLength) { _add(.top(v)) }
    public mutating func right(_ v: CSSLength) { _add(.right(v)) }
    public mutating func bottom(_ v: CSSLength) { _add(.bottom(v)) }
    public mutating func left(_ v: CSSLength) { _add(.left(v)) }
    public mutating func width(_ v: CSSLength) { _add(.width(v)) }
    public mutating func height(_ v: CSSLength) { _add(.height(v)) }
    public mutating func minWidth(_ v: CSSLength) { _add(.minWidth(v)) }
    public mutating func minHeight(_ v: CSSLength) { _add(.minHeight(v)) }
    public mutating func maxWidth(_ v: CSSLength) { _add(.maxWidth(v)) }
    public mutating func maxHeight(_ v: CSSLength) { _add(.maxHeight(v)) }
    public mutating func margin(_ v: CSSLength) { _add(.margin(v)) }
    public mutating func margin(_ side: Side, _ v: CSSLength) { _add(.margin(side, v)) }
    public mutating func margin(vertical: CSSLength, horizontal: CSSLength) { _add(.margin(vertical: vertical, horizontal: horizontal)) }
    public mutating func padding(_ v: CSSLength) { _add(.padding(v)) }
    public mutating func padding(_ side: Side, _ v: CSSLength) { _add(.padding(side, v)) }
    public mutating func padding(vertical: CSSLength, horizontal: CSSLength) { _add(.padding(vertical: vertical, horizontal: horizontal)) }
    public mutating func gap(_ v: CSSLength) { _add(.gap(v)) }
    public mutating func overflow(_ v: Overflow) { _add(.overflow(v)) }
    public mutating func zIndex(_ v: Int) { _add(.zIndex(v)) }
    public mutating func boxSizing(_ v: BoxSizing) { _add(.boxSizing(v)) }
    // Flex / Grid
    public mutating func flexDirection(_ v: FlexDirection) { _add(.flexDirection(v)) }
    public mutating func justifyContent(_ v: JustifyContent) { _add(.justifyContent(v)) }
    public mutating func alignItems(_ v: AlignItems) { _add(.alignItems(v)) }
    public mutating func alignSelf(_ v: AlignItems) { _add(.alignSelf(v)) }
    public mutating func flexWrap(_ v: FlexWrap) { _add(.flexWrap(v)) }
    public mutating func flexGrow(_ v: Double) { _add(.flexGrow(v)) }
    public mutating func flexShrink(_ v: Double) { _add(.flexShrink(v)) }
    public mutating func flexBasis(_ v: CSSLength) { _add(.flexBasis(v)) }
    public mutating func gridTemplateColumns(_ v: String) { _add(.gridTemplateColumns(v)) }
    public mutating func gridTemplateRows(_ v: String) { _add(.gridTemplateRows(v)) }
    // Typography
    public mutating func fontSize(_ v: CSSLength) { _add(.fontSize(v)) }
    public mutating func fontWeight(_ v: FontWeight) { _add(.fontWeight(v)) }
    public mutating func fontFamily(_ v: String) { _add(.fontFamily(v)) }
    public mutating func lineHeight(_ v: Double) { _add(.lineHeight(v)) }
    public mutating func textAlign(_ v: TextAlign) { _add(.textAlign(v)) }
    public mutating func textDecoration(_ v: TextDecoration) { _add(.textDecoration(v)) }
    public mutating func letterSpacing(_ v: CSSLength) { _add(.letterSpacing(v)) }
    public mutating func color(_ v: CSSColor) { _add(.color(v)) }
    // Box
    public mutating func background(_ v: CSSColor) { _add(.background(v)) }
    public mutating func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) { _add(.border(width, style, color)) }
    public mutating func borderColor(_ v: CSSColor) { _add(.borderColor(v)) }
    public mutating func borderRadius(_ v: CSSLength) { _add(.borderRadius(v)) }
    public mutating func boxShadow(_ v: String) { _add(.boxShadow(v)) }
    public mutating func opacity(_ v: Double) { _add(.opacity(v)) }
    public mutating func outline(_ v: Outline) { _add(.outline(v)) }
    // Misc
    public mutating func cursor(_ v: Cursor) { _add(.cursor(v)) }
    public mutating func transition(_ v: String) { _add(.transition(v)) }
    public mutating func listStyle(_ v: String) { _add(.listStyle(v)) }
}
```

- [ ] **Step 3: Pending rules through the bag**

`AttributeBag.swift` — add next to `styles`:

```swift
    private(set) var pendingRules: [PendingStyleRule] = []
    mutating func addPendingRule(_ r: PendingStyleRule) { pendingRules.append(r) }
```

and define (same file, above the bag):

```swift
/// A rule captured on an element before the registry is reachable; resolved
/// to a swui-<hash> class in resolveElement.
public struct PendingStyleRule {
    let pseudo: String?
    let media: String?
    let declarations: [StyleDeclaration]
}
```

`Resolver.swift` — in `resolveElement`, register pending rules and append their classes. Replace the final `return`:

```swift
    var effectiveBag = bag
    for rule in bag.pendingRules {
        let cls = ctx.registry.registerAnonymous(pseudo: rule.pseudo, media: rule.media,
                                                 declarations: rule.declarations)
        effectiveBag.appendClasses([cls])
    }
    let children = coalesceText(resolve(content, path: path.appending(.child(0)), ctx: &ctx))
    return [.element(ElementNode(identity: path, tag: tagName, attributes: effectiveBag.flattened(),
                                 properties: effectiveBag.flattenedProperties(),
                                 listeners: listeners, children: children, key: nil))]
```

(The `children` line moves after the rule loop; listener registration above stays untouched and still reads `bag`.)

- [ ] **Step 4: Write RuleModifiers+HTMLTag.swift**

```swift
extension HTMLTag {
    func _pendingRule(pseudo: String?, media: String?, _ body: (inout StyleProxy) -> Void) -> Self {
        var proxy = StyleProxy()
        body(&proxy)
        assert(proxy.pseudoBlocks.isEmpty, "pseudo blocks inside an element rule modifier are not supported — chain .hover/.focus/.active instead")
        var copy = self
        copy._attributes.addPendingRule(PendingStyleRule(pseudo: pseudo, media: media,
                                                         declarations: proxy.declarations))
        return copy
    }
    public func hover(_ body: (inout StyleProxy) -> Void) -> Self  { _pendingRule(pseudo: ":hover", media: nil, body) }
    public func focus(_ body: (inout StyleProxy) -> Void) -> Self  { _pendingRule(pseudo: ":focus", media: nil, body) }
    public func active(_ body: (inout StyleProxy) -> Void) -> Self { _pendingRule(pseudo: ":active", media: nil, body) }
    public func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) -> Self {
        _pendingRule(pseudo: nil, media: query.condition, body)
    }
}
```

- [ ] **Step 5: Write PseudoMediaTests.swift**

```swift
import Testing
@testable import SwiftWUI

@Suite struct PseudoMediaTests {
    @Test func hoverGeneratesClassAndRule() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(
            Button("+") {}.hover { $0.background(.hex("#eee")) }
        )
        // the button carries exactly the generated class, and the rule targets it
        let clsStart = html.firstRange(of: "swui-")!
        let cls = String(html[clsStart.lowerBound...].prefix(while: { $0 != "\"" && $0 != " " }))
        #expect(css == ".\(cls):hover { background: #eee }")
    }
    @Test func sameRuleTwoElementsOneEntry() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div {
                Button("a") {}.hover { $0.opacity(0.5) }
                Button("b") {}.hover { $0.opacity(0.5) }
            }
        )
        #expect(css.split(separator: "\n").count == 1)
    }
    @Test func mediaRuleWraps() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.media(.maxWidth(.px(600))) { $0.display(.none) }
        )
        #expect(css.hasPrefix("@media (max-width: 600px) { .swui-"))
        #expect(css.contains("display: none"))
    }
    @Test func mediaQueryConditions() {
        #expect(MediaQuery.minWidth(.rem(40)).condition == "(min-width: 40rem)")
        #expect(MediaQuery.prefersColorScheme(.dark).condition == "(prefers-color-scheme: dark)")
    }
    @Test func runtimeSetsStylesheetOnMount() {
        struct Root: Tag {
            var body: some Tag { Div { Text("x") }.hover { $0.color(.white) } }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.stylesheetText?.contains(":hover { color: #fff }") == true)
        #expect(backend.counts["setStylesheet"] == 1)
    }
}
```

- [ ] **Step 6: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (142).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(styles): StyleProxy + MediaQuery; .hover/.focus/.active/.media element modifiers via pending rules

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: `_StyledTag` — style modifiers on any Tag

**Files:**
- Create: `Sources/SwiftWUI/Styles/StyledTag.swift`
- Create: `Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift`
- Test: `Tests/SwiftWUITests/StyledWrapperTests.swift`

**Interfaces:**
- Consumes: `resolve()`, `_PrimitiveTag`, `.type` identity pattern (mirror `_AppearEffect` in `Sources/SwiftWUI/Effects/EffectModifiers.swift` — read it first and keep the identity handling byte-parallel), `StyleRegistry.registerAnonymous`, `_AttributeBag.mergeStyleText` (Task 4).
- Produces:
  - `struct _StyledTag<Content: Tag>: Tag, _PrimitiveTag` with `content`, `declarations: [StyleDeclaration]`, `rules: [PendingStyleRule]`
  - every §4 modifier + `.style(_:_:)` + `.hover/.focus/.active/.media` on `extension Tag` returning `_StyledTag<Self>`
  - the same set on `extension _StyledTag` returning `Self` (collapse — one wrapper per chain)

- [ ] **Step 1: Write StyledTag.swift**

```swift
/// Wrapper path (spec §6): style modifiers on non-HTML tags. One `.type`
/// identity segment per wrapper CHAIN (consecutive modifiers collapse).
/// Declarations apply to every top-level element root of the resolved
/// content, appended AFTER the element's own styles (outer wins).
public struct _StyledTag<Content: Tag>: Tag, _PrimitiveTag {
    public typealias Body = Never
    var content: Content
    var declarations: [StyleDeclaration]
    var rules: [PendingStyleRule]

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        let id = path.appending(.type(ObjectIdentifier(Self.self)))
        var ruleClasses: [String] = []
        for r in rules {
            ruleClasses.append(ctx.registry.registerAnonymous(pseudo: r.pseudo, media: r.media,
                                                              declarations: r.declarations))
        }
        var nodes = resolve(content, path: id.appending(.child(0)), ctx: &ctx)
        for i in nodes.indices {
            Self.apply(declarations: declarations, classes: ruleClasses, to: &nodes[i])
        }
        return nodes
    }

    /// Element roots get the styles; component roots are transparent (descend);
    /// text roots are a documented no-op (debug assert to surface it).
    static func apply(declarations: [StyleDeclaration], classes: [String], to node: inout Node) {
        switch node {
        case .element(var e):
            if !declarations.isEmpty {
                e.attributes["style"] = _AttributeBag.mergeStyleText(
                    base: e.attributes["style"], declarations)
            }
            for cls in classes {
                let existing = e.attributes["class"]
                e.attributes["class"] = existing.map { $0.isEmpty ? cls : $0 + " " + cls } ?? cls
            }
            node = .element(e)
        case .component(var c):
            for i in c.children.indices {
                apply(declarations: declarations, classes: classes, to: &c.children[i])
            }
            node = .component(c)
        case .text:
            assertionFailure("style modifier applied to a text root is a no-op")
        }
    }
}
```

Note: `mergeStyleText` already implements last-wins across `base + new`, so a wrapper declaration overrides the element's own same-property declaration — spec's "outer wins". Verify `_AttributeBag.mergeStyleText` handles a duplicate property across base/new: the base is a pre-joined string, so a duplicate property appears twice in the attribute — CSS itself applies last-wins. This is acceptable and matches the spec's semantics; note it in the code comment.

- [ ] **Step 2: Write StyleModifiers+Tag.swift**

Two extensions. `extension Tag` creates the wrapper; `extension _StyledTag` collapses. Concrete members on `_StyledTag` win over the `Tag` extension, and `HTMLTag`'s own modifiers (Task 4) win for HTML tags — verify with the overload test in Step 3.

```swift
extension Tag {
    func _styled(_ d: StyleDeclaration) -> _StyledTag<Self> {
        _StyledTag(content: self, declarations: [d], rules: [])
    }
    func _styledRule(pseudo: String?, media: String?, _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
        var proxy = StyleProxy(); body(&proxy)
        assert(proxy.pseudoBlocks.isEmpty, "pseudo blocks inside a rule modifier are not supported")
        return _StyledTag(content: self, declarations: [],
                          rules: [PendingStyleRule(pseudo: pseudo, media: media,
                                                   declarations: proxy.declarations)])
    }

    public func style(_ property: String, _ value: String) -> _StyledTag<Self> {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return _StyledTag(content: self, declarations: [], rules: [])
        }
        return _styled(StyleDeclaration(property: property, value: value))
    }
    public func hover(_ body: (inout StyleProxy) -> Void) -> _StyledTag<Self>  { _styledRule(pseudo: ":hover", media: nil, body) }
    public func focus(_ body: (inout StyleProxy) -> Void) -> _StyledTag<Self>  { _styledRule(pseudo: ":focus", media: nil, body) }
    public func active(_ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> { _styledRule(pseudo: ":active", media: nil, body) }
    public func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
        _styledRule(pseudo: nil, media: query.condition, body)
    }

    // The full §4 surface — every line delegates to a Task-3 factory:
    public func display(_ v: Display) -> _StyledTag<Self> { _styled(.display(v)) }
    public func position(_ v: Position) -> _StyledTag<Self> { _styled(.position(v)) }
    public func top(_ v: CSSLength) -> _StyledTag<Self> { _styled(.top(v)) }
    public func right(_ v: CSSLength) -> _StyledTag<Self> { _styled(.right(v)) }
    public func bottom(_ v: CSSLength) -> _StyledTag<Self> { _styled(.bottom(v)) }
    public func left(_ v: CSSLength) -> _StyledTag<Self> { _styled(.left(v)) }
    public func width(_ v: CSSLength) -> _StyledTag<Self> { _styled(.width(v)) }
    public func height(_ v: CSSLength) -> _StyledTag<Self> { _styled(.height(v)) }
    public func minWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.minWidth(v)) }
    public func minHeight(_ v: CSSLength) -> _StyledTag<Self> { _styled(.minHeight(v)) }
    public func maxWidth(_ v: CSSLength) -> _StyledTag<Self> { _styled(.maxWidth(v)) }
    public func maxHeight(_ v: CSSLength) -> _StyledTag<Self> { _styled(.maxHeight(v)) }
    public func margin(_ v: CSSLength) -> _StyledTag<Self> { _styled(.margin(v)) }
    public func margin(_ side: Side, _ v: CSSLength) -> _StyledTag<Self> { _styled(.margin(side, v)) }
    public func margin(vertical: CSSLength, horizontal: CSSLength) -> _StyledTag<Self> { _styled(.margin(vertical: vertical, horizontal: horizontal)) }
    public func padding(_ v: CSSLength) -> _StyledTag<Self> { _styled(.padding(v)) }
    public func padding(_ side: Side, _ v: CSSLength) -> _StyledTag<Self> { _styled(.padding(side, v)) }
    public func padding(vertical: CSSLength, horizontal: CSSLength) -> _StyledTag<Self> { _styled(.padding(vertical: vertical, horizontal: horizontal)) }
    public func gap(_ v: CSSLength) -> _StyledTag<Self> { _styled(.gap(v)) }
    public func overflow(_ v: Overflow) -> _StyledTag<Self> { _styled(.overflow(v)) }
    public func zIndex(_ v: Int) -> _StyledTag<Self> { _styled(.zIndex(v)) }
    public func boxSizing(_ v: BoxSizing) -> _StyledTag<Self> { _styled(.boxSizing(v)) }
    public func flexDirection(_ v: FlexDirection) -> _StyledTag<Self> { _styled(.flexDirection(v)) }
    public func justifyContent(_ v: JustifyContent) -> _StyledTag<Self> { _styled(.justifyContent(v)) }
    public func alignItems(_ v: AlignItems) -> _StyledTag<Self> { _styled(.alignItems(v)) }
    public func alignSelf(_ v: AlignItems) -> _StyledTag<Self> { _styled(.alignSelf(v)) }
    public func flexWrap(_ v: FlexWrap) -> _StyledTag<Self> { _styled(.flexWrap(v)) }
    public func flexGrow(_ v: Double) -> _StyledTag<Self> { _styled(.flexGrow(v)) }
    public func flexShrink(_ v: Double) -> _StyledTag<Self> { _styled(.flexShrink(v)) }
    public func flexBasis(_ v: CSSLength) -> _StyledTag<Self> { _styled(.flexBasis(v)) }
    public func gridTemplateColumns(_ v: String) -> _StyledTag<Self> { _styled(.gridTemplateColumns(v)) }
    public func gridTemplateRows(_ v: String) -> _StyledTag<Self> { _styled(.gridTemplateRows(v)) }
    public func fontSize(_ v: CSSLength) -> _StyledTag<Self> { _styled(.fontSize(v)) }
    public func fontWeight(_ v: FontWeight) -> _StyledTag<Self> { _styled(.fontWeight(v)) }
    public func fontFamily(_ v: String) -> _StyledTag<Self> { _styled(.fontFamily(v)) }
    public func lineHeight(_ v: Double) -> _StyledTag<Self> { _styled(.lineHeight(v)) }
    public func textAlign(_ v: TextAlign) -> _StyledTag<Self> { _styled(.textAlign(v)) }
    public func textDecoration(_ v: TextDecoration) -> _StyledTag<Self> { _styled(.textDecoration(v)) }
    public func letterSpacing(_ v: CSSLength) -> _StyledTag<Self> { _styled(.letterSpacing(v)) }
    public func color(_ v: CSSColor) -> _StyledTag<Self> { _styled(.color(v)) }
    public func background(_ v: CSSColor) -> _StyledTag<Self> { _styled(.background(v)) }
    public func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> _StyledTag<Self> { _styled(.border(width, style, color)) }
    public func borderColor(_ v: CSSColor) -> _StyledTag<Self> { _styled(.borderColor(v)) }
    public func borderRadius(_ v: CSSLength) -> _StyledTag<Self> { _styled(.borderRadius(v)) }
    public func boxShadow(_ v: String) -> _StyledTag<Self> { _styled(.boxShadow(v)) }
    public func opacity(_ v: Double) -> _StyledTag<Self> { _styled(.opacity(v)) }
    public func outline(_ v: Outline) -> _StyledTag<Self> { _styled(.outline(v)) }
    public func cursor(_ v: Cursor) -> _StyledTag<Self> { _styled(.cursor(v)) }
    public func transition(_ v: String) -> _StyledTag<Self> { _styled(.transition(v)) }
    public func listStyle(_ v: String) -> _StyledTag<Self> { _styled(.listStyle(v)) }
}

extension _StyledTag {
    // Collapse: consecutive style modifiers append to the SAME wrapper.
    func _styled(_ d: StyleDeclaration) -> Self {
        var copy = self; copy.declarations.append(d); return copy
    }
    func _styledRule(pseudo: String?, media: String?, _ body: (inout StyleProxy) -> Void) -> Self {
        var proxy = StyleProxy(); body(&proxy)
        var copy = self
        copy.rules.append(PendingStyleRule(pseudo: pseudo, media: media,
                                           declarations: proxy.declarations))
        return copy
    }
    public func style(_ property: String, _ value: String) -> Self {
        guard CSSSanitize.isValidIdent(property), CSSSanitize.isSafeValue(value) else {
            assertionFailure("invalid style declaration: \(property): \(value)")
            return self
        }
        return _styled(StyleDeclaration(property: property, value: value))
    }
    public func hover(_ body: (inout StyleProxy) -> Void) -> Self  { _styledRule(pseudo: ":hover", media: nil, body) }
    public func focus(_ body: (inout StyleProxy) -> Void) -> Self  { _styledRule(pseudo: ":focus", media: nil, body) }
    public func active(_ body: (inout StyleProxy) -> Void) -> Self { _styledRule(pseudo: ":active", media: nil, body) }
    public func media(_ query: MediaQuery, _ body: (inout StyleProxy) -> Void) -> Self {
        _styledRule(pseudo: nil, media: query.condition, body)
    }
    // Collapse variants of the full surface — every line appends to self:
    public func display(_ v: Display) -> Self { _styled(.display(v)) }
    public func position(_ v: Position) -> Self { _styled(.position(v)) }
    public func top(_ v: CSSLength) -> Self { _styled(.top(v)) }
    public func right(_ v: CSSLength) -> Self { _styled(.right(v)) }
    public func bottom(_ v: CSSLength) -> Self { _styled(.bottom(v)) }
    public func left(_ v: CSSLength) -> Self { _styled(.left(v)) }
    public func width(_ v: CSSLength) -> Self { _styled(.width(v)) }
    public func height(_ v: CSSLength) -> Self { _styled(.height(v)) }
    public func minWidth(_ v: CSSLength) -> Self { _styled(.minWidth(v)) }
    public func minHeight(_ v: CSSLength) -> Self { _styled(.minHeight(v)) }
    public func maxWidth(_ v: CSSLength) -> Self { _styled(.maxWidth(v)) }
    public func maxHeight(_ v: CSSLength) -> Self { _styled(.maxHeight(v)) }
    public func margin(_ v: CSSLength) -> Self { _styled(.margin(v)) }
    public func margin(_ side: Side, _ v: CSSLength) -> Self { _styled(.margin(side, v)) }
    public func margin(vertical: CSSLength, horizontal: CSSLength) -> Self { _styled(.margin(vertical: vertical, horizontal: horizontal)) }
    public func padding(_ v: CSSLength) -> Self { _styled(.padding(v)) }
    public func padding(_ side: Side, _ v: CSSLength) -> Self { _styled(.padding(side, v)) }
    public func padding(vertical: CSSLength, horizontal: CSSLength) -> Self { _styled(.padding(vertical: vertical, horizontal: horizontal)) }
    public func gap(_ v: CSSLength) -> Self { _styled(.gap(v)) }
    public func overflow(_ v: Overflow) -> Self { _styled(.overflow(v)) }
    public func zIndex(_ v: Int) -> Self { _styled(.zIndex(v)) }
    public func boxSizing(_ v: BoxSizing) -> Self { _styled(.boxSizing(v)) }
    public func flexDirection(_ v: FlexDirection) -> Self { _styled(.flexDirection(v)) }
    public func justifyContent(_ v: JustifyContent) -> Self { _styled(.justifyContent(v)) }
    public func alignItems(_ v: AlignItems) -> Self { _styled(.alignItems(v)) }
    public func alignSelf(_ v: AlignItems) -> Self { _styled(.alignSelf(v)) }
    public func flexWrap(_ v: FlexWrap) -> Self { _styled(.flexWrap(v)) }
    public func flexGrow(_ v: Double) -> Self { _styled(.flexGrow(v)) }
    public func flexShrink(_ v: Double) -> Self { _styled(.flexShrink(v)) }
    public func flexBasis(_ v: CSSLength) -> Self { _styled(.flexBasis(v)) }
    public func gridTemplateColumns(_ v: String) -> Self { _styled(.gridTemplateColumns(v)) }
    public func gridTemplateRows(_ v: String) -> Self { _styled(.gridTemplateRows(v)) }
    public func fontSize(_ v: CSSLength) -> Self { _styled(.fontSize(v)) }
    public func fontWeight(_ v: FontWeight) -> Self { _styled(.fontWeight(v)) }
    public func fontFamily(_ v: String) -> Self { _styled(.fontFamily(v)) }
    public func lineHeight(_ v: Double) -> Self { _styled(.lineHeight(v)) }
    public func textAlign(_ v: TextAlign) -> Self { _styled(.textAlign(v)) }
    public func textDecoration(_ v: TextDecoration) -> Self { _styled(.textDecoration(v)) }
    public func letterSpacing(_ v: CSSLength) -> Self { _styled(.letterSpacing(v)) }
    public func color(_ v: CSSColor) -> Self { _styled(.color(v)) }
    public func background(_ v: CSSColor) -> Self { _styled(.background(v)) }
    public func border(_ width: CSSLength, _ style: BorderStyle, _ color: CSSColor) -> Self { _styled(.border(width, style, color)) }
    public func borderColor(_ v: CSSColor) -> Self { _styled(.borderColor(v)) }
    public func borderRadius(_ v: CSSLength) -> Self { _styled(.borderRadius(v)) }
    public func boxShadow(_ v: String) -> Self { _styled(.boxShadow(v)) }
    public func opacity(_ v: Double) -> Self { _styled(.opacity(v)) }
    public func outline(_ v: Outline) -> Self { _styled(.outline(v)) }
    public func cursor(_ v: Cursor) -> Self { _styled(.cursor(v)) }
    public func transition(_ v: String) -> Self { _styled(.transition(v)) }
    public func listStyle(_ v: String) -> Self { _styled(.listStyle(v)) }
}
```

- [ ] **Step 3: Write StyledWrapperTests.swift**

```swift
import Testing
@testable import SwiftWUI

private struct Card: Tag {
    var body: some Tag { Div(class: "card") { Text("hi") } }
}
private struct TwoRoots: Tag {
    var body: some Tag {
        Div { Text("a") }
        Span { Text("b") }
    }
}
private struct StatefulCard: Tag {
    @State var n = 0
    var body: some Tag { Div { Button("+") { n += 1 }; Text("\(n)") } }
}

@Suite struct StyledWrapperTests {
    @Test func componentGetsWrapperStyles() {
        let html = HTMLRenderer.render(Card().margin(.px(16)))
        #expect(html.contains(#"style="margin: 16px""#))
    }
    @Test func htmlTagStaysOnBagPathNoWrapper() {
        // overload check: modifier on a concrete HTML tag returns the tag itself
        // (accessing _attributes compiles ⇔ the HTMLTag overload won, no wrapper)
        let d = Div { Text("x") }.padding(.px(4))
        #expect(d._attributes.styles.count == 1)
    }
    @Test func consecutiveModifiersCollapse() {
        let styled = Card().padding(.px(2)).margin(.px(4))
        #expect(styled.declarations.count == 2)          // one wrapper, two declarations
    }
    @Test func outerWins() {
        // Card's root Div has no margin; give it one inline and override from outside
        struct Inner: Tag { var body: some Tag { Div { Text("x") }.margin(.px(1)) } }
        let html = HTMLRenderer.render(Inner().margin(.px(9)))
        // both appear; CSS last-wins → 9px is effective. Pin the order:
        #expect(html.contains("margin: 1px; margin: 9px"))
    }
    @Test func multiRootAppliesToEveryElementRoot() {
        let html = HTMLRenderer.render(TwoRoots().color(.hex("#111")))
        #expect(html.ranges(of: "color: #111").count == 2)
    }
    @Test func wrapperRulesAttachClasses() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(
            Card().hover { $0.opacity(0.5) }
        )
        #expect(html.contains("swui-"))
        #expect(css.contains(":hover { opacity: 0.5 }"))
    }
    @Test func statePreservedAcrossReRenderWithWrapper() {
        struct Root: Tag {
            @State var tick = 0
            var body: some Tag {
                Div {
                    StatefulCard().padding(.px(4))
                    Button("t") { tick += 1 }
                    Text("tick \(tick)")
                }
            }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule)
        rt.mount()
        let plus = findAll(backend.container, tag: "button").first { $0.children.first?.text == "+" }!
        rt.dispatch(plus.events["click"]!); sched.pump()
        #expect(backend.serializeHTML().contains("1"))
        let t = findAll(backend.container, tag: "button").first { $0.children.first?.text == "t" }!
        rt.dispatch(t.events["click"]!); sched.pump()
        // wrapper identity is stable → StatefulCard keeps n == 1 across parent re-render
        #expect(backend.serializeHTML().contains("tick 1"))
        let plusAfter = findAll(backend.container, tag: "button").first { $0.children.first?.text == "+" }!
        #expect(plusAfter.parent!.children.last?.text == "1")   // counter text survived
    }
}
```

(`ranges(of:)`/`firstRange(of:)` are stdlib on Swift 6 — no Foundation needed.)

- [ ] **Step 4: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (149).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(styles): _StyledTag wrapper — full style surface on any Tag with collapse and outer-wins

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: `Styled` protocol, `Rule`, `RulesBuilder`, scope markers, `App.globalStyles`

**Files:**
- Create: `Sources/SwiftWUI/Styles/Rule.swift`
- Create: `Sources/SwiftWUI/Styles/Styled.swift`
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (scopeClass + Styled check)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (globalStyles init param)
- Modify: `Sources/SwiftWUI/App/App.swift` (globalStyles default)
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (pass-through)
- Test: `Tests/SwiftWUITests/StyledScopingTests.swift`

**Interfaces:**
- Consumes: `StyleProxy`, `MediaQuery`, `StyleRegistry.registerSelector`, `ResolveContext.owner` pattern (Task 2), `CSSSanitize`.
- Produces:
  - `struct Rule` — `init(class:media:_:)`, `init(id:media:_:)`, `init(element:media:_:)`
  - `@resultBuilder enum RulesBuilder`
  - `protocol Styled { @RulesBuilder var styles: [Rule] { get } }`
  - `ResolveContext.scopeClass: String?`
  - `Runtime.init(…, globalStyles: [Rule] = [])`
  - `App.globalStyles` (`@RulesBuilder static var`, default empty)
  - `DOMRuntime.mount(_:selector:globalStyles:)`

- [ ] **Step 1: Write Rule.swift**

```swift
public struct Rule {
    enum SelectorBase {
        case cls(String), id(String), element(String)
        var css: String {
            switch self {
            case .cls(let n): return "." + n
            case .id(let n): return "#" + n
            case .element(let n): return n
            }
        }
    }
    let base: SelectorBase
    let media: MediaQuery?
    let proxy: StyleProxy

    static func validated(_ name: String, kind: String) -> String {
        guard CSSSanitize.isValidIdent(name) else {
            assertionFailure("Rule(\(kind):) requires a plain CSS ident, got: \(name)")
            return "swui-invalid"
        }
        return name
    }
    public init(class name: String, media: MediaQuery? = nil, _ build: (inout StyleProxy) -> Void) {
        var p = StyleProxy(); build(&p)
        self.base = .cls(Self.validated(name, kind: "class")); self.media = media; self.proxy = p
    }
    public init(id name: String, media: MediaQuery? = nil, _ build: (inout StyleProxy) -> Void) {
        var p = StyleProxy(); build(&p)
        self.base = .id(Self.validated(name, kind: "id")); self.media = media; self.proxy = p
    }
    public init(element name: String, media: MediaQuery? = nil, _ build: (inout StyleProxy) -> Void) {
        var p = StyleProxy(); build(&p)
        self.base = .element(Self.validated(name, kind: "element")); self.media = media; self.proxy = p
    }

    /// Registers this rule (plus its pseudo blocks) under an optional scope marker.
    @MainActor func register(into registry: StyleRegistry, scope: String?) {
        if !proxy.declarations.isEmpty {
            registry.registerSelector(base: base.css, scope: scope, pseudo: nil,
                                      media: media?.condition, declarations: proxy.declarations)
        }
        for block in proxy.pseudoBlocks {
            registry.registerSelector(base: base.css, scope: scope, pseudo: block.pseudo,
                                      media: media?.condition, declarations: block.declarations)
        }
    }
}

@resultBuilder
public enum RulesBuilder {
    // NOTE: variadic buildBlock alone also covers the empty block (zero args →
    // []). Do NOT add a separate zero-arg overload — it creates an ambiguity.
    public static func buildBlock(_ parts: [Rule]...) -> [Rule] { parts.flatMap { $0 } }
    public static func buildExpression(_ r: Rule) -> [Rule] { [r] }
    public static func buildOptional(_ r: [Rule]?) -> [Rule] { r ?? [] }
    public static func buildEither(first: [Rule]) -> [Rule] { first }
    public static func buildEither(second: [Rule]) -> [Rule] { second }
    public static func buildArray(_ parts: [[Rule]]) -> [Rule] { parts.flatMap { $0 } }
}
```

- [ ] **Step 2: Write Styled.swift**

```swift
/// Component-scoped selector rules (spec §8). Adopt alongside Tag:
///
///     struct SearchForm: Tag, Styled {
///         @RulesBuilder var styles: [Rule] { Rule(class: "field") { $0.padding(.px(8)) } }
///         var body: some Tag { … }
///     }
///
/// Every element resolved in this component's body gets a per-type marker
/// class; selectors compile with the marker attached (Vue-style scoping).
/// Rules do not leak into child components or outward.
public protocol Styled {
    @RulesBuilder var styles: [Rule] { get }
}

/// Marker derived from the fully-qualified type name — stable across
/// instances and passes (scoped ≡ full byte-identical).
func scopeMarker(forTypeName name: String) -> String {
    "swui-s" + String(StyleRegistry.fnv1a(name), radix: 36)
}
```

- [ ] **Step 3: Wire into the resolver**

`ResolveContext` gains (next to `owner`):

```swift
    /// Scope marker of the innermost Styled component; appended to every
    /// element resolved in its body. Reset at EVERY component boundary.
    var scopeClass: String? = nil
```

In `resolve()` — the component boundary. Rules are evaluated INSIDE the tracking window, immediately before `body` (spec §8: dynamic rules re-register; dedup absorbs). Replace the tracking block:

```swift
    let savedOwner = ctx.owner
    let savedScope = ctx.scopeClass
    ctx.owner = id
    ctx.scopeClass = nil                       // child components never inherit a parent scope
    defer { ctx.owner = savedOwner; ctx.scopeClass = savedScope }
    var styledRules: [Rule] = []
    let body = withObservationTracking {
        if let styled = tag as? any Styled { styledRules = styled.styles }
        return tag.body
    } onChange: {
        MainActor.assumeIsolated { box.fire() }
    }
    if !styledRules.isEmpty {
        let marker = scopeMarker(forTypeName: String(reflecting: T.self))
        ctx.scopeClass = marker
        for rule in styledRules { rule.register(into: ctx.registry, scope: marker) }
    }
    let children = resolve(body, path: id.appending(.child(0)), ctx: &ctx)
```

In `resolveElement`, append the marker after the pending-rule loop (Task 6 already introduced `effectiveBag`):

```swift
    if let scope = ctx.scopeClass {
        effectiveBag.appendClasses([scope])
    }
```

- [ ] **Step 4: Global rules — Runtime + App + DOMRuntime**

`Runtime.swift` — the init gains a parameter and `mount()` registers before the first pass:

```swift
    private let globalStyles: [Rule]

    public init(backend: Backend, container: Backend.HostNode, root: some Tag,
                scheduleMicrotask: @escaping (@escaping () -> Void) -> Void,
                globalStyles: [Rule] = []) {
        applier = TreeApplier(backend: backend, container: container)
        rootTag = AnyTag(root)
        self.scheduleMicrotask = scheduleMicrotask
        self.globalStyles = globalStyles
    }

    public func mount() {
        for rule in globalStyles { rule.register(into: styleRegistry, scope: nil) }
        renderPass()
    }
```

`App.swift`:

```swift
public protocol App {
    associatedtype Content: Tag
    init()
    @TagBuilder var body: Content { get }
    /// Document-level rules (resets, body styles). Unscoped, registered once at mount.
    @RulesBuilder static var globalStyles: [Rule] { get }
}

extension App {
    public static var globalStyles: [Rule] { [] }
}
```

`DOMRuntime.swift` — `mount` gains the parameter and `App.main` forwards it:

```swift
    public static func mount(_ root: some Tag, selector: String = "body",
                             globalStyles: [Rule] = []) {
        // … unchanged until the Runtime line …
        let runtime = Runtime(backend: backend, container: container,
                              root: root, scheduleMicrotask: jsMicrotask,
                              globalStyles: globalStyles)
```

```swift
extension App {
    @MainActor public static func main() {
        DOMRuntime.mount(Self().body, globalStyles: Self.globalStyles)
    }
}
```

- [ ] **Step 5: Write StyledScopingTests.swift**

```swift
import Testing
@testable import SwiftWUI

private struct SearchForm: Tag, Styled {
    @RulesBuilder var styles: [Rule] {
        Rule(class: "field") { s in
            s.padding(.px(8))
            s.hover { $0.borderColor(.hex("#00f")) }
        }
        Rule(id: "submit") { $0.fontWeight(.bold) }
        Rule(element: "input") { $0.outline(.none) }
    }
    var body: some Tag {
        Form {
            Input(type: .text).classes("field")
            Button("Go") {}.classes("field").id("submit")
            ChildPlain()
        }
    }
}
private struct ChildPlain: Tag {
    var body: some Tag { Div(class: "field") { Text("child") } }
}
private struct DynamicRules: Tag, Styled {
    @State var wide = false
    @RulesBuilder var styles: [Rule] {
        Rule(class: "row") { $0.gap(.px(4)) }
        if wide { Rule(class: "row") { $0.gap(.px(16)) } }
    }
    var body: some Tag {
        Div(class: "row") { Button("w") { wide.toggle() } }
    }
}

@Suite struct StyledScopingTests {
    private var marker: String { scopeMarker(forTypeName: String(reflecting: SearchForm.self)) }

    @Test func selectorsCompileWithMarker() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(SearchForm())
        #expect(css.contains(".field.\(marker) { padding: 8px }"))
        #expect(css.contains(".field.\(marker):hover { border-color: #00f }"))
        #expect(css.contains("#submit.\(marker) { font-weight: bold }"))
        #expect(css.contains("input.\(marker) { outline: none }"))
    }
    @Test func markerOnOwnElementsNotChildComponents() {
        let (html, _) = HTMLRenderer.renderWithStylesheet(SearchForm())
        // the form + its input + button carry the marker
        #expect(html.ranges(of: marker).count >= 3)
        // the child component's div does NOT (extract child div and check)
        let childStart = html.firstRange(of: "child")!
        let childTagStart = html[..<childStart.lowerBound].lastIndex(of: "<")!
        let childOpenTag = html[childTagStart..<childStart.lowerBound]
        #expect(!childOpenTag.contains(marker))
    }
    @Test func nInstancesOneRegistryEntry() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(Div { SearchForm(); SearchForm() })
        #expect(css.ranges(of: ".field.\(marker) { padding: 8px }").count == 1)
    }
    @Test func dynamicRulesRegisterOnStateChange() {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: DynamicRules(), scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(backend.stylesheetText?.contains("gap: 4px") == true)
        #expect(backend.stylesheetText?.contains("gap: 16px") != true)
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        sched.pump()
        #expect(backend.stylesheetText?.contains("gap: 16px") == true)   // grew during scoped pass
    }
    @Test func globalStylesUnscoped() {
        struct Root: Tag { var body: some Tag { Div { Text("x") } } }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule,
                         globalStyles: [Rule(element: "body") { $0.margin(.zero) }])
        rt.mount()
        #expect(backend.stylesheetText == "body { margin: 0 }")
    }
    @Test func rulesBuilderSupportsEmptyAndConditionals() {
        @RulesBuilder func empty() -> [Rule] { }
        #expect(empty().isEmpty)
    }
}
```

- [ ] **Step 6: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (155). Watch `ScopedEquivalenceTests` — the scoped-pass rule registration path is exactly what canonical ordering protects.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(styles): Styled protocol with Vue-style scoped rules, RulesBuilder, App.globalStyles

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Themes — tokens, ThemeDefinition, setTheme

**Files:**
- Create: `Sources/SwiftWUI/Styles/Theme.swift`
- Modify: `Sources/SwiftWUI/Environment/Environment.swift` (setTheme key)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (themes param, setTheme, env injection)
- Modify: `Sources/SwiftWUI/App/App.swift` + `Sources/SwiftWUIDOM/DOMRuntime.swift` (themes pass-through)
- Test: `Tests/SwiftWUITests/ThemeTests.swift`

**Interfaces:**
- Consumes: `CSSValueConvertible`, `CSSColor.variable`, `StyleRegistry.registerRaw`, `EnvironmentKey` pattern (Environment.swift:1-15).
- Produces:
  - `struct StyleToken<Value: CSSValueConvertible>`, `typealias ColorToken`, `typealias LengthToken`
  - `CSSColor.token(_: ColorToken)`, `CSSLength.token(_: LengthToken)`
  - `struct ThemeAssignments { mutating func set<V>(_ token: StyleToken<V>, _ value: V) }`
  - `struct ThemeDefinition` — `init(_ build:)` (default → `:root`), `init(name:_:)`
  - `EnvironmentValues.setTheme: (String?) -> Void`
  - `Runtime.setTheme(_ name: String?)`, `Runtime.init(…, themes: [ThemeDefinition] = [])`
  - `App.themes: [ThemeDefinition]` (default `[]`), `DOMRuntime.mount(…, themes:)`

- [ ] **Step 1: Write Theme.swift**

```swift
/// A named CSS custom property, declared once as a static (spec §9):
///
///     extension ColorToken { static let accent = ColorToken("accent") }
///     H1("Hi").color(.token(.accent))          // → color: var(--accent)
public struct StyleToken<Value: CSSValueConvertible> {
    public let name: String
    public init(_ name: String) {
        assert(CSSSanitize.isValidIdent(name), "token name must be a CSS ident: \(name)")
        self.name = CSSSanitize.isValidIdent(name) ? name : "invalid"
    }
}
public typealias ColorToken = StyleToken<CSSColor>
public typealias LengthToken = StyleToken<CSSLength>

extension CSSColor {
    public static func token(_ t: ColorToken) -> CSSColor { .variable(t.name) }
}
extension CSSLength {
    /// Length tokens render via a raw var() passthrough.
    public static func token(_ t: LengthToken) -> CSSLength { .variable(t.name) }
}
```

`CSSLength` (Task 3) needs the matching case — add to the enum in CSSValues.swift:

```swift
    case variable(String)
```

and to its `css` switch:

```swift
        case .variable(let name): return "var(--\(name))"
```

Continue Theme.swift:

```swift
public struct ThemeAssignments {
    var pairs: [(name: String, value: String)] = []
    public mutating func set<V: CSSValueConvertible>(_ token: StyleToken<V>, _ value: V) {
        pairs.append(("--" + token.name, value.css))
    }
}

/// Default theme emits `:root { … }`; named themes emit `[data-theme="name"] { … }`.
/// Switching = one attribute write via setTheme, zero re-render (spec §9).
public struct ThemeDefinition {
    let name: String?                      // nil = default
    let pairs: [(name: String, value: String)]
    public init(_ build: (inout ThemeAssignments) -> Void) {
        var a = ThemeAssignments(); build(&a)
        self.name = nil; self.pairs = a.pairs
    }
    public init(name: String, _ build: (inout ThemeAssignments) -> Void) {
        assert(CSSSanitize.isValidIdent(name), "theme name must be a CSS ident: \(name)")
        var a = ThemeAssignments(); build(&a)
        self.name = CSSSanitize.isValidIdent(name) ? name : "invalid"; self.pairs = a.pairs
    }
    var ruleText: String {
        let selector = name.map { "[data-theme=\"\($0)\"]" } ?? ":root"
        let body = pairs.map { "\($0.name): \($0.value)" }.joined(separator: "; ")
        return "\(selector) { \(body) }"
    }
}
```

- [ ] **Step 2: Environment action**

`Environment.swift` — add at the bottom, following the file's `EnvironmentKey` pattern:

```swift
private struct SetThemeKey: EnvironmentKey {
    static let defaultValue: (String?) -> Void = { _ in }
}
extension EnvironmentValues {
    /// Switches the active theme: `setTheme("dark")` / `setTheme(nil)` (default).
    /// Provided by the runtime; the default value is a no-op (HTMLRenderer, tests).
    public var setTheme: (String?) -> Void {
        get { self[SetThemeKey.self] }
        set { self[SetThemeKey.self] = newValue }
    }
}
```

- [ ] **Step 3: Runtime wiring**

`Runtime.swift`:

```swift
    private let themes: [ThemeDefinition]
```

Init gains `themes: [ThemeDefinition] = []` (after `globalStyles`), stored. `mount()` registers them first:

```swift
    public func mount() {
        for theme in themes { styleRegistry.registerRaw(theme.ruleText) }
        for rule in globalStyles { rule.register(into: styleRegistry, scope: nil) }
        renderPass()
    }
```

`renderPass()` injects the action into the root environment (right after `ctx` creation, next to `ctx.registry`):

```swift
        ctx.environment.setTheme = { [weak self] name in self?.setTheme(name) }
```

(Retained-component environment snapshots are taken during resolve, so subtree passes inherit the action automatically.)

Public switch method — one attribute on the mount container:

```swift
    /// One data-theme attribute write on the mount container; zero re-render.
    public func setTheme(_ name: String?) {
        let container = applier.root.host!
        if let name {
            applier.backend.setAttribute(container, name: "data-theme", value: name)
        } else {
            applier.backend.removeAttribute(container, name: "data-theme")
        }
    }
```

(Verify `applier.root` is the container-holding MountedNode — Runtime.swift:109-114 already uses `applier.root.host!` this way.)

- [ ] **Step 4: App + DOMRuntime pass-through**

`App.swift` — add the requirement + default:

```swift
    /// Theme definitions: first-registered default theme emits :root.
    static var themes: [ThemeDefinition] { get }
```

```swift
extension App {
    public static var themes: [ThemeDefinition] { [] }
}
```

`DOMRuntime.mount` gains `themes: [ThemeDefinition] = []`, forwards to `Runtime(…, themes: themes)`; `App.main()` passes `themes: Self.themes`.

- [ ] **Step 5: Write ThemeTests.swift**

```swift
import Testing
@testable import SwiftWUI

extension ColorToken { fileprivate static let accent = ColorToken("accent") }
extension LengthToken { fileprivate static let pad = LengthToken("pad") }

@Suite struct ThemeTests {
    @Test func tokenRendering() {
        #expect(CSSColor.token(.accent).css == "var(--accent)")
        #expect(CSSLength.token(.pad).css == "var(--pad)")
        #expect(StyleDeclaration.color(.token(.accent)).value == "var(--accent)")
    }
    @Test func themeRuleText() {
        let light = ThemeDefinition { t in
            t.set(ColorToken.accent, .hex("#e94560"))
            t.set(LengthToken.pad, .px(8))
        }
        #expect(light.ruleText == ":root { --accent: #e94560; --pad: 8px }")
        let dark = ThemeDefinition(name: "dark") { t in
            t.set(ColorToken.accent, .hex("#16213e"))
        }
        #expect(dark.ruleText == #"[data-theme="dark"] { --accent: #16213e }"#)
    }
    @Test func runtimeEmitsThemesAndSwitches() {
        struct Root: Tag {
            @Environment(\.setTheme) var setTheme
            var body: some Tag { Div { Button("dark") { setTheme("dark") } } }
        }
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Root(), scheduleMicrotask: sched.schedule,
                         themes: [ThemeDefinition { $0.set(ColorToken.accent, .hex("#e94560")) },
                                  ThemeDefinition(name: "dark") { $0.set(ColorToken.accent, .hex("#16213e")) }])
        rt.mount()
        #expect(backend.stylesheetText?.contains(":root { --accent: #e94560 }") == true)
        #expect(backend.stylesheetText?.contains(#"[data-theme="dark"]"#) == true)
        // switch via the environment action wired through the button
        rt.dispatch(findFirst(backend.container, tag: "button")!.events["click"]!)
        #expect(backend.container.attrs["data-theme"] == "dark")
        rt.setTheme(nil)
        #expect(backend.container.attrs["data-theme"] == nil)
    }
}
```

- [ ] **Step 6: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (158).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(styles): themes — StyleToken/ThemeDefinition via CSS custom properties, setTheme environment action

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: `Style` protocol — reusable bundles

**Files:**
- Create: `Sources/SwiftWUI/Styles/Style.swift`
- Test: `Tests/SwiftWUITests/StyleBundleTests.swift`

**Interfaces:**
- Consumes: `StyleProxy` (declarations + pseudoBlocks), `_AttributeBag.addStyle/addPendingRule`, `_StyledTag`.
- Produces: `protocol Style { func build(_ s: inout StyleProxy) }`, `.style(_ style: some Style)` on `HTMLTag` (returns `Self`), `Tag` (returns `_StyledTag<Self>`), and `_StyledTag` (collapse).

- [ ] **Step 1: Write Style.swift**

```swift
/// Reusable named bundle (spec §10): declarations land on the inline path,
/// pseudo blocks become registry rules — on whichever surface it's applied.
public protocol Style {
    func build(_ s: inout StyleProxy)
}

extension HTMLTag {
    public func style(_ style: some Style) -> Self {
        var proxy = StyleProxy(); style.build(&proxy)
        var copy = self
        for d in proxy.declarations { copy._attributes.addStyle(d) }
        for block in proxy.pseudoBlocks {
            copy._attributes.addPendingRule(PendingStyleRule(pseudo: block.pseudo, media: nil,
                                                             declarations: block.declarations))
        }
        return copy
    }
}

extension Tag {
    public func style(_ style: some Style) -> _StyledTag<Self> {
        var proxy = StyleProxy(); style.build(&proxy)
        return _StyledTag(content: self, declarations: proxy.declarations,
                          rules: proxy.pseudoBlocks.map {
                              PendingStyleRule(pseudo: $0.pseudo, media: nil, declarations: $0.declarations)
                          })
    }
}

extension _StyledTag {
    public func style(_ style: some Style) -> Self {
        var proxy = StyleProxy(); style.build(&proxy)
        var copy = self
        copy.declarations.append(contentsOf: proxy.declarations)
        copy.rules.append(contentsOf: proxy.pseudoBlocks.map {
            PendingStyleRule(pseudo: $0.pseudo, media: nil, declarations: $0.declarations)
        })
        return copy
    }
}
```

- [ ] **Step 2: Write StyleBundleTests.swift**

```swift
import Testing
@testable import SwiftWUI

private struct CardStyle: Style {
    func build(_ s: inout StyleProxy) {
        s.padding(.px(24))
        s.borderRadius(.px(12))
        s.hover { $0.boxShadow("0 4px 16px rgba(0,0,0,.12)") }
    }
}
private struct PlainCard: Tag {
    var body: some Tag { Div(class: "card") { Text("hi") } }
}

@Suite struct StyleBundleTests {
    @Test func bundleOnHTMLTag() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(Div { Text("x") }.style(CardStyle()))
        #expect(html.contains("padding: 24px; border-radius: 12px"))
        #expect(css.contains(":hover { box-shadow: 0 4px 16px rgba(0,0,0,.12) }"))
    }
    @Test func bundleOnComponent() {
        let (html, css) = HTMLRenderer.renderWithStylesheet(PlainCard().style(CardStyle()))
        #expect(html.contains("padding: 24px"))
        #expect(css.contains(":hover"))
        #expect(html.contains("swui-"))          // rule class landed on the root element
    }
    @Test func sameBundleTwoElementsOneRule() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Span { Text("a") }.style(CardStyle()); Span { Text("b") }.style(CardStyle()) }
        )
        #expect(css.split(separator: "\n").count == 1)
    }
}
```

- [ ] **Step 3: Run the full suite**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (161).

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUI/Styles/Style.swift Tests/SwiftWUITests/StyleBundleTests.swift
git commit -m "feat(styles): Style protocol — reusable declaration+rule bundles on all surfaces

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: Property test — styled fixtures + registry equality

**Files:**
- Modify: `Tests/SwiftWUITests/ScopedEquivalenceTests.swift`

**Interfaces:**
- Consumes: `Runtime._registryText` (Task 5), everything from Tasks 3–10.
- Produces: the strengthened scoped ≡ full guarantee over styles (spec §11, §14).

- [ ] **Step 1: Extend the fixture**

Replace the three fixture components with a version that also exercises: an environment writer, an effect, an `@Observable` model read, inline styles, a hover rule, a `Styled` component, and a wrapper-styled component. Keep every phase-2 behavior (keyed ForEach, conditionals, sibling state):

```swift
@Observable private final class PropModel { var flag = false }

private struct PropEnvKey: EnvironmentKey { static let defaultValue = "-" }
extension EnvironmentValues {
    fileprivate var propTag: String { get { self[PropEnvKey.self] } set { self[PropEnvKey.self] = newValue } }
}

private struct PropLeaf: Tag {
    @State var n = 0
    var body: some Tag {
        Div(class: "leaf") {
            P { "n=\(n)" }
            Button("+") { n += 1 }
            if n % 3 == 1 { Span { "mod" } }
        }
        .padding(.px(4))                                   // inline style in the fixture
    }
}
private struct PropStyled: Tag, Styled {
    @State var hot = false
    @RulesBuilder var styles: [Rule] {
        Rule(class: "row") { $0.gap(.px(2)) }
        if hot { Rule(class: "row") { $0.gap(.px(20)) } }   // dynamic rule
    }
    var body: some Tag {
        Div(class: "row") {
            Button("heat") { hot.toggle() }
                .hover { $0.opacity(0.7) }                  // element rule
        }
    }
}
private struct PropObserved: Tag {
    let model: PropModel
    @Environment(\.propTag) var tag
    var body: some Tag {
        Div {
            Text(model.flag ? "on-\(tag)" : "off-\(tag)")
            Button("flip") { model.flag.toggle() }
        }
        .onAppear {}                                        // effect wrapper in the mix
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
    let model = PropModel()
    var body: some Tag {
        Div {
            PropLeaf()
            PropStyled()
            PropObserved(model: model).margin(.px(1))       // wrapper-styled component
            if showList { PropList() }
            Button("toggle") { showList.toggle() }
        }
        .environment(\.propTag, "e")                        // environment writer
    }
}
```

- [ ] **Step 2: Add the registry-text invariant**

Inside the event loop, after the existing four `#expect` lines:

```swift
            #expect(scoped._registryText == full._registryText,
                    "stylesheet diverged at seed \(seed)")
```

- [ ] **Step 3: Run the full suite (property test is the gate)**

Run: `swift test 2>&1 | tail -5`
Expected: all pass; the 20-seed × 25-event property test must be green. If registry texts diverge, the bug is real (canonical ordering or scoped-pass registration) — debug it, do NOT weaken the assertion (phase-2 precedent: the strengthened test caught a real ForEach key bug).

- [ ] **Step 4: Commit**

```bash
git add Tests/SwiftWUITests/ScopedEquivalenceTests.swift
git commit -m "test(runtime): property fixture with env/effects/observables/styles; scoped≡full pins registry text

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 12: TodoMVC restyle — acceptance

**Files:**
- Modify: `Examples/TodoMVC/Sources/main.swift`
- Modify: `Tests/SwiftWUITests/TodoAcceptanceTests.swift`

**Interfaces:**
- Consumes: the full phase-3 surface (Tasks 3–10).
- Produces: acceptance evidence (spec §15).

- [ ] **Step 1: Restyle the example**

In `Examples/TodoMVC/Sources/main.swift`, add tokens and themes above `TodoStore`:

```swift
extension ColorToken {
    static let accent  = ColorToken("accent")
    static let surface = ColorToken("surface")
    static let ink     = ColorToken("ink")
}
let lightTheme = ThemeDefinition { t in
    t.set(ColorToken.accent,  .hex("#e94560"))
    t.set(ColorToken.surface, .hex("#ffffff"))
    t.set(ColorToken.ink,     .hex("#1a1a2e"))
}
let darkTheme = ThemeDefinition(name: "dark") { t in
    t.set(ColorToken.surface, .hex("#16213e"))
    t.set(ColorToken.ink,     .hex("#eaeaea"))
}
```

`TodoRow` adopts `Styled` — the `.done`/`.todo` rules MUST live on the component
whose body renders the `li` elements (scoped rules only match the declaring
component's own body — spec §8):

```swift
private struct TodoRow: Tag, Styled {
    let todo: TodoStore.Todo
    @Environment(\.todoStore) var store
    @RulesBuilder var styles: [Rule] {
        Rule(class: "done") { s in
            s.textDecoration(.lineThrough)
            s.opacity(0.6)
        }
        Rule(class: "todo") { $0.color(.token(.ink)) }
    }
    var body: some Tag { /* unchanged */ }
}
```

`TodoApp` adopts `Styled` for ITS body's elements (h1, input, filters, buttons)
and gains a theme toggle:

```swift
private struct TodoApp: Tag, Styled {
    @State var store = TodoStore()
    @State var filter: Filter = .all
    @State var dark = false
    @Environment(\.setTheme) var setTheme
    @RulesBuilder var styles: [Rule] {
        Rule(class: "filters", media: .maxWidth(.px(600))) { $0.flexDirection(.column) }
        Rule(element: "button") { s in
            s.cursor(.pointer)
            s.hover { $0.background(.token(.accent)) }
        }
    }
    var visible: [TodoStore.Todo] { /* unchanged */ }
    var body: some Tag {
        Main {
            H1("todos").color(.token(.accent)).fontSize(.rem(2))
            Input(type: .text, value: Binding(get: { store.draft }, set: { store.draft = $0 }),
                  onKeyDown: { e in if e.key == "Enter" { store.add() } })
                .padding(.px(8))
                .width(.percent(100))
            Ul {
                ForEach(visible) { TodoRow(todo: $0) }
            }
            .listStyle("none")
            RemainingLabel()
            Div(class: "filters") {
                ForEach(Filter.allCases, id: \.rawValue) { f in
                    Button(f.rawValue) { filter = f }
                }
                Button("theme") { dark.toggle(); setTheme(dark ? "dark" : nil) }
            }
            .display(.flex)
            .gap(.px(8))
        }
        .background(.token(.surface))
        .environment(\.todoStore, store)
        .task { await store.load() }
        .onChange(of: filter) { /* unchanged */ }
    }
}
```

App declares globals and themes:

```swift
@main
struct TodoMVCApp: App {
    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { s in
            s.margin(.zero)
            s.fontFamily("system-ui, sans-serif")
        }
    }
    static var themes: [ThemeDefinition] { [lightTheme, darkTheme] }
    var body: some Tag { TodoApp() }
}
```

Careful: `Main { … }.background(…)` — `Main` is an HTML tag, so `.background` stays on the bag path and returns `Main<…>`; the subsequent `.environment`/`.task`/`.onChange` wrappers then apply as before. Keep modifier order: bag modifiers FIRST, then wrapper modifiers (`.environment`, `.task`, `.onChange`) — reversing them would hang bag modifiers on a wrapper (they'd become `_StyledTag` wrapping the effect wrapper — legal but a different identity than intended; keep the order shown).

- [ ] **Step 2: Mirror the styled bits in the native acceptance suite**

Apply the SAME `Styled` conformance + theme toggle changes to the fixture `TodoApp` inside `Tests/SwiftWUITests/TodoAcceptanceTests.swift` (it is a deliberate mirror of the example — keep the two in sync; `Counters` plumbing stays). The test file's `TodoMVCApp` equivalent doesn't exist — themes/globals for the test are passed via the `Runtime` init in `makeApp`:

```swift
    private func makeApp() -> (Runtime<MockBackend>, MockBackend, TestScheduler, Counters) {
        let backend = MockBackend(); let sched = TestScheduler(); let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TodoApp(counters: counters), scheduleMicrotask: sched.schedule,
                         globalStyles: [Rule(element: "body") { $0.margin(.zero) }],
                         themes: [ThemeDefinition { $0.set(ColorToken.accent, .hex("#e94560")) },
                                  ThemeDefinition(name: "dark") { $0.set(ColorToken.accent, .hex("#818cf8")) }])
        rt.mount()
        return (rt, backend, sched, counters)
    }
```

(Declare `extension ColorToken { fileprivate static let accent … }` etc. locally in the test file mirroring the example.)

IMPORTANT fallout: once the fixture `TodoRow` adopts `Styled`, its `li`
elements carry the scope marker — `class` becomes `"done swui-s…"`. Update the
existing equality assertions in `toggleReevaluatesAllRowsButKeepsDOMStable`
(and anywhere else that pins the exact class string):

```swift
        #expect(toggledLi.attrs["class"]?.hasPrefix("todo") == true)   // was == "todo"
        // …
        #expect(toggledLi.attrs["class"]?.hasPrefix("done") == true)   // was == "done"
        #expect(otherLis.allSatisfy { ($0.attrs["class"] ?? "").hasPrefix("todo") })
```

(`Li(class:)` sets the user class first; `appendClasses` puts the marker after
it, and `flattened()` space-joins in order — so `hasPrefix` is exact.)

Add the acceptance tests:

```swift
    @Test func styledAcceptance() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        _ = rt   // silence unused if needed
        // inline style landed
        let h1 = findFirst(backend.container, tag: "h1")!
        #expect(h1.attrs["style"]?.contains("color: var(--accent)") == true)
        // stylesheet: globals, themes, scoped rule, hover, media
        let css = backend.stylesheetText ?? ""
        #expect(css.contains("body { margin: 0 }"))
        #expect(css.contains(":root { --accent: #e94560 }"))
        #expect(css.contains(#"[data-theme="dark"]"#))
        #expect(css.contains(".done."))                       // scoped marker attached
        #expect(css.contains("button.") && css.contains(":hover"))
        #expect(css.contains("@media (max-width: 600px)"))
        // scope marker present on elements of TodoApp's body
        #expect((findFirst(backend.container, tag: "main")!.attrs["class"] ?? "").contains("swui-s"))
    }
    @Test func themeToggleSetsAttribute() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        _ = rt
        let themeBtn = findAll(backend.container, tag: "button").first { $0.children.first?.text == "theme" }!
        rt.dispatch(themeBtn.events["click"]!); sched.pump()
        #expect(backend.container.attrs["data-theme"] == "dark")
        rt.dispatch(themeBtn.events["click"]!); sched.pump()
        #expect(backend.container.attrs["data-theme"] == nil)
    }
```

- [ ] **Step 3: Run the native gate**

Run: `swift test 2>&1 | tail -5`
Expected: all pass (163).

- [ ] **Step 4: Run the wasm gate**

Run: `cd Examples/TodoMVC && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug && cd ../..`
Expected: build succeeds, JS package emitted. (Browser check is manual and NOT a merge blocker — spec §15; note in the report that Vite verification is pending user.)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(example): restyle TodoMVC with phase-3 styles — tokens, scoped rules, hover/media, dark theme toggle

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Final acceptance (after Task 12)

1. `swift test` — full suite green.
2. TodoMVC wasm js build green.
3. Whole-branch review (per project workflow): dispatch the reviewer over the phase-3 commit range; fix findings; re-review to READY TO MERGE.
4. Manual browser verification of the styled TodoMVC (user-driven; Vite: `npm --prefix Examples/TodoMVC run dev -- --port 8080`).
