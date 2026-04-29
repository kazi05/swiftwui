# SwiftWUI Showcase Template — Design Spec

**Date**: 2026-04-29
**Status**: Approved (brainstorming)
**Author**: Brainstorming session
**Topic**: Replace Counter scaffold with a 12-chapter Apple-style showcase template that ships as the default `swiftwui init` output.

---

## Goal

Replace the minimal Counter scaffold produced by `swiftwui init <name>` with a feature-complete showcase application that demonstrates every major SwiftWUI feature using a layout and information architecture inspired by Apple's "Develop in Swift" tutorial site (`developer.apple.com/tutorials/develop-in-swift/`).

The showcase doubles as:
- The default sample app for new projects (developers learn by editing real running code).
- The canonical demo for the framework's GitHub README and demo site.
- An integration test for every public API surface.

A `--minimal` flag preserves the previous tiny Counter-style scaffold for users who want a blank slate.

## Non-goals

- Pixel-perfect clone of Apple's site. We mimic the structure and feel; we do not lift the SF Pro web font, Apple device-chrome PNGs, Apple logos, or copyrighted copy.
- A full headless documentation site generator. The showcase is a single example app, not a Hugo/Docusaurus replacement.
- Build-time Swift macros to derive code-strings from view literals. Skipped for v1; revisited if the showcase grows beyond 12 chapters.

## Scope

- One new sample project at `Examples/Showcase/`.
- One new resource bundle inside `SwiftWUICLI` at `Sources/SwiftWUICLI/Templates/showcase/` (a build-time copy of `Examples/Showcase/`).
- Two CLI changes: default scaffold flips to showcase; new `--minimal` flag opts back into the legacy Counter-style template.
- Roughly 14 new Swift source files, 13 routes, 4–6 reusable view components, one `Theme` implementation.
- 13 native snapshot tests (one per chapter + home), one CLI scaffold integration test, one optional browser smoke test.

---

## Architecture

### Macro decisions (locked during brainstorming)

| # | Decision | Choice |
|---|---|---|
| 1 | Integration point | Replace Counter as default `swiftwui init` scaffold (with `--minimal` escape hatch). |
| 2 | Page depth | Home + 12 chapter pages (exhaustive coverage). |
| 3 | Preview rendering | Live inline previews — each chapter step renders the actual SwiftWUI view next to its source string. Code highlighted via `highlight.js` from CDN. |
| 4 | Visual fidelity | Apple-inspired (typography hierarchy, sticky scroll, generous space, light/dark) with SwiftWUI orange accent and a system-font stack — no SF Pro web hosting, no Apple assets. |
| 5 | Hero layout | Split: headline + CTA buttons left, animated code-frame right. |
| 6 | Chapter card style | Thumbnail card — code teaser as visual lead-in above title. |

### Project layout

```
Examples/Showcase/
├── Package.swift                     # Target name uses {{PROJECT_NAME}} placeholder
├── index.html                        # Loads highlight.js + module init
├── Tests/                            # Snapshot + structural tests
│   └── ShowcaseTests/
│       ├── ChapterSnapshotTests.swift
│       └── HomePageTests.swift
└── Sources/
    ├── main.swift                    # Application + 13 Routes
    ├── Theme/
    │   ├── ShowcaseTheme.swift       # `Theme` impl with light/dark token sets
    │   └── Layout.swift              # Spacing constants, max-width container
    ├── Components/
    │   ├── SiteChrome.swift          # NavBar (logo + dropdown + theme toggle), Footer
    │   ├── Hero.swift                # Reusable split hero
    │   ├── ChapterCard.swift         # Thumbnail card on home grid
    │   ├── BadgeGrid.swift           # "What's Inside" mini-grid
    │   ├── ScrollyTeller.swift       # Sticky scroll-pair container
    │   ├── CodeAndPreview.swift      # Single step (code + live view)
    │   └── SyntaxHighlight.swift     # highlight.js bridge via JavaScriptKit
    └── Pages/
        ├── HomePage.swift            # /
        └── Chapters/
            ├── HelloPage.swift       # /learn/hello
            ├── StatePage.swift       # /learn/state
            ├── ModifiersPage.swift   # /learn/modifiers
            ├── ListsPage.swift       # /learn/lists
            ├── FormsPage.swift       # /learn/forms
            ├── RoutingPage.swift     # /learn/routing
            ├── AsyncPage.swift       # /learn/async
            ├── ThemingPage.swift     # /learn/theming
            ├── A11yPage.swift        # /learn/a11y
            ├── ErrorsPage.swift      # /learn/errors
            ├── SSRPage.swift         # /learn/ssr
            └── PWAPage.swift         # /learn/pwa
```

### Component contracts

Each component is a self-contained `Tag` with a focused responsibility.

#### `SiteChrome { content }`
Wraps a page in shared navbar + footer. Reads current route to highlight active chapter in the dropdown. Theme toggle button stores choice in `localStorage` and toggles `<html data-theme>` attribute.

#### `Hero(eyebrow:, headline:, subhead:, primaryCTA:, ghostCTA:, code:)`
Renders the split hero. Right-side code frame shows a static, syntax-highlighted Swift snippet (no `IntersectionObserver`).

#### `ChapterCard(number:, title:, subtitle:, codeTeaser:, href:)`
Single thumbnail card. The thumbnail block renders `codeTeaser` in monospace inside the gradient background.

#### `BadgeGrid(items: [Badge])` and `Badge(title:, description:)`
4-column grid of mini cards for non-chapter features (Container Queries, Anchor Positioning, Parameter Packs, Hot Reload, Brotli/SRI, TestRenderer, QueryParam, Doctor command).

#### `ScrollyTeller(steps: [Step])`
The chapter page's central widget.

```swift
struct ScrollyTeller: Tag {
    struct Step {
        var number: Int
        var title: String
        var prose: String           // single paragraph; markdown-light (`code` only)
        var code: String            // raw Swift source
        var preview: AnyTag         // live view rendered in right pane when this step is active
    }

    let steps: [Step]

    @State private var activeStep: Int = 0

    var body: some Tag { /* CSS grid with sticky right pane */ }
}
```

The container is a `display: grid; grid-template-columns: 1fr 1fr; gap: 64px;` block. The left column iterates `steps` and renders a `CodeAndPreview` per step with `data-scrolly-step="\(step.number)"` and `min-height: 80vh`. The right column is a single `position: sticky; top: 96px;` panel that displays `steps[activeStep].preview`.

`ScrollyTeller` attaches a `.task { … }` mount handler that registers an `IntersectionObserver` on every `[data-scrolly-step]` child. The observer uses `rootMargin: "-40% 0px -40% 0px"` so a step counts as active when it crosses the middle 20% of the viewport. The callback writes `activeStep` through the existing `@State` machinery, which re-renders the right pane.

Mobile fallback at `max-width: 900px`: grid collapses to a single column, the right pane unsticks, and each step's preview inlines below its prose. Pure CSS — no JS branching.

#### `CodeAndPreview(step:)`
Single step: pill with step number, title, prose paragraph, code block (highlight.js-coloured), and an inline preview (used only on mobile; on desktop, preview is hidden via media query because the sticky pane handles it).

#### `SyntaxHighlight`
Calls `hljs.highlightAll()` once on app mount via a `JSClosure` registered on `<body>`'s `.task { … }` and again after every route change. Uses `highlight.js` v11 from `cdn.jsdelivr.net` (`@highlight-js/swift` language pack only — keeps the bundle small).

### Routing

`main.swift` declares 13 routes inside `Application { … }`:

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
app.mount()
```

Each chapter page is a small `Tag` that wraps content in `SiteChrome { … }` and renders an intro block plus one `ScrollyTeller` with that chapter's steps.

### Chapter content (12 chapters × 4–6 steps each)

| # | Path | Title | Steps emphasis |
|---|---|---|---|
| 1 | `/learn/hello` | Hello, SwiftWUI | Tag protocol, body, `Application.mount`, first render |
| 2 | `/learn/state` | State & Bindings | `@State`, `@Binding`, child propagation, `observe()` |
| 3 | `/learn/modifiers` | Modifiers | Chain pattern, `.padding`, `.style` fallback, identity stability |
| 4 | `/learn/lists` | Lists & ForEach | Keyed reconciliation, identity, reorder patches |
| 5 | `/learn/forms` | Forms & Inputs | Slider, Stepper, ColorPicker, DatePicker, Picker, validation |
| 6 | `/learn/routing` | Routing & Guards | `Route`, params, `RouteGuard`, redirect outcomes |
| 7 | `/learn/async` | Async & Resources | `.task { … }`, async data fetch, loading states |
| 8 | `/learn/theming` | Theming | `Theme` proto, light/dark, CSS custom props, mode toggle |
| 9 | `/learn/a11y` | Accessibility | ARIA modifiers, semantic landmarks, focus management |
| 10 | `/learn/errors` | Error Handling | `ErrorBoundary`, fallback UI, recovery |
| 11 | `/learn/ssr` | SSR & Hydration | `StaticRenderer`, `Application.hydrate` |
| 12 | `/learn/pwa` | PWA | `WebAppManifest`, `ServiceWorker.register` |

Below the chapter parts, the home page renders a `BadgeGrid` covering the secondary features that don't earn full chapters: Container Queries, Anchor Positioning, parameter-pack `TupleTag`, hot reload, Brotli + SRI, TestRenderer, `@QueryParam`, `swiftwui doctor`.

---

## Theming

A single `ShowcaseTheme` conforms to the existing `Theme` protocol (Phase 3). It defines two `ThemeTokens` sets — `light` and `dark` — emitted as CSS custom properties on `<html>`.

| Token | Light | Dark |
|---|---|---|
| `--swui-bg` | `#fbfbfd` | `#000000` |
| `--swui-surface` | `#ffffff` | `#1d1d1f` |
| `--swui-surface-2` | `#f5f5f7` | `#2c2c2e` |
| `--swui-fg` | `#1d1d1f` | `#f5f5f7` |
| `--swui-fg-2` | `#424245` | `#a1a1a6` |
| `--swui-fg-3` | `#6e6e73` | `#86868b` |
| `--swui-border` | `#e8e8ed` | `#3a3a3c` |
| `--swui-border-strong` | `#d2d2d7` | `#48484a` |
| `--swui-accent` | `#ff9500` | `#ff9f0a` |
| `--swui-accent-bg` | `#fff5e8` | `#3a2410` |
| `--swui-code-bg` | `#1d1d1f` | `#0d0d0f` |
| `--swui-code-fg` | `#f5f5f7` | `#f5f5f7` |

Spacing scale: `--space-1` through `--space-8` mapping to `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 px`.
Radius scale: `--radius-sm = 8px`, `--radius-md = 12px`, `--radius-lg = 18px`.
Font stacks (system fonts only):
- `--font-display`: `-apple-system, "SF Pro Display", system-ui, "Segoe UI", Roboto, sans-serif`
- `--font-text`: `-apple-system, "SF Pro Text", system-ui, "Segoe UI", Roboto, sans-serif`
- `--font-mono`: `ui-monospace, "SF Mono", "Cascadia Code", Menlo, Consolas, monospace`

Mode resolution:
1. On boot, `SyntaxHighlight`-style mount hook reads `localStorage.getItem("swui-theme")`.
2. If present (`"light"` or `"dark"`), set `document.documentElement.dataset.theme` accordingly.
3. If absent, leave `data-theme` unset and let `:root { color-scheme: light dark; }` plus `@media (prefers-color-scheme: dark) :root { /* dark tokens */ }` follow system preference.
4. The navbar toggle button writes to `localStorage` and updates `data-theme`.

`ShowcaseTheme` emits its CSS into a `<style>` block on the document root with this precedence (the existing `Theme` protocol exposes a `css(scope:)` hook for this; if not, the showcase appends the rules itself in `main.swift`):

```css
:root { /* light tokens */ }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { /* dark tokens */ }
}
:root[data-theme="dark"] { /* dark tokens */ }
```

This honours system preference by default while allowing manual override.

---

## Scaffolding integration

Source-of-truth is `Examples/Showcase/`. The CLI bundles a frozen copy at build time and copies it on `swiftwui init`.

### Build-time copy

A new Makefile target syncs the example into the CLI's resource directory:

```make
sync-templates:
	rm -rf Sources/SwiftWUICLI/Templates/showcase
	mkdir -p Sources/SwiftWUICLI/Templates
	rsync -a --exclude='.build' --exclude='node_modules' \
	      --exclude='Tests' --exclude='.swiftpm' --exclude='dist' \
	      Examples/Showcase/ Sources/SwiftWUICLI/Templates/showcase/
```

`make build` and `make test` depend on `sync-templates`. CI calls `make sync-templates` before `swift build` and hard-fails if the post-build `git status --porcelain Sources/SwiftWUICLI/Templates/showcase` is non-empty.

The `SwiftWUICLI` target gains a resource declaration:

```swift
.executableTarget(
    name: "SwiftWUICLI",
    dependencies: [...],
    resources: [.copy("Templates")]
)
```

### Token substitution

Files inside `Examples/Showcase/` use a single placeholder, `{{PROJECT_NAME}}`, in:
- `Package.swift` — target/product name.
- `index.html` — `<title>` and the module import path.
- `Sources/main.swift` — display title in the hero.

`FileGenerator` gains:

```swift
func scaffoldShowcase(name: String, at destination: URL) throws {
    let templateRoot = Bundle.module.url(forResource: "Templates/showcase", withExtension: nil)!
    try FileManager.default.copyItem(at: templateRoot, to: destination)
    try renameTokens(in: destination, replacing: ["{{PROJECT_NAME}}": name])
}

private func renameTokens(in dir: URL, replacing tokens: [String: String]) throws { /* … */ }
```

`renameTokens` walks every text file (skipping known binary extensions; none are expected in the template) and rewrites in place.

### CLI surface

```
swiftwui init MyApp                     # → showcase scaffold (default, new behaviour)
swiftwui init MyApp --minimal           # → legacy 4-file Counter-style scaffold
swiftwui init MyApp --template <name>   # reserved for future templates
```

The legacy scaffold path stays implemented in `Templates.minimalScaffold(name:)` (~30 lines, retained as the only string-literal template in `Templates.swift`). All other static methods on `Templates` go away.

`swiftwui doctor` gains a check: `diff -q -r Sources/SwiftWUICLI/Templates/showcase Examples/Showcase` excluding ignored dirs. If the diff is non-empty (developer edited the example without re-syncing), `doctor` prints a warning and exit code stays zero (warning, not failure).

---

## Testing

### Layer 1 — compile fidelity (per-PR)
`Examples/Showcase` is a workspace member. CI runs `cd Examples/Showcase && swift build` after the root build. Broken showcase fails the workflow.

### Layer 2 — TagNode snapshots (per-PR)
13 native test cases under `Examples/Showcase/Tests/ShowcaseTests/` (1 home page + 12 chapter pages) use `TestRenderer` (Phase 3 protocol). Each chapter test asserts:
- The expected number of scrolly steps appears (`data-scrolly-step="N"` attributes).
- A canary substring from the chapter's first code sample is present.
- An `aria-label` or semantic landmark survives rendering.

Example:

```swift
@Test
func StatePage_rendersFourSteps() throws {
    let html = try TestRenderer().render(StatePage())
    #expect(html.contains("data-scrolly-step=\"3\""))
    #expect(html.contains("Tapped \\(count)"))
    #expect(html.contains("aria-label="))
}
```

Total: ~150 LOC across all 13 page tests.

### Layer 3 — scaffold integration test (per-PR)
`SwiftWUICLITests/ScaffoldShowcaseTests.swift`:
1. Invoke `swiftwui init TestApp --dir <tmp>`.
2. Assert key files exist (Package.swift, index.html, Sources/main.swift, Sources/Pages/HomePage.swift, all 12 chapter files).
3. Assert no `{{PROJECT_NAME}}` placeholder remains.
4. Assert `TestApp` appears in `Package.swift` and `index.html`.
5. Run `cd <tmp>/TestApp && swift build` — exit code zero.

Runs in `swift test`. Bounded to ~10 sec.

### Layer 4 — browser smoke (nightly, on-demand)
`make smoke` boots `swiftwui dev --target Showcase`, then drives a Preview MCP / Playwright client to:
- Load `/`, assert hero `<h1>` text content and chapter card count = 12.
- Click chapter 2, assert URL becomes `/learn/state` and page header reads "State & Bindings".
- Scroll past step 2, assert right-pane preview content updated (`data-active-step` attribute or a known string in the active preview).
- Toggle theme, assert `<html data-theme="dark">` and that body background-color is the dark token.

Browser smoke is wired into a nightly job, not per-PR (slower, environment-sensitive).

### Drift mitigation

Two layers cover the `Examples/Showcase` ↔ `Templates/showcase` drift surface:
- `make sync-templates` runs in `make build` and `make test`.
- CI fails if `git status --porcelain Sources/SwiftWUICLI/Templates/showcase` is non-empty after `make sync-templates`.
- `swiftwui doctor` warns locally when the two trees diverge.

---

## Risks and open questions

1. **Bundle size growth**: SwiftWUICLI binary grows by an estimated 50–80 KB after embedding the showcase as a resource. Acceptable for a developer-facing CLI.
2. **highlight.js CDN dependency**: The showcase requires `cdn.jsdelivr.net` reachability at runtime for syntax colours. If the CDN is unavailable, code blocks fall back to plain monospace. Acceptable for v1 — switching to a self-hosted highlight.js bundle is a one-line change in `index.html` if it becomes a problem.
3. **Live drift between code-string and live view**: A `CodeAndPreview` step has both a Swift string (shown as code) and a real `Tag` (shown in the preview). They can drift if a developer edits one without the other. Mitigated by snapshot tests asserting canary substrings, and by code-review discipline. The `#sourceCode` macro option (rejected for v1) remains the long-term fix.
4. **Apple-likeness perception**: The visual style is intentionally Apple-tutorial-ish but not identical. If the resemblance is judged too close (legal/brand reasons), the brand colour and typographic rhythm can be retuned without restructuring layout code.

---

## Implementation order (preview, not the plan)

1. Add `Examples/Showcase/` skeleton: `Package.swift`, `main.swift` with stub routes, `index.html`. Verify `swift build` passes from a fresh clone.
2. Build the `Theme/ShowcaseTheme.swift` and base `Layout.swift` constants. Verify CSS variables emit on `<html>`.
3. Build reusable components in order: `SiteChrome` → `Hero` → `ChapterCard` → `BadgeGrid` → `CodeAndPreview` → `ScrollyTeller` → `SyntaxHighlight`.
4. Author `HomePage` + first chapter (`HelloPage`) end-to-end. Ship + verify in browser via Preview MCP.
5. Author the remaining 11 chapter pages. Snapshot tests for each.
6. Wire scaffolding: `make sync-templates`, `Templates/showcase` resource, `FileGenerator.scaffoldShowcase`, `--minimal` flag, `swiftwui doctor` drift check.
7. Add scaffold integration test + nightly browser smoke.

The detailed implementation plan is the next step (writing-plans skill).
