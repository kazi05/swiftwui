# Responsive Styling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete SwiftWUI's responsive layer as one `MediaQuery` vocabulary across five surfaces — extended media queries, a shared `Breakpoint` scale, `Responsive<Value>` style values, `@container` queries, and a reactive `media.matches(query)` check usable inside `body`.

**Architecture:** Additive. The shipping CSS `@media` path (`.media()`, `Rule(media:)`, `StyleProxy.media`) is untouched — new work adds sibling APIs that reuse the same `StyleRegistry` emission. Container queries get an additive `container` field on the registry entry (the `@media` path stays byte-identical). The reactive `matches()` surface follows the existing `EnvironmentSignals` recipe: an `@Observable` per-Runtime store fed by a new `RendererBackend.observeMediaQuery` seam.

**Tech Stack:** Swift 6.3.3, Swift Testing (`import Testing`, `@Suite`/`@Test`/`#expect`), JavaScriptKit (WASM DOM), MockBackend/TestScheduler native test harness.

## Global Constraints

- Swift **6.3.3** host + `swift-6.3.3-RELEASE_wasm` SDK; versions must match exactly.
- Native `swift test` is the primary gate. WASM gate: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM` (use `--target`, not `--product`).
- Never pass `-disable-reflection-metadata` (breaks Mirror → resets @State).
- Everything `@MainActor`; no new dependencies.
- All CSS values flow through `CSSSanitize`; all HTML through `HTMLEscaping`. Do not add new sinks.
- `matches()` is for STRUCTURAL branching only; CSS surfaces (`.media`/`.container`/`responsive`) are the FOUC-free default. SSR default of `matches()` is `false`.
- Mark deliberate ceilings with `// ponytail:` comments (no registry sweep; whole-store invalidation).
- Reference spec: `docs/superpowers/specs/2026-07-14-responsive-styling-design.md`.

---

### Task 1: Extend `MediaQuery` (combinators, orientation, height)

**Files:**
- Modify: `Sources/SwiftWUI/Styles/MediaQuery.swift`
- Test: `Tests/SwiftWUITests/MediaQueryConditionTests.swift` (create)

**Interfaces:**
- Consumes: existing `MediaQuery { let condition: String }`, `CSSLength` (`.px`, `.rem`, `.css`).
- Produces: `Orientation` enum; `MediaQuery.minHeight/maxHeight/orientation/and/or/not`. `and`/`or`/`not` wrap operands in parens so nesting stays valid CSS.

- [ ] **Step 1: Write the failing test**

Create `Tests/SwiftWUITests/MediaQueryConditionTests.swift`:

```swift
import Testing
@testable import SwiftWUI

@Suite struct MediaQueryConditionTests {
    @Test func heightAndOrientation() {
        #expect(MediaQuery.minHeight(.px(500)).condition == "(min-height: 500px)")
        #expect(MediaQuery.maxHeight(.px(500)).condition == "(max-height: 500px)")
        #expect(MediaQuery.orientation(.portrait).condition == "(orientation: portrait)")
        #expect(MediaQuery.orientation(.landscape).condition == "(orientation: landscape)")
    }
    @Test func combinatorsParenthesizeOperands() {
        #expect(MediaQuery.and(.minWidth(.px(768)), .maxWidth(.px(1023))).condition
                == "((min-width: 768px) and (max-width: 1023px))")
        #expect(MediaQuery.or(.minWidth(.px(400)), .orientation(.portrait)).condition
                == "((min-width: 400px) or (orientation: portrait))")
        #expect(MediaQuery.not(.minWidth(.px(768))).condition == "(not (min-width: 768px))")
    }
    @Test func combinatorsNestValidly() {
        // The v1 bug: nested and/or emitted unparenthesized, invalid CSS.
        let q = MediaQuery.and(.or(.minWidth(.px(400)), .orientation(.portrait)), .maxWidth(.px(900)))
        #expect(q.condition == "(((min-width: 400px) or (orientation: portrait)) and (max-width: 900px))")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MediaQueryConditionTests`
Expected: FAIL — `minHeight`/`orientation`/`and` not members of `MediaQuery`.

- [ ] **Step 3: Write minimal implementation**

Append to `Sources/SwiftWUI/Styles/MediaQuery.swift`:

```swift
public enum Orientation: String { case portrait, landscape }

extension MediaQuery {
    public static func minHeight(_ l: CSSLength) -> MediaQuery { .init(condition: "(min-height: \(l.css))") }
    public static func maxHeight(_ l: CSSLength) -> MediaQuery { .init(condition: "(max-height: \(l.css))") }
    public static func orientation(_ o: Orientation) -> MediaQuery { .init(condition: "(orientation: \(o.rawValue))") }

    // Each COMPOUND operand is wrapped in parens so nesting stays valid CSS
    // (fixes v1's unparenthesized combinator bug). Simple features are already
    // individually parenthesized.
    public static func and(_ a: MediaQuery, _ b: MediaQuery) -> MediaQuery {
        .init(condition: "(\(a.condition) and \(b.condition))")
    }
    public static func or(_ a: MediaQuery, _ b: MediaQuery) -> MediaQuery {
        .init(condition: "(\(a.condition) or \(b.condition))")
    }
    public static func not(_ q: MediaQuery) -> MediaQuery {
        .init(condition: "(not \(q.condition))")
    }
}
```

Note: `MediaQuery.init(condition:)` is the struct's memberwise init; it is already used by the existing statics in this file, so it is reachable here.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MediaQueryConditionTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Styles/MediaQuery.swift Tests/SwiftWUITests/MediaQueryConditionTests.swift
git commit -m "feat(styles): MediaQuery combinators, orientation, height conditions"
```

---

### Task 2: `Breakpoint` scale + `.up`/`.down`

**Files:**
- Create: `Sources/SwiftWUI/Styles/Breakpoint.swift`
- Test: `Tests/SwiftWUITests/MediaQueryConditionTests.swift` (append a suite)

**Interfaces:**
- Consumes: `MediaQuery.minWidth/maxWidth`, `CSSLength.px`.
- Produces: `Breakpoint` (`.sm/.md/.lg/.xl`, `Comparable`, `minWidthPx: Double`); `MediaQuery.up(_:)` (min-width), `MediaQuery.down(_:)` (max-width, -0.02px). Consumed by Task 5.

- [ ] **Step 1: Write the failing test**

Append to `Tests/SwiftWUITests/MediaQueryConditionTests.swift`:

```swift
@Suite struct BreakpointTests {
    @Test func scaleAndComparable() {
        #expect(Breakpoint.sm.minWidthPx == 640)
        #expect(Breakpoint.md.minWidthPx == 768)
        #expect(Breakpoint.lg.minWidthPx == 1024)
        #expect(Breakpoint.xl.minWidthPx == 1280)
        #expect(Breakpoint.sm < Breakpoint.md)
        #expect(Breakpoint.allCases.count == 4)
    }
    @Test func upIsMinWidth() {
        #expect(MediaQuery.up(.md).condition == "(min-width: 768px)")
    }
    @Test func downIsMaxWidthBelowBreakpoint() {
        // -0.02px avoids exact-boundary overlap with .up; formatting of the
        // fractional part is not asserted exactly.
        #expect(MediaQuery.down(.md).condition.hasPrefix("(max-width: 767"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter BreakpointTests`
Expected: FAIL — no type `Breakpoint`.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/SwiftWUI/Styles/Breakpoint.swift`:

```swift
/// Named responsive breakpoint scale (mobile-first). Static default; a
/// theme-injected scale can replace `minWidthPx` later without touching call
/// sites. // ponytail: static default scale.
public enum Breakpoint: Int, Comparable, CaseIterable {
    case sm, md, lg, xl
    public var minWidthPx: Double {
        switch self {
        case .sm: return 640
        case .md: return 768
        case .lg: return 1024
        case .xl: return 1280
        }
    }
    public static func < (a: Breakpoint, b: Breakpoint) -> Bool { a.rawValue < b.rawValue }
}

extension MediaQuery {
    /// Matches at/above the breakpoint. `@media (min-width: …)`.
    public static func up(_ bp: Breakpoint) -> MediaQuery { .minWidth(.px(bp.minWidthPx)) }
    /// Matches below the breakpoint. -0.02px avoids the exact-boundary overlap with `up`.
    public static func down(_ bp: Breakpoint) -> MediaQuery { .maxWidth(.px(bp.minWidthPx - 0.02)) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter BreakpointTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Styles/Breakpoint.swift Tests/SwiftWUITests/MediaQueryConditionTests.swift
git commit -m "feat(styles): Breakpoint scale + MediaQuery.up/.down"
```

---

### Task 3: `StyleRegistry` container support (additive)

**Files:**
- Modify: `Sources/SwiftWUI/HTML/AttributeBag.swift:3-7` (`PendingStyleRule`)
- Modify: `Sources/SwiftWUI/Styles/StyleRegistry.swift`
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift:159`
- Test: `Tests/SwiftWUITests/ContainerQueryTests.swift` (create — registry-level part)

**Interfaces:**
- Consumes: existing `StyleRegistry` entry/insert/register machinery.
- Produces: `PendingStyleRule.container: String?` (default nil); `StyleRegistry.registerAnonymous(pseudo:media:container:declarations:)` and `registerSelector(base:scope:pseudo:media:container:declarations:)` (both gain a `container` param); `@container <container> { … }` emission. The `@media` path is byte-identical to before. Consumed by Task 4.

Rationale: implements spec Section G's goal (generalized at-rule wrapper) additively — an extra `container` field rather than renaming `media`→`atRule` — so the shipping `@media` emission and its tests are untouched by construction.

- [ ] **Step 1: Write the failing test**

Create `Tests/SwiftWUITests/ContainerQueryTests.swift`:

```swift
import Testing
@testable import SwiftWUI

@Suite struct ContainerRegistryTests {
    @Test func containerAtRuleWraps() {
        let reg = StyleRegistry()
        _ = reg.registerAnonymous(pseudo: nil, media: nil,
                                  container: "sidebar (min-width: 400px)",
                                  declarations: [StyleDeclaration(property: "flex-direction", value: "row")])
        #expect(reg.text.hasPrefix("@container sidebar (min-width: 400px) { .swui-"))
        #expect(reg.text.contains("flex-direction: row"))
    }
    @Test func mediaPathUnchanged() {
        let reg = StyleRegistry()
        _ = reg.registerAnonymous(pseudo: nil, media: "(max-width: 600px)", container: nil,
                                  declarations: [StyleDeclaration(property: "display", value: "none")])
        #expect(reg.text.hasPrefix("@media (max-width: 600px) { .swui-"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ContainerRegistryTests`
Expected: FAIL — `registerAnonymous` has no `container:` parameter.

- [ ] **Step 3: Write minimal implementation**

3a. In `Sources/SwiftWUI/HTML/AttributeBag.swift`, add the field to `PendingStyleRule` (default keeps existing constructions compiling):

```swift
public struct PendingStyleRule {
    let pseudo: String?
    let media: String?
    var container: String? = nil
    let declarations: [StyleDeclaration]
}
```

3b. In `Sources/SwiftWUI/Styles/StyleRegistry.swift`, add `container` to `Entry`, thread it through `insert`, both `register*` methods, and the wrapper:

```swift
struct Entry {
    let media: String        // "" for no @media condition
    let container: String     // "" for no @container condition
    let text: String
    let hash: UInt64
}

private func insert(media: String, container: String, text: String, seed: String) -> UInt64 {
    let hash = Self.fnv1a(seed)
    if byHash[hash] == nil {
        byHash[hash] = Entry(media: media, container: container, text: text, hash: hash)
        version += 1
    }
    return hash
}

func registerAnonymous(pseudo: String?, media: String?, container: String? = nil,
                       declarations: [StyleDeclaration]) -> String {
    let body = Self.body(declarations)
    let seed = "anon|\(pseudo ?? "")|\(media ?? "")|\(container ?? "")|\(body)"
    let hash = Self.fnv1a(seed)
    let cls = Self.className(hash)
    guard !declarations.isEmpty else { return cls }
    let selector = "." + cls + (pseudo ?? "")
    _ = insert(media: media ?? "", container: container ?? "", text: "\(selector) { \(body) }", seed: seed)
    return cls
}

func registerSelector(base: String, scope: String?, pseudo: String?, media: String?,
                      container: String? = nil, declarations: [StyleDeclaration]) {
    let body = Self.body(declarations)
    let selector = base + (scope.map { "." + $0 } ?? "") + (pseudo ?? "")
    let seed = "sel|\(selector)|\(media ?? "")|\(container ?? "")|\(body)"
    _ = insert(media: media ?? "", container: container ?? "", text: "\(selector) { \(body) }", seed: seed)
}

func registerRaw(_ text: String) {
    _ = insert(media: "", container: "", text: text, seed: "raw|" + text)
}

public var text: String {
    let sorted = byHash.values.sorted {
        ($0.media, $0.container, $0.hash) < ($1.media, $1.container, $1.hash)
    }
    return sorted.map { e in
        if !e.container.isEmpty { return "@container \(e.container) { \(e.text) }" }
        if !e.media.isEmpty { return "@media \(e.media) { \(e.text) }" }
        return e.text
    }.joined(separator: "\n")
}
```

3c. In `Sources/SwiftWUI/Runtime/Resolver.swift:159`, pass the container through:

```swift
let cls = ctx.registry.registerAnonymous(pseudo: rule.pseudo, media: rule.media,
                                         container: rule.container,
                                         declarations: rule.declarations)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ContainerRegistryTests`
Expected: PASS (2 tests).

Run the full suite to confirm the `@media`/pseudo path did not regress:
Run: `swift test`
Expected: PASS (all pre-existing suites green — `PseudoMediaTests`, `StyledScopingTests`, `StyleRegistryTests`, `StyleBundleTests`, `TodoAcceptanceTests`).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/HTML/AttributeBag.swift Sources/SwiftWUI/Styles/StyleRegistry.swift Sources/SwiftWUI/Runtime/Resolver.swift Tests/SwiftWUITests/ContainerQueryTests.swift
git commit -m "feat(styles): additive @container support in StyleRegistry + PendingStyleRule"
```

---

### Task 4: Container query modifiers (`.container`, `.containerType`, `Rule`)

**Files:**
- Modify: `Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift` (Tag + _StyledTag)
- Modify: `Sources/SwiftWUI/Styles/Rule.swift`
- Test: `Tests/SwiftWUITests/ContainerQueryTests.swift` (append)

**Interfaces:**
- Consumes: Task 3's `PendingStyleRule.container`, `registerSelector(container:)`; existing `_StyledTag`, `_styled`, `StyleDeclaration`, `CSSSanitize.isValidIdent`.
- Produces: `ContainerType` enum; `.containerType(_:name:)` and `.container(_:name:_:)` on `Tag`/`_StyledTag`; `Rule(class:/id:/element:, container:, containerName:, _:)`.

- [ ] **Step 1: Write the failing test**

Append to `Tests/SwiftWUITests/ContainerQueryTests.swift`:

```swift
@Suite struct ContainerModifierTests {
    @Test func containerModifierEmitsAtContainer() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.container(.minWidth(.px(400)), name: "sidebar") { $0.flexDirection(.row) }
        )
        #expect(css.hasPrefix("@container sidebar (min-width: 400px) { .swui-"))
        #expect(css.contains("flex-direction: row"))
    }
    @Test func unnamedContainer() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.container(.minWidth(.px(400))) { $0.display(.flex) }
        )
        #expect(css.hasPrefix("@container (min-width: 400px) { .swui-"))
    }
    @Test func containerTypeSetsDeclarations() {
        let (html, _) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.containerType(.inlineSize, name: "sidebar")
        )
        #expect(html.contains("container-type: inline-size"))
        #expect(html.contains("container-name: sidebar"))
    }
    @Test func ruleContainer() {
        struct Card: Tag, Styled {
            @RulesBuilder var styles: [Rule] {
                Rule(class: "card", container: .minWidth(.px(400)), containerName: "sidebar") {
                    $0.flexDirection(.row)
                }
            }
            var body: some Tag { Div(class: "card") { Text("x") } }
        }
        let (_, css) = HTMLRenderer.renderWithStylesheet(Card())
        #expect(css.contains("@container sidebar (min-width: 400px) { .card"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ContainerModifierTests`
Expected: FAIL — `container`/`containerType` not members; `Rule` has no `container:`.

- [ ] **Step 3: Write minimal implementation**

3a. Add the `ContainerType` enum near the top of `Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift` (module scope):

```swift
public enum ContainerType: String { case inlineSize = "inline-size", size, normal }
```

3b. Add a private helper + the two public modifiers inside the `extension Tag { … }` block:

```swift
func _styledContainer(_ query: MediaQuery, name: String?,
                      _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
    var proxy = StyleProxy(); body(&proxy)
    let container = (name.map { "\($0) " } ?? "") + query.condition
    return _StyledTag(content: self, declarations: [],
                      rules: [PendingStyleRule(pseudo: nil, media: nil, container: container,
                                               declarations: proxy.declarations)])
}
public func container(_ query: MediaQuery, name: String? = nil,
                      _ body: (inout StyleProxy) -> Void) -> _StyledTag<Self> {
    _styledContainer(query, name: name, body)
}
public func containerType(_ type: ContainerType = .inlineSize, name: String? = nil) -> _StyledTag<Self> {
    var t = _styled(StyleDeclaration(property: "container-type", value: type.rawValue))
    if let name, CSSSanitize.isValidIdent(name) {
        t = t._styled(StyleDeclaration(property: "container-name", value: name))
    } else if name != nil {
        assertionFailure("invalid container-name ident")
    }
    return t
}
```

3c. Mirror on `_StyledTag` (inside `extension _StyledTag { … }`), appending to self:

```swift
func _styledContainer(_ query: MediaQuery, name: String?,
                      _ body: (inout StyleProxy) -> Void) -> Self {
    var proxy = StyleProxy(); body(&proxy)
    let container = (name.map { "\($0) " } ?? "") + query.condition
    var copy = self
    copy.rules.append(PendingStyleRule(pseudo: nil, media: nil, container: container,
                                       declarations: proxy.declarations))
    return copy
}
public func container(_ query: MediaQuery, name: String? = nil,
                      _ body: (inout StyleProxy) -> Void) -> Self {
    _styledContainer(query, name: name, body)
}
public func containerType(_ type: ContainerType = .inlineSize, name: String? = nil) -> Self {
    var t = _styled(StyleDeclaration(property: "container-type", value: type.rawValue))
    if let name, CSSSanitize.isValidIdent(name) {
        t = t._styled(StyleDeclaration(property: "container-name", value: name))
    } else if name != nil {
        assertionFailure("invalid container-name ident")
    }
    return t
}
```

3d. In `Sources/SwiftWUI/Styles/Rule.swift`, add container params + store the built prelude. Add a stored `let container: String?`, extend all three inits with `container: MediaQuery? = nil, containerName: String? = nil`, and emit it in `register`:

```swift
struct Rule {
    // …existing…
    let container: String?     // built prelude "name cond" / "cond", or nil

    // helper reused by all three inits:
    private static func buildContainer(_ q: MediaQuery?, _ name: String?) -> String? {
        guard let q else { return nil }
        let n = name.flatMap { CSSSanitize.isValidIdent($0) ? "\($0) " : nil } ?? ""
        return n + q.condition
    }

    public init(class name: String, media: MediaQuery? = nil,
                container: MediaQuery? = nil, containerName: String? = nil,
                _ build: (inout StyleProxy) -> Void) {
        var p = StyleProxy(); build(&p)
        self.base = .cls(Self.validated(name, kind: "class")); self.media = media
        self.container = Self.buildContainer(container, containerName); self.proxy = p
    }
    // …same two extra params for init(id:) and init(element:)…

    @MainActor func register(into registry: StyleRegistry, scope: String?) {
        if !proxy.declarations.isEmpty {
            registry.registerSelector(base: base.css, scope: scope, pseudo: nil,
                                      media: media?.condition, container: container,
                                      declarations: proxy.declarations)
        }
        for block in proxy.pseudoBlocks {
            registry.registerSelector(base: base.css, scope: scope, pseudo: block.pseudo,
                                      media: media?.condition, container: container,
                                      declarations: block.declarations)
        }
    }
}
```

Apply the same two new params (`container:`, `containerName:`) and the `self.container = Self.buildContainer(...)` assignment to `init(id:)` and `init(element:)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ContainerModifierTests`
Expected: PASS (4 tests).
Run: `swift test`
Expected: PASS (no regressions).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift Sources/SwiftWUI/Styles/Rule.swift Tests/SwiftWUITests/ContainerQueryTests.swift
git commit -m "feat(styles): .container()/.containerType() modifiers + Rule(container:)"
```

---

### Task 5: `Responsive<Value>` style values

**Files:**
- Create: `Sources/SwiftWUI/Styles/Responsive.swift`
- Modify: `Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift` (overloads + helper)
- Test: `Tests/SwiftWUITests/ResponsiveValueTests.swift` (create)

**Interfaces:**
- Consumes: `Breakpoint` + `MediaQuery.up`/`.and`/`.maxWidth` (Task 1–2), `StyleProxy`, `PendingStyleRule`, `_StyledTag`.
- Produces: `Responsive<Value>`; `responsive(_:sm:md:lg:xl:)`; `Tag._responsive` / `_StyledTag._responsive`; responsive overloads for `padding/margin/width/height/minWidth/maxWidth/fontSize/display/flexDirection/gap/textAlign/gridTemplateColumns`.

Design note: overrides emit **non-overlapping** `[bp_i, bp_{i+1})` media conditions (last one is open-ended `min-width`). `StyleRegistry` sorts rules by media string, not numeric width, so non-overlapping ranges make the result independent of stylesheet source order.

- [ ] **Step 1: Write the failing test**

Create `Tests/SwiftWUITests/ResponsiveValueTests.swift`:

```swift
import Testing
@testable import SwiftWUI

@Suite struct ResponsiveValueTests {
    @Test func baseOnlyEmitsNoMedia() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.padding(responsive(.px(16)))
        )
        #expect(css.contains("padding: 16px"))
        #expect(!css.contains("@media"))
    }
    @Test func overridesEmitNonOverlappingRanges() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.padding(responsive(.px(16), md: .px(32), lg: .px(48)))
        )
        // base
        #expect(css.contains("padding: 16px"))
        // md: [768, 1024) — bounded above so it can't beat lg by source order
        #expect(css.contains("(min-width: 768px) and (max-width: 1023"))
        #expect(css.contains("padding: 32px"))
        // lg: open-ended min-width
        #expect(css.contains("@media (min-width: 1024px) {"))
        #expect(css.contains("padding: 48px"))
    }
    @Test func displayResponsive() {
        let (_, css) = HTMLRenderer.renderWithStylesheet(
            Div { Text("x") }.display(responsive(.block, md: .flex))
        )
        #expect(css.contains("display: block"))
        #expect(css.contains("display: flex"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ResponsiveValueTests`
Expected: FAIL — `responsive` unresolved; `padding(Responsive<…>)` overload missing.

- [ ] **Step 3: Write minimal implementation**

3a. Create `Sources/SwiftWUI/Styles/Responsive.swift`:

```swift
/// A per-breakpoint style value: an unconditional `base` plus mobile-first
/// overrides. Overrides emit non-overlapping [bp, nextBp) media ranges so the
/// cascade does not depend on stylesheet source order.
public struct Responsive<Value> {
    public var base: Value
    public var overrides: [(Breakpoint, Value)]   // ascending by breakpoint
    public init(base: Value, overrides: [(Breakpoint, Value)]) {
        self.base = base
        self.overrides = overrides.sorted { $0.0 < $1.0 }
    }
}

public func responsive<V>(_ base: V, sm: V? = nil, md: V? = nil,
                          lg: V? = nil, xl: V? = nil) -> Responsive<V> {
    var o: [(Breakpoint, V)] = []
    if let sm { o.append((.sm, sm)) }
    if let md { o.append((.md, md)) }
    if let lg { o.append((.lg, lg)) }
    if let xl { o.append((.xl, xl)) }
    return Responsive(base: base, overrides: o)
}
```

3b. Add the desugar helper + overloads to `Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift`. In `extension Tag`:

```swift
func _responsive<V>(_ r: Responsive<V>,
                    _ apply: (inout StyleProxy, V) -> Void) -> _StyledTag<Self> {
    var base = StyleProxy(); apply(&base, r.base)
    var rules: [PendingStyleRule] = []
    for (i, pair) in r.overrides.enumerated() {
        var p = StyleProxy(); apply(&p, pair.1)
        guard !p.declarations.isEmpty else { continue }
        let cond: MediaQuery = (i + 1 < r.overrides.count)
            ? .and(.up(pair.0), .maxWidth(.px(r.overrides[i + 1].0.minWidthPx - 0.02)))
            : .up(pair.0)
        rules.append(PendingStyleRule(pseudo: nil, media: cond.condition, declarations: p.declarations))
    }
    return _StyledTag(content: self, declarations: base.declarations, rules: rules)
}
public func padding(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.padding($1) } }
public func margin(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.margin($1) } }
public func width(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.width($1) } }
public func height(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.height($1) } }
public func minWidth(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.minWidth($1) } }
public func maxWidth(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.maxWidth($1) } }
public func fontSize(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.fontSize($1) } }
public func gap(_ r: Responsive<CSSLength>) -> _StyledTag<Self> { _responsive(r) { $0.gap($1) } }
public func display(_ r: Responsive<Display>) -> _StyledTag<Self> { _responsive(r) { $0.display($1) } }
public func flexDirection(_ r: Responsive<FlexDirection>) -> _StyledTag<Self> { _responsive(r) { $0.flexDirection($1) } }
public func textAlign(_ r: Responsive<TextAlign>) -> _StyledTag<Self> { _responsive(r) { $0.textAlign($1) } }
public func gridTemplateColumns(_ r: Responsive<String>) -> _StyledTag<Self> { _responsive(r) { $0.gridTemplateColumns($1) } }
```

3c. Mirror the helper + overloads on `_StyledTag` (append to self):

```swift
func _responsive<V>(_ r: Responsive<V>,
                    _ apply: (inout StyleProxy, V) -> Void) -> Self {
    var copy = self
    var base = StyleProxy(); apply(&base, r.base)
    copy.declarations.append(contentsOf: base.declarations)
    for (i, pair) in r.overrides.enumerated() {
        var p = StyleProxy(); apply(&p, pair.1)
        guard !p.declarations.isEmpty else { continue }
        let cond: MediaQuery = (i + 1 < r.overrides.count)
            ? .and(.up(pair.0), .maxWidth(.px(r.overrides[i + 1].0.minWidthPx - 0.02)))
            : .up(pair.0)
        copy.rules.append(PendingStyleRule(pseudo: nil, media: cond.condition, declarations: p.declarations))
    }
    return copy
}
// same 12 overloads as 3b, each returning Self
public func padding(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.padding($1) } }
public func margin(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.margin($1) } }
public func width(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.width($1) } }
public func height(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.height($1) } }
public func minWidth(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.minWidth($1) } }
public func maxWidth(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.maxWidth($1) } }
public func fontSize(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.fontSize($1) } }
public func gap(_ r: Responsive<CSSLength>) -> Self { _responsive(r) { $0.gap($1) } }
public func display(_ r: Responsive<Display>) -> Self { _responsive(r) { $0.display($1) } }
public func flexDirection(_ r: Responsive<FlexDirection>) -> Self { _responsive(r) { $0.flexDirection($1) } }
public func textAlign(_ r: Responsive<TextAlign>) -> Self { _responsive(r) { $0.textAlign($1) } }
public func gridTemplateColumns(_ r: Responsive<String>) -> Self { _responsive(r) { $0.gridTemplateColumns($1) } }
```

`// ponytail: overload set bounded to layout/typography props that actually vary by width; extend per demand.`

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ResponsiveValueTests`
Expected: PASS (3 tests).
Run: `swift test`
Expected: PASS (no regressions).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Styles/Responsive.swift Sources/SwiftWUI/Styles/StyleModifiers+Tag.swift Tests/SwiftWUITests/ResponsiveValueTests.swift
git commit -m "feat(styles): Responsive<Value> per-breakpoint style values"
```

---

### Task 6: Backend seam `observeMediaQuery` + MockBackend

**Files:**
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift`
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift`
- Test: `Tests/SwiftWUITests/MediaMatchTests.swift` (create)

**Interfaces:**
- Produces: `RendererBackend.observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool` (default returns `false`); `MockBackend` records observers in `mediaObservers`, honors seeded `mediaMatches`, exposes `simulateMediaChange(_:matches:)`. Consumed by Tasks 7–9.

- [ ] **Step 1: Write the failing test**

Create `Tests/SwiftWUITests/MediaMatchTests.swift`:

```swift
import Testing
@testable import SwiftWUI

@Suite @MainActor struct MediaBackendSeamTests {
    @Test func mockRecordsAndFires() {
        let backend = MockBackend()
        backend.mediaMatches["(max-width: 600px)"] = true
        var last: Bool? = nil
        let initial = backend.observeMediaQuery("(max-width: 600px)") { last = $0 }
        #expect(initial == true)
        #expect(last == nil)                              // no change yet
        backend.simulateMediaChange("(max-width: 600px)", matches: false)
        #expect(last == false)
    }
    @Test func defaultSeamReturnsFalse() {
        // A backend that doesn't override the seam yields the SSR default.
        let base = MockBackend()
        let adopting = AdoptingBackend(base: base, container: base.container)
        #expect(adopting.observeMediaQuery("(min-width: 9999px)") { _ in } == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MediaBackendSeamTests`
Expected: FAIL — `observeMediaQuery`/`simulateMediaChange`/`mediaMatches` do not exist.

- [ ] **Step 3: Write minimal implementation**

3a. In `Sources/SwiftWUI/Render/RendererBackend.swift`, add to the protocol (near the environment-signals section) and a default impl:

```swift
// MARK: Reactive media matching (spec 2026-07-14)
/// Called lazily the first time a component reads `matches(condition)`. The
/// backend evaluates the condition now (synchronous initial value), retains a
/// change listener calling `onChange` on every future flip, and returns the
/// current match. Non-browser backends return `false` and never call onChange.
func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool
```

In `extension RendererBackend`:

```swift
public func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool { false }
```

3b. In `Sources/SwiftWUI/Render/MockBackend.swift`, add near the environment-observation members:

```swift
public private(set) var mediaObservers: [String: (Bool) -> Void] = [:]
public var mediaMatches: [String: Bool] = [:]         // pre-seedable by tests
public func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool {
    bump("observeMediaQuery")
    mediaObservers[condition] = onChange
    return mediaMatches[condition] ?? false
}
/// Test helper: simulate a media-condition flip (resize / orientation change).
public func simulateMediaChange(_ condition: String, matches: Bool) {
    mediaMatches[condition] = matches
    mediaObservers[condition]?(matches)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MediaBackendSeamTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Render/RendererBackend.swift Sources/SwiftWUI/Render/MockBackend.swift Tests/SwiftWUITests/MediaMatchTests.swift
git commit -m "feat(env): observeMediaQuery backend seam + MockBackend test knob"
```

---

### Task 7: `MediaMatchStore` + `@Environment(\.media)`

**Files:**
- Create: `Sources/SwiftWUI/Environment/MediaMatch.swift`
- Modify: `Sources/SwiftWUI/Environment/Environment.swift`
- Test: `Tests/SwiftWUITests/MediaMatchTests.swift` (append)

**Interfaces:**
- Consumes: Task 6 seam signature `(String, @escaping (Bool) -> Void) -> Bool`; `MediaQuery`; `EnvironmentValues`/`EnvironmentKey`.
- Produces: `MediaMatchStore` (`@MainActor @Observable`, `init(observe:)`, `func matches(_ condition: String) -> Bool`); `MediaProxy` (`matches(_ q: MediaQuery) -> Bool`); `EnvironmentValues.media: MediaProxy` and internal `_mediaStore`. Consumed by Task 8.

- [ ] **Step 1: Write the failing test**

Append to `Tests/SwiftWUITests/MediaMatchTests.swift`:

```swift
@Suite @MainActor struct MediaMatchStoreTests {
    @Test func dedupsRegistrationPerCondition() {
        var registered: [String] = []
        var sinks: [String: (Bool) -> Void] = [:]
        let store = MediaMatchStore(observe: { cond, cb in
            registered.append(cond); sinks[cond] = cb; return false
        })
        #expect(store.matches("(max-width: 600px)") == false)
        #expect(store.matches("(max-width: 600px)") == false)   // second read, no re-register
        #expect(registered == ["(max-width: 600px)"])
        // a listener flip surfaces on the next read
        sinks["(max-width: 600px)"]?(true)
        #expect(store.matches("(max-width: 600px)") == true)
    }
    @Test func proxyDefaultsFalseWithoutStore() {
        #expect(MediaProxy(store: nil).matches(.maxWidth(.px(600))) == false)
        #expect(EnvironmentValues().media.matches(.maxWidth(.px(600))) == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MediaMatchStoreTests`
Expected: FAIL — `MediaMatchStore`/`MediaProxy`/`EnvironmentValues.media` do not exist.

- [ ] **Step 3: Write minimal implementation**

3a. Create `Sources/SwiftWUI/Environment/MediaMatch.swift`:

```swift
import Observation

/// Reactive media-query matching, one per Runtime. Read `matches(_:)` inside a
/// component `body`; a condition flip re-renders exactly the readers.
@MainActor @Observable
public final class MediaMatchStore {
    // Baseline captured at registration. NON-observed: it is written during the
    // body eval that first reads a new query, and must not invalidate that read.
    @ObservationIgnored private var registered: [String: Bool] = [:]
    // Live overrides pushed by the backend change listener (fires OUTSIDE eval).
    // Observed → a write invalidates the components that read it.
    private var changes: [String: Bool] = [:]
    @ObservationIgnored private let observe: (String, @escaping (Bool) -> Void) -> Bool

    public init(observe: @escaping (String, @escaping (Bool) -> Void) -> Bool) {
        self.observe = observe
    }

    func matches(_ condition: String) -> Bool {
        let live = changes[condition]                 // TRACKED read → records dependency
        if let live { return live }
        if let base = registered[condition] { return base }
        let initial = observe(condition) { [weak self] v in self?.update(condition, v) }
        registered[condition] = initial               // non-observed write — safe during eval
        return initial
        // ponytail: no sweep — one matchMedia listener per distinct condition,
        // bounded like StyleRegistry.
    }
    private func update(_ condition: String, _ v: Bool) {
        guard changes[condition] != v else { return }
        changes[condition] = v                        // observed write → re-render readers
        // ponytail: whole-store invalidation (one observed dict); split per-key only if measured.
    }
}

/// Lightweight `@Environment(\.media)` value. `nil` store outside a live runtime
/// (native/SSG) → `matches` returns the SSR default `false`.
public struct MediaProxy {
    let store: MediaMatchStore?
    public func matches(_ q: MediaQuery) -> Bool { store?.matches(q.condition) ?? false }
}
```

3b. In `Sources/SwiftWUI/Environment/Environment.swift`, add the key + values (mirror the `_signals` shape from `EnvironmentSignals.swift`):

```swift
struct _MediaStoreKey: EnvironmentKey { static let defaultValue: MediaMatchStore? = nil }
extension EnvironmentValues {
    var _mediaStore: MediaMatchStore? {
        get { self[_MediaStoreKey.self] }
        set { self[_MediaStoreKey.self] = newValue }
    }
    /// Reactive media matching. `media.matches(q)` re-renders the reading
    /// component when `q` crosses. Use for STRUCTURAL branching; for styling
    /// prefer `.media()`/`.container()`/`responsive()` (no FOUC). `false` under SSR.
    public var media: MediaProxy { MediaProxy(store: _mediaStore) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MediaMatchStoreTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Environment/MediaMatch.swift Sources/SwiftWUI/Environment/Environment.swift Tests/SwiftWUITests/MediaMatchTests.swift
git commit -m "feat(env): MediaMatchStore + @Environment(\\.media) reactive matches()"
```

---

### Task 8: Runtime wiring + end-to-end reactive branch

**Files:**
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift`
- Test: `Tests/SwiftWUITests/MediaMatchTests.swift` (append)

**Interfaces:**
- Consumes: Task 6 backend seam via `applier.backend`; Task 7 `MediaMatchStore`, `_mediaStore`.
- Produces: a `MediaMatchStore` built once per Runtime and injected into the root `EnvironmentValues`; SPI `Runtime._mediaStore` for tests.

- [ ] **Step 1: Write the failing test**

Append to `Tests/SwiftWUITests/MediaMatchTests.swift`:

```swift
@MainActor private final class RC { var n = 0 }

private struct Responsive_Nav: Tag {
    let counter: RC
    @Environment(\.media) var media
    var body: some Tag {
        counter.n += 1
        return media.matches(.maxWidth(.px(600))) ? Div { Text("mobile") } : Div { Text("desktop") }
    }
}

@Suite @MainActor struct MediaMatchReactiveTests {
    private final class Sched {
        var q: [() -> Void] = []
        func schedule(_ f: @escaping () -> Void) { q.append(f) }
        func drain() { while !q.isEmpty { q.removeFirst()() } }
    }

    @Test func branchSwapsOnMediaFlipWithoutSpuriousRender() {
        let backend = MockBackend(); let sched = Sched()
        let counter = RC()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Responsive_Nav(counter: counter), scheduleMicrotask: sched.schedule)
        rt.mount(); sched.drain()
        // SSR/initial default is false → desktop branch, exactly one body eval.
        #expect(backend.serializeHTML().contains("desktop"))
        #expect(counter.n == 1)                              // no mutation-during-eval re-render

        backend.simulateMediaChange("(max-width: 600px)", matches: true)
        sched.drain()
        #expect(backend.serializeHTML().contains("mobile"))
        #expect(counter.n == 2)
        _ = rt   // keep alive — store closure captures [weak backend]
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MediaMatchReactiveTests`
Expected: FAIL — `.media` reads a nil store (no `_mediaStore` injected), so the branch never becomes reactive; the flip does not re-render.

- [ ] **Step 3: Write minimal implementation**

In `Sources/SwiftWUI/Runtime/Runtime.swift`:

3a. Add a lazily-built store property (place near the `signals` property, ~line 46):

```swift
private lazy var mediaStore = MediaMatchStore(observe: { [weak self] cond, cb in
    self?.applier.backend.observeMediaQuery(cond, onChange: cb) ?? false
})
public var _mediaStore: MediaMatchStore { mediaStore }   // SPI: tests
```

3b. Where `_signals` is injected into the root environment (grep `ctx.environment._signals =`, ~line 318), inject the store on the next line:

```swift
ctx.environment._signals = signals
ctx.environment._mediaStore = mediaStore
```

(If there is more than one site assigning `ctx.environment._signals`, add the `_mediaStore` line at each.)

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MediaMatchReactiveTests`
Expected: PASS (1 test).
Run: `swift test`
Expected: PASS (whole suite green).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUI/Runtime/Runtime.swift Tests/SwiftWUITests/MediaMatchTests.swift
git commit -m "feat(runtime): inject MediaMatchStore into root environment"
```

---

### Task 9: `DOMBackend.observeMediaQuery` (WASM) + full gate

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift`

**Interfaces:**
- Consumes: Task 6 protocol requirement `observeMediaQuery`.
- Produces: the live `matchMedia` implementation. No native unit test (DOM); verified by the WASM build gate + the native suite staying green.

- [ ] **Step 1: Implement `observeMediaQuery`**

In `Sources/SwiftWUIDOM/DOMBackend.swift`, add a retained-closure store (near the other retained `JSClosure`s) and the method (near `beginEnvironmentObservation`):

```swift
private var retainedMediaClosures: [JSClosure] = []
func observeMediaQuery(_ condition: String, onChange: @escaping (Bool) -> Void) -> Bool {
    guard let mql = JSObject.global.window.object?.matchMedia?(condition).object else { return false }
    let closure = JSClosure { _ in
        onChange(mql.matches.boolean ?? false)
        return .undefined
    }
    _ = mql.addEventListener?("change", closure)
    retainedMediaClosures.append(closure)   // must be retained while attached
    return mql.matches.boolean ?? false
}
```

Match the exact JSObject access idiom already used in this file for `matchMedia` in `beginEnvironmentObservation` (colorScheme) — mirror how `window`/`matchMedia`/`.matches`/`addEventListener` are addressed there; adjust the optional-chaining above to that idiom if it differs.

- [ ] **Step 2: Native build + full suite (regression gate)**

Run: `swift build`
Expected: builds clean.
Run: `swift test`
Expected: PASS — all suites, including every new one (`MediaQueryConditionTests`, `BreakpointTests`, `ContainerRegistryTests`, `ContainerModifierTests`, `ResponsiveValueTests`, `MediaBackendSeamTests`, `MediaMatchStoreTests`, `MediaMatchReactiveTests`).

- [ ] **Step 3: WASM build gate**

Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --target SwiftWUIDOM`
Expected: builds clean (DOMBackend conforms to `RendererBackend` with the new requirement; `JSClosure` retained).

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUIDOM/DOMBackend.swift
git commit -m "feat(dom): observeMediaQuery via window.matchMedia (WASM)"
```

---

## Self-Review

**Spec coverage:**
- §A MediaQuery extensions → Task 1. ✅
- §B Breakpoint + up/down → Task 2. ✅
- §C Responsive<Value> → Task 5 (non-overlapping ranges refine the naive min-width cascade for source-order safety). ✅
- §D Container queries → Tasks 3 (registry) + 4 (modifiers, Rule). ✅ (StyleProxy bundle `.container` for `Style` — cut; not requested, avoids touching bundle flush. See note below.)
- §E reactive matches() → Tasks 6 (seam) + 7 (store/env) + 8 (runtime) + 9 (DOM). ✅
- §F SSR/FOUC → `MediaProxy` returns `false` without a store (Task 7); reactive test asserts the default branch first (Task 8). ✅
- §G StyleRegistry generalization → Task 3, implemented additively (documented deviation). ✅

**Scope deviation (documented):** the spec's `StyleProxy.container` for `Style` bundles is dropped — it is symmetric sugar not in the user's three-surface ask and would require editing the bundle flush in `Style.swift`. The primary surfaces (`.container()` modifier, `Rule(container:)`) are delivered. Follow-up if bundle parity is wanted.

**Placeholder scan:** no TBD/TODO; every code step shows full code; every test step shows a runnable command + expected result.

**Type consistency:** `observeMediaQuery(_:onChange:) -> Bool` identical across protocol default (T6), MockBackend (T6), MediaMatchStore.observe closure (T7), Runtime injection (T8), DOMBackend (T9). `MediaMatchStore.matches(_ condition: String)` (internal) vs `MediaProxy.matches(_ q: MediaQuery)` (public) — distinct, intentional. `PendingStyleRule.container` added T3, written by T4 modifiers; `registerAnonymous`/`registerSelector` `container:` param consistent T3↔T4↔Resolver. `Responsive` overloads route through `_responsive` on both `Tag` and `_StyledTag` with matching signatures.

## Execution Handoff

Choose an execution approach when ready (subagent-driven recommended: fresh subagent per task + review between tasks).
