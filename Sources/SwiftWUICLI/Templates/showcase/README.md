# Examples/{{PROJECT_NAME}}

This directory is the source-of-truth for the `swiftwui init` {{project_name}} template — a fully working SwiftWUI application demonstrating every major framework feature across 12 chapters in an Apple-tutorial-style layout.

## Boot

```bash
swiftwui dev --target {{PROJECT_NAME}}
```

Open `http://localhost:8080`.

## Editing rules

`Examples/{{PROJECT_NAME}}/` is canonical. The CLI bundles a copy at `Sources/SwiftWUICLI/Templates/{{project_name}}/` with project-name placeholders. **Never edit `Templates/{{project_name}}/` directly.** After making changes here, run:

```bash
make sync-templates
```

CI enforces that the two directories stay in sync on every push.

## Design references

- Spec: `docs/superpowers/specs/2026-04-29-{{project_name}}-template-design.md`
- Plan: `docs/superpowers/plans/2026-04-29-{{project_name}}-template.md`

## Chapters

| # | Route | Source file |
|---|---|---|
| — | `/` | `Sources/{{PROJECT_NAME}}/Pages/HomePage.swift` |
| 1 | `/learn/hello` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/HelloPage.swift` |
| 2 | `/learn/state` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/StatePage.swift` |
| 3 | `/learn/modifiers` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/ModifiersPage.swift` |
| 4 | `/learn/lists` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/ListsPage.swift` |
| 5 | `/learn/forms` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/FormsPage.swift` |
| 6 | `/learn/routing` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/RoutingPage.swift` |
| 7 | `/learn/async` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/AsyncPage.swift` |
| 8 | `/learn/theming` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/ThemingPage.swift` |
| 9 | `/learn/a11y` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/A11yPage.swift` |
| 10 | `/learn/errors` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/ErrorsPage.swift` |
| 11 | `/learn/ssr` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/SSRPage.swift` |
| 12 | `/learn/pwa` | `Sources/{{PROJECT_NAME}}/Pages/Chapters/PWAPage.swift` |

## Tests

51 tests across 20 suites in `Tests/{{PROJECT_NAME}}Tests/`. Run with:

```bash
make {{project_name}}-test
```

End-to-end Playwright suites (smoke, nav, scrolly, a11y, visual, preview) live in `Tests/*.spec.ts`. Run with:

```bash
make {{project_name}}-playwright
```
