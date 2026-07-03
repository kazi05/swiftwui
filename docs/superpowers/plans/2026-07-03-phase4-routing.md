# Phase 4: Pages & Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SPA routing for SwiftWUI: `Route`/`Router` with v1-parity matching (`:param`, `*`, query, guards+redirect), pushState navigation via `Link` + environment actions, `Page` title/meta application, `@QueryParam` — plus the phase-3 carry list as Task 1.

**Architecture:** Router state (path+query) lives in `Runtime`, delivered through the environment exactly like `setTheme` (spec D1). `Router` is a primitive tag resolving matched content under `.keyed(pattern)` — param-only navigation preserves @State (spec D2). Navigation = `markDirty(.root)` full pass (spec D7). Platform surface (history, title, meta) is five new `RendererBackend` methods (setStylesheet precedent); MockBackend records them, so everything is natively testable. Redirects and head-writes commit post-pass, never re-entrantly (spec D5).

**Tech Stack:** Swift 6.3.3, swift-testing (`@Test`/`#expect`), MockBackend native gate, wasm SDK `swift-6.3.3-RELEASE_wasm` for example builds.

**Spec:** `docs/superpowers/specs/2026-07-03-phase4-routing-design.md` — read it before starting any task.

## Global Constraints

- Branch: `feature/fable-new-vision`. No new SwiftPM targets — routing lands in `Sources/SwiftWUI/Routing/` (new directory, same target) and `SwiftWUIDOM`.
- No new dependencies. No Foundation in `Sources/SwiftWUI` or the wasm examples (percent-decoding is hand-rolled in Task 2).
- Everything `@MainActor` via target default isolation. NEVER add `Sendable`/`@unchecked Sendable`.
- Identity: primitives append segments in `_resolve` only; bag-mutating methods never affect identity.
- Error posture: `assertionFailure`/`assert` in debug + drop/no-op in release. Exception (spec §4): a non-matching URL is a normal runtime condition — debug `print`, never assert.
- Testing workflow (user preference, overrides RED/GREEN stepping): write ALL of a task's code first, run `swift test` ONCE at the end, fix, commit. Every commit message ends with:

  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  ```
- Native gate: `swift test` from repo root. 170 tests pass at plan start; every task leaves the suite green. Per-task counts are estimates — the invariant is ZERO failures.
- Wasm gates: Task 11 `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`; Task 12 the same from `Examples/TodoMVC`. Between Task 4 and Task 11 the wasm target does NOT compile (DOMBackend lacks the new protocol methods) — expected, same as phase 3 Task 5→12.
- Test helpers: `Tests/SwiftWUITests/TestHelpers.swift` holds `typealias Tag = SwiftWUI.Tag`; `TestScheduler`, `findAll`, `findFirst`, `clickFirst` live in `RuntimeE2ETests.swift` (module-internal). Do NOT redeclare any of them.

## File Structure

New (all in the `SwiftWUI` target unless noted):

| File | Responsibility |
|---|---|
| `Sources/SwiftWUI/Routing/RoutePattern.swift` | `RoutePattern` (parse/match) + `RouteURL` (normalize, split, query parse, percent-decode) |
| `Sources/SwiftWUI/Routing/Route.swift` | `Route`, `RouteGuardResult`, `RouteBuilder` |
| `Sources/SwiftWUI/Routing/Page.swift` | `MetaTag`, `Page` protocol, `PageHead` |
| `Sources/SwiftWUI/Routing/RouteEnvironment.swift` | `RouteInfo`, `NavigateAction`, env keys `\.routeInfo` `\.navigate` `\.back` |
| `Sources/SwiftWUI/Routing/Router.swift` | `Router` primitive |
| `Sources/SwiftWUI/Routing/Link.swift` | `Link` |
| `Sources/SwiftWUI/Routing/QueryParam.swift` | `@QueryParam` |

Modified: `Runtime/Runtime.swift` (location state, navigate, injection, post-pass commit), `Runtime/Resolver.swift` (3 ResolveContext fields), `Render/RendererBackend.swift` + `Render/MockBackend.swift` (5 methods), `HTML/EventPayloads.swift` (`ClickEvent`), `HTML/HTMLTag.swift` (internal `onClickEvent`), `SwiftWUIDOM/DOMBackend.swift` + `DOMRuntime.swift` (wasm wiring), `Examples/TodoMVC/Sources/main.swift`, tests.

---

### Task 1: Phase-3 carry-list tests

**Files:**
- Modify: `Tests/SwiftWUITests/HTMLRendererTests.swift` (append)
- Modify: `Tests/SwiftWUITests/ObservationTests.swift` (append)

**Interfaces:**
- Consumes: `MockBackend` (Render/MockBackend.swift), `Runtime`, `TestScheduler` (RuntimeE2ETests.swift:42).
- Produces: tests only.

- [ ] **Step 1: MockBackend textarea child-text golden** (append to HTMLRendererTests.swift):

```swift
@Test @MainActor func mockBackendSerializesTextareaValueAsChildText() {
    let backend = MockBackend()
    let n = backend.createElement("textarea")
    backend.setProperty(n, name: "value", value: .string("a & <b>"))
    backend.insert(n, into: backend.container, before: nil)
    #expect(backend.serializeHTML() == "<textarea>a &amp; &lt;b&gt;</textarea>")
}
```

(Match the file's existing suite isolation — if the enclosing `@Suite` is already `@MainActor`, drop the attribute on the function.)

- [ ] **Step 2: ForEach + row-component double-fire test** (append to ObservationTests.swift; match the file's fixture style):

```swift
@Observable private final class FireModel { var labels = ["a", "b"] }
private final class FireCounter { var rowBodies = 0 }
private struct FireRow: Tag {
    let text: String
    let counter: FireCounter
    var body: some Tag {
        counter.rowBodies += 1
        return Li { text }
    }
}
private struct FireList: Tag {
    let model: FireModel
    let counter: FireCounter
    var body: some Tag {
        Ul { ForEach(model.labels, id: \.self) { l in FireRow(text: l, counter: counter) } }
    }
}
```

```swift
@Test func forEachRowMutationResolvesRowsExactlyOnce() {
    let model = FireModel(); let counter = FireCounter()
    let backend = MockBackend(); let sched = TestScheduler()
    let rt = Runtime(backend: backend, container: backend.container,
                     root: FireList(model: model, counter: counter),
                     scheduleMicrotask: sched.schedule)
    rt.mount()
    let base = counter.rowBodies                       // 2 after mount
    model.labels[0] = "z"                              // tracked by BOTH the body and the per-item closure
    sched.pump()
    #expect(counter.rowBodies == base + 2, "one flush → each row resolves once, not twice")
    #expect(backend.serializeHTML().contains("z"))
}
```

- [ ] **Step 3: Run `swift test`** — expected: all pass (~172).

- [ ] **Step 4: Commit**

```bash
git add Tests/SwiftWUITests/HTMLRendererTests.swift Tests/SwiftWUITests/ObservationTests.swift
git commit -m "test: phase-3 carry list — textarea golden, ForEach double-fire guard"
```

---

### Task 2: RoutePattern + RouteURL

**Files:**
- Create: `Sources/SwiftWUI/Routing/RoutePattern.swift`
- Create: `Tests/SwiftWUITests/RoutePatternTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces (internal): `RoutePattern.init(_ raw: String)`, `RoutePattern.match(_ path: String) -> [String: String]?`, `RoutePattern.raw: String`; `RouteURL.normalizePath(_:) -> String`, `RouteURL.split(_ url: String) -> (path: String, query: [String: String], search: String)`, `RouteURL.parseQuery(_:) -> [String: String]`, `RouteURL.percentDecode(_:) -> String`. Tasks 3, 5, 6 use exactly these.

- [ ] **Step 1: Write `RoutePattern.swift`**

```swift
/// URL helpers (spec §4). No Foundation — percent-decoding is hand-rolled.
enum RouteURL {
    /// Guarantees a leading "/", strips trailing "/" (root untouched): "/x/" → "/x".
    static func normalizePath(_ path: String) -> String {
        var p = path.hasPrefix("/") ? path : "/" + path
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// Path split on "/", empty segments dropped ("//" tolerated).
    static func pathSegments(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    /// "/a/b?x=1&y=2" → (path: "/a/b", query: ["x": "1", "y": "2"], search: "x=1&y=2").
    /// A "#fragment" suffix is dropped (never sent to servers, never routed on).
    static func split(_ url: String) -> (path: String, query: [String: String], search: String) {
        var u = url
        if let hash = u.firstIndex(of: "#") { u = String(u[..<hash]) }
        guard let q = u.firstIndex(of: "?") else { return (u, [:], "") }
        let search = String(u[u.index(after: q)...])
        return (String(u[..<q]), parseQuery(search), search)
    }

    /// Pairs split on "&", each on the FIRST "=", both sides percent-decoded.
    /// "+" is NOT treated as space (that's form encoding, not URLs).
    static func parseQuery(_ search: String) -> [String: String] {
        var out: [String: String] = [:]
        for pair in search.split(separator: "&") {
            guard !pair.isEmpty else { continue }
            if let eq = pair.firstIndex(of: "=") {
                out[percentDecode(String(pair[..<eq]))] =
                    percentDecode(String(pair[pair.index(after: eq)...]))
            } else {
                out[percentDecode(String(pair))] = ""
            }
        }
        return out
    }

    /// %XX UTF-8 decode. An invalid escape leaves the WHOLE input unchanged
    /// (spec §4/§11: never trap, never half-decode).
    static func percentDecode(_ s: String) -> String {
        guard s.contains("%") else { return s }
        func hex(_ b: UInt8) -> UInt8? {
            switch b {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): return b - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): return b - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): return b - UInt8(ascii: "A") + 10
            default: return nil
            }
        }
        let u = Array(s.utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(u.count)
        var i = 0
        while i < u.count {
            if u[i] == UInt8(ascii: "%") {
                guard i + 2 < u.count, let hi = hex(u[i + 1]), let lo = hex(u[i + 2]) else { return s }
                bytes.append(hi << 4 | lo); i += 3
            } else {
                bytes.append(u[i]); i += 1
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Parsed route pattern (spec §4): literal | :param | * (catch-all, last only).
struct RoutePattern: Equatable {
    enum Segment: Equatable {
        case literal(String)
        case param(String)
        case catchAll
    }
    let raw: String
    let segments: [Segment]

    init(_ raw: String) {
        self.raw = raw
        let parts = RouteURL.pathSegments(RouteURL.normalizePath(raw))
        var segs: [Segment] = []
        for (i, part) in parts.enumerated() {
            if part == "*" {
                assert(i == parts.count - 1, "RoutePattern: '*' must be the last segment in '\(raw)'")
                segs.append(.catchAll)
            } else if part.hasPrefix(":") {
                let name = String(part.dropFirst())
                assert(!name.isEmpty, "RoutePattern: empty ':' parameter name in '\(raw)'")
                segs.append(.param(name.isEmpty ? "_" : name))
            } else {
                segs.append(.literal(part))
            }
        }
        self.segments = segs
    }

    /// Captured params (percent-decoded), or nil when the path doesn't match.
    /// A catch-all's tail lands under key "*". Matching is case-sensitive.
    func match(_ path: String) -> [String: String]? {
        let parts = RouteURL.pathSegments(RouteURL.normalizePath(path))
            .map(RouteURL.percentDecode)
        var params: [String: String] = [:]
        var i = 0
        for seg in segments {
            switch seg {
            case .catchAll:
                params["*"] = parts[i...].joined(separator: "/")
                return params
            case .literal(let lit):
                guard i < parts.count, parts[i] == lit else { return nil }
            case .param(let name):
                guard i < parts.count else { return nil }
                params[name] = parts[i]
            }
            i += 1
        }
        return i == parts.count ? params : nil
    }
}
```

- [ ] **Step 2: Write `RoutePatternTests.swift`** (table-driven):

```swift
import Testing
@testable import SwiftWUI

@MainActor @Suite struct RoutePatternTests {
    @Test func staticAndRoot() {
        #expect(RoutePattern("/").match("/") == [:])
        #expect(RoutePattern("/about").match("/about") == [:])
        #expect(RoutePattern("/about").match("/abou") == nil)
        #expect(RoutePattern("/about").match("/about/x") == nil)
        #expect(RoutePattern("/about").match("/About") == nil)          // case-sensitive
        #expect(RoutePattern("/about").match("/about/") == [:])          // trailing slash
        #expect(RoutePattern("/a/b").match("/a//b") == [:])              // empty segments dropped
    }
    @Test func params() {
        #expect(RoutePattern("/todo/:id").match("/todo/42") == ["id": "42"])
        #expect(RoutePattern("/todo/:id").match("/todo") == nil)
        #expect(RoutePattern("/todo/:id").match("/todo/42/x") == nil)
        #expect(RoutePattern("/u/:a/p/:b").match("/u/1/p/2") == ["a": "1", "b": "2"])
        #expect(RoutePattern("/f/:name").match("/f/caf%C3%A9") == ["name": "café"])
        #expect(RoutePattern("/f/:name").match("/f/bad%GG") == ["name": "bad%GG"])  // invalid escape kept raw
    }
    @Test func catchAll() {
        #expect(RoutePattern("/docs/*").match("/docs/a/b") == ["*": "a/b"])
        #expect(RoutePattern("/docs/*").match("/docs") == ["*": ""])
        #expect(RoutePattern("/*").match("/anything/at/all") == ["*": "anything/at/all"])
    }
    @Test func urlSplit() {
        let (p, q, s) = RouteURL.split("/a/b?x=1&y=two%20words&flag")
        #expect(p == "/a/b")
        #expect(q == ["x": "1", "y": "two words", "flag": ""])
        #expect(s == "x=1&y=two%20words&flag")
        #expect(RouteURL.split("/plain").path == "/plain")
        #expect(RouteURL.split("/a?x=1#frag").query == ["x": "1"])       // fragment dropped
        #expect(RouteURL.parseQuery("a=b=c") == ["a": "b=c"])            // first '=' only
        #expect(RouteURL.normalizePath("x/") == "/x")
        #expect(RouteURL.normalizePath("/") == "/")
    }
    @Test func percentDecode() {
        #expect(RouteURL.percentDecode("no-escapes") == "no-escapes")
        #expect(RouteURL.percentDecode("%2Fslash") == "/slash")
        #expect(RouteURL.percentDecode("%E2%9C%93") == "✓")
        #expect(RouteURL.percentDecode("trunc%2") == "trunc%2")          // invalid: whole input unchanged
    }
}
```

- [ ] **Step 3: Run `swift test`** — expected: all pass (~177).

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUI/Routing/RoutePattern.swift Tests/SwiftWUITests/RoutePatternTests.swift
git commit -m "feat(routing): RoutePattern matcher + RouteURL helpers (no-Foundation percent-decode)"
```

---

### Task 3: Route, guards, RouteBuilder

**Files:**
- Create: `Sources/SwiftWUI/Routing/Route.swift`
- Create: `Tests/SwiftWUITests/RouteTests.swift`

**Interfaces:**
- Consumes: `RoutePattern` (Task 2), `AnyTag` (Core/Primitives.swift:64), `TagBuilder`.
- Produces: `RouteGuardResult` (`.allow`/`.redirect(String)`); `Route.init(_:guard:content:)` in two shapes (`() -> C` and `([String: String]) -> C`); `Route.pattern: RoutePattern`, `Route.guardClosure: (() -> RouteGuardResult)?`, `Route.builder: ([String: String]) -> AnyTag`; `@RouteBuilder` producing `[Route]`. Task 6 consumes all of it.

- [ ] **Step 1: Write `Route.swift`**

```swift
/// Outcome of a route guard (spec §5): `.allow` lets the route win the match;
/// `.redirect(path)` skips it and schedules a post-pass `navigate(replace: true)`.
public enum RouteGuardResult {
    case allow
    case redirect(String)
}

/// One URL pattern → content mapping (spec §4–5).
///
/// ```swift
/// Route("/") { HomePage() }
/// Route("/todo/:id") { params in TodoDetail(id: params["id"]!) }
/// Route("/admin", guard: { isAdmin ? .allow : .redirect("/login") }) { AdminPanel() }
/// ```
public struct Route {
    let pattern: RoutePattern
    let guardClosure: (() -> RouteGuardResult)?
    let builder: ([String: String]) -> AnyTag

    /// Route without parameters in the content closure.
    public init<C: Tag>(_ path: String,
                        guard guardClosure: (() -> RouteGuardResult)? = nil,
                        @TagBuilder content: @escaping () -> C) {
        self.pattern = RoutePattern(path)
        self.guardClosure = guardClosure
        self.builder = { _ in AnyTag(content()) }
    }

    /// Route receiving captured `:param` values (catch-all tail under "*").
    public init<C: Tag>(_ path: String,
                        guard guardClosure: (() -> RouteGuardResult)? = nil,
                        @TagBuilder content: @escaping ([String: String]) -> C) {
        self.pattern = RoutePattern(path)
        self.guardClosure = guardClosure
        self.builder = { AnyTag(content($0)) }
    }
}

// Mirrors RulesBuilder (Styles/Rule.swift:50): variadic buildBlock also covers
// the empty block — do NOT add a zero-arg overload (ambiguity).
@resultBuilder
public enum RouteBuilder {
    public static func buildBlock(_ parts: [Route]...) -> [Route] { parts.flatMap { $0 } }
    public static func buildExpression(_ r: Route) -> [Route] { [r] }
    public static func buildOptional(_ r: [Route]?) -> [Route] { r ?? [] }
    public static func buildEither(first: [Route]) -> [Route] { first }
    public static func buildEither(second: [Route]) -> [Route] { second }
    public static func buildArray(_ parts: [[Route]]) -> [Route] { parts.flatMap { $0 } }
}
```

- [ ] **Step 2: Write `RouteTests.swift`**

```swift
import Testing
@testable import SwiftWUI

@MainActor @Suite struct RouteTests {
    @Test func builderShapes() {
        let flag = true
        @RouteBuilder func routes() -> [Route] {
            Route("/") { Text("home") }
            if flag { Route("/a") { Text("a") } }
            for p in ["/x", "/y"] { Route(p) { Text(p) } }
        }
        let r = routes()
        #expect(r.count == 4)
        #expect(r[0].pattern.raw == "/")
        #expect(r[3].pattern.raw == "/y")
    }
    @Test func paramClosureReceivesCaptures() {
        let route = Route("/t/:id") { params in Text(params["id"] ?? "-") }
        let tag = route.builder(["id": "7"])
        #expect((tag.base as? Text)?.content == "7")
    }
    @Test func guardStored() {
        let route = Route("/admin", guard: { .redirect("/login") }) { Text("admin") }
        guard case .redirect(let target)? = route.guardClosure?() else {
            Issue.record("expected redirect"); return
        }
        #expect(target == "/login")
    }
}
```

- [ ] **Step 3: Run `swift test`** — expected: all pass (~180).

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUI/Routing/Route.swift Tests/SwiftWUITests/RouteTests.swift
git commit -m "feat(routing): Route + guards + RouteBuilder"
```

---

### Task 4: Page/MetaTag + backend routing surface

**Files:**
- Create: `Sources/SwiftWUI/Routing/Page.swift`
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (append to protocol)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (append methods)
- Create: `Tests/SwiftWUITests/PageTests.swift`

**Interfaces:**
- Consumes: `_AttributeBag.isValidName` (HTML/AttributeBag.swift:90, static internal).
- Produces: `MetaTag` (Equatable; factories `.charset(_:)`, `.viewport(_:)`, `.description(_:)`, `.named(_:content:)`, `.property(_:content:)`; `attributes: [String: String]`); `protocol Page: Tag { var title: String { get }; var meta: [MetaTag] { get } }` with `meta` defaulted to `[]`; `PageHead` (Equatable, `title` + `meta`); backend methods `pushState(path:)`, `replaceState(path:)`, `historyBack()`, `setTitle(_:)`, `setMetaTags(_:)`; MockBackend recorders `historyStack: [String]`, `replacedStates: [String]`, `backCount: Int`, `title: String?`, `metaTags: [MetaTag]`. Tasks 5–12 consume these.

- [ ] **Step 1: Write `Page.swift`**

```swift
/// A `<meta>` tag description (spec §9). Names are validated against the
/// `_AttributeBag` rules — invalid names assert in debug and are dropped.
public struct MetaTag: Equatable {
    public let attributes: [String: String]
    public init(attributes: [String: String]) {
        var valid: [String: String] = [:]
        for (name, value) in attributes {
            guard _AttributeBag.isValidName(name) else {
                assertionFailure("MetaTag: invalid attribute name '\(name)'")
                continue
            }
            valid[name] = value
        }
        self.attributes = valid
    }
    /// `<meta charset="...">`
    public static func charset(_ value: String) -> MetaTag {
        MetaTag(attributes: ["charset": value])
    }
    /// `<meta name="viewport" content="...">`
    public static func viewport(_ content: String) -> MetaTag {
        MetaTag(attributes: ["name": "viewport", "content": content])
    }
    /// `<meta name="description" content="...">`
    public static func description(_ content: String) -> MetaTag {
        MetaTag(attributes: ["name": "description", "content": content])
    }
    /// `<meta name="..." content="...">`
    public static func named(_ name: String, content: String) -> MetaTag {
        MetaTag(attributes: ["name": name, "content": content])
    }
    /// `<meta property="..." content="...">` (Open Graph)
    public static func property(_ property: String, content: String) -> MetaTag {
        MetaTag(attributes: ["property": property, "content": content])
    }
}

/// Route content that manages the document head (spec §9). Detection is
/// top-level only: the tag returned by the Route builder must itself conform
/// (wrappers like `.padding()` around it hide the conformance — documented).
public protocol Page: Tag {
    /// Browser-tab title, applied on navigation.
    var title: String { get }
    /// Managed `<meta>` set (replaces only tags marked data-swiftwui).
    var meta: [MetaTag] { get }
}
extension Page {
    public var meta: [MetaTag] { [] }
}

/// Head snapshot the Router captures for the matched page; the runtime diffs
/// it against the last applied snapshot post-pass (spec §9).
public struct PageHead: Equatable {
    public var title: String
    public var meta: [MetaTag]
    public init(title: String, meta: [MetaTag]) { self.title = title; self.meta = meta }
}
```

- [ ] **Step 2: Extend `RendererBackend`** (append inside the protocol, after `setStylesheet`):

```swift
    // MARK: Routing (phase 4, spec §3)
    /// History API. Backends without history (Mock) just record.
    func pushState(path: String)
    func replaceState(path: String)
    func historyBack()
    /// document.title.
    func setTitle(_ title: String)
    /// Replaces the document's MANAGED meta set (marked data-swiftwui);
    /// hand-written <meta> in the host HTML is never touched.
    func setMetaTags(_ tags: [MetaTag])
```

- [ ] **Step 3: Implement in `MockBackend`** (append after `setStylesheet`):

```swift
    public private(set) var historyStack: [String] = []
    public private(set) var replacedStates: [String] = []
    public private(set) var backCount = 0
    public private(set) var title: String?
    public private(set) var metaTags: [MetaTag] = []
    public func pushState(path: String) { bump("pushState"); historyStack.append(path) }
    public func replaceState(path: String) { bump("replaceState"); replacedStates.append(path) }
    public func historyBack() { bump("historyBack"); backCount += 1 }
    public func setTitle(_ title: String) { bump("setTitle"); self.title = title }
    public func setMetaTags(_ tags: [MetaTag]) { bump("setMetaTags"); metaTags = tags }
```

- [ ] **Step 4: Write `PageTests.swift`**

```swift
import Testing
@testable import SwiftWUI

@MainActor @Suite struct PageTests {
    @Test func metaFactories() {
        #expect(MetaTag.charset("utf-8").attributes == ["charset": "utf-8"])
        #expect(MetaTag.named("robots", content: "noindex").attributes
                == ["name": "robots", "content": "noindex"])
        #expect(MetaTag.property("og:title", content: "T").attributes
                == ["property": "og:title", "content": "T"])
    }
    @Test func pageMetaDefaultsEmpty() {
        struct P: Page { var title: String { "t" }
                         var body: some Tag { Text("x") } }
        #expect(P().meta.isEmpty)
    }
    @Test func mockBackendRecordsRoutingCalls() {
        let b = MockBackend()
        b.pushState(path: "/a"); b.replaceState(path: "/b"); b.historyBack()
        b.setTitle("T"); b.setMetaTags([.charset("utf-8")])
        #expect(b.historyStack == ["/a"])
        #expect(b.replacedStates == ["/b"])
        #expect(b.backCount == 1)
        #expect(b.title == "T")
        #expect(b.metaTags == [.charset("utf-8")])
    }
}
```

(No invalid-name assertion test — `assertionFailure` aborts debug test runs; the release-drop path is exercised implicitly by construction.)

- [ ] **Step 5: Run `swift test`** — expected: all pass (~183). The native suite is unaffected by DOMBackend (wasm-only, `#if arch(wasm32)`) — it stops compiling for wasm until Task 11, per Global Constraints.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI/Routing/Page.swift Sources/SwiftWUI/Render/RendererBackend.swift \
        Sources/SwiftWUI/Render/MockBackend.swift Tests/SwiftWUITests/PageTests.swift
git commit -m "feat(routing): Page/MetaTag + backend history/head surface"
```

---

### Task 5: Route environment + Runtime navigation core

**Files:**
- Create: `Sources/SwiftWUI/Routing/RouteEnvironment.swift`
- Modify: `Sources/SwiftWUI/Runtime/Resolver.swift` (3 new ResolveContext fields)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (location state, `initialPath:` init param, navigate/handlePopState, env injection, `commitRouteEffects`)
- Create: `Tests/SwiftWUITests/NavigationTests.swift`

**Interfaces:**
- Consumes: `RouteURL` (Task 2), `PageHead` + backend methods (Task 4), `markDirty(.root)` (Runtime.swift:42), env-action injection seam (Runtime.swift:144).
- Produces: `RouteInfo` (`path: String`, `query: [String: String]`, `params: [String: String]`, all defaulted); `NavigateAction` (`callAsFunction(_ path: String, replace: Bool = false)`); env keys `\.routeInfo`, `\.navigate`, `\.back`; `ResolveContext.pendingRedirect: String?`, `.pageHead: PageHead?`, `.routerCount: Int`; `Runtime.init(..., initialPath: String = "/", ...)`, `Runtime.navigate(to:replace:)`, `Runtime.handlePopState(url:)`. Tasks 6–12 consume these.

- [ ] **Step 1: Write `RouteEnvironment.swift`**

```swift
/// Current location, provided by the runtime (spec §7). `params` holds the
/// matched route's captures — written by Router for its subtree; readers
/// outside any Router see [:].
public struct RouteInfo: Equatable {
    public var path: String
    public var query: [String: String]
    public var params: [String: String]
    public init(path: String = "/", query: [String: String] = [:],
                params: [String: String] = [:]) {
        self.path = path; self.query = query; self.params = params
    }
}

/// `navigate("/x")` / `navigate("/x", replace: true)` (spec §7).
public struct NavigateAction {
    let handler: (String, Bool) -> Void
    public init(handler: @escaping (String, Bool) -> Void) { self.handler = handler }
    public func callAsFunction(_ path: String, replace: Bool = false) {
        handler(path, replace)
    }
}

private struct RouteInfoKey: EnvironmentKey {
    static let defaultValue = RouteInfo()
}
private struct NavigateKey: EnvironmentKey {
    static let defaultValue = NavigateAction { _, _ in }
}
private struct BackKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Current path/query/params. Default is "/" with empty dictionaries
    /// (HTMLRenderer, tests without a runtime).
    public var routeInfo: RouteInfo {
        get { self[RouteInfoKey.self] }
        set { self[RouteInfoKey.self] = newValue }
    }
    /// SPA navigation action; no-op default outside a runtime.
    public var navigate: NavigateAction {
        get { self[NavigateKey.self] }
        set { self[NavigateKey.self] = newValue }
    }
    /// history.back(); no-op default outside a runtime.
    public var back: () -> Void {
        get { self[BackKey.self] }
        set { self[BackKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Extend `ResolveContext`** (Resolver.swift, after `var pass: Int = 0`):

```swift
    /// First guard `.redirect` seen this pass; the runtime performs it
    /// POST-pass via navigate(replace: true) — never re-entrantly (spec §5).
    var pendingRedirect: String? = nil
    /// Head snapshot of the matched Page, if any (spec §9).
    var pageHead: PageHead? = nil
    /// Routers resolved this pass — asserted ≤ 1 (spec D9).
    var routerCount = 0
```

- [ ] **Step 3: Extend `Runtime`**

3a. Fields (after `private let globalStyles: [Rule]`):

```swift
    // Routing (spec §7): the runtime owns the current location.
    private var currentPath: String
    private var currentQuery: [String: String]
    private var lastPageHead: PageHead?
    private var redirectHops = 0
```

3b. Init — add the parameter after `root:` and initialize the fields (before `applier =` for definite initialization; order within init body is fine as long as all stored properties are set):

```swift
    public init(backend: Backend, container: Backend.HostNode, root: some Tag,
                initialPath: String = "/",
                scheduleMicrotask: @escaping (@escaping () -> Void) -> Void,
                globalStyles: [Rule] = [], themes: [ThemeDefinition] = []) {
        let (path, query, _) = RouteURL.split(initialPath)
        currentPath = RouteURL.normalizePath(path)
        currentQuery = query
        // … existing body unchanged …
```

3c. Navigation entry points (after `setTheme`):

```swift
    /// SPA navigation (spec §7): update location → pushState/replaceState →
    /// full pass. Same path+query → no-op (prevents self-redirect loops).
    public func navigate(to url: String, replace: Bool = false) {
        let (rawPath, query, search) = RouteURL.split(url)
        let path = RouteURL.normalizePath(rawPath)
        guard path != currentPath || query != currentQuery else { return }
        currentPath = path; currentQuery = query
        let full = search.isEmpty ? path : path + "?" + search
        if replace { applier.backend.replaceState(path: full) }
        else { applier.backend.pushState(path: full) }
        markDirty(.root)
    }

    /// Browser back/forward: the location already changed — no pushState.
    public func handlePopState(url: String) {
        let (rawPath, query, _) = RouteURL.split(url)
        currentPath = RouteURL.normalizePath(rawPath)
        currentQuery = query
        markDirty(.root)
    }
```

3d. Env injection in `renderPass()` (directly after the `ctx.environment.setTheme = …` line):

```swift
        ctx.environment.routeInfo = RouteInfo(path: currentPath, query: currentQuery)
        ctx.environment.navigate = NavigateAction { [weak self] path, replace in
            self?.navigate(to: path, replace: replace)
        }
        ctx.environment.back = { [weak self] in self?.applier.backend.historyBack() }
```

3e. Post-pass commit — add the method, then call it as the LAST line of BOTH `renderPass()` and `subtreePass(_:_:)` (after the effect callbacks loop):

```swift
    /// Applies Router by-products after a pass (spec §5, §9): head writes when
    /// the snapshot changed, then at most one redirect hop (capped at 10).
    private func commitRouteEffects(_ ctx: ResolveContext) {
        if let head = ctx.pageHead, head != lastPageHead {
            lastPageHead = head
            applier.backend.setTitle(head.title)
            applier.backend.setMetaTags(head.meta)
        }
        if let target = ctx.pendingRedirect {
            redirectHops += 1
            guard redirectHops <= 10 else {
                assertionFailure("Router: redirect chain exceeded 10 hops (→ \(target))")
                redirectHops = 0
                return
            }
            navigate(to: target, replace: true)
        } else {
            redirectHops = 0
        }
    }
```

```swift
        // end of renderPass() AND subtreePass():
        let callbacks = effects.reconcile(ctx.effects, under: …)   // existing line
        for cb in callbacks { cb() }                               // existing line
        commitRouteEffects(ctx)
```

(Subtree passes carry the row's environment SNAPSHOT — correct: navigation always marks `.root`, so no subtree pass ever runs against a stale location.)

- [ ] **Step 4: Write `NavigationTests.swift`**

```swift
import Testing
@testable import SwiftWUI

private struct PathProbe: Tag {
    @Environment(\.routeInfo) var info
    @Environment(\.navigate) var navigate
    @Environment(\.back) var back
    var body: some Tag {
        Div {
            P { "at:\(info.path) q:\(info.query["x"] ?? "-")" }
            Button("go") { navigate("/next?x=1") }
            Button("replace") { navigate("/swap", replace: true) }
            Button("back") { back() }
        }
    }
}

@MainActor @Suite struct NavigationTests {
    private func make(initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: PathProbe(), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func initialPathReachesEnvironment() {
        let (_, backend, _) = make(initialPath: "/a/b?x=7")
        #expect(backend.serializeHTML().contains("at:/a/b q:7"))
    }
    @Test func navigatePushesAndRerenders() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)   // "go"
        #expect(backend.historyStack == ["/next?x=1"])
        #expect(backend.serializeHTML().contains("at:/next q:1"))
    }
    @Test func replaceUsesReplaceState() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 1, sched: sched)   // "replace"
        #expect(backend.historyStack.isEmpty)
        #expect(backend.replacedStates == ["/swap"])
    }
    @Test func popStateChangesLocationWithoutPush() {
        let (rt, backend, sched) = make()
        rt.handlePopState(url: "/popped?x=9")
        sched.pump()
        #expect(backend.historyStack.isEmpty)
        #expect(backend.serializeHTML().contains("at:/popped q:9"))
    }
    @Test func sameLocationNavigationIsNoOp() {
        let (rt, backend, sched) = make(initialPath: "/here")
        rt.navigate(to: "/here")
        sched.pump()
        #expect(backend.historyStack.isEmpty)
    }
    @Test func backCallsBackend() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 2, sched: sched)   // "back"
        #expect(backend.backCount == 1)
    }
}
```

- [ ] **Step 5: Run `swift test`** — expected: all pass (~189).

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI/Routing/RouteEnvironment.swift Sources/SwiftWUI/Runtime/Resolver.swift \
        Sources/SwiftWUI/Runtime/Runtime.swift Tests/SwiftWUITests/NavigationTests.swift
git commit -m "feat(routing): runtime location state, navigate/popstate, env actions, post-pass commit"
```

---

### Task 6: Router primitive

**Files:**
- Create: `Sources/SwiftWUI/Routing/Router.swift`
- Create: `Tests/SwiftWUITests/RouterTests.swift`

**Interfaces:**
- Consumes: `Route`/`RouteBuilder` (Task 3), `RouteInfo` env (Task 5), `ResolveContext.pendingRedirect/pageHead/routerCount` (Task 5), `Page`/`PageHead` (Task 4), `resolve()` + `.keyed(NodeKey)` (ForEach precedent, Core/ForEach.swift:34).
- Produces: `Router.init(@RouteBuilder routes:)`, `Router.init(notFound:routes:)`. Tasks 7, 10, 12 consume it.

- [ ] **Step 1: Write `Router.swift`**

```swift
/// URL router (spec §6). A PRIMITIVE tag — matched content resolves under
/// `.keyed(pattern)`, so a route change tears @State down while a param-only
/// change (/todo/1 → /todo/2) keeps identity and preserves it (spec D2).
///
/// First-match-wins in declaration order (spec D3). One Router per app (D9).
public struct Router: Tag, _PrimitiveTag {
    public typealias Body = Never
    let routes: [Route]
    let notFound: AnyTag?

    public init(@RouteBuilder routes: () -> [Route]) {
        self.routes = routes()
        self.notFound = nil
    }
    public init<NF: Tag>(@TagBuilder notFound: () -> NF,
                         @RouteBuilder routes: () -> [Route]) {
        self.routes = routes()
        self.notFound = AnyTag(notFound())
    }

    @MainActor public func _resolve(path: NodeIdentity, ctx: inout ResolveContext) -> [Node] {
        ctx.routerCount += 1
        assert(ctx.routerCount == 1, "SwiftWUI supports one Router per app (spec D9)")
        let info = ctx.environment.routeInfo
        for route in routes {
            guard let params = route.pattern.match(info.path) else { continue }
            if let g = route.guardClosure, case .redirect(let target) = g() {
                if ctx.pendingRedirect == nil { ctx.pendingRedirect = target }  // first wins
                continue                                                        // skipped (spec §5)
            }
            let content = route.builder(params)
            if let page = content.base as? any Page {                           // top-level only (spec §9)
                ctx.pageHead = PageHead(title: page.title, meta: page.meta)
            }
            let saved = ctx.environment
            ctx.environment.routeInfo.params = params
            let nodes = resolve(content,
                                path: path.appending(.keyed(NodeKey(route.pattern.raw))),
                                ctx: &ctx)
            ctx.environment = saved
            return nodes
        }
        if let notFound {
            return resolve(notFound, path: path.appending(.keyed(NodeKey("#not-found"))), ctx: &ctx)
        }
        #if DEBUG
        print("SwiftWUI Router: no route matched '\(info.path)' and no notFound content")
        #endif
        return []
    }
}
```

- [ ] **Step 2: Write `RouterTests.swift`**

```swift
import Testing
@testable import SwiftWUI

private struct RCounterPage: Tag {
    let label: String
    @State var n = 0
    var body: some Tag {
        Div {
            P { "\(label):\(n)" }
            Button("inc") { n += 1 }
        }
    }
}
private struct RNav: Tag {
    @Environment(\.navigate) var navigate
    var body: some Tag {
        Div(class: "nav") {
            Button("home") { navigate("/") }
            Button("detail1") { navigate("/todo/1") }
            Button("detail2") { navigate("/todo/2") }
            Button("boom") { navigate("/definitely-missing") }
        }
    }
}
private struct RApp: Tag {
    var body: some Tag {
        Div {
            RNav()
            Router(notFound: { P { "404" } }) {
                Route("/") { RCounterPage(label: "home") }
                Route("/todo/:id") { params in RCounterPage(label: "todo-\(params["id"] ?? "?")") }
                Route("/todo/special") { RCounterPage(label: "never") }   // shadowed: declaration order
                Route("/docs/*") { params in P { "docs:\(params["*"] ?? "")" } }
            }
        }
    }
}

@MainActor @Suite struct RouterTests {
    private func make(initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: RApp(), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }
    /// Buttons: [home, detail1, detail2, boom, inc?] — nav block renders first.
    private func click(_ label: Int, _ rt: Runtime<MockBackend>,
                       _ b: MockBackend, _ s: TestScheduler) {
        clickFirst(b, rt, tag: "button", index: label, sched: s)
    }

    @Test func matchesInitialAndSwitchesRoutes() {
        let (rt, backend, sched) = make()
        #expect(backend.serializeHTML().contains("home:0"))
        click(1, rt, backend, sched)                       // → /todo/1
        #expect(backend.serializeHTML().contains("todo-1:0"))
        #expect(!backend.serializeHTML().contains("home:0"))   // nav Button("home") always present — assert on page text
    }
    @Test func routeChangeResetsStateParamChangePreservesIt() {
        let (rt, backend, sched) = make(initialPath: "/todo/1")
        clickFirst(backend, rt, tag: "button", index: 4, sched: sched)   // inc on the page
        #expect(backend.serializeHTML().contains("todo-1:1"))
        click(2, rt, backend, sched)                       // → /todo/2: SAME pattern
        #expect(backend.serializeHTML().contains("todo-2:1"), "param change preserves @State (D2)")
        click(0, rt, backend, sched)                       // → /
        click(1, rt, backend, sched)                       // → /todo/1: was torn down at "/"
        #expect(backend.serializeHTML().contains("todo-1:0"), "route change resets @State")
    }
    @Test func declarationOrderWins() {
        let (_, backend, _) = make(initialPath: "/todo/special")
        #expect(backend.serializeHTML().contains("todo-special:0"))
        #expect(!backend.serializeHTML().contains("never"))
    }
    @Test func catchAllCapturesTail() {
        let (_, backend, _) = make(initialPath: "/docs/a/b")
        #expect(backend.serializeHTML().contains("docs:a/b"))
    }
    @Test func notFoundRenders() {
        let (rt, backend, sched) = make()
        click(3, rt, backend, sched)                       // → missing
        #expect(backend.serializeHTML().contains("404"))
    }
    @Test func emptyRouterWithoutNotFoundRendersNothing() {
        let backend = MockBackend(); let sched = TestScheduler()
        struct Bare: Tag { var body: some Tag { Router { Route("/only") { Text("x") } } } }
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Bare(), initialPath: "/other",
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        #expect(!backend.serializeHTML().contains("x"))
        _ = rt
    }
}
```

- [ ] **Step 3: Run `swift test`** — expected: all pass (~195).

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUI/Routing/Router.swift Tests/SwiftWUITests/RouterTests.swift
git commit -m "feat(routing): Router primitive — keyed identity, notFound, first-match order"
```

---

### Task 7: Guards, redirects & Page head — integration tests

**Files:**
- Create: `Tests/SwiftWUITests/GuardAndPageTests.swift`
- (Production code only if these tests expose a defect in Tasks 5–6.)

**Interfaces:**
- Consumes: everything from Tasks 3–6.
- Produces: tests only.

- [ ] **Step 1: Write `GuardAndPageTests.swift`**

```swift
import Testing
@testable import SwiftWUI

private final class GateBox { var open = false }

private struct GHome: Tag, Page {
    var title: String { "Home — G" }
    var meta: [MetaTag] { [.description("home page")] }
    var body: some Tag { P { "ghome" } }
}
private struct GAdmin: Tag, Page {
    var title: String { "Admin — G" }
    var body: some Tag { P { "gadmin" } }
}
private struct GPlain: Tag {                       // NOT a Page
    var body: some Tag { P { "gplain" } }
}
private struct GNav: Tag {
    @Environment(\.navigate) var navigate
    var body: some Tag {
        Div {
            Button("admin") { navigate("/admin") }
            Button("plain") { navigate("/plain") }
            Button("home") { navigate("/") }
        }
    }
}
private struct GApp: Tag {
    let gate: GateBox
    var body: some Tag {
        Div {
            GNav()
            Router {
                Route("/") { GHome() }
                Route("/plain") { GPlain() }
                Route("/admin", guard: { [gate] in gate.open ? .allow : .redirect("/") }) { GAdmin() }
            }
        }
    }
}

@MainActor @Suite struct GuardAndPageTests {
    private func make(gate: GateBox = GateBox(), initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: GApp(gate: gate), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func pageHeadAppliedAtMount() {
        let (_, backend, _) = make()
        #expect(backend.title == "Home — G")
        #expect(backend.metaTags == [.description("home page")])
    }
    @Test func headSwapsOnNavigationAndNonPageLeavesTitle() {
        let (rt, backend, sched) = make(gate: { let g = GateBox(); g.open = true; return g }())
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)   // → /admin (allowed)
        #expect(backend.title == "Admin — G")
        #expect(backend.metaTags.isEmpty)                                 // default meta replaces old set
        clickFirst(backend, rt, tag: "button", index: 1, sched: sched)   // → /plain (not a Page)
        #expect(backend.title == "Admin — G", "non-Page route leaves the title untouched")
    }
    @Test func headWriteDeduped() {
        let (rt, backend, sched) = make()
        let sets = backend.counts["setTitle", default: 0]
        clickFirst(backend, rt, tag: "button", index: 2, sched: sched)   // navigate to current → no-op
        rt.handlePopState(url: "/")                                       // re-render same page
        sched.pump()
        #expect(backend.counts["setTitle", default: 0] == sets, "unchanged head → no backend writes")
    }
    @Test func closedGuardRedirects() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)   // → /admin, guard closed
        sched.pump()                                                      // redirect flush
        #expect(backend.serializeHTML().contains("ghome"))
        #expect(!backend.serializeHTML().contains("gadmin"))
        #expect(backend.historyStack == ["/admin"], "the blocked push happened first")
        #expect(backend.replacedStates == ["/"], "redirect is replace, not push (spec §5)")
    }
    @Test func openGuardAllows() {
        let gate = GateBox(); gate.open = true
        let (rt, backend, sched) = make(gate: gate)
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)
        #expect(backend.serializeHTML().contains("gadmin"))
    }
    @Test func mountOnGuardedRouteRedirectsImmediately() {
        let (rt, backend, sched) = make(initialPath: "/admin")   // bind rt: `_` would free the Runtime before pump (weak-self redirect closure)
        sched.pump()
        _ = rt
        #expect(backend.serializeHTML().contains("ghome"))
        #expect(backend.replacedStates == ["/"])
    }
}
```

(No 10-hop-cap test: an infinite A→B→A loop trips `assertionFailure` in debug test runs by design. The cap's arithmetic is trivial; the self-redirect case is covered by `closedGuardRedirects` reaching a stable state.)

- [ ] **Step 2: Run `swift test`** — expected: all pass (~201). If `headWriteDeduped` fails because `subtreePass` never ran a Router, adjust only the test, not the runtime.

- [ ] **Step 3: Commit**

```bash
git add Tests/SwiftWUITests/GuardAndPageTests.swift
git commit -m "test(routing): guards, redirect-as-replace, Page head application"
```

---

### Task 8: ClickEvent + Link

**Files:**
- Modify: `Sources/SwiftWUI/HTML/EventPayloads.swift` (append `ClickEvent`)
- Modify: `Sources/SwiftWUI/HTML/HTMLTag.swift` (append internal `onClickEvent`)
- Create: `Sources/SwiftWUI/Routing/Link.swift`
- Create: `Tests/SwiftWUITests/LinkTests.swift`

**Interfaces:**
- Consumes: `A` tag (HTML/Tags.swift:439 — href is `sanitizeURL`-ed there), `LinkTarget` (Tags.swift:433), `_AttributeBag.addRawHandler` (AttributeBag.swift:54), `\.navigate` (Task 5).
- Produces: `ClickEvent` (`button: Int`, `metaKey/ctrlKey/shiftKey/altKey: Bool`, computed `isModified`); internal `HTMLTag.onClickEvent(_: @escaping (ClickEvent?) -> Void) -> Self`; `Link.init(_ destination: String, target: LinkTarget? = nil, content:)`; `Link.isExternal(_: String) -> Bool` (static, internal). Task 11 decodes ClickEvent in DOMBackend; Task 12 uses Link.

- [ ] **Step 1: Append `ClickEvent` to EventPayloads.swift**

```swift
/// Click payload (phase 4, spec §8). Carries what Link needs to decide
/// whether the browser should keep default anchor behavior.
public struct ClickEvent {
    public let button: Int
    public let metaKey: Bool
    public let ctrlKey: Bool
    public let shiftKey: Bool
    public let altKey: Bool
    public init(button: Int = 0, metaKey: Bool = false, ctrlKey: Bool = false,
                shiftKey: Bool = false, altKey: Bool = false) {
        self.button = button; self.metaKey = metaKey; self.ctrlKey = ctrlKey
        self.shiftKey = shiftKey; self.altKey = altKey
    }
    /// True → new-tab/context intent; SPA must not intercept.
    public var isModified: Bool { button != 0 || metaKey || ctrlKey || shiftKey || altKey }
}
```

(Do NOT extend the `GenericEvent` adapter: a `ClickEvent` payload falls into its `default:` case — all-nil fields, same shape `.on(.click)` handlers effectively saw before.)

- [ ] **Step 2: Append internal click helper to HTMLTag.swift** (after `on(_:perform:)`):

```swift
    /// Internal: click with the raw ClickEvent payload. nil payload (tests
    /// dispatching without one, non-DOM backends) = unmodified click.
    func onClickEvent(_ action: @escaping (ClickEvent?) -> Void) -> Self {
        var copy = self
        copy._attributes.addRawHandler(.click) { any in action(any as? ClickEvent) }
        return copy
    }
```

- [ ] **Step 3: Write `Link.swift`**

```swift
/// SPA link (spec §8). Internal destination → <a data-swui-link> whose click
/// is intercepted into `\.navigate`; external destination (scheme or "//")
/// or an explicit `target` → plain <a>, the browser handles it. href is
/// scheme-sanitized by `A` itself.
public struct Link<Content: Tag>: Tag {
    @Environment(\.navigate) private var navigate
    let destination: String
    let target: LinkTarget?
    let content: Content

    public init(_ destination: String, target: LinkTarget? = nil,
                @TagBuilder content: () -> Content) {
        self.destination = destination
        self.target = target
        self.content = content()
    }

    /// "https://…", "mailto:…", "//host/…" — anything that leaves the app.
    static func isExternal(_ url: String) -> Bool {
        if url.hasPrefix("//") { return true }
        for ch in url {
            if ch == ":" { return true }
            if ch == "/" || ch == "?" || ch == "#" { return false }
        }
        return false
    }

    public var body: some Tag {
        let dest = destination
        let nav = navigate
        if Self.isExternal(dest) || target != nil {
            A(href: dest, target: target) { content }
        } else {
            A(href: dest) { content }
                .attribute("data-swui-link", "")
                .onClickEvent { e in
                    guard e?.isModified != true else { return }   // browser: new tab etc.
                    nav(dest)
                }
        }
    }
}
```

- [ ] **Step 4: Write `LinkTests.swift`**

```swift
import Testing
@testable import SwiftWUI

private struct LProbe: Tag {
    @Environment(\.routeInfo) var info
    var body: some Tag {
        Div {
            P { "at:\(info.path)" }
            Link("/inside") { Span { "in" } }
            Link("https://example.com") { Span { "out" } }
            Link("/tab", target: .blank) { Span { "tab" } }
        }
    }
}

@MainActor @Suite struct LinkTests {
    private func make() -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: LProbe(), scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func externalDetection() {
        #expect(Link<Text>.isExternal("https://x.y"))
        #expect(Link<Text>.isExternal("mailto:a@b.c"))
        #expect(Link<Text>.isExternal("//cdn.x/lib.js"))
        #expect(!Link<Text>.isExternal("/inside"))
        #expect(!Link<Text>.isExternal("/q?x=1"))
        #expect(!Link<Text>.isExternal("relative/path"))
    }
    @Test func internalLinkNavigatesOnPlainClick() {
        let (rt, backend, sched) = make()
        let anchors = findAll(backend.container, tag: "a")
        rt.dispatch(anchors[0].events["click"]!, payload: ClickEvent())
        sched.pump()
        #expect(backend.serializeHTML().contains("at:/inside"))
        #expect(backend.historyStack == ["/inside"])
    }
    @Test func modifiedClickIsNotIntercepted() {
        let (rt, backend, sched) = make()
        let anchors = findAll(backend.container, tag: "a")
        rt.dispatch(anchors[0].events["click"]!, payload: ClickEvent(metaKey: true))
        rt.dispatch(anchors[0].events["click"]!, payload: ClickEvent(button: 1))
        sched.pump()
        #expect(backend.historyStack.isEmpty)
        #expect(backend.serializeHTML().contains("at:/"))
    }
    @Test func nilPayloadCountsAsPlainClick() {
        let (rt, backend, sched) = make()
        let anchors = findAll(backend.container, tag: "a")
        rt.dispatch(anchors[0].events["click"]!)
        sched.pump()
        #expect(backend.historyStack == ["/inside"])
    }
    @Test func externalAndTargetLinksGetNoListenerNoMarker() {
        let (_, backend, _) = make()
        let anchors = findAll(backend.container, tag: "a")
        #expect(anchors.count == 3)
        #expect(anchors[0].attrs["data-swui-link"] == "")
        for a in anchors[1...] {
            #expect(a.events["click"] == nil)
            #expect(a.attrs["data-swui-link"] == nil)
        }
        #expect(anchors[2].attrs["target"] == "_blank")
    }
}
```

- [ ] **Step 5: Run `swift test`** — expected: all pass (~206).

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI/HTML/EventPayloads.swift Sources/SwiftWUI/HTML/HTMLTag.swift \
        Sources/SwiftWUI/Routing/Link.swift Tests/SwiftWUITests/LinkTests.swift
git commit -m "feat(routing): Link with modified-click passthrough + ClickEvent payload"
```

---

### Task 9: @QueryParam

**Files:**
- Create: `Sources/SwiftWUI/Routing/QueryParam.swift`
- Create: `Tests/SwiftWUITests/QueryParamTests.swift`

**Interfaces:**
- Consumes: `_EnvironmentProperty` seam (Environment.swift:17 — StateStore.link's Mirror pass injects it before body), `\.routeInfo` (Task 5).
- Produces: `@QueryParam("name") var x: T?` for any `T: LosslessStringConvertible` (String, Int, Double, Bool…). Task 10 uses it in the fixture.

- [ ] **Step 1: Write `QueryParam.swift`**

```swift
/// Read-only typed query access (spec §10): `@QueryParam("page") var page: Int?`.
/// nil when the parameter is absent OR fails to parse. Writing the query is
/// `navigate`. Rides the same injection seam as @Environment.
@propertyWrapper
public struct QueryParam<Value: LosslessStringConvertible>: _EnvironmentProperty {
    final class Slot { var snapshot: EnvironmentValues? }
    private let name: String
    private let slot = Slot()
    public init(_ name: String) { self.name = name }
    public var wrappedValue: Value? {
        guard let raw = (slot.snapshot ?? EnvironmentValues()).routeInfo.query[name]
        else { return nil }
        return Value(raw)
    }
    public func _inject(_ values: EnvironmentValues) { slot.snapshot = values }
}
```

- [ ] **Step 2: Write `QueryParamTests.swift`**

```swift
import Testing
@testable import SwiftWUI

private struct QProbe: Tag {
    @QueryParam("filter") var filter: String?
    @QueryParam("page") var page: Int?
    @Environment(\.navigate) var navigate
    var body: some Tag {
        Div {
            P { "f:\(filter ?? "-") p:\(page.map(String.init) ?? "-")" }
            Button("go") { navigate("/?filter=active&page=2") }
            Button("bad") { navigate("/?page=nope") }
        }
    }
}

@MainActor @Suite struct QueryParamTests {
    private func make(initialPath: String = "/")
        -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
        let backend = MockBackend(); let sched = TestScheduler()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: QProbe(), initialPath: initialPath,
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        return (rt, backend, sched)
    }

    @Test func absentIsNil() {
        let (_, backend, _) = make()
        #expect(backend.serializeHTML().contains("f:- p:-"))
    }
    @Test func typedReadAndRerenderOnQueryChange() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 0, sched: sched)
        #expect(backend.serializeHTML().contains("f:active p:2"))
    }
    @Test func parseFailureIsNil() {
        let (rt, backend, sched) = make()
        clickFirst(backend, rt, tag: "button", index: 1, sched: sched)
        #expect(backend.serializeHTML().contains("p:-"))
    }
    @Test func initialQueryVisible() {
        let (_, backend, _) = make(initialPath: "/?filter=done&page=9")
        #expect(backend.serializeHTML().contains("f:done p:9"))
    }
}
```

- [ ] **Step 3: Run `swift test`** — expected: all pass (~210).

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUI/Routing/QueryParam.swift Tests/SwiftWUITests/QueryParamTests.swift
git commit -m "feat(routing): @QueryParam typed read-only query access"
```

---

### Task 10: Property fixture — Router in scoped ≡ full

**Files:**
- Modify: `Tests/SwiftWUITests/ScopedEquivalenceTests.swift`

**Interfaces:**
- Consumes: existing fixture (`PropRoot` etc.), `Router`/`Route` (Task 6), `NavigateAction` (Task 5), `@QueryParam` (Task 9).
- Produces: tests only. The random click sequence now includes navigation buttons, so route teardown/param/query paths run under the scoped ≡ full property (this pattern caught real bugs in phases 2 and 3).

- [ ] **Step 1: Add routed fixture around `PropRoot`** (append after `PropRoot`, before the suite):

```swift
private struct PropNav: Tag {
    @Environment(\.navigate) var navigate
    var body: some Tag {
        Div(class: "nav") {
            Button("go-home") { navigate("/") }
            Button("go-alt") { navigate("/alt/7?q=z") }
            Button("go-alt2") { navigate("/alt/8?q=w") }
        }
    }
}
private struct PropAlt: Tag {
    let id: String
    @QueryParam("q") var q: String?
    @State var m = 0
    var body: some Tag {
        Div(class: "alt") {
            P { "alt-\(id)-\(q ?? "-")-m\(m)" }
            Button("m+") { m += 1 }
        }
    }
}
private struct PropApp: Tag {
    var body: some Tag {
        Div {
            PropNav()
            Router(notFound: { P { "nf" } }) {
                Route("/") { PropRoot() }
                Route("/alt/:n") { params in PropAlt(id: params["n"] ?? "?") }
            }
        }
    }
}
```

- [ ] **Step 2: Point both runtimes at the routed root.** In `scopedEqualsFull`, replace the two `root: PropRoot()` arguments with `root: PropApp()`. Everything else (assertion block, seeds, batching) stays byte-identical — both runtimes still see the same click sequence, and navigation buttons are part of the random pool.

- [ ] **Step 3: Run `swift test`** — expected: all pass (~210; same count, stronger property). If a seed diverges, that is a REAL finding — debug it, do not weaken the assertions.

- [ ] **Step 4: Commit**

```bash
git add Tests/SwiftWUITests/ScopedEquivalenceTests.swift
git commit -m "test(routing): route the scoped-equivalence property fixture through Router"
```

---

### Task 11: Wasm wiring — DOMBackend + DOMRuntime

**Files:**
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (5 protocol methods + click decode)
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (initial location + popstate)

**Interfaces:**
- Consumes: backend protocol (Task 4), `Runtime.init(initialPath:)` + `handlePopState` (Task 5), `ClickEvent` (Task 8), `MetaTag` (Task 4).
- Produces: a compiling wasm target; browser behavior for history/title/meta/link-interception.

- [ ] **Step 1: DOMBackend — append the routing surface** (after `setStylesheet`):

```swift
    // History/head idioms below are the v1-audited patterns (master
    // DOMBridge.swift:387-416) — do not "modernize" them.
    public func pushState(path: String) {
        _ = JSObject.global.history.object!.pushState!(JSValue.null, "", path)
    }
    public func replaceState(path: String) {
        _ = JSObject.global.history.object!.replaceState!(JSValue.null, "", path)
    }
    public func historyBack() {
        _ = JSObject.global.history.object!.back!()
    }
    public func setTitle(_ title: String) {
        document.title = .string(title)
    }
    public func setMetaTags(_ tags: [MetaTag]) {
        // Replace ONLY the managed set (spec §9): marked data-swiftwui.
        let old = document.querySelectorAll("meta[data-swiftwui]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object {
                _ = el.parentNode.object?.removeChild?(el)
            }
        }
        guard let head = document.head.object else { return }
        for tag in tags {
            let el = document.createElement("meta").object!
            for name in tag.attributes.keys.sorted() {
                _ = el.setAttribute?(name, tag.attributes[name]!)
            }
            _ = el.setAttribute?("data-swiftwui", "")
            _ = head.appendChild?(el)
        }
    }
```

- [ ] **Step 2: DOMBackend — click decode + conditional preventDefault.** In `decodePayload`, add a case BEFORE `default:`:

```swift
        case "click":
            let click = ClickEvent(button: Int(e.button.number ?? 0),
                                   metaKey: e.metaKey.boolean ?? false,
                                   ctrlKey: e.ctrlKey.boolean ?? false,
                                   shiftKey: e.shiftKey.boolean ?? false,
                                   altKey: e.altKey.boolean ?? false)
            // SPA interception (spec §8): unmodified click on a managed link →
            // suppress full-page navigation; Link's Swift handler navigates.
            if !click.isModified,
               e.currentTarget.object?.hasAttribute?("data-swui-link").boolean == true {
                _ = e.preventDefault?()
            }
            return click
```

- [ ] **Step 3: DOMRuntime — initial location + popstate.** In `mount`, replace the `Runtime(...)` construction and add the popstate listener after `runtime.mount()`:

```swift
        let location = JSObject.global.location
        let initialPath = (location.pathname.string ?? "/") + (location.search.string ?? "")
        let runtime = Runtime(backend: backend, container: container,
                              root: root, initialPath: initialPath,
                              scheduleMicrotask: jsMicrotask,
                              globalStyles: globalStyles, themes: themes)
```

```swift
        runtime.mount()
        let popstate = JSClosure { [weak runtime] _ in
            let loc = JSObject.global.location
            runtime?.handlePopState(url: (loc.pathname.string ?? "/") + (loc.search.string ?? ""))
            return .undefined
        }
        _ = JSObject.global.window.object?.addEventListener?("popstate", popstate)
        retained.append(popstate)                 // JSClosure must outlive the page (v1 lesson)
```

- [ ] **Step 4: Wasm gate**

Run: `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`
Expected: build succeeds (Counter has no routes — this is purely the compile gate for SwiftWUIDOM).
Also run `swift test` from the repo root — expected: all pass (native untouched).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUIDOM/DOMBackend.swift Sources/SwiftWUIDOM/DOMRuntime.swift
git commit -m "feat(routing): wasm history/head backend + popstate + link click interception"
```

---

### Task 12: TodoMVC routes — acceptance

**Files:**
- Modify: `Examples/TodoMVC/Sources/main.swift`
- Modify: `Tests/SwiftWUITests/TodoAcceptanceTests.swift` (mirror fixture + new tests)

**Interfaces:**
- Consumes: everything.
- Produces: the phase-4 acceptance artifact (spec §14): filters as routes `/`, `/active`, `/completed`; detail `/todo/:id`; per-route titles via `Page`; `Link`s in the footer.

- [ ] **Step 1: Restructure the example.** In `Examples/TodoMVC/Sources/main.swift`:

1a. `Filter` gains route paths:

```swift
private enum Filter: String, CaseIterable {
    case all, active, completed
    var path: String { self == .all ? "/" : "/\(rawValue)" }
}
```

1b. Split `TodoApp` into a routed shell + a `TodoPage: Page`. The shell keeps the long-lived state (store, theme) ABOVE the Router so it survives route switches; the page conforms to `Page` and derives the filter from its route:

```swift
private struct TodoPage: Tag, Page, Styled {
    let filter: Filter
    @Environment(\.todoStore) var store
    @Environment(\.setTheme) var setTheme
    @State var dark = false
    var title: String { "todos — \(filter.rawValue)" }
    var meta: [MetaTag] { [.description("SwiftWUI TodoMVC — \(filter.rawValue) todos")] }
    @RulesBuilder var styles: [Rule] {
        Rule(class: "filters", media: .maxWidth(.px(600))) { $0.flexDirection(.column) }
        Rule(element: "button") { s in
            s.cursor(.pointer)
            s.hover { $0.background(.token(.accent)) }
        }
    }
    var visible: [TodoStore.Todo] {
        switch filter {
        case .all: store.todos
        case .active: store.todos.filter { !$0.done }
        case .completed: store.todos.filter(\.done)
        }
    }
    var body: some Tag {
        Main {
            H1("todos").color(.token(.accent)).fontSize(.rem(2))
            Input(type: .text, value: Binding(get: { store.draft }, set: { store.draft = $0 }),
                  onKeyDown: { e in if e.key == "Enter" { store.add() } })
                .padding(.px(8))
                .width(.percent(100))
            Ul {
                ForEach(visible) { todo in
                    Li {
                        TodoRow(todo: todo)
                        Link("/todo/\(todo.id)") { Span { "→" } }
                    }
                }
            }
            .listStyle("none")
            RemainingLabel()
            Div(class: "filters") {
                ForEach(Filter.allCases, id: \.rawValue) { f in
                    Link(f.path) { Span { f.rawValue } }
                }
                Button("theme") { dark.toggle(); setTheme(dark ? "dark" : nil) }
            }
            .display(.flex)
            .gap(.px(8))
        }
        .background(.token(.surface))
    }
}
```

`TodoRow` loses its own `Li` wrapper (the page's `Li` now hosts row + `Link`); its scoped rules move to the inner `Span`:

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
    var body: some Tag {
        Input(checked: Binding(get: { todo.done }, set: { _ in store.toggle(todo.id) }))
        Span(class: todo.done ? "done" : "todo") { todo.title }
    }
}
```

1c. Detail page:

```swift
private struct TodoDetail: Tag, Page {
    let id: Int?
    @Environment(\.todoStore) var store
    var todo: TodoStore.Todo? { store.todos.first { $0.id == id } }
    var title: String { "todo #\(id.map(String.init) ?? "?")" }
    var body: some Tag {
        Main {
            if let todo {
                H1(todo.title)
                P { todo.done ? "done" : "active" }
                Button(todo.done ? "reopen" : "complete") { store.toggle(todo.id) }
            } else {
                H1("todo not found")
            }
            Link("/") { Span { "← back" } }
        }
    }
}
```

1d. Routed shell replaces `TodoApp`; the `@main` app keeps its name:

```swift
private struct TodoApp: Tag {
    @State var store = TodoStore()
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { TodoPage(filter: .all) }
            Route("/active") { TodoPage(filter: .active) }
            Route("/completed") { TodoPage(filter: .completed) }
            Route("/todo/:id") { params in TodoDetail(id: params["id"].flatMap(Int.init)) }
        }
        .environment(\.todoStore, store)
        .task { await store.load() }
    }
}
```

1e. Delete the old `.onChange(of: filter)` document.title hack and the now-unused `#if arch(wasm32)` JavaScriptKit import if nothing else uses it. `@State filter` is gone — the route IS the filter.

- [ ] **Step 2: Mirror in `TodoAcceptanceTests.swift`.** Apply the same restructure to the test fixture (it deliberately duplicates the example): routed `TodoApp` shell, `TodoPage: Page` with `title`, `TodoDetail`, `Link` footer. Keep the `Counters` threading and the `.task` seeding exactly as-is. Update existing assertions that relied on filter BUTTONS to click the filter LINKS instead (dispatch with `ClickEvent()` on the `<a>` elements). Then add:

```swift
    @Test func filterRoutesFilterTheList() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        // seeded: 1 done, 1 active (adjust to the fixture's .task seed)
        let links = findAll(backend.container, tag: "a")
        let active = links.first { $0.children.contains { $0.children.first?.text == "active" } }!
        rt.dispatch(active.events["click"]!, payload: ClickEvent())
        sched.pump()
        #expect(backend.title == "todos — active")
        #expect(backend.historyStack.last == "/active")
    }
    @Test func detailRouteShowsTodoAndPreservesStoreOnReturn() async {
        let (rt, backend, sched, _) = makeApp()
        await waitUntil(sched) { !findAll(backend.container, tag: "li").isEmpty }
        rt.navigate(to: "/todo/1000")                       // seeded id
        sched.pump()
        #expect(backend.title == "todo #1000")
        #expect(backend.serializeHTML().contains("seeded"))
        rt.navigate(to: "/")
        sched.pump()
        #expect(backend.serializeHTML().contains("seeded"), "store above Router survives")
    }
    @Test func unknownRouteRenders404() {
        let (rt, backend, sched, _) = makeApp()
        rt.navigate(to: "/nope")
        sched.pump()
        #expect(backend.serializeHTML().contains("404"))
    }
    @Test func mountAtDeepPathWorks() async {
        // Same fixture but initialPath "/completed" — direct URL entry.
        let backend = MockBackend(); let sched = TestScheduler(); let counters = Counters()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: TodoApp(counters: counters), initialPath: "/completed",
                         scheduleMicrotask: sched.schedule)
        rt.mount()
        _ = rt
        #expect(backend.title == "todos — completed")
    }
```

(Exact fixture-shape details — `Counters` parameter threading through `TodoPage`/`TodoDetail`, seed contents — follow the file's existing conventions; the assertions above are the contract.)

- [ ] **Step 3: Run `swift test`** — expected: all pass (~216, exact count depends on how many existing acceptance tests changed shape).

- [ ] **Step 4: Wasm gate**

Run: `cd Examples/TodoMVC && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Examples/TodoMVC/Sources/main.swift Tests/SwiftWUITests/TodoAcceptanceTests.swift
git commit -m "feat(example): TodoMVC filters as routes + /todo/:id detail + Page titles"
```

Browser check (Vite :8080) is manual/user-driven and non-blocking, per spec §14.

---

## Final review

After all 12 tasks: whole-branch review (Fable), fix wave if needed, re-review — same protocol as phases 2–3. Update `.superpowers/sdd/progress.md` per task as you go.
