# SwiftWUI Showcase Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the minimal Counter scaffold produced by `swiftwui init` with a 12-chapter Apple-style showcase application that demonstrates every major SwiftWUI feature, sourced from `Examples/Showcase/` and bundled into the CLI as a build-time resource.

**Architecture:** Single sample project at `Examples/Showcase/` is the source-of-truth. A Makefile target syncs it to `Sources/SwiftWUICLI/Templates/showcase/` as a Swift Package resource. `swiftwui init <name>` copies the resource and substitutes a `{{PROJECT_NAME}}` placeholder. Page layout uses a sticky-right scrolly-teller with `IntersectionObserver` driving an `@State`-tracked active step. Theming via the existing `Theme` protocol with `ThemeCSS.definitions(light:dark:)`.

**Tech Stack:** Swift 6 + SwiftWUI (Tag/TagBuilder), JavaScriptKit (DOM + observer bridge), highlight.js v11 from CDN, ArgumentParser, Foundation FileManager.

**Subagent assignments**:
- `voltagent-lang:swift-expert` — Swift component implementation (Phases 2–4 task bodies).
- `voltagent-core-dev:frontend-developer` — `index.html`, highlight.js + IntersectionObserver JS bridges, CSS (Phases 1, 3).
- `voltagent-qa-sec:architect-reviewer` — Phase-boundary architectural reviews (after Phase 2, 4, 5).
- `voltagent-qa-sec:test-automator` — Test scaffolding (Phase 6).
- `voltagent-core-dev:ui-designer` — Visual polish review (Phase 7).
- `voltagent-qa-sec:code-reviewer` — Final pass before merge.

**Spec reference:** [docs/superpowers/specs/2026-04-29-showcase-template-design.md](../specs/2026-04-29-showcase-template-design.md).

**Working directory** for this plan: a dedicated worktree under `.claude/worktrees/showcase-template/` (created via `superpowers:using-git-worktrees` before Phase 1).

---

## File map (locked)

```
Examples/Showcase/
├── Package.swift                                 ← created in Task 1.1
├── index.html                                    ← created in Task 1.2 (frontend-developer)
├── README.md                                     ← created in Task 7.2
├── Sources/Showcase/
│   ├── main.swift                                ← created in Task 1.3, populated through Phase 4
│   ├── Theme/
│   │   ├── ShowcaseTheme.swift                   ← Task 2.1
│   │   └── Layout.swift                          ← Task 2.2
│   ├── Components/
│   │   ├── SiteChrome.swift                      ← Task 3.1
│   │   ├── Hero.swift                            ← Task 3.2
│   │   ├── ChapterCard.swift                     ← Task 3.3
│   │   ├── BadgeGrid.swift                       ← Task 3.4
│   │   ├── SyntaxHighlight.swift                 ← Task 3.5 (frontend-developer)
│   │   ├── CodeAndPreview.swift                  ← Task 3.6
│   │   └── ScrollyTeller.swift                   ← Task 3.7 (swift-expert + frontend-developer)
│   └── Pages/
│       ├── HomePage.swift                        ← Task 4.1
│       └── Chapters/
│           ├── HelloPage.swift                   ← Task 4.2 (canonical chapter)
│           ├── StatePage.swift                   ← Task 4.3
│           ├── ModifiersPage.swift               ← Task 4.4
│           ├── ListsPage.swift                   ← Task 4.5
│           ├── FormsPage.swift                   ← Task 4.6
│           ├── RoutingPage.swift                 ← Task 4.7
│           ├── AsyncPage.swift                   ← Task 4.8
│           ├── ThemingPage.swift                 ← Task 4.9
│           ├── A11yPage.swift                    ← Task 4.10
│           ├── ErrorsPage.swift                  ← Task 4.11
│           ├── SSRPage.swift                     ← Task 4.12
│           └── PWAPage.swift                     ← Task 4.13
└── Tests/ShowcaseTests/
    ├── HomePageTests.swift                       ← Task 6.1
    └── ChapterSnapshotTests.swift                ← Task 6.2

Sources/SwiftWUICLI/
├── Templates/showcase/                           ← Task 5.1 (synced from Examples/Showcase by Makefile)
├── Templates.swift                               ← Task 5.4 (trim)
├── FileGenerator.swift                           ← Task 5.3
└── SwiftWUICLI.swift                             ← Task 5.5 (--minimal flag)

Tests/SwiftWUICLITests/
└── ScaffoldShowcaseTests.swift                   ← Task 6.4

Makefile                                          ← Task 5.1 (sync-templates target)
Package.swift (root)                              ← Task 5.2 (resources entry on SwiftWUICLI target)
```

---

## Phase 0 — Worktree setup

### Task 0.1: Create worktree

- [ ] **Step 1: Create dedicated worktree**

```bash
cd /Users/gadzhievkt/dev/SwiftWUI
git worktree add .claude/worktrees/showcase-template -b feat/showcase-template
cd .claude/worktrees/showcase-template
```

- [ ] **Step 2: Verify clean state**

```bash
swift test 2>&1 | tail -5
```

Expected: All 314 tests pass, suite count unchanged.

- [ ] **Step 3: Commit worktree marker**

No commit yet — worktree just opened. Proceed to Phase 1.

---

## Phase 1 — Foundation: project skeleton

**Subagent:** `voltagent-lang:swift-expert` for Swift, `voltagent-core-dev:frontend-developer` for `index.html`. Hand off after each task with the file content as context.

### Task 1.1: Create Examples/Showcase Package.swift

**Files:**
- Create: `Examples/Showcase/Package.swift`

- [ ] **Step 1: Write the file**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{{PROJECT_NAME}}",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "SwiftWUI", path: "../../"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "{{PROJECT_NAME}}",
            dependencies: [
                .product(name: "SwiftWUI", package: "SwiftWUI"),
            ]
        ),
        .testTarget(
            name: "{{PROJECT_NAME}}Tests",
            dependencies: ["{{PROJECT_NAME}}"]
        ),
    ]
)
```

- [ ] **Step 2: Verify it parses (placeholder will fail to build, that is expected)**

```bash
cd Examples/Showcase && swift package describe 2>&1 | head -3
```

Expected: Package describes (Swift PM tolerates `{{PROJECT_NAME}}` as a name string at parse time).

- [ ] **Step 3: Commit**

```bash
git add Examples/Showcase/Package.swift
git commit -m "feat(showcase): add Package.swift skeleton with PROJECT_NAME placeholder"
```

---

### Task 1.2: Create Examples/Showcase/index.html

**Files:**
- Create: `Examples/Showcase/index.html`

- [ ] **Step 1: Write the file** (frontend-developer)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{PROJECT_NAME}} — built with SwiftWUI</title>
    <link
      rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/atom-one-dark.min.css">
    <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/core.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/languages/swift.min.js"></script>
    <script>
        // Register Swift language. Highlights apply once SwiftWUI mounts and
        // calls `hljs.highlightAll()` from `SyntaxHighlight.swift`.
        hljs.registerLanguage('swift', window.hljsDefineSwift || (() => ({})));
    </script>
    <style>
        html, body { margin: 0; padding: 0; }
        body { font-family: var(--font-text, system-ui), sans-serif; }
    </style>
</head>
<body>
    <div id="app"></div>
    <script type="module">
        import { init } from "{{project_name}}";
        await init();
    </script>
</body>
</html>
```

(Note: `{{project_name}}` lowercased — JS module name. `renameTokens` substitutes both casings; see Task 5.3.)

- [ ] **Step 2: Commit**

```bash
git add Examples/Showcase/index.html
git commit -m "feat(showcase): add index.html with highlight.js CDN load"
```

---

### Task 1.3: Create Examples/Showcase/Sources/main.swift stub

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/main.swift`

- [ ] **Step 1: Write the stub**

```swift
import SwiftWUI

struct PlaceholderPage: Tag {
    let title: String
    var body: some Tag {
        Div {
            H1 { Text(title) }
            P { Text("Coming soon — chapter content lands in Phase 4.") }
        }
        .padding(.px(48))
        .style("font-family", "system-ui, sans-serif")
    }
}

let app = Application {
    Route("/")                { PlaceholderPage(title: "{{PROJECT_NAME}}") }
    Route("/learn/hello")     { PlaceholderPage(title: "Hello, SwiftWUI") }
    Route("/learn/state")     { PlaceholderPage(title: "State & Bindings") }
    Route("/learn/modifiers") { PlaceholderPage(title: "Modifiers") }
    Route("/learn/lists")     { PlaceholderPage(title: "Lists & ForEach") }
    Route("/learn/forms")     { PlaceholderPage(title: "Forms & Inputs") }
    Route("/learn/routing")   { PlaceholderPage(title: "Routing & Guards") }
    Route("/learn/async")     { PlaceholderPage(title: "Async & Resources") }
    Route("/learn/theming")   { PlaceholderPage(title: "Theming") }
    Route("/learn/a11y")      { PlaceholderPage(title: "Accessibility") }
    Route("/learn/errors")    { PlaceholderPage(title: "Error Handling") }
    Route("/learn/ssr")       { PlaceholderPage(title: "SSR & Hydration") }
    Route("/learn/pwa")       { PlaceholderPage(title: "PWA") }
}
app.mount()
```

- [ ] **Step 2: Verify native build succeeds**

```bash
cd Examples/Showcase && swift build 2>&1 | tail -5
```

Expected: `Build complete!` (placeholder name `{{PROJECT_NAME}}` is treated as a literal target name string by Swift PM but causes the executable name to be the literal — acceptable for a build sanity check; rename happens at scaffold time).

If the literal placeholder breaks `swift build` locally, temporarily replace with `Showcase` for the duration of Phase 1–4 and add `Showcase` to `.gitignore` of placeholder substitution. (Decided in Task 5.3 design — the canonical name during dev is `Showcase`; placeholder substitution happens in `Templates/showcase/` only, not in `Examples/Showcase/`.)

**Decision applied here:** Use literal `Showcase` in `Examples/Showcase/Package.swift` and source files. The Makefile sync target rewrites `Showcase` → `{{PROJECT_NAME}}` and `showcase` → `{{project_name}}` when copying to `Sources/SwiftWUICLI/Templates/showcase/`. This keeps `Examples/Showcase` directly buildable and removes the placeholder-friction during development.

Update Task 1.1 inline: replace `{{PROJECT_NAME}}` with `Showcase` in `Examples/Showcase/Package.swift`. Update Task 1.2: replace `{{PROJECT_NAME}}` with `Showcase` and `{{project_name}}` with `showcase` in `index.html`. Tokenisation happens during Makefile sync (Task 5.1).

- [ ] **Step 3: Re-verify with literal name**

```bash
# After applying the Showcase rename in Tasks 1.1 + 1.2:
cd Examples/Showcase && rm -rf .build && swift build 2>&1 | tail -5
```

Expected: `Build complete!`. Executable named `Showcase`.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/
git commit -m "feat(showcase): scaffold project skeleton with 13 stub routes"
```

---

### Task 1.4: Add Examples/Showcase to root CI build

**Files:**
- Modify: `Makefile` (root)

- [ ] **Step 1: Read existing Makefile**

```bash
cat Makefile
```

- [ ] **Step 2: Add showcase build target**

Append to `Makefile`:

```make
.PHONY: showcase-build
showcase-build:
	cd Examples/Showcase && swift build

.PHONY: ci
ci: build test showcase-build
	@echo "CI green."
```

If `build`/`test` targets do not yet exist in the Makefile, add them with the obvious bodies (`swift build` / `swift test`).

- [ ] **Step 3: Run the new target**

```bash
make showcase-build
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "chore(ci): add showcase-build target to Makefile"
```

---

## Phase 2 — Theme + Layout

**Subagent:** `voltagent-lang:swift-expert`. Hand the `SwiftWUIStyles/Theme.swift` content as context (already shown in spec).

### Task 2.1: Create ShowcaseTheme

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/ThemeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Showcase

@Suite("ShowcaseTheme")
struct ShowcaseThemeTests {
    @Test func light_definesAllRequiredTokens() {
        let tokens = ShowcaseTheme.light.tokens
        for key in ShowcaseTheme.requiredTokens {
            #expect(tokens[key] != nil, "missing light token: \(key)")
        }
    }

    @Test func dark_definesAllRequiredTokens() {
        let tokens = ShowcaseTheme.dark.tokens
        for key in ShowcaseTheme.requiredTokens {
            #expect(tokens[key] != nil, "missing dark token: \(key)")
        }
    }

    @Test func accent_isOrange() {
        #expect(ShowcaseTheme.light.tokens["swui-accent"] == "#ff9500")
        #expect(ShowcaseTheme.dark.tokens["swui-accent"]  == "#ff9f0a")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Examples/Showcase && swift test --filter ShowcaseThemeTests 2>&1 | tail -5
```

Expected: FAIL with "cannot find ShowcaseTheme in scope".

- [ ] **Step 3: Write the implementation**

```swift
// ShowcaseTheme.swift — light/dark token sets for the SwiftWUI showcase.

import SwiftWUIStyles

public struct ShowcaseTheme: Theme {
    public let tokens: [String: String]

    private init(tokens: [String: String]) { self.tokens = tokens }

    public static let requiredTokens: [String] = [
        "swui-bg", "swui-surface", "swui-surface-2",
        "swui-fg", "swui-fg-2", "swui-fg-3",
        "swui-border", "swui-border-strong",
        "swui-accent", "swui-accent-bg",
        "swui-code-bg", "swui-code-fg",
        "space-1", "space-2", "space-3", "space-4",
        "space-5", "space-6", "space-7", "space-8",
        "radius-sm", "radius-md", "radius-lg",
        "font-display", "font-text", "font-mono",
    ]

    public static let light = ShowcaseTheme(tokens: [
        "swui-bg":             "#fbfbfd",
        "swui-surface":        "#ffffff",
        "swui-surface-2":      "#f5f5f7",
        "swui-fg":             "#1d1d1f",
        "swui-fg-2":           "#424245",
        "swui-fg-3":           "#6e6e73",
        "swui-border":         "#e8e8ed",
        "swui-border-strong":  "#d2d2d7",
        "swui-accent":         "#ff9500",
        "swui-accent-bg":      "#fff5e8",
        "swui-code-bg":        "#1d1d1f",
        "swui-code-fg":        "#f5f5f7",
        "space-1": "4px",  "space-2": "8px",  "space-3": "12px", "space-4": "16px",
        "space-5": "24px", "space-6": "32px", "space-7": "48px", "space-8": "64px",
        "radius-sm": "8px", "radius-md": "12px", "radius-lg": "18px",
        "font-display": "-apple-system, \"SF Pro Display\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-text":    "-apple-system, \"SF Pro Text\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-mono":    "ui-monospace, \"SF Mono\", \"Cascadia Code\", Menlo, Consolas, monospace",
    ])

    public static let dark = ShowcaseTheme(tokens: [
        "swui-bg":             "#000000",
        "swui-surface":        "#1d1d1f",
        "swui-surface-2":      "#2c2c2e",
        "swui-fg":             "#f5f5f7",
        "swui-fg-2":           "#a1a1a6",
        "swui-fg-3":           "#86868b",
        "swui-border":         "#3a3a3c",
        "swui-border-strong":  "#48484a",
        "swui-accent":         "#ff9f0a",
        "swui-accent-bg":      "#3a2410",
        "swui-code-bg":        "#0d0d0f",
        "swui-code-fg":        "#f5f5f7",
        "space-1": "4px",  "space-2": "8px",  "space-3": "12px", "space-4": "16px",
        "space-5": "24px", "space-6": "32px", "space-7": "48px", "space-8": "64px",
        "radius-sm": "8px", "radius-md": "12px", "radius-lg": "18px",
        "font-display": "-apple-system, \"SF Pro Display\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-text":    "-apple-system, \"SF Pro Text\", system-ui, \"Segoe UI\", Roboto, sans-serif",
        "font-mono":    "ui-monospace, \"SF Mono\", \"Cascadia Code\", Menlo, Consolas, monospace",
    ])
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Examples/Showcase && swift test --filter ShowcaseThemeTests 2>&1 | tail -5
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift Examples/Showcase/Tests/ShowcaseTests/ThemeTests.swift
git commit -m "feat(showcase): add ShowcaseTheme with light/dark tokens"
```

---

### Task 2.2: Add layout constants

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Theme/Layout.swift`

- [ ] **Step 1: Write the file**

```swift
// Layout.swift — page-level layout constants for the showcase.

import SwiftWUIStyles

public enum Layout {
    public static let maxContentWidth = "1180px"
    public static let pageHorizontalPadding = "24px"
    public static let stickyTopOffset = "96px"
    public static let scrollyStepMinHeight = "80vh"
    public static let mobileBreakpoint = "900px"
}
```

- [ ] **Step 2: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Theme/Layout.swift
git commit -m "feat(showcase): add layout constants"
```

---

### Task 2.3: Wire ShowcaseTheme into main.swift

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/main.swift`

- [ ] **Step 1: Inject the theme CSS at app boot**

Replace the file body with:

```swift
import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit

private func installThemeCSS() {
    let css = ThemeCSS.definitions(light: ShowcaseTheme.light, dark: ShowcaseTheme.dark)
    let document = JSObject.global.document.object!
    let style = document.createElement!("style").object!
    _ = style.setAttribute!("data-swui-theme", "showcase")
    style.textContent = .string(css)
    _ = document.head.object!.appendChild!(style)
}
#else
private func installThemeCSS() {}
#endif

installThemeCSS()

let app = Application {
    Route("/")                { PlaceholderPage(title: "Showcase") }
    Route("/learn/hello")     { PlaceholderPage(title: "Hello, SwiftWUI") }
    // … all 13 routes preserved …
}
app.mount()

struct PlaceholderPage: Tag { /* unchanged from Task 1.3 */ }
```

(Keep the full route list and `PlaceholderPage` struct from Task 1.3 — only `installThemeCSS` and the `installThemeCSS()` call are new.)

- [ ] **Step 2: Verify build still succeeds**

```bash
cd Examples/Showcase && swift build 2>&1 | tail -3
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/main.swift
git commit -m "feat(showcase): inject ShowcaseTheme CSS at boot"
```

---

### Task 2.4: Architectural review checkpoint

- [ ] **Step 1: Dispatch architect-reviewer subagent**

```
Agent({
  description: "Phase 2 architecture review",
  subagent_type: "voltagent-qa-sec:architect-reviewer",
  prompt: "Review the showcase theme integration in Examples/Showcase/Sources/Showcase/Theme/ and main.swift against the spec at docs/superpowers/specs/2026-04-29-showcase-template-design.md. Confirm: (1) ShowcaseTheme uses the existing Theme protocol from SwiftWUIStyles correctly, (2) ThemeCSS.definitions emits the precedence required by the spec (system pref + manual override), (3) installThemeCSS does not race with Application.mount, (4) no token name collisions with existing framework themes. Report concerns as a bulleted list. Under 300 words."
})
```

- [ ] **Step 2: Address findings**

Apply concrete fixes from the review. If the review surfaces a structural concern (rare at this phase), discuss with the user before proceeding.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix(showcase): address Phase 2 architecture review findings"
```

(Skip this commit if the review found nothing actionable.)

---

## Phase 3 — Reusable components

**Subagent:** `voltagent-lang:swift-expert` for Swift, `voltagent-core-dev:frontend-developer` for `SyntaxHighlight` and `ScrollyTeller`'s JS bridge.

Each component is a small, focused `Tag`. TDD pattern per task: write a TestRenderer-based snapshot assertion → fail → implement → pass → commit.

### Task 3.1: SiteChrome

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/SiteChrome.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/SiteChromeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("SiteChrome")
struct SiteChromeTests {
    @Test func rendersNavbarAndFooter() {
        struct Stub: Tag { var body: some Tag { Text("body") } }
        let renderer = StaticRenderer()
        let html = renderer.renderFragment(SiteChrome { Stub() })
        #expect(html.contains("data-swui-navbar"))
        #expect(html.contains("data-swui-footer"))
        #expect(html.contains("SwiftWUI"))
        #expect(html.contains("body"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Examples/Showcase && swift test --filter SiteChromeTests 2>&1 | tail -5
```

Expected: FAIL — `cannot find SiteChrome in scope`.

- [ ] **Step 3: Implement**

```swift
// SiteChrome.swift — shared navbar + footer wrapper.

import SwiftWUI

public struct SiteChrome<Content: Tag>: Tag {
    let content: Content

    public init(@TagBuilder _ content: () -> Content) {
        self.content = content()
    }

    public var body: some Tag {
        Div {
            navbar
            Main { content }
                .style("min-height", "calc(100vh - 160px)")
                .attr("data-swui-main", "true")
            footer
        }
        .style("background", "var(--swui-bg)")
        .style("color", "var(--swui-fg)")
        .style("font-family", "var(--font-text)")
        .attr("data-swui-chrome", "true")
    }

    private var navbar: some Tag {
        Div {
            Div {
                A(href: "/") { Text("SwiftWUI") }
                    .style("font-weight", "700")
                    .style("color", "var(--swui-fg)")
                    .style("text-decoration", "none")
                Div { Text("") }.style("flex", "1")
                Button(onclick: { toggleTheme() }) { Text("☀︎ / ☾") }
                    .style("border", "1px solid var(--swui-border-strong)")
                    .style("border-radius", "14px")
                    .style("padding", "4px 12px")
                    .style("background", "transparent")
                    .style("color", "var(--swui-fg)")
                    .style("font-size", "11px")
                    .style("cursor", "pointer")
                    .ariaLabel("Toggle colour theme")
            }
            .display(.flex)
            .style("align-items", "center")
            .style("gap", "16px")
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "12px \(Layout.pageHorizontalPadding)")
        }
        .style("background", "color-mix(in srgb, var(--swui-surface) 92%, transparent)")
        .style("border-bottom", "1px solid var(--swui-border)")
        .style("position", "sticky")
        .style("top", "0")
        .style("z-index", "50")
        .style("backdrop-filter", "saturate(180%) blur(20px)")
        .attr("data-swui-navbar", "true")
    }

    private var footer: some Tag {
        Div {
            Div {
                P { Text("Built with SwiftWUI · Real Swift in WebAssembly.") }
                    .style("color", "var(--swui-fg-3)")
                    .style("font-size", "12px")
                    .style("margin", "0")
            }
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "32px \(Layout.pageHorizontalPadding)")
        }
        .style("border-top", "1px solid var(--swui-border)")
        .attr("data-swui-footer", "true")
    }
}

#if canImport(JavaScriptKit)
import JavaScriptKit
private func toggleTheme() {
    let html = JSObject.global.document.object!.documentElement.object!
    let current = html.getAttribute!("data-theme").string ?? ""
    let next = current == "dark" ? "light" : "dark"
    _ = html.setAttribute!("data-theme", next)
    _ = JSObject.global.localStorage.object!.setItem!("swui-theme", next)
}
#else
private func toggleTheme() {}
#endif
```

(Helper modifiers like `.ariaLabel`, `.display`, `.attr` exist on the framework — verify with grep and adjust to actual names if needed. If `.attr` is named differently, use `.style("data-…", …)` is **wrong** — instead extend `Tag` with a small `func attr(_:_:) -> ModifiedContent<Self>` helper in this file if it does not exist already.)

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Examples/Showcase && swift test --filter SiteChromeTests 2>&1 | tail -5
```

Expected: PASS, 1 test.

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/SiteChrome.swift Examples/Showcase/Tests/ShowcaseTests/SiteChromeTests.swift
git commit -m "feat(showcase): add SiteChrome navbar/footer wrapper"
```

---

### Task 3.2: Hero

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/Hero.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/HeroTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Suite("Hero")
struct HeroTests {
    @Test func rendersAllSlots() {
        let html = StaticRenderer().renderFragment(
            Hero(
                eyebrow: "Build with SwiftWUI",
                headline: "Real Swift. Right in the browser.",
                subhead: "A declarative web framework that compiles to WebAssembly.",
                primaryCTA: ("Get started", "/learn/hello"),
                ghostCTA: ("View on GitHub", "https://github.com/AkhtarGadique/SwiftWUI"),
                code: "struct Counter: Tag {}"
            )
        )
        #expect(html.contains("Build with SwiftWUI"))
        #expect(html.contains("Real Swift"))
        #expect(html.contains("Get started"))
        #expect(html.contains("View on GitHub"))
        #expect(html.contains("struct Counter"))
        #expect(html.contains("data-swui-hero"))
    }
}
```

- [ ] **Step 2: Run test to fail**

```bash
cd Examples/Showcase && swift test --filter HeroTests
```

- [ ] **Step 3: Implement**

```swift
// Hero.swift — split hero with code-frame on the right.

import SwiftWUI

public struct Hero: Tag {
    let eyebrow: String
    let headline: String
    let subhead: String
    let primaryCTA: (label: String, href: String)
    let ghostCTA: (label: String, href: String)
    let code: String

    public init(eyebrow: String, headline: String, subhead: String,
                primaryCTA: (String, String), ghostCTA: (String, String),
                code: String) {
        self.eyebrow = eyebrow
        self.headline = headline
        self.subhead = subhead
        self.primaryCTA = primaryCTA
        self.ghostCTA = ghostCTA
        self.code = code
    }

    public var body: some Tag {
        Div {
            Div {
                Div {
                    P { Text(eyebrow) }
                        .style("color", "var(--swui-accent)")
                        .style("font-size", "11px")
                        .style("font-weight", "600")
                        .style("letter-spacing", "0.08em")
                        .style("text-transform", "uppercase")
                        .style("margin", "0 0 12px")
                    H1 { Text(headline) }
                        .style("font-family", "var(--font-display)")
                        .style("font-size", "48px")
                        .style("font-weight", "700")
                        .style("letter-spacing", "-0.02em")
                        .style("line-height", "1.05")
                        .style("margin", "0 0 16px")
                    P { Text(subhead) }
                        .style("color", "var(--swui-fg-2)")
                        .style("font-size", "17px")
                        .style("line-height", "1.5")
                        .style("max-width", "520px")
                        .style("margin", "0 0 24px")
                    Div {
                        A(href: primaryCTA.href) { Text(primaryCTA.label) }
                            .style("background", "var(--swui-fg)")
                            .style("color", "var(--swui-bg)")
                            .style("padding", "10px 22px")
                            .style("border-radius", "22px")
                            .style("text-decoration", "none")
                            .style("font-weight", "500")
                        A(href: ghostCTA.href) { Text(ghostCTA.label) }
                            .style("border", "1px solid var(--swui-border-strong)")
                            .style("color", "var(--swui-fg)")
                            .style("padding", "10px 22px")
                            .style("border-radius", "22px")
                            .style("text-decoration", "none")
                            .style("font-weight", "500")
                    }
                    .display(.flex)
                    .style("gap", "10px")
                }
                CodeFrame(code: code)
            }
            .style("display", "grid")
            .style("grid-template-columns", "1fr 1fr")
            .style("gap", "48px")
            .style("align-items", "center")
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "64px \(Layout.pageHorizontalPadding)")
        }
        .style("background", "linear-gradient(180deg, var(--swui-surface-2) 0%, var(--swui-bg) 100%)")
        .attr("data-swui-hero", "true")
    }
}

struct CodeFrame: Tag {
    let code: String
    var body: some Tag {
        Div {
            Div {
                Div { Text("") }.style("width", "9px").style("height", "9px").style("border-radius", "50%").style("background", "#5e5e5e")
                Div { Text("") }.style("width", "9px").style("height", "9px").style("border-radius", "50%").style("background", "#5e5e5e")
                Div { Text("") }.style("width", "9px").style("height", "9px").style("border-radius", "50%").style("background", "#5e5e5e")
            }
            .display(.flex)
            .style("gap", "5px")
            .style("padding", "12px 14px")
            .style("border-bottom", "1px solid #2a2a2c")
            Pre { Code { Text(code) }.style("font-family", "var(--font-mono)") }
                .style("margin", "0")
                .style("padding", "16px")
                .style("font-size", "13px")
                .style("color", "var(--swui-code-fg)")
                .style("overflow-x", "auto")
                .attr("class", "language-swift")
        }
        .style("background", "var(--swui-code-bg)")
        .style("border-radius", "var(--radius-md)")
        .style("box-shadow", "0 20px 50px rgba(0,0,0,0.15)")
        .style("overflow", "hidden")
        .attr("data-swui-codeframe", "true")
    }
}
```

- [ ] **Step 4: Pass + commit**

```bash
cd Examples/Showcase && swift test --filter HeroTests 2>&1 | tail -3
git add Examples/Showcase/Sources/Showcase/Components/Hero.swift Examples/Showcase/Tests/ShowcaseTests/HeroTests.swift
git commit -m "feat(showcase): add Hero split layout with CodeFrame"
```

---

### Task 3.3: ChapterCard

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/ChapterCard.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/ChapterCardTests.swift`

- [ ] **Step 1: Failing test**

```swift
@Suite("ChapterCard")
struct ChapterCardTests {
    @Test func rendersNumberTitleAndTeaser() {
        let html = StaticRenderer().renderFragment(
            ChapterCard(
                number: 2,
                title: "State & Bindings",
                subtitle: "Reactive data with @State.",
                codeTeaser: "@State var count = 0",
                href: "/learn/state"
            )
        )
        #expect(html.contains("CHAPTER 2"))
        #expect(html.contains("State &amp; Bindings") || html.contains("State & Bindings"))
        #expect(html.contains("@State var count"))
        #expect(html.contains("/learn/state"))
    }
}
```

- [ ] **Step 2: Fail → implement → pass**

```swift
// ChapterCard.swift — thumbnail card on the home grid.

import SwiftWUI

public struct ChapterCard: Tag {
    let number: Int
    let title: String
    let subtitle: String
    let codeTeaser: String
    let href: String

    public init(number: Int, title: String, subtitle: String, codeTeaser: String, href: String) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.codeTeaser = codeTeaser
        self.href = href
    }

    public var body: some Tag {
        A(href: href) {
            Div {
                Div { Text(codeTeaser) }
                    .style("font-family", "var(--font-mono)")
                    .style("font-size", "11px")
                    .style("color", "#884400")
                    .style("padding", "0 16px")
                    .style("display", "flex")
                    .style("align-items", "center")
                    .style("justify-content", "center")
                    .style("height", "100%")
                Div {
                    P { Text("CHAPTER \(number)") }
                        .style("font-size", "10px")
                        .style("color", "var(--swui-fg-3)")
                        .style("letter-spacing", "0.06em")
                        .style("margin", "0 0 4px")
                    H3 { Text(title) }
                        .style("font-size", "16px")
                        .style("font-weight", "600")
                        .style("margin", "0 0 6px")
                        .style("color", "var(--swui-fg)")
                    P { Text(subtitle) }
                        .style("font-size", "13px")
                        .style("color", "var(--swui-fg-3)")
                        .style("line-height", "1.4")
                        .style("margin", "0")
                }
                .style("padding", "14px 16px 18px")
            }
            .style("background", "var(--swui-surface)")
            .style("border", "1px solid var(--swui-border)")
            .style("border-radius", "var(--radius-md)")
            .style("overflow", "hidden")
        }
        .style("text-decoration", "none")
        .style("color", "inherit")
        .style("display", "block")
    }
}
```

(Thumbnail uses a static gradient background — add via inline style on the first `Div`: `.style("background", "linear-gradient(135deg, #fff5e8, #ffe4cc)").style("height", "90px")`.)

- [ ] **Step 3: Pass + commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/ChapterCard.swift Examples/Showcase/Tests/ShowcaseTests/ChapterCardTests.swift
git commit -m "feat(showcase): add ChapterCard thumbnail card"
```

---

### Task 3.4: BadgeGrid

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/BadgeGrid.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/BadgeGridTests.swift`

- [ ] **Step 1: Failing test**

```swift
@Suite("BadgeGrid")
struct BadgeGridTests {
    @Test func rendersAllBadges() {
        let html = StaticRenderer().renderFragment(
            BadgeGrid(items: [
                .init(title: "Container Queries", description: "Component-level responsive styles"),
                .init(title: "Hot Reload", description: "Sub-second iteration"),
            ])
        )
        #expect(html.contains("Container Queries"))
        #expect(html.contains("Hot Reload"))
        #expect(html.contains("Sub-second"))
    }
}
```

- [ ] **Step 2: Fail → implement → pass**

```swift
// BadgeGrid.swift — "What's Inside" mini-grid.

import SwiftWUI

public struct BadgeGrid: Tag {
    public struct Item: Sendable {
        public let title: String
        public let description: String
        public init(title: String, description: String) {
            self.title = title
            self.description = description
        }
    }

    let items: [Item]

    public init(items: [Item]) { self.items = items }

    public var body: some Tag {
        Div {
            ForEach(items, id: \.title) { item in
                Div {
                    H4 { Text(item.title) }
                        .style("font-size", "12px")
                        .style("font-weight", "600")
                        .style("margin", "0 0 4px")
                        .style("color", "var(--swui-fg)")
                    P { Text(item.description) }
                        .style("font-size", "11px")
                        .style("color", "var(--swui-fg-3)")
                        .style("line-height", "1.3")
                        .style("margin", "0")
                }
                .style("background", "var(--swui-surface)")
                .style("border", "1px solid var(--swui-border)")
                .style("border-radius", "var(--radius-sm)")
                .style("padding", "12px 14px")
            }
        }
        .style("display", "grid")
        .style("grid-template-columns", "repeat(auto-fit, minmax(200px, 1fr))")
        .style("gap", "10px")
    }
}
```

- [ ] **Step 3: Pass + commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/BadgeGrid.swift Examples/Showcase/Tests/ShowcaseTests/BadgeGridTests.swift
git commit -m "feat(showcase): add BadgeGrid for What's Inside section"
```

---

### Task 3.5: SyntaxHighlight (frontend-developer)

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/SyntaxHighlight.swift`

- [ ] **Step 1: Implement**

```swift
// SyntaxHighlight.swift — bridge to highlight.js loaded via CDN in index.html.

import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit

public enum SyntaxHighlight {
    public static func apply() {
        guard let hljs = JSObject.global.hljs.object else { return }
        _ = hljs.highlightAll!()
    }
}
#else
public enum SyntaxHighlight { public static func apply() {} }
#endif

/// Mount-time hook every chapter page calls in its `.task { … }` so code
/// blocks colourise after each route change.
public struct HighlightOnMount: Tag {
    public init() {}
    public var body: some Tag {
        Div { Text("") }
            .style("display", "none")
            .task { SyntaxHighlight.apply() }
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd Examples/Showcase && swift build 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/SyntaxHighlight.swift
git commit -m "feat(showcase): add SyntaxHighlight bridge to highlight.js"
```

---

### Task 3.6: CodeAndPreview

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/CodeAndPreview.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/CodeAndPreviewTests.swift`

- [ ] **Step 1: Failing test**

```swift
@Suite("CodeAndPreview")
struct CodeAndPreviewTests {
    @Test func rendersStepNumberTitleAndCode() {
        let html = StaticRenderer().renderFragment(
            CodeAndPreview(
                stepNumber: 1,
                title: "Add reactive storage",
                prose: "Mark a property @State.",
                code: "@State var count = 0",
                preview: AnyTag(Div { Text("preview") }),
                showInlinePreview: false
            )
        )
        #expect(html.contains("STEP 1"))
        #expect(html.contains("Add reactive storage"))
        #expect(html.contains("@State var count"))
        #expect(html.contains("data-scrolly-step=\"1\""))
    }
}
```

- [ ] **Step 2: Fail → implement → pass**

```swift
// CodeAndPreview.swift — single step in a chapter scrolly-teller.

import SwiftWUI

public struct CodeAndPreview: Tag {
    let stepNumber: Int
    let title: String
    let prose: String
    let code: String
    let preview: AnyTag
    let showInlinePreview: Bool

    public init(stepNumber: Int, title: String, prose: String, code: String,
                preview: AnyTag, showInlinePreview: Bool = true) {
        self.stepNumber = stepNumber
        self.title = title
        self.prose = prose
        self.code = code
        self.preview = preview
        self.showInlinePreview = showInlinePreview
    }

    public var body: some Tag {
        Div {
            Span { Text("STEP \(stepNumber)") }
                .style("display", "inline-block")
                .style("background", "var(--swui-surface-2)")
                .style("color", "var(--swui-fg-3)")
                .style("font-size", "10px")
                .style("font-weight", "600")
                .style("padding", "2px 8px")
                .style("border-radius", "var(--radius-sm)")
                .style("margin-bottom", "10px")
            H3 { Text(title) }
                .style("font-size", "20px")
                .style("font-weight", "600")
                .style("margin", "0 0 8px")
                .style("color", "var(--swui-fg)")
            P { Text(prose) }
                .style("color", "var(--swui-fg-2)")
                .style("font-size", "14px")
                .style("line-height", "1.55")
                .style("margin", "0 0 14px")
                .style("max-width", "560px")
            Pre { Code { Text(code) }.attr("class", "language-swift") }
                .style("background", "var(--swui-code-bg)")
                .style("color", "var(--swui-code-fg)")
                .style("border-radius", "var(--radius-sm)")
                .style("padding", "12px 14px")
                .style("font-family", "var(--font-mono)")
                .style("font-size", "12px")
                .style("margin", "0 0 16px")
                .style("overflow-x", "auto")
            if showInlinePreview {
                Div { preview }
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "var(--radius-sm)")
                    .style("padding", "16px")
                    .style("background", "var(--swui-surface)")
                    .attr("data-mobile-preview", "true")
            }
        }
        .style("background", "var(--swui-surface)")
        .style("border", "1px solid var(--swui-border)")
        .style("border-radius", "var(--radius-md)")
        .style("padding", "20px 22px")
        .style("min-height", Layout.scrollyStepMinHeight)
        .attr("data-scrolly-step", "\(stepNumber)")
    }
}
```

- [ ] **Step 3: Pass + commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/CodeAndPreview.swift Examples/Showcase/Tests/ShowcaseTests/CodeAndPreviewTests.swift
git commit -m "feat(showcase): add CodeAndPreview step component"
```

---

### Task 3.7: ScrollyTeller (swift-expert + frontend-developer)

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/ScrollyTellerTests.swift`

- [ ] **Step 1: Failing test**

```swift
@Suite("ScrollyTeller")
struct ScrollyTellerTests {
    @Test func rendersAllStepsAndStickyPane() {
        let steps = (1...3).map { n in
            ScrollyTeller.Step(
                number: n,
                title: "Step \(n)",
                prose: "Prose \(n)",
                code: "code \(n)",
                preview: AnyTag(Div { Text("preview \(n)") })
            )
        }
        let html = StaticRenderer().renderFragment(ScrollyTeller(steps: steps))
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"3\""))
        #expect(html.contains("data-swui-scrolly-sticky"))
    }
}
```

- [ ] **Step 2: Fail → implement → pass**

```swift
// ScrollyTeller.swift — 2-column scroll-driven teaching widget.

import SwiftWUI

#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public struct ScrollyTeller: Tag {
    public struct Step: Sendable {
        public let number: Int
        public let title: String
        public let prose: String
        public let code: String
        public let preview: AnyTag
        public init(number: Int, title: String, prose: String, code: String, preview: AnyTag) {
            self.number = number
            self.title = title
            self.prose = prose
            self.code = code
            self.preview = preview
        }
    }

    let steps: [Step]
    @State private var activeStep: Int = 1

    public init(steps: [Step]) { self.steps = steps }

    public var body: some Tag {
        Div {
            Div {
                ForEach(steps, id: \.number) { step in
                    CodeAndPreview(
                        stepNumber: step.number,
                        title: step.title,
                        prose: step.prose,
                        code: step.code,
                        preview: step.preview,
                        showInlinePreview: false
                    )
                }
            }
            .style("display", "flex")
            .style("flex-direction", "column")
            .style("gap", "32px")

            Div {
                Div {
                    Div {
                        if let active = steps.first(where: { $0.number == activeStep }) {
                            active.preview
                        } else if let first = steps.first {
                            first.preview
                        }
                    }
                    .style("padding", "32px 24px")
                    .style("background", "var(--swui-surface)")
                    .style("border", "1px solid var(--swui-border)")
                    .style("border-radius", "var(--radius-md)")
                    .attr("data-swui-scrolly-sticky", "true")
                    .attr("data-active-step", "\(activeStep)")
                }
                .style("position", "sticky")
                .style("top", Layout.stickyTopOffset)
            }
        }
        .style("display", "grid")
        .style("grid-template-columns", "1fr 1fr")
        .style("gap", "48px")
        .style("max-width", Layout.maxContentWidth)
        .style("margin", "0 auto")
        .style("padding", "32px \(Layout.pageHorizontalPadding)")
        .attr("data-swui-scrolly", "true")
        .task { @MainActor in
            installScrollyObserver(setActive: { newValue in
                self.activeStep = newValue
            })
        }
    }
}

#if canImport(JavaScriptKit)
@MainActor
private func installScrollyObserver(setActive: @escaping (Int) -> Void) {
    let document = JSObject.global.document.object!
    let steps = document.querySelectorAll!("[data-scrolly-step]").object!
    let length = Int(steps.length.number ?? 0)
    guard length > 0 else { return }

    let callback = JSClosure { args -> JSValue in
        guard let entries = args.first?.object else { return .undefined }
        let count = Int(entries.length.number ?? 0)
        for i in 0..<count {
            let entry = entries[i].object!
            if entry.isIntersecting.boolean ?? false {
                let target = entry.target.object!
                if let attr = target.getAttribute!("data-scrolly-step").string,
                   let n = Int(attr) {
                    setActive(n)
                }
            }
        }
        return .undefined
    }

    let options = JSObject.global.Object.function!.new()
    options.rootMargin = .string("-40% 0px -40% 0px")
    options.threshold = .number(0)

    let observer = JSObject.global.IntersectionObserver.function!.new(callback, options)
    for i in 0..<length {
        _ = observer.observe!(steps[i])
    }
}
#else
private func installScrollyObserver(setActive: @escaping (Int) -> Void) {}
#endif
```

- [ ] **Step 3: Pass + commit**

```bash
cd Examples/Showcase && swift test --filter ScrollyTellerTests 2>&1 | tail -3
git add Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift Examples/Showcase/Tests/ShowcaseTests/ScrollyTellerTests.swift
git commit -m "feat(showcase): add ScrollyTeller with IntersectionObserver"
```

---

## Phase 4 — Pages

**Subagent:** `voltagent-lang:swift-expert`. Provide the spec chapter table + components from Phase 3 as context.

### Task 4.1: HomePage

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Pages/HomePage.swift`
- Test: `Examples/Showcase/Tests/ShowcaseTests/HomePageTests.swift`

- [ ] **Step 1: Failing test**

```swift
@Suite("HomePage")
struct HomePageTests {
    @Test func rendersHeroAndAllChapterCards() {
        let html = StaticRenderer().renderFragment(HomePage())
        #expect(html.contains("data-swui-hero"))
        #expect(html.contains("CHAPTER 1"))
        #expect(html.contains("CHAPTER 12"))
        #expect(html.contains("What"))     // What's Inside section
        #expect(html.contains("Container Queries"))
    }
}
```

- [ ] **Step 2: Fail → implement → pass**

```swift
// HomePage.swift — landing page for the showcase.

import SwiftWUI

public struct HomePage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            Hero(
                eyebrow: "Build with SwiftWUI",
                headline: "Real Swift.\nRight in the browser.",
                subhead: "A declarative web framework that compiles to WebAssembly. State, routing, SSR — all the Swift you already know.",
                primaryCTA: ("Get started", "/learn/hello"),
                ghostCTA: ("View on GitHub", "https://github.com/AkhtarGadique/SwiftWUI"),
                code: heroCode
            )
            chapterSection(
                eyebrow: "Part 1 — Essentials",
                title: "Get to know SwiftWUI",
                description: "Three chapters covering tags, state, and modifiers.",
                cards: [
                    (1, "Hello, SwiftWUI",      "Build your first declarative view.",            "struct ContentView: Tag { … }",         "/learn/hello"),
                    (2, "State & Bindings",     "Reactive data with @State.",                    "@State var count = 0",                  "/learn/state"),
                    (3, "Modifiers",            "Style views with chained modifiers.",           ".padding(.px(16)).fontSize(.px(20))",   "/learn/modifiers"),
                ]
            )
            chapterSection(
                eyebrow: "Part 2 — Building UI",
                title: "Compose your interface",
                description: "Lists, forms, routing, and async data.",
                cards: [
                    (4,  "Lists & ForEach",      "Keyed reconciliation that preserves state.",   "ForEach(items, id: \\.id) { … }",     "/learn/lists"),
                    (5,  "Forms & Inputs",       "Typed Slider, Stepper, Picker, and friends.",  "Slider(value: $temp, in: 0...100)",   "/learn/forms"),
                    (6,  "Routing & Guards",     "Routes, params, and authentication gates.",    "Route(\"/admin\", guard: …) { … }",   "/learn/routing"),
                    (7,  "Async & Resources",    "Fetch data with .task { … } and async/await.", ".task { items = await fetch() }",     "/learn/async"),
                ]
            )
            chapterSection(
                eyebrow: "Part 3 — Production",
                title: "Ship to the web",
                description: "Theming, accessibility, error handling, SSR, PWA.",
                cards: [
                    (8,  "Theming",              "Light + dark via CSS custom properties.",      "ThemeCSS.definitions(light:dark:)",   "/learn/theming"),
                    (9,  "Accessibility",        "ARIA modifiers and semantic landmarks.",       ".ariaLabel(\"Close\")",               "/learn/a11y"),
                    (10, "Error Handling",       "Catch render-time errors with ErrorBoundary.", "ErrorBoundary { … }",                 "/learn/errors"),
                    (11, "SSR & Hydration",      "Render on the server, hydrate on the client.", "Application.hydrate(on: \"app\")",    "/learn/ssr"),
                    (12, "PWA",                  "Web App Manifest + Service Worker.",            "WebAppManifest(name: …)",             "/learn/pwa"),
                ]
            )
            whatsInsideSection
            HighlightOnMount()
        }
    }

    private func chapterSection(eyebrow: String, title: String, description: String,
                                cards: [(Int, String, String, String, String)]) -> some Tag {
        Div {
            Div {
                P { Text(eyebrow) }
                    .style("color", "var(--swui-accent)").style("font-size", "11px")
                    .style("font-weight", "600").style("letter-spacing", "0.08em")
                    .style("text-transform", "uppercase").style("margin", "0 0 8px")
                H2 { Text(title) }
                    .style("font-family", "var(--font-display)")
                    .style("font-size", "28px").style("font-weight", "600")
                    .style("margin", "0 0 4px").style("color", "var(--swui-fg)")
                P { Text(description) }
                    .style("font-size", "14px").style("color", "var(--swui-fg-3)")
                    .style("margin", "0 0 24px")
                Div {
                    ForEach(cards, id: \.0) { card in
                        ChapterCard(number: card.0, title: card.1, subtitle: card.2,
                                    codeTeaser: card.3, href: card.4)
                    }
                }
                .style("display", "grid")
                .style("grid-template-columns", "repeat(auto-fit, minmax(240px, 1fr))")
                .style("gap", "16px")
            }
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "48px \(Layout.pageHorizontalPadding)")
        }
    }

    private var whatsInsideSection: some Tag {
        Div {
            Div {
                P { Text("What's Inside") }
                    .style("color", "var(--swui-accent)").style("font-size", "11px")
                    .style("font-weight", "600").style("letter-spacing", "0.08em")
                    .style("text-transform", "uppercase").style("margin", "0 0 8px")
                H2 { Text("Production-ready features") }
                    .style("font-family", "var(--font-display)")
                    .style("font-size", "24px").style("margin", "0 0 4px")
                P { Text("Available in the framework — covered briefly in chapters or in the README.") }
                    .style("font-size", "14px").style("color", "var(--swui-fg-3)")
                    .style("margin", "0 0 16px")
                BadgeGrid(items: [
                    .init(title: "Container Queries",  description: "Component-level responsive styles"),
                    .init(title: "Anchor Positioning", description: "Type-safe popover positioning"),
                    .init(title: "Parameter Packs",    description: "Zero-cost variadic tag tuples"),
                    .init(title: "Hot Reload",         description: "Sub-second iteration in dev"),
                    .init(title: "Brotli + SRI",       description: "Compressed, integrity-checked builds"),
                    .init(title: "TestRenderer",       description: "Native unit tests, no browser"),
                    .init(title: "QueryParam",         description: "URL-driven state with @QueryParam"),
                    .init(title: "Doctor command",     description: "Toolchain health check"),
                ])
            }
            .style("max-width", Layout.maxContentWidth)
            .style("margin", "0 auto")
            .style("padding", "32px \(Layout.pageHorizontalPadding) 64px")
        }
    }

    private var heroCode: String {
        """
        struct Counter: Tag {
          @State var count = 0
          var body: some Tag {
            Button(onclick: { count += 1 }) {
              Text("Tapped \\(count)")
            }
          }
        }
        """
    }
}
```

- [ ] **Step 3: Pass + commit**

```bash
cd Examples/Showcase && swift test --filter HomePageTests
git add Examples/Showcase/Sources/Showcase/Pages/HomePage.swift Examples/Showcase/Tests/ShowcaseTests/HomePageTests.swift
git commit -m "feat(showcase): add HomePage with hero, 3 chapter sections, what's inside"
```

---

### Task 4.2: HelloPage (canonical chapter pattern)

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Pages/Chapters/HelloPage.swift`

The HelloPage is the canonical pattern — every other chapter file uses the same shape, only differing in `intro` text and `steps` content.

- [ ] **Step 1: Failing test (added in Task 6.2 batch)**

(Test for this page is part of the chapter snapshot test suite created in Phase 6. Skip the per-task test — Phase 6 adds them all.)

- [ ] **Step 2: Implement**

```swift
// HelloPage.swift — Chapter 1: Hello, SwiftWUI.

import SwiftWUI

public struct HelloPage: Tag {
    public init() {}

    public var body: some Tag {
        SiteChrome {
            ChapterIntro(
                part: "Chapter 1 — Essentials",
                title: "Hello, SwiftWUI",
                lead: "Build your first declarative view by conforming a struct to Tag and returning a body. By the end of this chapter you will mount a real SwiftWUI app on a DOM element and render styled HTML.",
                meta: ["Estimated time" : "5 min", "Difficulty" : "Beginner", "Module" : "SwiftWUICore"]
            )
            ScrollyTeller(steps: helloSteps)
            ChapterFooter(prev: nil, next: ("State & Bindings", "/learn/state"))
            HighlightOnMount()
        }
    }

    private var helloSteps: [ScrollyTeller.Step] { [
        .init(
            number: 1, title: "Conform a struct to Tag",
            prose: "Every SwiftWUI view starts the same way — declare a struct, conform to Tag, and define a body that returns more Tags.",
            code: """
            struct Greeting: Tag {
              var body: some Tag {
                H1 { Text("Hello, SwiftWUI") }
              }
            }
            """,
            preview: AnyTag(Div { H1 { Text("Hello, SwiftWUI") }.style("font-family", "var(--font-display)") })
        ),
        .init(
            number: 2, title: "Compose with @TagBuilder",
            prose: "The @TagBuilder result builder lets you write a list of children directly inside the body without commas or arrays.",
            code: """
            var body: some Tag {
              Div {
                H1 { Text("Hello") }
                P  { Text("Welcome.") }
              }
            }
            """,
            preview: AnyTag(Div {
                H1 { Text("Hello") }.style("font-family", "var(--font-display)").style("margin", "0")
                P  { Text("Welcome.") }.style("color", "var(--swui-fg-2)").style("margin", "8px 0 0")
            })
        ),
        .init(
            number: 3, title: "Mount on a DOM element",
            prose: "Application.mount() boots the runtime and renders into an element by id. The default id is `app`.",
            code: """
            let app = Application(page: { Greeting() })
            app.mount()
            """,
            preview: AnyTag(Div { Text("Mounted! Open the browser console and inspect #app.") }
                .style("font-family", "var(--font-mono)").style("font-size", "12px").style("color", "var(--swui-fg-3)"))
        ),
        .init(
            number: 4, title: "Style with chained modifiers",
            prose: "Add style by chaining modifiers. They are type-safe and order matters where CSS cascade rules apply.",
            code: """
            H1 { Text("Hello") }
              .fontSize(.px(28))
              .padding(.px(16))
              .style("color", "var(--swui-accent)")
            """,
            preview: AnyTag(H1 { Text("Hello") }.style("font-size", "28px").style("padding", "16px").style("color", "var(--swui-accent)").style("margin", "0"))
        ),
    ] }
}
```

- [ ] **Step 3: Verify build**

```bash
cd Examples/Showcase && swift build 2>&1 | tail -3
```

- [ ] **Step 4: Wire ChapterIntro + ChapterFooter helpers (small inline structs)**

Inside `Components/`, create `ChapterIntro.swift` (a small `Tag` that takes part/title/lead/meta and renders them) and `ChapterFooter.swift` (prev/next link row). Both are obvious renderings of the layout shown in the spec's chapter mockup. Add corresponding tiny snapshot tests in their own Test files.

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Pages/Chapters/HelloPage.swift \
        Examples/Showcase/Sources/Showcase/Components/ChapterIntro.swift \
        Examples/Showcase/Sources/Showcase/Components/ChapterFooter.swift \
        Examples/Showcase/Tests/ShowcaseTests/ChapterIntroTests.swift \
        Examples/Showcase/Tests/ShowcaseTests/ChapterFooterTests.swift
git commit -m "feat(showcase): add HelloPage canonical chapter + intro/footer helpers"
```

---

### Tasks 4.3 – 4.13: Remaining 11 chapter pages

Each chapter follows the exact pattern of `HelloPage`. The varying inputs are:
- `ChapterIntro`: `part`, `title`, `lead`, `meta`.
- `ScrollyTeller(steps:)`: 4–6 `Step` values whose `code` is the chapter's canonical Swift snippet and whose `preview` renders an inline live mini-view exercising that snippet.
- `ChapterFooter`: `prev` + `next` (chained per the chapter list).

For each chapter task, the implementer:
1. Copies `HelloPage.swift` to the new file.
2. Renames the type and updates `body` to call `ChapterIntro` with the chapter's part/title/lead/meta.
3. Replaces the steps array with the chapter's specific 4–6 `Step`s.
4. Updates `ChapterFooter` `prev` / `next`.
5. Builds + commits.

The per-chapter step content is content-creative, not architectural — it follows the table below. Each task in this run:

```
### Task 4.X: <ChapterName>Page
Files: Create Examples/Showcase/Sources/Showcase/Pages/Chapters/<ChapterName>Page.swift
- [ ] Copy HelloPage.swift, rename type, update intro
- [ ] Replace steps array with chapter content (see table)
- [ ] Update ChapterFooter prev/next
- [ ] swift build → succeeds
- [ ] git commit -m "feat(showcase): add <ChapterName>Page (chapter N)"
```

| Task | Chapter | Step canonical-code subjects |
|---|---|---|
| 4.3  | StatePage      | `@State var count`, mutation in `onclick`, `@Binding`, child propagation |
| 4.4  | ModifiersPage  | `.padding`, `.fontSize`, `.style` fallback, modifier order |
| 4.5  | ListsPage      | `ForEach(items, id: \.id)`, keyed reorder, identity stability |
| 4.6  | FormsPage      | `Slider`, `Stepper`, `Picker`, `DatePicker`, `ColorPicker`, validation |
| 4.7  | RoutingPage    | `Route(_:)`, route params, `RouteGuard`, redirect |
| 4.8  | AsyncPage      | `.task { … }`, `await fetch`, loading state |
| 4.9  | ThemingPage    | `Theme` proto, `ThemeCSS.definitions`, `data-theme` toggle |
| 4.10 | A11yPage       | `.ariaLabel`, semantic landmarks, focus management |
| 4.11 | ErrorsPage     | `ErrorBoundary { … } catch: { … }`, fallback UI |
| 4.12 | SSRPage        | `StaticRenderer.renderFragment`, `Application.hydrate(on:)` |
| 4.13 | PWAPage        | `WebAppManifest(name:short:icons:)`, `ServiceWorker.register(_:)` |

Each `lead` is one paragraph (≤ 60 words). Each step's `prose` is one paragraph (≤ 40 words). Each step's `preview` is a small live render using the framework — keep it self-contained (no network calls in browser-side previews; use static stub data).

**Per-chapter checkpoint:** after every 4 chapters (so after Tasks 4.5, 4.9, 4.13), run the full Examples/Showcase test suite:

```bash
cd Examples/Showcase && swift test 2>&1 | tail -10
```

Expected: all passing.

After Task 4.13, register all 13 routes in `main.swift` against the real page types instead of `PlaceholderPage`. Replace the route block with:

```swift
let app = Application {
    Route("/")                { HomePage() }
    Route("/learn/hello")     { HelloPage() }
    Route("/learn/state")     { StatePage() }
    Route("/learn/modifiers") { ModifiersPage() }
    Route("/learn/lists")     { ListsPage() }
    Route("/learn/forms")     { FormsPage() }
    Route("/learn/routing")   { RoutingPage() }
    Route("/learn/async")     { AsyncPage() }
    Route("/learn/theming")   { ThemingPage() }
    Route("/learn/a11y")      { A11yPage() }
    Route("/learn/errors")    { ErrorsPage() }
    Route("/learn/ssr")       { SSRPage() }
    Route("/learn/pwa")       { PWAPage() }
}
```

Commit: `feat(showcase): wire all 13 routes to real chapter pages`. Delete the `PlaceholderPage` struct.

---

### Task 4.14: Architectural review — Phase 4 boundary

- [ ] **Step 1: Dispatch architect-reviewer subagent**

```
Agent({
  description: "Phase 4 architecture review",
  subagent_type: "voltagent-qa-sec:architect-reviewer",
  prompt: "Review the showcase pages in Examples/Showcase/Sources/Showcase/Pages/ against the spec at docs/superpowers/specs/2026-04-29-showcase-template-design.md and the components in Sources/Showcase/Components/. Confirm: (1) all 12 chapter pages follow the same shape (SiteChrome > ChapterIntro > ScrollyTeller > ChapterFooter), (2) each chapter has 4-6 steps, (3) preview AnyTag values do not allocate unbounded resources, (4) IntersectionObserver lifecycle on ScrollyTeller does not leak across route changes, (5) no chapter shadows tokens or class-names from another. Report concerns as a bulleted list. Under 350 words."
})
```

- [ ] **Step 2: Address findings + commit**

```bash
git add -A
git commit -m "fix(showcase): address Phase 4 architecture review findings"
```

(Skip if review is clean.)

---

### Task 4.15: Manual browser smoke

- [ ] **Step 1: Boot dev server**

```bash
cd Examples/Showcase && swift run swiftwui dev --target Showcase --port 8080
```

(In a new terminal — leaves the server running.)

- [ ] **Step 2: Open the preview MCP**

Use Claude Preview to load `http://localhost:8080`. Verify visually:
- Hero renders with split layout, code-frame on right.
- 3 chapter sections each contain their cards.
- Click `Hello, SwiftWUI` card → URL becomes `/learn/hello`, ChapterIntro renders.
- Scroll past step 2 — right pane preview swaps content (`data-active-step` updates).
- Click theme toggle → background flips between light and dark.

If any step fails, stop and fix before Phase 5.

- [ ] **Step 3: Stop server, no commit (smoke is verification)**

---

## Phase 5 — CLI scaffolding integration

**Subagent:** `voltagent-lang:swift-expert`. Spec section "Scaffolding integration" is the source.

### Task 5.1: Makefile sync-templates target

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Append the target**

```make
.PHONY: sync-templates
sync-templates:
	rm -rf Sources/SwiftWUICLI/Templates/showcase
	mkdir -p Sources/SwiftWUICLI/Templates
	rsync -a --exclude='.build' --exclude='node_modules' \
	      --exclude='Tests' --exclude='.swiftpm' --exclude='dist' \
	      --exclude='Package.resolved' \
	      Examples/Showcase/ Sources/SwiftWUICLI/Templates/showcase/
	# Replace the literal "Showcase" target name with the placeholder
	# token used at scaffold time. Both casings are substituted.
	find Sources/SwiftWUICLI/Templates/showcase -type f \
	  \( -name '*.swift' -o -name '*.html' -o -name '*.md' \) \
	  -exec sed -i.bak 's/Showcase/{{PROJECT_NAME}}/g; s/showcase/{{project_name}}/g' {} +
	find Sources/SwiftWUICLI/Templates/showcase -type f -name '*.bak' -delete
```

(`sed -i.bak` is portable across BSD / GNU sed; we delete the `.bak` files afterwards.)

- [ ] **Step 2: Run it**

```bash
make sync-templates
ls Sources/SwiftWUICLI/Templates/showcase
grep -r "{{PROJECT_NAME}}" Sources/SwiftWUICLI/Templates/showcase | head -3
```

Expected: directory contains the synced files; `{{PROJECT_NAME}}` appears in the synced `Package.swift`, `index.html`, `main.swift`.

- [ ] **Step 3: Commit**

```bash
git add Makefile Sources/SwiftWUICLI/Templates/showcase
git commit -m "build(cli): sync Examples/Showcase to SwiftWUICLI Templates resource"
```

---

### Task 5.2: Add resource declaration to SwiftWUICLI target

**Files:**
- Modify: `Package.swift` (root)

- [ ] **Step 1: Find the SwiftWUICLI target block**

Open root `Package.swift` and locate the existing `.executableTarget(name: "SwiftWUICLI", …)`.

- [ ] **Step 2: Add resources**

Append to that target:

```swift
.executableTarget(
    name: "SwiftWUICLI",
    dependencies: [
        // … existing dependencies …
    ],
    resources: [
        .copy("Templates")
    ]
),
```

- [ ] **Step 3: Verify**

```bash
swift build --target SwiftWUICLI 2>&1 | tail -5
```

Expected: builds, the `Templates/` directory ships into the binary's resource bundle.

- [ ] **Step 4: Commit**

```bash
git add Package.swift
git commit -m "build(cli): bundle Templates as SwiftWUICLI resource"
```

---

### Task 5.3: FileGenerator.scaffoldShowcase

**Files:**
- Modify: `Sources/SwiftWUICLI/FileGenerator.swift`

- [ ] **Step 1: Read the existing file**

Identify the current `generate()` entry point.

- [ ] **Step 2: Add scaffoldShowcase + renameTokens**

```swift
extension FileGenerator {
    func scaffoldShowcase(at destination: URL) throws {
        guard let templateRoot = Bundle.module.url(
            forResource: "Templates/showcase",
            withExtension: nil
        ) else {
            throw NSError(
                domain: "SwiftWUICLI",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "Templates/showcase resource missing from bundle"]
            )
        }
        try FileManager.default.copyItem(at: templateRoot, to: destination)
        try renameTokens(in: destination, replacing: [
            "{{PROJECT_NAME}}": projectName,
            "{{project_name}}": projectName.lowercased(),
        ])
    }

    private func renameTokens(in dir: URL, replacing tokens: [String: String]) throws {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return }
        for case let url as URL in walker {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isFile else { continue }
            // Skip binary extensions defensively. Current template has none, but
            // future additions (PNGs, fonts) would otherwise corrupt.
            let ext = url.pathExtension.lowercased()
            let textExtensions: Set<String> = ["swift", "html", "md", "json", "css", "js", "yml", "yaml", "txt"]
            guard textExtensions.contains(ext) else { continue }
            var contents = try String(contentsOf: url, encoding: .utf8)
            for (token, value) in tokens {
                contents = contents.replacingOccurrences(of: token, with: value)
            }
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
```

- [ ] **Step 3: Update generate() to call scaffoldShowcase by default**

Replace the existing `generate()` body with a switch on a new property `mode` (added in Task 5.5):

```swift
func generate() throws {
    let dest = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(projectName)
    try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: false)
    switch mode {
    case .showcase: try scaffoldShowcase(at: dest)
    case .minimal:  try scaffoldMinimal(at: dest)   // existing literal-based scaffold
    }
}
```

(Move the existing literal-based `mainSwift` / `packageSwift` / `indexHTML` / `gitignore` / `readmeMD` content into a single `scaffoldMinimal(at:)` method.)

- [ ] **Step 4: Verify build**

```bash
swift build --target SwiftWUICLI 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUICLI/FileGenerator.swift
git commit -m "feat(cli): FileGenerator.scaffoldShowcase + token substitution"
```

---

### Task 5.4: Trim Templates.swift

**Files:**
- Modify: `Sources/SwiftWUICLI/Templates.swift`

- [ ] **Step 1: Reduce file to a single minimalScaffold(name:) method**

The new contents:

```swift
/// Minimal Counter-style scaffold returned by `scaffoldMinimal`. Used when
/// the user passes `--minimal` to `swiftwui init`. Keep this short: 30
/// lines of Swift across 4 files. The full showcase ships from
/// `Templates/showcase/` as a build-time resource.
enum Templates {
    static func minimalPackageSwift(name: String) -> String { /* unchanged */ }
    static func minimalMainSwift(name: String) -> String    { /* unchanged */ }
    static func minimalIndexHTML(name: String) -> String    { /* unchanged */ }
    static func minimalGitignore() -> String                { /* unchanged */ }
    static func minimalReadmeMD(name: String) -> String     { /* unchanged */ }
}
```

Rename the existing methods to `minimal*`. The bodies stay byte-identical — only the names change.

- [ ] **Step 2: Update callers**

Adjust any callers in `FileGenerator.scaffoldMinimal(at:)` to use the renamed methods.

- [ ] **Step 3: Build + commit**

```bash
swift build --target SwiftWUICLI 2>&1 | tail -3
git add Sources/SwiftWUICLI/Templates.swift Sources/SwiftWUICLI/FileGenerator.swift
git commit -m "refactor(cli): rename legacy templates to minimal* prefix"
```

---

### Task 5.5: Add --minimal flag to Init

**Files:**
- Modify: `Sources/SwiftWUICLI/SwiftWUICLI.swift`
- Modify: `Sources/SwiftWUICLI/FileGenerator.swift`

- [ ] **Step 1: Add the flag and `mode` plumbing**

In `SwiftWUICLI.swift`, replace the `Init` struct's `run()` body:

```swift
struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Scaffold a new SwiftWUI project."
    )

    @Argument(help: "Project name (letters, digits, hyphens, underscores).")
    var projectName: String

    @Flag(name: .long, help: "Use the minimal Counter-style scaffold instead of the showcase template.")
    var minimal: Bool = false

    func run() throws {
        guard isValidProjectName(projectName) else {
            throw ValidationError("Project name must contain only letters, numbers, hyphens, and underscores.")
        }
        let mode: FileGenerator.Mode = minimal ? .minimal : .showcase
        let generator = FileGenerator(projectName: projectName, mode: mode)
        try generator.generate()
        print("""

        Project '\(projectName)' created (\(mode == .minimal ? "minimal" : "showcase") template).

        Next steps:
          cd \(projectName)
          swiftwui dev --target \(projectName)

        Then open http://localhost:8080.
        """)
    }

    private func isValidProjectName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
```

In `FileGenerator.swift`, add:

```swift
extension FileGenerator {
    enum Mode: String { case showcase, minimal }
}
```

And update the initialiser to take `mode: Mode = .showcase`.

- [ ] **Step 2: Build + smoke**

```bash
swift build --target SwiftWUICLI 2>&1 | tail -3
swift run swiftwui init __TestShowcase__ 2>&1 | tail -5
ls __TestShowcase__/Sources
swift run swiftwui init __TestMinimal__ --minimal 2>&1 | tail -5
ls __TestMinimal__/Sources
rm -rf __TestShowcase__ __TestMinimal__
```

Expected:
- Showcase init produces a directory tree with `Theme/`, `Components/`, `Pages/Chapters/`.
- Minimal init produces only `main.swift`.

- [ ] **Step 3: Commit**

```bash
git add Sources/SwiftWUICLI/SwiftWUICLI.swift Sources/SwiftWUICLI/FileGenerator.swift
git commit -m "feat(cli): default init to showcase template, add --minimal flag"
```

---

### Task 5.6: Doctor drift check

**Files:**
- Modify: `Sources/SwiftWUICLI/SwiftWUICLI.swift`

- [ ] **Step 1: Add the check inside Doctor.run()**

After the existing tool checks, append:

```swift
checkShowcaseTemplateSync(&allOK)
```

And define:

```swift
private func checkShowcaseTemplateSync(_ allOK: inout Bool) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
        "-c",
        "diff -qr --exclude='.build' --exclude='Tests' --exclude='node_modules' --exclude='.swiftpm' --exclude='Package.resolved' Examples/Showcase Sources/SwiftWUICLI/Templates/showcase 2>/dev/null | grep -v '{{PROJECT_NAME}}' | head -5"
    ]
    process.standardOutput = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            print("✓ Showcase template in sync with Examples/Showcase")
        } else {
            print("⚠︎ Showcase template differs from Examples/Showcase — run `make sync-templates`")
        }
    } catch {
        print("⚠︎ Could not verify showcase template sync (diff unavailable)")
    }
}
```

(Diff-against-token-substituted output is approximate; the warning is non-fatal — drift is caught hard by CI in Task 6.5.)

- [ ] **Step 2: Build + smoke**

```bash
swift build --target SwiftWUICLI 2>&1 | tail -3
swift run swiftwui doctor | tail -10
```

- [ ] **Step 3: Commit**

```bash
git add Sources/SwiftWUICLI/SwiftWUICLI.swift
git commit -m "feat(cli): doctor warns when showcase template drifts"
```

---

### Task 5.7: Architectural review — Phase 5 boundary

- [ ] Dispatch `voltagent-qa-sec:architect-reviewer` with prompt covering: resource bundle path correctness, sed command portability, mode-flag plumbing, and atomicity of `copyItem` + `renameTokens` (rollback on failure mid-substitution). Address findings and commit.

---

## Phase 6 — Tests

**Subagent:** `voltagent-qa-sec:test-automator`.

### Task 6.1: HomePage snapshot test (already done in 4.1)

Confirmed in Task 4.1 — kept here for traceability. Skip.

### Task 6.2: Chapter snapshot tests

**Files:**
- Create: `Examples/Showcase/Tests/ShowcaseTests/ChapterSnapshotTests.swift`

- [ ] **Step 1: Write the suite**

```swift
import Testing
import SwiftWUI
import SwiftWUIRuntime
@testable import Showcase

@Suite("Chapter snapshots")
struct ChapterSnapshotTests {

    private func render(_ tag: some Tag) -> String {
        StaticRenderer().renderFragment(tag)
    }

    @Test func helloPage_hasFourSteps() {
        let html = render(HelloPage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("data-scrolly-step=\"4\""))
        #expect(html.contains("Hello, SwiftWUI"))
        #expect(html.contains("Application(page:"))
    }

    @Test func statePage_mentionsAtState() {
        let html = render(StatePage())
        #expect(html.contains("data-scrolly-step=\"1\""))
        #expect(html.contains("@State"))
    }

    @Test func modifiersPage_mentionsPadding() {
        let html = render(ModifiersPage())
        #expect(html.contains(".padding"))
    }

    @Test func listsPage_mentionsForEach() {
        let html = render(ListsPage())
        #expect(html.contains("ForEach"))
    }

    @Test func formsPage_mentionsSlider() {
        let html = render(FormsPage())
        #expect(html.contains("Slider"))
    }

    @Test func routingPage_mentionsRouteGuard() {
        let html = render(RoutingPage())
        #expect(html.contains("RouteGuard") || html.contains("guard:"))
    }

    @Test func asyncPage_mentionsTask() {
        let html = render(AsyncPage())
        #expect(html.contains(".task"))
    }

    @Test func themingPage_mentionsThemeCSS() {
        let html = render(ThemingPage())
        #expect(html.contains("ThemeCSS"))
    }

    @Test func a11yPage_mentionsAria() {
        let html = render(A11yPage())
        #expect(html.contains("ariaLabel") || html.contains("aria-label"))
    }

    @Test func errorsPage_mentionsErrorBoundary() {
        let html = render(ErrorsPage())
        #expect(html.contains("ErrorBoundary"))
    }

    @Test func ssrPage_mentionsHydrate() {
        let html = render(SSRPage())
        #expect(html.contains("hydrate"))
    }

    @Test func pwaPage_mentionsManifest() {
        let html = render(PWAPage())
        #expect(html.contains("WebAppManifest") || html.contains("manifest"))
    }
}
```

- [ ] **Step 2: Run + commit**

```bash
cd Examples/Showcase && swift test --filter ChapterSnapshotTests 2>&1 | tail -3
git add Examples/Showcase/Tests/ShowcaseTests/ChapterSnapshotTests.swift
git commit -m "test(showcase): add 12 chapter snapshot tests"
```

---

### Task 6.3: Workspace-level test that the showcase builds

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Strengthen showcase-build target**

```make
.PHONY: showcase-test
showcase-test:
	cd Examples/Showcase && swift test 2>&1 | tail -5

ci: build test showcase-build showcase-test
```

- [ ] **Step 2: Run + commit**

```bash
make showcase-test
git add Makefile
git commit -m "chore(ci): add showcase-test to CI Makefile target"
```

---

### Task 6.4: Scaffold integration test

**Files:**
- Create: `Tests/SwiftWUICLITests/ScaffoldShowcaseTests.swift`

- [ ] **Step 1: Write the test**

```swift
import Testing
import Foundation

@Suite("Scaffold — showcase template")
struct ScaffoldShowcaseTests {

    @Test func showcaseScaffoldCompiles() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let projectName = "TestApp"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "swift run swiftwui init \(projectName)"]
        process.currentDirectoryURL = tmp
        process.standardOutput = Pipe()
        process.standardError  = Pipe()
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let project = tmp.appendingPathComponent(projectName)
        let mainSwift = project.appendingPathComponent("Sources/\(projectName)/main.swift")
        let pkg       = project.appendingPathComponent("Package.swift")
        let chapter   = project.appendingPathComponent("Sources/\(projectName)/Pages/Chapters/HelloPage.swift")

        for f in [mainSwift, pkg, chapter] {
            #expect(FileManager.default.fileExists(atPath: f.path), "missing: \(f.lastPathComponent)")
        }

        // No placeholder remains.
        let pkgText = try String(contentsOf: pkg, encoding: .utf8)
        #expect(!pkgText.contains("{{PROJECT_NAME}}"))
        #expect(pkgText.contains(projectName))

        // Generated project compiles.
        let build = Process()
        build.executableURL = URL(fileURLWithPath: "/bin/sh")
        build.arguments = ["-c", "cd \(project.path) && swift build"]
        try build.run()
        build.waitUntilExit()
        #expect(build.terminationStatus == 0)
    }

    @Test func minimalFlagProducesSmallScaffold() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "swift run swiftwui init Min --minimal"]
        process.currentDirectoryURL = tmp
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let pages = tmp.appendingPathComponent("Min/Sources/Min/Pages")
        #expect(!FileManager.default.fileExists(atPath: pages.path),
                "minimal scaffold should not include Pages/")
    }
}
```

- [ ] **Step 2: Run + commit**

```bash
swift test --filter ScaffoldShowcaseTests 2>&1 | tail -10
git add Tests/SwiftWUICLITests/ScaffoldShowcaseTests.swift
git commit -m "test(cli): add scaffold integration tests for showcase + minimal"
```

(If `Tests/SwiftWUICLITests/` does not yet exist, also add a `testTarget` for it in root `Package.swift` — straightforward addition.)

---

### Task 6.5: CI hard-fail on template drift

**Files:**
- Modify: `.github/workflows/ci.yml` (or whatever CI definition exists; create if missing)

- [ ] **Step 1: Add a step**

```yaml
- name: Verify showcase template is in sync
  run: |
    make sync-templates
    git diff --exit-code Sources/SwiftWUICLI/Templates/showcase
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: hard-fail on showcase template drift"
```

---

## Phase 7 — Polish, README, final review

### Task 7.1: README in Examples/Showcase

**Files:**
- Create: `Examples/Showcase/README.md`

- [ ] **Step 1: Write a short README** (≤ 60 lines) with:
  - One-line description.
  - `swift run swiftwui dev --target Showcase` boot.
  - Link back to the spec doc.
  - Note: this directory is the source-of-truth for the `swiftwui init` showcase template; edits propagate via `make sync-templates`.

- [ ] **Step 2: Update root README**

In root `README.md`, replace the existing "Quick start" Counter snippet with the new flow:

```markdown
## Quick start

```bash
brew install swift wasm-opt brotli           # plus the swiftwasm SDK
swiftwui init MyApp                          # scaffolds the showcase template
cd MyApp && swiftwui dev --target MyApp
open http://localhost:8080
```

For a blank-slate project: `swiftwui init MyApp --minimal`.
```

- [ ] **Step 3: Commit**

```bash
git add Examples/Showcase/README.md README.md
git commit -m "docs: README updates for showcase scaffold"
```

---

### Task 7.2: UI polish review

- [ ] **Step 1: Boot dev server, take screenshots**

```bash
cd Examples/Showcase && swift run swiftwui dev --target Showcase --port 8080
```

Use Preview MCP to capture full-page screenshots of `/`, `/learn/hello`, `/learn/state` in both light and dark mode.

- [ ] **Step 2: Dispatch ui-designer subagent**

```
Agent({
  description: "Showcase UI polish review",
  subagent_type: "voltagent-core-dev:ui-designer",
  prompt: "Review these 6 screenshots (home, hello, state, all in light and dark) of the SwiftWUI showcase application. Verify: typographic hierarchy, spacing rhythm, contrast in dark mode, accent colour usage (orange = #ff9500 light / #ff9f0a dark), consistency of card surfaces, code-frame readability. Report concrete CSS/style fixes as a numbered list with file paths and exact value changes. Under 400 words.",
  // attach screenshots
})
```

- [ ] **Step 3: Apply fixes + commit**

```bash
git add -A
git commit -m "polish(showcase): apply UI designer feedback"
```

---

### Task 7.3: Final code review

- [ ] **Step 1: Dispatch code-reviewer subagent**

```
Agent({
  description: "Final code review",
  subagent_type: "voltagent-qa-sec:code-reviewer",
  prompt: "Review the entire showcase implementation in Examples/Showcase/ and the CLI changes in Sources/SwiftWUICLI/ against the spec at docs/superpowers/specs/2026-04-29-showcase-template-design.md. Focus on: (1) test coverage completeness, (2) any deviation from the spec's locked decisions, (3) accidental copying of Apple trademarks/assets, (4) error paths in FileGenerator (cleanup on partial copy failure), (5) drift surface mitigation. Surface only actionable issues. Under 500 words."
})
```

- [ ] **Step 2: Address findings + commit**

```bash
git add -A
git commit -m "fix(showcase): address final code review findings"
```

---

### Task 7.4: Merge to main

- [ ] **Step 1: Run full CI locally**

```bash
make ci
```

Expected: green.

- [ ] **Step 2: Merge worktree branch**

Use `superpowers:finishing-a-development-branch` to choose between fast-forward, rebase, or PR-based merge per project convention.

---

## Self-Review

**1. Spec coverage:** Walked the spec section-by-section.
- Goal / Non-goals / Scope: addressed by Phases 1–7 collectively. ✓
- Macro decisions table: each of the 6 decisions has a concrete task implementing it (Phase 5 = #1 + #2, Phase 3.5/3.7 = #3, Phase 2 = #4, Phase 3.2 = #5, Phase 3.3 = #6). ✓
- Project layout: Task 0 + Tasks 1.1–1.3 + Phase 3 + Phase 4. ✓
- Component contracts (SiteChrome, Hero, ChapterCard, BadgeGrid, ScrollyTeller, CodeAndPreview, SyntaxHighlight): Tasks 3.1–3.7. ✓
- Routing (13 routes): Task 1.3 stub + Task 4.13 final wiring. ✓
- Chapter content (12 chapters × 4–6 steps): Tasks 4.2–4.13. ✓
- Theming (token table, mode resolution): Tasks 2.1, 2.3. The `data-theme` toggle wiring lives in `SiteChrome` (Task 3.1). ✓
- Scaffolding (Makefile, resource decl, FileGenerator, --minimal, doctor): Tasks 5.1–5.6. ✓
- Testing (compile, snapshot, scaffold, smoke, drift): Tasks 6.1–6.5 + 4.15. ✓
- Risks: bundle size + CDN dependency + drift acknowledged in spec; drift mitigations live in 5.1, 5.6, 6.5. ✓

**2. Placeholder scan:** searched for "TBD", "TODO", "fill in", "appropriate error handling", "similar to Task". The chapter content tables in Task 4.3–4.13 do reference a single canonical pattern (HelloPage) rather than duplicating full code per chapter — this is intentional and the table provides exact `step.code` subjects per chapter; flagged for the executing agent that creative chapter prose is theirs to write inside the spec's voice.

**3. Type consistency:** verified — `ScrollyTeller.Step`, `BadgeGrid.Item`, `FileGenerator.Mode` use consistent property names across tasks; `ChapterCard.init` signature matches its single call site in `HomePage.chapterSection`.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-29-showcase-template.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task (using the assignments locked above: swift-expert / frontend-developer / architect-reviewer / test-automator / ui-designer / code-reviewer), review between tasks, fast iteration.

**2. Inline Execution** — I run the tasks myself in this session using `superpowers:executing-plans`, with checkpoints for review.

**Which approach?**
