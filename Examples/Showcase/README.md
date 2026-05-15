# Examples/Showcase

This directory is the source-of-truth for the `swiftwui init` showcase template — a fully working SwiftWUI application demonstrating every major framework feature across 12 chapters in an Apple-tutorial-style layout.

## Boot

```bash
swiftwui dev --target Showcase
```

Open `http://localhost:8080`.

## Editing rules

`Examples/Showcase/` is canonical. The CLI bundles a copy at `Sources/SwiftWUICLI/Templates/showcase/` with project-name placeholders. **Never edit `Templates/showcase/` directly.** After making changes here, run:

```bash
make sync-templates
```

CI enforces that the two directories stay in sync on every push.

## Design references

- Spec: `docs/superpowers/specs/2026-04-29-showcase-template-design.md`
- Plan: `docs/superpowers/plans/2026-04-29-showcase-template.md`

## Chapters

| # | Route | Source file |
|---|---|---|
| — | `/` | `Sources/Showcase/Pages/HomePage.swift` |
| 1 | `/learn/hello` | `Sources/Showcase/Pages/Chapters/HelloPage.swift` |
| 2 | `/learn/state` | `Sources/Showcase/Pages/Chapters/StatePage.swift` |
| 3 | `/learn/modifiers` | `Sources/Showcase/Pages/Chapters/ModifiersPage.swift` |
| 4 | `/learn/lists` | `Sources/Showcase/Pages/Chapters/ListsPage.swift` |
| 5 | `/learn/forms` | `Sources/Showcase/Pages/Chapters/FormsPage.swift` |
| 6 | `/learn/routing` | `Sources/Showcase/Pages/Chapters/RoutingPage.swift` |
| 7 | `/learn/async` | `Sources/Showcase/Pages/Chapters/AsyncPage.swift` |
| 8 | `/learn/theming` | `Sources/Showcase/Pages/Chapters/ThemingPage.swift` |
| 9 | `/learn/a11y` | `Sources/Showcase/Pages/Chapters/A11yPage.swift` |
| 10 | `/learn/errors` | `Sources/Showcase/Pages/Chapters/ErrorsPage.swift` |
| 11 | `/learn/ssr` | `Sources/Showcase/Pages/Chapters/SSRPage.swift` |
| 12 | `/learn/pwa` | `Sources/Showcase/Pages/Chapters/PWAPage.swift` |

## Tests

51 tests across 20 suites in `Tests/ShowcaseTests/`. Run with:

```bash
make showcase-test
```

End-to-end Playwright suites (smoke, nav, scrolly, a11y, visual, preview) live in `Tests/*.spec.ts`. Run with:

```bash
make showcase-playwright
```
