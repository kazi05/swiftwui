# Phase 7 — Tutorial Site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the "Hello, SwiftWUI" tutorial site — 12 pages, Apple-tutorial style, built with SwiftWUI itself (ssg + hydration), with real sample apps, Playwright-captured screenshots, and a browser smoke gate.

**Architecture:** A data-driven engine in `Sites/Tutorial`: plain-Swift content model (`Chapter → Section → Step`, `Panel`, `Quiz`) rendered by one component set; prerendered via the TodoMVC dual-entry ssg pattern; hydrated in the browser; scrollspy/quiz/menus are live `@State` components. Samples under `Sites/Tutorial/Samples/*` are the compiled source of truth for every code panel.

**Tech Stack:** Swift 6.3.3 + SwiftWUI (path dep), JavaScriptKit (wasm-only IntersectionObserver), Swift Testing (native gate), swiftwui CLI (build/ssg/serve/dev), Playwright (tools only — screenshots + smoke).

**Spec:** `docs/superpowers/specs/2026-07-05-phase7-tutorial-site-design.md` (all §-references below point there).

## Global Constraints

- Toolchain: Swift **6.3.3** (swiftly) host + `swift-6.3.3-RELEASE_wasm` SDK. Versions must match exactly.
- All wasm builds go through the CLI (`swiftwui build` → isolated `.build-wasm` scratch path). NEVER run raw `swift package --swift-sdk … js` in a directory that also gets native `swift build`/`swift run` (corrupts `.build/debug` triple symlink — WasmBuild.swift:26).
- The CLI is invoked as `swift run --package-path <repo-root> swiftwui <cmd>` with cwd = the project directory. In commands below, `$REPO` = the SwiftWUI checkout root and `SWIFTWUI="swift run --package-path $REPO swiftwui"`.
- No framework/CLI source changes (spec §15). The ONLY files outside `Sites/Tutorial` this plan touches: `Examples/Counter/Sources/` (tutorial markers + `Hello.swift`, Task 10).
- No new Swift dependencies. JavaScriptKit is already used by every example. Playwright is an npm devDependency confined to `Sites/Tutorial/tools/screenshots/` — never a build input of the site.
- All site copy in English. Swift files: `swiftSettings: [.defaultIsolation(MainActor.self)]` (repo pattern).
- Testing style (user preference, overrides RED/GREEN cadence): per task, write ALL code + tests first, run the suite ONCE at the end, then commit. Native `swift test --package-path Sites/Tutorial` is the primary gate.
- Commit messages end with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- Excerpt markers in sample sources: a line `// tutorial:begin <name>` … `// tutorial:end <name>` at column 0; the excerpt is the lines strictly between them, verbatim.
- Screenshots live in `Sites/Tutorial/Assets/screens/` and are committed. `swiftwui dev` does NOT serve `/assets/*` (dev URL space is `/app/*` + vendor + index only) — images 404 under `dev`; the golden path for visual checks is `swiftwui serve dist` after the `cp -R Assets dist/assets` step (§13 of the spec, Task 9's build script).

## Spec deviation (single, with rationale)

Spec §5 sketches `Panel.code(file:, source: CodeRef)` with panel text loadable from the referenced file. Wasm has no filesystem at render time, so this plan embeds the text in `CodePanel.code` and keeps the file pointer as `CodeOrigin` (`.sample(path:marker:)` / `.fragment(path:)`), enforced byte-for-byte by the native excerpt-sync test (spec §9.2). Semantics are identical — panels cannot drift from compiled sources; only the representation differs.

## Design tokens (extracted from Figma `u9MtpHLmB6MvupyLgEHayW` — final values, do not re-derive)

| Token (ColorToken name) | Value | Used for |
|---|---|---|
| `page-bg` | `#faf9f7` | page + nav background |
| `band-bg` | `#f2f0ec` | quiz band, browser-mock chrome |
| `dark-bg` | `#17140f` | hero, chapter bar, CTA card |
| `dark-card` | `#211d17` | code cards, terminals |
| `overlay-bg` | `#1d1a15` | chapter-menu overlay |
| `ink` | `#1c1917` | headings/body on light |
| `muted` | `#57534e` | secondary text on light |
| `faint` | `#a8a29e` | inactive step numbers |
| `border-light` | `#e7e5e0` | light borders/dividers |
| `dark-text` | `#f5f1ea` | primary text on dark |
| `dark-muted` | `#c9c3b8` | secondary text on dark |
| `accent` | `#d9552f` | buttons, light-bg kickers, active step numbers |
| `accent-soft` | `#e8794f` | dark-bg kickers, code keywords, terminal `$` |
| `on-accent` | `#fffaf5` | text on accent buttons |
| `code-type` | `#dfb07e` | type identifiers in code |
| `code-string` | `#a8b892` | strings in code, terminal success lines |

Non-token constants (used inline where they occur): dark borders `rgba(255,255,255,0.08/0.10/0.12/0.14/0.15)`, chapter-dropdown fill `rgba(255,255,255,0.06)`, menu-item active fill `rgba(255,255,255,0.08)`, ghost-button border `rgba(245,241,234,0.25)`, quiz selected fill `rgba(217,85,47,0.06)` + `1.5px` `#d9552f` border, hero body text `rgba(201,195,184,0.85)`, chrome filename `rgba(201,195,184,0.7)`, menu label `rgba(201,195,184,0.55)`, menu item `rgba(245,241,234,0.8)`; shadows: code card `0px 24px 60px -12px rgba(217,84,46,0.10)`, terminal/browser `0px 16px 40px -8px rgba(28,26,23,0.12)`, overlay `0px 20px 50px -10px rgba(0,0,0,0.35)`; traffic-light dots `#ff5f57 #febc2e #28c840`.

Typography (Figma uses Geist/Geist Mono; per spec D10 we ship system stacks): UI `system-ui, -apple-system, 'Segoe UI', sans-serif`; code/kickers `ui-monospace, 'SF Mono', Menlo, monospace`. Sizes: hero h1 54px/-1.5px bold; chapter-page hero h1 44px/-1px bold; section title 30px/-0.5px bold; quiz header 26px/-0.4px; CTA title 28px/-0.5px; kicker mono 12px medium +1.5px tracking uppercase; step number mono 13px; step title 15px lh23; body/intro 16px lh26; code mono 13px lh21 (terminal lh22); nav links 14px; footer 13px. Content column 1040px; hero pad-y 104px; section pad 88px top / 56px bottom, header→body gap 40px, columns gap 56px; panel width 480px (hero code card 460px); cards r14 (CTA r18, buttons/options r10, menu items r8, section-dropdown pill r999).

## File map (final)

```
Sites/Tutorial/
├─ Package.swift                    Task 1
├─ index.html                       Task 1
├─ README.md                        Task 16
├─ Sources/
│  ├─ TutorialKit/                  (library — all logic, testable)
│  │  ├─ Model/ContentModel.swift   Task 1
│  │  ├─ Model/Curriculum.swift     Task 1 (skeleton) → filled by Tasks 10,13,14,15
│  │  ├─ Content/Ch01_Overview.swift … Ch12_WrapUpShip.swift   Tasks 10,13,14,15
│  │  ├─ Theme.swift                Task 2
│  │  ├─ Support/SwiftHighlighter.swift  Task 3
│  │  ├─ Support/ScrollSpy.swift    Task 7 (#if arch(wasm32))
│  │  ├─ Components/SiteNav.swift, SiteFooter.swift, HeroView.swift, NextChapterCTA.swift   Task 4
│  │  ├─ Components/PanelView.swift Task 5
│  │  ├─ Components/ChapterBar.swift, ChapterMenu.swift        Task 6
│  │  ├─ Components/SectionView.swift, StepList.swift          Task 7
│  │  ├─ Components/QuizCard.swift  Task 8
│  │  └─ Components/Pages.swift (OverviewPage/ChapterPage/WrapUpPage), App.swift  Task 9
│  └─ TutorialSite/main.swift       Task 9 (dual entry)
├─ Tests/TutorialKitTests/
│  ├─ TestSupport.swift             Task 1
│  ├─ ContentInvariantTests.swift   Task 1 (grows in 10,13,14,15)
│  ├─ ThemeTests.swift              Task 2
│  ├─ HighlighterTests.swift        Task 3
│  ├─ ComponentGoldenTests.swift    Tasks 4,5
│  ├─ InteractionTests.swift        Tasks 6,7,8
│  ├─ PageTests.swift               Task 9
│  └─ ExcerptSyncTests.swift        Task 10
├─ Assets/screens/                  Task 10 (placeholder) → Task 12 (real)
├─ Samples/
│  ├─ StyleBubble/{Package.swift,index.html,Sources/main.swift}   Task 11
│  ├─ ChatRouter/{Package.swift,index.html,Sources/main.swift}    Task 11
│  └─ ShipCounter/{Package.swift,index.html,Dockerfile,Sources/main.swift}  Task 11
└─ tools/screenshots/
   ├─ package.json, shots.mjs, shots.config.mjs                   Task 12
   ├─ smoke.spec.mjs, playwright.config.mjs, run-smoke.sh         Task 12
   └─ .gitignore                    Task 12
Examples/Counter/Sources/main.swift  Task 10 (markers only)
Examples/Counter/Sources/Hello.swift Task 10 (new)
```

Task order = spec §14 slices: engine (1–9) → hero chapter end-to-end (10) → samples + pipeline (11–12) → content (13–15) → acceptance + README (16).

---
### Task 1: Package scaffold + content model + curriculum skeleton

**Files:**
- Create: `Sites/Tutorial/Package.swift`
- Create: `Sites/Tutorial/index.html`
- Create: `Sites/Tutorial/Sources/TutorialKit/Model/ContentModel.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Model/Curriculum.swift`
- Create: `Sites/Tutorial/Sources/TutorialSite/main.swift` (temporary stub, replaced in Task 9)
- Create: `Sites/Tutorial/Tests/TutorialKitTests/TestSupport.swift`
- Test: `Sites/Tutorial/Tests/TutorialKitTests/ContentInvariantTests.swift`

**Interfaces:**
- Consumes: nothing (first task).
- Produces (used by ALL later tasks — exact names are binding):
  - `Track`, `PageKind`, `TermLine`, `CodeOrigin`, `CodePanel`, `Panel`, `Step`, `Section`, `Question`, `Quiz`, `Chapter` (all `public`, fields below).
  - `Curriculum.chapters: [Chapter]`, `Curriculum.chapter(slug:) -> Chapter?`, `Curriculum.next(after:) -> Chapter?`, `Curriculum.ssgPaths: [String]`, `Chapter.path: String`.
  - Test helpers: `repoRoot: URL`, `siteRoot: URL` (computed from `#filePath`).

- [ ] **Step 1: Write the package manifest and shell**

`Sites/Tutorial/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TutorialSite",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .target(name: "TutorialKit", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        ], swiftSettings: [.defaultIsolation(MainActor.self)]),
        .executableTarget(name: "TutorialSite", dependencies: [
            "TutorialKit",
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "SwiftWUIStatic", package: "SwiftWUI",
                     condition: .when(platforms: [.macOS, .linux])),
        ], swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "TutorialKitTests", dependencies: [
            "TutorialKit",
            .product(name: "SwiftWUI", package: "SwiftWUI"),
        ], swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
```

`Sites/Tutorial/index.html` (CLI-template shape — NOT the Examples shape; `swiftwui build` serves the bundle from `/app/index.js`):

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>SwiftWUI Tutorials</title>
  <script type="importmap">
  {"imports": {"@bjorn3/browser_wasi_shim": "/vendor/wasi-shim/index.js"}}
  </script>
</head>
<body>
  <script type="module">
    import { init } from "/app/index.js";
    await init();
  </script>
</body>
</html>
```

`Sites/Tutorial/Sources/TutorialSite/main.swift` — temporary stub so the executable target builds before Task 9 replaces it:

```swift
import TutorialKit

@main enum Entry {
    static func main() {
        print("TutorialSite: entry lands in Task 9")
    }
}
```

- [ ] **Step 2: Write the content model**

`Sites/Tutorial/Sources/TutorialKit/Model/ContentModel.swift` — renderer-agnostic: NO SwiftWUI import here; native tests validate content without a backend (spec §5).

```swift
/// Content model for the tutorial site (spec §5). Pure data — no Tag imports.

public enum Track: String, CaseIterable, Sendable {
    case welcome = "Welcome"
    case explore = "Explore SwiftWUI"
    case styles = "Styles"
    case routing = "Routing"
    case ship = "Ship"
}

public enum PageKind: Equatable, Sendable {
    case overview, chapter, wrapUp
}

public struct TermLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case command, output, note }
    public let kind: Kind
    public let text: String
    public init(_ kind: Kind, _ text: String) { self.kind = kind; self.text = text }
}

/// Where a code panel's text comes from — the TEXT is embedded (wasm has no
/// filesystem); the origin pins it to a compiled file via native test (spec §7/§9.2).
public enum CodeOrigin: Equatable, Sendable {
    /// `code` must equal the region between `// tutorial:begin <marker>` and
    /// `// tutorial:end <marker>` in the file at repo-relative `path`.
    case sample(path: String, marker: String)
    /// `code` must be a verbatim substring of the file at repo-relative `path`.
    case fragment(path: String)
}

public struct CodePanel: Equatable, Sendable {
    public let file: String        // chrome title, e.g. "Counter.swift"
    public let code: String        // embedded verbatim source text
    public let origin: CodeOrigin
    public init(file: String, code: String, origin: CodeOrigin) {
        self.file = file; self.code = code; self.origin = origin
    }
}

public enum Panel: Equatable, Sendable {
    case code(CodePanel)
    case terminal(title: String, lines: [TermLine])
    /// `screenshot` is a path under Assets/, e.g. "screens/counter-3.png";
    /// rendered as <img src="/assets/screens/counter-3.png">.
    case browser(url: String, screenshot: String)
}

public struct Step: Equatable, Sendable {
    public let title: String
    public let detail: String?
    /// Override: when this step is active, the sticky panel shows this instead
    /// of the section panel (spec D2).
    public let panel: Panel?
    public init(_ title: String, detail: String? = nil, panel: Panel? = nil) {
        self.title = title; self.detail = detail; self.panel = panel
    }
}

public struct Section: Equatable, Sendable {
    public let anchor: String      // stable DOM id prefix + #anchor target, kebab-case
    public let kicker: String      // "01 · TOOLCHAIN"
    public let title: String
    public let intro: String?
    public let steps: [Step]
    public let panel: Panel
    public init(anchor: String, kicker: String, title: String, intro: String? = nil,
                steps: [Step], panel: Panel) {
        self.anchor = anchor; self.kicker = kicker; self.title = title
        self.intro = intro; self.steps = steps; self.panel = panel
    }
}

public struct Question: Equatable, Sendable {
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
    public let explanation: String
    public init(prompt: String, options: [String], correctIndex: Int, explanation: String) {
        self.prompt = prompt; self.options = options
        self.correctIndex = correctIndex; self.explanation = explanation
    }
}

public struct Quiz: Equatable, Sendable {
    public let questions: [Question]   // invariant: exactly 3 (spec §3)
    public init(questions: [Question]) { self.questions = questions }
}

public struct Chapter: Sendable {
    public let slug: String
    public let track: Track
    public let kicker: String      // "GETTING STARTED", "CHAPTER · STYLES", "WRAP-UP · SHIP"
    public let title: String
    public let tagline: String
    public let body: String?       // hero paragraph (big hero only)
    public let minutes: Int
    public let kind: PageKind
    public let heroPanel: Panel?   // ch4 code card in the hero (Figma 1:2); nil = simple hero
    public let sections: [Section]
    public let recap: [String]?    // wrap-up bullets (spec §5)
    public let quiz: Quiz?
    public init(slug: String, track: Track, kicker: String, title: String,
                tagline: String, body: String? = nil, minutes: Int, kind: PageKind,
                heroPanel: Panel? = nil, sections: [Section] = [],
                recap: [String]? = nil, quiz: Quiz? = nil) {
        self.slug = slug; self.track = track; self.kicker = kicker; self.title = title
        self.tagline = tagline; self.body = body; self.minutes = minutes; self.kind = kind
        self.heroPanel = heroPanel; self.sections = sections
        self.recap = recap; self.quiz = quiz
    }

    /// Route path: overview is "/", everything else "/tutorials/<slug>".
    public var path: String { kind == .overview ? "/" : "/tutorials/\(slug)" }
}
```

- [ ] **Step 3: Write the curriculum skeleton**

`Sites/Tutorial/Sources/TutorialKit/Model/Curriculum.swift`. Chapters 1–12 exist from day one with final slugs/titles/tracks/kinds; `sections`/`recap`/`quiz` are empty until the content tasks (10, 13–15) replace each stub with `ChXX.chapter`. The stubs keep every menu/next link resolvable so the invariant tests are green at every slice (spec §14).

```swift
/// Ordered curriculum (spec §3). Content tasks replace stub entries with the
/// full `ChXX.chapter` definitions; slugs/order/kinds are FINAL here.
public enum Curriculum {
    public static let chapters: [Chapter] = [
        Chapter(slug: "welcome", track: .welcome, kicker: "SWIFTWUI TUTORIALS",
                title: "Welcome to SwiftWUI Tutorials",
                tagline: "Learn to build the web in pure Swift — one chapter at a time.",
                minutes: 2, kind: .overview),
        Chapter(slug: "install-the-toolchain", track: .welcome, kicker: "CHAPTER · WELCOME",
                title: "Install the toolchain",
                tagline: "Swift 6.3.3, the matching WASM SDK, and the swiftwui CLI.",
                minutes: 10, kind: .chapter),
        Chapter(slug: "create-your-first-project", track: .welcome, kicker: "CHAPTER · WELCOME",
                title: "Create your first project",
                tagline: "Scaffold with swiftwui init and iterate with hot reload.",
                minutes: 10, kind: .chapter),
        Chapter(slug: "hello-swiftwui", track: .explore, kicker: "GETTING STARTED",
                title: "Hello, SwiftWUI",
                tagline: "Build the web in pure Swift.",
                body: "You’ll build Counter — an interactive page written entirely in Swift, compiled to WebAssembly, and rendered through a SwiftUI-style declarative API. No JavaScript required.",
                minutes: 25, kind: .chapter),
        Chapter(slug: "wrap-up-explore", track: .explore, kicker: "WRAP-UP · EXPLORE SWIFTWUI",
                title: "Wrap-up: Explore SwiftWUI",
                tagline: "What you learned building your first SwiftWUI page.",
                minutes: 5, kind: .wrapUp),
        Chapter(slug: "style-in-swift", track: .styles, kicker: "CHAPTER · STYLES",
                title: "Style in Swift",
                tagline: "Type-safe CSS modifiers cover the common cases; a raw string escape hatch covers the rest.",
                minutes: 20, kind: .chapter),
        Chapter(slug: "wrap-up-styles", track: .styles, kicker: "WRAP-UP · STYLES",
                title: "Wrap-up: Styles",
                tagline: "Modifiers, rules, and themes — recapped.",
                minutes: 5, kind: .wrapUp),
        Chapter(slug: "route-between-pages", track: .routing, kicker: "CHAPTER · ROUTING",
                title: "Route between pages",
                tagline: "Declare routes as data, render a Tag per path, and let the framework drive browser history.",
                minutes: 20, kind: .chapter),
        Chapter(slug: "wrap-up-routing", track: .routing, kicker: "WRAP-UP · ROUTING",
                title: "Wrap-up: Routing",
                tagline: "Routes, links, and identity — recapped.",
                minutes: 5, kind: .wrapUp),
        Chapter(slug: "prerender-and-hydrate", track: .ship, kicker: "CHAPTER · SHIP",
                title: "Prerender and hydrate",
                tagline: "Static HTML at build time for instant first paint; the WASM runtime hydrates it into a live app.",
                minutes: 20, kind: .chapter),
        Chapter(slug: "deploy-with-docker", track: .ship, kicker: "CHAPTER · SHIP",
                title: "Deploy with Docker",
                tagline: "One reproducible image: build the wasm bundle, prerender, export static files.",
                minutes: 15, kind: .chapter),
        Chapter(slug: "wrap-up-ship", track: .ship, kicker: "WRAP-UP · SHIP",
                title: "Wrap-up: Ship",
                tagline: "SSG, hydration, and deployment — recapped.",
                minutes: 5, kind: .wrapUp),
    ]

    public static func chapter(slug: String) -> Chapter? {
        chapters.first { $0.slug == slug && $0.kind != .overview }
    }

    public static var overview: Chapter { chapters[0] }

    /// Next chapter in curriculum order; the LAST page wraps to the overview
    /// ("Explore more tutorials", spec §3). The overview itself has no next.
    public static func next(after chapter: Chapter) -> Chapter? {
        guard chapter.kind != .overview,
              let i = chapters.firstIndex(where: { $0.slug == chapter.slug }) else { return nil }
        return i + 1 < chapters.count ? chapters[i + 1] : overview
    }

    /// The 11 dynamic ssg paths (overview excluded — it is the static "/" route, spec §11).
    public static var ssgPaths: [String] {
        chapters.filter { $0.kind != .overview }.map(\.path)
    }
}
```

- [ ] **Step 4: Write test support + content invariant tests**

`Sites/Tutorial/Tests/TutorialKitTests/TestSupport.swift`:

```swift
import Foundation
import SwiftWUI
@testable import TutorialKit

/// Sites/Tutorial (this package's root), derived from #filePath —
/// stable regardless of the runner's cwd.
let siteRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // TutorialKitTests
    .deletingLastPathComponent()   // Tests
    .deletingLastPathComponent()   // Sites/Tutorial
/// SwiftWUI repo root.
let repoRoot: URL = siteRoot
    .deletingLastPathComponent()   // Sites
    .deletingLastPathComponent()   // repo

/// Manual microtask pump (mirrors the framework's RuntimeE2ETests helper —
/// that helper is internal to the framework's test target, so the site keeps
/// its own copy).
@MainActor final class TestScheduler {
    private var queue: [() -> Void] = []
    func schedule(_ f: @escaping () -> Void) { queue.append(f) }
    func pump() { while !queue.isEmpty { queue.removeFirst()() } }
}

@MainActor
func findFirst(_ node: MockNode, tag: String) -> MockNode? {
    if node.tag == tag { return node }
    for c in node.children { if let f = findFirst(c, tag: tag) { return f } }
    return nil
}

@MainActor
func findAll(_ node: MockNode, tag: String) -> [MockNode] {
    var out: [MockNode] = []
    if node.tag == tag { out.append(node) }
    for c in node.children { out += findAll(c, tag: tag) }
    return out
}

/// First descendant whose class attribute contains `cls` (space-separated match).
@MainActor
func findFirst(_ node: MockNode, class cls: String) -> MockNode? {
    if let classes = node.attrs["class"]?.split(separator: " ").map(String.init),
       classes.contains(cls) { return node }
    for c in node.children { if let f = findFirst(c, class: cls) { return f } }
    return nil
}

@MainActor
func findAll(_ node: MockNode, class cls: String) -> [MockNode] {
    var out: [MockNode] = []
    if let classes = node.attrs["class"]?.split(separator: " ").map(String.init),
       classes.contains(cls) { out.append(node) }
    for c in node.children { out += findAll(c, class: cls) }
    return out
}

/// All text content beneath a node, concatenated in document order.
@MainActor
func textContent(_ node: MockNode) -> String {
    var out = node.text ?? ""
    for c in node.children { out += textContent(c) }
    return out
}

@MainActor
func makeRuntime(_ root: some Tag) -> (Runtime<MockBackend>, MockBackend, TestScheduler) {
    let backend = MockBackend()
    let sched = TestScheduler()
    let rt = Runtime(backend: backend, container: backend.container,
                     root: root, scheduleMicrotask: sched.schedule)
    return (rt, backend, sched)
}
```

`Sites/Tutorial/Tests/TutorialKitTests/ContentInvariantTests.swift` (spec §9.1 — the screenshot/quiz-count assertions are written now and are green on stubs because stubs have no panels/quizzes; they bite as content lands):

```swift
import Foundation
import Testing
@testable import TutorialKit

@Suite struct ContentInvariantTests {
    @Test func slugsAreUniqueAndKebabCase() {
        let slugs = Curriculum.chapters.map(\.slug)
        #expect(Set(slugs).count == slugs.count)
        for s in slugs {
            #expect(!s.isEmpty)
            #expect(s.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }, "bad slug: \(s)")
        }
    }

    @Test func curriculumShape() {
        #expect(Curriculum.chapters.count == 12)
        #expect(Curriculum.chapters[0].kind == .overview)
        #expect(Curriculum.chapters.filter { $0.kind == .wrapUp }.count == 4)
        #expect(Curriculum.ssgPaths.count == 11)
        #expect(Curriculum.ssgPaths.allSatisfy { $0.hasPrefix("/tutorials/") })
    }

    @Test func nextChainResolves() {
        // Every non-overview chapter has a next; the last wraps to the overview.
        for ch in Curriculum.chapters where ch.kind != .overview {
            #expect(Curriculum.next(after: ch) != nil, "no next after \(ch.slug)")
        }
        let last = Curriculum.chapters.last!
        #expect(Curriculum.next(after: last)?.kind == .overview)
        #expect(Curriculum.next(after: Curriculum.overview) == nil)
    }

    @Test func wrapUpsCarryRecapAndQuizOnceAuthored() {
        for ch in Curriculum.chapters where ch.kind == .wrapUp {
            // Stubs (sections empty AND recap nil) are exempt until their
            // content task lands; an authored wrap-up must be complete.
            let authored = ch.recap != nil || ch.quiz != nil
            guard authored else { continue }
            #expect(ch.recap?.isEmpty == false, "\(ch.slug): recap missing")
            #expect(ch.quiz != nil, "\(ch.slug): quiz missing")
            #expect(ch.sections.isEmpty, "\(ch.slug): wrap-ups have no sections (spec §3)")
        }
    }

    @Test func quizzesHaveExactlyThreeValidQuestions() {
        for ch in Curriculum.chapters {
            guard let quiz = ch.quiz else { continue }
            #expect(quiz.questions.count == 3, "\(ch.slug): quiz must have 3 questions")
            for q in quiz.questions {
                #expect(q.options.count >= 2)
                #expect(q.options.indices.contains(q.correctIndex), "\(ch.slug): correctIndex out of range")
                #expect(!q.explanation.isEmpty)
            }
        }
    }

    @Test func sectionAnchorsUniquePerChapter() {
        for ch in Curriculum.chapters {
            let anchors = ch.sections.map(\.anchor)
            #expect(Set(anchors).count == anchors.count, "\(ch.slug): duplicate anchors")
        }
    }

    @Test func browserPanelScreenshotsExistOnDisk() {
        for ch in Curriculum.chapters {
            for section in ch.sections {
                for panel in [section.panel] + section.steps.compactMap(\.panel) {
                    guard case .browser(_, let shot) = panel else { continue }
                    let url = siteRoot.appendingPathComponent("Assets/\(shot)")
                    #expect(FileManager.default.fileExists(atPath: url.path),
                            "\(ch.slug): missing screenshot Assets/\(shot)")
                }
            }
        }
    }
}
```

- [ ] **Step 5: Build + test once**

```bash
cd Sites/Tutorial
swift build            # expected: Build complete
swift test             # expected: all ContentInvariantTests pass
```

- [ ] **Step 6: Commit**

```bash
git add Sites/Tutorial
git commit -m "feat(tutorial): package scaffold, content model, curriculum skeleton

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 2: Theme tokens + global stylesheet

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Theme.swift`
- Test: `Sites/Tutorial/Tests/TutorialKitTests/ThemeTests.swift`

**Interfaces:**
- Consumes: Task 1 model (nothing directly — parallel-safe).
- Produces: `extension ColorToken` statics (`.pageBg .bandBg .darkBg .darkCard .overlayBg .ink .muted .faint .borderLight .darkText .darkMuted .accent .accentSoft .onAccent .codeType .codeString`), `TutorialTheme.definition: ThemeDefinition`, `TutorialStyles.rules: [Rule]` (the FULL site stylesheet — later components add no rules, only class names from the list below), `Fonts.ui: String`, `Fonts.mono: String`.
- CSS class contract (binding for Tasks 4–9; all selectors defined here): `tut-content tut-nav tut-brand tut-nav-links tut-chapterbar tut-series tut-series-accent tut-divider tut-dropdown tut-pill tut-menu tut-menu-open tut-menu-group tut-menu-label tut-menu-item tut-menu-item-active tut-menu-dot tut-hero tut-hero-grid tut-hero-text tut-hero-title tut-hero-tagline tut-hero-body tut-hero-actions tut-hero-simple tut-btn-primary tut-btn-ghost tut-kicker tut-kicker-dark tut-card-dark tut-chrome tut-dot tut-dot-r tut-dot-y tut-dot-g tut-chrome-title tut-code tut-code-line tok-kw tok-type tok-str tok-num tok-cmt tok-wrap tut-term-line tut-term-cmd tut-term-prompt tut-term-out tut-term-note tut-section tut-section-header tut-section-title tut-section-intro tut-section-body tut-steps tut-step tut-step-active tut-step-num tut-step-title tut-step-detail tut-panel tut-browser tut-browser-chrome tut-url tut-viewport tut-shot tut-quiz tut-quiz-header tut-quiz-card tut-question tut-option tut-option-selected tut-option-correct tut-option-wrong tut-radio tut-option-label tut-quiz-submit tut-explain tut-explain-ok tut-explain-no tut-cta tut-cta-card tut-cta-text tut-cta-title tut-cta-tagline tut-footer tut-footer-links tut-overview-hero tut-track tut-track-label tut-cards tut-card-link tut-card-kicker tut-card-title tut-card-tagline tut-card-minutes tut-recap tut-recap-item`.

- [ ] **Step 1: Write Theme.swift**

Values come from the "Design tokens" table in the header — copy them exactly. Shape (the listing below is complete for tokens/fonts/theme and for the structurally interesting rules; the remaining rules are pure token-table transcription — every class in the contract above MUST get a rule here, using the header's exact px/color values):

```swift
import SwiftWUI

public extension ColorToken {
    static let pageBg      = ColorToken("page-bg")
    static let bandBg      = ColorToken("band-bg")
    static let darkBg      = ColorToken("dark-bg")
    static let darkCard    = ColorToken("dark-card")
    static let overlayBg   = ColorToken("overlay-bg")
    static let ink         = ColorToken("ink")
    static let muted       = ColorToken("muted")
    static let faint       = ColorToken("faint")
    static let borderLight = ColorToken("border-light")
    static let darkText    = ColorToken("dark-text")
    static let darkMuted   = ColorToken("dark-muted")
    static let accent      = ColorToken("accent")
    static let accentSoft  = ColorToken("accent-soft")
    static let onAccent    = ColorToken("on-accent")
    static let codeType    = ColorToken("code-type")
    static let codeString  = ColorToken("code-string")
}

public enum Fonts {
    public static let ui = "system-ui, -apple-system, 'Segoe UI', sans-serif"
    public static let mono = "ui-monospace, 'SF Mono', Menlo, monospace"
}

public enum TutorialTheme {
    public static let definition = ThemeDefinition { t in
        t.set(ColorToken.pageBg, .hex("#faf9f7"))
        t.set(ColorToken.bandBg, .hex("#f2f0ec"))
        t.set(ColorToken.darkBg, .hex("#17140f"))
        t.set(ColorToken.darkCard, .hex("#211d17"))
        t.set(ColorToken.overlayBg, .hex("#1d1a15"))
        t.set(ColorToken.ink, .hex("#1c1917"))
        t.set(ColorToken.muted, .hex("#57534e"))
        t.set(ColorToken.faint, .hex("#a8a29e"))
        t.set(ColorToken.borderLight, .hex("#e7e5e0"))
        t.set(ColorToken.darkText, .hex("#f5f1ea"))
        t.set(ColorToken.darkMuted, .hex("#c9c3b8"))
        t.set(ColorToken.accent, .hex("#d9552f"))
        t.set(ColorToken.accentSoft, .hex("#e8794f"))
        t.set(ColorToken.onAccent, .hex("#fffaf5"))
        t.set(ColorToken.codeType, .hex("#dfb07e"))
        t.set(ColorToken.codeString, .hex("#a8b892"))
    }
}

public enum TutorialStyles {
    @RulesBuilder public static var rules: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.token(.pageBg))
            p.color(.token(.ink))
            p.fontFamily(Fonts.ui)
        }
        Rule(element: "a") { p in
            p.color(.current)
            p.textDecoration(.none)
        }
        Rule(class: "tut-content") { p in
            p.maxWidth(.px(1040)); p.margin(vertical: .zero, horizontal: .auto)
            p.padding(vertical: .zero, horizontal: .px(24))
        }
        // — nav / footer —
        Rule(class: "tut-nav") { p in
            p.background(.token(.pageBg))
            p.style("border-bottom", "1px solid var(--border-light)")
        }
        // (tut-brand: flex, gap 8, 17px 600; tut-nav-links: flex gap 28, 14px 500, color muted)
        // — chapter bar (dark) —
        Rule(class: "tut-chapterbar") { p in
            p.background(.token(.darkBg))
            p.style("border-bottom", "1px solid rgba(255,255,255,0.10)")
            p.position(.sticky); p.top(.zero); p.zIndex(40)
        }
        Rule(class: "tut-dropdown") { p in
            p.style("background", "rgba(255,255,255,0.06)")
            p.style("border", "1px solid rgba(255,255,255,0.14)")
            p.borderRadius(.px(8)); p.color(.token(.darkText))
            p.fontSize(.px(14)); p.cursor(.pointer)
            p.padding(vertical: .px(8), horizontal: .px(14))
        }
        Rule(class: "tut-pill") { p in
            p.style("border", "1px solid rgba(255,255,255,0.14)")
            p.borderRadius(.px(999)); p.color(.token(.darkMuted))
            p.fontSize(.px(13)); p.cursor(.pointer)
            p.padding(vertical: .px(7), horizontal: .px(14))
        }
        // — chapter menu overlay —
        Rule(class: "tut-menu") { p in
            p.display(.none)
            p.position(.absolute); p.style("top", "52px"); p.left(.zero)
            p.width(.px(340)); p.background(.token(.overlayBg))
            p.style("border", "1px solid rgba(255,255,255,0.12)")
            p.borderRadius(.px(14)); p.zIndex(50)
            p.padding(vertical: .px(20), horizontal: .px(12))
            p.boxShadow("0px 20px 50px -10px rgba(0,0,0,0.35)")
        }
        Rule(class: "tut-menu-open") { p in p.display(.block) }
        Rule(class: "tut-menu-item") { p in
            p.display(.block)
            p.style("color", "rgba(245,241,234,0.8)")
            p.fontSize(.px(14)); p.borderRadius(.px(8))
            p.padding(vertical: .px(8), horizontal: .px(12))
            p.hover { h in h.style("background", "rgba(255,255,255,0.05)") }
        }
        Rule(class: "tut-menu-item-active") { p in
            p.style("background", "rgba(255,255,255,0.08)")
            p.color(.token(.darkText)); p.fontWeight(.custom(600))
        }
        // — hero —
        Rule(class: "tut-hero") { p in
            p.background(.token(.darkBg)); p.color(.token(.darkText))
            p.padding(vertical: .px(104), horizontal: .zero)
        }
        Rule(class: "tut-hero-grid") { p in
            p.display(.grid); p.gridTemplateColumns("1fr 460px"); p.gap(.px(72))
            p.alignItems(.center)
        }
        Rule(class: "tut-hero-title") { p in
            p.fontSize(.px(54)); p.fontWeight(.bold)
            p.letterSpacing(.px(-1.5)); p.margin(.zero)
        }
        // (tut-hero-tagline 21/500 darkMuted; tut-hero-body 16 lh26 rgba(201,195,184,0.85);
        //  tut-hero-simple → same dark band, no grid, title 44px/-1px;
        //  tut-hero-actions flex gap 12 padding-top 8)
        Rule(class: "tut-btn-primary") { p in
            p.background(.token(.accent)); p.color(.token(.onAccent))
            p.borderRadius(.px(10)); p.fontSize(.px(15)); p.fontWeight(.custom(600))
            p.padding(vertical: .px(12), horizontal: .px(20))
            p.display(.inlineBlock); p.cursor(.pointer)
            p.style("border", "none")
        }
        Rule(class: "tut-btn-ghost") { p in
            p.style("border", "1px solid rgba(245,241,234,0.25)")
            p.color(.token(.darkText)); p.borderRadius(.px(10))
            p.fontSize(.px(15)); p.fontWeight(.custom(600))
            p.padding(vertical: .px(12), horizontal: .px(20))
            p.display(.inlineBlock); p.cursor(.pointer)
            p.style("background", "transparent")
        }
        // — kickers —
        Rule(class: "tut-kicker") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.fontWeight(.custom(500))
            p.letterSpacing(.px(1.5)); p.color(.token(.accent))
            p.style("text-transform", "uppercase")
        }
        Rule(class: "tut-kicker-dark") { p in p.color(.token(.accentSoft)) }
        // — dark cards (code + terminal) —
        Rule(class: "tut-card-dark") { p in
            p.background(.token(.darkCard))
            p.style("border", "1px solid rgba(255,255,255,0.08)")
            p.borderRadius(.px(14)); p.overflow(.hidden)
            p.boxShadow("0px 16px 40px -8px rgba(28,26,23,0.12)")
        }
        Rule(class: "tut-chrome") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.px(8))
            p.padding(vertical: .px(13), horizontal: .px(18))
        }
        Rule(class: "tut-dot")   { p in p.width(.px(10)); p.height(.px(10)); p.borderRadius(.px(999)) }
        Rule(class: "tut-dot-r") { p in p.background(.hex("#ff5f57")) }
        Rule(class: "tut-dot-y") { p in p.background(.hex("#febc2e")) }
        Rule(class: "tut-dot-g") { p in p.background(.hex("#28c840")) }
        Rule(class: "tut-chrome-title") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(12))
            p.style("color", "rgba(201,195,184,0.7)")
        }
        Rule(class: "tut-code") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(13)); p.color(.token(.darkText))
            p.padding(vertical: .zero, horizontal: .px(18))
            p.style("padding-bottom", "20px")
            p.overflow(.auto)
        }
        Rule(class: "tut-code-line") { p in p.style("line-height", "21px"); p.style("white-space", "pre") }
        Rule(class: "tok-kw")   { p in p.color(.token(.accentSoft)) }
        Rule(class: "tok-type") { p in p.color(.token(.codeType)) }
        Rule(class: "tok-str")  { p in p.color(.token(.codeString)) }
        Rule(class: "tok-num")  { p in p.color(.token(.codeString)) }
        Rule(class: "tok-cmt")  { p in p.color(.token(.faint)) }
        Rule(class: "tok-wrap") { p in p.color(.token(.accentSoft)) }
        // — terminal lines —
        Rule(class: "tut-term-line") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(13))
            p.style("line-height", "22px"); p.style("white-space", "pre")
        }
        Rule(class: "tut-term-prompt") { p in p.color(.token(.accentSoft)) }
        Rule(class: "tut-term-out")    { p in p.color(.token(.darkMuted)) }
        Rule(class: "tut-term-note")   { p in p.color(.token(.codeString)) }
        // — sections —
        Rule(class: "tut-section") { p in
            p.padding(vertical: .zero, horizontal: .zero)
            p.style("padding-top", "88px"); p.style("padding-bottom", "56px")
        }
        Rule(class: "tut-section-title") { p in
            p.fontSize(.px(30)); p.fontWeight(.bold); p.letterSpacing(.px(-0.5))
            p.margin(.zero); p.style("margin-top", "12px")
        }
        Rule(class: "tut-section-intro") { p in
            p.fontSize(.px(16)); p.style("line-height", "26px"); p.color(.token(.muted))
        }
        Rule(class: "tut-section-body") { p in
            p.display(.grid); p.gridTemplateColumns("1fr 480px"); p.gap(.px(56))
            p.style("margin-top", "40px"); p.alignItems(.start)
            p.media(.maxWidth(.px(1080))) { m in
                m.gridTemplateColumns("1fr")
            }
        }
        Rule(class: "tut-step") { p in
            p.display(.flex); p.gap(.px(16))
            p.padding(vertical: .px(16), horizontal: .zero)
            p.style("border-top", "1px solid var(--border-light)")
        }
        Rule(class: "tut-step-num") { p in
            p.fontFamily(Fonts.mono); p.fontSize(.px(13)); p.fontWeight(.custom(500))
            p.color(.token(.faint))
        }
        Rule(class: "tut-step-title") { p in
            p.fontSize(.px(15)); p.style("line-height", "23px"); p.color(.token(.muted))
            p.margin(.zero)
        }
        Rule(class: "tut-step-active") { p in p.style("--noop", "0") }  // marker class; children styled below
        Rule(class: "tut-step-detail") { p in
            p.fontSize(.px(14)); p.style("line-height", "22px"); p.color(.token(.faint))
            p.margin(.zero); p.style("margin-top", "4px")
        }
        Rule(class: "tut-panel") { p in
            p.position(.sticky); p.style("top", "96px")
            p.media(.maxWidth(.px(1080))) { m in m.position(.static) }
        }
        // — browser mock —
        Rule(class: "tut-browser") { p in
            p.background(.white); p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(14)); p.overflow(.hidden)
            p.boxShadow("0px 16px 40px -8px rgba(28,26,23,0.10)")
        }
        Rule(class: "tut-browser-chrome") { p in
            p.background(.token(.bandBg)); p.display(.flex); p.alignItems(.center)
            p.gap(.px(10)); p.padding(vertical: .px(12), horizontal: .px(16))
        }
        Rule(class: "tut-url") { p in
            p.background(.white); p.borderRadius(.px(6)); p.flexGrow(1)
            p.fontFamily(Fonts.mono); p.fontSize(.px(12)); p.color(.token(.muted))
            p.padding(vertical: .px(5), horizontal: .px(12))
        }
        Rule(class: "tut-shot") { p in p.display(.block); p.width(.percent(100)) }
        // — quiz —
        Rule(class: "tut-quiz") { p in
            p.background(.token(.bandBg))
            p.padding(vertical: .px(72), horizontal: .zero)
        }
        Rule(class: "tut-quiz-card") { p in
            p.background(.white); p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(14)); p.padding(.px(28))
            p.maxWidth(.px(720)); p.margin(vertical: .zero, horizontal: .auto)
        }
        Rule(class: "tut-option") { p in
            p.display(.flex); p.alignItems(.center); p.gap(.px(12))
            p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(10)); p.cursor(.pointer)
            p.padding(vertical: .px(13), horizontal: .px(16))
            p.fontFamily(Fonts.mono); p.fontSize(.px(14))
            p.style("margin-top", "14px")
        }
        Rule(class: "tut-option-selected") { p in
            p.style("background", "rgba(217,85,47,0.06)")
            p.style("border", "1.5px solid var(--accent)")
        }
        Rule(class: "tut-option-correct") { p in
            p.style("background", "rgba(90,140,60,0.08)")
            p.style("border", "1.5px solid #5a8c3c")
        }
        Rule(class: "tut-option-wrong") { p in
            p.style("background", "rgba(217,85,47,0.06)")
            p.style("border", "1.5px solid var(--accent)")
        }
        Rule(class: "tut-radio") { p in
            p.width(.px(18)); p.height(.px(18)); p.borderRadius(.px(999))
            p.style("border", "1.5px solid var(--border-light)")
            p.boxSizing(.borderBox)
        }
        Rule(class: "tut-quiz-submit") { p in
            p.background(.token(.accent)); p.color(.token(.onAccent))
            p.borderRadius(.px(10)); p.fontSize(.px(14)); p.fontWeight(.custom(600))
            p.padding(vertical: .px(11), horizontal: .px(20))
            p.style("border", "none"); p.cursor(.pointer)
            p.style("margin-top", "18px")
        }
        // (tut-explain 14px lh22; -ok color #5a8c3c, -no color accent)
        // — CTA / footer / overview: transcribe header values —
        Rule(class: "tut-cta-card") { p in
            p.background(.token(.darkBg)); p.color(.token(.darkText))
            p.borderRadius(.px(18)); p.display(.flex); p.alignItems(.center); p.gap(.px(48))
            p.padding(vertical: .px(44), horizontal: .px(48))
        }
        Rule(class: "tut-footer") { p in
            p.style("border-top", "1px solid var(--border-light)")
            p.padding(vertical: .px(28), horizontal: .zero)
            p.fontSize(.px(13)); p.color(.token(.muted))
        }
        Rule(class: "tut-cards") { p in
            p.display(.grid); p.gridTemplateColumns("repeat(3, 1fr)"); p.gap(.px(20))
            p.media(.maxWidth(.px(1080))) { m in m.gridTemplateColumns("1fr") }
        }
        Rule(class: "tut-card-link") { p in
            p.display(.block); p.background(.white)
            p.style("border", "1px solid var(--border-light)")
            p.borderRadius(.px(14)); p.padding(.px(24))
            p.hover { h in h.style("border-color", "var(--accent)") }
        }
        // …remaining contract classes: same mechanical transcription of the
        // header's token table (sizes/colors listed there are normative).
    }
}
```

Active-step emphasis (no descendant selectors in `Rule` — mark children directly): `StepList` (Task 7) applies `tut-step-num`+inline `.color(.token(.accent))` and `tut-step-title`+`.color(.token(.ink)).fontWeight(.custom(600))` on the ACTIVE step's children instead of a CSS descendant rule.

**IMPLEMENTER NOTE:** every `// (…)`-comment above is an instruction to write those rules out in full with the header table's values — the final file contains no such comments and covers every class in the contract list.

- [ ] **Step 2: Write ThemeTests**

`Sites/Tutorial/Tests/TutorialKitTests/ThemeTests.swift`:

```swift
import Testing
import SwiftWUI
@testable import TutorialKit

@Suite struct ThemeTests {
    @Test @MainActor func stylesheetRegistersAllContractClasses() {
        struct Probe: Tag { var body: some Tag { Div { Text("x") } } }
        let backend = MockBackend()
        let rt = Runtime(backend: backend, container: backend.container,
                         root: Probe(), scheduleMicrotask: { $0() },
                         globalStyles: TutorialStyles.rules,
                         themes: [TutorialTheme.definition])
        rt.mount()
        let css = rt._registryText
        // :root theme block carries every token
        for token in ["--page-bg", "--dark-bg", "--accent", "--code-string", "--border-light"] {
            #expect(css.contains(token), "missing \(token)")
        }
        // spot-check load-bearing selectors incl. sticky + breakpoint collapse
        for cls in ["tut-content", "tut-hero", "tut-panel", "tut-section-body",
                    "tut-option-selected", "tut-menu-open", "tok-kw", "tut-card-dark"] {
            #expect(css.contains(".\(cls)"), "missing rule .\(cls)")
        }
        #expect(css.contains("sticky"))
        #expect(css.contains("max-width: 1080px"))
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
cd Sites/Tutorial && swift test    # expected: ThemeTests + Task-1 suite pass
git add Sites/Tutorial && git commit -m "feat(tutorial): design tokens, theme, global stylesheet

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: SwiftHighlighter

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Support/SwiftHighlighter.swift`
- Test: `Sites/Tutorial/Tests/TutorialKitTests/HighlighterTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `SwiftHighlighter.tokenize(line: String) -> [SwiftHighlighter.Token]` with `Token(text: String, kind: Kind)`, `Kind: { plain, keyword, type, string, comment, number, wrapper }`, and `Kind.cssClass: String?` (`nil` for plain, else `tok-kw/tok-type/tok-str/tok-num/tok-cmt/tok-wrap`). PanelView (Task 5) renders tokens; the tokenizer itself never touches Tags.

- [ ] **Step 1: Write the tokenizer**

Deterministic single-pass state machine per line — identical output on native/ssg and wasm (spec D8). No multiline constructs (tutorial snippets contain none; a `/*` falls out as plain).

```swift
/// Line-based Swift/terminal syntax tokenizer (spec D8). Pure function of the
/// input line — determinism is what keeps ssg output and hydrated DOM identical.
public enum SwiftHighlighter {
    public enum Kind: Equatable, Sendable {
        case plain, keyword, type, string, comment, number, wrapper
        public var cssClass: String? {
            switch self {
            case .plain: return nil
            case .keyword: return "tok-kw"
            case .type: return "tok-type"
            case .string: return "tok-str"
            case .comment: return "tok-cmt"
            case .number: return "tok-num"
            case .wrapper: return "tok-wrap"
            }
        }
    }
    public struct Token: Equatable, Sendable {
        public let text: String
        public let kind: Kind
        public init(_ text: String, _ kind: Kind) { self.text = text; self.kind = kind }
    }

    static let keywords: Set<String> = [
        "import", "struct", "class", "enum", "extension", "protocol", "func",
        "var", "let", "some", "return", "if", "else", "guard", "for", "in",
        "while", "switch", "case", "default", "static", "public", "private",
        "init", "self", "true", "false", "nil", "throws", "try", "await", "async",
    ]

    public static func tokenize(line: String) -> [Token] {
        var tokens: [Token] = []
        var plain = ""
        func flushPlain() { if !plain.isEmpty { tokens.append(Token(plain, .plain)); plain = "" } }

        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            // comment to end of line
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                flushPlain()
                tokens.append(Token(String(chars[i...]), .comment))
                return tokens
            }
            // string literal (interpolation stays inside the string token — matches the design)
            if c == "\"" {
                flushPlain()
                var j = i + 1
                var s = "\""
                while j < chars.count {
                    s.append(chars[j])
                    if chars[j] == "\"" && chars[j - 1] != "\\" { break }
                    j += 1
                }
                tokens.append(Token(s, .string))
                i = j + 1
                continue
            }
            // property wrapper / attribute
            if c == "@" {
                flushPlain()
                var j = i + 1
                while j < chars.count, chars[j].isLetter || chars[j].isNumber { j += 1 }
                tokens.append(Token(String(chars[i..<j]), .wrapper))
                i = j
                continue
            }
            // identifier / keyword / TypeName
            if c.isLetter || c == "_" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                let word = String(chars[i..<j])
                if keywords.contains(word) {
                    flushPlain(); tokens.append(Token(word, .keyword))
                } else if word.first!.isUppercase {
                    flushPlain(); tokens.append(Token(word, .type))
                } else {
                    plain += word
                }
                i = j
                continue
            }
            // number
            if c.isNumber {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." || chars[j] == "_" { j += 1 }
                flushPlain(); tokens.append(Token(String(chars[i..<j]), .number))
                i = j
                continue
            }
            plain.append(c)
            i += 1
        }
        flushPlain()
        return tokens
    }
}
```

- [ ] **Step 2: Write golden tests**

`Sites/Tutorial/Tests/TutorialKitTests/HighlighterTests.swift`:

```swift
import Testing
@testable import TutorialKit

@Suite struct HighlighterTests {
    private func kinds(_ line: String) -> [(String, SwiftHighlighter.Kind)] {
        SwiftHighlighter.tokenize(line: line).map { ($0.text, $0.kind) }
    }

    @Test func stateDeclaration() {
        let t = kinds("    @State var count = 0")
        #expect(t.map(\.0) == ["    ", "@State", " ", "var", " count = ", "0"])
        #expect(t.map(\.1) == [.plain, .wrapper, .plain, .keyword, .plain, .number])
    }

    @Test func structHeader() {
        let t = kinds("struct Counter: Tag {")
        #expect(t.map(\.0) == ["struct", " ", "Counter", ": ", "Tag", " {"])
        #expect(t.map(\.1) == [.keyword, .plain, .type, .plain, .type, .plain])
    }

    @Test func stringWithInterpolationStaysOneToken() {
        let t = kinds(#"H1("Count: \(count)")"#)
        #expect(t.map(\.0) == ["H1", "(", #""Count: \(count)""#, ")"])
        #expect(t.map(\.1) == [.type, .plain, .string, .plain])
    }

    @Test func commentSwallowsRestOfLine() {
        let t = kinds("let x = 1 // trailing")
        #expect(t.last?.1 == .comment)
        #expect(t.last?.0 == "// trailing")
    }

    @Test func deterministicAcrossCalls() {
        let line = #"Route("/docs/:page") { params in Docs() }"#
        #expect(kinds(line).map(\.0) == kinds(line).map(\.0))
        #expect(kinds(line).map(\.1) == kinds(line).map(\.1))
    }

    @Test func roundTripPreservesText() {
        for line in ["struct Hello: Tag {", #"    P { "Knock, knock." }"#,
                     "        .padding(.px(12))", "}"] {
            let joined = SwiftHighlighter.tokenize(line: line).map(\.text).joined()
            #expect(joined == line)
        }
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
cd Sites/Tutorial && swift test
git add Sites/Tutorial && git commit -m "feat(tutorial): deterministic Swift syntax highlighter

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 4: Chrome components — SiteNav, SiteFooter, HeroView, NextChapterCTA

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/SiteNav.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/SiteFooter.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/HeroView.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/NextChapterCTA.swift`
- Test: `Sites/Tutorial/Tests/TutorialKitTests/ComponentGoldenTests.swift`

**Interfaces:**
- Consumes: `Chapter`/`Curriculum` (Task 1), classes+tokens (Task 2), `PanelView` — NOT yet available; HeroView takes the already-built panel as a generic child (see below), so Task 4 does not depend on Task 5.
- Produces: `SiteNav()`, `SiteFooter()`, `HeroView(chapter:)` (rendering `heroPanel` via `PanelView` is wired in Task 9 — here `HeroView` renders the hero WITHOUT the panel column when `heroPanel == nil` and leaves a `Div(class: "tut-hero-panel-slot")` marker; Task 9 does not change this file — see the design note below), `NextChapterCTA(chapter:)`.
- GitHub URL constant: `SiteLinks.repo = "https://github.com/kazimgadzhiev/SwiftWUI"`, `SiteLinks.docs = repo + "/tree/main/docs"`, `SiteLinks.examples = repo + "/tree/main/Examples"` (spec §6: GitHub paths until real surfaces exist). Put `SiteLinks` in `SiteNav.swift`.

**Design note (dependency inversion to keep tasks independent):** `HeroView` takes `panel: Panel?` and renders it through a closure-free subcomponent it does not own. To avoid a Task-4→Task-5 dependency, `HeroView` is generic over its panel content: `HeroView<PanelContent: Tag>` with `init(chapter: Chapter, @TagBuilder panel: () -> PanelContent)`; Task 9's `ChapterPage` passes `PanelView(panel:)` in. For the no-panel case there is a convenience `init(chapter: Chapter) where PanelContent == EmptyTag`.

- [ ] **Step 1: Write the four components**

`SiteNav.swift`:

```swift
import SwiftWUI

public enum SiteLinks {
    public static let repo = "https://github.com/kazimgadzhiev/SwiftWUI"
    public static let docs = repo + "/tree/main/docs"
    public static let examples = repo + "/tree/main/Examples"
}

/// Top navigation (Figma 3:2): light bar, brand left, links right.
public struct SiteNav: Tag {
    public init() {}
    public var body: some Tag {
        Nav(class: "tut-nav") {
            Div(class: "tut-content tut-nav-inner") {
                Link("/") {
                    Span(class: "tut-brand") { "SwiftWUI" }
                }
                Div(class: "tut-nav-links") {
                    A(href: SiteLinks.docs) { "Docs" }
                    Link("/") { Span { "Tutorials" } }
                    A(href: SiteLinks.examples) { "Examples" }
                    A(href: SiteLinks.repo) { "GitHub" }
                }
            }
        }
    }
}
```

(`tut-nav-inner` joins the class contract: flex, height 64px, align center, gap 32, brand flex-grows via `tut-nav-links` margin-left auto — add these two rules to `TutorialStyles` in THIS task; the Task-2 contract list already reserves the names.)

`SiteFooter.swift`:

```swift
import SwiftWUI

/// Footer (Figma 9:53).
public struct SiteFooter: Tag {
    public init() {}
    public var body: some Tag {
        Footer(class: "tut-footer") {
            Div(class: "tut-content tut-footer-inner") {
                Span { "SwiftWUI — Swift on the web, SwiftUI in spirit." }
                Div(class: "tut-footer-links") {
                    A(href: SiteLinks.docs) { "Docs" }
                    A(href: SiteLinks.repo) { "GitHub" }
                    A(href: SiteLinks.repo + "/blob/main/LICENSE") { "MIT License" }
                }
            }
        }
    }
}
```

`HeroView.swift`:

```swift
import SwiftWUI

/// Chapter hero. Big variant (Figma 3:15): text + actions left, panel right.
/// Simple variant (Figma 11:51): kicker + title + tagline, no grid.
public struct HeroView<PanelContent: Tag>: Tag {
    let chapter: Chapter
    let panelContent: PanelContent

    public init(chapter: Chapter, @TagBuilder panel: () -> PanelContent) {
        self.chapter = chapter
        self.panelContent = panel()
    }

    public var body: some Tag {
        Header(class: "tut-hero") {
            Div(class: "tut-content") {
                if chapter.heroPanel != nil {
                    Div(class: "tut-hero-grid") {
                        Div(class: "tut-hero-text") {
                            Span(class: "tut-kicker tut-kicker-dark") {
                                "\(chapter.kicker) · \(chapter.minutes) MIN"
                            }
                            H1(chapter.title, class: "tut-hero-title")
                            P(class: "tut-hero-tagline") { Text(chapter.tagline) }
                            if let heroBody = chapter.body {
                                P(class: "tut-hero-body") { Text(heroBody) }
                            }
                            Div(class: "tut-hero-actions") {
                                if let first = chapter.sections.first {
                                    A(href: "#\(first.anchor)", class: "tut-btn-primary") { "Start the tutorial" }
                                }
                                A(href: SiteLinks.repo, class: "tut-btn-ghost") { "View on GitHub" }
                            }
                        }
                        panelContent
                    }
                } else {
                    Div(class: "tut-hero-simple") {
                        Span(class: "tut-kicker tut-kicker-dark") { Text(chapter.kicker) }
                        H1(chapter.title, class: "tut-hero-title tut-hero-title-simple")
                        P(class: "tut-hero-tagline") { Text(chapter.tagline) }
                    }
                }
            }
        }
    }
}

extension HeroView where PanelContent == EmptyTag {
    public init(chapter: Chapter) { self.init(chapter: chapter) { EmptyTag() } }
}
```

(`tut-hero-title-simple` = 44px/-1px — add rule now.)

`NextChapterCTA.swift`:

```swift
import SwiftWUI

/// Next-chapter CTA (Figma 9:43). `chapter` is the CURRENT page; the target
/// comes from Curriculum.next(after:). Last page wraps to the overview.
public struct NextChapterCTA: Tag {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }

    public var body: some Tag {
        if let next = Curriculum.next(after: chapter) {
            Div(class: "tut-cta") {
                Div(class: "tut-content") {
                    Div(class: "tut-cta-card") {
                        Div(class: "tut-cta-text") {
                            Span(class: "tut-kicker tut-kicker-dark") {
                                next.kind == .overview ? "EXPLORE MORE" : "NEXT CHAPTER"
                            }
                            H2(next.kind == .overview ? "Explore more tutorials" : next.title,
                               class: "tut-cta-title")
                            P(class: "tut-cta-tagline") { Text(next.tagline) }
                        }
                        Link(next.path) {
                            Span(class: "tut-btn-primary") { "Continue →" }
                        }
                    }
                }
            }
        }
    }
}
```

(`tut-cta` = padding-y 88px wrapper; `tut-cta-text` flex-grow 1. Add remaining CTA rules per header table.)

- [ ] **Step 2: Write golden tests**

Append to `ComponentGoldenTests.swift`:

```swift
import Testing
import SwiftWUI
@testable import TutorialKit

@Suite @MainActor struct ChromeComponentTests {
    @Test func navRendersBrandAndLinks() {
        let html = HTMLRenderer.render(SiteNav())
        #expect(html.contains("SwiftWUI"))
        for label in ["Docs", "Tutorials", "Examples", "GitHub"] { #expect(html.contains(label)) }
        #expect(html.contains(SiteLinks.repo))
        #expect(html.contains("data-swui-link"))   // Tutorials is an intercepted SPA link
    }

    @Test func footerRendersTagline() {
        let html = HTMLRenderer.render(SiteFooter())
        #expect(html.contains("SwiftUI in spirit"))
        #expect(html.contains("MIT License"))
    }

    @Test func bigHeroRendersActionsAndGrid() {
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        // Big-hero shape needs heroPanel != nil; fixture stands in until Task 10 authors ch4.
        let fixture = Chapter(slug: ch.slug, track: ch.track, kicker: ch.kicker,
                              title: ch.title, tagline: ch.tagline, body: ch.body,
                              minutes: ch.minutes, kind: .chapter,
                              heroPanel: .terminal(title: "x", lines: []),
                              sections: [TutorialKit.Section(anchor: "toolchain", kicker: "01",
                                                 title: "t", steps: [Step("s")],
                                                 panel: .terminal(title: "x", lines: []))])
        let html = HTMLRenderer.render(HeroView(chapter: fixture) { Div(class: "panel-probe") { Text("P") } })
        #expect(html.contains("tut-hero-grid"))
        #expect(html.contains("GETTING STARTED · 25 MIN"))
        #expect(html.contains("Start the tutorial"))
        #expect(html.contains("#toolchain"))
        #expect(html.contains("panel-probe"))
    }

    @Test func simpleHeroHasNoGridOrActions() {
        let ch = Curriculum.chapter(slug: "style-in-swift")!
        let html = HTMLRenderer.render(HeroView(chapter: ch))
        #expect(html.contains("tut-hero-simple"))
        #expect(!html.contains("tut-hero-grid"))
        #expect(!html.contains("Start the tutorial"))
    }

    @Test func ctaTargetsNextChapterAndLastWrapsToOverview() {
        let styles = Curriculum.chapter(slug: "hello-swiftwui")!
        let html = HTMLRenderer.render(NextChapterCTA(chapter: styles))
        #expect(html.contains("NEXT CHAPTER"))
        #expect(html.contains("/tutorials/wrap-up-explore"))

        let last = Curriculum.chapters.last!
        let lastHTML = HTMLRenderer.render(NextChapterCTA(chapter: last))
        #expect(lastHTML.contains("Explore more tutorials"))
        #expect(lastHTML.contains("href=\"/\""))

        let overviewHTML = HTMLRenderer.render(NextChapterCTA(chapter: Curriculum.overview))
        #expect(!overviewHTML.contains("tut-cta-card"))   // overview has no CTA
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
cd Sites/Tutorial && swift test
git add Sites/Tutorial && git commit -m "feat(tutorial): nav, footer, hero, next-chapter CTA

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: PanelView — code card / terminal / browser mock

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/PanelView.swift`
- Test: append to `Sites/Tutorial/Tests/TutorialKitTests/ComponentGoldenTests.swift`

**Interfaces:**
- Consumes: `Panel`/`CodePanel`/`TermLine` (Task 1), `SwiftHighlighter` (Task 3), classes (Task 2).
- Produces: `PanelView(panel: Panel)` — the ONLY renderer of panels; `ChromeBar(title: String)` (shared mac-chrome row); `CodeView(code: String)`.

- [ ] **Step 1: Write PanelView.swift**

```swift
import SwiftWUI

/// Mac-window chrome row: three dots + title (Figma 3:28).
struct ChromeBar: Tag {
    let title: String
    var body: some Tag {
        Div(class: "tut-chrome") {
            Span(class: "tut-dot tut-dot-r")
            Span(class: "tut-dot tut-dot-y")
            Span(class: "tut-dot tut-dot-g")
            Span(class: "tut-chrome-title") { Text(title) }
        }
    }
}

/// Highlighted code block. Line split is deterministic; ForEach keys by line
/// index — content is static per page, so index identity is stable (no reorders).
struct CodeView: Tag {
    let code: String
    var body: some Tag {
        Div(class: "tut-code") {
            ForEach(Array(code.split(separator: "\n", omittingEmptySubsequences: false).enumerated()),
                    id: \.offset) { item in
                Div(class: "tut-code-line") {
                    ForEach(Array(SwiftHighlighter.tokenize(line: String(item.element)).enumerated()),
                            id: \.offset) { tok in
                        if let cls = tok.element.kind.cssClass {
                            Span(class: cls) { Text(tok.element.text) }
                        } else {
                            Text(tok.element.text)
                        }
                    }
                    // an empty line still needs height:
                    if item.element.isEmpty { Text(" ") }
                }
            }
        }
    }
}

/// One visual panel (spec §6): code card, terminal, or browser mock.
public struct PanelView: Tag {
    let panel: Panel
    public init(panel: Panel) { self.panel = panel }

    public var body: some Tag {
        switch panel {
        case .code(let card):
            Div(class: "tut-card-dark") {
                ChromeBar(title: card.file)
                CodeView(code: card.code)
            }
        case .terminal(let title, let lines):
            Div(class: "tut-card-dark") {
                ChromeBar(title: title)
                Div(class: "tut-code") {
                    ForEach(Array(lines.enumerated()), id: \.offset) { item in
                        Div(class: "tut-term-line") {
                            switch item.element.kind {
                            case .command:
                                Span(class: "tut-term-prompt") { "$" }
                                Text(" " + item.element.text)
                            case .output:
                                Span(class: "tut-term-out") { Text(item.element.text) }
                            case .note:
                                Span(class: "tut-term-note") { Text(item.element.text) }
                            }
                        }
                    }
                }
            }
        case .browser(let url, let screenshot):
            Div(class: "tut-browser") {
                Div(class: "tut-browser-chrome") {
                    Span(class: "tut-dot tut-dot-r")
                    Span(class: "tut-dot tut-dot-y")
                    Span(class: "tut-dot tut-dot-g")
                    Div(class: "tut-url") { Text(url) }
                }
                Img(src: "/assets/\(screenshot)", alt: "App preview at \(url)", class: "tut-shot")
            }
        }
    }
}
```

- [ ] **Step 2: Golden tests (append to ComponentGoldenTests.swift)**

```swift
@Suite @MainActor struct PanelViewTests {
    @Test func codePanelHighlights() {
        let card = CodePanel(file: "Counter.swift",
                             code: "struct Counter: Tag {\n    @State var count = 0\n}",
                             origin: .fragment(path: "Examples/Counter/Sources/main.swift"))
        let html = HTMLRenderer.render(PanelView(panel: .code(card)))
        #expect(html.contains("Counter.swift"))
        #expect(html.contains("tok-kw"))     // struct
        #expect(html.contains("tok-wrap"))   // @State
        #expect(html.contains("tut-card-dark"))
    }

    @Test func terminalPanelStylesLineKinds() {
        let html = HTMLRenderer.render(PanelView(panel: .terminal(title: "zsh — counter", lines: [
            TermLine(.command, "swiftwui init counter"),
            TermLine(.output, "  created counter/Package.swift"),
            TermLine(.note, "> dev server on http://localhost:8080"),
        ])))
        #expect(html.contains("zsh — counter"))
        #expect(html.contains("tut-term-prompt"))
        #expect(html.contains("tut-term-out"))
        #expect(html.contains("tut-term-note"))
    }

    @Test func browserPanelRendersShot() {
        let html = HTMLRenderer.render(PanelView(panel: .browser(url: "localhost:8080",
                                                                 screenshot: "screens/counter-3.png")))
        #expect(html.contains("/assets/screens/counter-3.png"))
        #expect(html.contains("localhost:8080"))
        #expect(html.contains("tut-browser-chrome"))
    }

    @Test func ssgAndSecondRenderAreIdentical() {
        // determinism proxy for hydration adoption (spec D8)
        let card = CodePanel(file: "A.swift", code: "let a = \"x\" // c",
                             origin: .fragment(path: "Examples/Counter/Sources/main.swift"))
        let a = HTMLRenderer.render(PanelView(panel: .code(card)))
        let b = HTMLRenderer.render(PanelView(panel: .code(card)))
        #expect(a == b)
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
cd Sites/Tutorial && swift test
git add Sites/Tutorial && git commit -m "feat(tutorial): panel renderer — code card, terminal, browser mock

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 6: ChapterBar + ChapterMenu (interactive dropdowns)

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/ChapterMenu.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/ChapterBar.swift`
- Test: `Sites/Tutorial/Tests/TutorialKitTests/InteractionTests.swift`

**Interfaces:**
- Consumes: `Curriculum`, `Chapter`, `Track` (Task 1), classes (Task 2).
- Produces: `ChapterBar(chapter: Chapter)` (owns both dropdown `@State`s), `ChapterMenu(currentSlug: String)` (pure render of the overlay, Figma 10:26).

- [ ] **Step 1: Write ChapterMenu.swift (pure)**

```swift
import SwiftWUI

/// Chapter-menu overlay (Figma 10:26): all 12 curriculum entries grouped by
/// track, current entry highlighted with an accent dot.
public struct ChapterMenu: Tag {
    let currentSlug: String
    public init(currentSlug: String) { self.currentSlug = currentSlug }

    public var body: some Tag {
        ForEach(Track.allCases, id: \.rawValue) { track in
            Div(class: "tut-menu-group") {
                Span(class: "tut-menu-label") { Text(track.rawValue.uppercased()) }
                ForEach(Curriculum.chapters.filter { $0.track == track }, id: \.slug) { ch in
                    Link(ch.path) {
                        Span(class: ch.slug == currentSlug
                             ? "tut-menu-item tut-menu-item-active"
                             : "tut-menu-item") {
                            if ch.slug == currentSlug {
                                Span(class: "tut-menu-dot")
                            }
                            Text(ch.title)
                        }
                    }
                }
            }
        }
    }
}
```

(`tut-menu-dot`: 6px accent circle, inline-block, margin-right 8 — add rule.)

- [ ] **Step 2: Write ChapterBar.swift**

```swift
import SwiftWUI

/// Dark bar under the nav (Figma 7:26): series label, chapter dropdown
/// (opens the ChapterMenu overlay), section dropdown (in-page anchors).
/// Both dropdowns are live @State; prerendered state = both closed (spec §11).
public struct ChapterBar: Tag {
    let chapter: Chapter
    @State private var menuOpen = false
    @State private var sectionsOpen = false

    public init(chapter: Chapter) { self.chapter = chapter }

    public var body: some Tag {
        Div(class: "tut-chapterbar") {
            Div(class: "tut-content tut-chapterbar-inner") {
                Span(class: "tut-series") {
                    "SwiftWUI "
                    Span(class: "tut-series-accent") { "Tutorials" }
                }
                Span(class: "tut-divider")
                Div(class: "tut-dropdown-wrap") {
                    Button(class: "tut-dropdown", onClick: { menuOpen.toggle(); sectionsOpen = false }) {
                        Text(chapter.kind == .overview ? "All chapters" : chapter.title)
                        Text(" ▾")
                    }
                    Div(class: menuOpen ? "tut-menu tut-menu-open" : "tut-menu") {
                        ChapterMenu(currentSlug: chapter.slug)
                    }
                }
                Div(class: "tut-spacer") {}
                if !chapter.sections.isEmpty {
                    Div(class: "tut-dropdown-wrap") {
                        Button(class: "tut-pill", onClick: { sectionsOpen.toggle(); menuOpen = false }) {
                            Text("Sections ▾")
                        }
                        Div(class: sectionsOpen ? "tut-menu tut-menu-open" : "tut-menu") {
                            ForEach(chapter.sections, id: \.anchor) { s in
                                A(href: "#\(s.anchor)", class: "tut-menu-item") { Text(s.title) }
                            }
                        }
                    }
                }
            }
        }
    }
}
```

(New rules this task: `tut-chapterbar-inner` flex/56px/align-center/gap-20; `tut-series` 15px 600 darkText; `tut-series-accent` accentSoft; `tut-divider` 1×20px rgba(255,255,255,0.15); `tut-dropdown-wrap` position relative; `tut-spacer` flex-grow 1. The section-dropdown `tut-menu` reuses overlay styling — on the right side add `right: 0; left: auto` via a `tut-menu-right` class if visual check needs it; keep left-anchored initially.)

- [ ] **Step 3: Interaction tests**

`Sites/Tutorial/Tests/TutorialKitTests/InteractionTests.swift`:

```swift
import Testing
import SwiftWUI
@testable import TutorialKit

@Suite @MainActor struct ChapterBarTests {
    @Test func menuListsAll12EntriesGroupedByTrack() {
        let html = HTMLRenderer.render(ChapterMenu(currentSlug: "hello-swiftwui"))
        for ch in Curriculum.chapters { #expect(html.contains(ch.title)) }
        for label in ["WELCOME", "EXPLORE SWIFTWUI", "STYLES", "ROUTING", "SHIP"] {
            #expect(html.contains(label))
        }
        #expect(html.contains("tut-menu-item-active"))
    }

    @Test func chapterDropdownTogglesOverlay() {
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        let (rt, backend, sched) = makeRuntime(ChapterBar(chapter: ch))
        rt.mount()
        // prerendered state: closed
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
        let toggle = findAll(backend.container, tag: "button")[0]
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") != nil)
        rt.dispatch(toggle.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-menu-open") == nil)
    }

    @Test func sectionDropdownHiddenWithoutSections() {
        let wrapUp = Curriculum.chapter(slug: "wrap-up-ship")!   // stub: no sections
        let html = HTMLRenderer.render(ChapterBar(chapter: wrapUp))
        #expect(!html.contains("Sections ▾"))
    }
}
```

- [ ] **Step 4: Run + commit**

```bash
cd Sites/Tutorial && swift test
git add Sites/Tutorial && git commit -m "feat(tutorial): chapter bar with menu overlay and section dropdown

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: SectionView + StepList + ScrollSpy

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Support/ScrollSpy.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/StepList.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/SectionView.swift`
- Test: append to `Sites/Tutorial/Tests/TutorialKitTests/InteractionTests.swift`

**Interfaces:**
- Consumes: `Section`/`Step`/`Panel` (Task 1), `PanelView` (Task 5), classes (Task 2).
- Produces: `SectionView(section: Section, index: Int)`; `StepList(section: Section, activeStep: Int)`; `Section.activePanel(step: Int) -> Panel` (model helper — pure, tested natively); `ScrollSpy` (wasm-only class, native no-op shim); step DOM id convention `"\(section.anchor)-step-\(i)"`.

- [ ] **Step 1: Add the pure panel-selection helper to ContentModel.swift**

```swift
public extension Section {
    /// Panel to show when `step` is active: the step's override or the
    /// section default. Out-of-range (pre-mount) falls back to the default.
    func activePanel(step: Int) -> Panel {
        guard steps.indices.contains(step) else { return panel }
        return steps[step].panel ?? panel
    }
}
```

- [ ] **Step 2: Write ScrollSpy.swift**

wasm: one IntersectionObserver over the section's step elements; fires the callback with the topmost intersecting step index. Native/ssg: inert stub with the same API (spec D9).

```swift
#if arch(wasm32)
import JavaScriptKit

/// Site-local scrollspy (spec D9 — deliberately NOT a framework feature).
/// JSClosure is retained for the component's lifetime (v1 lesson: a JSClosure
/// must outlive its attachment).
@MainActor
public final class ScrollSpy {
    private var observer: JSObject?
    private var callback: JSClosure?

    public init() {}

    /// Observes `#\(anchor)-step-\(i)` for i in 0..<stepCount.
    /// `onActive` receives the smallest intersecting step index.
    public func attach(anchor: String, stepCount: Int, onActive: @escaping (Int) -> Void) {
        detach()
        let document = JSObject.global.document
        let cb = JSClosure { args in
            guard let entries = args.first?.object else { return .undefined }
            let n = Int(entries.length.number ?? 0)
            var best: Int? = nil
            for i in 0..<n {
                guard let entry = entries[i].object,
                      entry.isIntersecting.boolean == true,
                      let id = entry.target.id.string,
                      let idx = Int(id.split(separator: "-").last.map(String.init) ?? "")
                else { continue }
                best = best.map { min($0, idx) } ?? idx
            }
            if let best { onActive(best) }
            return .undefined
        }
        let options = JSObject.global.Object.function!.new()
        // active band: a step becomes active when its box crosses the
        // 25%–45% viewport band (tuned in smoke, spec §13)
        options.rootMargin = .string("-25% 0px -55% 0px")
        let obs = JSObject.global.IntersectionObserver.function!.new(cb, options)
        for i in 0..<stepCount {
            let el = document.getElementById("\(anchor)-step-\(i)")
            if el.isNull || el.isUndefined { continue }
            _ = obs.observe!(el)
        }
        observer = obs
        callback = cb
    }

    public func detach() {
        if let observer { _ = observer.disconnect?() }
        observer = nil
        callback = nil
    }
}
#else
/// Native/ssg shim: same API, does nothing — prerendered pages show step 0.
@MainActor
public final class ScrollSpy {
    public init() {}
    public func attach(anchor: String, stepCount: Int, onActive: @escaping (Int) -> Void) {}
    public func detach() {}
}
#endif
```

- [ ] **Step 3: Write StepList.swift + SectionView.swift**

```swift
import SwiftWUI

/// Left column of a section (Figma 4:11). The ACTIVE step gets emphasized
/// number/title colors inline (Rule has no descendant selectors).
/// Two-digit step number without Foundation (no String(format:) on wasm —
/// TodoMVC convention: no Foundation in wasm targets).
func stepNumber(_ i: Int) -> String { (i < 9 ? "0" : "") + String(i + 1) }

public struct StepList: Tag {
    let section: Section
    let activeStep: Int

    public var body: some Tag {
        Div(class: "tut-steps") {
            ForEach(Array(section.steps.enumerated()), id: \.offset) { item in
                Div(id: "\(section.anchor)-step-\(item.offset)",
                    class: item.offset == activeStep ? "tut-step tut-step-active" : "tut-step") {
                    if item.offset == activeStep {
                        Span(class: "tut-step-num") { Text(stepNumber(item.offset)) }
                            .color(.token(.accent))
                        Div {
                            P(class: "tut-step-title") { Text(item.element.title) }
                                .color(.token(.ink)).fontWeight(.custom(600))
                            if let detail = item.element.detail {
                                P(class: "tut-step-detail") { Text(detail) }
                            }
                        }
                    } else {
                        Span(class: "tut-step-num") { Text(stepNumber(item.offset)) }
                        Div {
                            P(class: "tut-step-title") { Text(item.element.title) }
                            if let detail = item.element.detail {
                                P(class: "tut-step-detail") { Text(detail) }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One tutorial section (Figma 4:5): header + [steps | sticky panel].
/// activeStep drives both the step highlight and the panel swap (spec D2).
/// Initial-state contract (spec §6): activeStep = 0 on BOTH backends; ssg
/// renders step 0 active; scrollspy mutates state only post-mount.
public struct SectionView: Tag {
    let section: Section
    let index: Int
    @State private var activeStep = 0
    @State private var spy = ScrollSpy()

    public init(section: Section, index: Int) {
        self.section = section
        self.index = index
    }

    public var body: some Tag {
        // NOTE: body is a @TagBuilder — no `return` statements. The whole
        // section is ONE chained expression so the effect modifiers apply once.
        SwiftWUI.Section(id: section.anchor, class: "tut-section") {
            Div(class: "tut-content") {
                Div(class: "tut-section-header") {
                    Span(class: "tut-kicker") { Text(section.kicker) }
                    H2(section.title, class: "tut-section-title")
                    if let intro = section.intro {
                        P(class: "tut-section-intro") { Text(intro) }
                    }
                }
                Div(class: "tut-section-body") {
                    StepList(section: section, activeStep: activeStep)
                    Div(class: "tut-panel") {
                        PanelView(panel: section.activePanel(step: activeStep))
                    }
                }
            }
        }
        .onAppear { [section, spy] in
            spy.attach(anchor: section.anchor, stepCount: section.steps.count) { idx in
                activeStep = idx
            }
        }
        .onDisappear { [spy] in spy.detach() }
    }
}
```

NAME COLLISION NOTE: the model type `TutorialKit.Section` collides with the HTML tag `SwiftWUI.Section` inside this file. Disambiguate the tag as `SwiftWUI.Section(id:class:)` at the one use site (keep the model name unqualified). If `@State private var spy = ScrollSpy()` trips the Mirror-based state graft (ScrollSpy is a class — allowed, StateBox stores any value), fall back to creating the spy inside `.onAppear` and storing it in a `@State var spyBox: ScrollSpy?`.

- [ ] **Step 4: Tests (append to InteractionTests.swift)**

```swift
@Suite @MainActor struct SectionViewTests {
    private var fixture: TutorialKit.Section {
        TutorialKit.Section(
            anchor: "state", kicker: "03 · STATE", title: "Add state",
            intro: "Intro line.",
            steps: [
                Step("Declare @State", panel: .code(CodePanel(
                    file: "Counter.swift", code: "@State var count = 0",
                    origin: .fragment(path: "Examples/Counter/Sources/main.swift")))),
                Step("Mutate it"),
                Step("Writes coalesce"),
            ],
            panel: .browser(url: "localhost:8080", screenshot: "screens/counter-3.png"))
    }

    @Test func panelSelection() {
        #expect(fixture.activePanel(step: 0) == .code(CodePanel(
            file: "Counter.swift", code: "@State var count = 0",
            origin: .fragment(path: "Examples/Counter/Sources/main.swift"))))
        #expect(fixture.activePanel(step: 1) == fixture.panel)   // no override → default
        #expect(fixture.activePanel(step: 99) == fixture.panel)  // out of range → default
    }

    @Test func ssgStateContract_stepZeroActiveAndOverridePanelShown() {
        let html = HTMLRenderer.render(SectionView(section: fixture, index: 0))
        #expect(html.contains("tut-step-active"))
        #expect(html.contains("id=\"state-step-0\""))
        #expect(html.contains("id=\"state-step-2\""))
        // step 0 carries an override → prerendered panel is the CODE card, not the browser mock
        #expect(html.contains("tut-card-dark"))
        #expect(!html.contains("tut-browser"))
        // deterministic render (hydration proxy)
        #expect(html == HTMLRenderer.render(SectionView(section: fixture, index: 0)))
    }

    @Test func firstStepIsTheActiveOne() {
        let html = HTMLRenderer.render(SectionView(section: fixture, index: 0))
        let activeRange = html.range(of: "tut-step-active")!
        let step1Range = html.range(of: "id=\"state-step-1\"")!
        #expect(activeRange.lowerBound < step1Range.lowerBound)
    }
}
```

(The live IntersectionObserver path is wasm-only — it is exercised by the Playwright smoke in Task 12, not natively.)

- [ ] **Step 5: Run + commit**

```bash
cd Sites/Tutorial && swift test
git add Sites/Tutorial && git commit -m "feat(tutorial): section engine — step list, sticky panel, scrollspy

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 8: QuizCard

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/QuizCard.swift`
- Test: append to `Sites/Tutorial/Tests/TutorialKitTests/InteractionTests.swift`

**Interfaces:**
- Consumes: `Quiz`/`Question` (Task 1), classes (Task 2).
- Produces: `QuizCard(quiz: Quiz)` — the quiz band (Figma 9:26). State machine: `index` (current question), `selected: Int?`, `checked: Bool`. Prerendered state: question 1, nothing selected, unchecked (spec §11).

- [ ] **Step 1: Write QuizCard.swift**

```swift
import SwiftWUI

/// "Check your understanding" band (Figma 9:26). Fully client-side @State —
/// this component is the site's proof of hydrated interactivity.
public struct QuizCard: Tag {
    let quiz: Quiz
    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var checked = false

    public init(quiz: Quiz) { self.quiz = quiz }

    private func optionClass(_ i: Int, question: Question) -> String {
        if checked {
            if i == question.correctIndex { return "tut-option tut-option-correct" }
            if i == selected { return "tut-option tut-option-wrong" }
            return "tut-option"
        }
        return i == selected ? "tut-option tut-option-selected" : "tut-option"
    }

    public var body: some Tag {
        let question = quiz.questions[index]
        Div(class: "tut-quiz") {
            Div(class: "tut-content") {
                Div(class: "tut-quiz-header") {
                    Span(class: "tut-kicker") { "CHECK YOUR UNDERSTANDING" }
                    H2("Question \(index + 1) of \(quiz.questions.count)", class: "tut-question")
                }
                Div(class: "tut-quiz-card") {
                    P(class: "tut-quiz-prompt") { Text(question.prompt) }
                    ForEach(Array(question.options.enumerated()), id: \.offset) { item in
                        Div(class: optionClass(item.offset, question: question)) {
                            Span(class: "tut-radio")
                            Span(class: "tut-option-label") { Text(item.element) }
                        }
                        .on(.click) { _ in
                            guard !checked else { return }
                            selected = item.offset
                        }
                    }
                    if checked {
                        P(class: selected == question.correctIndex
                          ? "tut-explain tut-explain-ok" : "tut-explain tut-explain-no") {
                            Text(question.explanation)
                        }
                        if index + 1 < quiz.questions.count {
                            Button("Next question", class: "tut-quiz-submit", onClick: {
                                index += 1; selected = nil; checked = false
                            })
                        }
                    } else {
                        Button("Check answer", class: "tut-quiz-submit", onClick: {
                            if selected != nil { checked = true }
                        })
                    }
                }
            }
        }
    }
}
```

(`tut-quiz-prompt`: 18px/600 lh26 — add rule. Note `.on(.click)` attaches to the option `Div` — `Div` is an `HTMLTag`, the modifier returns `Self`, chaining before the builder collects it.)

- [ ] **Step 2: Tests (append to InteractionTests.swift)**

```swift
@Suite @MainActor struct QuizCardTests {
    private var quiz: Quiz {
        Quiz(questions: [
            Question(prompt: "Which property wrapper drives re-rendering in SwiftWUI?",
                     options: ["@Environment", "@State", "@Binding"], correctIndex: 1,
                     explanation: "Assigning a new value to @State invalidates the owning component."),
            Question(prompt: "Q2", options: ["a", "b"], correctIndex: 0, explanation: "E2"),
            Question(prompt: "Q3", options: ["a", "b"], correctIndex: 1, explanation: "E3"),
        ])
    }

    @Test func prerenderedStateIsQuestionOneUnchecked() {
        let html = HTMLRenderer.render(QuizCard(quiz: quiz))
        #expect(html.contains("Question 1 of 3"))
        #expect(html.contains("Check answer"))
        #expect(!html.contains("tut-option-selected"))
        #expect(!html.contains("tut-explain"))
        #expect(html == HTMLRenderer.render(QuizCard(quiz: quiz)))   // deterministic
    }

    @Test func selectCheckAdvanceFlow() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()

        // select the correct option (index 1)
        let options = findAll(backend.container, class: "tut-option")
        rt.dispatch(options[1].events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-option-selected") != nil)

        // check → correct highlight + explanation + Next
        let check = findAll(backend.container, tag: "button")[0]
        rt.dispatch(check.events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-option-correct") != nil)
        #expect(findFirst(backend.container, class: "tut-explain-ok") != nil)

        // next question resets selection
        let next = findAll(backend.container, tag: "button")[0]
        rt.dispatch(next.events["click"]!)
        sched.pump()
        #expect(textContent(backend.container).contains("Question 2 of 3"))
        #expect(findFirst(backend.container, class: "tut-option-selected") == nil)
    }

    @Test func wrongAnswerHighlightsBothAndLastQuestionHasNoNext() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        let options = findAll(backend.container, class: "tut-option")
        rt.dispatch(options[0].events["click"]!)   // wrong (correct is 1)
        sched.pump()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-option-wrong") != nil)
        #expect(findFirst(backend.container, class: "tut-option-correct") != nil)
        #expect(findFirst(backend.container, class: "tut-explain-no") != nil)
    }

    @Test func checkWithoutSelectionIsInert() {
        let (rt, backend, sched) = makeRuntime(QuizCard(quiz: quiz))
        rt.mount()
        rt.dispatch(findAll(backend.container, tag: "button")[0].events["click"]!)
        sched.pump()
        #expect(findFirst(backend.container, class: "tut-explain") == nil)
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
cd Sites/Tutorial && swift test
git add Sites/Tutorial && git commit -m "feat(tutorial): quiz card with check/advance state machine

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Pages, App, routes, ssg entry — first end-to-end build

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Components/Pages.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/App.swift`
- Rewrite: `Sites/Tutorial/Sources/TutorialSite/main.swift` (replaces Task 1 stub)
- Create: `Sites/Tutorial/build-site.sh`
- Test: `Sites/Tutorial/Tests/TutorialKitTests/PageTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–8.
- Produces: `OverviewPage()`, `ChapterPage(chapter:)`, `WrapUpPage(chapter:)`, `TutorialApp: App` (routes, `globalStyles`, `themes`), ssg dual entry. Route table: `Route("/") { OverviewPage() }` + `Route("/tutorials/:slug")` dispatching by `kind` (spec §11).

- [ ] **Step 1: Write Pages.swift**

```swift
import SwiftWUI

/// Landing page (spec §3 overview pattern): hero + chapter cards by track.
public struct OverviewPage: Tag, Page {
    public init() {}
    public var title: String { "SwiftWUI Tutorials" }
    public var meta: [MetaTag] {
        [.viewport("width=device-width, initial-scale=1"),
         .description("Learn SwiftWUI: build the web in pure Swift.")]
    }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: Curriculum.overview)
        Header(class: "tut-hero") {
            Div(class: "tut-content tut-overview-hero") {
                Span(class: "tut-kicker tut-kicker-dark") { Text(Curriculum.overview.kicker) }
                H1(Curriculum.overview.title, class: "tut-hero-title tut-hero-title-simple")
                P(class: "tut-hero-tagline") { Text(Curriculum.overview.tagline) }
            }
        }
        Main(class: "tut-content") {
            ForEach(Track.allCases, id: \.rawValue) { track in
                Div(class: "tut-track") {
                    Span(class: "tut-kicker tut-track-label") { Text(track.rawValue.uppercased()) }
                    Div(class: "tut-cards") {
                        ForEach(Curriculum.chapters.filter { $0.track == track && $0.kind != .overview },
                                id: \.slug) { ch in
                            Link(ch.path) {
                                Span(class: "tut-card-link") {
                                    Span(class: "tut-card-kicker") { Text(ch.kind == .wrapUp ? "WRAP-UP" : "CHAPTER") }
                                    Span(class: "tut-card-title") { Text(ch.title) }
                                    Span(class: "tut-card-tagline") { Text(ch.tagline) }
                                    Span(class: "tut-card-minutes") { Text("\(ch.minutes) MIN") }
                                }
                            }
                        }
                    }
                }
            }
        }
        SiteFooter()
    }
}

/// Chapter page (Figma 1:2 / 11:26 pattern).
public struct ChapterPage: Tag, Page {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }
    public var title: String { "\(chapter.title) — SwiftWUI Tutorials" }
    public var meta: [MetaTag] {
        [.viewport("width=device-width, initial-scale=1"),
         .description(chapter.tagline)]
    }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: chapter)
        if let heroPanel = chapter.heroPanel {
            HeroView(chapter: chapter) { PanelView(panel: heroPanel) }
        } else {
            HeroView(chapter: chapter)
        }
        Main {
            ForEach(Array(chapter.sections.enumerated()), id: \.element.anchor) { item in
                SectionView(section: item.element, index: item.offset)
            }
        }
        if let quiz = chapter.quiz {
            QuizCard(quiz: quiz)
        }
        NextChapterCTA(chapter: chapter)
        SiteFooter()
    }
}

/// Wrap-up page (spec §3): recap bullets + quiz + CTA. No sections.
public struct WrapUpPage: Tag, Page {
    let chapter: Chapter
    public init(chapter: Chapter) { self.chapter = chapter }
    public var title: String { "\(chapter.title) — SwiftWUI Tutorials" }
    public var meta: [MetaTag] {
        [.viewport("width=device-width, initial-scale=1"),
         .description(chapter.tagline)]
    }

    public var body: some Tag {
        SiteNav()
        ChapterBar(chapter: chapter)
        HeroView(chapter: chapter)
        Main(class: "tut-content") {
            Ul(class: "tut-recap") {
                ForEach(Array((chapter.recap ?? []).enumerated()), id: \.offset) { item in
                    Li(class: "tut-recap-item") { Text(item.element) }
                }
            }
        }
        if let quiz = chapter.quiz {
            QuizCard(quiz: quiz)
        }
        NextChapterCTA(chapter: chapter)
        SiteFooter()
    }
}

/// 404 for unknown (and the overview's own) slugs under /tutorials/.
struct NotFoundPage: Tag, Page {
    var title: String { "Not found — SwiftWUI Tutorials" }
    var body: some Tag {
        SiteNav()
        Main(class: "tut-content") {
            H1("404", class: "tut-hero-title")
            P { "No such tutorial. " }
            Link("/") { Span { "Back to the overview" } }
        }
        SiteFooter()
    }
}
```

- [ ] **Step 2: Write App.swift**

```swift
import SwiftWUI

public struct TutorialApp: App {
    public init() {}

    public static var globalStyles: [Rule] { TutorialStyles.rules }
    public static var themes: [ThemeDefinition] { [TutorialTheme.definition] }

    public var body: some Tag {
        Router(notFound: { NotFoundPage() }) {
            Route("/") { OverviewPage() }
            Route("/tutorials/:slug") { params in
                RoutedChapter(slug: params["slug"] ?? "")
            }
        }
    }
}

/// Dispatch by curriculum kind (spec §6 "Page dispatch"). Returned tag must be
/// the TOP-LEVEL Page conformer per Route — but Router only reads `Page` off
/// the route's direct content, so RoutedChapter itself must NOT be the Page;
/// the concrete pages are. Head handling: RoutedChapter forwards by being
/// transparent — verified by PageTests.headTitleFollowsRoute below; if the
/// title does NOT land (Page detection is top-level only, spec Routing/Page.swift),
/// replace RoutedChapter with three explicit guards inside the Route closure:
///   if let ch = Curriculum.chapter(slug: slug), ch.kind == .chapter { ChapterPage(chapter: ch) }
///   else if let ch = ..., ch.kind == .wrapUp { WrapUpPage(chapter: ch) } else { NotFoundPage() }
/// written INLINE in the Route content builder (buildEither keeps each branch top-level).
struct RoutedChapter: Tag {
    let slug: String
    var body: some Tag {
        if let ch = Curriculum.chapter(slug: slug) {
            if ch.kind == .wrapUp {
                WrapUpPage(chapter: ch)
            } else {
                ChapterPage(chapter: ch)
            }
        } else {
            NotFoundPage()
        }
    }
}
```

**KNOWN RISK (decide by test, not by taste):** `Page` detection is top-level-only (Routing/Router.swift — `content.base as? any Page`). `RoutedChapter` is not a `Page`, so per-chapter `<title>` will NOT be captured through the wrapper. `PageTests.headTitleFollowsRoute` (Step 4) pins the REQUIRED behavior; if it fails with the wrapper, use the inline-branches form described in the comment (that keeps `ChapterPage` top-level in the builder). Either way the test decides — do not ship a page without per-chapter titles.

- [ ] **Step 3: Rewrite main.swift (dual entry) + build script**

`Sites/Tutorial/Sources/TutorialSite/main.swift` — exactly the template/TodoMVC pattern (spec §11; wasmScriptPath MUST be `/app/index.js`, the CLI dist layout):

```swift
import TutorialKit
import SwiftWUI

#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: TutorialSite ssg --out <dir>")
            return
        }
        args.removeFirst()
        var out = "dist"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(TutorialApp.self, config: .init(
            outDir: out,
            mode: .hydrate(wasmScriptPath: "/app/index.js"),
            paths: Curriculum.ssgPaths))
        print("generated \(report.pages.count) pages, skipped \(report.skippedPatterns)")
        if !report.unmatchedPaths.isEmpty {
            print("UNMATCHED paths (config typo?): \(report.unmatchedPaths)")
        }
    }
}
#else
import SwiftWUIDOM

@main enum Entry {
    static func main() { TutorialApp.main() }
}
#endif
```

`Sites/Tutorial/build-site.sh` (the canonical dist assembly — order per phase-6 fix: CLI dist FIRST, ssg pages LAST so prerendered pages win; assets copied because the CLI does not know about them):

```bash
#!/bin/bash
# Assemble the full tutorial site into dist/. Run from Sites/Tutorial.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
swift run --package-path "$REPO" swiftwui build --out dist
mkdir -p dist/assets && cp -R Assets/. dist/assets/
swift run --package-path "$REPO" swiftwui ssg --out dist
echo "site assembled: dist/ — preview with: swift run --package-path $REPO swiftwui serve dist"
```

`chmod +x Sites/Tutorial/build-site.sh`.

- [ ] **Step 4: Write PageTests.swift**

```swift
import Testing
import SwiftWUI
@testable import TutorialKit

@Suite @MainActor struct PageTests {
    @Test func ssgPathListMatchesCurriculum() {
        // spec §9.5: 11 dynamic paths + static root == 12 pages
        #expect(Curriculum.ssgPaths.count + 1 == Curriculum.chapters.count)
        #expect(Set(Curriculum.ssgPaths).count == 11)
    }

    @Test func routerServesAllTwelvePages() {
        let (rt, backend, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        #expect(textContent(backend.container).contains("Welcome to SwiftWUI Tutorials"))
        for ch in Curriculum.chapters where ch.kind != .overview {
            rt.navigate(to: ch.path)
            sched.pump()
            #expect(textContent(backend.container).contains(ch.title), "missing \(ch.slug)")
        }
    }

    @Test func unknownAndOverviewSlugsHit404() {
        let (rt, backend, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        rt.navigate(to: "/tutorials/no-such-chapter")
        sched.pump()
        #expect(textContent(backend.container).contains("404"))
        rt.navigate(to: "/tutorials/welcome")   // the overview's slug must NOT resolve here
        sched.pump()
        #expect(textContent(backend.container).contains("404"))
    }

    @Test func headTitleFollowsRoute() {
        let (rt, _, sched) = makeRuntime(TutorialApp().body)
        rt.mount()
        rt.navigate(to: "/tutorials/style-in-swift")
        sched.pump()
        #expect(rt._pageHead?.title == "Style in Swift — SwiftWUI Tutorials")
    }

    @Test func chapterPageGoldenStructure() {
        // tiny fixture chapter — full-page structural golden (spec §9.4).
        // slug MUST be a real curriculum slug: NextChapterCTA and ChapterMenu
        // resolve against Curriculum — an unknown slug drops the CTA.
        let ch = Chapter(slug: "hello-swiftwui", track: .explore, kicker: "TEST",
                        title: "Fixture", tagline: "T.", minutes: 1, kind: .chapter,
                        sections: [TutorialKit.Section(anchor: "one", kicker: "01 · A", title: "S1",
                                           steps: [Step("First"), Step("Second")],
                                           panel: .terminal(title: "t", lines: [TermLine(.command, "x")]))],
                        quiz: Quiz(questions: [
                            Question(prompt: "P", options: ["a", "b"], correctIndex: 0, explanation: "E"),
                            Question(prompt: "P2", options: ["a", "b"], correctIndex: 0, explanation: "E"),
                            Question(prompt: "P3", options: ["a", "b"], correctIndex: 0, explanation: "E"),
                        ]))
        let html = HTMLRenderer.render(ChapterPage(chapter: ch))
        for marker in ["tut-nav", "tut-chapterbar", "tut-hero", "tut-section",
                       "tut-step-active", "tut-quiz", "tut-cta-card", "tut-footer",
                       "id=\"one-step-0\"", "CHECK YOUR UNDERSTANDING"] {
            #expect(html.contains(marker), "missing \(marker)")
        }
    }
}
```

- [ ] **Step 5: Run the native suite, then the first real end-to-end**

```bash
cd Sites/Tutorial && swift test
# native ssg smoke (pages exist even with stub content):
swift run TutorialSite ssg --out /tmp/tut-dist-probe
# expected: "generated 12 pages, skipped []" and /tmp/tut-dist-probe/tutorials/hello-swiftwui/index.html exists
ls /tmp/tut-dist-probe/tutorials/ | wc -l    # expected: 11
```

- [ ] **Step 6: Commit**

```bash
git add Sites/Tutorial
git commit -m "feat(tutorial): pages, router, ssg dual entry — 12 pages end-to-end

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 10: Chapter 4 content — "Hello, SwiftWUI" (hero chapter, end-to-end)

**Files:**
- Modify: `Examples/Counter/Sources/main.swift` (add markers ONLY — two comment lines)
- Create: `Examples/Counter/Sources/Hello.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch04_HelloSwiftWUI.swift`
- Modify: `Sites/Tutorial/Sources/TutorialKit/Model/Curriculum.swift` (replace ch4 stub with `Ch04.chapter`)
- Create: `Sites/Tutorial/Assets/screens/counter-3.png` (placeholder, replaced in Task 12)
- Test: `Sites/Tutorial/Tests/TutorialKitTests/ExcerptSyncTests.swift`

**Interfaces:**
- Consumes: model + engine (Tasks 1–9).
- Produces: `Ch04.chapter: Chapter`; excerpt markers `counter` and `hello` in Examples/Counter; the excerpt-sync test harness (`markedRegion(of:marker:)`, `Chapter.allPanels`) reused by Tasks 13–15.

- [ ] **Step 1: Add markers to Examples/Counter + Hello.swift**

`Examples/Counter/Sources/main.swift` — insert `// tutorial:begin counter` on the line BEFORE `struct Counter: Tag {` and `// tutorial:end counter` on the line AFTER the struct's closing `}`. No other edits — the struct body stays byte-identical.

New `Examples/Counter/Sources/Hello.swift` (compiled, unused by the app — it exists so the ch4 "Core API" panel is real code, spec §7):

```swift
import SwiftWUI

// tutorial:begin hello
struct Hello: Tag {
    var body: some Tag {
        Div(class: "card") {
            H1("Hello, SwiftWUI")
            P { "Swift on the web —" }
            P { "no JavaScript required." }
            A(href: "/docs") { "Read the docs" }
        }
    }
}
// tutorial:end hello
```

- [ ] **Step 2: Write Ch04_HelloSwiftWUI.swift**

Copy from Figma 1:2 verbatim (steps/kickers/terminal lines were extracted from the design during planning — do not rephrase). Code excerpts are RAW strings (`#"""…"""#`) so `\(count)` stays literal; they must match the marked file regions byte-for-byte (the test enforces it).

```swift
/// Chapter 4 — Hello, SwiftWUI (Figma 1:2).
public enum Ch04 {
    static let counterCode = #"""
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
"""#

    static let helloCode = #"""
struct Hello: Tag {
    var body: some Tag {
        Div(class: "card") {
            H1("Hello, SwiftWUI")
            P { "Swift on the web —" }
            P { "no JavaScript required." }
            A(href: "/docs") { "Read the docs" }
        }
    }
}
"""#

    public static let chapter = Chapter(
        slug: "hello-swiftwui", track: .explore, kicker: "GETTING STARTED",
        title: "Hello, SwiftWUI",
        tagline: "Build the web in pure Swift.",
        body: "You’ll build Counter — an interactive page written entirely in Swift, compiled to WebAssembly, and rendered through a SwiftUI-style declarative API. No JavaScript required.",
        minutes: 25, kind: .chapter,
        heroPanel: .code(CodePanel(file: "Counter.swift", code: counterCode,
                                   origin: .sample(path: "Examples/Counter/Sources/main.swift",
                                                   marker: "counter"))),
        sections: [
            Section(anchor: "toolchain", kicker: "01 · TOOLCHAIN",
                    title: "Scaffold a project in seconds",
                    intro: "The swiftwui CLI carries a project from first file to production build: init, dev, build, ssg, serve.",
                    steps: [
                        Step("Install the SwiftWUI toolchain and the matching Swift WASM SDK."),
                        Step("Run swiftwui init counter and pick a template: basic, mvvm, or tca-style."),
                        Step("swiftwui dev compiles the app and serves it locally."),
                        Step("Edit any file — hot reload updates the page and keeps your @State."),
                    ],
                    panel: .terminal(title: "zsh — counter", lines: [
                        TermLine(.command, "swiftwui init counter"),
                        TermLine(.output, "  created counter/Package.swift"),
                        TermLine(.output, "  created counter/Sources/App/main.swift"),
                        TermLine(.output, "  created counter/Dockerfile"),
                        TermLine(.command, "cd counter"),
                        TermLine(.command, "swiftwui dev"),
                        TermLine(.note, "> dev server on http://localhost:8080"),
                        TermLine(.note, "> watching sources — hot reload on"),
                    ])),
            Section(anchor: "core-api", kicker: "02 · CORE API",
                    title: "Declare your interface with Tags",
                    intro: "Tag is SwiftWUI’s View: plain structs with a @TagBuilder body. Uppercase tags mirror HTML, and attributes are typed init parameters.",
                    steps: [
                        Step("Conform a struct to Tag and return markup from body."),
                        Step("Compose Div, H1, P, A, Button — the nesting reads like the DOM it renders."),
                        Step("Pass attributes as typed parameters: Div(class: \"card\"), A(href: \"/docs\")."),
                        Step("No classes, no inheritance — value-semantic structs all the way down."),
                    ],
                    panel: .code(CodePanel(file: "Hello.swift", code: helloCode,
                                           origin: .sample(path: "Examples/Counter/Sources/Hello.swift",
                                                           marker: "hello")))),
            Section(anchor: "state", kicker: "03 · STATE",
                    title: "Add state, get reactivity",
                    intro: "@State works the way you know from SwiftUI: assign a new value and the framework re-renders exactly what changed — nothing more.",
                    steps: [
                        Step("Declare @State var count = 0 inside your Tag.",
                             panel: .code(CodePanel(file: "Counter.swift", code: counterCode,
                                                    origin: .sample(path: "Examples/Counter/Sources/main.swift",
                                                                    marker: "counter")))),
                        Step("Mutate it from an event closure: Button(\"+\") { count += 1 }."),
                        Step("Writes coalesce — many mutations, one DOM flush per microtask."),
                        Step("Structural identity keeps state stable across re-renders and list reorders."),
                    ],
                    panel: .browser(url: "localhost:8080", screenshot: "screens/counter-3.png")),
        ],
        quiz: Quiz(questions: [
            Question(prompt: "Which property wrapper drives re-rendering in SwiftWUI?",
                     options: ["@Environment", "@State", "@Binding"], correctIndex: 1,
                     explanation: "Assigning a new value to @State invalidates the owning component; the runtime re-renders and patches only that subtree."),
            Question(prompt: "What happens when you save a file while swiftwui dev is running?",
                     options: ["The page fully reloads and loses state",
                               "The wasm rebuilds and hot reload preserves your @State",
                               "Nothing until you refresh manually"], correctIndex: 1,
                     explanation: "The dev server rebuilds, snapshots live @State, and the new bundle adopts it."),
            Question(prompt: "How are Tag bodies written?",
                     options: ["HTML template strings", "A @TagBuilder result builder", "JSX"],
                     correctIndex: 1,
                     explanation: "@TagBuilder is a Swift result builder — the same mechanism as SwiftUI’s ViewBuilder."),
        ]))
}
```

In `Curriculum.swift`, replace the ch4 stub entry with `Ch04.chapter` (the array literal now mixes stubs and authored entries — final state after Task 15: all 12 authored).

- [ ] **Step 3: Placeholder screenshot (dies in Task 12)**

```bash
mkdir -p Sites/Tutorial/Assets/screens
echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > Sites/Tutorial/Assets/screens/counter-3.png
```

- [ ] **Step 4: Write ExcerptSyncTests.swift**

```swift
import Foundation
import Testing
@testable import TutorialKit

extension Chapter {
    /// Every panel on the page: hero + section defaults + step overrides.
    var allPanels: [Panel] {
        var out: [Panel] = []
        if let heroPanel { out.append(heroPanel) }
        for s in sections {
            out.append(s.panel)
            out += s.steps.compactMap(\.panel)
        }
        return out
    }
}

/// spec §9.2 — code panels are pinned to compiled sample sources.
@Suite struct ExcerptSyncTests {
    private func fileText(_ repoRelative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(repoRelative), encoding: .utf8)
    }

    /// Lines strictly between `// tutorial:begin <marker>` and `// tutorial:end <marker>`.
    private func markedRegion(of text: String, marker: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let begin = lines.firstIndex(where: { $0 == "// tutorial:begin \(marker)" }),
              let end = lines.firstIndex(where: { $0 == "// tutorial:end \(marker)" }),
              begin + 1 <= end - 1 || begin + 1 == end
        else { return nil }
        return lines[(begin + 1)..<end].joined(separator: "\n")
    }

    @Test func everyCodePanelMatchesItsSource() throws {
        for ch in Curriculum.chapters {
            for panel in ch.allPanels {
                guard case .code(let card) = panel else { continue }
                switch card.origin {
                case .sample(let path, let marker):
                    let text = try fileText(path)
                    let region = markedRegion(of: text, marker: marker)
                    #expect(region != nil, "\(ch.slug): marker '\(marker)' not found in \(path)")
                    #expect(region == card.code,
                            "\(ch.slug): panel '\(card.file)' drifted from \(path) [\(marker)]")
                case .fragment(let path):
                    let text = try fileText(path)
                    #expect(text.contains(card.code),
                            "\(ch.slug): panel '\(card.file)' is not a verbatim fragment of \(path)")
                }
            }
        }
    }

    @Test func ch4HasAStepPanelOverride() {
        // spec §9.1: the smoke's panel-swap check needs a target in ch. 4
        let ch = Curriculum.chapter(slug: "hello-swiftwui")!
        let hasOverride = ch.sections.contains { $0.steps.contains { $0.panel != nil } }
        #expect(hasOverride)
    }
}
```

- [ ] **Step 5: Run everything, then the first real browser build**

```bash
cd Sites/Tutorial && swift test          # incl. excerpt sync against Examples/Counter
cd ../../Examples/Counter && swift build # markers didn't break the example
cd ../../Sites/Tutorial && ./build-site.sh
# expected: wasm build ok; assets copied; "generated 12 pages"
grep -c "application/swiftwui-state" dist/tutorials/hello-swiftwui/index.html   # ≥1 (prerendered+hydratable)
grep -c "tut-step-active" dist/tutorials/hello-swiftwui/index.html             # ≥1 (step-0 active in SSG)
grep -c "/assets/screens/counter-3.png" dist/tutorials/hello-swiftwui/index.html # 1
```

Manual (non-blocking, spec §10.5): `swift run --package-path ../.. swiftwui serve dist` → open http://localhost:8080/tutorials/hello-swiftwui — dark hero + code card, sticky panel, quiz clickable.

- [ ] **Step 6: Commit**

```bash
git add Sites/Tutorial Examples/Counter
git commit -m "feat(tutorial): Hello, SwiftWUI chapter — content, excerpt sync, first e2e build

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 11: Sample packages — StyleBubble, ChatRouter, ShipCounter

**Files:**
- Create: `Sites/Tutorial/Samples/StyleBubble/{Package.swift,index.html,Sources/main.swift}`
- Create: `Sites/Tutorial/Samples/ChatRouter/{Package.swift,index.html,Sources/main.swift}`
- Create: `Sites/Tutorial/Samples/ShipCounter/{Package.swift,index.html,Dockerfile,Sources/main.swift}`
- Test: append to `Sites/Tutorial/Tests/TutorialKitTests/ExcerptSyncTests.swift`

**Interfaces:**
- Consumes: nothing from TutorialKit (samples are standalone packages).
- Produces: marked excerpts consumed by Tasks 13–15 content: `bubble`, `bubble-rules`, `bubble-theme` (StyleBubble); `chat-routes`, `chat-links` (ChatRouter); `ship-ssg`, `ship-static` (ShipCounter). ShipCounter's `Counter` struct is BYTE-IDENTICAL to `Ch04.counterCode` (the screenshot app runs the exact code the ch4 page shows — pinned by test).

All three `Package.swift` files are the TodoMVC shape with the path dep hopped one level deeper (`../../../..` → repo root) and the sample's name substituted:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StyleBubble",                 // ChatRouter / ShipCounter respectively
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../../.."),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(name: "StyleBubble", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            .product(name: "SwiftWUIStatic", package: "SwiftWUI",
                     condition: .when(platforms: [.macOS, .linux])),
        ], path: "Sources", swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
```

All three `index.html` files are the CLI-template shape (`swiftwui build` requires one; title = sample name):

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>StyleBubble</title>
  <script type="importmap">
  {"imports": {"@bjorn3/browser_wasi_shim": "/vendor/wasi-shim/index.js"}}
  </script>
</head>
<body>
  <script type="module">
    import { init } from "/app/index.js";
    await init();
  </script>
</body>
</html>
```

All three `main.swift` files end with the template dual entry (native = ssg usage, wasm = App.main()) — copy verbatim from `Sources/SwiftWUIToolchain/Resources/templates/basic/Sources/main.swift` lines `#if canImport(SwiftWUIStatic) … #endif`, substituting the App type name. This also makes native `swift build` link without the DOM runtime.

- [ ] **Step 1: StyleBubble/Sources/main.swift**

```swift
import SwiftWUI
import SwiftWUIDOM

extension ColorToken {
    static let stageBg  = ColorToken("stage-bg")
    static let stageInk = ColorToken("stage-ink")
}

// tutorial:begin bubble
struct Bubble: Tag {
    var body: some Tag {
        P { "Knock, knock." }
            .padding(.px(12))
            .background(.hex("#F2F0EC"))
            .borderRadius(.px(10))
            .fontSize(.rem(1.1))
            .style("backdrop-filter", "blur(4px)")
    }
}
// tutorial:end bubble

struct Stage: Tag {
    @State private var theme: String? = nil
    var body: some Tag {
        Div(class: "stage") {
            Bubble()
            Button("Toggle theme", class: "stage-toggle") {
                theme = theme == nil ? "dark" : nil
                setDocumentTheme(theme)
            }
        }
    }
}

struct BubbleApp: App {
    var body: some Tag { Stage() }

// tutorial:begin bubble-rules
    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.token(.stageBg))
            p.color(.token(.stageInk))
            p.fontFamily("system-ui, sans-serif")
        }
        Rule(class: "stage") { p in
            p.padding(.px(48))
            p.display(.flex); p.flexDirection(.column); p.gap(.px(16))
            p.alignItems(.start)
        }
        Rule(class: "stage-toggle") { p in
            p.padding(vertical: .px(8), horizontal: .px(14))
            p.borderRadius(.px(8)); p.cursor(.pointer)
            p.hover { h in h.opacity(0.8) }
        }
    }
// tutorial:end bubble-rules

// tutorial:begin bubble-theme
    static var themes: [ThemeDefinition] {
        [
            ThemeDefinition { t in                      // default → :root
                t.set(ColorToken.stageBg, .hex("#faf9f7"))
                t.set(ColorToken.stageInk, .hex("#1c1917"))
            },
            ThemeDefinition(name: "dark") { t in        // → [data-theme="dark"]
                t.set(ColorToken.stageBg, .hex("#17140f"))
                t.set(ColorToken.stageInk, .hex("#f5f1ea"))
            },
        ]
    }
// tutorial:end bubble-theme
}
```

`setDocumentTheme(_:)` — small helper in the same file: on wasm calls the runtime's theme switch; IMPLEMENTER: check `Sources/SwiftWUIDOM` for the public theme-switch entry (`Runtime.setTheme(_:)` is the core API — the DOM runtime exposes an app-level equivalent; if the only surface is on the runtime instance, reach it the way the phase-3 browser check did, or drop the toggle button and keep the themes static — the tutorial text needs the THEME DEFINITIONS, the toggle is garnish. Dropping the button is the approved fallback; do not invent new framework surface.)

- [ ] **Step 2: ChatRouter/Sources/main.swift**

```swift
import SwiftWUI
import SwiftWUIDOM

// tutorial:begin chat-links
struct NavBar: Tag {
    var body: some Tag {
        Nav(class: "bar") {
            Link("/") { Span { "Home" } }
            Link("/chat") { Span { "Chat" } }
            Link("/docs/routing") { Span { "Docs" } }
        }
    }
}
// tutorial:end chat-links

struct Home: Tag, Page {
    var title: String { "Home — ChatRouter" }
    var body: some Tag {
        Main { NavBar(); H1("Home"); P { "A tiny three-route app." } }
    }
}

struct Chat: Tag, Page {
    @State private var messages = ["Welcome to the chat."]
    @State private var draft = ""
    var title: String { "Chat — ChatRouter" }
    var body: some Tag {
        Main {
            NavBar()
            H1("Chat")
            Ul(class: "log") {
                ForEach(Array(messages.enumerated()), id: \.offset) { item in
                    Li { Text(item.element) }
                }
            }
            Input(type: .text, value: $draft)
            Button("Send") {
                let text = draft
                if !text.isEmpty { messages.append(text); draft = "" }
            }
        }
    }
}

struct DocPage: Tag, Page {
    let slug: String
    var title: String { "\(slug) — Docs" }
    var body: some Tag {
        Main {
            NavBar()
            H1("Docs: \(slug)")
            P { "Route parameters arrive as typed captures — same page Tag, different data." }
        }
    }
}

// tutorial:begin chat-routes
struct ChatApp: App {
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { Home() }
            Route("/chat") { Chat() }
            Route("/docs/:page") { params in
                DocPage(slug: params["page"] ?? "intro")
            }
        }
    }
}
// tutorial:end chat-routes
```

(+ dual entry with `ChatApp`.)

- [ ] **Step 3: ShipCounter/Sources/main.swift + Dockerfile**

`Counter` struct: byte-identical copy of the marked region in `Examples/Counter/Sources/main.swift` (WITHOUT new markers — the canonical marker stays in Examples; identity is pinned by test).

```swift
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

struct HomePage: Tag, Page {
    var title: String { "ShipCounter" }
    var body: some Tag {
        Main { Counter() }
    }
}

// tutorial:begin ship-static
struct AboutPage: Tag, Page {
    @State var builtAt = "not prerendered"
    var title: String { "About — ShipCounter" }
    var body: some Tag {
        Main {
            H2("About")
            P { Text(builtAt) }
            Link("/") { Span { "Home" } }
        }
        .staticTask { builtAt = "prerendered at build time" }
    }
}
// tutorial:end ship-static

struct RootApp: Tag {
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
    }
}

struct ShipCounterApp: App {
    var body: some Tag { RootApp() }
}

#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

// tutorial:begin ship-ssg
@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: ShipCounter ssg --out <dir>")
            return
        }
        args.removeFirst()
        var out = "dist"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(ShipCounterApp.self, config: .init(
            outDir: out,
            mode: .hydrate(wasmScriptPath: "/app/index.js")))
        print("generated \(report.pages.count) pages")
    }
}
// tutorial:end ship-ssg
#else
@main enum Entry {
    static func main() { ShipCounterApp.main() }
}
#endif
```

`ShipCounter/Dockerfile` — the basic template's Dockerfile with `{{NAME}}` → `ShipCounter` (final content, verbatim):

```dockerfile
# Reproducible wasm build (spec §9). Requires the Swift.org WASM SDK artifactbundle
# URL for the EXACT toolchain in the base image:
#   docker build --build-arg WASM_SDK_URL=<artifactbundle url> --output type=local,dest=dist-docker .
# NOTE: works once the SwiftWUI dependency in Package.swift is a git URL or is
# vendored inside this directory — a path dependency outside the build context
# is invisible to docker (README, "Docker" section).
FROM swift:6.3.3 AS build
ARG WASM_SDK_URL
WORKDIR /src
COPY . .
RUN swift sdk install "$WASM_SDK_URL"
RUN swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c release
RUN mkdir -p dist/app dist/vendor \
 && cp -r .build/plugins/PackageToJS/outputs/Package/. dist/app/ \
 && cp -r vendor/. dist/vendor/ \
 && cp index.html dist/index.html
RUN swift run ShipCounter ssg --out dist

FROM scratch AS export
COPY --from=build /src/dist /
```

The Dockerfile's `cp -r vendor/.` expects a project-local `vendor/` dir: check whether the basic template ships one (`ls Sources/SwiftWUIToolchain/Resources/templates/basic/`); if yes, copy it into ShipCounter too. If not, the Dockerfile is template-verbatim anyway and inoperative until publication (path dep) — leave as documentation.

- [ ] **Step 4: Tests (append to ExcerptSyncTests.swift)**

```swift
@Suite struct SampleSyncTests {
    @Test func shipCounterRunsTheExactCh4Code() throws {
        let text = try String(contentsOf: repoRoot.appendingPathComponent(
            "Sites/Tutorial/Samples/ShipCounter/Sources/main.swift"), encoding: .utf8)
        #expect(text.contains(Ch04.counterCode),
                "ShipCounter.Counter drifted from Examples/Counter — the screenshot app must run the code the page shows")
    }

    @Test func allExpectedMarkersResolve() throws {
        let expectations: [(String, String)] = [
            ("Examples/Counter/Sources/main.swift", "counter"),
            ("Examples/Counter/Sources/Hello.swift", "hello"),
            ("Sites/Tutorial/Samples/StyleBubble/Sources/main.swift", "bubble"),
            ("Sites/Tutorial/Samples/StyleBubble/Sources/main.swift", "bubble-rules"),
            ("Sites/Tutorial/Samples/StyleBubble/Sources/main.swift", "bubble-theme"),
            ("Sites/Tutorial/Samples/ChatRouter/Sources/main.swift", "chat-routes"),
            ("Sites/Tutorial/Samples/ChatRouter/Sources/main.swift", "chat-links"),
            ("Sites/Tutorial/Samples/ShipCounter/Sources/main.swift", "ship-ssg"),
            ("Sites/Tutorial/Samples/ShipCounter/Sources/main.swift", "ship-static"),
        ]
        for (path, marker) in expectations {
            let text = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            #expect(text.contains("// tutorial:begin \(marker)"), "\(path): missing begin \(marker)")
            #expect(text.contains("// tutorial:end \(marker)"), "\(path): missing end \(marker)")
        }
    }
}
```

(`markedRegion` stays `private` in ExcerptSyncTests — this suite only checks marker presence; region equality re-runs in `everyCodePanelMatchesItsSource` once content references land.)

- [ ] **Step 5: Build all three samples (native + wasm via CLI), run site tests**

```bash
REPO="$(pwd)"   # repo root
for s in StyleBubble ChatRouter ShipCounter; do
  ( cd Sites/Tutorial/Samples/$s && \
    swift build && \
    swift run --package-path "$REPO" swiftwui build --out /tmp/tut-sample-$s )
done
# expected per sample: native Build complete + dist assembled (LAYOUT: index.html + app/ + vendor/)
( cd Sites/Tutorial/Samples/ShipCounter && swift run ShipCounter ssg --out /tmp/tut-ship-ssg )
# expected: "generated 2 pages"
cd Sites/Tutorial && swift test
```

- [ ] **Step 6: Commit**

```bash
git add Sites/Tutorial/Samples Sites/Tutorial/Tests
git commit -m "feat(tutorial): sample apps — StyleBubble, ChatRouter, ShipCounter

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 12: Playwright pipeline — screenshots + smoke

**Files:**
- Create: `Sites/Tutorial/tools/screenshots/package.json`
- Create: `Sites/Tutorial/tools/screenshots/.gitignore` (`node_modules/`, `test-results/`, `.tmp/`)
- Create: `Sites/Tutorial/tools/screenshots/shots.config.mjs`
- Create: `Sites/Tutorial/tools/screenshots/shots.mjs`
- Create: `Sites/Tutorial/tools/screenshots/playwright.config.mjs`
- Create: `Sites/Tutorial/tools/screenshots/smoke.spec.mjs`
- Create: `Sites/Tutorial/tools/screenshots/run-smoke.sh`
- Replace: `Sites/Tutorial/Assets/screens/counter-3.png` (real shot kills the Task-10 placeholder)
- Create: `Sites/Tutorial/Assets/screens/{first-project,style-bubble,chat-router,ship-static}.png`

**Interfaces:**
- Consumes: samples (Task 11), site build script (Task 9), CLI (`swiftwui build/ssg/serve/init`).
- Produces: `npm run shots` (regenerate all PNGs), `npm run smoke` (spec §8/§10.4 acceptance). Screenshot inventory consumed by content Tasks 13–15: `counter-3.png` (ch4, already referenced), `first-project.png` (ch3), `style-bubble.png` (ch6), `chat-router.png` (ch8), `ship-static.png` (ch10).

- [ ] **Step 1: package.json + playwright.config.mjs**

```json
{
  "name": "tutorial-screenshots",
  "private": true,
  "type": "module",
  "scripts": {
    "shots": "node shots.mjs",
    "smoke": "bash run-smoke.sh"
  },
  "devDependencies": {
    "@playwright/test": "^1.45.0"
  }
}
```

```js
// playwright.config.mjs
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testMatch: 'smoke.spec.mjs',
  timeout: 60_000,
  use: {
    baseURL: process.env.SMOKE_BASE_URL ?? 'http://localhost:4174',
    viewport: { width: 1440, height: 900 },
  },
});
```

- [ ] **Step 2: shots.config.mjs (the frame manifest)**

```js
// Frame manifest (spec §8). `project` is repo-relative; `scaffold: true`
// generates a fresh basic-template app with `swiftwui init` instead.
// `ssg: true` runs the sample's ssg entry before serving (prerendered shot).
export const shots = [
  {
    name: 'counter-3',
    project: 'Sites/Tutorial/Samples/ShipCounter',   // runs the EXACT ch4 code (pinned by SampleSyncTests)
    route: '/',
    actions: async (page) => {
      await page.getByRole('button', { name: '+' }).click({ clickCount: 3 });
      await page.getByText('Count: 3').waitFor();
    },
  },
  {
    name: 'first-project',
    scaffold: true,                                   // swiftwui init HelloWUI --template basic
    route: '/',
    actions: async (page) => { await page.getByText('Count:').waitFor(); },
  },
  {
    name: 'style-bubble',
    project: 'Sites/Tutorial/Samples/StyleBubble',
    route: '/',
    actions: async (page) => { await page.getByText('Knock, knock.').waitFor(); },
  },
  {
    name: 'chat-router',
    project: 'Sites/Tutorial/Samples/ChatRouter',
    route: '/chat',
    actions: async (page) => {
      await page.locator('input').fill('Hello from Swift');
      await page.getByRole('button', { name: 'Send' }).click();
      await page.getByText('Hello from Swift').waitFor();
    },
  },
  {
    name: 'ship-static',
    project: 'Sites/Tutorial/Samples/ShipCounter',
    route: '/about',
    ssg: true,
    actions: async (page) => { await page.getByText('prerendered at build time').waitFor(); },
  },
];
```

- [ ] **Step 3: shots.mjs (the driver)**

```js
// Screenshot driver (spec §8): per frame — build the sample through the CLI
// (isolated .build-wasm; NEVER raw `swift package js`), serve dist, run the
// frame's actions, save a 960×544@2x PNG into Assets/screens/.
import { chromium } from '@playwright/test';
import { spawn, execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, cpSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { shots } from './shots.config.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const SITE = resolve(HERE, '../..');            // Sites/Tutorial
const REPO = resolve(SITE, '../..');            // SwiftWUI checkout
const OUT = join(SITE, 'Assets/screens');
const PORT = 4173;

function swiftwui(args, cwd) {
  execFileSync('swift', ['run', '--package-path', REPO, 'swiftwui', ...args],
               { cwd, stdio: 'inherit' });
}

function serveDist(cwd) {
  const proc = spawn('swift',
    ['run', '--package-path', REPO, 'swiftwui', 'serve', 'dist', '--port', String(PORT)],
    { cwd, stdio: 'inherit' });
  return proc;
}

async function waitForServer(url, tries = 60) {
  for (let i = 0; i < tries; i++) {
    try { const r = await fetch(url); if (r.ok) return; } catch {}
    await new Promise(r => setTimeout(r, 500));
  }
  throw new Error(`server never came up at ${url}`);
}

const browser = await chromium.launch();
for (const shot of shots) {
  let projectDir;
  let scratch;
  if (shot.scaffold) {
    scratch = mkdtempSync(join(tmpdir(), 'tut-scaffold-'));
    execFileSync('swift', ['run', '--package-path', REPO, 'swiftwui',
                           'init', 'HelloWUI', '--swiftwui-path', REPO],
                 { cwd: scratch, stdio: 'inherit' });
    projectDir = join(scratch, 'HelloWUI');
  } else {
    projectDir = join(REPO, shot.project);
  }

  swiftwui(['build', '--out', 'dist'], projectDir);
  if (shot.ssg) {
    execFileSync('swift', ['run', shot.project.split('/').pop(), 'ssg', '--out', 'dist'],
                 { cwd: projectDir, stdio: 'inherit' });
  }

  const server = serveDist(projectDir);
  try {
    await waitForServer(`http://localhost:${PORT}${shot.route}`);
    const page = await browser.newPage({
      viewport: { width: 960, height: 544 },
      deviceScaleFactor: 2,
    });
    await page.goto(`http://localhost:${PORT}${shot.route}`);
    await page.waitForSelector('[data-swui-hydrated="true"]');
    if (shot.actions) await shot.actions(page);
    await page.screenshot({ path: join(OUT, `${shot.name}.png`) });
    await page.close();
    console.log(`shot: ${shot.name}.png`);
  } finally {
    server.kill();
    if (scratch) rmSync(scratch, { recursive: true, force: true });
  }
}
await browser.close();
```

- [ ] **Step 4: smoke.spec.mjs + run-smoke.sh**

```js
// Acceptance smoke (spec §8/§10.4) against the BUILT site (`swiftwui serve dist`).
import { test, expect } from '@playwright/test';

const SLUGS = [
  'install-the-toolchain', 'create-your-first-project', 'hello-swiftwui',
  'wrap-up-explore', 'style-in-swift', 'wrap-up-styles', 'route-between-pages',
  'wrap-up-routing', 'prerender-and-hydrate', 'deploy-with-docker', 'wrap-up-ship',
];
const PATHS = ['/', ...SLUGS.map(s => `/tutorials/${s}`)];

for (const path of PATHS) {
  test(`hydrates without console errors: ${path}`, async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(path);
    // console silence is NOT proof — the adoption-failure path cold-renders
    // silently; the runtime sets this attribute ONLY on successful adoption.
    await expect(page.locator('[data-swui-hydrated="true"]')).toHaveCount(1, { timeout: 30_000 });
    expect(errors).toEqual([]);
  });
}

test('quiz: select → check → highlight', async ({ page }) => {
  await page.goto('/tutorials/hello-swiftwui');
  await page.waitForSelector('[data-swui-hydrated="true"]');
  await page.locator('.tut-option', { hasText: '@State' }).click();
  await expect(page.locator('.tut-option-selected')).toHaveCount(1);
  await page.getByRole('button', { name: 'Check answer' }).click();
  await expect(page.locator('.tut-option-correct')).toHaveCount(1);
  await expect(page.locator('.tut-explain-ok')).toBeVisible();
});

test('chapter menu: open overlay → navigate', async ({ page }) => {
  await page.goto('/tutorials/hello-swiftwui');
  await page.waitForSelector('[data-swui-hydrated="true"]');
  await page.locator('.tut-dropdown').click();
  await expect(page.locator('.tut-menu-open')).toBeVisible();
  await page.locator('.tut-menu-open').getByText('Style in Swift').click();
  await expect(page).toHaveURL(/\/tutorials\/style-in-swift$/);
  await expect(page.locator('h1')).toContainText('Style in Swift');
});

test('scrollspy: active step flips and panel swaps', async ({ page }) => {
  await page.goto('/tutorials/hello-swiftwui');
  await page.waitForSelector('[data-swui-hydrated="true"]');
  // section "state": step 0 override = code card; scrolled to step 2 → browser mock (spec D2)
  await page.locator('#state').scrollIntoViewIfNeeded();
  await expect(page.locator('#state-step-0')).toHaveClass(/tut-step-active/);
  await expect(page.locator('#state .tut-panel .tut-card-dark')).toBeVisible();
  await page.locator('#state-step-2').scrollIntoViewIfNeeded();
  await page.mouse.wheel(0, 60);   // nudge the observer band
  await expect(page.locator('#state-step-2')).toHaveClass(/tut-step-active/, { timeout: 10_000 });
  await expect(page.locator('#state .tut-panel .tut-browser')).toBeVisible();
});
```

```bash
#!/bin/bash
# run-smoke.sh — build the full site, serve it, run the smoke suite.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="$HERE/../.."
REPO="$SITE/../.."
PORT=4174

(cd "$SITE" && ./build-site.sh)
(cd "$SITE" && swift run --package-path "$REPO" swiftwui serve dist --port $PORT) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
for i in $(seq 1 60); do curl -sf "http://localhost:$PORT/" >/dev/null && break; sleep 0.5; done
(cd "$HERE" && SMOKE_BASE_URL="http://localhost:$PORT" npx playwright test)
```

`chmod +x run-smoke.sh`.

- [ ] **Step 5: Install, generate real screenshots, run smoke**

```bash
cd Sites/Tutorial/tools/screenshots
npm install && npx playwright install chromium
npm run shots
# expected: 5 PNGs written to ../../Assets/screens (counter-3 placeholder replaced by a real Count: 3 frame)
git status ../../Assets/screens   # 5 files (1 modified, 4 new)
npm run smoke
# expected at THIS point: hydration+quiz+menu+scrollspy tests PASS for /tutorials/hello-swiftwui and /;
# stub chapters also hydrate (they render hero+CTA only). If a stub page fails hydration, fix now — not in Task 13.
cd ../.. && swift test              # screenshot-existence invariants now check real files
```

- [ ] **Step 6: Commit**

```bash
git add Sites/Tutorial/tools Sites/Tutorial/Assets
git commit -m "feat(tutorial): Playwright pipeline — real screenshots + browser smoke

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 13: Content — Welcome track (overview, install, first project)

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch01_Overview.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch02_InstallToolchain.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch03_FirstProject.swift`
- Modify: `Sites/Tutorial/Sources/TutorialKit/Model/Curriculum.swift` (stubs 1–3 → `Ch01.chapter`, `Ch02.chapter`, `Ch03.chapter`)

**Interfaces:** consumes model + `screens/first-project.png` (Task 12). Produces `Ch01/Ch02/Ch03.chapter`.

- [ ] **Step 1: Write the three content files**

`Ch01_Overview.swift` — the overview keeps its Task-1 fields (cards derive from the other chapters' metadata; no sections/quiz — spec §5):

```swift
/// Chapter 1 — the landing page. Card content derives from Curriculum; this
/// file only pins the hero copy.
public enum Ch01 {
    public static let chapter = Chapter(
        slug: "welcome", track: .welcome, kicker: "SWIFTWUI TUTORIALS",
        title: "Welcome to SwiftWUI Tutorials",
        tagline: "Learn to build the web in pure Swift — one chapter at a time.",
        minutes: 2, kind: .overview)
}
```

`Ch02_InstallToolchain.swift`:

```swift
/// Chapter 2 — Install the toolchain.
public enum Ch02 {
    public static let chapter = Chapter(
        slug: "install-the-toolchain", track: .welcome, kicker: "CHAPTER · WELCOME",
        title: "Install the toolchain",
        tagline: "Swift 6.3.3, the matching WASM SDK, and the swiftwui CLI.",
        minutes: 10, kind: .chapter,
        sections: [
            Section(anchor: "swift-toolchain", kicker: "01 · SWIFT",
                    title: "Install Swift with swiftly",
                    intro: "swiftly manages Swift toolchains the way rustup manages Rust.",
                    steps: [
                        Step("Install swiftly, the Swift toolchain manager, from swift.org.",
                             detail: "macOS and Linux installers live at swift.org/install."),
                        Step("Install and select Swift 6.3.3: swiftly install 6.3.3, then swiftly use 6.3.3."),
                        Step("Verify: swift --version should print swift-6.3.3-RELEASE."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "swiftly install 6.3.3"),
                        TermLine(.command, "swiftly use 6.3.3"),
                        TermLine(.command, "swift --version"),
                        TermLine(.note, "> Swift version 6.3.3 (swift-6.3.3-RELEASE)"),
                    ])),
            Section(anchor: "wasm-sdk", kicker: "02 · WASM SDK",
                    title: "Add the WebAssembly SDK",
                    intro: "SwiftWUI compiles your app to wasm with the official Swift.org SDK.",
                    steps: [
                        Step("Install the SDK bundle: swift sdk install with the swift-6.3.3-RELEASE_wasm URL from swift.org/download."),
                        Step("Host toolchain and SDK versions must match exactly — 6.3.3 with 6.3.3.",
                             detail: "A mismatched pair fails at link time with confusing errors."),
                        Step("Verify with swift sdk list — the wasm SDK should be listed."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "swift sdk install <swift-6.3.3-RELEASE_wasm bundle URL>"),
                        TermLine(.command, "swift sdk list"),
                        TermLine(.note, "> swift-6.3.3-RELEASE_wasm"),
                    ])),
            Section(anchor: "cli", kicker: "03 · CLI",
                    title: "Build the swiftwui CLI",
                    intro: "The CLI carries a project from first file to production build.",
                    steps: [
                        Step("Clone the SwiftWUI repository."),
                        Step("swift build -c release --product swiftwui builds the binary.",
                             detail: "Or run it in place: swift run swiftwui <command>."),
                        Step("No package-manager distribution yet — brew/mint packaging is on the roadmap."),
                    ],
                    panel: .terminal(title: "zsh — SwiftWUI", lines: [
                        TermLine(.command, "git clone https://github.com/kazimgadzhiev/SwiftWUI"),
                        TermLine(.command, "cd SwiftWUI && swift build -c release --product swiftwui"),
                        TermLine(.command, ".build/release/swiftwui --help"),
                        TermLine(.note, "> swiftwui — init, dev, build, ssg, serve"),
                    ])),
        ])
}
```

`Ch03_FirstProject.swift`:

```swift
/// Chapter 3 — Create your first project.
public enum Ch03 {
    public static let chapter = Chapter(
        slug: "create-your-first-project", track: .welcome, kicker: "CHAPTER · WELCOME",
        title: "Create your first project",
        tagline: "Scaffold with swiftwui init and iterate with hot reload.",
        minutes: 10, kind: .chapter,
        sections: [
            Section(anchor: "scaffold", kicker: "01 · SCAFFOLD",
                    title: "Scaffold with swiftwui init",
                    intro: "One command creates a complete, buildable SwiftWUI app.",
                    steps: [
                        Step("Run swiftwui init HelloWUI and pick a template with --template: basic, mvvm, or tca.",
                             detail: "Until SwiftWUI is published, pass --swiftwui-path pointing at your checkout."),
                        Step("The scaffold ships Package.swift, index.html, a Counter component, and a Dockerfile."),
                        Step("Everything builds natively too — swift build works without a browser."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "swiftwui init HelloWUI --swiftwui-path ../SwiftWUI"),
                        TermLine(.output, "  created HelloWUI/Package.swift"),
                        TermLine(.output, "  created HelloWUI/Sources/main.swift"),
                        TermLine(.output, "  created HelloWUI/index.html"),
                        TermLine(.output, "  created HelloWUI/Dockerfile"),
                        TermLine(.command, "cd HelloWUI"),
                    ])),
            Section(anchor: "dev-loop", kicker: "02 · DEV LOOP",
                    title: "Iterate with hot reload",
                    intro: "swiftwui dev rebuilds on save and keeps your app state alive.",
                    steps: [
                        Step("swiftwui dev builds the wasm bundle and serves it locally."),
                        Step("Save any Swift file — the page hot-reloads and keeps your @State.",
                             detail: "Live state is snapshotted before the swap and adopted by the new bundle."),
                        Step("This is the freshly scaffolded app in the browser — a working counter out of the box."),
                    ],
                    panel: .browser(url: "localhost:8080", screenshot: "screens/first-project.png")),
        ])
}
```

- [ ] **Step 2: Swap the three stubs in Curriculum.swift, run, commit**

```bash
cd Sites/Tutorial && swift test        # excerpt/screenshot invariants cover the new content
./build-site.sh && grep -c "Install the toolchain" dist/tutorials/install-the-toolchain/index.html   # ≥1
git add Sites/Tutorial && git commit -m "feat(tutorial): Welcome track content — overview, install, first project

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 14: Content — Explore wrap-up + Styles track

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch05_WrapUpExplore.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch06_StyleInSwift.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch07_WrapUpStyles.swift`
- Modify: `Sites/Tutorial/Sources/TutorialKit/Model/Curriculum.swift` (stubs 5–7 → authored)

**Interfaces:** consumes StyleBubble markers (Task 11) + `screens/style-bubble.png` (Task 12).

- [ ] **Step 1: Write the three content files**

`Ch05_WrapUpExplore.swift`:

```swift
/// Chapter 5 — Wrap-up: Explore SwiftWUI.
public enum Ch05 {
    public static let chapter = Chapter(
        slug: "wrap-up-explore", track: .explore, kicker: "WRAP-UP · EXPLORE SWIFTWUI",
        title: "Wrap-up: Explore SwiftWUI",
        tagline: "What you learned building your first SwiftWUI page.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Tag is SwiftWUI’s View: a value-semantic struct with a @TagBuilder body.",
            "Uppercase tags mirror HTML; attributes are typed init parameters.",
            "@State plus event closures give reactivity with zero JavaScript.",
            "swiftwui init / dev / build / ssg / serve carries a project from scaffold to production.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "Which target does SwiftWUI compile to for the browser?",
                     options: ["x86_64 native", "WebAssembly via the swift-6.3.3-RELEASE_wasm SDK", "The JVM"],
                     correctIndex: 1,
                     explanation: "The app compiles to wasm; JavaScriptKit bridges it to the DOM."),
            Question(prompt: "What happens to sibling DOM nodes when one @State value changes?",
                     options: ["The whole page re-creates", "Only the changed nodes are patched", "Nothing until reload"],
                     correctIndex: 1,
                     explanation: "The reconciler diffs the resolved trees and applies a minimal patch set."),
            Question(prompt: "Where do Button event closures run?",
                     options: ["In generated JavaScript", "In Swift, compiled to wasm", "On a server"],
                     correctIndex: 1,
                     explanation: "Listeners do a fire-time lookup into the Swift-side listener registry."),
        ]))
}
```

`Ch06_StyleInSwift.swift` — the `bubble*` excerpt strings are raw strings that MUST byte-match the marked regions written in Task 11 (the `bubble-rules`/`bubble-theme` regions keep their 4-space member indentation — copy exactly; the test is the referee):

```swift
/// Chapter 6 — Style in Swift (Figma 11:26 + authored sections).
public enum Ch06 {
    static let bubbleCode = #"""
struct Bubble: Tag {
    var body: some Tag {
        P { "Knock, knock." }
            .padding(.px(12))
            .background(.hex("#F2F0EC"))
            .borderRadius(.px(10))
            .fontSize(.rem(1.1))
            .style("backdrop-filter", "blur(4px)")
    }
}
"""#

    // These are the marked regions of Samples/StyleBubble/Sources/main.swift
    // (Task 11 Step 1) — byte-identical incl. member indentation; ExcerptSyncTests
    // fails on any drift, including whitespace.
    static let rulesCode = #"""
    @RulesBuilder static var globalStyles: [Rule] {
        Rule(element: "body") { p in
            p.margin(.zero)
            p.background(.token(.stageBg))
            p.color(.token(.stageInk))
            p.fontFamily("system-ui, sans-serif")
        }
        Rule(class: "stage") { p in
            p.padding(.px(48))
            p.display(.flex); p.flexDirection(.column); p.gap(.px(16))
            p.alignItems(.start)
        }
        Rule(class: "stage-toggle") { p in
            p.padding(vertical: .px(8), horizontal: .px(14))
            p.borderRadius(.px(8)); p.cursor(.pointer)
            p.hover { h in h.opacity(0.8) }
        }
    }
"""#
    static let themeCode = #"""
    static var themes: [ThemeDefinition] {
        [
            ThemeDefinition { t in                      // default → :root
                t.set(ColorToken.stageBg, .hex("#faf9f7"))
                t.set(ColorToken.stageInk, .hex("#1c1917"))
            },
            ThemeDefinition(name: "dark") { t in        // → [data-theme="dark"]
                t.set(ColorToken.stageBg, .hex("#17140f"))
                t.set(ColorToken.stageInk, .hex("#f5f1ea"))
            },
        ]
    }
"""#

    public static let chapter = Chapter(
        slug: "style-in-swift", track: .styles, kicker: "CHAPTER · STYLES",
        title: "Style in Swift",
        tagline: "Type-safe CSS modifiers cover the common cases; a raw string escape hatch covers the rest.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "modifiers", kicker: "01 · MODIFIERS",
                    title: "Style without leaving Swift",
                    intro: "Modifiers chain on any Tag and collapse into a single inline style.",
                    steps: [
                        Step("Chain type-safe modifiers on any Tag: .padding, .background, .borderRadius."),
                        Step("Values are typed — .px(12), .rem(1.1), .percent(50) — not strings."),
                        Step("Consecutive modifiers collapse into one style attribute — no wrapper soup."),
                        Step(".style(\"property\", \"value\") is the raw escape hatch when the DSL lacks a property."),
                    ],
                    panel: .code(CodePanel(file: "Bubble.swift", code: bubbleCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/StyleBubble/Sources/main.swift",
                                                           marker: "bubble")))),
            Section(anchor: "rules", kicker: "02 · RULES",
                    title: "Rule classes and stylesheets",
                    intro: "Shared styles belong in a real stylesheet, not on every node.",
                    steps: [
                        Step("Register document-level rules once via App.globalStyles."),
                        Step("Rule(class:) writes an actual stylesheet — inspect it in devtools."),
                        Step("Pseudo-selectors nest as blocks: hover { … }, focus { … }."),
                        Step("Media queries scope any rule: media(.maxWidth(.px(1080))) { … }."),
                    ],
                    panel: .code(CodePanel(file: "StyleBubble.swift", code: rulesCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/StyleBubble/Sources/main.swift",
                                                           marker: "bubble-rules")))),
            Section(anchor: "themes", kicker: "03 · THEMES",
                    title: "Design tokens and themes",
                    intro: "Tokens become CSS variables; themes swap them without re-rendering.",
                    steps: [
                        Step("Declare tokens as ColorToken statics; read them with .token(.stageInk).",
                             panel: .code(CodePanel(file: "StyleBubble.swift", code: themeCode,
                                                    origin: .sample(path: "Sites/Tutorial/Samples/StyleBubble/Sources/main.swift",
                                                                    marker: "bubble-theme")))),
                        Step("The default ThemeDefinition emits :root variables."),
                        Step("Named themes emit [data-theme=\"…\"] blocks — switching is one attribute write, zero re-render."),
                    ],
                    panel: .browser(url: "localhost:8080", screenshot: "screens/style-bubble.png")),
        ])
}
```

`Ch07_WrapUpStyles.swift`:

```swift
/// Chapter 7 — Wrap-up: Styles.
public enum Ch07 {
    public static let chapter = Chapter(
        slug: "wrap-up-styles", track: .styles, kicker: "WRAP-UP · STYLES",
        title: "Wrap-up: Styles",
        tagline: "Modifiers, rules, and themes — recapped.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Type-safe modifiers collapse into one inline style attribute per element.",
            "Rule(class:) in globalStyles emits a real stylesheet with pseudo and media support.",
            "ColorToken + ThemeDefinition give CSS-variable theming; switching themes is one attribute write.",
            ".style(\"property\", \"value\") covers what the DSL doesn’t — values are validated, never escaped into selectors.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "Where do chained .padding()-style modifiers land in the DOM?",
                     options: ["One collapsed inline style attribute", "A generated CSS file per component", "JavaScript style calls at runtime"],
                     correctIndex: 0,
                     explanation: "Consecutive style modifiers append to the same wrapper and serialize as one style attribute."),
            Question(prompt: "What emits a [data-theme=\"dark\"] rule block?",
                     options: ["ThemeDefinition(name: \"dark\")", "Rule(class: \"dark\")", "An inline .style() call"],
                     correctIndex: 0,
                     explanation: "Named themes render as [data-theme] selectors; the default theme renders as :root."),
            Question(prompt: "The DSL has no backdrop-filter modifier. What do you do?",
                     options: [".style(\"backdrop-filter\", \"blur(4px)\")", "Edit the generated CSS in dist", "Add JavaScript"],
                     correctIndex: 0,
                     explanation: "The escape hatch takes any property/value pair and validates it before emitting."),
        ]))
}
```

- [ ] **Step 2: Swap stubs 5–7, run, commit**

```bash
cd Sites/Tutorial && swift test && ./build-site.sh
git add Sites/Tutorial && git commit -m "feat(tutorial): Explore wrap-up + Styles track content

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 15: Content — Routing + Ship tracks

**Files:**
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch08_Routing.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch09_WrapUpRouting.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch10_PrerenderHydrate.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch11_DeployDocker.swift`
- Create: `Sites/Tutorial/Sources/TutorialKit/Content/Ch12_WrapUpShip.swift`
- Modify: `Sites/Tutorial/Sources/TutorialKit/Model/Curriculum.swift` (stubs 8–12 → authored; after this task NO stubs remain)

**Interfaces:** consumes ChatRouter/ShipCounter markers (Task 11), `screens/chat-router.png` + `screens/ship-static.png` (Task 12).

- [ ] **Step 1: Write the five content files**

Excerpt raw strings (`routesCode` ← `chat-routes`, `linksCode` ← `chat-links`, `ssgCode` ← `ship-ssg`, `staticCode` ← `ship-static`, `dockerCode` ← Dockerfile fragment) follow the Ch06 pattern: verbatim copies of the Task-11 marked regions, pinned by ExcerptSyncTests. `dockerCode` uses `.fragment(path: "Sites/Tutorial/Samples/ShipCounter/Dockerfile")` with the contiguous block from the first `FROM` line through the nginx `COPY` line, copied byte-for-byte from the file Task 11 created.

`Ch08_Routing.swift`:

```swift
/// Chapter 8 — Route between pages (Figma 12:34 + authored sections).
public enum Ch08 {
    static let routesCode = #"""
struct ChatApp: App {
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { Home() }
            Route("/chat") { Chat() }
            Route("/docs/:page") { params in
                DocPage(slug: params["page"] ?? "intro")
            }
        }
    }
}
"""#
    static let linksCode = #"""
struct NavBar: Tag {
    var body: some Tag {
        Nav(class: "bar") {
            Link("/") { Span { "Home" } }
            Link("/chat") { Span { "Chat" } }
            Link("/docs/routing") { Span { "Docs" } }
        }
    }
}
"""#

    public static let chapter = Chapter(
        slug: "route-between-pages", track: .routing, kicker: "CHAPTER · ROUTING",
        title: "Route between pages",
        tagline: "Declare routes as data, render a Tag per path, and let the framework drive browser history.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "router", kicker: "01 · ROUTER",
                    title: "Declare your routes",
                    intro: "Routes are data: a pattern, an optional guard, and content.",
                    steps: [
                        Step("Router is just a Tag — declare it in your App body."),
                        Step("Route maps a pattern to content; first match wins in declaration order."),
                        Step("Dynamic segments capture values: Route(\"/docs/:page\") { params in … }."),
                        Step("notFound content renders when nothing matches."),
                    ],
                    panel: .code(CodePanel(file: "App.swift", code: routesCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/ChatRouter/Sources/main.swift",
                                                           marker: "chat-routes")))),
            Section(anchor: "navigation", kicker: "02 · NAVIGATION",
                    title: "Links and programmatic navigation",
                    intro: "Navigation is interception, not page loads.",
                    steps: [
                        Step("Link(\"/chat\") renders an <a> and intercepts the click into SPA navigation."),
                        Step("Cmd-click and middle-click fall through to the browser — new tabs still work."),
                        Step("Programmatic: read @Environment(\\.navigate), then navigate(\"/chat\") or navigate(path, replace: true)."),
                        Step("External URLs render as plain anchors — the browser handles them."),
                    ],
                    panel: .code(CodePanel(file: "NavBar.swift", code: linksCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/ChatRouter/Sources/main.swift",
                                                           marker: "chat-links")))),
            Section(anchor: "identity", kicker: "03 · STATE & IDENTITY",
                    title: "Identity across navigation",
                    intro: "Route identity decides which state survives a URL change.",
                    steps: [
                        Step("Matched content is keyed by its route pattern in the tree."),
                        Step("Param-only changes (/docs/intro → /docs/api) keep the page’s @State."),
                        Step("Switching routes tears state down — a fresh page starts clean."),
                    ],
                    panel: .browser(url: "localhost:8080/chat", screenshot: "screens/chat-router.png")),
        ])
}
```

`Ch09_WrapUpRouting.swift`:

```swift
/// Chapter 9 — Wrap-up: Routing.
public enum Ch09 {
    public static let chapter = Chapter(
        slug: "wrap-up-routing", track: .routing, kicker: "WRAP-UP · ROUTING",
        title: "Wrap-up: Routing",
        tagline: "Routes, links, and identity — recapped.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Router is a Tag; routes are data — pattern, optional guard, content.",
            "First match wins in declaration order; :param captures arrive as a dictionary.",
            "Link intercepts internal clicks; modified clicks and external URLs stay native.",
            "Identity is keyed by route pattern — param changes keep @State, route changes reset it.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "You navigate /docs/intro → /docs/api under Route(\"/docs/:page\"). What happens to the page’s @State?",
                     options: ["It is preserved — same route identity", "It resets", "It crashes"],
                     correctIndex: 0,
                     explanation: "Param-only changes keep the keyed identity, so state survives (spec D2 of the routing phase)."),
            Question(prompt: "What does Link render for an external https:// destination?",
                     options: ["A plain <a> the browser handles", "An intercepted SPA link", "A disabled anchor"],
                     correctIndex: 0,
                     explanation: "Only internal root-relative destinations are intercepted into navigate()."),
            Question(prompt: "How many Routers may an app declare?",
                     options: ["Exactly one", "One per page", "Any number, nested"],
                     correctIndex: 0,
                     explanation: "One Router per app — a second one traps in debug builds."),
        ]))
}
```

`Ch10_PrerenderHydrate.swift`:

```swift
/// Chapter 10 — Prerender and hydrate (Figma 13:42 + authored sections).
public enum Ch10 {
    static let ssgCode = #"""
@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: ShipCounter ssg --out <dir>")
            return
        }
        args.removeFirst()
        var out = "dist"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate(ShipCounterApp.self, config: .init(
            outDir: out,
            mode: .hydrate(wasmScriptPath: "/app/index.js")))
        print("generated \(report.pages.count) pages")
    }
}
"""#
    static let staticCode = #"""
struct AboutPage: Tag, Page {
    @State var builtAt = "not prerendered"
    var title: String { "About — ShipCounter" }
    var body: some Tag {
        Main {
            H2("About")
            P { Text(builtAt) }
            Link("/") { Span { "Home" } }
        }
        .staticTask { builtAt = "prerendered at build time" }
    }
}
"""#

    public static let chapter = Chapter(
        slug: "prerender-and-hydrate", track: .ship, kicker: "CHAPTER · SHIP",
        title: "Prerender and hydrate",
        tagline: "Static HTML at build time for instant first paint; the WASM runtime hydrates it into a live app.",
        minutes: 20, kind: .chapter,
        sections: [
            Section(anchor: "ssg", kicker: "01 · SSG",
                    title: "From routes to static pages",
                    intro: "The same app renders in the browser and at build time — one codebase, two entries.",
                    steps: [
                        Step("Keep two entries in main.swift: wasm runs the app, native runs ssg.",
                             detail: "#if canImport(SwiftWUIStatic) selects the entry per platform."),
                        Step("StaticSite.generate renders one page per route with a fresh native runtime."),
                        Step("Dynamic patterns need explicit paths in the config — unmatched ones are reported, not guessed."),
                        Step("Order matters: swiftwui build assembles dist first, ssg writes pages last."),
                    ],
                    panel: .terminal(title: "zsh — shipcounter", lines: [
                        TermLine(.command, "swiftwui build --out dist"),
                        TermLine(.note, "> wasm bundle -> dist/app/index.js"),
                        TermLine(.command, "swiftwui ssg --out dist"),
                        TermLine(.note, "> generated 2 pages"),
                        TermLine(.command, "swiftwui serve dist --port 9000"),
                        TermLine(.note, "> serving dist on http://localhost:9000"),
                    ])),
            Section(anchor: "hydrate", kicker: "02 · HYDRATE",
                    title: "Adopt, don’t re-render",
                    intro: "Hydration walks the prerendered DOM instead of throwing it away.",
                    steps: [
                        Step("The runtime adopts the prerendered DOM node by node."),
                        Step("Live @State ships as an application/swiftwui-state snapshot inside the page."),
                        Step("On any structural mismatch the runtime falls back to a cold render — content still works."),
                        Step("data-swui-hydrated=\"true\" on the container is the success signal — tests assert it."),
                    ],
                    panel: .code(CodePanel(file: "main.swift", code: ssgCode,
                                           origin: .sample(path: "Sites/Tutorial/Samples/ShipCounter/Sources/main.swift",
                                                           marker: "ship-ssg")))),
            Section(anchor: "static-data", kicker: "03 · STATIC DATA",
                    title: "Build-time loaders",
                    intro: "Some state should be computed once, at build time.",
                    steps: [
                        Step(".staticTask runs your async loader during prerendering.",
                             panel: .code(CodePanel(file: "AboutPage.swift", code: staticCode,
                                                    origin: .sample(path: "Sites/Tutorial/Samples/ShipCounter/Sources/main.swift",
                                                                    marker: "ship-static")))),
                        Step("The loaded @State serializes into the page and is adopted on hydrate."),
                        Step("This About page was filled at build time — no client fetch, no flash."),
                    ],
                    panel: .browser(url: "localhost:9000/about", screenshot: "screens/ship-static.png")),
        ])
}
```

`Ch11_DeployDocker.swift` — the content mirrors the ACTUAL template Dockerfile: a `swift:6.3.3` build stage (wasm bundle + ssg) and a `FROM scratch` export stage that emits `dist/` via `docker build --output`. No nginx claims — the template ships none.

```swift
/// Chapter 11 — Deploy with Docker.
public enum Ch11 {
    // verbatim contiguous block of Samples/ShipCounter/Dockerfile (Task 11 Step 3)
    static let dockerCode = #"""
FROM swift:6.3.3 AS build
ARG WASM_SDK_URL
WORKDIR /src
COPY . .
RUN swift sdk install "$WASM_SDK_URL"
RUN swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c release
RUN mkdir -p dist/app dist/vendor \
 && cp -r .build/plugins/PackageToJS/outputs/Package/. dist/app/ \
 && cp -r vendor/. dist/vendor/ \
 && cp index.html dist/index.html
RUN swift run ShipCounter ssg --out dist

FROM scratch AS export
COPY --from=build /src/dist /
"""#

    public static let chapter = Chapter(
        slug: "deploy-with-docker", track: .ship, kicker: "CHAPTER · SHIP",
        title: "Deploy with Docker",
        tagline: "One reproducible image: build the wasm bundle, prerender, export static files.",
        minutes: 15, kind: .chapter,
        sections: [
            Section(anchor: "image", kicker: "01 · IMAGE",
                    title: "One multi-stage build",
                    intro: "Swift builds in stage one; only static files leave the image.",
                    steps: [
                        Step("Stage one: a swift:6.3.3 image installs the WASM SDK, builds the release bundle, and runs ssg.",
                             detail: "The SDK artifactbundle URL arrives as a build arg — it must match the image’s toolchain exactly."),
                        Step("Stage two is FROM scratch: docker build --output exports dist/ as plain files."),
                        Step("The template Dockerfile ships with every swiftwui init scaffold."),
                    ],
                    panel: .code(CodePanel(file: "Dockerfile", code: dockerCode,
                                           origin: .fragment(path: "Sites/Tutorial/Samples/ShipCounter/Dockerfile")))),
            Section(anchor: "serve", kicker: "02 · SERVE",
                    title: "Serving — and one honest caveat",
                    intro: "The output is a static site; host it anywhere. One prerequisite applies today.",
                    steps: [
                        Step("The exported dist/ is plain static files — nginx, a CDN, any static host works.",
                             detail: "Give .wasm the application/wasm MIME type and add an SPA fallback for non-prerendered routes."),
                        Step("Honest limitation: the Docker build needs a published SwiftWUI package — a path dependency outside the build context cannot resolve.",
                             detail: "Works as-is the day SwiftWUI has a public git URL; the Dockerfile documents this."),
                        Step("Local preview without Docker: swiftwui serve dist."),
                    ],
                    panel: .terminal(title: "zsh — shipcounter", lines: [
                        TermLine(.command, "docker build --build-arg WASM_SDK_URL=<url> --output type=local,dest=dist-docker ."),
                        TermLine(.note, "> note: requires a published SwiftWUI package —"),
                        TermLine(.note, ">       path dependencies stay outside the build context"),
                        TermLine(.command, "swiftwui serve dist-docker"),
                    ])),
        ])
}
```

`Ch12_WrapUpShip.swift`:

```swift
/// Chapter 12 — Wrap-up: Ship (last page: CTA wraps to the overview).
public enum Ch12 {
    public static let chapter = Chapter(
        slug: "wrap-up-ship", track: .ship, kicker: "WRAP-UP · SHIP",
        title: "Wrap-up: Ship",
        tagline: "SSG, hydration, and deployment — recapped.",
        minutes: 5, kind: .wrapUp,
        recap: [
            "Dual entry: wasm runs the app, native runs StaticSite.generate.",
            "build first, ssg last — prerendered pages must win in dist.",
            "Hydration adopts the prerendered DOM and restores the state snapshot; any mismatch falls back to a cold render.",
            "Docker: build + prerender in stage one, a FROM-scratch export stage emits dist/ — pending a published package.",
        ],
        quiz: Quiz(questions: [
            Question(prompt: "In what order do build and ssg run?",
                     options: ["build first, then ssg — pages land last", "ssg first, then build", "Order doesn’t matter"],
                     correctIndex: 0,
                     explanation: "The CLI’s dist assembly would clobber prerendered pages; ssg writes last so they win."),
            Question(prompt: "How does hydration attach listeners without rebuilding the page?",
                     options: ["It adopts the prerendered DOM node by node", "It replaces body.innerHTML", "It diffs against an empty tree"],
                     correctIndex: 0,
                     explanation: "Adoption walks the existing DOM against the resolved tree and binds in place."),
            Question(prompt: "What marks a successfully hydrated page?",
                     options: ["data-swui-hydrated=\"true\" on the container", "A console.log line", "Nothing observable"],
                     correctIndex: 0,
                     explanation: "The runtime sets the attribute only when adoption succeeds — silence proves nothing."),
        ]))
}
```

- [ ] **Step 2: Swap stubs 8–12 (Curriculum now 100% authored), full local gate, commit**

```bash
cd Sites/Tutorial && swift test
./build-site.sh
cd tools/screenshots && npm run smoke     # all 12 pages now authored — full smoke must be green
cd ../.. && git add Sites/Tutorial
git commit -m "feat(tutorial): Routing + Ship tracks content — curriculum complete

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---
### Task 16: Acceptance matrix + README

**Files:**
- Create: `Sites/Tutorial/README.md`
- No source changes expected — this task RUNS spec §10 end to end and fixes only what it finds.

**Interfaces:** consumes everything.

- [ ] **Step 1: Write README.md**

Content (write in full — short doc, ~40 lines): what the site is (spec §1, one paragraph); prerequisites (Swift 6.3.3 + `swift-6.3.3-RELEASE_wasm`, Node for tools only); build (`./build-site.sh`), preview (`swift run --package-path ../.. swiftwui serve dist`); test (`swift test`); screenshots (`cd tools/screenshots && npm install && npm run shots`); smoke (`npm run smoke`); layout map (one line per top-level dir); THREE documented caveats verbatim from the spec: (1) `swiftwui dev` does not serve `/assets/*` — screenshots 404 under dev, use `serve dist`; (2) never mix raw `swift package --swift-sdk … js` with native builds in one directory — use the CLI (`.build-wasm` isolation); (3) hydrate boot script is inline JS — do not put the site behind a strict `script-src` CSP without hashes (phase-6 carry).

- [ ] **Step 2: Run the full acceptance matrix (spec §10)**

```bash
REPO="$(pwd)"                                       # repo root
# 1. native gates — site suite AND framework suite untouched
(cd Sites/Tutorial && swift test)                   # expected: all green
swift test                                          # expected: 291/291 framework tests untouched

# 2. samples: native + wasm-via-CLI
for s in StyleBubble ChatRouter ShipCounter; do
  (cd Sites/Tutorial/Samples/$s && swift build && \
   swift run --package-path "$REPO" swiftwui build --out /tmp/acc-$s)
done
(cd Examples/Counter && swift build)                # markers didn't break the example

# 3. full site build + ssg + assets
(cd Sites/Tutorial && ./build-site.sh)
ls Sites/Tutorial/dist/tutorials | wc -l            # expected: 11
test -f Sites/Tutorial/dist/index.html && echo ROOT-OK
# every referenced screenshot resolves under dist (spec §10.3):
for f in Sites/Tutorial/Assets/screens/*.png; do
  test -f "Sites/Tutorial/dist/assets/screens/$(basename "$f")" || echo "MISSING $f"
done                                                 # expected: no output

# 4. smoke (hydration attribute on 12/12, quiz, menu, scrollspy, panel swap)
(cd Sites/Tutorial/tools/screenshots && npm run smoke)   # expected: all tests pass
```

- [ ] **Step 3: Visual spot-check (manual, non-blocking — spec §10.5)**

`swift run --package-path "$REPO" swiftwui serve dist` from `Sites/Tutorial`, compare against Figma frames `1:2` (hello-swiftwui), `11:26` (style-in-swift), `12:34` (route-between-pages), `13:42` (prerender-and-hydrate). Log deviations; fix only layout-breaking ones this task.

- [ ] **Step 4: Commit**

```bash
git add Sites/Tutorial/README.md
git commit -m "docs(tutorial): README — build, preview, screenshots, caveats

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Execution notes

- **Order:** strictly 1→16 (spec §14 slices). Tasks 2–8 have no cross-dependencies beyond what their Interfaces blocks state and could run out of order EXCEPT: 4–9 all touch `TutorialStyles.rules` additions and `ComponentGoldenTests`/`InteractionTests` — run them sequentially to avoid merge noise.
- **Per-task gate:** `swift test --package-path Sites/Tutorial` green before every commit. `swiftwui`-based gates start at Task 9 (first e2e) and are part of Tasks 9, 10, 12, 13, 15, 16.
- **Figma fidelity:** visual spot-check is non-blocking per phase convention, but if an implementer must choose between the plan's CSS numbers and the Figma frame, the header token table (extracted from Figma) wins.
- **If a framework limitation blocks a step** (e.g. `Page`-detection through `RoutedChapter`, `@State` holding `ScrollSpy`): the plan names the approved fallback inline at that step. Use it; do NOT modify framework sources (spec §15).
