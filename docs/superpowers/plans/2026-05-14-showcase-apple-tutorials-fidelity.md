# Showcase Apple Tutorials Fidelity — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the existing 13-route SwiftWUI showcase to pixel-faithful parity with Apple's "Develop in Swift Tutorials" reference, ship hybrid live/screenshot previews, complete the `.style()` → typed-modifier migration, and gate everything with a Playwright suite (smoke + nav + scrolly + a11y + visual + per-preview snapshot).

**Architecture:** Pure refactor + visual upgrade on a single cohesive PR against `feat/showcase-template`. No new modules. Plan phases mirror spec §5 (P0–P8), but Playwright harness ships before the `.style()` sweep so the sweep's "0 px visual diff" acceptance has a working baseline. Implementation is multi-agent: each phase lists primary + review agents.

**Tech Stack:** Swift 6 (WASM target via swift-6.2.3-RELEASE_wasm SDK), SwiftWUI framework modules, Vite dev server, Playwright + @axe-core/playwright, npm.

**Spec:** `docs/superpowers/specs/2026-05-14-showcase-apple-tutorials-fidelity-design.md` (commit `b10eccf`).

**Worktree:** All work happens at `/Users/gadzhievkt/dev/SwiftWUI/.claude/worktrees/showcase-template` on branch `feat/showcase-template`.

---

## Codebase orientation (read first)

- Showcase Swift sources live under `Examples/Showcase/Sources/Showcase/` — 9 components, 1 theme dir, 1 home page, 12 chapter pages.
- `Sources/SwiftWUICLI/Templates/showcase/` mirrors `Examples/Showcase/` exactly. **Never edit it by hand.** Run `make sync-templates` after every committed showcase change. CI fails on drift.
- Tests under `Examples/Showcase/Tests/ShowcaseTests/` use `SwiftWUITestRenderer` to stringify Tags. 28 tests pass today; the bar.
- Existing typed modifiers live in `Sources/SwiftWUIStyles/StyleModifier.swift`, `Sources/SwiftWUIStyles/StyleProxy.swift`, etc. The raw escape hatch is `.style("css-prop", value)` defined in `Sources/SwiftWUICore/TagModifier.swift`.
- Native build: `swift build` (51 tests in core), `swift test`.
- Showcase build: `make showcase-build` (delegates to `cd Examples/Showcase && swift build`).
- Showcase tests: `make showcase-test` (28 tests under ShowcaseTests).
- CI aggregate: `make ci` runs build + test + showcase-build + showcase-test. After this plan, `make ci-playwright` joins.
- Sync source-of-truth: `make sync-templates` rebuilds `Sources/SwiftWUICLI/Templates/showcase/` from `Examples/Showcase/`. CI's "template drift" guard fails if you forget.

---

## File map (locked before tasks)

### New files (Swift, framework-level)

- `Sources/SwiftWUIStyles/TypographyModifiers.swift` — `fontFamily`, `textTransform`, `letterSpacing`, `lineHeight`, `whiteSpace`, `textAlign`, `textDecoration`, `textIndent`.
- `Tests/SwiftWUIStylesTests/TypographyModifiersTests.swift` — TestRenderer-driven assertions on each new modifier.

### Modified files (Swift, framework-level)

- `Sources/SwiftWUIStyles/StyleModifier.swift` — add `backdropFilter`, `cursor`, `boxShadow`, full `borderTop / borderRight / borderBottom / borderLeft`.

### New files (showcase, Swift)

- `Examples/Showcase/Sources/Showcase/Components/TutorialTopBar.swift`
- `Examples/Showcase/Sources/Showcase/Components/ChapterPickerPopover.swift`
- `Examples/Showcase/Sources/Showcase/Components/SectionPickerPopover.swift`
- `Examples/Showcase/Sources/Showcase/Components/ThemeToggle.swift`
- `Examples/Showcase/Sources/Showcase/Components/PreviewFrame.swift`
- `Examples/Showcase/Sources/Showcase/Components/PreviewKind.swift`
- `Examples/Showcase/Sources/Showcase/Components/StepNavButtons.swift`
- `Examples/Showcase/Sources/Showcase/Components/ChapterRegistry.swift` — single source of truth for chapter metadata (id, title, slug, group, steps) used by the popovers.

### Modified files (showcase, Swift)

- `Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift` — replace token set with §4.2 light/dark tables; emit `@media (prefers-color-scheme: …)` blocks + `[data-theme=…]` overrides.
- `Examples/Showcase/Sources/Showcase/Components/SiteChrome.swift` — strip old horizontal link bar; mount `TutorialTopBar`.
- `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift` — extend `Step` with `highlightLines: [Int]`, change `preview` type from `AnyTag` to `PreviewKind`; render line-numbered code panel + active-step bar + preview crossfade.
- `Examples/Showcase/Sources/Showcase/Components/SyntaxHighlight.swift` — emit `<table>` with line-number gutter, expose `data-line` attributes for highlight scripting.
- `Examples/Showcase/Sources/Showcase/Components/CodeAndPreview.swift` — adapt to `PreviewKind`.
- `Examples/Showcase/Sources/Showcase/Components/{Hero,ChapterCard,ChapterIntro,ChapterFooter,BadgeGrid}.swift` — `.style()` → typed.
- `Examples/Showcase/Sources/Showcase/Pages/HomePage.swift` — `.style()` → typed; mount new TutorialTopBar via SiteChrome.
- `Examples/Showcase/Sources/Showcase/Pages/Chapters/*.swift` (12 files) — `.style()` → typed; new `highlightLines: [Int]` per step; `.live(…)` → `PreviewKind.live(…)` for now (Phase 6 introduces `.screenshot(…)`).
- `Examples/Showcase/Sources/Showcase/main.swift` — commit the already-on-disk SPA navigation glue (link interception + popstate) that this worktree carries uncommitted.

### New files (showcase, tests + tooling)

- `Examples/Showcase/tests/package.json`
- `Examples/Showcase/tests/tsconfig.json`
- `Examples/Showcase/tests/playwright.config.ts`
- `Examples/Showcase/tests/lib/{routes,viewports,themes,helpers}.ts`
- `Examples/Showcase/tests/{smoke,nav,scrolly,a11y,visual,preview}.spec.ts`
- `Examples/Showcase/tests/__screenshots__/.gitkeep`
- `Examples/Showcase/Resources/snapshots/.gitkeep`

### New showcase tests (Swift, TestRenderer-based)

- `Examples/Showcase/Tests/ShowcaseTests/ThemeToggleTests.swift`
- `Examples/Showcase/Tests/ShowcaseTests/ChapterPickerPopoverTests.swift`
- `Examples/Showcase/Tests/ShowcaseTests/SectionPickerPopoverTests.swift`
- `Examples/Showcase/Tests/ShowcaseTests/TutorialTopBarTests.swift`
- `Examples/Showcase/Tests/ShowcaseTests/StepNavButtonsTests.swift`
- `Examples/Showcase/Tests/ShowcaseTests/PreviewFrameTests.swift`
- `Examples/Showcase/Tests/ShowcaseTests/PreviewKindTests.swift`
- `Examples/Showcase/Tests/ShowcaseTests/ChapterRegistryTests.swift`

### Modified tooling

- `Makefile` — new targets `showcase-snapshots`, `showcase-playwright`, `ci-playwright`; extend `ci` aggregate.
- `.github/workflows/ci.yml` — add Playwright job after showcase tests.
- `.gitignore` — append `Examples/Showcase/tests/node_modules/`, `Examples/Showcase/tests/test-results/`, `Examples/Showcase/tests/playwright-report/`.

---

## Migration table (used in Phase 3)

Apply these rewrites mechanically. Anything still using `.style(...)` after the sweep must have a `--custom-prop` first argument or be flagged for a follow-up typed modifier.

| Raw `.style(...)`                                  | Typed equivalent                                                              | Source of typed modifier          |
| -------------------------------------------------- | ------------------------------------------------------------------------------ | --------------------------------- |
| `.style("display", "flex")`                        | `.display(.flex)`                                                              | StyleModifier (existing)          |
| `.style("display", "grid")`                        | `.display(.grid)`                                                              | StyleModifier (existing)          |
| `.style("display", "none")`                        | `.display(.none)`                                                              | StyleModifier (existing)          |
| `.style("flex-direction", "column")`               | `.flexDirection(.column)`                                                      | StyleModifier (existing)          |
| `.style("align-items", "center")`                  | `.alignItems(.center)`                                                         | StyleModifier (existing)          |
| `.style("justify-content", "space-between")`       | `.justifyContent(.spaceBetween)`                                               | StyleModifier (existing)          |
| `.style("gap", "10px")`                            | `.gap(.px(10))`                                                                | StyleModifier (existing)          |
| `.style("grid-template-columns", "…")`             | `.gridTemplateColumns("…")`                                                    | StyleModifier (existing)          |
| `.style("padding", "32px 64px")`                   | `.padding(.px(32), .px(64))`                                                   | StyleModifier (existing)          |
| `.style("margin", "0 auto")`                       | `.margin(.zero, .auto)`                                                        | StyleModifier (existing)          |
| `.style("background", v)`                          | `.background(.css(v))` / `.background(.token("swui-bg"))`                      | StyleModifier (existing)          |
| `.style("border", "1px solid …")`                  | `.border(width: .px(1), style: .solid, color: .css("…"))`                     | StyleModifier (existing)          |
| `.style("border-top", v)`                          | `.borderTop(width:style:color:)`                                               | StyleModifier extension (Phase 1) |
| `.style("border-radius", v)`                       | `.borderRadius(.px(...))` / `.borderRadius(.token("radius-sm"))`               | StyleModifier (existing)          |
| `.style("color", v)`                               | `.foregroundColor(.css(v))` / `.foregroundColor(.token("swui-fg"))`            | StyleModifier (existing)          |
| `.style("font-size", "11px")`                      | `.fontSize(.px(11))`                                                           | StyleModifier (existing)          |
| `.style("font-weight", "600")`                     | `.fontWeight(.w600)`                                                           | StyleModifier (existing)          |
| `.style("font-family", v)`                         | `.fontFamily(v)`                                                               | TypographyModifiers (Phase 1)     |
| `.style("text-transform", "uppercase")`            | `.textTransform(.uppercase)`                                                   | TypographyModifiers (Phase 1)     |
| `.style("letter-spacing", "0.08em")`               | `.letterSpacing(.em(0.08))`                                                    | TypographyModifiers (Phase 1)     |
| `.style("line-height", "1.5")`                     | `.lineHeight(.unitless(1.5))`                                                  | TypographyModifiers (Phase 1)     |
| `.style("text-align", "right")`                    | `.textAlign(.right)`                                                           | TypographyModifiers (Phase 1)     |
| `.style("text-decoration", "none")`                | `.textDecoration(.none)`                                                       | TypographyModifiers (Phase 1)     |
| `.style("white-space", "nowrap")`                  | `.whiteSpace(.nowrap)`                                                         | TypographyModifiers (Phase 1)     |
| `.style("max-width", v)`                           | `.maxWidth(.px(...))` / `.maxWidth(.token("..."))`                             | StyleModifier (existing)          |
| `.style("min-height", v)`                          | `.minHeight(.px(...))`                                                         | StyleModifier (existing)          |
| `.style("backdrop-filter", v)`                     | `.backdropFilter(v)`                                                           | StyleModifier extension (Phase 1) |
| `.style("box-shadow", v)`                          | `.boxShadow(.css(v))`                                                          | StyleModifier extension (Phase 1) |
| `.style("cursor", "pointer")`                      | `.cursor(.pointer)`                                                            | StyleModifier extension (Phase 1) |
| `.style("position", v)` / `.style("inset", v)` etc | `.position(.absolute)` / `.inset(...)`                                         | StyleModifier (existing)          |
| `.style("--swui-foo", v)`                          | **leave unchanged** — CSS custom-prop assignment is the legitimate escape hatch |                                   |

A grep target locks the post-sweep acceptance:

```bash
grep -rn '\.style(' Examples/Showcase/Sources --include='*.swift' \
  | grep -vE '\.style\("--' \
  | wc -l
# must be 0
```

---

## Phase 0 — Design tokens (spec P0)

**Primary:** swift-expert + ui-designer · **Review:** architect-reviewer

### Task 1: Add tests for new ShowcaseTheme tokens

**Files:**
- Create: `Examples/Showcase/Tests/ShowcaseTests/ThemeTests.swift` (replace existing)
- Reference: `Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift`

- [ ] **Step 1: Read existing ThemeTests**

Run: `cat Examples/Showcase/Tests/ShowcaseTests/ThemeTests.swift`

Skim the structure; we replace it.

- [ ] **Step 2: Write the failing test file**

Open `Examples/Showcase/Tests/ShowcaseTests/ThemeTests.swift` and replace its contents:

```swift
import Testing
@testable import Showcase

@Suite("ShowcaseTheme")
struct ShowcaseThemeTests {
    @Test("Emits dark-mode tokens by default under prefers-color-scheme: dark")
    func darkTokens() {
        let css = ShowcaseTheme.css
        #expect(css.contains("--swui-bg: #000000"))
        #expect(css.contains("--swui-fg: #f5f5f7"))
        #expect(css.contains("--swui-accent: #5ac8b0"))
        #expect(css.contains("--syntax-keyword: #fc5fa3"))
    }

    @Test("Emits light-mode tokens under prefers-color-scheme: light")
    func lightTokens() {
        let css = ShowcaseTheme.css
        #expect(css.contains("@media (prefers-color-scheme: light)"))
        #expect(css.contains("--swui-bg: #ffffff"))
        #expect(css.contains("--swui-fg: #1d1d1f"))
        #expect(css.contains("--swui-accent: #0a84ff"))
        #expect(css.contains("--syntax-keyword: #ad3da4"))
    }

    @Test("Manual override via [data-theme=light] beats system default")
    func manualLightOverride() {
        let css = ShowcaseTheme.css
        #expect(css.contains(":root[data-theme=\"light\"]"))
        #expect(css.contains(":root[data-theme=\"dark\"]"))
    }

    @Test("Tutorials accent matches the Apple wordmark mint-teal in dark mode")
    func accentMatchesReference() {
        let css = ShowcaseTheme.css
        #expect(css.contains("--swui-accent: #5ac8b0"))
        #expect(css.contains("--swui-accent-strong: #66e1c1"))
    }

    @Test("All required tokens declared in both modes")
    func allTokensDeclared() {
        let required: [String] = [
            "--swui-bg", "--swui-surface", "--swui-surface-2",
            "--swui-fg", "--swui-fg-2", "--swui-fg-3",
            "--swui-border", "--swui-border-strong",
            "--swui-accent", "--swui-accent-strong",
            "--swui-code-bg", "--swui-code-line-hl",
            "--syntax-keyword", "--syntax-type", "--syntax-string",
            "--syntax-number", "--syntax-comment",
            "--font-display", "--font-text", "--font-mono",
        ]
        for token in required {
            #expect(ShowcaseTheme.css.contains(token), "missing token: \(token)")
        }
    }
}
```

- [ ] **Step 3: Run tests, confirm they fail**

Run: `cd Examples/Showcase && swift test --filter ShowcaseThemeTests`
Expected: FAIL — old token set doesn't have these values.

- [ ] **Step 4: Commit failing test**

```bash
git add Examples/Showcase/Tests/ShowcaseTests/ThemeTests.swift
git commit -m "test(showcase): expand theme tests for Apple-fidelity tokens"
```

### Task 2: Replace ShowcaseTheme token set

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift`

- [ ] **Step 1: Read the existing file**

Run: `cat Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift`

Note the existing `static let css: String = """ … """` shape. We replace the CSS body.

- [ ] **Step 2: Write the new theme**

Replace the file contents:

```swift
// ShowcaseTheme.swift — Apple Tutorials–fidelity token set.
// Dark-default (matches cited reference). Light variant designed to feel
// like Apple's lighter docs sections. Manual override via
// <html data-theme="light|dark"> beats the @media default.

import SwiftWUI

public enum ShowcaseTheme {
    public static let css: String = """
    :root {
      --swui-bg: #000000;
      --swui-surface: #1c1c1e;
      --swui-surface-2: #2c2c2e;
      --swui-fg: #f5f5f7;
      --swui-fg-2: #98989d;
      --swui-fg-3: #6e6e73;
      --swui-border: rgba(255, 255, 255, 0.10);
      --swui-border-strong: rgba(255, 255, 255, 0.22);
      --swui-accent: #5ac8b0;
      --swui-accent-strong: #66e1c1;
      --swui-code-bg: #1d1d1f;
      --swui-code-line-hl: rgba(255, 255, 255, 0.06);
      --syntax-keyword: #fc5fa3;
      --syntax-type: #5dd8ff;
      --syntax-string: #fc6a5d;
      --syntax-number: #d0bf69;
      --syntax-comment: #7f8c98;
      --font-display: -apple-system, "SF Pro Display", "Segoe UI", sans-serif;
      --font-text: -apple-system, "SF Pro Text", "Segoe UI", sans-serif;
      --font-mono: "SF Mono", "Menlo", "Cascadia Code", monospace;
      --radius-sm: 6px;
      --radius-md: 10px;
      --radius-lg: 16px;
      --radius-pill: 999px;
    }

    @media (prefers-color-scheme: light) {
      :root:not([data-theme="dark"]) {
        --swui-bg: #ffffff;
        --swui-surface: #f5f5f7;
        --swui-surface-2: #ebebf0;
        --swui-fg: #1d1d1f;
        --swui-fg-2: #6e6e73;
        --swui-fg-3: #aeaeb2;
        --swui-border: rgba(0, 0, 0, 0.10);
        --swui-border-strong: rgba(0, 0, 0, 0.18);
        --swui-accent: #0a84ff;
        --swui-accent-strong: #007aff;
        --swui-code-bg: #f5f5f7;
        --swui-code-line-hl: rgba(0, 0, 0, 0.04);
        --syntax-keyword: #ad3da4;
        --syntax-type: #0f68a2;
        --syntax-string: #c41a16;
        --syntax-number: #272ad8;
        --syntax-comment: #5d6c79;
      }
    }

    :root[data-theme="light"] {
      --swui-bg: #ffffff;
      --swui-surface: #f5f5f7;
      --swui-surface-2: #ebebf0;
      --swui-fg: #1d1d1f;
      --swui-fg-2: #6e6e73;
      --swui-fg-3: #aeaeb2;
      --swui-border: rgba(0, 0, 0, 0.10);
      --swui-border-strong: rgba(0, 0, 0, 0.18);
      --swui-accent: #0a84ff;
      --swui-accent-strong: #007aff;
      --swui-code-bg: #f5f5f7;
      --swui-code-line-hl: rgba(0, 0, 0, 0.04);
      --syntax-keyword: #ad3da4;
      --syntax-type: #0f68a2;
      --syntax-string: #c41a16;
      --syntax-number: #272ad8;
      --syntax-comment: #5d6c79;
    }

    :root[data-theme="dark"] {
      --swui-bg: #000000;
      --swui-surface: #1c1c1e;
      --swui-surface-2: #2c2c2e;
      --swui-fg: #f5f5f7;
      --swui-fg-2: #98989d;
      --swui-fg-3: #6e6e73;
      --swui-border: rgba(255, 255, 255, 0.10);
      --swui-border-strong: rgba(255, 255, 255, 0.22);
      --swui-accent: #5ac8b0;
      --swui-accent-strong: #66e1c1;
      --swui-code-bg: #1d1d1f;
      --swui-code-line-hl: rgba(255, 255, 255, 0.06);
      --syntax-keyword: #fc5fa3;
      --syntax-type: #5dd8ff;
      --syntax-string: #fc6a5d;
      --syntax-number: #d0bf69;
      --syntax-comment: #7f8c98;
    }

    html, body {
      background: var(--swui-bg);
      color: var(--swui-fg);
      font-family: var(--font-text);
      -webkit-font-smoothing: antialiased;
      margin: 0;
      padding: 0;
    }
    """
}
```

- [ ] **Step 3: Run theme tests, confirm pass**

Run: `cd Examples/Showcase && swift test --filter ShowcaseThemeTests`
Expected: PASS (all 5 tests).

- [ ] **Step 4: Run the whole showcase suite**

Run: `make showcase-test`
Expected: PASS (28 tests; nothing else broken).

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift
git commit -m "feat(showcase): Apple Tutorials light+dark token set"
```

### Task 3: Add JS theme bootstrap to `index.html`

**Files:**
- Modify: `Examples/Showcase/index.html`

- [ ] **Step 1: Read existing index.html**

Run: `cat Examples/Showcase/index.html`

- [ ] **Step 2: Insert the bootstrap snippet**

In the `<head>` before WASM loader script, add:

```html
<script>
  // Theme bootstrap: respect saved choice, else fall back to system pref.
  (function () {
    var saved = null;
    try { saved = localStorage.getItem("swui-theme"); } catch (_) {}
    if (saved === "light" || saved === "dark") {
      document.documentElement.setAttribute("data-theme", saved);
    }
  })();
</script>
```

This runs synchronously before paint so there is no FOUC flicker.

- [ ] **Step 3: Manual check**

Open the showcase locally (`make dev` then visit `http://localhost:8080/`); confirm initial paint matches the system theme. No JS error in console.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/index.html
git commit -m "feat(showcase): synchronous theme bootstrap (no FOUC)"
```

---

## Phase 1 — Typed modifiers in SwiftWUIStyles (spec P1)

**Primary:** api-designer + swift-expert · **Review:** architect-reviewer

### Task 4: Add TypographyModifiers tests

**Files:**
- Create: `Tests/SwiftWUIStylesTests/TypographyModifiersTests.swift`
- Reference: `Tests/SwiftWUIStylesTests/StyleModifierTests.swift` for patterns

- [ ] **Step 1: Look at existing test patterns**

Run: `ls Tests/SwiftWUIStylesTests/ && head -60 Tests/SwiftWUIStylesTests/StyleModifierTests.swift`

Note the `TestRenderer.render(tag)` pattern and use of `#expect(html.contains(...))`.

- [ ] **Step 2: Write the failing tests**

Write the file:

```swift
import Testing
import SwiftWUICore
import SwiftWUIStyles
import SwiftWUIRuntime
import SwiftWUIHTML

@Suite("TypographyModifiers")
struct TypographyModifiersTests {
    @Test("fontFamily emits font-family declaration")
    func fontFamily() {
        let html = TestRenderer.render(
            Span { Text("x") }.fontFamily("Helvetica, sans-serif")
        )
        #expect(html.contains("font-family: Helvetica, sans-serif"))
    }

    @Test("textTransform.uppercase")
    func textTransformUppercase() {
        let html = TestRenderer.render(Span { Text("x") }.textTransform(.uppercase))
        #expect(html.contains("text-transform: uppercase"))
    }

    @Test("letterSpacing em")
    func letterSpacingEm() {
        let html = TestRenderer.render(Span { Text("x") }.letterSpacing(.em(0.08)))
        #expect(html.contains("letter-spacing: 0.08em"))
    }

    @Test("lineHeight unitless")
    func lineHeightUnitless() {
        let html = TestRenderer.render(Span { Text("x") }.lineHeight(.unitless(1.5)))
        #expect(html.contains("line-height: 1.5"))
    }

    @Test("lineHeight px")
    func lineHeightPx() {
        let html = TestRenderer.render(Span { Text("x") }.lineHeight(.px(24)))
        #expect(html.contains("line-height: 24px"))
    }

    @Test("whiteSpace nowrap")
    func whiteSpaceNowrap() {
        let html = TestRenderer.render(Span { Text("x") }.whiteSpace(.nowrap))
        #expect(html.contains("white-space: nowrap"))
    }

    @Test("textAlign right")
    func textAlignRight() {
        let html = TestRenderer.render(Div { Text("x") }.textAlign(.right))
        #expect(html.contains("text-align: right"))
    }

    @Test("textDecoration none")
    func textDecorationNone() {
        let html = TestRenderer.render(A(href: "#") { Text("x") }.textDecoration(.none))
        #expect(html.contains("text-decoration: none"))
    }

    @Test("textIndent px")
    func textIndentPx() {
        let html = TestRenderer.render(P { Text("x") }.textIndent(.px(16)))
        #expect(html.contains("text-indent: 16px"))
    }
}
```

- [ ] **Step 3: Run, expect fail**

Run: `swift test --filter TypographyModifiers`
Expected: FAIL — modifiers do not exist.

- [ ] **Step 4: Commit failing tests**

```bash
git add Tests/SwiftWUIStylesTests/TypographyModifiersTests.swift
git commit -m "test(styles): add typography modifier tests (failing)"
```

### Task 5: Implement TypographyModifiers

**Files:**
- Create: `Sources/SwiftWUIStyles/TypographyModifiers.swift`

- [ ] **Step 1: Look at how existing typed modifiers are wired**

Run: `head -80 Sources/SwiftWUIStyles/StyleModifier.swift`

Note: most existing modifiers extend `Tag` via `func name(...) -> some Tag { self.style("css-prop", value.cssString) }`.

- [ ] **Step 2: Write the file**

```swift
// TypographyModifiers.swift — typed wrappers for typography CSS properties.

import SwiftWUICore

// MARK: - Enums

public enum CSSTextTransform: String {
    case none
    case uppercase
    case lowercase
    case capitalize
    case fullWidth = "full-width"
}

public enum CSSWhiteSpace: String {
    case normal
    case nowrap
    case pre
    case preLine = "pre-line"
    case preWrap = "pre-wrap"
}

public enum CSSTextAlign: String {
    case left
    case right
    case center
    case justify
    case start
    case end
}

public enum CSSTextDecoration: String {
    case none
    case underline
    case overline
    case lineThrough = "line-through"
}

public enum CSSLineHeight {
    case unitless(Double)
    case px(Double)
    case em(Double)
    case rem(Double)
    case normal

    var cssString: String {
        switch self {
        case .unitless(let v): return String(format: "%g", v)
        case .px(let v):       return "\(format(v))px"
        case .em(let v):       return "\(format(v))em"
        case .rem(let v):      return "\(format(v))rem"
        case .normal:          return "normal"
        }
    }
    private func format(_ v: Double) -> String { String(format: "%g", v) }
}

public enum CSSLetterSpacing {
    case px(Double)
    case em(Double)
    case rem(Double)
    case normal

    var cssString: String {
        switch self {
        case .px(let v):  return "\(format(v))px"
        case .em(let v):  return "\(format(v))em"
        case .rem(let v): return "\(format(v))rem"
        case .normal:     return "normal"
        }
    }
    private func format(_ v: Double) -> String { String(format: "%g", v) }
}

public enum CSSTextIndent {
    case px(Double)
    case em(Double)
    case percent(Double)

    var cssString: String {
        switch self {
        case .px(let v):      return "\(format(v))px"
        case .em(let v):      return "\(format(v))em"
        case .percent(let v): return "\(format(v))%"
        }
    }
    private func format(_ v: Double) -> String { String(format: "%g", v) }
}

// MARK: - Modifiers

extension Tag {
    public func fontFamily(_ value: String) -> some Tag {
        self.style("font-family", value)
    }

    public func textTransform(_ value: CSSTextTransform) -> some Tag {
        self.style("text-transform", value.rawValue)
    }

    public func whiteSpace(_ value: CSSWhiteSpace) -> some Tag {
        self.style("white-space", value.rawValue)
    }

    public func textAlign(_ value: CSSTextAlign) -> some Tag {
        self.style("text-align", value.rawValue)
    }

    public func textDecoration(_ value: CSSTextDecoration) -> some Tag {
        self.style("text-decoration", value.rawValue)
    }

    public func lineHeight(_ value: CSSLineHeight) -> some Tag {
        self.style("line-height", value.cssString)
    }

    public func letterSpacing(_ value: CSSLetterSpacing) -> some Tag {
        self.style("letter-spacing", value.cssString)
    }

    public func textIndent(_ value: CSSTextIndent) -> some Tag {
        self.style("text-indent", value.cssString)
    }
}
```

- [ ] **Step 3: Run typography tests**

Run: `swift test --filter TypographyModifiers`
Expected: PASS (9 tests).

- [ ] **Step 4: Run the full core suite**

Run: `swift test`
Expected: PASS (51+ tests, with new 9 added).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUIStyles/TypographyModifiers.swift
git commit -m "feat(styles): typography modifiers (fontFamily, textTransform, letterSpacing, lineHeight, …)"
```

### Task 6: Extend StyleModifier with backdropFilter / cursor / boxShadow / borderTop+Right+Bottom+Left

**Files:**
- Modify: `Sources/SwiftWUIStyles/StyleModifier.swift`
- Create: `Tests/SwiftWUIStylesTests/StyleModifierExtensionsTests.swift`

- [ ] **Step 1: Write the failing test file**

```swift
import Testing
import SwiftWUICore
import SwiftWUIStyles
import SwiftWUIRuntime
import SwiftWUIHTML

@Suite("StyleModifier extensions")
struct StyleModifierExtensionsTests {
    @Test("backdropFilter passes through string")
    func backdropFilter() {
        let html = TestRenderer.render(
            Div { EmptyTag() }.backdropFilter("saturate(180%) blur(20px)")
        )
        #expect(html.contains("backdrop-filter: saturate(180%) blur(20px)"))
    }

    @Test("cursor pointer")
    func cursorPointer() {
        let html = TestRenderer.render(Div { EmptyTag() }.cursor(.pointer))
        #expect(html.contains("cursor: pointer"))
    }

    @Test("boxShadow css")
    func boxShadow() {
        let html = TestRenderer.render(
            Div { EmptyTag() }.boxShadow("0 1px 3px rgba(0,0,0,.10)")
        )
        #expect(html.contains("box-shadow: 0 1px 3px rgba(0,0,0,.10)"))
    }

    @Test("borderTop width style color")
    func borderTop() {
        let html = TestRenderer.render(
            Div { EmptyTag() }.borderTop(width: .px(1), style: .solid, color: .css("#000"))
        )
        #expect(html.contains("border-top: 1px solid #000"))
    }

    @Test("borderLeft accent")
    func borderLeft() {
        let html = TestRenderer.render(
            Div { EmptyTag() }.borderLeft(width: .px(3), style: .solid, color: .token("swui-accent"))
        )
        #expect(html.contains("border-left: 3px solid var(--swui-accent)"))
    }
}
```

- [ ] **Step 2: Run, expect fail**

Run: `swift test --filter "StyleModifier extensions"`
Expected: FAIL.

- [ ] **Step 3: Append to StyleModifier.swift**

Open `Sources/SwiftWUIStyles/StyleModifier.swift`. At the bottom, before any trailing brace, add:

```swift
// MARK: - Phase 1 additions (backdrop-filter, cursor, box-shadow, side-specific borders)

public enum CSSCursor: String {
    case auto
    case `default`
    case pointer
    case text
    case wait
    case crosshair
    case help
    case move
    case grab
    case grabbing
    case notAllowed = "not-allowed"
    case zoomIn = "zoom-in"
    case zoomOut = "zoom-out"
}

extension Tag {
    public func backdropFilter(_ value: String) -> some Tag {
        self.style("backdrop-filter", value)
    }

    public func cursor(_ value: CSSCursor) -> some Tag {
        self.style("cursor", value.rawValue)
    }

    public func boxShadow(_ value: String) -> some Tag {
        self.style("box-shadow", value)
    }

    public func borderTop(width: CSSLength, style: CSSBorderStyle, color: CSSColor) -> some Tag {
        self.style("border-top", "\(width.cssString) \(style.rawValue) \(color.cssString)")
    }

    public func borderRight(width: CSSLength, style: CSSBorderStyle, color: CSSColor) -> some Tag {
        self.style("border-right", "\(width.cssString) \(style.rawValue) \(color.cssString)")
    }

    public func borderBottom(width: CSSLength, style: CSSBorderStyle, color: CSSColor) -> some Tag {
        self.style("border-bottom", "\(width.cssString) \(style.rawValue) \(color.cssString)")
    }

    public func borderLeft(width: CSSLength, style: CSSBorderStyle, color: CSSColor) -> some Tag {
        self.style("border-left", "\(width.cssString) \(style.rawValue) \(color.cssString)")
    }
}
```

(Existing names `CSSLength`, `CSSBorderStyle`, `CSSColor` are already declared elsewhere in `Sources/SwiftWUIStyles/`. If a name collision shows in the build, gate the additions with `#if !RAW_BORDER_TOP` or rename minor symbols — but expect no collision because these modifiers are new.)

- [ ] **Step 4: Run the test**

Run: `swift test --filter "StyleModifier extensions"`
Expected: PASS.

- [ ] **Step 5: Run full core suite**

Run: `swift test`
Expected: PASS (60+ tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUIStyles/StyleModifier.swift Tests/SwiftWUIStylesTests/StyleModifierExtensionsTests.swift
git commit -m "feat(styles): backdropFilter, cursor, boxShadow, side-specific borderTop/Right/Bottom/Left"
```

---

## Phase 2 — Playwright harness (spec P6, moved up)

**Why early:** P2 (.style sweep) requires a working `visual.spec.ts` baseline to enforce "0 px diff" acceptance. The smoke + visual specs ship now; nav / scrolly specs come back after their targets exist.

**Primary:** test-automator + frontend-developer · **Review:** qa-expert

### Task 7: Scaffold tests/ directory

**Files:**
- Create: `Examples/Showcase/tests/package.json`
- Create: `Examples/Showcase/tests/tsconfig.json`
- Create: `Examples/Showcase/tests/playwright.config.ts`
- Create: `Examples/Showcase/tests/lib/routes.ts`
- Create: `Examples/Showcase/tests/lib/viewports.ts`
- Create: `Examples/Showcase/tests/lib/themes.ts`
- Create: `Examples/Showcase/tests/lib/helpers.ts`
- Modify: `.gitignore`

- [ ] **Step 1: Append .gitignore entries**

Append to `.gitignore`:

```
# Playwright (Examples/Showcase/tests)
Examples/Showcase/tests/node_modules/
Examples/Showcase/tests/test-results/
Examples/Showcase/tests/playwright-report/
Examples/Showcase/tests/blob-report/
```

- [ ] **Step 2: Write package.json**

```json
{
  "name": "swiftwui-showcase-tests",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "playwright test",
    "test:smoke": "playwright test smoke",
    "test:visual": "playwright test visual",
    "test:update-snapshots": "playwright test --update-snapshots",
    "report": "playwright show-report"
  },
  "devDependencies": {
    "@axe-core/playwright": "^4.10.0",
    "@playwright/test": "^1.49.0",
    "typescript": "^5.6.0"
  }
}
```

- [ ] **Step 3: Write tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "allowImportingTsExtensions": false,
    "noEmit": true,
    "types": ["@playwright/test"]
  },
  "include": ["**/*.ts"]
}
```

- [ ] **Step 4: Write playwright.config.ts**

```ts
import { defineConfig, devices } from "@playwright/test";

const PORT = Number(process.env.SHOWCASE_TEST_PORT ?? 4173);

export default defineConfig({
  testDir: ".",
  fullyParallel: false, // visual.spec must run serially against one dev server
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium-desktop",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 800 } },
    },
    {
      name: "chromium-mobile",
      use: { ...devices["iPhone 14"], browserName: "chromium" },
    },
  ],
  webServer: {
    command: `npm --prefix ../ run dev -- --port ${PORT}`,
    port: PORT,
    reuseExistingServer: !process.env.CI,
    timeout: 90_000,
  },
  snapshotPathTemplate: "{testDir}/__screenshots__/{testFilePath}/{arg}{ext}",
});
```

(`npm --prefix ../` resolves to `Examples/Showcase/`. The Showcase `package.json` already exposes a `dev` script that launches Vite — verify with `head Examples/Showcase/package.json` and adjust the command if the script is named differently.)

- [ ] **Step 5: Write lib/routes.ts**

```ts
export const ROUTES = [
  { path: "/",                  name: "home" },
  { path: "/learn/hello",       name: "hello" },
  { path: "/learn/state",       name: "state" },
  { path: "/learn/modifiers",   name: "modifiers" },
  { path: "/learn/lists",       name: "lists" },
  { path: "/learn/forms",       name: "forms" },
  { path: "/learn/routing",     name: "routing" },
  { path: "/learn/async",       name: "async" },
  { path: "/learn/theming",     name: "theming" },
  { path: "/learn/a11y",        name: "a11y" },
  { path: "/learn/errors",      name: "errors" },
  { path: "/learn/ssr",         name: "ssr" },
  { path: "/learn/pwa",         name: "pwa" },
] as const;

export type Route = (typeof ROUTES)[number];
```

- [ ] **Step 6: Write lib/viewports.ts**

```ts
export const VIEWPORTS = [
  { name: "desktop", width: 1280, height: 800 },
  { name: "mobile",  width: 393,  height: 852 },
] as const;
```

- [ ] **Step 7: Write lib/themes.ts**

```ts
export const THEMES = ["light", "dark"] as const;
export type Theme = (typeof THEMES)[number];
```

- [ ] **Step 8: Write lib/helpers.ts**

```ts
import type { Page } from "@playwright/test";
import type { Theme } from "./themes.js";

export async function setTheme(page: Page, theme: Theme) {
  await page.addInitScript((t) => {
    try { localStorage.setItem("swui-theme", t); } catch (_) {}
    document.documentElement.setAttribute("data-theme", t);
  }, theme);
}

export async function waitForHydration(page: Page) {
  await page.waitForFunction(
    () => document.querySelector("[data-swui-mounted]") !== null,
    null,
    { timeout: 10_000 },
  );
}
```

- [ ] **Step 9: Install deps + verify**

Run:
```bash
cd Examples/Showcase/tests
npm install
npx playwright install --with-deps chromium
```

Expected: install completes; chromium browser binary downloaded.

- [ ] **Step 10: Commit**

```bash
git add .gitignore Examples/Showcase/tests/package.json Examples/Showcase/tests/tsconfig.json \
        Examples/Showcase/tests/playwright.config.ts Examples/Showcase/tests/lib/
git commit -m "test(showcase): scaffold Playwright harness + shared lib"
```

### Task 8: smoke.spec.ts — every route loads, no console errors

**Files:**
- Create: `Examples/Showcase/tests/smoke.spec.ts`

- [ ] **Step 1: Write the test**

```ts
import { test, expect } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { waitForHydration } from "./lib/helpers.js";

for (const route of ROUTES) {
  test(`smoke: ${route.name} (${route.path})`, async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(`console.error: ${msg.text()}`);
    });

    const response = await page.goto(route.path);
    expect(response, `${route.path} returned no response`).not.toBeNull();
    expect(response!.status(), `${route.path} not 200`).toBe(200);

    await waitForHydration(page);
    await expect(page.locator("h1").first()).toBeVisible();

    expect(errors, `Console errors on ${route.path}:\n${errors.join("\n")}`).toEqual([]);
  });
}
```

- [ ] **Step 2: Add `data-swui-mounted` flag to runtime (one-shot)**

The helper `waitForHydration` requires a marker. Modify `Sources/SwiftWUIRuntime/Application.swift`: after mount completes, set `document.documentElement.setAttribute("data-swui-mounted", "true")`. Locate `app.mount()` and append the JS bridge call. Keep the change tiny — single line plus optional comment.

Pattern (place near the end of `mount()`):

```swift
#if canImport(JavaScriptKit)
_ = JSObject.global.document.object?.documentElement.object?.setAttribute?("data-swui-mounted", "true")
#endif
```

- [ ] **Step 3: Run the smoke spec**

Make sure the Showcase dev server can boot (`make showcase-build` first to confirm Swift compiles).

Run:
```bash
cd Examples/Showcase/tests
npx playwright test smoke --project=chromium-desktop
```

Expected: 13 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/tests/smoke.spec.ts Sources/SwiftWUIRuntime/Application.swift
git commit -m "test(showcase): smoke spec — 13 routes load with no console errors"
```

### Task 9: visual.spec.ts — full-page screenshots × viewport × theme (pre-sweep baseline)

**Files:**
- Create: `Examples/Showcase/tests/visual.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { THEMES } from "./lib/themes.js";
import { setTheme, waitForHydration } from "./lib/helpers.js";

for (const theme of THEMES) {
  for (const route of ROUTES) {
    test(`visual: ${route.name} ${theme}`, async ({ page }, testInfo) => {
      await setTheme(page, theme);
      await page.goto(route.path);
      await waitForHydration(page);
      await page.waitForTimeout(150); // settle animations

      await expect(page).toHaveScreenshot(`${route.name}-${theme}.png`, {
        fullPage: true,
        maxDiffPixelRatio: 0.001, // 0.1 %
        animations: "disabled",
      });
    });
  }
}
```

- [ ] **Step 2: Capture pre-sweep baselines (one-time)**

Run:
```bash
cd Examples/Showcase/tests
npx playwright test visual --update-snapshots
```

Expected: 13 × 2 = 26 PNGs written under `__screenshots__/visual.spec.ts/`.

(Both projects — desktop + mobile — when you re-run without filtering. For the pre-sweep baseline, capture both projects → 52 PNGs total.)

```bash
npx playwright test visual --update-snapshots --project=chromium-desktop
npx playwright test visual --update-snapshots --project=chromium-mobile
```

- [ ] **Step 3: Commit baselines**

```bash
git add Examples/Showcase/tests/visual.spec.ts Examples/Showcase/tests/__screenshots__/
git commit -m "test(showcase): visual spec + pre-sweep baselines (52 PNGs)"
```

### Task 10: Wire `make showcase-playwright`

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Read current Makefile around showcase targets**

Run: `grep -n "showcase" Makefile`

- [ ] **Step 2: Append targets**

Append before the final `.PHONY` line (or after the existing `showcase-test` target):

```makefile
.PHONY: showcase-playwright
showcase-playwright:
	cd Examples/Showcase/tests && npm install --silent && npx playwright install --with-deps chromium && npx playwright test

.PHONY: ci-playwright
ci-playwright: ci showcase-playwright
	@echo "Playwright CI green."
```

Update the `help` target's `@echo` lines so `showcase-playwright` and `ci-playwright` appear in the help output.

- [ ] **Step 3: Run `make showcase-playwright` locally**

Run: `make showcase-playwright`
Expected: smoke (13) + visual (26 desktop + 26 mobile) PASS.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "build(make): add showcase-playwright and ci-playwright targets"
```

---

## Phase 3 — `.style()` sweep (spec P2)

**Primary:** refactoring-specialist + swift-expert · **Review:** code-reviewer

The sweep touches 9 component files + HomePage + 12 chapter pages = 22 files. After the sweep, `visual.spec.ts` must show **0 px diff** against the baselines captured in Task 9 — because tokens (Phase 0) already shipped and Phase 3 is pure refactor.

### Task 11: Migrate Hero.swift (worked example, full file shown)

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Components/Hero.swift`

- [ ] **Step 1: Read current Hero.swift**

Run: `cat Examples/Showcase/Sources/Showcase/Components/Hero.swift`

- [ ] **Step 2: Apply migration table mechanically**

For each `.style("css-prop", value)` line, look up the prop in the migration table at the top of this plan and substitute. Custom-prop values (`background: "var(--swui-fg)"`) become `.background(.token("swui-fg"))` where the value is a single CSS variable; otherwise keep `.background(.css(value))`.

After substitution, Hero.swift should have **zero** raw `.style(_, _)` calls (custom-prop assignments excepted). Lines that previously called `.style("font-family", "var(--font-display)")` become `.fontFamily("var(--font-display)")`. Lines that called `.style("color", "var(--swui-accent)")` become `.foregroundColor(.token("swui-accent"))`.

- [ ] **Step 3: Run showcase build**

Run: `make showcase-build`
Expected: PASS.

- [ ] **Step 4: Run native showcase tests**

Run: `make showcase-test`
Expected: PASS (28 tests).

- [ ] **Step 5: Run visual regression**

Run: `cd Examples/Showcase/tests && npx playwright test visual --project=chromium-desktop --grep "home"`
Expected: PASS (home page uses Hero — must visually match baseline).

- [ ] **Step 6: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/Hero.swift
git commit -m "refactor(showcase): Hero.swift .style() → typed modifiers"
```

### Task 12: Sweep remaining components

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Components/ChapterCard.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/ChapterIntro.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/ChapterFooter.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/BadgeGrid.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/SiteChrome.swift` (will be rewritten in Phase 4 — sweep here anyway so visual.spec passes incrementally)
- Modify: `Examples/Showcase/Sources/Showcase/Components/SyntaxHighlight.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/CodeAndPreview.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`

- [ ] **Step 1: Apply migration table to each file in turn**

For each file: open, find every `.style("css-prop", value)` line, swap to the typed equivalent per the migration table. Leave `.style("--swui-foo", token)` lines untouched.

- [ ] **Step 2: Build after each file**

After each file, run: `make showcase-build`
Expected: PASS.

- [ ] **Step 3: Native tests**

After last file, run: `make showcase-test`
Expected: PASS (28).

- [ ] **Step 4: Visual regression**

Run: `cd Examples/Showcase/tests && npx playwright test visual`
Expected: PASS — all 52 baselines unchanged.

- [ ] **Step 5: Commit (one commit covers the component sweep)**

```bash
git add Examples/Showcase/Sources/Showcase/Components/
git commit -m "refactor(showcase): component .style() → typed modifiers"
```

### Task 13: Sweep HomePage and all 12 chapter pages

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Pages/HomePage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/HelloPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/StatePage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/ModifiersPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/ListsPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/FormsPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/RoutingPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/AsyncPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/ThemingPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/A11yPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/ErrorsPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/SSRPage.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/PWAPage.swift`

- [ ] **Step 1: Apply migration table to each file**

Same recipe as Task 12. Inside the `preview: AnyTag(...)` blocks, `.style()` calls also apply — convert them too. **Do not** change the `preview: AnyTag(...)` argument shape yet — that lands in Phase 6 alongside `PreviewKind`.

- [ ] **Step 2: Verify grep target**

Run:
```bash
grep -rn '\.style(' Examples/Showcase/Sources --include='*.swift' \
  | grep -vE '\.style\("--' \
  | wc -l
```
Expected: `0`

- [ ] **Step 3: Build + tests**

```bash
make showcase-build
make showcase-test
```
Expected: PASS.

- [ ] **Step 4: Visual regression (52 baselines)**

Run: `cd Examples/Showcase/tests && npx playwright test visual`
Expected: PASS — zero pixel drift across all routes/themes/viewports.

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Pages/
git commit -m "refactor(showcase): HomePage + 12 chapter pages .style() → typed modifiers"
```

### Task 14: Sync templates + smoke

**Files:**
- Run: `make sync-templates`

- [ ] **Step 1: Sync**

Run: `make sync-templates`

- [ ] **Step 2: Verify drift guard**

Run: `swift run swiftwui-cli doctor` (if available) or rerun showcase tests.
Expected: no drift errors.

- [ ] **Step 3: Commit synced template**

```bash
git add Sources/SwiftWUICLI/Templates/showcase/
git commit -m "chore: sync showcase template after .style() sweep"
```

---

## Phase 4 — Dual-dropdown top bar (spec P3)

**Primary:** swift-expert + frontend-developer · **Review:** architect-reviewer

### Task 15: ChapterRegistry — single source of truth

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/ChapterRegistry.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/ChapterRegistryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Showcase

@Suite("ChapterRegistry")
struct ChapterRegistryTests {
    @Test("Contains 12 chapters grouped in 3 sections")
    func count() {
        #expect(ChapterRegistry.all.count == 12)
        let groups = Set(ChapterRegistry.all.map(\.group))
        #expect(groups == ["Essentials", "Building UI", "Production"])
    }

    @Test("Each chapter has unique id and path")
    func unique() {
        let ids = ChapterRegistry.all.map(\.id)
        let paths = ChapterRegistry.all.map(\.path)
        #expect(Set(ids).count == ids.count)
        #expect(Set(paths).count == paths.count)
    }

    @Test("Path for id resolves both directions")
    func lookup() {
        let hello = ChapterRegistry.chapter(forID: "hello")
        #expect(hello?.path == "/learn/hello")
        let byPath = ChapterRegistry.chapter(forPath: "/learn/state")
        #expect(byPath?.id == "state")
    }
}
```

- [ ] **Step 2: Run, expect fail**

Run: `make showcase-test`
Expected: FAIL.

- [ ] **Step 3: Write ChapterRegistry.swift**

```swift
// ChapterRegistry.swift — canonical chapter metadata. Used by the top-bar
// popovers and the section picker's "N of M" pagination.

import SwiftWUI

public struct ChapterInfo: Identifiable, Hashable {
    public let id: String           // slug: "hello", "state", …
    public let number: Int          // 1...12
    public let title: String        // "Hello, SwiftWUI"
    public let path: String         // "/learn/hello"
    public let group: String        // "Essentials" | "Building UI" | "Production"
}

public enum ChapterRegistry {
    public static let all: [ChapterInfo] = [
        .init(id: "hello",     number: 1,  title: "Hello, SwiftWUI",  path: "/learn/hello",     group: "Essentials"),
        .init(id: "state",     number: 2,  title: "State & Bindings", path: "/learn/state",     group: "Essentials"),
        .init(id: "modifiers", number: 3,  title: "Modifiers",        path: "/learn/modifiers", group: "Essentials"),

        .init(id: "lists",     number: 4,  title: "Lists & ForEach",  path: "/learn/lists",     group: "Building UI"),
        .init(id: "forms",     number: 5,  title: "Forms & Inputs",   path: "/learn/forms",     group: "Building UI"),
        .init(id: "routing",   number: 6,  title: "Routing & Guards", path: "/learn/routing",   group: "Building UI"),
        .init(id: "async",     number: 7,  title: "Async & Resources",path: "/learn/async",     group: "Building UI"),

        .init(id: "theming",   number: 8,  title: "Theming",          path: "/learn/theming",   group: "Production"),
        .init(id: "a11y",      number: 9,  title: "Accessibility",    path: "/learn/a11y",      group: "Production"),
        .init(id: "errors",    number: 10, title: "Error Handling",   path: "/learn/errors",    group: "Production"),
        .init(id: "ssr",       number: 11, title: "SSR & Hydration",  path: "/learn/ssr",       group: "Production"),
        .init(id: "pwa",       number: 12, title: "PWA",              path: "/learn/pwa",       group: "Production"),
    ]

    public static func chapter(forID id: String) -> ChapterInfo? {
        all.first { $0.id == id }
    }

    public static func chapter(forPath path: String) -> ChapterInfo? {
        all.first { $0.path == path }
    }

    public static func grouped() -> [(group: String, chapters: [ChapterInfo])] {
        let order = ["Essentials", "Building UI", "Production"]
        return order.map { g in (g, all.filter { $0.group == g }) }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `make showcase-test`
Expected: PASS (28 + 3 = 31).

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/ChapterRegistry.swift \
        Examples/Showcase/Tests/ShowcaseTests/ChapterRegistryTests.swift
git commit -m "feat(showcase): ChapterRegistry — canonical chapter metadata"
```

### Task 16: ThemeToggle component

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/ThemeToggle.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/ThemeToggleTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
@testable import Showcase
import SwiftWUIRuntime

@Suite("ThemeToggle")
struct ThemeToggleTests {
    @Test("Renders both light and dark icons with aria-pressed")
    func rendersIcons() {
        let html = TestRenderer.render(ThemeToggle())
        #expect(html.contains("aria-label=\"Toggle theme\""))
        #expect(html.contains("data-swui-theme-toggle"))
    }

    @Test("Carries the click handler attribute")
    func clickWired() {
        let html = TestRenderer.render(ThemeToggle())
        #expect(html.contains("onclick") || html.contains("data-swui-event"))
    }
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Implement**

```swift
// ThemeToggle.swift — sun/moon switcher in the top bar.

import SwiftWUI

public struct ThemeToggle: Tag {
    public init() {}

    public var body: some Tag {
        Button(onclick: { ThemeToggle.toggle() }) {
            Span { Text("☼") }.style("--icon", "sun").style("display", "inline")
            Span { Text("☾") }.style("--icon", "moon").style("display", "none")
        }
        .style("data-swui-theme-toggle", "true")            // identifies node for tests
        .aria(label: "Toggle theme")
        .background(.token("swui-surface"))
        .border(width: .px(1), style: .solid, color: .token("swui-border"))
        .borderRadius(.px(6))
        .cursor(.pointer)
        .padding(.px(6), .px(10))
        .fontSize(.px(13))
        .foregroundColor(.token("swui-fg-2"))
    }

    static func toggle() {
        #if canImport(JavaScriptKit)
        let doc = JSObject.global.document.object!
        let root = doc.documentElement.object!
        let current = root.getAttribute?("data-theme").string ?? ""
        let next = current == "dark" ? "light" : "dark"
        _ = root.setAttribute?("data-theme", JSValue.string(next))
        _ = JSObject.global.localStorage.object?.setItem?("swui-theme", JSValue.string(next))
        #endif
    }
}
```

(Add the JavaScriptKit import at file top if not already in scope: `#if canImport(JavaScriptKit) import JavaScriptKit #endif`.)

The Span icons could be replaced with proper Heroicons SVGs in a follow-up; for now glyphs ship clean and accessible.

- [ ] **Step 3: Run tests**

Run: `make showcase-test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/ThemeToggle.swift \
        Examples/Showcase/Tests/ShowcaseTests/ThemeToggleTests.swift
git commit -m "feat(showcase): ThemeToggle component (sun/moon + localStorage)"
```

### Task 17: ChapterPickerPopover

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/ChapterPickerPopover.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/ChapterPickerPopoverTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import Showcase
import SwiftWUIRuntime

@Suite("ChapterPickerPopover")
struct ChapterPickerPopoverTests {
    @Test("Lists 12 chapters grouped in 3 sections")
    func listsAll() {
        let html = TestRenderer.render(ChapterPickerPopover(active: "hello"))
        #expect(html.contains("Essentials"))
        #expect(html.contains("Building UI"))
        #expect(html.contains("Production"))
        for c in ChapterRegistry.all {
            #expect(html.contains(c.title), "missing chapter: \(c.title)")
        }
    }

    @Test("Marks the active chapter")
    func marksActive() {
        let html = TestRenderer.render(ChapterPickerPopover(active: "state"))
        #expect(html.contains("data-active=\"state\""))
    }
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Implement**

```swift
// ChapterPickerPopover.swift — three-column grouped chapter list.

import SwiftWUI

public struct ChapterPickerPopover: Tag {
    public let active: String

    public init(active: String) { self.active = active }

    public var body: some Tag {
        Div {
            ForEach(ChapterRegistry.grouped(), id: \.group) { entry in
                Div {
                    P { Text(entry.group) }
                        .fontSize(.px(11))
                        .fontWeight(.w600)
                        .textTransform(.uppercase)
                        .letterSpacing(.em(0.06))
                        .foregroundColor(.token("swui-fg-3"))
                        .style("margin", "0 0 8px")
                    ForEach(entry.chapters) { chapter in
                        A(href: chapter.path) {
                            Text("\(chapter.number) · \(chapter.title)")
                        }
                        .display(.block)
                        .padding(.px(6), .px(10))
                        .borderRadius(.px(6))
                        .fontSize(.px(13))
                        .foregroundColor(.token(chapter.id == active ? "swui-accent" : "swui-fg-2"))
                        .background(.token(chapter.id == active ? "swui-surface-2" : "transparent"))
                        .textDecoration(.none)
                        .style("data-active", chapter.id == active ? chapter.id : "")
                    }
                }
                .style("min-width", "180px")
            }
        }
        .display(.grid)
        .gridTemplateColumns("repeat(3, 1fr)")
        .gap(.px(24))
        .padding(.px(16))
        .background(.token("swui-surface"))
        .border(width: .px(1), style: .solid, color: .token("swui-border"))
        .borderRadius(.px(10))
        .boxShadow("0 16px 40px rgba(0,0,0,.35)")
        .style("data-swui-popover", "chapter")
    }
}
```

- [ ] **Step 3: Run tests**

Run: `make showcase-test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/ChapterPickerPopover.swift \
        Examples/Showcase/Tests/ShowcaseTests/ChapterPickerPopoverTests.swift
git commit -m "feat(showcase): ChapterPickerPopover (3-group grid)"
```

### Task 18: SectionPickerPopover

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/SectionPickerPopover.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/SectionPickerPopoverTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import Showcase
import SwiftWUIRuntime

@Suite("SectionPickerPopover")
struct SectionPickerPopoverTests {
    @Test("Renders the supplied step titles")
    func renders() {
        let steps = ["Conform a struct to Tag", "Compose with @TagBuilder", "Mount", "Style"]
        let html = TestRenderer.render(
            SectionPickerPopover(chapter: "hello", stepTitles: steps, active: 2)
        )
        for title in steps {
            #expect(html.contains(title))
        }
    }

    @Test("Highlights active step")
    func active() {
        let html = TestRenderer.render(
            SectionPickerPopover(chapter: "hello",
                                 stepTitles: ["a", "b", "c"], active: 2)
        )
        #expect(html.contains("data-active-step=\"2\""))
    }
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Implement**

```swift
// SectionPickerPopover.swift — lists current chapter's scrolly steps.

import SwiftWUI

public struct SectionPickerPopover: Tag {
    public let chapter: String
    public let stepTitles: [String]
    public let active: Int    // 1-indexed

    public init(chapter: String, stepTitles: [String], active: Int) {
        self.chapter = chapter
        self.stepTitles = stepTitles
        self.active = active
    }

    public var body: some Tag {
        Div {
            ForEach(Array(stepTitles.enumerated()), id: \.offset) { idx, title in
                let stepNumber = idx + 1
                Div {
                    Text("\(stepNumber)  \(title)")
                }
                .display(.block)
                .padding(.px(8), .px(12))
                .borderRadius(.px(6))
                .fontSize(.px(13))
                .foregroundColor(.token(stepNumber == active ? "swui-accent" : "swui-fg-2"))
                .background(.token(stepNumber == active ? "swui-surface-2" : "transparent"))
                .cursor(.pointer)
                .style("data-active-step", "\(active)")
                .style("data-step", "\(stepNumber)")
            }
        }
        .display(.flex)
        .flexDirection(.column)
        .gap(.px(2))
        .padding(.px(8))
        .background(.token("swui-surface"))
        .border(width: .px(1), style: .solid, color: .token("swui-border"))
        .borderRadius(.px(10))
        .boxShadow("0 16px 40px rgba(0,0,0,.35)")
        .style("min-width", "240px")
        .style("data-swui-popover", "section")
        .style("data-chapter", chapter)
    }
}
```

- [ ] **Step 3: Run tests**

Run: `make showcase-test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/SectionPickerPopover.swift \
        Examples/Showcase/Tests/ShowcaseTests/SectionPickerPopoverTests.swift
git commit -m "feat(showcase): SectionPickerPopover (step list + active)"
```

### Task 19: TutorialTopBar — composition

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/TutorialTopBar.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/TutorialTopBarTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import Showcase
import SwiftWUIRuntime

@Suite("TutorialTopBar")
struct TutorialTopBarTests {
    @Test("Renders 'Develop in Swift' wordmark with accent on 'Tutorials'")
    func wordmark() {
        let html = TestRenderer.render(
            TutorialTopBar(currentChapter: "hello",
                           stepTitles: ["a", "b"],
                           currentStep: 1)
        )
        #expect(html.contains("Develop in Swift"))
        #expect(html.contains("Tutorials"))
        #expect(html.contains("var(--swui-accent)"))    // accent color used somewhere on the wordmark
    }

    @Test("Shows N of M pagination chip")
    func pagination() {
        let html = TestRenderer.render(
            TutorialTopBar(currentChapter: "hello",
                           stepTitles: ["a", "b", "c", "d"],
                           currentStep: 3)
        )
        #expect(html.contains("3 of 4"))
    }

    @Test("Mounts theme toggle")
    func themeToggle() {
        let html = TestRenderer.render(
            TutorialTopBar(currentChapter: "hello",
                           stepTitles: ["a"],
                           currentStep: 1)
        )
        #expect(html.contains("data-swui-theme-toggle"))
    }
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Implement**

```swift
// TutorialTopBar.swift — dual-dropdown top bar matching Apple Tutorials.

import SwiftWUI

public struct TutorialTopBar: Tag {
    public let currentChapter: String
    public let stepTitles: [String]
    public let currentStep: Int

    public init(currentChapter: String, stepTitles: [String], currentStep: Int) {
        self.currentChapter = currentChapter
        self.stepTitles = stepTitles
        self.currentStep = currentStep
    }

    public var body: some Tag {
        let chapterTitle = ChapterRegistry.chapter(forID: currentChapter)?.title ?? "Welcome"

        return Div {
            // Wordmark
            Div {
                Span { Text("Develop in Swift") }
                    .fontFamily("var(--font-display)")
                    .fontSize(.px(14))
                    .fontWeight(.w600)
                    .foregroundColor(.token("swui-fg"))
                Span { Text(" Tutorials") }
                    .fontFamily("var(--font-display)")
                    .fontSize(.px(14))
                    .fontWeight(.w600)
                    .foregroundColor(.token("swui-accent"))
            }
            .display(.flex)
            .alignItems(.center)

            // Chapter dropdown
            Details {
                Summary {
                    Span { Text(chapterTitle) }
                        .fontSize(.px(13))
                        .foregroundColor(.token("swui-fg"))
                    Span { Text(" ▾") }
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-3"))
                }
                .cursor(.pointer)
                .style("list-style", "none")
                .padding(.px(6), .px(10))
                .borderRadius(.px(6))
                .background(.token("swui-surface"))
                .border(width: .px(1), style: .solid, color: .token("swui-border"))

                ChapterPickerPopover(active: currentChapter)
                    .style("position", "absolute")
                    .style("top", "calc(100% + 4px)")
                    .style("left", "0")
                    .style("z-index", "100")
            }
            .style("position", "relative")

            // Section dropdown + N of M chip
            Details {
                Summary {
                    let active = max(1, min(currentStep, stepTitles.count))
                    let title = stepTitles.indices.contains(active - 1) ? stepTitles[active - 1] : ""
                    Span { Text(title) }
                        .fontSize(.px(13))
                        .foregroundColor(.token("swui-fg"))
                    Span { Text("  \(active) of \(stepTitles.count)") }
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-3"))
                    Span { Text(" ▾") }
                        .fontSize(.px(11))
                        .foregroundColor(.token("swui-fg-3"))
                }
                .cursor(.pointer)
                .style("list-style", "none")
                .padding(.px(6), .px(10))
                .borderRadius(.px(6))
                .background(.token("swui-surface"))
                .border(width: .px(1), style: .solid, color: .token("swui-border"))

                SectionPickerPopover(chapter: currentChapter,
                                     stepTitles: stepTitles,
                                     active: currentStep)
                    .style("position", "absolute")
                    .style("top", "calc(100% + 4px)")
                    .style("left", "0")
                    .style("z-index", "100")
            }
            .style("position", "relative")

            // Spacer + theme toggle on the right
            Div { EmptyTag() }.style("flex", "1")
            ThemeToggle()
        }
        .display(.flex)
        .alignItems(.center)
        .gap(.px(16))
        .padding(.px(8), .px(16))
        .background(.token("swui-bg"))
        .borderBottom(width: .px(1), style: .solid, color: .token("swui-border"))
        .style("position", "sticky")
        .style("top", "0")
        .style("z-index", "50")
        .style("data-swui-topbar", "true")
    }
}
```

(`<details>/<summary>` is the no-JS popover pattern; an enhancement task can later replace it with `AnchorPositioning` for keyboard polish.)

- [ ] **Step 3: Run tests**

Run: `make showcase-test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/TutorialTopBar.swift \
        Examples/Showcase/Tests/ShowcaseTests/TutorialTopBarTests.swift
git commit -m "feat(showcase): TutorialTopBar (wordmark + dual dropdown + theme toggle)"
```

### Task 20: Mount the top bar in SiteChrome

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Components/SiteChrome.swift`

- [ ] **Step 1: Read current SiteChrome**

Run: `cat Examples/Showcase/Sources/Showcase/Components/SiteChrome.swift`

- [ ] **Step 2: Replace the header with TutorialTopBar**

In the SiteChrome body, replace the existing header `Div { … }` with:

```swift
TutorialTopBar(
    currentChapter: SiteChrome.currentChapterID(),
    stepTitles: SiteChrome.stepTitles(),
    currentStep: SiteChrome.currentStep()
)
```

Add three static helpers in `SiteChrome`:

```swift
static func currentChapterID() -> String {
    #if canImport(JavaScriptKit)
    if let path = JSObject.global.window.object?.location.object?.pathname.string,
       let chapter = ChapterRegistry.chapter(forPath: path) {
        return chapter.id
    }
    #endif
    return "home"
}

static func stepTitles() -> [String] {
    // Default: empty array. ScrollyTeller pushes titles into a global registry
    // (see Phase 5) so this helper can read them. For now, return [].
    return ScrollyStepRegistry.titles
}

static func currentStep() -> Int {
    return ScrollyStepRegistry.currentStep
}
```

`ScrollyStepRegistry` is a lightweight observable type added in Phase 5 (Task 23). For now create a placeholder file `Examples/Showcase/Sources/Showcase/Components/ScrollyStepRegistry.swift`:

```swift
// ScrollyStepRegistry.swift — bridges ScrollyTeller's current step
// state to the TutorialTopBar's section picker. Updated by
// ScrollyTeller's mount-side JS in Phase 5.

public enum ScrollyStepRegistry {
    public static var titles: [String] = []
    public static var currentStep: Int = 1
}
```

- [ ] **Step 3: Build**

Run: `make showcase-build`
Expected: PASS.

- [ ] **Step 4: Visual regression — expect drift, update baselines**

The top bar is a visible change. Update the 52 baselines:

```bash
cd Examples/Showcase/tests
npx playwright test visual --update-snapshots
```

Reviewer must inspect the new PNGs before commit — confirm the top bar matches the cited Apple screenshots.

- [ ] **Step 5: Native tests**

Run: `make showcase-test`
Expected: PASS.

- [ ] **Step 6: Commit (paired commits — code + new baselines)**

```bash
git add Examples/Showcase/Sources/Showcase/Components/SiteChrome.swift \
        Examples/Showcase/Sources/Showcase/Components/ScrollyStepRegistry.swift
git commit -m "feat(showcase): mount TutorialTopBar in SiteChrome"

git add Examples/Showcase/tests/__screenshots__/visual.spec.ts/
git commit -m "test(showcase): refresh visual baselines after top-bar mount"
```

### Task 21: nav.spec.ts — top bar interactions

**Files:**
- Create: `Examples/Showcase/tests/nav.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from "@playwright/test";
import { setTheme, waitForHydration } from "./lib/helpers.js";

test("chapter dropdown opens and lists all 12 chapters", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("[data-swui-topbar] details").first().click();
  await expect(page.locator("[data-swui-popover=\"chapter\"]")).toBeVisible();
  // Title list contains "Hello, SwiftWUI"
  await expect(page.locator("[data-swui-popover=\"chapter\"]")).toContainText("Hello, SwiftWUI");
  await expect(page.locator("[data-swui-popover=\"chapter\"]")).toContainText("PWA");
});

test("chapter link navigates", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("[data-swui-topbar] details").first().click();
  await page.getByRole("link", { name: /State & Bindings/ }).click();
  await expect(page).toHaveURL(/\/learn\/state/);
});

test("theme toggle flips data-theme and persists across reload", async ({ page }) => {
  await setTheme(page, "light");
  await page.goto("/learn/hello");
  await waitForHydration(page);

  await page.locator("[data-swui-theme-toggle]").click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");

  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
});

test("browser back/forward stays in sync with SPA router", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("[data-swui-topbar] details").first().click();
  await page.getByRole("link", { name: /Modifiers/ }).click();
  await expect(page).toHaveURL(/\/learn\/modifiers/);
  await page.goBack();
  await expect(page).toHaveURL(/\/learn\/hello/);
});
```

- [ ] **Step 2: Run**

Run: `cd Examples/Showcase/tests && npx playwright test nav --project=chromium-desktop`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Examples/Showcase/tests/nav.spec.ts
git commit -m "test(showcase): nav.spec — top-bar dropdown + theme toggle + SPA history"
```

---

## Phase 5 — ScrollyTeller v2 (spec P4)

**Primary:** swift-expert + frontend-developer · **Review:** architect-reviewer

### Task 22: Extend Step shape (highlightLines)

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`

This is the same commit that introduces `PreviewKind` (next phase) — but to keep Phase 5 isolated, we keep `preview: AnyTag` here and switch to `PreviewKind` in Phase 6.

- [ ] **Step 1: Read current ScrollyTeller.Step**

Run: `grep -n "struct Step" Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`

- [ ] **Step 2: Extend the Step struct**

In `ScrollyTeller.swift`, change the `Step` struct to add `highlightLines`:

```swift
public struct Step: Identifiable {
    public let number: Int
    public let title: String
    public let prose: String
    public let code: String
    public let highlightLines: [Int]   // NEW — 1-indexed line numbers to highlight when this step is active
    public let preview: AnyTag
    public var id: Int { number }

    public init(number: Int,
                title: String,
                prose: String,
                code: String,
                highlightLines: [Int] = [],
                preview: AnyTag) {
        self.number = number
        self.title = title
        self.prose = prose
        self.code = code
        self.highlightLines = highlightLines
        self.preview = preview
    }
}
```

Default value `= []` means existing call sites compile without edits.

- [ ] **Step 3: Build**

Run: `make showcase-build` → PASS (all 12 chapter pages compile because `highlightLines` has a default).

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift
git commit -m "feat(showcase): Step.highlightLines field (default empty)"
```

### Task 23: Line-numbered code panel with highlight rendering

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Components/SyntaxHighlight.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`

- [ ] **Step 1: Failing test in ScrollyTellerTests**

Append to `Examples/Showcase/Tests/ShowcaseTests/ScrollyTellerTests.swift`:

```swift
@Test("Code panel emits data-line attributes per source line")
func dataLineAttrs() {
    let step = ScrollyTeller.Step(
        number: 1, title: "t", prose: "p",
        code: "let x = 1\nlet y = 2", highlightLines: [2],
        preview: AnyTag(Text("ok"))
    )
    let html = TestRenderer.render(ScrollyTeller(steps: [step]))
    #expect(html.contains("data-line=\"1\""))
    #expect(html.contains("data-line=\"2\""))
}

@Test("Highlight lines apply --swui-code-line-hl background")
func highlightApplied() {
    let step = ScrollyTeller.Step(
        number: 1, title: "t", prose: "p",
        code: "a\nb\nc", highlightLines: [2],
        preview: AnyTag(Text("ok"))
    )
    let html = TestRenderer.render(ScrollyTeller(steps: [step]))
    #expect(html.contains("data-line-hl=\"2\""))
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Rework SyntaxHighlight.swift**

Replace the `SyntaxHighlight` body so it emits a `<table>` (or stacked `<div>`s with `display: table`) with a left column of line numbers and a right column of code. Each row carries `data-line="\(idx)"`.

For each line in the source, render:

```html
<div class="swui-code-line" data-line="N" style="display: grid; grid-template-columns: 36px 1fr;">
  <span style="color: var(--swui-fg-3); text-align: right; padding-right: 12px;">N</span>
  <code style="white-space: pre;">…source line…</code>
</div>
```

Use existing token tinting (`--syntax-keyword`, `--syntax-type`, etc.) for spans inside the code column. Keep the existing regex-based highlighter — only the wrapping changes.

- [ ] **Step 3: Update ScrollyTeller to pass highlightLines into the panel**

In ScrollyTeller's body where the code panel is rendered, wrap each `Step.code` in a container with `data-line-hl="\(line)"` markers (one attribute per highlighted line, or a comma-joined `data-line-hl="2,4"` shape) so CSS can target them:

```css
.swui-code-line[data-line-hl] { background: var(--swui-code-line-hl); }
```

Add this CSS to `ShowcaseTheme.css` (Task 2 file).

- [ ] **Step 4: Run tests**

Run: `make showcase-test` → PASS.

- [ ] **Step 5: Visual regression — expect drift, update**

Run: `cd Examples/Showcase/tests && npx playwright test visual --update-snapshots`
Reviewer inspects PNGs.

- [ ] **Step 6: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/SyntaxHighlight.swift \
        Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift \
        Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift \
        Examples/Showcase/Tests/ShowcaseTests/ScrollyTellerTests.swift
git commit -m "feat(showcase): line-numbered code panel + per-step line highlight"

git add Examples/Showcase/tests/__screenshots__/visual.spec.ts/
git commit -m "test(showcase): refresh visual baselines after code-panel rework"
```

### Task 24: StepNavButtons

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/StepNavButtons.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/StepNavButtonsTests.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import Showcase
import SwiftWUIRuntime

@Suite("StepNavButtons")
struct StepNavButtonsTests {
    @Test("Renders two buttons with prev/next labels")
    func renders() {
        let html = TestRenderer.render(StepNavButtons(total: 4, current: 2))
        #expect(html.contains("← Prev step") || html.contains("&larr; Prev step"))
        #expect(html.contains("Next step →") || html.contains("Next step &rarr;"))
    }

    @Test("Shows current/total chip")
    func chip() {
        let html = TestRenderer.render(StepNavButtons(total: 5, current: 3))
        #expect(html.contains("Step 3 / 5"))
    }
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Implement**

```swift
// StepNavButtons.swift — prev/next + N/M chip embedded in the code panel.

import SwiftWUI

public struct StepNavButtons: Tag {
    public let total: Int
    public let current: Int

    public init(total: Int, current: Int) {
        self.total = total
        self.current = current
    }

    public var body: some Tag {
        Div {
            Button(onclick: { StepNavButtons.go(delta: -1) }) {
                Text("← Prev step")
            }
            .padding(.px(6), .px(12))
            .background(.token("swui-surface"))
            .border(width: .px(1), style: .solid, color: .token("swui-border"))
            .borderRadius(.px(6))
            .fontSize(.px(12))
            .foregroundColor(.token(current > 1 ? "swui-fg" : "swui-fg-3"))
            .cursor(.pointer)

            Div { EmptyTag() }.style("flex", "1")

            Span { Text("Step \(current) / \(total)") }
                .fontSize(.px(12))
                .foregroundColor(.token("swui-fg-3"))

            Div { EmptyTag() }.style("flex", "1")

            Button(onclick: { StepNavButtons.go(delta: 1) }) {
                Text("Next step →")
            }
            .padding(.px(6), .px(12))
            .background(.token("swui-accent"))
            .borderRadius(.px(6))
            .fontSize(.px(12))
            .fontWeight(.w600)
            .foregroundColor(.token("swui-bg"))
            .cursor(.pointer)
        }
        .display(.flex)
        .alignItems(.center)
        .gap(.px(8))
        .padding(.px(8), .px(12))
        .background(.token("swui-surface"))
        .borderBottom(width: .px(1), style: .solid, color: .token("swui-border"))
        .style("data-step-nav", "\(current)/\(total)")
    }

    static func go(delta: Int) {
        #if canImport(JavaScriptKit)
        // Implementation: scroll to next step's anchor. ScrollyTeller mounts
        // a `data-step="N"` attribute on each step card. We resolve current
        // step from ScrollyStepRegistry.currentStep + delta then scroll into view.
        let next = ScrollyStepRegistry.currentStep + delta
        let id = "swui-step-\(next)"
        if let el = JSObject.global.document.object?.getElementById?(id).object {
            _ = el.scrollIntoView?(JSValue.boolean(true))
        }
        #endif
    }
}
```

- [ ] **Step 3: Mount inside ScrollyTeller's code panel**

In ScrollyTeller's body, prepend `StepNavButtons(total: steps.count, current: ScrollyStepRegistry.currentStep)` to the right-column code panel container.

- [ ] **Step 4: Run tests + visual**

```bash
make showcase-test
cd Examples/Showcase/tests && npx playwright test visual --update-snapshots
```

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/StepNavButtons.swift \
        Examples/Showcase/Tests/ShowcaseTests/StepNavButtonsTests.swift \
        Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift
git commit -m "feat(showcase): StepNavButtons (prev/next + step chip) in code panel"

git add Examples/Showcase/tests/__screenshots__/visual.spec.ts/
git commit -m "test(showcase): refresh visual baselines after StepNav"
```

### Task 25: Active-step vertical bar + preview crossfade

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`

- [ ] **Step 1: Add active-step bar to step prose card**

For each step card, render the existing prose container with:

```swift
.borderLeft(width: .px(3), style: .solid, color: .token("swui-accent"))
.style("opacity", "0.5")   // inactive default; CSS rule below flips to 1 for active
```

Add CSS to `ShowcaseTheme.css`:

```css
.swui-step-card { border-left-color: transparent !important; opacity: 1; transition: border-left-color .2s ease; }
.swui-step-card[data-active="true"] { border-left-color: var(--swui-accent) !important; }

.swui-preview-pane { transition: opacity .2s ease; }
.swui-preview-pane[data-preview-fading="true"] { opacity: 0; }
```

Apply `.style("data-active", isActive ? "true" : "false")` on each `swui-step-card` based on IntersectionObserver's emission.

- [ ] **Step 2: Crossfade on preview swap**

In the mount-side script (search for ScrollyTeller's existing IntersectionObserver in `Application.swift` or wherever it lives), when `currentStep` changes:

```js
const pane = document.querySelector("[data-swui-preview-pane]");
pane.setAttribute("data-preview-fading", "true");
setTimeout(() => {
  // swap preview content (existing behavior)
  pane.removeAttribute("data-preview-fading");
}, 200);
```

If the observer code lives in Swift via `JSClosure`, port the same logic.

- [ ] **Step 3: Run native tests**

Run: `make showcase-test` → PASS.

- [ ] **Step 4: Visual baseline refresh**

```bash
cd Examples/Showcase/tests && npx playwright test visual --update-snapshots
```

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift \
        Examples/Showcase/Sources/Showcase/Theme/ShowcaseTheme.swift
git commit -m "feat(showcase): active-step vertical bar + preview crossfade"

git add Examples/Showcase/tests/__screenshots__/visual.spec.ts/
git commit -m "test(showcase): refresh visual baselines (active-step bar + crossfade)"
```

### Task 26: scrolly.spec.ts — interaction coverage

**Files:**
- Create: `Examples/Showcase/tests/scrolly.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from "@playwright/test";
import { waitForHydration } from "./lib/helpers.js";

test("scrolling advances current step", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);

  // Step 1 active by default.
  await expect(page.locator("[data-swui-step-card][data-active=\"true\"]")).toContainText(/Conform a struct/i);

  // Scroll into step 2.
  await page.locator("[data-swui-step-card]").nth(1).scrollIntoViewIfNeeded();
  await page.waitForTimeout(300);

  await expect(page.locator("[data-swui-step-card][data-active=\"true\"]")).toContainText(/Compose with @TagBuilder/i);
});

test("highlight lines match active step's highlightLines", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);

  const highlighted = await page.locator("[data-line-hl]").count();
  expect(highlighted).toBeGreaterThan(0);
});

test("StepNav next button advances current step", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("button", { hasText: /Next step/ }).click();
  await page.waitForTimeout(300);
  await expect(page.locator("[data-step-nav]")).toContainText("2 /");
});
```

- [ ] **Step 2: Add `data-swui-step-card` attributes**

In `ScrollyTeller.swift`, on the step prose card root: `.style("data-swui-step-card", "true")`. Also add `.style("id", "swui-step-\(step.number)")` to support `scrollIntoView` from StepNavButtons.

- [ ] **Step 3: Run**

```bash
cd Examples/Showcase/tests && npx playwright test scrolly --project=chromium-desktop
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/tests/scrolly.spec.ts \
        Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift
git commit -m "test(showcase): scrolly.spec — step advance + line highlight + nav buttons"
```

### Task 27: Populate `highlightLines` for every step in every chapter

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/HelloPage.swift` (+ 11 more chapter files)

- [ ] **Step 1: For each chapter, fill the field**

The author reads each chapter's existing `code: """ … """` body and decides which line numbers correspond to that step's narrative pivot. Default to "the lines the prose talks about." If unsure, set `highlightLines: []` and leave to a follow-up — the code panel will simply not highlight.

A worked example for HelloPage step 1:

```swift
.init(
    number: 1,
    title: "Conform a struct to Tag",
    prose: "…",
    code: """
        struct Greeting: Tag {
          var body: some Tag {
            H1 { Text("Hello, SwiftWUI") }
          }
        }
        """,
    highlightLines: [1, 5],   // struct declaration + closing brace
    preview: AnyTag(...)
)
```

- [ ] **Step 2: Build + test**

```bash
make showcase-build
make showcase-test
```
Expected: PASS.

- [ ] **Step 3: Visual baseline refresh**

```bash
cd Examples/Showcase/tests && npx playwright test visual --update-snapshots
```

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Pages/Chapters/
git commit -m "feat(showcase): populate highlightLines for all chapters"

git add Examples/Showcase/tests/__screenshots__/visual.spec.ts/
git commit -m "test(showcase): refresh baselines after highlightLines population"
```

---

## Phase 6 — PreviewFrame + PreviewKind (spec P5)

**Primary:** swift-expert + api-designer · **Review:** code-reviewer

### Task 28: PreviewKind enum + tests

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/PreviewKind.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/PreviewKindTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
@testable import Showcase

@Suite("PreviewKind")
struct PreviewKindTests {
    @Test("Live kind preserves an AnyTag")
    func live() {
        let kind = PreviewKind.live(AnyTag(Text("x")))
        switch kind {
        case .live(let tag):
            #expect(TestRenderer.render(tag).contains("x"))
        case .screenshot:
            Issue.record("expected .live")
        }
    }

    @Test("Screenshot kind preserves the path")
    func screenshot() {
        let kind = PreviewKind.screenshot("hello-step-1.png")
        switch kind {
        case .screenshot(let path):
            #expect(path == "hello-step-1.png")
        case .live:
            Issue.record("expected .screenshot")
        }
    }
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Write the enum**

```swift
// PreviewKind.swift — how a ScrollyTeller step's preview pane is filled.

import SwiftWUI

public enum PreviewKind {
    case live(AnyTag)
    case screenshot(String)    // path relative to Resources/snapshots/
}
```

- [ ] **Step 3: Run**

Run: `make showcase-test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/PreviewKind.swift \
        Examples/Showcase/Tests/ShowcaseTests/PreviewKindTests.swift
git commit -m "feat(showcase): PreviewKind enum (.live | .screenshot)"
```

### Task 29: PreviewFrame component

**Files:**
- Create: `Examples/Showcase/Sources/Showcase/Components/PreviewFrame.swift`
- Create: `Examples/Showcase/Tests/ShowcaseTests/PreviewFrameTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
@testable import Showcase
import SwiftWUIRuntime

@Suite("PreviewFrame")
struct PreviewFrameTests {
    @Test("Renders three traffic-light dots and address bar")
    func chromeRendered() {
        let html = TestRenderer.render(
            PreviewFrame(kind: .live(AnyTag(Text("ok"))), label: "localhost:8080")
        )
        #expect(html.contains("#ff5f57"))   // red dot
        #expect(html.contains("#ffbd2e"))   // yellow dot
        #expect(html.contains("#28c840"))   // green dot
        #expect(html.contains("localhost:8080"))
    }

    @Test("Live preview body renders the supplied tag")
    func liveTag() {
        let html = TestRenderer.render(
            PreviewFrame(kind: .live(AnyTag(Text("INNER"))), label: "")
        )
        #expect(html.contains("INNER"))
    }

    @Test("Screenshot preview emits img with snapshots path")
    func screenshot() {
        let html = TestRenderer.render(
            PreviewFrame(kind: .screenshot("hello-step-2.png"), label: "")
        )
        #expect(html.contains("src=\"/snapshots/hello-step-2.png\""))
        #expect(html.contains("alt="))
    }
}
```

Run: `make showcase-test` → FAIL.

- [ ] **Step 2: Implement**

```swift
// PreviewFrame.swift — browser-window chrome wrapping a step's preview content.

import SwiftWUI

public struct PreviewFrame: Tag {
    public let kind: PreviewKind
    public let label: String

    public init(kind: PreviewKind, label: String = "localhost:8080") {
        self.kind = kind
        self.label = label
    }

    public var body: some Tag {
        Div {
            // Window chrome
            Div {
                Div { EmptyTag() }
                    .background(.css("#ff5f57"))
                    .style("width", "12px").style("height", "12px")
                    .borderRadius(.token("radius-pill"))
                Div { EmptyTag() }
                    .background(.css("#ffbd2e"))
                    .style("width", "12px").style("height", "12px")
                    .borderRadius(.token("radius-pill"))
                Div { EmptyTag() }
                    .background(.css("#28c840"))
                    .style("width", "12px").style("height", "12px")
                    .borderRadius(.token("radius-pill"))
                Div { EmptyTag() }.style("flex", "1")
                Span { Text(label) }
                    .fontFamily("var(--font-mono)")
                    .fontSize(.px(11))
                    .foregroundColor(.token("swui-fg-3"))
                Div { EmptyTag() }.style("flex", "1")
            }
            .display(.flex)
            .alignItems(.center)
            .gap(.px(6))
            .padding(.px(8), .px(12))
            .background(.token("swui-surface"))
            .borderBottom(width: .px(1), style: .solid, color: .token("swui-border"))

            // Body
            Div {
                switch kind {
                case .live(let tag):
                    tag
                case .screenshot(let path):
                    Img(src: "/snapshots/\(path)", alt: "Preview screenshot")
                        .style("max-width", "100%")
                        .style("display", "block")
                }
            }
            .padding(.px(20))
        }
        .background(.token("swui-bg"))
        .border(width: .px(1), style: .solid, color: .token("swui-border"))
        .borderRadius(.px(10))
        .style("overflow", "hidden")
        .style("data-swui-preview-pane", "true")
    }
}
```

- [ ] **Step 3: Run tests**

Run: `make showcase-test` → PASS.

- [ ] **Step 4: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/PreviewFrame.swift \
        Examples/Showcase/Tests/ShowcaseTests/PreviewFrameTests.swift
git commit -m "feat(showcase): PreviewFrame (browser-window chrome + PreviewKind dispatch)"
```

### Task 30: Switch Step.preview type to PreviewKind

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift`
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/*.swift` (12 files)

- [ ] **Step 1: Change Step.preview type**

In `ScrollyTeller.swift`:

```swift
public let preview: PreviewKind   // was: AnyTag

public init(number: Int, title: String, prose: String, code: String,
            highlightLines: [Int] = [], preview: PreviewKind) {
    …
    self.preview = preview
    …
}
```

In ScrollyTeller's body where it renders the preview, wrap with `PreviewFrame(kind: step.preview)`.

- [ ] **Step 2: Update every chapter call site**

For each `Pages/Chapters/*.swift`, change `preview: AnyTag(…)` → `preview: .live(AnyTag(…))`.

(`.live` is the only kind needed now. Phase 6's Task 31 introduces the first `.screenshot` swap.)

- [ ] **Step 3: Build + test**

```bash
make showcase-build
make showcase-test
```
Expected: PASS.

- [ ] **Step 4: Visual baseline refresh**

```bash
cd Examples/Showcase/tests && npx playwright test visual --update-snapshots
```

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/Components/ScrollyTeller.swift \
        Examples/Showcase/Sources/Showcase/Pages/Chapters/
git commit -m "feat(showcase): Step.preview is PreviewKind (.live for every step)"

git add Examples/Showcase/tests/__screenshots__/visual.spec.ts/
git commit -m "test(showcase): refresh baselines for browser-window preview chrome"
```

### Task 31: `make showcase-snapshots` target

**Files:**
- Create: `Examples/Showcase/tests/snapshot-generator.spec.ts`
- Modify: `Makefile`
- Create: `Examples/Showcase/Resources/snapshots/.gitkeep`

- [ ] **Step 1: Write the generator spec**

```ts
import { test } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { waitForHydration } from "./lib/helpers.js";
import { promises as fs } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "..", "Resources", "snapshots");

test.describe("@generate-snapshots", () => {
  for (const route of ROUTES) {
    test(`generate ${route.name} previews`, async ({ page }) => {
      await page.goto(route.path);
      await waitForHydration(page);
      await fs.mkdir(OUT_DIR, { recursive: true });

      const panes = await page.locator("[data-swui-preview-pane]").all();
      for (let i = 0; i < panes.length; i++) {
        const png = await panes[i].screenshot();
        const file = join(OUT_DIR, `${route.name}-step-${i + 1}.png`);
        await fs.writeFile(file, png);
      }
    });
  }
});
```

Only runs when invoked by tag — does **not** run as part of `npx playwright test` by default.

- [ ] **Step 2: Add the Makefile target**

Append:

```makefile
.PHONY: showcase-snapshots
showcase-snapshots:
	cd Examples/Showcase/tests && npx playwright test --grep "@generate-snapshots"
```

Update `help` listing.

- [ ] **Step 3: Run once**

Run: `make showcase-snapshots`
Expected: PNGs land under `Examples/Showcase/Resources/snapshots/`.

- [ ] **Step 4: Stop committing — these PNGs are pre-rendered assets**

Add to `.gitignore` (or commit selectively):

```
# Generated previews — committed only when a chapter opts into .screenshot
Examples/Showcase/Resources/snapshots/*.png
!Examples/Showcase/Resources/snapshots/.gitkeep
```

The author commits an individual PNG only when they convert a `.live` step to `.screenshot`.

- [ ] **Step 5: Commit**

```bash
git add Examples/Showcase/tests/snapshot-generator.spec.ts Makefile \
        Examples/Showcase/Resources/snapshots/.gitkeep .gitignore
git commit -m "build: showcase-snapshots target (Playwright-driven PNG generator)"
```

### Task 32: Demo — convert one HelloPage step to `.screenshot`

**Files:**
- Modify: `Examples/Showcase/Sources/Showcase/Pages/Chapters/HelloPage.swift`
- Add: `Examples/Showcase/Resources/snapshots/hello-step-N.png` (specific PNG file)

- [ ] **Step 1: Pick a step**

HelloPage step 3 ("Mount on a DOM element") has the most static preview ("Mounted! Open the browser console…"). Convert it.

- [ ] **Step 2: Generate the PNG**

Run: `make showcase-snapshots`

Identify the file produced under `Resources/snapshots/hello-step-3.png`.

- [ ] **Step 3: Swap the chapter source**

In HelloPage.swift, change step 3:

```swift
preview: .live(AnyTag(...))
```

to

```swift
preview: .screenshot("hello-step-3.png")
```

- [ ] **Step 4: Build + visual**

```bash
make showcase-build
make showcase-test
cd Examples/Showcase/tests && npx playwright test visual --update-snapshots
```

- [ ] **Step 5: Commit (PNG + chapter together)**

```bash
git add -f Examples/Showcase/Resources/snapshots/hello-step-3.png \
        Examples/Showcase/Sources/Showcase/Pages/Chapters/HelloPage.swift
git commit -m "feat(showcase): demo .screenshot preview kind for Hello chapter step 3"

git add Examples/Showcase/tests/__screenshots__/visual.spec.ts/
git commit -m "test(showcase): refresh baselines after .screenshot conversion"
```

---

## Phase 7 — Accessibility + per-preview snapshot specs

**Primary:** accessibility-tester + test-automator · **Review:** qa-expert

### Task 33: a11y.spec.ts

**Files:**
- Create: `Examples/Showcase/tests/a11y.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { ROUTES } from "./lib/routes.js";
import { THEMES } from "./lib/themes.js";
import { setTheme, waitForHydration } from "./lib/helpers.js";

for (const theme of THEMES) {
  for (const route of ROUTES) {
    test(`a11y: ${route.name} ${theme}`, async ({ page }) => {
      await setTheme(page, theme);
      await page.goto(route.path);
      await waitForHydration(page);

      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
        .analyze();

      expect(results.violations, JSON.stringify(results.violations, null, 2)).toEqual([]);
    });
  }
}
```

- [ ] **Step 2: Run, fix any genuine issues**

Run: `cd Examples/Showcase/tests && npx playwright test a11y`

Likely findings to fix at chapter source:
- Missing `alt` on screenshot images (PreviewFrame already supplies; verify).
- Insufficient color contrast in light-mode `--swui-fg-2` against `--swui-bg` — adjust token if axe flags.
- Missing `aria-label` on theme toggle button — already wired in Task 16.
- Missing `lang` on `<html>` — add to `Examples/Showcase/index.html` head.

Iterate until 0 violations across all 26 (route × theme) combinations.

- [ ] **Step 3: Commit spec + any chapter/token fixes**

```bash
git add Examples/Showcase/tests/a11y.spec.ts Examples/Showcase/index.html \
        Examples/Showcase/Sources/Showcase/
git commit -m "test(showcase): a11y.spec — 0 WCAG 2.1 AA violations across 26 route×theme combos"
```

### Task 34: preview.spec.ts — per-preview snapshot diff

**Files:**
- Create: `Examples/Showcase/tests/preview.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { waitForHydration } from "./lib/helpers.js";

for (const route of ROUTES) {
  test(`preview: ${route.name}`, async ({ page }) => {
    await page.goto(route.path);
    await waitForHydration(page);

    const panes = page.locator("[data-swui-preview-pane]");
    const count = await panes.count();
    test.skip(count === 0, `${route.name} has no preview panes`);

    for (let i = 0; i < count; i++) {
      await expect(panes.nth(i)).toHaveScreenshot(`${route.name}-step-${i + 1}.png`, {
        maxDiffPixelRatio: 0.001,
        animations: "disabled",
      });
    }
  });
}
```

- [ ] **Step 2: Capture per-preview baselines**

Run: `cd Examples/Showcase/tests && npx playwright test preview --update-snapshots`

- [ ] **Step 3: Commit baselines**

```bash
git add Examples/Showcase/tests/preview.spec.ts \
        Examples/Showcase/tests/__screenshots__/preview.spec.ts/
git commit -m "test(showcase): preview.spec — per-preview snapshot baselines"
```

---

## Phase 8 — CI wiring + final sync (spec P7 + P8)

**Primary:** code-reviewer + test-automator · **Review:** architect-reviewer + qa-expert

### Task 35: Update CI workflow

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read current workflow**

Run: `cat .github/workflows/ci.yml`

- [ ] **Step 2: Append a Playwright job**

After the existing showcase-test job, append:

```yaml
  showcase-playwright:
    runs-on: ubuntu-22.04
    needs: showcase-test
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
        with: { swift-version: "6.0" }
      - uses: actions/setup-node@v4
        with: { node-version: "20" }
      - name: Install Playwright deps
        run: |
          cd Examples/Showcase/tests
          npm ci
          npx playwright install --with-deps chromium
      - name: Run Playwright
        run: cd Examples/Showcase/tests && npx playwright test
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: Examples/Showcase/tests/playwright-report/
```

- [ ] **Step 3: Push branch + watch CI**

After local `make ci-playwright` is green, push and confirm GitHub Actions reports green.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run Playwright suite (smoke + nav + scrolly + a11y + visual + preview)"
```

### Task 36: Commit the SPA navigation glue currently uncommitted

**Files:**
- `Examples/Showcase/Sources/Showcase/main.swift` (already modified on disk)

- [ ] **Step 1: Review the diff**

Run: `git diff Examples/Showcase/Sources/Showcase/main.swift`

Confirm it implements link-click interception + popstate sync. Mention `<system>` constraints in the body: no JS bundler glue beyond what's already shipping.

- [ ] **Step 2: Commit**

```bash
git add Examples/Showcase/Sources/Showcase/main.swift
git commit -m "feat(showcase): SPA link interception + popstate router sync"
```

### Task 37: Final `make sync-templates` + verify drift guard

**Files:**
- Modify: `Sources/SwiftWUICLI/Templates/showcase/` (auto-regenerated)

- [ ] **Step 1: Sync**

Run: `make sync-templates`

- [ ] **Step 2: Verify**

Run: `git status -s` — expect changes only under `Sources/SwiftWUICLI/Templates/showcase/`.

Run: `make ci` — expect the existing template-drift check inside CI to pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/SwiftWUICLI/Templates/showcase/
git commit -m "chore: sync showcase template (Apple Tutorials fidelity pass)"
```

### Task 38: Open PR

- [ ] **Step 1: Push branch**

```bash
git push -u origin feat/showcase-template
```

- [ ] **Step 2: Open PR**

```bash
gh pr create --title "feat(showcase): Apple Tutorials fidelity pass" --body "$(cat <<'EOF'
## Summary
- Pixel-faithful parity with developer.apple.com/tutorials/develop-in-swift (dark+light, dual-dropdown top bar, mint-teal accent).
- ScrollyTeller v2 — scroll-synced line highlighting, StepNavButtons, active-step bar, preview crossfade.
- Hybrid preview rendering — `PreviewKind.live(AnyTag)` and `PreviewKind.screenshot(path)`.
- `.style()` → typed modifier sweep (693 calls → 0 non-custom-prop).
- Playwright suite — smoke + nav + scrolly + a11y + visual (52 baselines) + preview (per-pane).

## Test plan
- [x] `make ci` green
- [x] `make ci-playwright` green
- [x] Manual: theme toggle persists across reload on every chapter
- [x] Manual: chapter dropdown navigates; section dropdown reflects scroll
- [x] Spec: `docs/superpowers/specs/2026-05-14-showcase-apple-tutorials-fidelity-design.md`
- [x] Plan: `docs/superpowers/plans/2026-05-14-showcase-apple-tutorials-fidelity.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Hand off URL to author for review**

---

## Self-review checklist (run before declaring done)

1. **Spec coverage**: every section of the spec maps to a task.
   - §4.2 tokens → Task 1+2.
   - §4.3 top bar → Tasks 17+18+19+20.
   - §4.4 ScrollyTeller v2 → Tasks 22-27.
   - §4.5 PreviewFrame → Task 29.
   - §4.6 snapshot generation → Tasks 31+32.
   - §4.7 `.style()` migration → Tasks 11-13.
   - §4.8 Playwright suite → Tasks 7-10, 21, 26, 33, 34.
   - §4.9 component diagram → emerges from Tasks 15-25.
   - §5 implementation phases → Phases 0-8 of this plan (Playwright moved earlier for baseline gating, documented in front-matter).
   - §6 risks → addressed by phase ordering (baseline captured before sweep) + token coexistence + `--update-snapshots` discipline.

2. **No placeholders**. Confirmed — every step has code or a precise command.

3. **Type consistency**. `Step.highlightLines` vs `Step.preview: PreviewKind` — both declared in Task 22/30. `PreviewKind` consumers are `PreviewFrame` (Task 29) and ScrollyTeller body (Task 30). `ChapterRegistry.chapter(forID:)` / `chapter(forPath:)` used in Task 20. All names line up.

4. **Per-phase commit discipline**. Each task ends with a single `git commit`. Tasks that change both code and visual baselines emit two commits (code first, baselines second) so reviewer can read commits independently.

---

## Execution

Plan saved to `docs/superpowers/plans/2026-05-14-showcase-apple-tutorials-fidelity.md`. Two execution options:

1. **Subagent-Driven** (recommended) — dispatch a fresh subagent per task, review between tasks, fast iteration. Each phase's "Primary" agent (swift-expert / frontend-developer / etc.) owns its tasks; the "Review" agent gates the phase commit.
2. **Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batch with checkpoints.

Pick one.
