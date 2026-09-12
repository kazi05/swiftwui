# Changelog

Notable changes to SwiftWUI. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions match the
`v<version>` git tags described in `Sources/SwiftWUIToolchain/SwiftWUIVersion.swift`.

## [Unreleased]

## [0.10.0] - 2026-09-12

### Added

- `VirtualForEach` provides fixed-height, keyed virtual collections with an
  overscan window and bounded initial HTML. Use `.complete` where every item
  must remain in the document; variable-height rows are not supported.
- Opt-in `RuntimeDiagnostics` reports render reasons, dirty-cover counts,
  lifetime counts and optional tree metadata. Debug WASM builds can expose the
  bounded metadata ring through `DOMRuntime.enableDevTools()`.
- `ExplicitComponentRegistration` gives components stable identifiers and named
  state slots for hydration snapshots. The dependency-free
  `Scripts/generate-component-registration.mjs` prototype emits same-file
  registrations, including for private wrapper storage.
- `WebResourceCache`, `AsyncResource` and `AsyncBoundary` add keyed GET caching,
  request deduplication, TTL, cancellation, invalidation and explicit hydration
  seeds. `EnhancedForm`/`FormSubmission` add asynchronous form state and field
  errors while ordinary form submission remains available without JavaScript.
- `StaticSiteMode.staticOnly` emits no boot loader, import map, state snapshot
  or WASM resource. Hydrated static sites may defer activation with
  `BootActivation.idle`, `.visible` or `.interaction`; `DOMRuntime.mountIsland`
  adds disposable, selectively activated leaf widgets.
- Public static-delivery validation supports indexed metadata, canonical URLs,
  JSON-LD and generated local links. `StaticSiteConfig.delivery` exports exact
  redirects, trailing-slash policy and 404 behavior for preview and nginx.
- `DOMNavigationOptions` adds post-commit focus, polite title announcements and
  back/forward scroll restoration.
- `ComputeWorker` supports typed `Sendable` messages, cancellation, explicit
  `WorkerBuffer` transfer ownership, compiled-module reuse and terminal teardown.
- `swiftwui build` writes `swiftwui-build-report.json` with toolchain,
  raw/gzip/Brotli, section and import data. `swiftwui metrics` validates a
  built artifact against a fixture/configuration-specific size budget. Optional
  `swiftwui-assets.json` produces responsive image variants and asset metadata.
- `swiftwui interop init --target <target>` scaffolds an app-owned BridgeJS
  boundary pinned to JavaScriptKit 0.56.1. The sample facade covers synchronous
  calls, promises, errors and explicitly disposable callbacks.
- `ScrollReader` and `ScrollProxy` expose fresh layout metrics and explicit
  anchor restoration/end scrolling after DOM commit. Reader-scoped lookup,
  hydration and unmount guards preserve host ownership; smooth commands respect
  reduced motion. Existing scroll events and CSS `ScrollBehavior` remain compatible.
- `onDocumentVisibilityChange(initial:_:)` and
  `onVisualViewportChange(initial:_:)` deliver deduplicated, lifecycle-scoped
  browser visibility and visual viewport snapshots after the client commit.
- Typed visibility roots and margins let elements observe the viewport or the
  nearest named ancestor, with exact-host rebinding and logical-unmount cleanup.
- `KeyEvent.isComposing` and callback-scoped `preventDefault()` support IME-aware
  Enter handling without a separate JavaScript listener. Existing initializer
  calls remain compatible; delayed cancellation calls have no effect.
- `WebFile.blob()`, range-based `WebBlob.slice`, and `WebSession.upload(for:from:)`
  send browser-selected files without first reading them into WASM. Data-backed
  blobs support native and browser uploads; existing readers/transports can opt
  into the new capabilities without changing their existing conformances.
- Opaque `WebObjectURL` handles work with Img, Video, Audio, and A. Resources are
  retained through shared use and exit transitions, support explicit idempotent
  revocation, and are omitted from generated HTML and hydration snapshots.

### Changed

- Dirty runtime updates now use ancestor-based minimal cover selection and one
  indexed batched tree replacement. In the repository's serialized native
  debug fixture, a 500-row coalesced flush fell from 739.92 ms to 31.59 ms
  (23.4x). This is not a browser, release-mode, or Core Web Vitals claim.
- `Runtime.unmount()` is terminal and drains listeners, effects, state,
  observation gates and browser subscriptions. It is safe to call repeatedly;
  a disposed runtime cannot be mounted again.
- Build preflight records the resolved `swift` and `swiftc` paths and rejects
  missing, Embedded, malformed or known mismatched host/compiler/SDK selections.
- The modernized Counter release is 9,611,359 bytes raw, 3,433,088 gzip and
  2,497,701 Brotli 11, versus 9,407,550 / 3,353,472 / 2,415,062 before this
  work. The default shared WASM module is therefore about 2.2% larger raw;
  this release does not claim a general WASM-size reduction.

### Fixed

- Visibility callbacks now compare `intersectionRatio` with the requested
  threshold and process every queued IntersectionObserver entry. Thresholds
  must be finite and in `0...1`; zero preserves `isIntersecting` semantics.
- Native HTTP requests preserve fractional timeout values and report URLSession
  cancellation and timeout as `WebFetchError.cancelled` and `.timeout`.
- State/observation callbacks, async resource completions and deferred work
  now reject stale generations after unmount or replacement.
- Static output rejects traversal, percent-encoded traversal and symlink escape
  paths. Redirects are served as their configured 301, 302 or 308 status, and
  indexed unknown routes return 404 rather than an accidental SPA response.
- Tutorial sitemap generation now uses the site origin and avoids duplicated
  `/tutorials/tutorials/` URL prefixes.
- Worker buffer ownership changes only after a successful `postMessage`, so a
  synchronous clone failure leaves the source buffer usable. Failed workers now
  complete all pending calls.
- Delayed boot activation, interop loading, malformed history fragments, focus
  restoration and responsive-image regeneration have regression coverage.

### Migration

- Existing applications remain source compatible by default. To retain stable
  component state across wrapper reorder/add/remove, opt into
  `ExplicitComponentRegistration` and give each state slot a unique `stableID`;
  do not mix named and unnamed slots within a component.
- Virtual collections require a truthful `rowHeight`. Keep variable-height,
  searchable or fully crawlable collections on `ForEach`/`.complete` or publish
  paginated static pages.
- Retain every returned `DOMIsland` and call `dispose()` when its container is
  removed. Islands require a dedicated container outside a reconciled root,
  cannot contain `Router`, replace their initial static children on activation,
  and share the document's module bytes.
- Public sites should opt into `StaticSiteConfig(indexing: .indexed)` only after
  providing an absolute origin, title, description and valid local links. Set
  `activationSelector` for visible/interaction activation. Regenerate hosting
  adapter files after each SSG run.
- BridgeJS is opt-in experimental integration. Run `swiftwui interop init`,
  commit generated bindings, retain and dispose subscriptions, and pin the Node
  environment used for TS2Swift generation. It is not automatic npm-package
  binding generation.
- Swift 6.3.3 remains the supported compiler. The Swift 6.4 continuous
  Observation and Embedded Swift work are isolated experiments: no compatible
  full SwiftWUI Embedded/browser profile is included.

## [0.9.2] - 2026-08-05

### Fixed

- **Wasm bundles are ~36 MB smaller.** `SHA256.swift` moved into the `SwiftWUI` core in 0.9.0
  carrying a bare `import Foundation`. Swift emits autolink entries per *module*, not per file,
  so that one import made every object file in `SwiftWUI` — and every module downstream of it —
  request `-lFoundationInternationalization -l_FoundationICU`. `lib_FoundationICU.a` defines
  `icudt76_dat`, a single non-strippable data symbol holding every ICU locale, calendar and
  collation table, so it is linked whole or not at all.

  Every bundle built against 0.9.0 or 0.9.1 carries it. Measured on the Counter example:
  **45 MB → 8.8 MB** raw, 12 MB → 2.3 MB brotli. On a real 11.8k-LOC site: 48.9 MB → 10 MB raw,
  12.7 MB → 2.6 MB brotli. If you shipped a site built with 0.9.0 or 0.9.1, rebuild it.

  The file needed the umbrella for exactly two things: `Data` (which
  `FoundationEssentials` has, via the `_FoundationData` typealias the core already declared) and
  `String(format:)` (which it does not — now a hand-rolled nibble table).

### Added

- **A guard against the same regression, on both sides of the framework boundary.**
  `FoundationImportGuardTests` fails `swift test` when any file in `SwiftWUI` or `SwiftWUIDOM`
  imports `Foundation`, `CoreFoundation` or `FoundationInternationalization` outside the
  `#else` branch of a `#if canImport(FoundationEssentials)` guard.

  For applications, `swiftwui build -c release` now reads the built bundle's
  `.swift1_autolink_entries` section and warns when it links `_FoundationICU`, naming the
  modules that requested it and the size their data section reached. It warns and never fails —
  an app that genuinely needs `Locale` or `Calendar` must still build.

## [0.9.1] - 2026-08-04

### Fixed

- **`swift build -c release` no longer crashes the compiler.** Every class in `SwiftWUI` and
  `SwiftWUIStatic` inherited a MainActor-isolated `deinit` from
  `.defaultIsolation(MainActor.self)`, and Swift 6.3.2/6.3.3 die with signal 11 in the SIL
  inliner optimizing one for an Apple target. Each class now opts out with
  `nonisolated deinit { }` — no class in either target had a deinit body, so the isolation only
  bought an executor hop per dealloc.

  The crash was latent since 0.6.0 and became reachable in 0.9.0, when `SwiftWUIToolchain`
  started depending on the core: that is what first pulled `SwiftWUI` into the optimized CLI
  build, so `brew install swiftwui` failed on 0.9.0. Wasm builds were never affected.

## [0.9.0] - 2026-08-04

### Added

- **Boot loading.** A SwiftWUI binary is a couple of megabytes compressed, which on a slow
  connection is ten-odd seconds during which a prerendered page looks alive and is not. You can
  now declare what the visitor sees in that window, in Swift:

  ```swift
  struct MyApp: App {
      static var bootUI: BootUI {
          .overlay(after: .ms(300)) { Div(class: "boot") { P { "Loading…" } } }
      }
  }
  ```

  ``BootUI`` sits on ``App`` and on ``Page`` (a page override wins; `.none` opts a page out),
  ``Tag/whileBooting(_:)`` puts a skeleton in place of one heavy widget, and ``BootRetry`` is a
  retry control for the failed state — it carries no Swift closure, because the failed state is
  precisely the one with no runtime to run one.

  The UI is rendered **natively at build time**, through the document's own runtime, so an
  overlay that reads the localization catalog renders in that document's language. It ships
  inside an inert `<template>` and is revealed by a small shipped JS shim that fetches the wasm
  itself, so progress is counted against real decompressed bytes rather than `Content-Length`.
  Phase lives in one attribute on `<html>` — `downloading`, `starting`, `failed`, and *absent*
  for ready. Absent-means-ready is deliberate: a client that runs no JavaScript never sees the
  attribute, so it gets the ordinary static page instead of one hidden behind skeletons.

  Typed keystrokes survive hydration, `swiftwui serve --boot-debug` previews the states against
  a real build, and `swiftwui dev` serves the shim so a scaffolded project boots the same way it
  will in production.

- **Per-locale route paths.** A route can have its own URL in each language —
  `/delivery/:from/:to` in English, `/dostavka/:from/:to` in Russian — through an optional table
  inside ``Localization``:

  ```swift
  Localization(catalog: L10n.self, default: .en, strategy: .pathPrefix(),
               routePaths: LocalizedRoutes { … })
  ```

  ``Route``, ``Router``, guards, `@RouteParam` and ``Prerender`` are untouched: the canonical
  path is what the render tree keeps seeing, and only `LocalePath`'s externalize/internalize
  consult the table. Tables that cannot work — overlapping slugs, collisions, patterns that
  match nothing — fail the build with their own diagnostics rather than producing a green build
  and a broken site.

### Changed

- The wasm URL now carries a content hash (`?v=…`), and the generated `nginx.conf` caches only
  versioned requests as `immutable`. A request without the query gets `no-cache`, so a
  hand-written `index.html` that boots without the shim is never pinned.
- `swiftwui build` splices its boot block into a marker region in `index.html`. A project
  scaffolded before this release has no marker and an inline boot script in `<body>`; the build
  replaces that script and says so, because leaving both would boot the app twice.

### Fixed

- `.notFound` pages no longer serve an HTTP 200 self-canonical with a full hreflang set, which
  could get an empty page indexed as a language alternate of a real one.
- The prerender's `noindex` meta is dropped when the client moves the URL.
- Route-table validation runs at app startup, not only under `ssg`.

## [0.8.0] - 2026-07-29

### Added

- **Localization.** Translations live in a `Locales/` folder inside the target that owns them —
  `Sources/<Target>/Locales/<tag>.json`, or `Sources/Locales/<tag>.json` for the `path: "Sources"`
  layout every `swiftwui init` template uses — with flat keys,
  `{name}` placeholders and ICU cardinal plurals — and `swiftwui l10n generate` compiles them
  into a committed `Generated/L10n.swift`: one function per key, parameters typed from the
  placeholders, CLDR plural rules emitted as Swift so wasm and native SSG agree without
  `Intl.PluralRules`. Declare the app's locales with one static property:

  ```swift
  static var localization: Localization? {
      Localization(catalog: L10n.self, default: .en, strategy: .pathPrefix())
  }
  ```

  `Text`, `Button`, `Img(alt:)`, `Input(placeholder:)`, `Textarea(placeholder:)`,
  `.attribute(_:_:)` and `.pageMeta(title:)` take a `LocalizedText` directly; everything else
  resolves through `@Environment(\.locale)` and `resolved(for:)`. Switching is
  `@Environment(\.setLocale)`, with `\.availableLocales` and `\.layoutDirection` alongside it.
  Resolution is exact tag → primary language → the app's default → the key. Every untrusted
  locale string the runtime reads — `localStorage`, the served `<html lang>`,
  `navigator.languages` — is validated against the declared set first; a URL prefix is matched
  against it exactly, and the `swiftwui_locale` cookie is read at the edge, never by the app.

  Three strategies decide how the locale is carried. `.pathPrefix()` puts every non-default
  locale under its tag (`/ru/about/`), prerenders one tree per locale and emits `hreflang`
  plus `x-default`. `.negotiated` keeps clean URLs and puts the locale in the output folder,
  with the edge choosing by cookie then `Accept-Language` — `ssg` writes
  `dist/swiftwui-site.json` and a matching `dist/nginx.conf`, `swiftwui serve` reproduces the
  rule locally, and a host that cannot rewrite (GitHub Pages, bare S3) reaches only the
  default locale. `.client` ships a single default-locale tree and switches after boot.
  An app that declares no `localization` is unaffected: every branch is inert and SSG output
  is byte-for-byte unchanged.

  New CLI: `swiftwui l10n generate [--check] [--allow-missing] [--target <name>]` and
  `swiftwui l10n add <tag>`. `build` and `ssg` regenerate first; `dev` watches
  `Locales/*.json`. `--check` is the CI gate. See <doc:Localization> and `Examples/Localized`,
  which prerenders itself per locale and takes `-Xswiftc -DNEGOTIATED` to compare dist layouts.

- **Tutorial chapter 20, "Speak every language."** Catalogs, codegen, `L10n` in a body, a
  switcher built from the environment, the three strategies, and what one build writes per
  locale.

- **`swiftwui init` scaffolds a starter catalog** at `Sources/Locales/en.json`, with
  `exclude: ["Locales"]` already declared. `swiftwui l10n add <tag>` seeds from an existing
  catalog and cannot create the first, so a fresh project starts one step further along.

### Changed

- **The scaffold's entry file is now `Sources/Entry.swift`, not `Sources/main.swift`.** A file
  named `main.swift` *is* top-level code, and `@main` cannot coexist with it — so a scaffolded
  project stopped compiling the moment its target gained a second source file, which
  `Generated/L10n.swift` is. Existing projects are unaffected; new ones get a target that can
  grow. Only the file name changed.

### Fixed

- **`ssg --path` wrote to the wrong folder in a localized app.** The scaffold templates and
  the <doc:Prerendering> example passed the requested path to `StaticSite.writeDocument`,
  discarding `RenderedPage.path` and `.subdir` — the two values that say where the render
  actually decided the document goes. Under `.negotiated` that is a different directory, and
  a `.staticTask` calling `setLocale` can move it under any strategy.

- **`swiftwui dev` ignored translation edits in a scaffolded project.** The watcher matched
  catalogs with `contains("/Locales/")`, but the directory walk yields paths relative to
  `Sources`, so a flat `Sources/Locales/en.json` arrived without the leading slash and never
  matched. The first build was correct and every later edit was silently dropped.

- **`.package(path: "../..")` broke every example and the tutorial site inside a git worktree.**
  A path dependency takes its package name from the directory, so `.product(package: "SwiftWUI")`
  named a package that did not exist and resolution failed before any source was read. The
  dependency now declares `name: "SwiftWUI"` explicitly.

## [0.7.0] - 2026-07-28

### Fixed

- **Breakpoint stacks cascaded backwards.** `StyleRegistry` ordered `@media` blocks by a
  lexicographic sort of the condition string, so `(min-width: 1024px)` was emitted before
  `(min-width: 640px)` — `'0'` sorts before `'6'`. At a wide viewport every `min-width` block
  matches, and since same-specificity class rules are decided by source order, the *smallest*
  breakpoint won. Any hand-written mobile-first stack built with `.media(.up(_:))` or
  `Rule(class:media:)` has been inverted since v0.3.0.

  Blocks are now ordered by width semantics: `min-width` ascending, then `max-width`
  descending, with non-width conditions (`orientation`, `prefers-color-scheme`) last so they
  can override a width rule. `Responsive<Value>` was never affected — it desugars to
  non-overlapping ranges, so only one ever matches.

### Added

- **`:focus-visible`** joins `hover`/`focus`/`active` on all three pseudo-class surfaces —
  `StyleProxy.focusVisible { }` inside a `Rule` or `Style` bundle, and `.focusVisible { }`
  chained on an `HTMLTag` or a `Tag`. Prefer it over `.focus` for focus rings: `:focus` also
  fires on a mouse click, which is why rings on clicked buttons read as a bug.

- **DocC articles for four releases that shipped without one** — <doc:Animations>,
  <doc:ResponsiveStyling> (both v0.3.0), <doc:DragAndDrop> (v0.5.0), <doc:Dependencies>
  (v0.6.0), plus <doc:Keyframes> and <doc:Deployment>. The catalog's Topics index was audited
  against the actual public surface and regrouped; `GettingStarted` had a stale reserved-names
  list and still implied a local path dependency was required.

- **The tutorial site grew from 13 chapters to 19** and was rebuilt on a new visual identity.
  New chapters cover responsive styling, bindings and the event vocabulary, drag and drop,
  keyframes and view transitions, data and dependency injection, and prerender policies —
  the feature areas the tutorial had never caught up with. It ships a real light/dark theme,
  a keyboard-operable quiz, WCAG-AA contrast throughout, and a phone layout that works;
  the previous one broke below the `1fr 460px` hero grid.

- **CSS `@keyframes`** — declare a keyframe animation as a value and attach it with a typed modifier:

  ```swift
  let spin = Keyframes("spin") {
      $0.from { $0.transform(.rotate(.deg(0))) }
      $0.to { $0.transform(.rotate(.deg(360))) }
  }

  Div().animation(spin, duration: .s(1), timingFunction: .linear, iterations: .infinite)
  ```

  The rule is emitted inside `@media (prefers-reduced-motion: no-preference)` by default; pass
  `respectsReducedMotion: false` to opt out. The emitted CSS name is hash-suffixed, so identical
  keyframes dedupe and two values sharing a name cannot overwrite each other. Distinct from the
  WAAPI `animation(_:value:)`, which stays the right tool for state-driven transitions.

- **View transitions** — opt-in, SwiftUI-flavored animated navigation and in-page transitions
  built on the browser's native View Transitions API:

  ```swift
  Router { /* … */ }.pageTransition(.fade)

  SearchForm().matchedTransition(id: "search-form")   // same id on the destination page
  ```

  Also `Route(transition:)` (destination-declared), `navigate(to:transition:)` (call-site
  explicit), and `withViewTransition { }` (in-page state changes — tabs, filters, expanding a
  card). Presets: `.fade`, `.slide(edge:)`, `.zoom(sourceID:)`, `.custom(old:new:)` (built from
  `Keyframes`). No behavior change for apps that don't opt in. See <doc:ViewTransitions> for
  the full precedence order, caveats, and fallback behavior.
- `NavigateAction` gained a second, additive initializer carrying the new ambient-transition
  channel, and `navigate(to:replace:transition:)` gained a `transition:` parameter; existing
  `NavigateAction { path, replace in … }` call sites still compile unchanged.
- `@Environment(\.navigate)` picks up the nearest ambient `.pageTransition` automatically;
  `@Dependency(\.navigate)` cannot (deliberately not render-tree-bound) — but a destination
  `Route(transition:)` still applies to it, same as any other call site.
- A FLIP-based fallback (`element.animate`) runs in browsers without the View Transitions API,
  forceable with `?swui-vt=flip` for manual testing; it is deliberately partial — only named
  elements travel, a name nested inside another name rides its ancestor's morph instead of
  animating independently, and sizing is faked with `scale` — see <doc:ViewTransitions> for the
  full list of degradations.
- **Behavior change:** the hydration SPI `_suppressTransitionsOnce` — which already suppressed
  enter transitions on the first flush after adopting prerendered HTML — now also suppresses
  exit transitions on that same flush, so a removed element can't leave behind an inert ghost
  still carrying its `view-transition-name`.
- **On-demand SSG (Phase A)** — per-route control over what gets prerendered, when, and what's
  in its `<head>`. See <doc:Prerendering> for the full picture.
  - **Prerender policies** — `Route.prerender(_:)` / `App.prerender`, resolved most-specific-first
    against `StaticSiteConfig.defaultPrerender`: `.never`, `.build`, `.onDemand`,
    `.paths { async throws -> [String] }`, `.allowingOnDemand()`, `.revalidate(_:)`.
  - **Kill-switch** — `StaticSiteConfig.prerenderEnabled`, readable from the `SWIFTWUI_PRERENDER`
    environment variable via `PrerenderSwitch.enabled(fromEnvironment:)`. Fail-closed: unset means
    on; `1`/`true`/`on`/`yes` (case-insensitive) mean on; every other non-empty value turns
    prerendering off.
  - **`.pageMeta(title:meta:links:structuredData:)`** — a head patch applied from inside the route
    subtree, after the `@State` graft and after `.staticTask` writes, unlike `Page.title` which
    the `Router` snapshots before either. Includes a JSON-LD channel
    (`<script type="application/ld+json">`, serialized through the same raw-text-sink escaping the
    hydration snapshot uses).
  - **Canonical synthesis** — a `<link rel="canonical">` is added to any prerendered page that
    declares none, when `StaticSiteConfig.siteURL` is set; no `siteURL` means no synthesis.
  - **`@RouteParam`** — typed, optional read access to a matched route's captures.
  - **`.onRouteChange(initial:)`** — pushes `RouteInfo` into a plain model class on mount and on
    every navigation, guaranteed to run before `.staticTask` loaders in the same pass.
  - **`staticTask(_:)` / `staticTask(id:)`** — a `.build`-policy `.task` variant: awaited during
    SSG before the page's HTML is taken, skipped on a hydrated client boot (the snapshot's `tasks`
    list covers it), and runs like a normal task on a cold client.
  - **Public `StaticSite.render(_:path:config:)`** — renders exactly one path and returns an
    explicit `RenderedPage` with a `.page` / `.redirect(to:permanent:)` / `.notFound` / `.error(_:)`
    outcome; `StaticSite.generate` is now built on top of it. Every generated app template's
    `main.swift` exposes this as `ssg --path <path>`, writing exactly one file.
  - **Sitemap generation** — `sitemap.xml` (indexed into `sitemap-N.xml` chunks past 45,000 URLs),
    written alongside a build when `siteURL` is set; only `.page`-outcome routes are listed.

### Changed

- **SPI:** `Runtime._collectRoutes()` now returns `[_CollectedRoute]` (pattern + the route's
  `Prerender?`, if any) instead of just patterns — a caller pattern-matching the old element type
  breaks at compile time, not silently at runtime.
- **SPI:** `RendererBackend` gained `setStructuredData(_ blocks: [String])`, with a default no-op
  implementation so existing conforming backends keep compiling. A custom backend that doesn't
  override it silently drops JSON-LD — `AdoptingBackend` and `DOMBackend` both forward it; a
  third-party backend needs to add its own override.

## [0.6.0] - 2026-07-20

### Added

- Lightweight dependency injection: `@Dependency(\.key)` resolvable anywhere
  (components, models, closures), `DependencyKey` with `liveValue`/`testValue`
  (auto test detection), scoped `withDependencies` and permanent
  `prepareDependencies` overrides. No external dependency.
- Built-in dependency keys `\.navigate`, `\.webStorage`, `\.logger` —
  programmatic navigation, imperative web storage (shared with `@AppStorage`
  reactivity), and a print-based logger. Runtime-backed after DOM boot via
  `Runtime.bootstrapDependencies()`; safe no-op/in-memory defaults elsewhere.
- Built-in dependency key `\.webSession` — network access for models and
  services outside the render tree (`WebSession.shared` passthrough,
  `.unsupported` in tests so unmocked requests fail loudly).

## [0.5.0] - 2026-07-16

Drag & drop and file input: HTML5 drag/drop for both OS files and typed
in-app payloads, plus a click-to-pick file dialog and a drag-reorderable
`ForEach`.

### Added

- `.draggable(_:isDragged:)` / `.dropDestination(for:allowedTypes:action:isTargeted:)`
  (`WebFile`) and `.dropDestination(for:action:isTargeted:)` (typed
  `DragPayload`) — HTMLTag drag sources and drop zones.
- `DragPayload` protocol (Codable-backed) for custom drag payloads; encoded
  into DOM attributes at render time and travels via the OS drag pasteboard
  — visible in the DOM, so never put secrets in a payload.
- `FileType` (UTType analog: `.image`, `.pdf`, `.zip`, …), `.fileImporter(
  isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)`
  for a click-to-pick file dialog, and typed file drop zones.
- `@Environment(\.dragSession)` — window-level signal for whether something
  is being dragged over the page right now, and whether it includes files.
- `.preventsAccidentalDropNavigation()` — guards against the classic
  drag-and-drop footgun where a file dropped outside any zone navigates the
  tab away.
- `ForEach.onMove(axis:perform:)` — drag-to-reorder rows with live preview
  (shifting siblings, dimmed source); `action` receives `(fromIndex,
  toInsertionOffset)`, not SwiftUI's `IndexSet` (would pull ~40 MB of
  Foundation/ICU into the wasm bundle for no benefit over HTML5's
  single-item drags).
- Reserved DOM contract: `swui:cmd:` property-command channel and
  `data-swui-*` attribute prefix — framework-owned, don't set by hand.

### Example

- `Examples/DragDrop` — acceptance app exercising every state above, plus
  `ACCEPTANCE.md` manual browser checklist.

## v0.4.0 — 2026-07-15

Typed style-modifier expansion: ~150 new typed CSS modifiers so real
web-apps rarely need the `.style("prop","val")` string escape. Purely
additive — no existing modifier changed; the escape hatch stays for the
deliberate long tail.

### Added — CSS value types

- `CSSLength` gained intrinsic sizing (`.minContent`, `.maxContent`,
  `.fitContent(_)`) and the mobile-safe viewport units
  (`.dvh/.svh/.lvh/.dvw/.svw/.lvw/.vmin/.vmax/.ch`).
- `Overflow` gained `.clip`; `Display` gained the table/`list-item`/
  `flow-root`/`inline-grid` family; `Cursor` gained ~28 keywords
  (resize directions, `grabbing`, `zoom-in/out`, …).
- New value types: `CSSAngle`, `CSSDuration`, `TimingFunction`, `Shadow`
  (box + text), `BlendMode`, `GridLine`, `BorderRadius` (per-corner),
  `FilterFunction`, `TransformFunction`, `CSSBackgroundImage` (linear/
  radial/conic gradients + `url()`), `ObjectPosition`, `BackgroundPosition`,
  `BackgroundSize`, `AspectRatio`, and dedicated `JustifyItems`/
  `JustifySelf`/`AlignContent`.

### Added — modifiers

- Layout/box: `overflowX/Y`, `objectFit`, `objectPosition`, `aspectRatio`,
  `visibility`, `inset`, logical `margin*/padding*/inset*` (inline/block),
  `min/maxInlineSize`, `min/maxBlockSize`, `rowGap`/`columnGap`/
  `gap(row:column:)`, `order`, `float`, `clear`, `isolation`.
- Flex/grid: `justifyItems`, `justifySelf`, `alignContent`, `placeContent/
  Items/Self`, `gridAutoFlow`, `grid{Column,Row}[Start/End]`, `gridArea`,
  `gridTemplateAreas`, `flex`, `flexFlow`.
- Typography: `whiteSpace`, `textTransform`, `textOverflow`, `lineClamp`,
  `textDecoration{Line,Color,Style,Thickness}`, `textIndent`, `textShadow`,
  `wordBreak`, `overflowWrap`, `verticalAlign`, `lineHeight(CSSLength)`,
  `listStyleType/Position`, `textWrap`, `fontVariant/Numeric`, `fontStyle`,
  `fontStretch`, `fontOpticalSizing`, `fontSmoothing`, `textAlignLast`,
  `textUnderlineOffset`, `wordSpacing`, `hyphens`, `direction`, `caretColor`,
  `textStroke`.
- Backgrounds/borders: `backgroundColor/Image/Repeat/Position/Size/
  Attachment/Origin/Clip/BlendMode`, per-side `border`/`borderWidth/Style/
  Color`, per-corner `borderRadius`, `outline{Width,Style,Color,Offset}`,
  `boxShadow(Shadow…)`, `borderCollapse`, `tableLayout`, `borderSpacing`.
- Effects/motion: `filter`, `backdropFilter`, `mixBlendMode`, `clipPath`,
  `transform`, `transformStyle`, `perspective`, `backfaceVisibility`,
  `willChange`, `transition(property:duration:timingFunction:delay:)` (typed;
  `cssTransition(String)` unchanged), `transitionDuration/TimingFunction/
  Delay`, `contentVisibility`, `containIntrinsicSize`.
- Interactivity/misc: `pointerEvents`, `userSelect`, `touchAction`,
  `scrollBehavior`, `scrollSnapType/Align/Stop`, `scrollPadding/Margin`,
  `overscrollBehavior[X/Y]`, `resize`, `appearance`, `accentColor`,
  `colorSchemeHint`, `break{Inside,Before,After}`, `scrollbarWidth`,
  `tapHighlightColor`, `fill`/`stroke`/`strokeWidth`, `columnCount/Width`,
  `counter{Reset,Increment,Set}`.

## v0.3.0 — 2026-07-15

Animations (WAAPI engine), responsive styling (breakpoints, container
queries, reactive viewport checks), release precompression + nginx config.

### Added — Release artifacts

- `swiftwui build -c release` now precompresses dist files: every
  compressible asset ≥ 1 KB (wasm/js/css/html/json/svg/…) gets `.gz`
  (gzip -9) and, when brotli is installed, `.br` (brotli -q 11) siblings —
  served for free via nginx `gzip_static`/`brotli_static`. Debug builds
  remove stale siblings; `swiftwui ssg` refreshes them after prerendering.
- `dist/nginx.conf` — generated ready-to-deploy server block (conf.d style):
  precompressed serving, wasm MIME for `instantiateStreaming`, SPA fallback
  with ssg prerender support, safe revalidation caching.
- Loud warning when `wasm-opt` (binaryen) is missing on release builds —
  PackageToJS silently ships a ~2.5× larger wasm without it.
- `nginx.conf` joined the reserved `public/` names; service-worker precache
  manifests exclude `.gz`/`.br` siblings and `nginx.conf`.

### Added — Responsive styling

- `@Environment(\.media)` — reactive `matches(_:)` viewport checks inside a
  component `body`, backed by `window.matchMedia` change events; defaults to
  `false` during SSR/hydration, so use it for structural branching, not styling.
- `Breakpoint` scale — `sm`/`md`/`lg`/`xl` at 640/768/1024/1280 px with
  `MediaQuery.up(_:)`/`.down(_:)` helpers.
- `MediaQuery` grew `minHeight`/`maxHeight`/`orientation(_:)` conditions and
  `and`/`or`/`not` combinators.
- `responsive(_:sm:md:lg:xl:)` / `Responsive<Value>` — per-breakpoint values
  desugared into non-overlapping media rules with a cascade-safe base.
- Container queries — `.containerType(_:name:)` / `.container(_:name:)`
  modifiers, `Rule(container:)`, and `container` blocks inside style proxies
  emit `@container` rules (names validated against CSS injection).

### Added — Animations

- `withAnimation(_:completion:)` — animates every state write inside the
  closure; `completion` fires once every animation it started has settled.
- `Animation` — springs solved to CSS `linear()` easing (`.spring(duration:bounce:)`,
  presets `.smooth`/`.snappy`/`.bouncy`), plus `.linear`/`.easeIn`/`.easeOut`/
  `.easeInOut`/`.timingCurve`, and `.delay`/`.speed`/`.repeatCount`/`.repeatForever`
  modifiers.
- `.animation(_:value:)` — scoped implicit animation that fires only when
  `value` changes.
- `AnyTransition` — `.opacity`, `.scale(anchor:)`, `.offset(x:y:)`, `.move(edge:)`,
  `.slide`, `.combined(with:)`, `.asymmetric(insertion:removal:)`, `.animation(_:)`,
  and the `.active([StyleDeclaration])` primitive — plus `.transition(_:)` to
  attach one to a view, with enter/exit playback, deferred DOM removal on
  exit, and bidirectional interruption (ghost adoption / enter cancellation).
- `.offset(x:y:)`, `.scaleEffect(_:anchor:)`, `.rotationEffect(_:anchor:)` —
  transform modifiers on individual `translate`/`scale`/`rotate` CSS channels
  (each animates and retargets independently).
- `\.accessibilityReduceMotion` environment key — mirrors
  `prefers-reduced-motion: reduce`; the engine automatically collapses every
  animation to duration ≈ 0 when it's on.
- DOMBackend animates via the Web Animations API (`element.animate`) — one
  call per changed style property, zero per-frame bridge traffic.

### Known limitations

- `.animation(_:value:)` drives enter transitions but does not drive removal
  transitions in v1 (removed identities never resolve under the wrapper).

### Changed

- **BREAKING:** the CSS shorthand modifier `.transition(String)` is renamed to
  `.cssTransition(String)` on both `Tag` and `HTMLTag` — `.transition(_:)` now
  refers exclusively to `AnyTransition`. `StyleProxy.transition(String)`
  (inside `.hover { }` / `.media { }` blocks) is unaffected.

## v0.2.0 — 2026-07-13

Browser APIs (`@AppStorage`/`@SceneStorage`, `colorScheme`, `WebSession`,
file selection), opt-in PWA mode, BridgeJS-backed DOM ops, `TagModifier`.

## v0.1.0 — 2026-07-06

First public release: core `Tag`/`@State` API, typed styles, routing,
full HTML + SSG/hydration, `swiftwui` CLI, tutorial site.
