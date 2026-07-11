# Assets & Static Files

**Date:** 2026-07-11
**Status:** Approved
**Goal:** A `public/` directory convention that serves static assets (images,
video, fonts, favicon, robots.txt, …) identically in dev, build, SSG, and
serve — plus the head/style/tag APIs needed to actually use those assets from
Swift (`<link rel>`, `@font-face`, typed `Img` attributes).

## Scope

Two areas change:

1. **Toolchain** (`SwiftWUIToolchain` / CLI): `public/` serving and copying,
   MIME table, HTTP Range support, template scaffold.
2. **Framework** (`SwiftWUI` core): `LinkTag` head links, `FontFace` style
   helper, typed `Img` attributes.

Everything stays natively testable: toolchain via its existing unit tests,
framework via MockBackend + serializer tests. No new dependencies.

Out of scope: fingerprinting/cache-busting, image optimization/resizing, CDN
helpers, `Bundle.module` resource extraction to the browser, live
(state-driven) head updates between navigations (same rule as title/meta),
multi-range requests, font subsetting.

## 1. The `public/` convention

A project may contain a `public/` directory next to `Package.swift`. Its
contents map to the URL root:

```
MySite/
├─ Package.swift
├─ index.html
├─ public/
│  ├─ favicon.svg      → /favicon.svg
│  ├─ robots.txt       → /robots.txt
│  ├─ images/hero.webp → /images/hero.webp
│  └─ fonts/Inter.woff2 → /fonts/Inter.woff2
└─ Sources/
```

The directory is optional — absent `public/`, nothing changes anywhere.

**Reserved names.** The top-level entries `app`, `vendor`, `index.html`, and
`__swiftwui` collide with the framework's own output layout. A `public/`
containing any of them is a build error (`ToolchainError`) in
`swiftwui build` / `swiftwui ssg`, and a console warning in `swiftwui dev`.

**Extensionless files.** In dev, extensionless paths always fall through to
the SPA route fallback, so an extensionless public file (e.g. `CNAME`) is not
reachable in dev — but it is copied to `dist/`, which is where files like
`CNAME` matter. Documented, not worked around.

## 2. Dev server

New handler in the `DevSession` chain (DevSession.swift:34-64), placed after
the reserved routes (SSE hub, dev-client, wasi-shim, `/app/`) and before the
index.html SPA fallback:

- Request path contains a `.` in its last segment → look up the file under
  `public/` via the existing traversal-guarded `StaticFiles` machinery
  (HTTPServer.swift:196-216), serving **directly from the source directory**
  (no copy step — edits are visible on reload). Miss → 404, as today.
- Extensionless path → SPA fallback, as today. Routes always win.

This closes the documented gap in Sites/Tutorial/README.md:68-69
("swiftwui dev does not serve /assets/*") and gives dev/prod parity.

## 3. HTTPServer: MIME table + Range requests

Both fixes land in `HTTPServer.swift` and therefore apply to `swiftwui dev`
**and** `swiftwui serve` at once.

**MIME table** (HTTPServer.swift:37-48) gains: `gif`, `webp`, `avif`, `ico`,
`woff`, `woff2`, `ttf`, `otf`, `mp4`, `webm`, `mp3`, `ogg`, `wav`, `txt`,
`xml`, `webmanifest`, `pdf`. Unknown extensions keep falling back to
`application/octet-stream`.

**Range requests.** Static file responses advertise `Accept-Ranges: bytes`.
A single-range `Range: bytes=start-end` (including open `bytes=start-` and
suffix `bytes=-n` forms) returns `206 Partial Content` with `Content-Range`.
Out-of-bounds ranges return `416`. Multi-range and malformed headers are
ignored — full `200` response. This unbreaks video/audio seeking in dev and
serve.

## 4. Build and SSG copy

**`swiftwui build`** — `DistLayout.assemble` (WasmBuild.swift:49-66), after
the bundle copy: for each top-level child of `public/`, remove the existing
`dist/<name>` and copy. The dist directory itself is never wiped (it also
holds `app/` and `vendor/`). Reserved-name check runs first (§1).

**`swiftwui ssg`** — `SSGCommand` performs the same copy into `--out` after
the generator run. Both commands are self-sufficient; build/ssg order no
longer matters for assets.

**Tutorial migration.** `Sites/Tutorial` moves `Assets/` → `public/assets/`
(URLs `/assets/…` keep working unchanged) and `build-site.sh` drops its
manual `cp -R Assets/. dist/assets/` line.

## 5. Templates and docs

- `swiftwui init` (all three templates) scaffolds `public/` containing a
  small `favicon.svg`, and the template `index.html` references it.
- Docs updated: template README, `SwiftWUI.docc/GettingStarted.md`, and the
  Tutorial chapter covering project layout mention the convention in one
  short section each.

## 6. Head links: `LinkTag`

Mirror of `MetaTag` (Routing/Page.swift:3-36):

```swift
public struct LinkTag: Equatable {
    public let attributes: [String: String]   // names validated like MetaTag
    public static func icon(_ href: String, type: String? = nil) -> LinkTag
    public static func stylesheet(_ href: String) -> LinkTag
    public static func preload(_ href: String, as: PreloadKind, type: String? = nil) -> LinkTag
    public static func canonical(_ href: String) -> LinkTag
}
```

- `PreloadKind`: `font | image | style | script | fetch` (maps to the `as`
  attribute; `font` preloads additionally get `crossorigin`).
- Attribute names validated via `_AttributeBag.isValidName` (assert + drop),
  exactly like `MetaTag`.
- URL attributes (`href`) pass through `HTMLEscaping.sanitizeURL` at the
  serialization/application choke point — same policy as `Img.src`; a
  `javascript:` href is dropped.
- `Page` gains `var links: [LinkTag] { get }` with a default of `[]`;
  `PageHead` gains a `links` field.
- `RendererBackend` gains `setLinks(_: [LinkTag])` next to `setMetaTags`
  (RendererBackend.swift:29): managed replacement of `<link>` elements
  carrying the `data-swiftwui` marker; hand-written links in `index.html`
  are never touched. MockBackend records; DOMBackend applies; the SSG
  `DocumentSerializer` emits links into `<head>` for both static pages and
  the hydration document.
- Application is navigation-driven with the same caveat as title/meta
  (Page.swift:43-48): a mid-route `@State`-driven change is not re-applied
  until the next route pass.

## 7. Fonts: `FontFace`

```swift
FontFace(family: "Inter", src: "/fonts/Inter.woff2", format: .woff2,
         weight: 400...700, style: .normal, display: .swap)
```

- `format`: `woff2 | woff | truetype | opentype`; `style`: `normal | italic`;
  `display`: `auto | block | swap | fallback | optional`; `weight` accepts a
  single `Int` or a `ClosedRange<Int>` (variable fonts).
- Serializes to a complete `@font-face { … }` block. `family` is quoted and
  escaped; `src` goes through `HTMLEscaping.sanitizeURL`, and the serialized
  values respect the `CSSSanitize.isSafeValue` sink (StyleRegistry.swift:26-34).
- Declared as `static var fontFaces: [FontFace]` on the `App` protocol
  (default `[]`), plumbed exactly like `App.themes`: `Runtime.mount`
  registers each face via `StyleRegistry.registerRaw`
  (Runtime.swift:83, StyleRegistry.swift:70-72), so the block lands in both
  the SPA stylesheet and the SSG `styles.css` with zero new machinery.
  (Amended from the earlier `.fontFaces(_:)` modifier idea: the App-level
  static mirrors the existing `themes` plumbing one-to-one and needs no new
  resolve-time machinery; fonts are global like themes.)
- Escaping instead of asserting: `family` and `src` are emitted inside CSS
  quoted strings with `\` and `"` escaped; `src` additionally passes
  `HTMLEscaping.sanitizeURL` first. No debug-assert path — invalid input
  degrades to a harmless string, never a CSS breakout.

## 8. `Img` typed attributes

Additive parameters on `Img` (Tags.swift:543-552), all optional:

- `width: Int?`, `height: Int?` — layout-shift prevention;
- `srcset: String?`, `sizes: String?`;
- `loading: .lazy | .eager`;
- `decoding: .async | .sync | .auto`.

`src`/`srcset` URL handling stays on the existing `sanitizeURL` path.
Required `alt:` is unchanged.

## 9. Tests

Toolchain (native):
- MIME lookups for the new extensions.
- Range: `bytes=0-99`, `bytes=100-`, `bytes=-100`, out-of-bounds → 416,
  multi-range → full 200, no header → 200.
- Dev handler: dotted path hit / miss, extensionless falls to SPA fallback,
  traversal attempt rejected.
- DistLayout: `public/` children copied, re-run idempotent, reserved-name
  collision throws, absent `public/` is a no-op.
- Scaffolder: templates produce `public/favicon.svg`; no stray placeholders.

Framework (native):
- `LinkTag` statics produce expected attributes; invalid names dropped.
- MockBackend records `setLinks`; router pass applies page links; default
  `links` is `[]`.
- Serializer emits `<link>` in `<head>`; `javascript:` href dropped.
- `FontFace` serialization (all fields, weight range, quoting); registry
  dedupe on repeated registration; unsafe `src` dropped.
- `Img` new attributes serialize; omitted → absent from output.
