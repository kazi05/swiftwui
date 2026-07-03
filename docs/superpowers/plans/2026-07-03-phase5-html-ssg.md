# Phase 5: Full HTML, SSG & Hydration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete HTML tag set (~110 elements), static site generation riding the real `Runtime`, build-time data loading with a state snapshot, and full DOM hydration via an adopting walk — plus the phase-4 carry list as Task 1.

**Architecture:** SSG runs a native `Runtime<MockBackend>` per page (guards/redirects/effects identical to the browser), then serializes `runtime._currentTree` through the existing pure `HTMLRenderer` fold into a full document (spec §5, §9). Build-time loaders are `.task` effects with a `.build` policy, awaited by the driver in a capped loop (D5); their results ship in a JSON snapshot keyed by canonical `NodeIdentity` strings (D7). The wasm client seeds `StateStore` from the snapshot, re-resolves, and an `AdoptingBackend` claims the prerendered DOM pre-order instead of creating nodes (D2); any mismatch discards and cold-mounts (D6). The generator lives in a new native-only `SwiftWUIStatic` module (D11).

**Tech Stack:** Swift 6.3.3, swift-testing (`@Test`/`#expect`), MockBackend native gate, wasm SDK `swift-6.3.3-RELEASE_wasm`, FoundationEssentials JSON (only in `SwiftWUIStatic` and `SwiftWUIDOM`).

**Spec:** `docs/superpowers/specs/2026-07-03-phase5-html-ssg-design.md` — read it before starting any task.

## Global Constraints

- Branch: `feature/fable-new-vision`.
- **Module layout (D11):** new SwiftPM target `SwiftWUIStatic` (native-only via platform condition) is ALLOWED this phase. `Sources/SwiftWUI` stays Foundation-free — snapshot JSON goes through injected encode/decode hooks; `SwiftWUIStatic` and `SwiftWUIDOM` may `import Foundation` / `FoundationEssentials`.
- No new package dependencies.
- Everything `@MainActor` via target default isolation. NEVER add `Sendable`/`@unchecked Sendable` (the one existing `_InvalidateBox` exception stands).
- Identity: primitives append segments in `_resolve` only; bag-mutating methods never affect identity.
- Error posture: SSG fails loud at build time (`throw`); hydration NEVER fails at runtime — mismatch → silent cold rebuild (debug `assertionFailure` first). Spec §5, D6.
- Testing workflow (user preference, overrides RED/GREEN stepping): write ALL of a task's code first, run `swift test` ONCE at the end, fix, commit. Every commit message ends with:

  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  ```
- Native gate: `swift test` from repo root. 216 tests pass at plan start; every task leaves the suite green. Per-task counts are estimates — the invariant is ZERO failures.
- Wasm gates (Task 13/14): `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`, same from `Examples/TodoMVC`. Between Task 8 and Task 13 the wasm target does NOT compile (DOMBackend lacks the new read-API methods) — expected, same as phases 3–4.
- Test helpers: `Tests/SwiftWUITests/TestHelpers.swift` holds `typealias Tag = SwiftWUI.Tag`; `TestScheduler`, `findAll`, `findFirst`, `clickFirst` live in `RuntimeE2ETests.swift` (module-internal). Do NOT redeclare any of them.
- T8 invariant is the hydration foundation: `HTMLRenderer` output parsed as HTML must equal the DOM the backend builds. Every new tag and every serializer change must preserve it (`CrossCheckTests` guards it).

## File Structure

New:

| File | Target | Responsibility |
|---|---|---|
| `Sources/SwiftWUI/HTML/Tags+Text.swift` | SwiftWUI | Task 2: text-level & semantic containers |
| `Sources/SwiftWUI/HTML/Tags+Table.swift` | SwiftWUI | Task 3: table family + form controls |
| `Sources/SwiftWUI/HTML/Tags+Media.swift` | SwiftWUI | Task 4: media/embedded/interactive |
| `Sources/SwiftWUI/Identity/IdentityCanonical.swift` | SwiftWUI | Task 5: `_TypeNameRegistry`, canonical string |
| `Sources/SwiftWUI/State/StateSnapshot.swift` | SwiftWUI | Task 7: pending rows + encode/decode hooks |
| `Sources/SwiftWUI/Render/AdoptingBackend.swift` | SwiftWUI | Task 8: adopting walk wrapper |
| `Sources/SwiftWUIStatic/DocumentSerializer.swift` | SwiftWUIStatic (new) | Task 10: full-document assembly |
| `Sources/SwiftWUIStatic/SnapshotJSON.swift` | SwiftWUIStatic | Task 10: snapshot JSON assembly/encoding |
| `Sources/SwiftWUIStatic/StaticSite.swift` | SwiftWUIStatic | Task 11: generate driver |
| `Sources/SwiftWUIDOM/SnapshotBoot.swift` | SwiftWUIDOM | Task 13: script-tag read, JSONDecoder hook |

Modified: `Package.swift` (new target, Task 10), `Routing/RoutePattern.swift` + `Routing/Link.swift` + `Runtime/Runtime.swift` (Task 1 carry + Task 9 SPI), `HTML/EventPayloads.swift` (Task 1), `Routing/Router.swift` + `Runtime/Resolver.swift` (Task 5 registry, Task 9 collect), `Effects/EffectModifiers.swift` + `Effects/EffectStore.swift` (Task 6), `State/State.swift` + `State/StateStore.swift` (Task 7), `Render/RendererBackend.swift` + `Render/MockBackend.swift` + `Render/HTMLRenderer.swift` (Tasks 4, 8), `SwiftWUIDOM/DOMBackend.swift` + `DOMRuntime.swift` (Task 13), `Examples/TodoMVC/*` (Task 14), tests throughout.

---

### Task 1: Phase-4 carry list

**Files:**
- Modify: `Sources/SwiftWUI/Routing/RoutePattern.swift` (normalizePath, catchAll degrade, isExternal move)
- Modify: `Sources/SwiftWUI/Routing/Link.swift` (anchor/relative semantics)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (navigate scheme assert)
- Modify: `Sources/SwiftWUI/HTML/EventPayloads.swift` (ClickEvent fields)
- Modify: `Sources/SwiftWUI/Routing/Page.swift` (title doc comment)
- Modify: `Sources/SwiftWUI/Routing/Router.swift` (release two-Router comment)
- Test: `Tests/SwiftWUITests/RoutePatternTests.swift`, `Tests/SwiftWUITests/LinkTests.swift`, `Tests/SwiftWUITests/EventPayloadTests.swift` (append to each)

**Interfaces:**
- Produces: `RouteURL.isExternal(_ url: String) -> Bool` (moved from `Link`, now the single source; Link delegates). `ClickEvent` gains `public let targetValue: String?` and `public let checked: Bool?` (init defaults `nil` — source-compatible).

- [ ] **Step 1: `normalizePath` O(n)** — in `RoutePattern.swift` replace the trailing-slash loop (`String.count` inside the loop is O(n) → O(n²) total):

```swift
static func normalizePath(_ path: String) -> String {
    var p = path.hasPrefix("/") ? path : "/" + path
    var n = p.count                                   // computed once — O(n) total
    while n > 1 && p.hasSuffix("/") { p.removeLast(); n -= 1 }
    return p
}
```

- [ ] **Step 2: catchAll release degrade** — in `RoutePattern.init`, after the segment loop, drop anything after a mid-pattern `*` (debug still asserts; release gets a defined prefix-match degrade instead of silent mis-matching):

```swift
if let i = segs.firstIndex(of: .catchAll), i < segs.count - 1 {
    segs = Array(segs[...i])          // release degrade: '*' swallows the tail (documented)
}
self.segments = segs
```

(Keep the existing `assert(i == parts.count - 1, …)` in the loop — debug behavior unchanged.)

- [ ] **Step 3: move `isExternal` to `RouteURL`** — add to `RouteURL` (same body as `Link.isExternal` today):

```swift
/// "https://…", "mailto:…", "//host/…" — anything that leaves the app.
static func isExternal(_ url: String) -> Bool {
    if url.hasPrefix("//") { return true }
    for ch in url {
        if ch == ":" { return true }
        if ch == "/" || ch == "?" || ch == "#" { return false }
    }
    return false
}
```

In `Link`, replace the static method with a forwarder: `static func isExternal(_ url: String) -> Bool { RouteURL.isExternal(url) }` (LinkTests reference it).

- [ ] **Step 4: Link anchor + relative semantics** — in `Link.body`, fragment destinations pass through to the browser (same-page scroll), and non-root-relative internal destinations assert in debug (spec §12):

```swift
public var body: some Tag {
    let dest = destination
    let nav = navigate
    if Self.isExternal(dest) || target != nil || dest.hasPrefix("#") {
        A(href: dest, target: target) { content }          // browser handles: external, targeted, or #anchor
    } else {
        assert(dest.hasPrefix("/"),
               "Link destination must be root-relative ('/docs/intro'), got '\(dest)' — relative paths resolve against the SSG file location, not the route")
        A(href: dest) { content }
            .attribute("data-swui-link", "")
            .onClickEvent { e in
                guard e?.isModified != true else { return }
                nav(dest)
            }
    }
}
```

- [ ] **Step 5: `navigate()` scheme assert** — in `Runtime.navigate(to:replace:)`, first line:

```swift
assert(!RouteURL.isExternal(url),
       "navigate() expects an app-internal path, got '\(url)' — use a plain A/Link for external URLs")
```

- [ ] **Step 6: ClickEvent field mapping** — extend `ClickEvent` (existing members unchanged):

```swift
public struct ClickEvent {
    public let button: Int
    public let metaKey: Bool
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    /// target.value / target.checked at fire time (nil for non-form targets).
    /// Filled by DOMBackend's decoder so `.on(.click)` GenericEvent adapters
    /// stop dropping them (phase-4 carry).
    public let targetValue: String?
    public let checked: Bool?
    public init(button: Int = 0, metaKey: Bool = false, ctrlKey: Bool = false,
                shiftKey: Bool = false, altKey: Bool = false,
                targetValue: String? = nil, checked: Bool? = nil) {
        self.button = button; self.metaKey = metaKey; self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey; self.altKey = altKey
        self.targetValue = targetValue; self.checked = checked
    }
    public var isModified: Bool { button != 0 || metaKey || ctrlKey || shiftKey || altKey }
}
```

And add the adapter case in `GenericEvent.init(type:payload:)` BEFORE `default`:

```swift
case let e as ClickEvent:   self.init(type: type, targetValue: e.targetValue, key: nil, checked: e.checked)
```

(The DOMBackend decode side lands in Task 13 — native code and tests are complete without it.)

- [ ] **Step 7: docs** — on `Page.title` declaration add:

```swift
/// Browser-tab title, applied on navigation.
/// NOTE: head application is navigation-driven — a @State-driven change to
/// `title` between navigations is NOT re-applied until the next route pass
/// (phase-4 decision; revisit if live titles are ever needed).
```

On `Router._resolve`'s assert line add a trailing comment: `// release: both Routers resolve (documented degrade); debug traps`.

- [ ] **Step 8: tests** — append to `RoutePatternTests.swift`:

```swift
@Test func normalizePathStripsManyTrailingSlashes() {
    #expect(RouteURL.normalizePath("/a" + String(repeating: "/", count: 1000)) == "/a")
    #expect(RouteURL.normalizePath(String(repeating: "/", count: 1000)) == "/")
}
@Test func isExternalClassifiesDestinations() {
    #expect(RouteURL.isExternal("https://x.dev"))
    #expect(RouteURL.isExternal("mailto:a@b.c"))
    #expect(RouteURL.isExternal("//cdn.x.dev/lib.js"))
    #expect(!RouteURL.isExternal("/docs/intro"))
    #expect(!RouteURL.isExternal("/search?q=a:b"))     // ':' after '?' is not a scheme
    #expect(!RouteURL.isExternal("#section"))
}
#if !DEBUG
@Test func catchAllMidPatternDegradesToPrefixMatch() {   // release-only: debug asserts in init
    let p = RoutePattern("/files/*/edit")
    #expect(p.match("/files/a/b") == ["*": "a/b"])
}
#endif
```

Append to `LinkTests.swift` (match the file's existing render-and-inspect style — it renders via `HTMLRenderer.render` or a `Runtime<MockBackend>`; follow whichever pattern the existing Link tests use):

```swift
@Test func anchorLinkIsNotIntercepted() {
    let html = HTMLRenderer.render(Link("#features") { Text("Features") })
    #expect(html.contains("href=\"#features\""))
    #expect(!html.contains("data-swui-link"))
}
```

Append to `EventPayloadTests.swift`:

```swift
@Test func genericAdapterMapsClickEventFields() {
    let g = GenericEvent(type: "click",
                         payload: ClickEvent(targetValue: "on", checked: true))
    #expect(g.targetValue == "on")
    #expect(g.checked == true)
    #expect(g.key == nil)
}
```

- [ ] **Step 9: run `swift test`** — expected: all pass (≈220, zero failures).

- [ ] **Step 10: commit**

```bash
git add -A
git commit -m "fix(routing): phase-4 carry list — normalizePath O(n), catchAll degrade, Link anchors, navigate assert, ClickEvent fields"
```

---

### Task 2: Tag set — text-level & semantic containers

**Files:**
- Create: `Sources/SwiftWUI/HTML/Tags+Text.swift`
- Test: `Tests/SwiftWUITests/HTMLRendererTests.swift` (append)

**Interfaces:**
- Consumes: `_HTMLContainerTag`/`_HTMLVoidTag` protocols (`HTML/HTMLTag.swift`), `_AttributeBag`, `Text`, `EmptyTag`.
- Produces: 36 public tag structs listed below. All follow the `Div` pattern exactly.

- [ ] **Step 1: the container template.** Every plain container in the table below is EXACTLY this shape (this is `Div`'s existing pattern — copy it, changing only the struct name and tagName):

```swift
public struct Aside<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "aside" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        self.content = content()
    }
}
```

Plain containers (struct → tagName): `Aside`→aside, `Address`→address, `Small`→small, `Sub`→sub, `Sup`→sup, `Mark`→mark, `Kbd`→kbd, `Cite`→cite, `Dfn`→dfn, `Var`→`var`, `Samp`→samp, `B`→b, `I`→i, `U`→u, `S`→s, `Bdi`→bdi, `Bdo`→bdo, `Ruby`→ruby, `Rt`→rt, `Rp`→rp, `Hgroup`→hgroup, `Search`→search, `Menu`→menu, `Figure`→figure, `Figcaption`→figcaption, `Dl`→dl, `Dt`→dt, `Dd`→dd, `Summary`→summary (used by Task 4's Details too).

- [ ] **Step 2: typed-attribute containers** — same template plus the listed init params (attribute set only when non-nil, mirroring `Input`'s `_attributes.set(name, value)` which ignores nil):

```swift
public struct Blockquote<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "blockquote" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        self.content = content()
    }
}

public struct Q<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "q" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        self.content = content()
    }
}

public struct Time<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "time" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(datetime: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("datetime", datetime)
        self.content = content()
    }
}

public struct Abbr<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "abbr" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(title: String? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("title", title)
        self.content = content()
    }
}

public struct Del<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "del" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, datetime: String? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        _attributes.set("datetime", datetime)
        self.content = content()
    }
}

public struct Ins<Content: Tag>: _HTMLContainerTag {     // same params as Del
    public static var tagName: String { "ins" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(cite: String? = nil, datetime: String? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let cite { _attributes.set("cite", HTMLEscaping.sanitizeURL(cite)) }
        _attributes.set("datetime", datetime)
        self.content = content()
    }
}

public struct Data<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "data" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: String, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("value", value)
        self.content = content()
    }
}
```

- [ ] **Step 3: `Wbr` void** — `Br` pattern:

```swift
public struct Wbr: _HTMLVoidTag {
    public static var tagName: String { "wbr" }
    public var _attributes: _AttributeBag
    public init() { _attributes = _AttributeBag() }
}
```

- [ ] **Step 4: tests** — append to `HTMLRendererTests.swift` (spot goldens, not one per tag — the template is shared; test one plain, every typed one, and the void):

```swift
@Test func textLevelTagsRender() {
    #expect(HTMLRenderer.render(Aside { Text("x") }) == "<aside>x</aside>")
    #expect(HTMLRenderer.render(Blockquote(cite: "https://a.dev") { Text("q") })
            == "<blockquote cite=\"https://a.dev\">q</blockquote>")
    #expect(HTMLRenderer.render(Q(cite: "https://a.dev") { Text("q") })
            == "<q cite=\"https://a.dev\">q</q>")
    #expect(HTMLRenderer.render(Time(datetime: "2026-07-03") { Text("today") })
            == "<time datetime=\"2026-07-03\">today</time>")
    #expect(HTMLRenderer.render(Abbr(title: "HyperText") { Text("HT") })
            == "<abbr title=\"HyperText\">HT</abbr>")
    #expect(HTMLRenderer.render(Del(datetime: "2026-01-01") { Text("old") })
            == "<del datetime=\"2026-01-01\">old</del>")
    #expect(HTMLRenderer.render(Ins { Text("new") }) == "<ins>new</ins>")
    #expect(HTMLRenderer.render(Data(value: "42") { Text("answer") })
            == "<data value=\"42\">answer</data>")
    #expect(HTMLRenderer.render(Div { Wbr() }) == "<div><wbr></div>")
    #expect(HTMLRenderer.render(Blockquote(cite: "javascript:alert(1)") { Text("q") })
            == "<blockquote>q</blockquote>")            // sanitizeURL drops the attr entirely
}
```

NOTE: check `HTMLEscaping.sanitizeURL`'s actual rejection behavior before finalizing the last assertion — if it returns nil (attr dropped) the golden above is right; if it returns a neutered value, pin whatever it produces. Read `Escaping/HTMLEscaping.swift` first.

- [ ] **Step 5: run `swift test`** — expected: all pass.

- [ ] **Step 6: commit**

```bash
git add -A
git commit -m "feat(html): text-level and semantic container tags (batch 1 of full tag set)"
```

---

### Task 3: Tag set — table family & form controls

**Files:**
- Create: `Sources/SwiftWUI/HTML/Tags+Table.swift`
- Test: `Tests/SwiftWUITests/HTMLRendererTests.swift` (append), `Tests/SwiftWUITests/ControlledInputTests.swift` (append)

**Interfaces:**
- Consumes: container/void templates (Task 2 conventions), `Binding<String>` + `_attributes.setProperty`/`addHandler` (the `Input(value:)` controlled pattern at `HTML/Tags.swift:104`), `ChangeEvent`.
- Produces: `Table, Caption, Thead, Tbody, Tfoot, Tr, Th, Td, Colgroup, Col, Select, Option, Optgroup, Fieldset, Legend, Output, Datalist, Progress, Meter`. Controlled `Select(value: Binding<String>, …)`.

- [ ] **Step 1: table containers** — plain template (Task 2 Step 1 shape): `Table`→table, `Caption`→caption, `Thead`→thead, `Tbody`→tbody, `Tfoot`→tfoot, `Tr`→tr. Cells get span params:

```swift
public struct Th<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "th" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(colspan: Int? = nil, rowspan: Int? = nil, scope: String? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let colspan { _attributes.set("colspan", String(colspan)) }
        if let rowspan { _attributes.set("rowspan", String(rowspan)) }
        _attributes.set("scope", scope)
        self.content = content()
    }
}

public struct Td<Content: Tag>: _HTMLContainerTag {      // same minus scope
    public static var tagName: String { "td" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(colspan: Int? = nil, rowspan: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let colspan { _attributes.set("colspan", String(colspan)) }
        if let rowspan { _attributes.set("rowspan", String(rowspan)) }
        self.content = content()
    }
}

public struct Colgroup<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "colgroup" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(span: Int? = nil, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let span { _attributes.set("span", String(span)) }
        self.content = content()
    }
}

public struct Col: _HTMLVoidTag {
    public static var tagName: String { "col" }
    public var _attributes: _AttributeBag
    public init(span: Int? = nil, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let span { _attributes.set("span", String(span)) }
    }
}
```

- [ ] **Step 2: Select/Option/Optgroup** — `Option` is a plain container plus `value:`/`selected:`/`disabled:`; `Select` has an uncontrolled init and a controlled one following `Input(value:)` exactly (DOM `value` property + change writes back):

```swift
public struct Option<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "option" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: String? = nil, selected: Bool = false, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("value", value)
        if selected { _attributes.set("selected", "") }
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
}
extension Option where Content == Text {
    public init(_ label: String, value: String? = nil, selected: Bool = false,
                disabled: Bool = false, id: String? = nil, class classes: String? = nil) {
        self.init(value: value, selected: selected, disabled: disabled,
                  id: id, class: classes) { Text(label) }
    }
}

public struct Optgroup<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "optgroup" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(label: String, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("label", label)
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
}

public struct Select<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "select" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(name: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("name", name)
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
    /// Controlled select (Input(value:) pattern): DOM `value` property tracks
    /// the binding; every change event writes it back.
    public init(value: Binding<String>, name: String? = nil, disabled: Bool = false,
                id: String? = nil, class classes: String? = nil,
                onChange: ((ChangeEvent) -> Void)? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("name", name)
        if disabled { _attributes.set("disabled", "") }
        _attributes.setProperty("value", .string(value.wrappedValue))
        _attributes.addHandler(.change, payload: ChangeEvent.self) { e in
            value.wrappedValue = e.value
            onChange?(e)
        }
        self.content = content()
    }
}
```

- [ ] **Step 3: remaining form tags:**

```swift
public struct Fieldset<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "fieldset" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(disabled: Bool = false, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if disabled { _attributes.set("disabled", "") }
        self.content = content()
    }
}
```

`Legend`, `Datalist` — plain template. `Output` — plain plus `for:`/`name:` (`_attributes.set("for", htmlFor)`, param label `for htmlFor: String? = nil`).

```swift
public struct Progress<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "progress" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: Double? = nil, max: Double? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let value { _attributes.set("value", String(value)) }
        if let max { _attributes.set("max", String(max)) }
        self.content = content()
    }
}

public struct Meter<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "meter" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(value: Double, min: Double? = nil, max: Double? = nil,
                low: Double? = nil, high: Double? = nil, optimum: Double? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("value", String(value))
        if let min { _attributes.set("min", String(min)) }
        if let max { _attributes.set("max", String(max)) }
        if let low { _attributes.set("low", String(low)) }
        if let high { _attributes.set("high", String(high)) }
        if let optimum { _attributes.set("optimum", String(optimum)) }
        self.content = content()
    }
}
```

- [ ] **Step 4: tests** — append a table golden to `HTMLRendererTests.swift`:

```swift
@Test func tableFamilyRenders() {
    let html = HTMLRenderer.render(
        Table {
            Thead { Tr { Th(scope: "col") { Text("N") } } }
            Tbody { Tr { Td(colspan: 2) { Text("1") } } }
        })
    #expect(html == "<table><thead><tr><th scope=\"col\">N</th></tr></thead>"
                  + "<tbody><tr><td colspan=\"2\">1</td></tr></tbody></table>")
}
@Test func selectOptionRender() {
    let html = HTMLRenderer.render(
        Select(name: "pet") {
            Option("Cat", value: "cat", selected: true)
            Option("Dog", value: "dog")
        })
    #expect(html == "<select name=\"pet\"><option selected value=\"cat\">Cat</option>"
                  + "<option value=\"dog\">Dog</option></select>")
}
```

Append a controlled-select test to `ControlledInputTests.swift`, mirroring the file's existing controlled-Input test structure (Runtime + MockBackend + dispatch a `.change` with `ChangeEvent(value: "dog", checked: false)`, expect the binding updated and the `value` property re-rendered). Copy the existing controlled-input test in that file and adapt tag/event.

- [ ] **Step 5: run `swift test`** — expected: all pass.

- [ ] **Step 6: commit**

```bash
git add -A
git commit -m "feat(html): table family and form controls incl. controlled Select (batch 2)"
```

---

### Task 4: Tag set — media, embedded & interactive

**Files:**
- Create: `Sources/SwiftWUI/HTML/Tags+Media.swift`
- Modify: `Sources/SwiftWUI/Render/HTMLRenderer.swift` (voidElements: add `"param"`)
- Test: `Tests/SwiftWUITests/HTMLRendererTests.swift` (append), `Tests/SwiftWUITests/CrossCheckTests.swift` (extend fixture)

**Interfaces:**
- Consumes: templates + `HTMLEscaping.sanitizeURL` for every URL-bearing attribute (`src`, `poster`, `data`, `href` — same posture as `A`/`Img`).
- Produces: `Details, Dialog, Iframe, Video, Audio, Source, Track, Picture, Canvas, Object, Embed, Param, Map, Area, Noscript`. NO `Template`/`Slot` (spec §11 — parser puts template children into `.content`, breaking T8/adoption).

- [ ] **Step 1: interactive containers:**

```swift
public struct Details<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "details" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(open: Bool = false, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if open { _attributes.set("open", "") }
        self.content = content()
    }
}

public struct Dialog<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "dialog" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(open: Bool = false, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if open { _attributes.set("open", "") }
        self.content = content()
    }
}
```

(`Summary` landed in Task 2.)

- [ ] **Step 2: media:**

```swift
public struct Video<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "video" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(src: String? = nil, poster: String? = nil,
                controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false, playsinline: Bool = false,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let src { _attributes.set("src", HTMLEscaping.sanitizeURL(src)) }
        if let poster { _attributes.set("poster", HTMLEscaping.sanitizeURL(poster)) }
        if controls { _attributes.set("controls", "") }
        if autoplay { _attributes.set("autoplay", "") }
        if loop { _attributes.set("loop", "") }
        if muted { _attributes.set("muted", "") }
        if playsinline { _attributes.set("playsinline", "") }
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}

public struct Audio<Content: Tag>: _HTMLContainerTag {   // Video minus visual params
    public static var tagName: String { "audio" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(src: String? = nil, controls: Bool = false, autoplay: Bool = false,
                loop: Bool = false, muted: Bool = false,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let src { _attributes.set("src", HTMLEscaping.sanitizeURL(src)) }
        if controls { _attributes.set("controls", "") }
        if autoplay { _attributes.set("autoplay", "") }
        if loop { _attributes.set("loop", "") }
        if muted { _attributes.set("muted", "") }
        self.content = content()
    }
}

public struct Source: _HTMLVoidTag {
    public static var tagName: String { "source" }
    public var _attributes: _AttributeBag
    public init(src: String? = nil, srcset: String? = nil, type: String? = nil,
                media: String? = nil, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let src { _attributes.set("src", HTMLEscaping.sanitizeURL(src)) }
        _attributes.set("srcset", srcset)          // srcset is a URL LIST — not single-URL sanitizable; escaped at serialization like any attr
        _attributes.set("type", type)
        _attributes.set("media", media)
    }
}

public struct Track: _HTMLVoidTag {
    public static var tagName: String { "track" }
    public var _attributes: _AttributeBag
    public init(src: String, kind: String? = nil, srclang: String? = nil,
                label: String? = nil, isDefault: Bool = false,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("kind", kind)
        _attributes.set("srclang", srclang)
        _attributes.set("label", label)
        if isDefault { _attributes.set("default", "") }
    }
}
```

`Picture` — plain container template.

- [ ] **Step 3: embedded:**

```swift
public struct Iframe<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "iframe" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(src: String, title: String? = nil, sandbox: String? = nil,
                allow: String? = nil, loading: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("title", title)
        _attributes.set("sandbox", sandbox)
        _attributes.set("allow", allow)
        _attributes.set("loading", loading)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}
extension Iframe where Content == EmptyTag {
    public init(src: String, title: String? = nil, sandbox: String? = nil,
                allow: String? = nil, loading: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil) {
        self.init(src: src, title: title, sandbox: sandbox, allow: allow,
                  loading: loading, width: width, height: height,
                  id: id, class: classes) { EmptyTag() }
    }
}

public struct Canvas<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "canvas" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}

public struct Object<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "object" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(data: String? = nil, type: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        if let data { _attributes.set("data", HTMLEscaping.sanitizeURL(data)) }
        _attributes.set("type", type)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        self.content = content()
    }
}

public struct Embed: _HTMLVoidTag {
    public static var tagName: String { "embed" }
    public var _attributes: _AttributeBag
    public init(src: String, type: String? = nil,
                width: Int? = nil, height: Int? = nil,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("type", type)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
    }
}

public struct Param: _HTMLVoidTag {
    public static var tagName: String { "param" }
    public var _attributes: _AttributeBag
    public init(name: String, value: String) {
        _attributes = _AttributeBag()
        _attributes.set("name", name)
        _attributes.set("value", value)
    }
}

public struct Map<Content: Tag>: _HTMLContainerTag {
    public static var tagName: String { "map" }
    public var _attributes: _AttributeBag
    public var content: Content
    public init(name: String, id: String? = nil, class classes: String? = nil,
                @TagBuilder content: () -> Content) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("name", name)
        self.content = content()
    }
}

public struct Area: _HTMLVoidTag {
    public static var tagName: String { "area" }
    public var _attributes: _AttributeBag
    public init(shape: String, coords: String? = nil, href: String? = nil,
                alt: String, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("shape", shape)
        _attributes.set("coords", coords)
        if let href { _attributes.set("href", HTMLEscaping.sanitizeURL(href)) }
        _attributes.set("alt", alt)
    }
}
```

- [ ] **Step 4: `Noscript` — text-only (spec §11):**

```swift
/// Text-only by design: with scripting enabled, the HTML parser treats
/// noscript content as raw text — element children would come back as one
/// text node and break T8/adoption. One text child matches in both worlds.
public struct Noscript: _HTMLContainerTag {
    public static var tagName: String { "noscript" }
    public var _attributes: _AttributeBag
    public var content: Text
    public init(_ text: String, id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        content = Text(text)
    }
}
```

- [ ] **Step 5: void set + coverage assert** — add `"param"` to `HTMLRenderer.voidElements`. Append to `HTMLRendererTests.swift`:

```swift
@Test func voidSetCoversAllVoidTagStructs() {
    // Every _HTMLVoidTag's tagName must be in HTMLRenderer.voidElements —
    // a miss means serialized output grows a bogus closing tag (T8 break).
    let voidTagNames = [Input.tagName, Img.tagName, Br.tagName, Hr.tagName,
                        Wbr.tagName, Col.tagName, Source.tagName, Track.tagName,
                        Embed.tagName, Param.tagName, Area.tagName]
    for name in voidTagNames { #expect(HTMLRenderer.voidElements.contains(name)) }
}
@Test func mediaAndInteractiveTagsRender() {
    #expect(HTMLRenderer.render(Details(open: true) { Summary { Text("t") }; P { Text("b") } })
            == "<details open><summary>t</summary><p>b</p></details>")
    #expect(HTMLRenderer.render(Video(src: "/v.mp4", controls: true) { Source(src: "/v.webm", type: "video/webm") })
            == "<video controls src=\"/v.mp4\"><source src=\"/v.webm\" type=\"video/webm\"></video>")
    #expect(HTMLRenderer.render(Noscript("Enable JS")) == "<noscript>Enable JS</noscript>")
    #expect(HTMLRenderer.render(Iframe(src: "https://x.dev", title: "demo"))
            == "<iframe src=\"https://x.dev\" title=\"demo\"></iframe>")
}
```

- [ ] **Step 6: extend the cross-check fixture** — `CrossCheckTests.swift` holds the T8 property (HTMLRenderer output ≡ MockBackend serialize). Add a representative new-tag subtree (table + details + video with source) to its existing fixture so the property covers the new vocabulary. Follow the file's existing fixture-extension style.

- [ ] **Step 7: run `swift test`** — expected: all pass.

- [ ] **Step 8: commit**

```bash
git add -A
git commit -m "feat(html): media, embedded and interactive tags; void-set coverage assert (batch 3)"
```

---

### Task 5: Canonical NodeIdentity serialization

**Files:**
- Create: `Sources/SwiftWUI/Identity/IdentityCanonical.swift`
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (one line: register type names)
- Test: `Tests/SwiftWUITests/IdentityTests.swift` (append)

**Interfaces:**
- Consumes: `NodeIdentity`/`IdentitySegment` (`Identity/Identity.swift`), `resolve<T>` component boundary (`Runtime/Resolver.swift:47`).
- Produces: `NodeIdentity._canonicalString: String?` (nil only for unregistered `.type` — impossible for resolve-produced identities); `_TypeNameRegistry.register(_ type: Any.Type)`. Grammar (D7): segments joined by `/`; `c<n>` (child), `b0`/`b1` (branch), `k<escaped desc>` (keyed, `String(describing: base)`), `t<escaped qualified name>` (type, `String(reflecting:)`). Escape: `%` → `%25`, `/` → `%2F` inside a segment payload.

- [ ] **Step 1: registry + canonical string** — `IdentityCanonical.swift`:

```swift
/// ObjectIdentifier → fully-qualified type name (spec §7 / D7). Populated by
/// resolve<T> at every component boundary. ObjectIdentifier is process-local;
/// the snapshot needs a name that is identical in the native builder and the
/// wasm client of the same source — String(reflecting:) is exactly that.
/// NEVER use hashValue anywhere in this file (seed-randomized per process).
enum _TypeNameRegistry {
    private(set) static var names: [ObjectIdentifier: String] = [:]
    static func register(_ type: Any.Type) {
        let oid = ObjectIdentifier(type)
        if names[oid] == nil { names[oid] = String(reflecting: type) }
    }
}

// (No replacingOccurrences — that's Foundation, and the core is Foundation-free.)
private func escapeSegmentPayload(_ s: String) -> String {
    guard s.contains("%") || s.contains("/") else { return s }
    var out = ""
    out.reserveCapacity(s.count)
    for ch in s {
        switch ch {
        case "%": out += "%25"
        case "/": out += "%2F"
        default:  out.append(ch)
        }
    }
    return out
}

extension NodeIdentity {
    /// Canonical cross-process form (spec D7): "c0/tTodoMVC.AboutPage/c0/b1".
    /// The exact grammar is a compatibility surface between an SSG build and
    /// the wasm client built from the same source — pinned by a golden test.
    public var _canonicalString: String? {
        var parts: [String] = []
        parts.reserveCapacity(segments.count)
        for seg in segments {
            switch seg {
            case .child(let n):   parts.append("c\(n)")
            case .branch(let b):  parts.append(b ? "b1" : "b0")
            case .keyed(let k):   parts.append("k" + escapeSegmentPayload(String(describing: k.base)))
            case .type(let oid):
                guard let name = _TypeNameRegistry.names[oid] else { return nil }
                parts.append("t" + escapeSegmentPayload(name))
            }
        }
        return parts.joined(separator: "/")
    }
}
```

- [ ] **Step 2: register at every `.type`-minting site** — in `Resolver.swift`'s `resolve<T>`, directly after `let id = path.appending(.type(ObjectIdentifier(T.self)))` add:

```swift
_TypeNameRegistry.register(T.self)     // snapshot keys need the stable name (spec D7)
```

PLAN AMENDMENT (Task-5 review C1): `resolve<T>` is NOT the only `.type` minter — five primitive wrappers append `.type(ObjectIdentifier(Self.self))` in their `_resolve` and must register the same way (one line each, next to their `path.appending(.type(...))`): `_EnvironmentWriter` (Environment/Environment.swift:43), `_OnChangeEffect`/`_TaskEffect`/`_AppearEffect` (Effects/EffectModifiers.swift:8,25,37), `_StyledTag` (Styles/StyledTag.swift:14). Without these, `_canonicalString` is nil for any subtree under `.environment`/`.task`/`.onAppear`/`.onChange`/wrapper styles — silent state loss at hydration. HTML primitives (Div etc.) never mint `.type` and stay out of the registry.

- [ ] **Step 3: tests** — append to `IdentityTests.swift`:

```swift
private struct CanonFixture: Tag { var body: some Tag { Div { Text("x") } } }

@Test func canonicalStringGrammar() {
    _TypeNameRegistry.register(CanonFixture.self)
    let id = NodeIdentity.root
        .appending(.child(0))
        .appending(.type(ObjectIdentifier(CanonFixture.self)))
        .appending(.branch(true))
        .appending(.keyed(NodeKey("a/b%c")))
    #expect(id._canonicalString == "c0/t\(String(reflecting: CanonFixture.self))/b1/ka%2Fb%25c")
}
@Test func canonicalStringNilForUnregisteredType() {
    struct NeverResolved {}
    let id = NodeIdentity.root.appending(.type(ObjectIdentifier(NeverResolved.self)))
    #expect(id._canonicalString == nil)
}
@Test func resolveRegistersComponentTypeNames() {
    var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(), invalidate: { _ in })
    _ = resolve(CanonFixture(), path: .root, ctx: &ctx)
    let id = NodeIdentity.root.appending(.type(ObjectIdentifier(CanonFixture.self)))
    #expect(id._canonicalString?.hasPrefix("t") == true)
}
```

- [ ] **Step 4: run `swift test`**, expected all pass.

- [ ] **Step 5: commit**

```bash
git add -A
git commit -m "feat(identity): canonical NodeIdentity serialization + type-name registry (spec D7)"
```

---

### Task 6: TaskPolicy — `.build` tasks & `.staticTask`

**Files:**
- Modify: `Sources/SwiftWUI/Effects/EffectModifiers.swift` (policy param, staticTask sugar)
- Modify: `Sources/SwiftWUI/Effects/EffectStore.swift` (policy routing, build-mode collection, skip set)
- Test: `Tests/SwiftWUITests/EffectTests.swift` (append)

**Interfaces:**
- Consumes: `EffectRequest.task` (`EffectStore.swift:5`), `_TaskEffect` (`EffectModifiers.swift:21`), `NodeIdentity._canonicalString` (Task 5).
- Produces:
  - `public enum TaskPolicy { case client, build }`
  - `Tag.task(id:policy:_:)` / `Tag.task(policy:_:)` (policy defaults `.client` — source-compatible) and `Tag.staticTask(_:)` (= `.build`).
  - `EffectStore` SPI for the SSG driver (Task 11) and hydration boot (Task 13):
    `_buildMode: Bool` (default false), `_skipBuildTaskKeys: Set<String>`,
    `_drainBuildTasks() -> [(id: NodeIdentity, action: () async -> Void)]`,
    `_completedBuildKeys: [String]`, `_recordBuildCompleted(_ id: NodeIdentity)`.

- [ ] **Step 1: policy on the request** — in `EffectStore.swift`:

```swift
public enum TaskPolicy { case client, build }
```

Change the case to `case task(id: NodeIdentity, taskID: AnyHashable?, policy: TaskPolicy, action: () async -> Void)` and fix the `var id` switch accordingly.

- [ ] **Step 2: modifiers** — in `EffectModifiers.swift`, `_TaskEffect` gains `let policy: TaskPolicy` and appends it in its `_resolve` (`ctx.effects.append(.task(id: id, taskID: taskID, policy: policy, action: action))`). Public surface (replaces the two existing `task` overloads, keeping their signatures valid via defaults):

```swift
public func task(policy: TaskPolicy = .client, _ action: @escaping () async -> Void) -> some Tag {
    _TaskEffect(taskID: nil, policy: policy, action: action, content: self)
}
public func task<ID: Hashable>(id: ID, policy: TaskPolicy = .client,
                               _ action: @escaping () async -> Void) -> some Tag {
    _TaskEffect(taskID: AnyHashable(id), policy: policy, action: action, content: self)
}
/// Build-time loader (spec §6, D5): runs during SSG and is awaited before the
/// HTML is taken; its @State writes ship in the snapshot. On a hydrated client
/// it is skipped (the snapshot's "tasks" list covers it); on a cold client it
/// runs like a normal task.
public func staticTask(_ action: @escaping () async -> Void) -> some Tag {
    _TaskEffect(taskID: nil, policy: .build, action: action, content: self)
}
```

- [ ] **Step 3: EffectStore routing** — add stored state:

```swift
/// SSG driver mode (spec §6): .build tasks are collected, not started;
/// .client tasks don't run at all.
var _buildMode = false
/// Canonical ids of .build tasks the snapshot says already ran (client boot).
var _skipBuildTaskKeys: Set<String> = []
private var pendingBuild: [(id: NodeIdentity, action: () async -> Void)] = []
private var startedBuild: Set<NodeIdentity> = []
private(set) var _completedBuildKeys: [String] = []

func _drainBuildTasks() -> [(id: NodeIdentity, action: () async -> Void)] {
    defer { pendingBuild = [] }
    return pendingBuild
}
func _recordBuildCompleted(_ id: NodeIdentity) {
    if let key = id._canonicalString { _completedBuildKeys.append(key) }
}
```

Replace the `.task` handling inside `reconcile` with:

```swift
case .task(let id, let taskID, let policy, let action):
    if _buildMode {
        // SSG: .client never runs at build; .build is collected once per identity
        // and awaited by the driver (spec §6). No Task objects are created here.
        if policy == .build, !startedBuild.contains(id) {
            startedBuild.insert(id)
            pendingBuild.append((id, action))
        }
    } else if policy == .build, let key = id._canonicalString,
              _skipBuildTaskKeys.remove(key) != nil {
        // Hydration boot: the snapshot carried this loader's result — consume
        // the skip entry and park a finished Task so the identity is occupied
        // (a later taskID change still restarts it via the normal path).
        tasks[id] = (Task {}, taskID)
    } else if let existing = tasks[id] {
        if existing.id != taskID {
            existing.task.cancel()
            tasks[id] = (Task { await action() }, taskID)
        }
    } else {
        tasks[id] = (Task { await action() }, taskID)
    }
```

(The sweep block above `reconcile`'s request loop is unchanged — build-mode entries never land in `tasks`, so nothing leaks.)

- [ ] **Step 4: tests** — append to `EffectTests.swift`, following the file's existing runtime-fixture style (`Runtime<MockBackend>` + `TestScheduler`):

```swift
private struct BuildTaskFixture: Tag {
    @State var loaded = "initial"
    var body: some Tag {
        Div { Text(loaded) }
            .staticTask { loaded = "from-loader" }
            .task { loaded = "client-task-ran" }        // .client — must NOT run in build mode
    }
}

@Test func buildModeCollectsBuildTasksAndSkipsClientTasks() async {
    let backend = MockBackend()
    let sched = TestScheduler()
    let runtime = Runtime(backend: backend, container: backend.container,
                          root: BuildTaskFixture(), scheduleMicrotask: sched.schedule)
    runtime._effects._buildMode = true
    runtime.mount()
    let drained = runtime._effects._drainBuildTasks()
    #expect(drained.count == 1)
    await drained[0].action()
    runtime._effects._recordBuildCompleted(drained[0].id)
    sched.pump()
    #expect(backend.serializeHTML().contains("from-loader"))
    #expect(!backend.serializeHTML().contains("client-task-ran"))
    #expect(runtime._effects._completedBuildKeys.count == 1)
}

@Test func skipSetConsumesBuildTaskOnce() async throws {
    // Boot with the loader's canonical key in the skip set: the .build task
    // must not run; a normal .client task on the same tree still runs.
    let backend = MockBackend()
    let sched = TestScheduler()
    let runtime = Runtime(backend: backend, container: backend.container,
                          root: BuildTaskFixture(), scheduleMicrotask: sched.schedule)
    // Key discovery: run a probe first to learn the loader's canonical id.
    let probeBackend = MockBackend()
    let probe = Runtime(backend: probeBackend, container: probeBackend.container,
                        root: BuildTaskFixture(), scheduleMicrotask: { _ in })
    probe._effects._buildMode = true
    probe.mount()
    let key = probe._effects._drainBuildTasks()[0].id._canonicalString!
    runtime._effects._skipBuildTaskKeys = [key]
    runtime.mount()
    try await Task.sleep(nanoseconds: 50_000_000)     // let the .client Task land
    sched.pump()
    let html = backend.serializeHTML()
    #expect(html.contains("client-task-ran"))          // .client ran
    #expect(runtime._effects._skipBuildTaskKeys.isEmpty)   // skip entry consumed
}
```

NOTE: `runtime._effects` is Task 9's SPI accessor. To keep this task self-contained, add it here (one line in `Runtime`): `public var _effects: EffectStore { effects }` — Task 9 lists it too; whichever task lands first adds it, the other skips.

- [ ] **Step 5: run `swift test`**, expected all pass (the async tests use the same patterns as existing EffectTests task tests).

- [ ] **Step 6: commit**

```bash
git add -A
git commit -m "feat(effects): TaskPolicy .client/.build, staticTask loader, EffectStore build-mode collection (spec D5)"
```

---

### Task 7: State snapshot — core seams (pending rows, encode/decode hooks)

**Files:**
- Create: `Sources/SwiftWUI/State/StateSnapshot.swift`
- Modify: `Sources/SwiftWUI/State/State.swift` (`_StateProperty._boxDecoding`, `StateBox` encode conformance)
- Modify: `Sources/SwiftWUI/State/StateStore.swift` (pending seed in `link`, `_encodeSnapshotRows`)
- Test: `Tests/SwiftWUITests/StateStoreTests.swift` (append)

**Interfaces:**
- Consumes: `StateStore.link` (StateStore.swift:60), `_StateProperty` protocol + `StateBox` (State/State.swift — READ THE FILE FIRST: the exact box type/initializer must be reused, not re-invented), `NodeIdentity._canonicalString` (Task 5).
- Produces (all Foundation-free — JSON work happens in the injected closures):
  - `public typealias SnapshotDecode = (String, any Decodable.Type) -> (any Decodable)?`
  - `public typealias SnapshotEncode = (any Encodable) -> String?`
  - `StateStore._pendingRows: [String: [String]]` (canonical key → slot JSON fragments), `StateStore._decodeSlot: SnapshotDecode?`
  - `StateStore._encodeSnapshotRows(_ encode: SnapshotEncode) -> [String: [String]]` — Encodable-only rows, WHOLE row dropped on any non-encodable slot (spec §7).
  - `_StateProperty._boxDecoding(json: String, decode: SnapshotDecode) -> AnyObject?`
  - Slot JSON convention (D7 note): every slot fragment is a **single-element JSON array** `[<value>]` — sidesteps top-level-fragment support differences between JSON coders; both hooks follow it (Task 10/13).

- [ ] **Step 1: `StateSnapshot.swift`** — the typealiases plus doc comment:

```swift
/// Snapshot plumbing (spec §7, D7). The core never touches JSON itself —
/// SwiftWUIStatic injects the encoder (JSONEncoder), SwiftWUIDOM the decoder
/// (JSONDecoder/FoundationEssentials). Slot convention: one JSON fragment per
/// @State slot, always a single-element array "[<value>]".
public typealias SnapshotDecode = (String, any Decodable.Type) -> (any Decodable)?
public typealias SnapshotEncode = (any Encodable) -> String?
```

- [ ] **Step 2: `_StateProperty` decode hook** — in `State.swift`, add to the `_StateProperty` protocol:

```swift
/// Builds a box seeded from a snapshot slot, or nil when Value isn't
/// Decodable / the JSON doesn't decode. Never traps (spec §7).
func _boxDecoding(json: String, decode: SnapshotDecode) -> AnyObject?
```

`State<Value>` implementation (adapt the box construction to the file's actual `StateBox` initializer — read it first):

```swift
public func _boxDecoding(json: String, decode: SnapshotDecode) -> AnyObject? {
    guard let decodableType = Value.self as? any Decodable.Type,
          let decoded = decode(json, decodableType),
          let value = decoded as? Value else { return nil }
    return StateBox(value)          // ← match the real initializer in State.swift
}
```

- [ ] **Step 3: `StateBox` encode conformance** — in `State.swift`:

```swift
protocol _SnapshotEncodableBox: AnyObject {
    func _encodeJSON(_ encode: SnapshotEncode) -> String?
}
extension StateBox: _SnapshotEncodableBox {
    func _encodeJSON(_ encode: SnapshotEncode) -> String? {
        guard let v = value as? any Encodable else { return nil }
        return encode(v)
    }
}
```

(If `StateBox`'s stored value property has a different name, adapt; the shape is what matters.)

- [ ] **Step 4: StateStore seed + encode** — add stored properties:

```swift
/// Snapshot seed (spec §7): canonical id → slot JSON fragments, consumed on
/// first link() of each row. Seeded by DOMRuntime before mount.
public var _pendingRows: [String: [String]] = [:]
public var _decodeSlot: SnapshotDecode? = nil
```

In `link(_:at:environment:invalidate:)`, insert BEFORE the `if let boxes = rows[id]` branch:

```swift
if rows[id] == nil, !_pendingRows.isEmpty, let decode = _decodeSlot,
   let key = id._canonicalString, let slots = _pendingRows.removeValue(forKey: key) {
    if slots.count == props.count {
        var boxes: [AnyObject] = []
        boxes.reserveCapacity(slots.count)
        var ok = true
        for (json, p) in zip(slots, props) {
            guard let box = p._boxDecoding(json: json, decode: decode) else { ok = false; break }
            boxes.append(box)
        }
        if ok {
            rows[id] = boxes       // the adopt path below grafts them like any persisted row
        } else {
            #if DEBUG
            print("SwiftWUI snapshot: row '\(key)' failed to decode — using initial values")
            #endif
        }
    } else {
        #if DEBUG
        print("SwiftWUI snapshot: row '\(key)' slot count \(slots.count) != \(props.count) — using initial values")
        #endif
    }
}
```

(Consumed-or-not, `removeValue` already guarantees no stale reuse — spec §7.)

Add the encode walk:

```swift
/// SSG side (spec §7): Encodable-only rows; a single non-encodable slot drops
/// the WHOLE row (partial rows would desync Mirror order on restore).
public func _encodeSnapshotRows(_ encode: SnapshotEncode) -> [String: [String]] {
    var out: [String: [String]] = [:]
    outer: for (id, boxes) in rows {
        guard let key = id._canonicalString else { continue }
        var slots: [String] = []
        slots.reserveCapacity(boxes.count)
        for box in boxes {
            guard let enc = box as? _SnapshotEncodableBox,
                  let json = enc._encodeJSON(encode) else { continue outer }
            slots.append(json)
        }
        out[key] = slots
    }
    return out
}
```

- [ ] **Step 5: tests** — append to `StateStoreTests.swift`. Test encode/decode round-trip WITHOUT Foundation by using hand-rolled Int/String coders in the test (the test target may import Foundation, but keeping the hooks trivial pins the contract, not a coder):

```swift
import Foundation   // test target only — hooks live here, not in the core

private let jsonEncode: SnapshotEncode = { v in
    struct AnyEncodable: Encodable {                 // slot convention: single-element array
        let base: any Encodable
        func encode(to encoder: Encoder) throws { try base.encode(to: encoder) }
    }
    guard let data = try? JSONEncoder().encode([AnyEncodable(base: v)]) else { return nil }
    return String(decoding: data, as: UTF8.self)
}
private let jsonDecode: SnapshotDecode = { json, type in
    func open<T: Decodable>(_ t: T.Type) -> (any Decodable)? {
        (try? JSONDecoder().decode([T].self, from: Data(json.utf8)))?.first
    }
    return _openExistential(type, do: open)
}

private struct SnapFixture: Tag {
    @State var count = 0
    @State var label = "initial"
    var body: some Tag { Div { Text("\(label):\(count)") } }
}

@Test func snapshotRoundTripRestoresState() {
    // 1. Mutate state via a live runtime, encode.
    let backend = MockBackend()
    let sched = TestScheduler()
    let r1 = Runtime(backend: backend, container: backend.container,
                     root: SnapFixture(), scheduleMicrotask: sched.schedule)
    r1.mount()
    // Reach in through the store: mutate by clicking is overkill — use the
    // encode of the INITIAL row, then hand-edit the fragment to prove decode wins.
    let rows = r1._store._encodeSnapshotRows(jsonEncode)
    #expect(rows.count == 1)
    let key = rows.keys.first!
    #expect(rows[key] == ["[0]", "[\"initial\"]"])

    // 2. Boot a second runtime seeded with edited values.
    let backend2 = MockBackend()
    let store2Runtime = Runtime(backend: backend2, container: backend2.container,
                                root: SnapFixture(), scheduleMicrotask: { _ in })
    store2Runtime._store._pendingRows = [key: ["[42]", "[\"restored\"]"]]
    store2Runtime._store._decodeSlot = jsonDecode
    store2Runtime.mount()
    #expect(backend2.serializeHTML().contains("restored:42"))
}

@Test func snapshotSlotCountMismatchFallsBackToInitial() {
    // Key discovery: mount a probe, take its encoded row key.
    let backendP = MockBackend()
    let probe = Runtime(backend: backendP, container: backendP.container,
                        root: SnapFixture(), scheduleMicrotask: { _ in })
    probe.mount()
    let key = probe._store._encodeSnapshotRows(jsonEncode).keys.first!

    let backend2 = MockBackend()
    let r = Runtime(backend: backend2, container: backend2.container,
                    root: SnapFixture(), scheduleMicrotask: { _ in })
    r._store._pendingRows = [key: ["[42]"]]                  // 1 slot, fixture has 2
    r._store._decodeSlot = jsonDecode
    r.mount()
    #expect(backend2.serializeHTML().contains("initial:0"))  // fell back
    #expect(r._store._pendingRows.isEmpty)                   // consumed even on failure
}

@Test func nonEncodableSlotDropsWholeRow() {
    final class Opaque {}                                     // not Encodable
    struct MixedFixture: Tag {
        @State var n = 1
        @State var o = Opaque()
        var body: some Tag { Div { Text("\(n)") } }
    }
    let backend = MockBackend()
    let r = Runtime(backend: backend, container: backend.container,
                    root: MixedFixture(), scheduleMicrotask: { _ in })
    r.mount()
    #expect(r._store._encodeSnapshotRows(jsonEncode).isEmpty)   // whole row dropped
}
```

NOTE for the implementer: `_openExistential` usage above is the standard trick to open `any Decodable.Type`; if the toolchain rejects the exact spelling, use the equivalent `func open<T: Decodable>(_: T.Type)` + `open(type)` via a protocol-extension trampoline. The CONTRACT (single-element-array fragments, count-mismatch fallback, whole-row drop) is what the tests must pin.

- [ ] **Step 6: run `swift test`**, expected all pass.

- [ ] **Step 7: commit**

```bash
git add -A
git commit -m "feat(state): snapshot seams — pending rows, decode-on-link, Encodable row walk (spec §7)"
```

---

### Task 8: Backend read API + AdoptingBackend

**Files:**
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (4 read methods)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (implement them)
- Create: `Sources/SwiftWUI/Render/AdoptingBackend.swift`
- Test: `Tests/SwiftWUITests/AdoptionTests.swift` (new file)

**Interfaces:**
- Consumes: `RendererBackend`, `MockBackend`/`MockNode`, `TreeApplier` mount order (pre-order: createElement/createTextNode → attrs/props/listeners → insert → children).
- Produces:
  - `RendererBackend` gains (spec §10): `func childCount(of node: HostNode) -> Int`, `func child(of node: HostNode, at index: Int) -> HostNode`, `func tagName(of node: HostNode) -> String?` (nil for text), `func textContent(of node: HostNode) -> String`.
  - `public final class AdoptingBackend<Base: RendererBackend>: RendererBackend where Base.HostNode: AnyObject` with `init(base: Base, container: Base.HostNode)`, `private(set) var failed: Bool`, `func finishAdoption() -> Bool`.
- **WASM BREAKS HERE** (DOMBackend lacks the methods) until Task 13 — expected per Global Constraints.

- [ ] **Step 1: protocol methods** — append to `RendererBackend` after `setMetaTags`:

```swift
    // MARK: Hydration read API (phase 5, spec §10)
    /// Minimal DOM reads for the adopting walk. Text nodes count as children.
    func childCount(of node: HostNode) -> Int
    func child(of node: HostNode, at index: Int) -> HostNode
    /// Lowercased element tag name; nil for text nodes.
    func tagName(of node: HostNode) -> String?
    func textContent(of node: HostNode) -> String
```

- [ ] **Step 2: MockBackend impls** (no count bumps — reads aren't churn):

```swift
    public func childCount(of node: MockNode) -> Int { node.children.count }
    public func child(of node: MockNode, at index: Int) -> MockNode { node.children[index] }
    public func tagName(of node: MockNode) -> String? { node.tag }
    public func textContent(of node: MockNode) -> String { node.text ?? "" }
```

- [ ] **Step 3: AdoptingBackend** — full file:

```swift
/// Hydration backend (spec §8, D2/D6): while adoption is active,
/// createElement/createTextNode return the NEXT node of a pre-order walk over
/// `container`'s existing subtree instead of creating; insert() verifies the
/// adopted child already sits under the expected parent. TreeApplier's mount
/// emits creates in exactly pre-order (parent created+inserted before its
/// children), so a T8-conforming document adopts 1:1.
///
/// First divergence sets `failed` and flips to passthrough creation so the
/// mount completes structurally; the CALLER must then discard everything and
/// cold-mount (clear container + fresh Runtime) — never repair in place.
///
/// Write calls (setAttribute/setProperty/setEventListener/setText) always
/// delegate: values are byte-identical to the prerender (T8), so they're
/// idempotent, and listener attachment is precisely what hydration must do.
@MainActor
public final class AdoptingBackend<Base: RendererBackend>: RendererBackend
where Base.HostNode: AnyObject {
    public typealias HostNode = Base.HostNode
    public let base: Base
    public private(set) var failed = false
    private var active = true
    /// Pre-order stream over the container's ORIGINAL subtree (container excluded).
    private var stream: [HostNode] = []
    private var cursor = 0
    /// ObjectIdentifier(child wrapper) → ObjectIdentifier(parent wrapper).
    /// Safe even for JSObject: we only ever key the wrapper instances WE
    /// handed out (stream entries + container) — never re-read wrappers.
    private var parentOf: [ObjectIdentifier: ObjectIdentifier] = [:]
    private let containerID: ObjectIdentifier
    /// D6 wants debug-loud mismatches, but the fallback path itself must be
    /// testable in debug — tests that exercise deliberate mismatches set false.
    public var _assertOnMismatch = true

    public init(base: Base, container: HostNode) {
        self.base = base
        buildStream(of: container)
        // PLAN AMENDMENT (Task-8 review I1): an empty container is a cold
        // mount, not a mismatch — deactivate instead of arming a false fail
        // (Task 13's fallback re-wraps a cleared container and must not trap).
        active = !stream.isEmpty
    }
    private func buildStream(of node: HostNode) {
        for i in 0..<base.childCount(of: node) {
            let c = base.child(of: node, at: i)
            stream.append(c)
            parentOf[ObjectIdentifier(c)] = ObjectIdentifier(node)
            // textarea's serialized value is child TEXT in HTML but a `value`
            // PROPERTY in the VDOM — skip its subtree (spec §8 / textarea rule).
            if base.tagName(of: c) == "textarea" { continue }
            buildStream(of: c)
        }
    }

    private func fail() {
        if !failed {
            failed = true
            if _assertOnMismatch {
                assertionFailure("SwiftWUI hydration mismatch at stream index \(cursor)/\(stream.count)")
            }
        }
        active = false
    }
    private func nextAdopted(expectTag: String?) -> HostNode? {
        guard cursor < stream.count else { fail(); return nil }
        let candidate = stream[cursor]
        let actual = base.tagName(of: candidate)
        // Tag names compare lowercased: DOM tagName is uppercase, our
        // serializer emits lowercase; MockBackend stores lowercase.
        guard actual?.lowercased() == expectTag?.lowercased() else { fail(); return nil }
        cursor += 1
        return candidate
    }

    /// True when every prerendered node was claimed and nothing diverged.
    /// Always deactivates adoption — subsequent calls create for real.
    public func finishAdoption() -> Bool {
        let ok = !failed && cursor == stream.count
        if !ok && !failed { fail() }     // leftover nodes = mismatch (spec §8)
        active = false
        return ok
    }

    // MARK: creates (adopt while active)
    public func createElement(_ tag: String) -> HostNode {
        if active, let n = nextAdopted(expectTag: tag) { return n }
        return base.createElement(tag)
    }
    public func createTextNode(_ text: String) -> HostNode {
        // No byte comparison of text (browser entity/whitespace view) — but
        // TreeApplier.mount never calls setText on fresh text nodes, so the
        // adopted node self-heals here (idempotent under T8, corrective
        // otherwise). PLAN AMENDMENT (Task-8 review I2).
        if active, let n = nextAdopted(expectTag: nil) {
            base.setText(n, text)
            return n
        }
        return base.createTextNode(text)
    }
    public func insert(_ child: HostNode, into parent: HostNode, before anchor: HostNode?) {
        if active {
            // Adopted child must already sit under this parent; adopted parent
            // wrappers and the container are the only legal parents mid-adoption.
            if parentOf[ObjectIdentifier(child)] == ObjectIdentifier(parent) { return }  // no-op: already in place
            fail()
            // fall through: base.insert makes the (doomed) tree structurally sound
        }
        base.insert(child, into: parent, before: anchor)
    }

    // MARK: passthrough
    public func setText(_ node: HostNode, _ text: String) { base.setText(node, text) }
    public func setAttribute(_ node: HostNode, name: String, value: String) { base.setAttribute(node, name: name, value: value) }
    public func removeAttribute(_ node: HostNode, name: String) { base.removeAttribute(node, name: name) }
    public func setProperty(_ node: HostNode, name: String, value: PropertyValue) { base.setProperty(node, name: name, value: value) }
    public func setEventListener(_ node: HostNode, event: String, id: ListenerID) { base.setEventListener(node, event: event, id: id) }
    public func removeEventListener(_ node: HostNode, event: String) { base.removeEventListener(node, event: event) }
    public func remove(_ child: HostNode, from parent: HostNode) { base.remove(child, from: parent) }
    public func setStylesheet(_ text: String) { base.setStylesheet(text) }
    public func pushState(path: String) { base.pushState(path: path) }
    public func replaceState(path: String) { base.replaceState(path: path) }
    public func historyBack() { base.historyBack() }
    public func setTitle(_ title: String) { base.setTitle(title) }
    public func setMetaTags(_ tags: [MetaTag]) { base.setMetaTags(tags) }
    public func childCount(of node: HostNode) -> Int { base.childCount(of: node) }
    public func child(of node: HostNode, at index: Int) -> HostNode { base.child(of: node, at: index) }
    public func tagName(of node: HostNode) -> String? { base.tagName(of: node) }
    public func textContent(of node: HostNode) -> String { base.textContent(of: node) }
}
```

(D6 posture: debug-loud via `_assertOnMismatch` default-true, release-silent; hydration wiring in Task 13 keeps the default.)

- [ ] **Step 4: tests** — new `Tests/SwiftWUITests/AdoptionTests.swift`. Build the "prerendered DOM" by hand as MockNodes, then hydrate a matching fixture over it:

```swift
import Testing
@testable import SwiftWUI

private struct HydroFixture: Tag {
    @State var count = 0
    var body: some Tag {
        Div(class: "box") {
            H1("Count: \(count)")
            Button("+") { count += 1 }
        }
    }
}

/// The MockNode tree a T8-conforming prerender of HydroFixture(count: 0) parses to.
@MainActor private func prerenderedTree(into backend: MockBackend) {
    let div = MockNode(); div.tag = "div"; div.attrs = ["class": "box"]
    let h1 = MockNode(); h1.tag = "h1"
    let h1t = MockNode(); h1t.text = "Count: 0"
    let btn = MockNode(); btn.tag = "button"; btn.attrs = ["type": "button"]
    let btnt = MockNode(); btnt.text = "+"
    h1.children = [h1t]; h1t.parent = h1
    btn.children = [btnt]; btnt.parent = btn
    div.children = [h1, btn]; h1.parent = div; btn.parent = div
    backend.container.children = [div]; div.parent = backend.container
}

@Suite @MainActor struct AdoptionTests {
    @Test func adoptionClaimsEveryNodeWithZeroCreates() {
        let base = MockBackend()
        prerenderedTree(into: base)
        let adopting = AdoptingBackend(base: base, container: base.container)
        let sched = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: HydroFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(adopting.finishAdoption())
        #expect(base.counts["createElement"] == nil)      // nothing created
        #expect(base.counts["createTextNode"] == nil)
        #expect((base.counts["setEventListener"] ?? 0) >= 1)   // listeners attached
        // The adopted tree is LIVE: click through it.
        clickFirst(base, runtime, tag: "button", sched: sched)
        #expect(base.serializeHTML().contains("Count: 1"))
    }

    @Test func tagMismatchFailsAndFallbackRebuildIsCorrect() {
        let base = MockBackend()
        prerenderedTree(into: base)
        findFirst(base.container, tag: "h1")!.tag = "h2"      // tamper
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting._assertOnMismatch = false
        let sched = TestScheduler()
        var runtime = Runtime(backend: adopting, container: base.container,
                              root: HydroFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(!adopting.finishAdoption())
        // Cold-rebuild path (what DOMRuntime does on failure, spec D6):
        for c in base.container.children { base.remove(c, from: base.container) }
        let fresh = MockBackend()  // fallback uses a plain backend
        _ = fresh
        runtime = Runtime(backend: AdoptingBackend(base: base, container: base.container),
                          container: base.container, root: HydroFixture(),
                          scheduleMicrotask: sched.schedule)
        // Empty container → empty stream → adoption trivially finishes; creates are real.
        runtime.mount()
        #expect(base.serializeHTML() ==
            "<div class=\"box\"><h1>Count: 0</h1><button type=\"button\">+</button></div>")
    }

    @Test func leftoverNodesFailAdoption() {
        let base = MockBackend()
        prerenderedTree(into: base)
        let extra = MockNode(); extra.tag = "p"
        base.container.children.append(extra); extra.parent = base.container
        let adopting = AdoptingBackend(base: base, container: base.container)
        adopting._assertOnMismatch = false
        let sched = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: HydroFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(!adopting.finishAdoption())
    }

    @Test func textareaSubtreeIsSkipped() {
        // Prerender serializes textarea value as child text; VDOM has no such
        // child — the walk must swallow it (spec §8).
        struct TAFixture: Tag {
            @State var text = "seed"
            var body: some Tag { Div { Textarea(text: $text) } }
        }
        let base = MockBackend()
        let div = MockNode(); div.tag = "div"
        let ta = MockNode(); ta.tag = "textarea"
        let tat = MockNode(); tat.text = "seed"
        ta.children = [tat]; tat.parent = ta
        div.children = [ta]; ta.parent = div
        base.container.children = [div]; div.parent = base.container
        let adopting = AdoptingBackend(base: base, container: base.container)
        let sched = TestScheduler()
        let runtime = Runtime(backend: adopting, container: base.container,
                              root: TAFixture(), scheduleMicrotask: sched.schedule)
        runtime.mount()
        #expect(adopting.finishAdoption())
        _ = runtime
    }
}
```

- [ ] **Step 5: run `swift test`** — expected all pass. (Wasm now does not compile — expected until Task 13.)

- [ ] **Step 6: commit**

```bash
git add -A
git commit -m "feat(render): backend read API + AdoptingBackend hydration walk (spec §8, §10)"
```

---

### Task 9: Runtime SPI — SSG driver hooks & route collection

**Files:**
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (SPI accessors, collect pass)
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (`collectedRoutes` field)
- Modify: `Sources/SwiftWUI/Routing/Router.swift` (report patterns)
- Modify: `Sources/SwiftWUI/Routing/RoutePattern.swift` (public surface)
- Test: `Tests/SwiftWUITests/RouterTests.swift` (append)

**Interfaces:**
- Consumes: `ResolveContext`, `Router._resolve`, existing test hooks (`_store`, `_current`, `_registryText`).
- Produces (underscore-public SPI, spec §5 — consumed by SwiftWUIStatic/SwiftWUIDOM):
  - `Runtime._currentTree: Node?`, `Runtime._pageHead: PageHead?`, `Runtime._locationPath: String`, `Runtime._effects: EffectStore` (if Task 6 didn't add it), `Runtime._store` (exists, keep).
  - `Runtime._collectRoutes() -> [RoutePattern]` — side-effect-free w.r.t. the runtime's own store/listeners (throwaway context).
  - `RoutePattern` becomes `public` (type, `raw`, `match(_:)`, `init(_:)`, and `var isStatic: Bool`); `Segment` stays internal.
  - `RouteURL` becomes `public enum` with ONE underscore-public method: `public static func _normalize(_ path: String) -> String { normalizePath(path) }` (all other members stay internal) — needed by SwiftWUIStatic (output dirs, redirect compare) and SwiftWUIDOM (snapshot path compare vs `location.pathname` trailing-slash variants).

- [ ] **Step 1: RoutePattern public surface** — mark `public struct RoutePattern`, `public let raw`, `public init(_ raw: String)`, `public func match(_ path: String) -> [String: String]?`, and add:

```swift
    /// No :param / catch-all — auto-enumerable by SSG (spec D3).
    public var isStatic: Bool {
        segments.allSatisfy { if case .literal = $0 { return true } else { return false } }
    }
```

- [ ] **Step 2: collect flag** — in `ResolveContext` add `var collectedRoutes: [RoutePattern]? = nil`. In `Router._resolve`, first line after the router-count assert:

```swift
ctx.collectedRoutes?.append(contentsOf: routes.map(\.pattern))
```

- [ ] **Step 3: Runtime SPI** — next to the existing test hooks:

```swift
    // SSG/hydration SPI (spec §5): stable underscore-public surface for
    // SwiftWUIStatic and SwiftWUIDOM. Not API.
    public var _currentTree: Node? { current }
    public var _pageHead: PageHead? { lastPageHead }
    public var _locationPath: String { currentPath }
    public var _effects: EffectStore { effects }     // skip if Task 6 already added it
    public var _styleRegistryText: String { styleRegistry.text }

    /// One throwaway resolve with route collection on. Uses a FRESH store and
    /// listener registry. Guards DO run (they run on any resolve);
    /// redirects/pageHead of this pass are discarded.
    /// PLAN AMENDMENT (Task-9 review C1): resolve() must SKIP StateStore.link
    /// during a collect pass (`if ctx.collectedRoutes == nil { ctx.store.link(…) }`)
    /// — component struct copies share Slot objects with the live tree, so
    /// linking against the throwaway store rebinds live boxes' invalidate to
    /// the no-op and injects the throwaway environment into live slots
    /// (frozen root UI). Collect passes resolve bodies with struct-initial
    /// values; @Environment-conditional trees see defaults — acceptable for
    /// pattern enumeration.
    public func _collectRoutes() -> [RoutePattern] {
        var ctx = ResolveContext(store: StateStore(), listeners: ListenerRegistry(),
                                 invalidate: { _ in })
        ctx.collectedRoutes = []
        ctx.environment.routeInfo = RouteInfo(path: currentPath, query: currentQuery)
        passCounter += 1; ctx.pass = passCounter
        _ = resolve(rootTag, path: .root, ctx: &ctx)
        return ctx.collectedRoutes ?? []
    }
```

(`_store` and `_registryText` already exist — do NOT redeclare; `_styleRegistryText` above duplicates `_registryText` — use the existing `_registryText`, make it `public`, and skip the new name.)

- [ ] **Step 4: tests** — append to `RouterTests.swift` (follow the file's fixture style):

```swift
@Test func collectRoutesReportsAllPatterns() {
    struct CollectApp: Tag {
        var body: some Tag {
            Router {
                Route("/") { Text("home") }
                Route("/about") { Text("about") }
                Route("/todo/:id") { _ in Text("todo") }
            }
        }
    }
    let backend = MockBackend()
    let runtime = Runtime(backend: backend, container: backend.container,
                          root: CollectApp(), scheduleMicrotask: { _ in })
    runtime.mount()
    let patterns = runtime._collectRoutes()
    #expect(patterns.map(\.raw) == ["/", "/about", "/todo/:id"])
    #expect(patterns.map(\.isStatic) == [true, true, false])
    // Collection must not disturb live state:
    #expect(runtime._currentTree != nil)
}
```

(Adapt the `Route` initializer spellings to the real ones in `Route.swift` — the param-taking variant receives `[String: String]`.)

- [ ] **Step 5: run `swift test`**, expected all pass.

- [ ] **Step 6: commit**

```bash
git add -A
git commit -m "feat(runtime): SSG SPI accessors + route-collection pass (spec §5, D3)"
```

---

### Task 10: SwiftWUIStatic module — DocumentSerializer + snapshot JSON

**Files:**
- Modify: `Package.swift` (new target + product + test dep)
- Create: `Sources/SwiftWUIStatic/DocumentSerializer.swift`
- Create: `Sources/SwiftWUIStatic/SnapshotJSON.swift`
- Test: `Tests/SwiftWUITests/DocumentSerializerTests.swift` (new file)

**Interfaces:**
- Consumes: `PageHead`/`MetaTag`, `HTMLEscaping`, `SnapshotEncode` slot convention (Task 7), `_AttributeBag.isValidName` (meta names are pre-validated by `MetaTag`).
- Produces:
  - `public enum DocumentSerializer { static func render(_ input: Input) -> String }` with `public struct Input`.
  - `enum SnapshotJSON { static func assemble(version:path:rows:tasks:) -> String; static let encodeSlot: SnapshotEncode; static func jsonString(_ s: String) -> String }`.

- [ ] **Step 1: Package.swift** — add the target (native-only consumers guard themselves; the root package builds it natively, example wasm builds never depend on it):

```swift
products: [
    .library(name: "SwiftWUI", targets: ["SwiftWUI"]),
    .library(name: "SwiftWUIDOM", targets: ["SwiftWUIDOM"]),
    .library(name: "SwiftWUIStatic", targets: ["SwiftWUIStatic"]),
],
…
targets: [
    .target(name: "SwiftWUI", swiftSettings: [.defaultIsolation(MainActor.self)]),
    .target(name: "SwiftWUIStatic", dependencies: ["SwiftWUI"],
            swiftSettings: [.defaultIsolation(MainActor.self)]),
    .target(name: "SwiftWUIDOM", dependencies: [ /* unchanged */ ]),
    .testTarget(name: "SwiftWUITests", dependencies: ["SwiftWUI", "SwiftWUIStatic"],
                swiftSettings: [.defaultIsolation(MainActor.self)]),
]
```

- [ ] **Step 2: SnapshotJSON.swift:**

```swift
import Foundation
import SwiftWUI

/// Snapshot payload assembly (spec §7, D7). Slot fragments follow the Task-7
/// convention: single-element JSON arrays. JSONEncoder escapes "/" as "\/"
/// by default — that is our </script> breakout defense; jsonString() below
/// does the same for hand-assembled keys. Deterministic: keys sorted.
enum SnapshotJSON {
    /// Encodes one @State value as "[<value>]".
    static let encodeSlot: SnapshotEncode = { value in
        struct Box: Encodable {
            let base: any Encodable
            func encode(to encoder: Encoder) throws {
                var c = encoder.unkeyedContainer()
                try c.encode(AnyEnc(base: base))
            }
        }
        struct AnyEnc: Encodable {
            let base: any Encodable
            func encode(to encoder: Encoder) throws { try base.encode(to: encoder) }
        }
        guard let data = try? JSONEncoder().encode(Box(base: value)) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// JSON string literal with "/" escaped (breakout defense for keys/paths).
    static func jsonString(_ s: String) -> String {
        var out = "\""
        for ch in s.unicodeScalars {
            switch ch {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "/":  out += "\\/"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case let c where c.value < 0x20:
                out += String(format: "\\u%04x", c.value)
            default:   out.unicodeScalars.append(ch)
            }
        }
        return out + "\""
    }

    /// Hand-assembled because row values are pre-encoded fragments — running
    /// them through JSONEncoder again would double-encode.
    static func assemble(version: Int, path: String,
                         rows: [String: [String]], tasks: [String]) -> String {
        var out = "{\"v\":\(version),\"path\":\(jsonString(path)),\"rows\":{"
        out += rows.keys.sorted().map { key in
            jsonString(key) + ":[" + rows[key]!.map { $0 }.joined(separator: ",") + "]"
        }.joined(separator: ",")
        out += "},\"tasks\":["
        out += tasks.sorted().map(jsonString).joined(separator: ",")
        out += "]}"
        return out
    }
}
```

- [ ] **Step 3: DocumentSerializer.swift:**

```swift
import SwiftWUI

/// Full-page assembly (spec §9). Pure string building; every dynamic value
/// flows through HTMLEscaping. <title> is RCDATA — entity escaping is correct
/// there. The snapshot <script> is RAW TEXT: no HTML escaping (entities are
/// NOT decoded in scripts); breakout is prevented at the JSON level ("\/").
public enum DocumentSerializer {
    public struct Input {
        public var bodyHTML: String
        public var css: String?              // inline <style> (default path)
        public var cssHref: String?          // <link rel="stylesheet"> instead
        public var head: PageHead?
        public var snapshotJSON: String?     // hydrate mode only
        public var wasmScriptPath: String?   // hydrate mode only
        public var lang: String
        public init(bodyHTML: String, css: String? = nil, cssHref: String? = nil,
                    head: PageHead? = nil, snapshotJSON: String? = nil,
                    wasmScriptPath: String? = nil, lang: String = "en") {
            self.bodyHTML = bodyHTML; self.css = css; self.cssHref = cssHref
            self.head = head; self.snapshotJSON = snapshotJSON
            self.wasmScriptPath = wasmScriptPath; self.lang = lang
        }
    }

    public static func render(_ input: Input) -> String {
        var out = "<!doctype html>\n<html lang=\"" + HTMLEscaping.text(input.lang) + "\">\n<head>\n"
        out += "<meta charset=\"utf-8\">\n"
        let metas = input.head?.meta ?? []
        let hasViewport = metas.contains { $0.attributes["name"] == "viewport" }
        if !hasViewport {
            out += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" data-swiftwui>\n"
        }
        out += "<title>" + HTMLEscaping.text(input.head?.title ?? "") + "</title>\n"
        for meta in metas {
            out += "<meta"
            for name in meta.attributes.keys.sorted() {
                out += " \(name)=\"\(HTMLEscaping.text(meta.attributes[name]!))\""
            }
            out += " data-swiftwui>\n"       // managed set marker (phase-4 semantics)
        }
        if let href = input.cssHref {
            out += "<link rel=\"stylesheet\" href=\"" + HTMLEscaping.text(href) + "\">\n"
        } else if let css = input.css, !css.isEmpty {
            // Raw-text context: CSS comes from our own registry (already
            // sanitized at registration — phase-3 sink guards); assert-guard
            // the impossible breakout anyway.
            assert(!css.contains("</style"), "registry CSS must never contain </style")
            out += "<style data-swiftwui>\n" + css + "\n</style>\n"
        }
        if let snapshot = input.snapshotJSON {
            assert(!snapshot.contains("</script"),
                   "snapshot JSON must be breakout-free (\\/ escaping)")
            out += "<script type=\"application/swiftwui-state\" data-swiftwui>" + snapshot + "</script>\n"
        }
        out += "</head>\n<body>\n" + input.bodyHTML + "\n"
        if let src = input.wasmScriptPath {
            out += "<script type=\"module\" src=\"" + HTMLEscaping.text(src) + "\"></script>\n"
        }
        out += "</body>\n</html>\n"
        return out
    }
}
```

- [ ] **Step 4: tests** — new `Tests/SwiftWUITests/DocumentSerializerTests.swift`:

```swift
import Testing
import SwiftWUI
@testable import SwiftWUIStatic

@Suite @MainActor struct DocumentSerializerTests {
    @Test func staticModeGolden() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<h1>Hi</h1>",
            css: ".a{color:red}",
            head: PageHead(title: "T & Co", meta: [.description("d")])))
        #expect(html == """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1" data-swiftwui>
        <title>T &amp; Co</title>
        <meta content="d" name="description" data-swiftwui>
        <style data-swiftwui>
        .a{color:red}
        </style>
        </head>
        <body>
        <h1>Hi</h1>
        </body>
        </html>

        """)
    }
    @Test func hydrateModeIncludesSnapshotAndBootScript() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "<div></div>",
            snapshotJSON: "{\"v\":1}",
            wasmScriptPath: "/app.js"))
        #expect(html.contains("<script type=\"application/swiftwui-state\" data-swiftwui>{\"v\":1}</script>"))
        #expect(html.contains("<script type=\"module\" src=\"/app.js\"></script>"))
    }
    @Test func explicitViewportSuppressesDefault() {
        let html = DocumentSerializer.render(.init(
            bodyHTML: "",
            head: PageHead(title: "t", meta: [.viewport("width=500")])))
        #expect(html.contains("content=\"width=500\""))
        #expect(!html.contains("initial-scale=1"))
    }
    @Test func snapshotSlotEscapesScriptBreakout() {
        // A string state value containing "</script>" must not break out (D7).
        let slot = SnapshotJSON.encodeSlot("</script><script>alert(1)</script>")
        #expect(slot != nil)
        #expect(!slot!.contains("</script"))               // JSONEncoder's \/ escaping
        let doc = SnapshotJSON.assemble(version: 1, path: "/x",
                                        rows: ["c0/tA.B": [slot!]], tasks: ["c0/tA.B"])
        #expect(!doc.contains("</script"))
        #expect(doc.contains("\"v\":1"))
    }
    @Test func assembleIsDeterministic() {
        let a = SnapshotJSON.assemble(version: 1, path: "/", rows: ["b": ["[1]"], "a": ["[2]"]], tasks: ["z", "y"])
        #expect(a == "{\"v\":1,\"path\":\"\\/\",\"rows\":{\"a\":[[2]],\"b\":[[1]]},\"tasks\":[\"y\",\"z\"]}")
    }
}
```

NOTE: verify JSONEncoder's default `/`-escaping with the breakout test above — if the toolchain's swift-foundation does NOT escape by default, post-process `encodeSlot`'s output through a `"</"` → `"<\\/"` replacement and keep the same test green. The test is the contract; the mechanism may adapt.

- [ ] **Step 5: run `swift test`**, expected all pass.

- [ ] **Step 6: commit**

```bash
git add -A
git commit -m "feat(static): SwiftWUIStatic module — DocumentSerializer + snapshot JSON assembly (spec §9, D7, D11)"
```

---

### Task 11: StaticSite.generate driver

**Files:**
- Create: `Sources/SwiftWUIStatic/StaticSite.swift`
- Test: `Tests/SwiftWUITests/StaticSiteTests.swift` (new file)

**Interfaces:**
- Consumes: `Runtime` SPI (Task 9: `_currentTree`, `_pageHead`, `_locationPath`, `_effects`, `_registryText`, `_collectRoutes`, `flush`), `HTMLRenderer.render(nodes:)` — make the internal `static func render(_ nodes: [Node]) -> String` underscore-public (`public static func _render(_ nodes: [Node]) -> String { render(nodes) }`), `StateStore._encodeSnapshotRows` (Task 7), `SnapshotJSON`/`DocumentSerializer` (Task 10), `MockBackend` as the static backend (spec §10), `RoutePattern` (Task 9).
- Produces:

```swift
public enum StaticSiteMode { case hydrate(wasmScriptPath: String), staticOnly }
public struct StaticSiteConfig {
    public var outDir: String
    public var mode: StaticSiteMode
    public var paths: [String]
    public var cssFile: Bool
    public init(outDir: String, mode: StaticSiteMode, paths: [String] = [], cssFile: Bool = false)
}
public enum StaticSiteError: Error, CustomStringConvertible {
    case buildTaskOverflow(page: String, iterations: Int)
    case io(path: String, underlying: String)
}
public struct StaticSiteReport {
    public var pages: [String]                    // generated page paths
    public var redirects: [String: String]        // page → target (stub emitted)
    public var skippedPatterns: [String]          // dynamic patterns with no explicit path
}
public enum StaticSite {
    @MainActor public static func generate<A: App>(_ app: A.Type, config: StaticSiteConfig) async throws -> StaticSiteReport
}
```

- [ ] **Step 1: the driver** — `StaticSite.swift`:

```swift
import Foundation
import SwiftWUI

public enum StaticSite {
    /// Renders one page per enumerated path (spec §5): a fresh native
    /// Runtime<MockBackend> per page — guards, redirects, effects and state
    /// behave exactly as in the browser.
    @MainActor
    public static func generate<A: App>(_ app: A.Type,
                                        config: StaticSiteConfig) async throws -> StaticSiteReport {
        // --- enumerate ---
        let probeBackend = MockBackend()
        let probe = Runtime(backend: probeBackend, container: probeBackend.container,
                            root: A().body, scheduleMicrotask: { $0() },
                            globalStyles: A.globalStyles, themes: A.themes)
        probe.mount()
        let patterns = probe._collectRoutes()
        var pagePaths: [String] = []
        var skipped: [String] = []
        var claimed = Set<String>()
        for pattern in patterns {
            if pattern.isStatic {
                pagePaths.append(pattern.raw)
            } else {
                let matching = config.paths.filter { pattern.match($0) != nil && !claimed.contains($0) }
                if matching.isEmpty {
                    skipped.append(pattern.raw)
                } else {
                    pagePaths.append(contentsOf: matching)
                    claimed.formUnion(matching)          // first-match-wins, like the Router
                }
            }
        }

        // --- render each page ---
        var report = StaticSiteReport(pages: [], redirects: [:], skippedPatterns: skipped)
        // cssFile mode: union at PAGE-TEXT granularity — registry text is not
        // guaranteed line-per-rule (media blocks), so we dedup whole page
        // registries in first-seen order. Overlap duplicates rules, which is
        // harmless (CSS is idempotent) — optimize only if it ever matters.
        var cssUnion: [String] = []
        var cssSeen = Set<String>()
        var documents: [(path: String, html: String)] = []

        for path in pagePaths {
            let (html, css, redirect) = try await renderPage(A.self, path: path, config: config)
            if let redirect {
                report.redirects[path] = redirect
                documents.append((path, redirectStub(to: redirect)))
                continue
            }
            report.pages.append(path)
            if config.cssFile, !css.isEmpty, cssSeen.insert(css).inserted {
                cssUnion.append(css)
            }
            documents.append((path, html))
        }

        // --- write files ---
        let fm = FileManager.default
        for (path, html) in documents {
            let dir = path == "/" ? config.outDir : config.outDir + path
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try html.write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
            } catch {
                throw StaticSiteError.io(path: dir + "/index.html", underlying: "\(error)")
            }
        }
        if config.cssFile {
            let cssPath = config.outDir + "/styles.css"
            do { try cssUnion.joined(separator: "\n").write(toFile: cssPath, atomically: true, encoding: .utf8) }
            catch { throw StaticSiteError.io(path: cssPath, underlying: "\(error)") }
        }
        return report
    }

    /// Meta-refresh stub for guard-redirected pages (spec D4).
    static func redirectStub(to target: String) -> String {
        "<!doctype html>\n<meta http-equiv=\"refresh\" content=\"0; url="
            + HTMLEscaping.text(target) + "\">\n"
    }

    @MainActor
    private static func renderPage<A: App>(_ app: A.Type, path: String,
                                           config: StaticSiteConfig) async throws
        -> (html: String, css: String, redirect: String?) {
        // Immediate-drain scheduler: microtasks run synchronously in order.
        var queue: [() -> Void] = []
        var draining = false
        func pump() {
            guard !draining else { return }
            draining = true
            while !queue.isEmpty { queue.removeFirst()() }
            draining = false
        }
        let backend = MockBackend()
        let runtime = Runtime(backend: backend, container: backend.container,
                              root: A().body, initialPath: path,
                              scheduleMicrotask: { queue.append($0) },
                              globalStyles: A.globalStyles, themes: A.themes)
        runtime._effects._buildMode = true
        runtime.mount()
        pump()                                     // guards/redirect hops settle here

        // Build-task loop (spec §6, D5): cap mirrors the redirect-hop cap.
        var iterations = 0
        while true {
            let pending = runtime._effects._drainBuildTasks()
            if pending.isEmpty { break }
            iterations += 1
            guard iterations <= 10 else {
                throw StaticSiteError.buildTaskOverflow(page: path, iterations: iterations)
            }
            for task in pending {
                await task.action()               // awaited sequentially, MainActor
                runtime._effects._recordBuildCompleted(task.id)
            }
            pump()                                 // state writes → re-render → possibly new tasks
        }

        // Redirect detection: the runtime settled on a different location.
        let settled = runtime._locationPath
        if settled != RouteURL._normalize(path) {
            return ("", "", settled)
        }

        guard case .component(let rootComponent)? = runtime._currentTree else {
            return ("", runtime._registryText, nil)     // empty page (no route matched)
        }
        let body = HTMLRenderer._render(rootComponent.children)
        let css = runtime._registryText
        var snapshot: String? = nil
        if case .hydrate = config.mode {
            let rows = runtime._store._encodeSnapshotRows(SnapshotJSON.encodeSlot)
            snapshot = SnapshotJSON.assemble(version: 1, path: settled, rows: rows,
                                             tasks: runtime._effects._completedBuildKeys)
        }
        var wasmPath: String? = nil
        if case .hydrate(let p) = config.mode { wasmPath = p }
        let doc = DocumentSerializer.render(.init(
            bodyHTML: body,
            css: config.cssFile ? nil : css,
            cssHref: config.cssFile ? "/styles.css" : nil,
            head: runtime._pageHead,
            snapshotJSON: snapshot,
            wasmScriptPath: wasmPath))
        return (doc, css, nil)
    }
}
```

NOTES for the implementer:
- `RouteURL._normalize` is Task 9's SPI export.
- `HTMLEscaping.text` is public (check; if not, export `_text` the same way).
- Query strings in `config.paths` (e.g. `/todo?f=active`): `initialPath` handles them; the OUTPUT path must strip the query for the directory (`/todo?f=active` is not a file path). Split on `?` for the directory decision; documented limitation: query-variant pages are not distinct SSG outputs — generate path-only entries.
- Redirect-target pages: D4 — the stub is emitted for the ORIGINAL path; the target renders only if itself enumerated. No transitive chasing.

- [ ] **Step 2: tests** — new `Tests/SwiftWUITests/StaticSiteTests.swift`:

```swift
import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

private struct SiteApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
            Route("/todo/:id") { params in Text("todo \(params["id"] ?? "?")") }
            Route("/admin", guard: { .redirect("/") }) { Text("secret") }
        }
    }
}
private struct HomePage: Tag, Page {
    var title: String { "Home" }
    var body: some Tag { H1("Welcome") }
}
private struct AboutPage: Tag, Page {
    @State var fact = "loading"
    var title: String { "About" }
    var body: some Tag {
        P { Text(fact) }.staticTask { fact = "prerendered-fact" }
    }
}

@Suite @MainActor struct StaticSiteTests {
    func tempDir() -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-ssg-\(UUID().uuidString)"
        return dir
    }

    @Test func generatesStaticRoutesAndExplicitDynamicPaths() async throws {
        let out = tempDir()
        let report = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly, paths: ["/todo/1", "/todo/2"]))
        #expect(Set(report.pages) == ["/", "/about", "/todo/1", "/todo/2"])
        #expect(report.redirects == ["/admin": "/"])
        #expect(report.skippedPatterns.isEmpty)
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains("<h1>Welcome</h1>"))
        #expect(home.contains("<title>Home</title>"))
        #expect(!home.contains("application/swiftwui-state"))     // staticOnly: no snapshot
        #expect(!home.contains("type=\"module\""))                //             no boot script
        let todo = try String(contentsOfFile: out + "/todo/1/index.html", encoding: .utf8)
        #expect(todo.contains("todo 1"))
        let admin = try String(contentsOfFile: out + "/admin/index.html", encoding: .utf8)
        #expect(admin.contains("http-equiv=\"refresh\""))
        #expect(admin.contains("url=/"))
    }

    @Test func buildTaskResultLandsInHTMLAndSnapshot() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .hydrate(wasmScriptPath: "/app.js")))
        let about = try String(contentsOfFile: out + "/about/index.html", encoding: .utf8)
        #expect(about.contains("prerendered-fact"))               // loader awaited before HTML
        #expect(about.contains("application/swiftwui-state"))
        #expect(about.contains("prerendered-fact\\\"") || about.contains("prerendered-fact"))  // value in snapshot rows
        #expect(about.contains("\"tasks\":["))                    // completed loader recorded
        #expect(about.contains("<script type=\"module\" src=\"/app.js\">"))
    }

    @Test func dynamicPatternWithoutPathsIsSkippedWithWarning() async throws {
        let out = tempDir()
        let report = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly))
        #expect(report.skippedPatterns == ["/todo/:id"])
    }

    @Test func buildTaskOverflowThrows() async {
        struct LoopApp: App {
            init() {}
            var body: some Tag { Router { Route("/") { LoopPage() } } }
        }
        struct LoopPage: Tag {
            @State var n = 0
            var body: some Tag {
                // Every completed loader bumps state → new identity via branch →
                // schedules another loader. Never quiesces.
                Div { Text("\(n)") }
                    .staticTask { n += 1 }
                if n > 0 { Div { Text("child \(n)") }.staticTask { n += 1 } }
            }
        }
        let out = tempDir()
        await #expect(throws: StaticSiteError.self) {
            _ = try await StaticSite.generate(LoopApp.self, config: .init(
                outDir: out, mode: .staticOnly))
        }
    }

    @Test func cssFileModeWritesUnion() async throws {
        let out = tempDir()
        _ = try await StaticSite.generate(SiteApp.self, config: .init(
            outDir: out, mode: .staticOnly, cssFile: true))
        let home = try String(contentsOfFile: out + "/index.html", encoding: .utf8)
        #expect(home.contains("<link rel=\"stylesheet\" href=\"/styles.css\">"))
        #expect(!home.contains("<style data-swiftwui>"))
        #expect(FileManager.default.fileExists(atPath: out + "/styles.css"))
    }
}
```

NOTES: adapt `Route("/admin", guard:)` to the real guard-init spelling in `Route.swift`; adapt the overflow fixture until it genuinely re-schedules (the mechanism: a `.build` task under an identity that appears AFTER the first loader's write — the `if n > 0` branch provides it; `staticTask` under a new identity each iteration may need a `ForEach`/keyed trick — the CONTRACT is that a never-quiescing page throws `buildTaskOverflow`, adjust the fixture as needed).

- [ ] **Step 3: run `swift test`**, expected all pass.

- [ ] **Step 4: commit**

```bash
git add -A
git commit -m "feat(static): StaticSite.generate — enumeration, build-task loop, redirect stubs, css union (spec §5, D3-D5)"
```

---

### Task 12: SSG → parse → hydrate round-trip property

**Files:**
- Create: `Tests/SwiftWUITests/HydrationRoundTripTests.swift` (includes the subset HTML parser as a test helper)

**Interfaces:**
- Consumes: everything from Tasks 5–11. The parser is TEST-ONLY code (never product) and targets OUR serializer's output subset exclusively: lowercase tags, double-quoted attrs, boolean attrs bare, entities `&amp; &lt; &gt; &quot; &#39;`, void set = `HTMLRenderer.voidElements`, textarea child text.
- Produces: `parseHTMLSubset(_ html: String, into backend: MockBackend)` helper + the round-trip property.

- [ ] **Step 1: subset parser** (top of the new test file):

```swift
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic

/// Parses OUR compact serializer output back into MockNodes. Test helper only.
@MainActor
func parseHTMLSubset(_ html: String, into backend: MockBackend) {
    var stack: [MockNode] = [backend.container]
    var i = html.startIndex

    func decodeEntities(_ s: Substring) -> String {
        var out = ""
        var j = s.startIndex
        while j < s.endIndex {
            if s[j] == "&" {
                let rest = s[j...]
                if rest.hasPrefix("&amp;") { out += "&"; j = s.index(j, offsetBy: 5); continue }
                if rest.hasPrefix("&lt;")  { out += "<"; j = s.index(j, offsetBy: 4); continue }
                if rest.hasPrefix("&gt;")  { out += ">"; j = s.index(j, offsetBy: 4); continue }
                if rest.hasPrefix("&quot;") { out += "\""; j = s.index(j, offsetBy: 6); continue }
                if rest.hasPrefix("&#39;") { out += "'"; j = s.index(j, offsetBy: 5); continue }
            }
            out.append(s[j]); j = s.index(after: j)
        }
        return out
    }
    func appendText(_ t: String) {
        guard !t.isEmpty else { return }
        // Coalesce like a browser: adjacent text merges.
        if let last = stack.last!.children.last, last.text != nil {
            last.text! += t
        } else {
            let n = MockNode(); n.text = t; n.parent = stack.last
            stack.last!.children.append(n)
        }
    }

    while i < html.endIndex {
        if html[i] == "<" {
            guard let close = html[i...].firstIndex(of: ">") else { break }
            let inner = html[html.index(after: i)..<close]
            if inner.hasPrefix("/") {
                stack.removeLast()
            } else {
                let n = MockNode()
                var rest = inner
                let nameEnd = rest.firstIndex(where: { $0 == " " }) ?? rest.endIndex
                n.tag = String(rest[..<nameEnd])
                rest = rest[nameEnd...].drop(while: { $0 == " " })
                while !rest.isEmpty {
                    let attrNameEnd = rest.firstIndex(where: { $0 == "=" || $0 == " " }) ?? rest.endIndex
                    let name = String(rest[..<attrNameEnd])
                    if attrNameEnd < rest.endIndex, rest[attrNameEnd] == "=" {
                        let vStart = rest.index(attrNameEnd, offsetBy: 2)   // skip ="
                        let vEnd = rest[vStart...].firstIndex(of: "\"")!
                        n.attrs[name] = decodeEntities(rest[vStart..<vEnd])
                        rest = rest[rest.index(after: vEnd)...].drop(while: { $0 == " " })
                    } else {
                        if !name.isEmpty { n.attrs[name] = "" }             // boolean attr
                        rest = rest[attrNameEnd...].drop(while: { $0 == " " })
                    }
                }
                n.parent = stack.last
                stack.last!.children.append(n)
                if !HTMLRenderer.voidElements.contains(n.tag!) { stack.append(n) }
            }
            i = html.index(after: close)
        } else {
            let next = html[i...].firstIndex(of: "<") ?? html.endIndex
            appendText(decodeEntities(html[i..<next]))
            i = next
        }
    }
}
```

- [ ] **Step 2: the round-trip property** — render a routed, styled, stateful fixture through the SSG body pipeline, parse, hydrate, assert zero creates + live listeners; then a mutation sweep:

```swift
private struct RoundTripApp: App {
    init() {}
    var body: some Tag {
        Router {
            Route("/") { RTPage() }
        }
    }
}
private struct RTPage: Tag, Page {
    @State var n = 0
    @State var note = "seed & <breakout>"
    var title: String { "RT" }
    var body: some Tag {
        Div(class: "rt") {
            H1("n = \(n)")
            P { Text(note) }
            Button("+") { n += 1 }
            Ul { ForEach([1, 2, 3], id: \.self) { i in Li { Text("item \(i)") } } }
        }
    }
}

@Suite @MainActor struct HydrationRoundTripTests {
    /// SSG body → parse → adopt: zero creates, listeners live, then click works.
    @Test func roundTripAdoptsWithZeroCreates() {
        // 1. Prerender via the same path StaticSite uses.
        let ssgBackend = MockBackend()
        let ssg = Runtime(backend: ssgBackend, container: ssgBackend.container,
                          root: RoundTripApp().body, initialPath: "/",
                          scheduleMicrotask: { $0() })
        ssg.mount()
        let bodyHTML = ssgBackend.serializeHTML()

        // 2. Parse into a fresh Mock DOM (the "browser").
        let dom = MockBackend()
        parseHTMLSubset(bodyHTML, into: dom)

        // 3. Hydrate.
        let adopting = AdoptingBackend(base: dom, container: dom.container)
        let sched = TestScheduler()
        let client = Runtime(backend: adopting, container: dom.container,
                             root: RoundTripApp().body, initialPath: "/",
                             scheduleMicrotask: sched.schedule)
        client.mount()
        #expect(adopting.finishAdoption())
        #expect(dom.counts["createElement"] == nil)
        #expect(dom.counts["createTextNode"] == nil)
        #expect(dom.counts["remove"] == nil)

        // 4. The adopted tree is live.
        clickFirst(dom, client, tag: "button", sched: sched)
        #expect(dom.serializeHTML().contains("n = 1"))
    }

    /// Every single-node mutation of the prerendered DOM must fail adoption —
    /// and the fallback cold mount must reproduce the canonical HTML.
    @Test func mutationSweepAlwaysFallsBackCleanly() {
        let ssgBackend = MockBackend()
        let ssg = Runtime(backend: ssgBackend, container: ssgBackend.container,
                          root: RoundTripApp().body, initialPath: "/",
                          scheduleMicrotask: { $0() })
        ssg.mount()
        let canonical = ssgBackend.serializeHTML()

        for mutation in 0..<3 {
            let dom = MockBackend()
            parseHTMLSubset(canonical, into: dom)
            switch mutation {
            case 0: findFirst(dom.container, tag: "h1")!.tag = "h3"          // tag swap
            case 1:                                                          // extra node
                let junk = MockNode(); junk.tag = "p"
                let div = findFirst(dom.container, tag: "div")!
                junk.parent = div; div.children.append(junk)
            default:                                                         // missing node
                let ul = findFirst(dom.container, tag: "ul")!
                ul.children.removeLast()
            }
            let adopting = AdoptingBackend(base: dom, container: dom.container)
            adopting._assertOnMismatch = false
            let sched = TestScheduler()
            let client = Runtime(backend: adopting, container: dom.container,
                                 root: RoundTripApp().body, initialPath: "/",
                                 scheduleMicrotask: sched.schedule)
            client.mount()
            #expect(!adopting.finishAdoption(), "mutation \(mutation) must fail adoption")

            // Fallback: clear + cold mount on the SAME dom backend.
            for c in dom.container.children { dom.remove(c, from: dom.container) }
            let cold = Runtime(backend: dom, container: dom.container,
                               root: RoundTripApp().body, initialPath: "/",
                               scheduleMicrotask: sched.schedule)
            cold.mount()
            #expect(dom.serializeHTML() == canonical, "mutation \(mutation) fallback diverged")
        }
    }
}
```

(Adapt `ForEach([1,2,3], id: \.self)` to the real ForEach spelling in `Core/ForEach.swift` — if only `Identifiable` collections are supported, use the file's existing keyed-fixture idiom.)

- [ ] **Step 3: run `swift test`**, expected all pass.

- [ ] **Step 4: commit**

```bash
git add -A
git commit -m "test(hydration): SSG → parse → adopt round-trip property + mutation fallback sweep"
```

---

### Task 13: Wasm wiring — DOMBackend read API, snapshot boot, DOMRuntime.hydrate

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (4 read methods, ClickEvent decode fields, stylesheet reuse)
- Create: `Sources/SwiftWUIDOM/SnapshotBoot.swift`
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (hydrate path + auto-detect in `App.main`)
- Gate: `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug` (wasm compiles again after Task 8's break)

**Interfaces:**
- Consumes: `AdoptingBackend`, `StateStore._pendingRows`/`_decodeSlot`, `EffectStore._skipBuildTaskKeys`, `SnapshotDecode` slot convention (single-element array).
- Produces: `DOMRuntime.mount(…)` gains automatic hydration: if `script[type="application/swiftwui-state"]` exists in the document, adopt; else classic mount. No public API change for users — `App.main()` just works on both prerendered and empty pages.

- [ ] **Step 1: DOMBackend read API** — match the file's existing JSObject idioms (`.object!`, `?`-chaining — read neighboring methods first):

```swift
    public func childCount(of node: JSObject) -> Int {
        Int(node.childNodes.length.number ?? 0)
    }
    public func child(of node: JSObject, at index: Int) -> JSObject {
        node.childNodes.item(index).object!
    }
    public func tagName(of node: JSObject) -> String? {
        // nodeType 1 = element; DOM tagName is uppercase — normalize.
        guard node.nodeType.number == 1 else { return nil }
        return node.tagName.string?.lowercased()
    }
    public func textContent(of node: JSObject) -> String {
        node.textContent.string ?? ""
    }
```

- [ ] **Step 2: ClickEvent decode fields** — in the backend's click-payload decoder (find the existing `ClickEvent(` construction), add:

```swift
    targetValue: event.target.value.string,
    checked: event.target.checked.boolean
```

- [ ] **Step 3: managed-stylesheet adoption** — in `setStylesheet`, before creating the managed `<style>` element, query `document.querySelector("style[data-swiftwui]")` and reuse it if present (the SSG-inlined stylesheet becomes the managed one — no duplicate rules; text is replaced with identical content on first flush).

- [ ] **Step 4: SnapshotBoot.swift** — parse the script tag and seed:

```swift
import SwiftWUI
#if arch(wasm32)
import JavaScriptKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Reads the SSG snapshot (spec §7): seeds pending rows + the skip set, and
/// installs the JSONDecoder-backed slot decoder (single-element-array
/// convention from Task 7).
@MainActor
enum SnapshotBoot {
    struct Payload: Decodable {
        let v: Int
        let path: String
        let rows: [String: [RawSlot]]
        let tasks: [String]
    }
    /// Captures each slot's raw JSON text so the typed decode can happen later
    /// at link() time when Value is known.
    struct RawSlot: Decodable {
        let raw: String
        init(from decoder: Decoder) throws {
            // Re-encode the arbitrary JSON value to text. Simplest robust route:
            // decode as JSONValue enum and re-serialize.
            let v = try JSONValue(from: decoder)
            raw = "[" + v.serialized + "]"          // restore the single-element-array wrapper
        }
    }
    /// Minimal JSON value tree for slot re-serialization.
    indirect enum JSONValue: Decodable {
        case null, bool(Bool), number(Double), string(String)
        case array([JSONValue]), object([String: JSONValue])
        // …standard Decodable implementation over singleValue/unkeyed/keyed containers…
        var serialized: String { /* standard re-serializer, escapes via SnapshotBoot.jsonString */ }
    }

    static let decodeSlot: SnapshotDecode = { json, type in
        func open<T: Decodable>(_ t: T.Type) -> (any Decodable)? {
            (try? JSONDecoder().decode([T].self, from: Data(json.utf8)))?.first
        }
        return _openExistential(type, do: open)
    }

    /// nil when the page has no snapshot / version mismatch / current location
    /// differs from the snapshot's path (spec §7 — cold boot in those cases).
    static func read(currentPath: String) -> Payload? {
        let document = JSObject.global.document
        let el = document.querySelector("script[type=\"application/swiftwui-state\"]")
        guard let obj = el.object, let text = obj.textContent.string,
              let payload = try? JSONDecoder().decode(Payload.self, from: Data(text.utf8)),
              payload.v == 1,
              // Static servers serve "/about/" with a trailing slash; the
              // snapshot stores the normalized form — compare normalized.
              RouteURL._normalize(payload.path) == RouteURL._normalize(currentPath)
        else { return nil }
        return payload
    }
    static func removeScriptTag() {
        let el = JSObject.global.document.querySelector("script[type=\"application/swiftwui-state\"]")
        _ = el.object?.remove?()
    }
}
#endif
```

IMPLEMENTER NOTE (the two `…standard…` comments above are the ONLY intentionally-elided bodies in this plan — they are 30 lines of fully standard JSON tree Decodable/serializer code with zero project-specific decisions; write them inline): `JSONValue.init(from:)` tries `singleValueContainer` null/Bool/Double/String, then unkeyed array, then keyed `[String: JSONValue]`. `serialized` emits canonical JSON, reusing the same string-escaping rules as `SnapshotJSON.jsonString` (copy that helper in as a private func — `\/` escaping included).

- [ ] **Step 5: DOMRuntime hydrate path** — restructure `mount` (keep the existing signature; hydration auto-detects):

```swift
    public static func mount(_ root: some Tag, selector: String = "body",
                             globalStyles: [Rule] = [], themes: [ThemeDefinition] = []) {
        JavaScriptEventLoop.installGlobalExecutor()
        assertReflectionAlive()
        let document = JSObject.global.document
        let container: JSObject = selector == "body"
            ? document.body.object!
            : document.querySelector(selector).object!
        let location = JSObject.global.location
        let initialPath = (location.pathname.string ?? "/") + (location.search.string ?? "")

        if let payload = SnapshotBoot.read(currentPath: location.pathname.string ?? "/") {
            let adopting = AdoptingBackend(base: makeBackend(), container: container)
            let runtime = makeRuntime(root: root, backend: adopting, container: container,
                                      initialPath: initialPath,
                                      globalStyles: globalStyles, themes: themes)
            runtime._store._pendingRows = payload.rows.mapValues { $0.map(\.raw) }
            runtime._store._decodeSlot = SnapshotBoot.decodeSlot
            runtime._effects._skipBuildTaskKeys = Set(payload.tasks)
            runtime.mount()
            if adopting.finishAdoption() {
                SnapshotBoot.removeScriptTag()
                finishMount(runtime: runtime, backend: adopting, container: container)
                return
            }
            // Mismatch (spec D6): discard everything, cold-boot below.
            while Int(container.childNodes.length.number ?? 0) > 0 {
                _ = container.removeChild?(container.childNodes.item(0))
            }
            retained.removeAll()
        }
        let backend = makeBackend()
        let runtime = makeRuntime(root: root, backend: backend, container: container,
                                  initialPath: initialPath,
                                  globalStyles: globalStyles, themes: themes)
        runtime.mount()
        finishMount(runtime: runtime, backend: backend, container: container)
    }
```

Factor the current body into `makeBackend()` (DOMBackend + DispatchBox wiring), `makeRuntime(…)` (generic over backend), and `finishMount(…)` (dispatch rebind, retained.append, popstate listener, `data-swui-mounted`) so both paths share them. `finishMount` additionally sets `data-swui-hydrated="true"` when the backend is an AdoptingBackend that finished cleanly (browser-test hook). The DispatchBox generic wiring: `box.fn = { [weak runtime] in runtime?.dispatch($0, payload: $1) }` works for both runtime types since `dispatch` is on `Runtime<B>` — keep the box per-mount.

- [ ] **Step 6: wasm gate:**

```bash
cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
```

Expected: builds green (Counter has no snapshot → cold path compiles + runs as before). Then `swift test` from the repo root: all native tests still pass.

- [ ] **Step 7: commit**

```bash
git add -A
git commit -m "feat(wasm): DOM read API, snapshot boot + hydrating DOMRuntime.mount with cold fallback (spec §8, D6)"
```

---

### Task 14: TodoMVC SSG entry + acceptance

**Files:**
- Modify: `Examples/TodoMVC/Package.swift` (SwiftWUIStatic dep with platform condition)
- Modify: `Examples/TodoMVC/Sources/main.swift` (dual entry: wasm mount / native ssg)
- Test: `Tests/SwiftWUITests/TodoAcceptanceTests.swift` (append SSG acceptance)
- Gates: both wasm example builds + native suite

**Interfaces:**
- Consumes: `StaticSite.generate`, the TodoMVC route table (from phase 4).
- Produces: `swift run TodoMVC ssg --out dist/ [--static]` per spec §4/§15.

- [ ] **Step 1: Package.swift dep** — in `Examples/TodoMVC/Package.swift`, add to the executable target's dependencies:

```swift
.product(name: "SwiftWUIStatic", package: "SwiftWUI",
         condition: .when(platforms: [.macOS, .linux])),
```

(The wasm build's platform is `.wasi` → SwiftWUIStatic is never built for it; Foundation-on-wasm risk avoided. Verify the package name spelling matches the existing path-dependency declaration.)

- [ ] **Step 2: dual entry** — the app currently ends with `TodoApp.main()` via `@main`/App conformance. Restructure the entry (keep every component and route unchanged):

```swift
#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: TodoMVC ssg --out <dir> [--static] [--css-file]")
            return
        }
        args.removeFirst()
        var out = "dist"
        var mode = StaticSiteMode.hydrate(wasmScriptPath: "/index.js")
        var cssFile = false
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out": i += 1; out = args[i]
            case "--static": mode = .staticOnly
            case "--css-file": cssFile = true
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(TodoApp.self, config: .init(
            outDir: out, mode: mode,
            paths: ["/todo/1", "/todo/2"],       // explicit dynamic paths (spec D3)
            cssFile: cssFile))
        print("generated \(report.pages.count) pages, \(report.redirects.count) redirects, skipped \(report.skippedPatterns)")
    }
}
#else
@main enum Entry {
    static func main() { TodoApp.main() }
}
#endif
```

(`TodoApp` must lose its own `@main` attribute; check the actual type name in main.swift — the App conformance stays.)

- [ ] **Step 3: a build-time-loaded page** — add to the TodoMVC route table a small About page proving the loader path end-to-end (native `swift run` demo + manual browser check):

```swift
struct AboutPage: Tag, Page {
    @State var buildInfo = "not prerendered"
    var title: String { "About — TodoWUI" }
    var body: some Tag {
        Section(class: "about") {
            H2("About")
            P { Text(buildInfo) }
            Link("/") { Text("Back") }
        }
        .staticTask { buildInfo = "prerendered at build time" }
    }
}
// …in the Router: Route("/about") { AboutPage() }
```

- [ ] **Step 4: acceptance test** — append to `TodoAcceptanceTests.swift` a native SSG acceptance mirroring StaticSiteTests but over the REAL TodoMVC app structure is impossible (it lives in a separate package) — instead extend the SSG acceptance with a TodoMVC-shaped fixture: routes `/`, `/active`, `/completed`, `/todo/:id`, `/about` with a `.staticTask` loader, verifying: all static routes emitted, both explicit todo pages emitted, hydrate output contains snapshot + module script, staticOnly contains neither, about page contains the prerendered string. Reuse the SiteApp pattern from Task 11's tests; assert `report.pages.count == 6`.

- [ ] **Step 5: gates:**

```bash
swift test                                                          # native: all green
cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
cd ../TodoMVC   && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
swift run TodoMVC ssg --out /tmp/todomvc-dist && ls /tmp/todomvc-dist   # native run works
```

Expected: wasm builds green; native run prints the report and `ls` shows `index.html`, `about/`, `active/`, `completed/`, `todo/`.

NOTE: `swift run TodoMVC` runs from `Examples/TodoMVC/`; the last command's cwd matters.

- [ ] **Step 6: commit**

```bash
git add -A
git commit -m "feat(example): TodoMVC dual entry — wasm mount / native ssg with build-time About loader"
```

---

## Final review

After all 14 tasks: dispatch the whole-branch Fable review (same protocol as phases 2–4):
- Diff range: plan-start commit .. HEAD.
- Named risks to trace: (1) adoption stream vs TreeApplier create order on components/ForEach boundaries; (2) snapshot key stability native↔wasm (`String(reflecting:)` divergence would silently cold-boot — acceptable degrade, but verify names match for the example app); (3) `_skipBuildTaskKeys` consumption exactly-once semantics across re-renders; (4) `</script>` breakout defense end-to-end (state value → slot → assemble → serializer assert); (5) css-union rule-order stability; (6) build-task loop termination + cap; (7) DOMRuntime fallback teardown completeness (retained closures, listener registry of the discarded runtime).
- Browser visual check (manual, non-blocking, Vite): hydrated TodoMVC boots with `data-swui-hydrated`, no flash, snapshot script removed, About shows prerendered text pre-wasm; static build navigates as MPA.
- Memory/progress ledger updates per workflow.





