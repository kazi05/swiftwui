# Swift Language Recommendations for SwiftWUI

Concrete uses of Swift 5.9 -> 6.2 features tailored to a single-threaded WASM target. Effort: S (<1d), M (1-3d), L (>3d).

---

## 1. `@Tag` macro to eliminate primitive boilerplate

**Change.** Each HTML tag (Div, Span, Form, etc.) repeats the same property bag (`attributes`, `eventListeners`, `styles`, `classes`, `children`, `observers`) plus an `init`. A peer/member macro generates the conformance.

**Before** (Tags/Div.swift, ~30 LOC repeated x16):
```swift
public struct Div: HTMLTag, TagNodeConvertible {
    public static let tagName = "div"
    public var attributes: [String: String] = [:]
    public var eventListeners: [String: EventHandler] = [:]
    public var styles: [String: String] = [:]
    public var classes: [String] = []
    public var children: [AnyTag]
    public var observers: [WebObserver] = []
    public init(class className: String? = nil, id: String? = nil,
                @TagBuilder content: () -> some Tag = { EmptyTag() }) { /* ... */ }
}
```

**After:**
```swift
@HTMLElement("div")
public struct Div {}      // 1 line. Macro emits all storage + init + HTMLTag conformance.
```

**Impact.** DX big win (-90% LOC for tags); zero binary cost (macro expands to current code). Catches misspellings at compile time.
**Effort.** M. Macro is a `MemberMacro + ExtensionMacro` plugin in swift-syntax.

---

## 2. `#html` literal macro for templating

**Change.** A `FreestandingExpressionMacro` parses HTML at compile time into Tag tree.

**Before:**
```swift
Div { H1 { "Title" }; P { "Hello \(name)" } }.class("hero")
```

**After:**
```swift
#html("""
<div class="hero">
  <h1>Title</h1>
  <p>Hello \(name)</p>
</div>
""")
```

**Impact.** Optional ergonomics; designers can paste HTML. Compile-time validated against tag whitelist. No runtime parser -> zero binary cost.
**Effort.** L. Needs SwiftSyntax HTML parser; reuse swift-html-parser.

---

## 3. `@Bindable`-style projection via macro

**Change.** Mirror SwiftUI's `@Bindable` so users can write `$model.field` on `@Observable` classes without `@State`.

**Before:** must wrap in `@State var model = FormModel()` then use `Binding`'s dynamicMemberLookup.

**After:**
```swift
@Bindable var model: FormModel  // generates wrapper that vends Binding<T> via $model.field
Input(text: $model.name)
```

**Impact.** Aligns with SwiftUI mental model; removes accidental state recreation bugs.
**Effort.** S. Thin wrapper using existing dynamicMemberLookup infra in `Binding`.

---

## 4. Result builder 2.0: `buildPartialBlock` for O(n) compile time

**Change.** TagBuilder uses parameter packs (good) but pays type-check cost per overload. Adding `buildPartialBlock` reduces type checker load and enables better diagnostics.

**Before** (TagBuilder.swift:29):
```swift
public static func buildBlock<each T: Tag>(_ components: repeat each T) -> TupleTag {
    var children: [any Tag] = []
    repeat children.append(each components)   // boxes into existential
    return TupleTag(children: children)
}
```

**After:**
```swift
public static func buildPartialBlock<First: Tag>(first: First) -> TuplePair<First, EmptyTag> {
    TuplePair(First, EmptyTag())
}
public static func buildPartialBlock<Acc: Tag, Next: Tag>(
    accumulated: Acc, next: Next
) -> TuplePair<Acc, Next> {
    TuplePair(accumulated, next)
}
```

`TuplePair<A, B>` is a recursive struct holding both children; full type information preserved -> reconciler can specialize.

**Impact.** -30-50% compile time on deep view trees; enables monomorphic dispatch in `toTagNodes()`. Removes `[any Tag]` boxing in TupleTag.
**Effort.** M. Coexist with packs for variadic case; deprecate `[any Tag]` storage.

---

## 5. Parameter packs for `TupleTag` (eliminate existential array)

**Change.** Replace `TupleTag.children: [any Tag]` with a pack-typed struct.

**Before** (TupleTag.swift):
```swift
public struct TupleTag: Tag {
    public let children: [any Tag]   // existential boxing per child
}
```

**After:**
```swift
public struct TupleTag<each Child: Tag>: Tag, TagNodeConvertible {
    public typealias Body = Never
    public let children: (repeat each Child)
    public func toTagNodes() -> [TagNode] {
        var nodes: [TagNode] = []
        for child in repeat each children {
            if let c = child as? TagNodeConvertible { nodes.append(contentsOf: c.toTagNodes()) }
            else { nodes.append(contentsOf: resolveTagBody(child)) }
        }
        return nodes
    }
}
```

**Impact.** Removes per-child existential allocation; ARC traffic drops; specialization enables inlining of `toTagNodes`. Estimated -10-20% render time on hot paths.
**Effort.** M. Touches TagBuilder + every site that pattern-matches TupleTag.

---

## 6. Typed throws (Swift 6) for renderer & devserver

**Change.** Reconciler/renderer/devserver currently swallow errors silently or `print`. Use typed throws to make recovery explicit.

**Before** (DevServer.swift):
```swift
func rebuild() {
    let result = builder.build()
    if !result.success { print("...") }   // string-based error
}
```

**After:**
```swift
enum BuildError: Error { case sdkMissing, compileFailed(stderr: String), wasmMissing }
func rebuild() throws(BuildError) -> BuildArtifact {
    guard let sdk = WASMBuilder.detectSDK() else { throw .sdkMissing }
    let r = try builder.build()  // throws(BuildError)
    return r
}

// Renderer:
enum RenderError: Error { case rootMissing, patchTargetMissing(index: Int) }
func update(_ tag: some Tag) throws(RenderError) { ... }
```

**Impact.** Zero binary cost (typed throws lower to discriminated unions, no existential `any Error`). Better diagnostics in dev server WebSocket protocol.
**Effort.** S for devserver, M for renderer (touches Application.swift render loop).

---

## 7. `~Copyable` for unique resources (JS observer / closure handles)

**Change.** `JSClosure`, `IntersectionObserver`, `ResizeObserver` are linear resources: leaking them leaks JS callbacks. Wrap in noncopyable types so the compiler enforces single ownership.

**Before** (DOMRenderer.swift:27): observers stored in `[ObjectIdentifier: [JSObject]]` -> easy to double-free or forget to disconnect.

**After:**
```swift
struct OwnedJSObserver: ~Copyable {
    private let underlying: JSObject
    init(_ js: JSObject) { self.underlying = js }
    consuming func disconnect(via bridge: DOMBridge) {
        bridge.disconnectObserver(underlying)
    }
    deinit { /* warn if not disconnected */ }
}
```

Renderer holds `[ObjectIdentifier: [OwnedJSObserver]]`; cleanupObservers consumes them.

**Impact.** Eliminates a class of leaks; makes lifetime errors compile-time. Slightly safer hot reload (current devserver rebuild leaks observers across reloads).
**Effort.** M. Requires Swift 5.9+; touches DOMRenderer cleanupObservers paths.

---

## 8. `~Escapable` & `Span<T>` for reconciler hot paths

**Change.** Reconciler.diffChildren allocates `[ChildPatch]` per element. With Swift 6.2 `Span<T>`, walk children without ARC traffic on intermediate arrays.

**Before** (Reconciler.swift:144):
```swift
private func diffChildren(old: [TagNode], new: [TagNode]) -> [ChildPatch] {
    var patches: [ChildPatch] = []
    for i in 0..<max(old.count, new.count) { ... patches.append(...) }
    return patches
}
```

**After:**
```swift
func diffChildren(old: Span<TagNode>, new: Span<TagNode>,
                  into patches: inout OutputSpan<ChildPatch>) { ... }
```

`Span` is `~Escapable`; no allocation, no ARC. Buffer pooled across diffs.

**Impact.** -20-40% reconciliation time on large trees; smaller heap pressure on WASM (matters: WASM linear memory growth is expensive). Smaller binary if Array specialization is replaced with span.
**Effort.** L. Requires Swift 6.2 toolchain; reconciler API churn; pool management.

---

## 9. Strict concurrency: `nonisolated(unsafe)` cleanup + isolation regions

**Change.** Globals (`EventHandlerRegistry`, `OnChangeStorage`, all `EventContext`s) use `nonisolated(unsafe) static var` with `#if !arch(wasm32)` NSLock branches. Swift 6.2 `@isolated(any)` and isolation regions let us model "single-threaded WASM" cleanly.

**Before** (EventHandlerRegistry.swift:14):
```swift
nonisolated(unsafe) private static var handlers: [String: @Sendable () -> Void] = [:]
#if !arch(wasm32)
private static let lock = NSLock()
#endif
```

**After:** Define a `@globalActor WebMain` actor and mark all single-threaded singletons isolated to it. On WASM, the actor compiles down to no-op (single thread). On native (test path) it serializes via task executor without NSLock.

```swift
@globalActor
public actor WebMain { public static let shared = WebMain() }

@WebMain
public enum EventHandlerRegistry {
    public static var handlers: [EventListenerID: @Sendable () -> Void] = [:]
    public static func register(_ h: @escaping @Sendable () -> Void) -> EventListenerID { ... }
}
```

Renderer becomes `@WebMain`; tag conversion runs synchronously in that domain. Removes every `#if !arch(wasm32)` lock branch.

**Impact.** Removes ~80 lines of `#if`-guarded locking; uniform code path; fewer Sendable warnings; smaller binary on WASM (no NSLock symbol).
**Effort.** M. Plumbs `@WebMain` through Application.mount; tests run inside `await WebMain.shared.run { ... }`.

---

## 10. Reduce existentials: `some Tag` everywhere, kill `[any Tag]`

**Change.** Audit existential `any Tag` -> use `some Tag` or generics. Remaining genuine type-erasure (router routes, dynamic tag lists) can use a single `AnyTag` opaque box.

**Hot spots.**
- `HTMLTag.children: [AnyTag]` -> for variadic children, switch to pack-based `(repeat each Child)`.
- `TupleTag.children: [any Tag]` -> see #5.
- `AnyTag.storage: any Tag` -> keep, but mark with `_underlyingType` to enable specialization in TagNodeConvertible.

**Impact.** -1-2% binary size (existential metadata is fat in WASM); inlining unlocked for monomorphic call sites.
**Effort.** L. Wide-reaching refactor.

---

## 11. Custom `ExpressibleByStringInterpolation` for `#html` and class lists

**Change.** Build interpolation appender that escapes user input automatically and detects bindings.

```swift
extension HTMLLiteral: ExpressibleByStringInterpolation {
    struct StringInterpolation: StringInterpolationProtocol {
        mutating func appendInterpolation<T: Tag>(_ tag: T) { /* embed safely */ }
        mutating func appendInterpolation(escaped raw: String) { /* trust */ }
        mutating func appendInterpolation<V>(_ binding: Binding<V>) { /* two-way bind */ }
    }
}
let h: HTMLLiteral = "<div class=\"\(cssClass)\">\(name)</div>"  // auto-escaped
```

Same pattern for `ClassList` (`.class(("active", isActive), "card")`).

**Impact.** XSS-safe-by-default; readable templating.
**Effort.** S for ClassList; pairs with #2 for full HTML literal.

---

## 12. Embedded Swift compatibility shims

**Change.** Embedded Swift (no Observation, no reflection, no Foundation) yields ~10x smaller WASM (50-150 KB vs 1.5 MB). Carve out an `SwiftWUICore` that compiles in `--embedded` mode.

**Steps.**
1. Move `Observation`-dependent code (`State`, `StateObserver`, `Application.renderCycle`) to `SwiftWUIState` (already separate -> keep).
2. Provide `EmbeddedState`: closure-based `@State` without `@Observable`. Re-renders triggered manually via `setNeedsRender()`.
3. Replace `UUID().uuidString` with monotonic counter (no Foundation).
4. Replace `[String: ...]` with `Array<(K,V)>` linear scan in hot paths (Embedded forbids generic collection metadata).

**Before:**
```swift
@Observable final class StateStorage<Value> { var value: Value }
```

**After (Embedded path):**
```swift
final class EmbeddedStateStorage<Value: ~Copyable> {
    var value: Value
    var observers: [() -> Void] = []
    func notify() { for o in observers { o() } }
}
```

**Impact.** Order-of-magnitude binary reduction for landing pages / widgets. Two SKUs: "Counter app = 60 KB" embedded vs "Full app = 2 MB" with Observation.
**Effort.** L. New module + parallel API surface; gated behind SwiftPM trait/flag.

---

## 13. swift-syntax codegen for HTML tags from spec

**Change.** Don't hand-write Tags/*.swift. Pull WHATWG `tags.json` at build time, run a swift-syntax generator that emits all 100+ HTML elements + their attributes typed.

**Plan.** SwiftPM build tool plugin `HTMLTagGenerator` reads `Resources/whatwg-elements.json`, emits `Generated/HTMLTags.swift` with one `@HTMLElement(...)` invocation per tag (combined with #1).

**Impact.** Coverage of all HTML5 tags; auto-typed attributes (e.g., `<img>` gets `srcset`, `loading: LoadingMode`); zero maintenance. Binary cost: tree-shaken — unused tags eliminated.
**Effort.** M. Build plugin + JSON of WHATWG attribute table.

---

## 14. `@_alwaysEmitIntoClient` & `@inlinable` on hot paths

**Change.** Mark `resolveTagBody`, `Reconciler.diff`, `TagNodeConvertible.toTagNodes()` `@inlinable`. Mark small modifier helpers `@_alwaysEmitIntoClient` so they're emitted into the user's binary and cross-module-specialized.

**Before** (TagNodeConvertible.swift:115):
```swift
public func resolveTagBody<T: Tag>(_ tag: T) -> [TagNode] { ... }
```

**After:**
```swift
@inlinable
public func resolveTagBody<T: Tag>(_ tag: T) -> [TagNode] { ... }
```

Combined with #5 / #10, the compiler can prove TupleTag children types and inline through.

**Impact.** Render path stops being "library boundary" -> WMO + LTO can collapse the tag tree into straight-line DOM mutations. -20-30% render time hot-path; +small binary if overused.
**Effort.** S. Just annotations; benchmark per-function.

---

## 15. Specific Swift 6.1 / 6.2 features to adopt now

| Feature | Where | Why |
|---|---|---|
| typed throws | `Reconciler`, `WASMBuilder`, `DevServer.rebuild` | exhaustive error handling, zero overhead |
| `sending` parameters | `EventHandlerRegistry.register(_:)`, `Tag` closures | clearer ownership transfer to global registry |
| isolation regions (SE-0414) | `@WebMain` boundary in #9 | suppress false-positive Sendable diagnostics |
| `@isolated(any)` closures | `OnChangeTag.action`, `TaskTag.action` | callable from any actor without erasure |
| `Span<T>` / `MutableSpan<T>` | Reconciler children diff #8 | borrow-only iteration, no allocation |
| `~Copyable` enums | `Patch` enum case payloads (avoid copies of large `TagNode`) | reconciler patches stop deep-copying |
| `nonisolated(nonsending)` | tag struct methods | safe call from `@WebMain` without hops |
| `@discardableResult` + typed throws on builders | DSL ergonomics | suppress unused-warning churn |

---

## Priority roadmap

1. **Quick wins (S):** typed throws on devserver (#6), `@inlinable` on hot path (#14), ClassList interpolation (#11), `@Bindable` (#3).
2. **Foundational (M):** `@HTMLElement` macro + codegen (#1, #13), `@WebMain` global actor (#9), buildPartialBlock TupleTag (#4 + #5), `~Copyable` JS observers (#7).
3. **Strategic (L):** Embedded Swift mode (#12), `Span<T>` reconciler (#8), `#html` literal macro (#2), full existential reduction (#10).

Adopting 1-2 first establishes the macro infrastructure; everything else builds on it. Embedded Swift mode is the biggest single binary-size lever (~10x) and is the differentiator vs Tokamak/Vite-React.
