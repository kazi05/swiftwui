# Phase 7 — SwiftWUI Tutorial Site ("Hello, SwiftWUI")

**Date:** 2026-07-05
**Status:** Approved design (brainstorm complete; awaiting implementation plan)
**Figma:** `u9MtpHLmB6MvupyLgEHayW` — frames `1:2` (main tutorial page), `11:26` (Style in Swift), `12:34` (Route between pages), `13:42` (Prerender and hydrate), `10:26` (chapter-menu overlay), symbol `4:2` (Step).

## 1. Purpose

The best documentation for SwiftWUI is a finished tutorial page plus the real code behind it — modeled on Apple's "Develop in Swift / Hello, SwiftUI" tutorials, where steps scroll on the left and real screenshots of real code appear on the right. The site itself is built **with SwiftWUI** (dogfooding): every page is prerendered by `ssg`, hydrated by the WASM runtime, and every interactive element (quiz, chapter menu, scrollspy) is a live `@State` component. The site existing at all is the framework's strongest proof.

This is the opening slice of the Phase 7 roadmap item (docs site).

## 2. Decisions (settled in brainstorm)

| # | Decision | Choice |
|---|----------|--------|
| D1 | Site stack | Pure SwiftWUI app: `swiftwui build` + `swiftwui ssg` (wrapper over `swift run TutorialSite ssg`) + hydration. No hand-written JS. |
| D2 | Scroll UX | Apple-style: right panel CSS-sticky within each section; active step highlighted via scrollspy; a step may swap the panel content. |
| D3 | Scope | Full curriculum, 12 pages (see §3). |
| D4 | Location / deploy | `Sites/Tutorial` in-repo, path dependency on SwiftWUI. No deploy this phase (publication is a phase-7 carry). Local viewing via `swiftwui serve dist`. |
| D5 | Preview screenshots | Playwright script drives the real sample apps, captures PNGs step-by-step, commits them to the repo. Site build does not depend on Playwright. |
| D6 | Content architecture | Data-driven engine: content = plain Swift structs (`Chapter → Section → Step`, `Panel`, `Quiz`); one component set renders all page kinds. |
| D7 | Site copy language | English (matching code/docs convention). |
| D8 | Syntax highlighting | Build-time Swift tokenizer in the site target (`SwiftHighlighter`) emitting `Span(class:)` tokens — deterministic, identical output in ssg and wasm (hydration-adoption safe). No JS highlighter. |
| D9 | Scrollspy home | Site-local helper on JavaScriptKit (`#if arch(wasm32)`), registered via `.onAppear`. Framework untouched; promotion to a framework modifier is a separate future decision. |
| D10 | Fonts | System font stacks (`system-ui` + monospace). No external font loads. |
| D11 | Viewport scope | Desktop-first per the 1440px Figma. One breakpoint (≤1080px): section grid collapses to a single column, the panel renders inline after its step list (non-sticky), scrollspy highlight stays. Full responsive/mobile design is a later slice (§14). |

## 3. Curriculum (12 pages)

Three page kinds, one engine:

- **Overview** (`/`) — "Welcome to SwiftWUI Tutorials": hero + chapter cards grouped by track. No Figma frame; the pattern is fixed here: card = kicker + title + tagline + minutes badge (all existing `Chapter` fields), cards grouped under track headers in curriculum order; hero copy authored in the overview's content file. No NextChapter CTA.
- **Chapter** — the Figma `1:2` pattern: Nav + ChapterBar + Hero + N sections (steps left, sticky panel right) + optional quiz + NextChapter CTA + Footer. The quiz, when present, renders between the last section and the CTA (that is where Figma `1:2` places it).
- **Wrap-up** — chapter-group summary: recap bullets (`Chapter.recap`) + quiz (required) + CTA. No sections.

| # | Track | Page | Kind | Design source | Right-panel / content material |
|---|-------|------|------|---------------|-------------------------------|
| 1 | Welcome | Welcome to SwiftWUI Tutorials | overview | none — pattern fixed above | chapter cards from Curriculum |
| 2 | Welcome | Install the toolchain | chapter | none — chapter pattern | terminals (swiftly, Swift 6.3.3 + matching WASM SDK, version-match warning) |
| 3 | Welcome | Create your first project | chapter | none | terminal (`swiftwui init` / `dev`, template choice) + screenshot of the scaffolded basic-template app |
| 4 | Explore | **Hello, SwiftWUI** | chapter | **Figma 1:2 (full)** | terminal, code, Counter screenshot, quiz |
| 5 | Explore | Wrap-up: Explore SwiftWUI | wrap-up | none — wrap-up pattern | recap + quiz |
| 6 | Styles | Style in Swift | chapter | Figma 11:26 (1 section) + authored: rule classes/stylesheets; themes + `ColorToken` | code + screenshots |
| 7 | Styles | Wrap-up: Styles | wrap-up | none | recap + quiz |
| 8 | Routing | Route between pages | chapter | Figma 12:34 (1 section) + authored: `Link`/`navigate`, `:param` routes, browser history | code + screenshots |
| 9 | Routing | Wrap-up: Routing | wrap-up | none | recap + quiz |
| 10 | Ship | Prerender and hydrate | chapter | Figma 13:42 (1 section) + authored: hydration adoption, state snapshot | terminal + screenshots |
| 11 | Ship | Deploy with Docker | chapter | none | Dockerfile + terminal; honest note that the template Dockerfile requires a published SwiftWUI (path-dep limitation, "once published") |
| 12 | Ship | Wrap-up: Ship | wrap-up | none | recap + quiz |

Authored pages follow the designed patterns (section = kicker + title + intro + 3–5 steps + panel). The chapter-menu overlay (`10:26`) lists all 12 entries; since all 12 ship this phase, every entry is live.

Quizzes: every quiz has exactly 3 questions (Figma `9:26` shows "Question 1 of 3"; §9 tests the invariant). Chapter 4 carries its designed quiz; wrap-ups always carry one; other chapters have none.

Next-chapter CTA: target derived from curriculum order. The last page (Wrap-up: Ship) links back to the overview ("Explore more tutorials"). The overview has no CTA.

## 4. Package layout

```
Sites/Tutorial/
├─ Package.swift              # path dep on SwiftWUI (products SwiftWUI, SwiftWUIDOM,
│                             #   SwiftWUIStatic under .when(platforms: [.macOS, .linux]))
│                             # + JavaScriptKit product directly on the target (TodoMVC shape)
├─ index.html                 # CLI-template shape (import { init } from "/app/index.js")
├─ Sources/TutorialSite/
│  ├─ main.swift              # #if canImport(SwiftWUIStatic) ssg entry / wasm App entry (TodoMVC pattern)
│  ├─ App.swift               # TutorialApp: routes, themes, global styles
│  ├─ Model/
│  │  ├─ Curriculum.swift     # ordered [Chapter]; next-links derived from order
│  │  └─ ContentModel.swift   # Chapter/Section/Step/Panel/Quiz structs
│  ├─ Content/
│  │  ├─ Ch01_Welcome.swift … Ch12_WrapUpShip.swift   # one file per page
│  ├─ Components/
│  │  ├─ SiteNav.swift, ChapterBar.swift, ChapterMenu.swift
│  │  ├─ HeroView.swift, SectionView.swift, StepList.swift
│  │  ├─ PanelView.swift      # code-card / terminal / browser-mock
│  │  ├─ QuizCard.swift, NextChapterCTA.swift, SiteFooter.swift
│  │  └─ OverviewPage.swift, ChapterPage.swift, WrapUpPage.swift
│  ├─ Support/
│  │  ├─ SwiftHighlighter.swift
│  │  └─ ScrollSpy.swift      # #if arch(wasm32) JavaScriptKit IntersectionObserver
│  └─ Theme.swift             # ColorToken set + ThemeDefinition from Figma variables
├─ Assets/
│  └─ screens/                # committed Playwright PNGs
├─ Samples/
│  ├─ StyleBubble/            # tiny runnable package per authored chapter (see §7)
│  ├─ ChatRouter/             #   each with its own index.html (swiftwui build requires it)
│  └─ ShipCounter/
└─ tools/screenshots/         # package.json, playwright, shots.config.ts, smoke.spec.ts
```

## 5. Content model

```swift
struct Chapter  { slug, track, kicker, title, tagline, minutes, kind,
                  sections: [Section], recap: [String]?, quiz: Quiz? }
                  // kind == .wrapUp → sections empty, recap + quiz required
                  // kind == .overview → sections empty, no recap/quiz; cards derive
                  //   from the other chapters' metadata (kicker/title/tagline/minutes/track)
enum  PageKind  { case overview, chapter, wrapUp }
struct Section  { kicker, title, intro: String?, steps: [Step], panel: Panel }
struct Step     { title, detail: String?, panel: Panel? }        // override → scrollspy swaps panel
enum  Panel     { case code(file: String, source: CodeRef)
                  case terminal(title: String, lines: [TermLine])
                  case browser(url: String, screenshot: String) } // Assets/screens path
struct Quiz     { questions: [Question] }                         // exactly 3; options + correctIndex + explanation
enum  CodeRef   { case literal(String)                            // short fragment; must be a verbatim
                                                                  //   substring of a compiled sample file (§9.2)
                  case sample(path: String, marker: String) }     // excerpt between // tutorial:begin/end
```

Content structs are renderer-agnostic (no Tag imports) so native tests can validate them without a backend.

## 6. Engine components & behavior

- **SiteNav / SiteFooter** — static; links per Figma. Until real surfaces exist, Docs/Examples point at GitHub repo paths (README/docs dir, Examples dir); Tutorials → `/`; GitHub → repo.
- **ChapterBar** — series label + two `@State` dropdowns: chapter dropdown opens the `ChapterMenu` overlay (Figma `10:26`, grouped list, current item marked); section dropdown lists the current page's sections as `#anchor` links. On overview and wrap-up pages (no sections) the section dropdown is hidden.
- **Page dispatch** — the `/tutorials/:slug` route body looks the slug up in `Curriculum` and switches on `kind` to `ChapterPage` / `WrapUpPage` (no separate dispatcher component; `OverviewPage` is the static `/` route).
- **SectionView** — CSS grid; left `StepList`, right sticky panel (`position: sticky` scoped to the section). Each step gets a stable DOM id for scrollspy + anchors. Below the D11 breakpoint: single column, panel inline after the step list, non-sticky.
- **ScrollSpy** — wasm-only: one IntersectionObserver per section over step elements; callback sets `@State activeStep` → active-step highlight class + panel swap when the step carries a `panel` override. `JSClosure` retained for the component's lifetime (v1 lesson). **Initial state contract (hydration):** `activeStep` defaults to `0` on both backends; ssg output renders step 0 with the active class; a section whose step 0 has no override shows `Section.panel`. Scrollspy mutates state only post-mount, so prerendered HTML and first hydrated render agree.
- **PanelView** — three variants matching Figma: mac-chrome code card (traffic lights + filename), terminal (prompt/output line styling), browser mock (URL bar + screenshot `Img`).
- **QuizCard** — `@State selected: Int?`, `@State checked: Bool`; check reveals correct/incorrect styling + explanation; "Next question" cycles `@State index` over `questions.count`.
- **SwiftHighlighter** — line-based tokenizer: keywords, type-ish identifiers (leading uppercase), strings (incl. interpolation boundary), comments, numbers, property wrappers (`@State` etc.), CLI prompt lines for terminals. Deterministic output only — same spans in ssg HTML and hydrated DOM.

## 7. Samples — source of truth for tutorial code

- `Examples/Counter` is the hero app of "Hello, SwiftWUI": the page's code panels are excerpts of its real source via `// tutorial:begin/end` markers (verified by test, §9). If the tutorial narrative needs the counter code to read differently, the change lands in `Examples/Counter` first.
- `Sites/Tutorial/Samples/*` — minimal runnable SwiftWUI packages per authored chapter: `StyleBubble` (modifiers + theme + stylesheet), `ChatRouter` (Route/Link/`:param`/history), `ShipCounter` (Counter configured for the ssg + hydrate + Dockerfile story). Each compiles natively and for wasm; each is a Playwright screenshot target; each carries the CLI-template `index.html`.
- Page 3's screenshot source is a basic-template scaffold the screenshot script generates itself (`swiftwui init` into a temp dir — deterministic), so the shot is reproducible without committing a fourth sample.
- Code panels never contain code that doesn't compile somewhere in the repo. Short fragments (`CodeRef.literal`) are allowed only when they are verbatim substrings of a compiled sample file — enforced by test (§9.2).

## 8. Screenshot & smoke pipeline (Playwright)

- `tools/screenshots/shots.config.ts` — manifest of frames: `{ sample, route, actions (e.g. click "+" ×3), viewport 960×544, out: Assets/screens/<name>.png }`.
- `npm run shots`: for each sample — `swiftwui build --out <tmp>` (+ sample `ssg` when the shot needs a prerendered page), `swiftwui serve`, run actions, save PNG. All sample builds go through the CLI (isolated `.build-wasm` scratch path — never raw `swift package js` mixed with native builds, §13). Screenshots are committed; regenerating is an explicit developer action.
- `npm run smoke`: acceptance run against the built site (`swiftwui serve dist`):
  - every one of the 12 pages loads AND carries `[data-swui-hydrated="true"]` on the container (the runtime sets it only on successful adoption; console silence is NOT proof — the adoption-failure path cold-renders silently);
  - quiz: select → check → correct/incorrect highlight;
  - chapter-menu overlay: open → navigate;
  - scrollspy: active-step class flips on scroll;
  - panel swap: scroll to a step carrying a `panel` override and assert the sticky panel content changed (at least one chapter — Hello, SwiftWUI — must contain a `Step.panel` override so this has a target);
  - no console errors.
- The site build never invokes Playwright; missing screenshots fail the native content test (§9), not the build.

## 9. Testing

Native `swift test` is the primary gate (MockBackend, no browser):

1. **Content invariants** — slugs unique; menu/next-chapter links resolve (last chapter → overview); wrap-ups have recap + quiz and zero sections; every quiz has exactly 3 questions with `correctIndex` in range; every `Panel.browser` screenshot file exists on disk; every `CodeRef.sample` marker resolves; at least one `Step.panel` override exists in ch. 4.
2. **Excerpt sync** — `CodeRef.sample` panels match current file content between markers; every `CodeRef.literal` string is a verbatim substring of at least one file under `Samples/` or `Examples/Counter/Sources` (fails when a sample drifts from the page).
3. **SwiftHighlighter goldens** — token-span output pinned for representative fragments of the real samples.
4. **Page render golden** — HTMLRenderer output for one full chapter page pinned (structure regression).
5. **Route enumeration** — ssg config paths (11, §11) + the static root equal the curriculum count (12).

## 10. Acceptance matrix (phase gate)

1. `swift test` green (site package + framework suite untouched).
2. All samples compile: native `swift build` + wasm via `swiftwui build` (CLI path isolates `.build-wasm`; no raw `swift package js` next to native builds — §13).
3. `swiftwui build` + `swiftwui ssg --out dist` → 12 prerendered pages; every screenshot referenced by a `Panel.browser` resolves to a file under `dist`.
4. `npm run smoke` green against `swiftwui serve dist` (hydration attribute on 12/12 pages, quiz, menu, scrollspy, panel swap).
5. Visual spot-check against Figma frames `1:2`, `11:26`, `12:34`, `13:42` (manual, non-blocking — same convention as phases 3–6).

## 11. Routing & SSG

- `Route("/") { OverviewPage() }`; `Route("/tutorials/:slug") { … }` — slug looked up in `Curriculum` among non-overview chapters; unknown slug (including the overview's own) renders a small not-found Tag.
- ssg entry (TodoMVC dual-entry pattern, `#if canImport(SwiftWUIStatic)`): `StaticSite.generate(TutorialApp.self, config: .init(outDir:, mode: .hydrate(wasmScriptPath: "/app/index.js"), paths: <11 slug paths>))` — the CLI dist layout puts the bundle at `/app/index.js` (the templates' value; TodoMVC's `/index.js` is valid only for its non-CLI serving). Paths enumerated from `Curriculum` filtering out `kind == .overview` (11 paths; the root comes from the static route). Default importmap already matches the CLI layout.
- Invoked as `swiftwui ssg` (wraps `swift run TutorialSite ssg --out …`).
- Hydration: prerendered HTML shows step-0 panels (active class on step 0, §6) and unopened menus; adoption matches because the highlighter is deterministic (D8) and scrollspy mutates state only post-mount (D9).

## 12. Styling

- Figma tokens → `Theme.swift`: warm light background, dark card/terminal surfaces, orange accent, muted text tones as `ColorToken`s + one `ThemeDefinition`. Exact values pulled from Figma variables (`get_variable_defs` / design context) at implementation time — the palette is fixed by the design, only the extraction is deferred.
- Layout: 1040px content column (Figma), CSS grid for section bodies, `position: sticky` right column; single-column collapse below the D11 breakpoint.
- Styles via type-safe modifiers + rule classes; `.style()` escape hatch where the DSL lacks a property — which is itself a teaching point in chapter 6.
- Fonts: `system-ui` stack for UI, `ui-monospace/SFMono/Menlo` stack for code.

## 13. Risks & open items (verify during implementation planning)

- **Asset pipeline**: `swiftwui build`/`ssg` dist assembly may not copy arbitrary `Assets/` files; if not, the site's build step gains an explicit `cp -R Assets dist/assets` (documented in the site README). Not a design blocker; acceptance §10.3 catches it.
- **Sticky + scrollspy interplay**: IntersectionObserver thresholds need tuning so the active step flips when a step's top crosses the panel line; ship with a sensible default, adjust in smoke.
- **`.build` symlink hazard** (phase-6 carry): all wasm builds — screenshot script AND acceptance runs — go through the CLI (isolated `.build-wasm`); never raw `swift package js` mixed with native `swift build`/`swift run` in the same directory.
- **CSP carry note** (phase-6): hydrate boot script is inline JS; the tutorial serves locally so no CSP constraint this phase, but the Ship chapter should not claim strict-CSP compatibility.
- **Docker chapter honesty**: template Dockerfile is inoperative until SwiftWUI is published (path dep outside build context). Chapter 11 teaches the flow and states the limitation explicitly.

## 14. Implementation ordering (guidance for the plan)

1. **Engine slice first**: content model + components + theme + one fully wired chapter (Hello, SwiftWUI) end-to-end — ssg + hydration + quiz + scrollspy. Its Counter screenshot may land as a hand-made placeholder for at most this slice.
2. **Pipeline slice**: Samples packages + Playwright shots + smoke; regenerate ch. 4's screenshot through the pipeline (placeholder dies here).
3. **Content slices**: remaining chapters in curriculum order (their `Panel.browser` content lands only after the pipeline exists — §9.1 makes missing PNGs a test failure), then wrap-ups + overview.

Each slice keeps `swift test` green; §10's full matrix gates the phase, not each slice.

## 15. Out of scope (this phase)

- Deployment / GitHub Pages / CI publishing; base-path knob (cssFile relative-href carry).
- brew/mint distribution, git-URL template dependency (phase-7 carry items — separate slice).
- Full responsive/mobile design beyond the single D11 breakpoint; touch-specific UX.
- Search, versioned docs, API reference (DocC) — later docs-site slices.
- Framework changes of any kind (scrollspy stays site-local).
- Localization (English only).
