# Swift 6.4 migration and library review — 26 September 2026

Branch: `claude/sleepy-heisenberg-bmbraf`; baseline: `b004a25`. Swift 6.4.0 was
released on 14 September 2026 (tag `swift-6.4.0-RELEASE`, WASM SDK
`swift-6.4.0-RELEASE_wasm`, SHA-256 `f07b7be3…aa86d` per swift.org).

**Verification status.** The review environment had no Swift toolchain and its
network policy blocked `download.swift.org`, so nothing in this change was
compiled or run locally. Every change was kept small, re-read against its call
sites, and covered by a regression test where the behavior is testable with
`MockBackend`/native code. The `Verify` workflow (native 6.4.0 + release CLI,
native 6.3.3 compatibility, WASM/browser matrix on 6.4.0) is the gate that has
to pass before merging.

## Toolchain migration

| Change | Where |
| --- | --- |
| Default toolchain 6.3.3 → 6.4.0 | `.swift-version`, `Scripts/install-swift-ci.sh`, `.github/workflows/verify.yml`, `WasmSDK.pinned` |
| WASM SDK bundle + checksum | CI env, scaffold/tutorial Dockerfiles (`WASM_SDK_URL`/`WASM_SDK_CHECKSUM` defaults, `swift sdk install --checksum`) |
| Docs and tutorial | README, DocC GettingStarted/Deployment, tutorial chapters 2/5/11, BrowserEvents, experiments |
| Compatibility | Manifest stays `swift-tools-version: 6.2`; new `native-compat-6-3` CI job builds and tests on 6.3.3 |
| SE-0506 | `Experiments/Swift64/run-se0506.sh` runs on 6.4.0 in CI as a non-gating step |

Bugs found while migrating:

- **`x.y` vs `x.y.0`.** 6.4.0 is the first x.y.0 release whose tag, and so SDK
  id, spells the patch component (`swift-6.4.0-RELEASE_wasm`), while
  `swift --version` may print `6.4`. `WasmSDK.preflight` compared strings
  verbatim and would have rejected a correct pair. It now compares with
  `WasmSDK.sameRelease` and, without `--swift-sdk`, prefers the installed web
  SDK built for the selected host.
- **Expired signing key.** The pinned "Swift 6.x Release Signing Key"
  (`52BB7E3D…981F`) expired on 16 September 2026, and swift.org's
  `all-keys.asc` still carries that expiry. `gpg --verify` exits 0 and reports
  `VALIDSIG` for expired keys, so the installer now also requires the signature
  timestamp to predate the key's expiry. 6.4.0 (14 September) and 6.3.3 pass;
  a later release signed with a refreshed key needs the pinned block updated,
  and the script says so.
- The installer's banner check matched `Swift version 6.3.3 (…)`; it now
  matches the release tag in parentheses, which is stable across both banners.

Not changed, deliberately: the `nonisolated deinit { }` requirement and its
guard test stay until a 6.4 Apple-target release build proves the SIL-inliner
crash (6.3.2/6.3.3) is gone; the WASM size budgets were measured with 6.3.3 and
may need re-measuring if the 6.4.0 fixtures move.

## Review method

Five read-only reviewers covered the render/state core, the DOM backend and
browser JavaScript, static generation/SEO/localization/routing, the
toolchain/CLI/dev server, and styles/HTML/fetch. Each finding below was
re-verified against the code before it was fixed or deferred.

## Fixed

| Severity | Finding | Fix |
| --- | --- | --- |
| High | Raw-string CSS (e.g. `fontFamily(String)`) could contain `</style>`; SSG wrote registry CSS into `<style>` guarded only by a debug `assert` | `HTMLEscaping.rawTextElement` at every `<style>` sink (`DocumentSerializer`, `BootSplice`) |
| High | `isSafeValue` allowed `;`, `)` and quotes, so `url(x); position: fixed …` smuggled declarations into registry rules and SSG `style=""` | Tokenizer-aware `isSafeValue` (no top-level `;`, balanced parens/quotes, no trailing `\`); inline declarations gated in `_AttributeBag.addStyle` |
| Medium | `@container` blocks sorted as strings: `(min-width: 1000px)` before `(min-width: 400px)` | Numeric container key in `StyleRegistry.text` |
| Medium | `Link("/docs#install")` click pushed `/docs` (fragment dropped); no-op on `/docs` | Fragment links are left to the browser |
| Medium | SSG wrote `/caf%C3%A9` to a literal `caf%C3%A9/` folder that decoding servers never look up | `StaticSite.outputFile` decodes each segment once |
| Medium | View-transition update after `unmount()` remounted the tree as a zombie | `mounted` guard in the update closure |
| Medium | `swiftwui build --out .` deleted the project's `index.html` and vendored shim | `DistLayout.requireSeparateOutput` |
| Low | `build`/`ssg` re-rooted absolute `--out` paths under the project | Absolute paths honored |
| Low | `ModifiedTag` ignored per-identity transaction overrides | Same save/apply/restore as component boundaries |
| Low | `ScrollRegistry.drain` ran commands in `Dictionary` order | Sorted by creation generation |
| Low | `SpringSolver` settle scan unbounded in duration | Duration clamped to 10 s |
| Low | `/\host` classified as an internal route | Treated as protocol-relative |
| Low | `styles.css` write failed when no document created `outDir` | `createDirectory` first |
| Low | Dev server spun on persistent `accept()` errors; `EINTR` truncated responses | Back-off and retry |

## Deferred (needs design or browser verification)

- **`ForEach.onMove` decoration lost on scoped re-render** (medium-high).
  `_SortableDecorator` mutates the row's first element after resolution; a
  stateful row component re-rendered as its own pass root loses `draggable`,
  `data-swui-drag*` and the drag handlers. Needs a stash/replay path like
  `_StyledTag` (`RetainedComponent.styleWrappers`) plus scoped-equivalence and
  browser tests.
- **Scaffolded `Dockerfile` does not produce a bootable `dist/` for apps with
  `bootUI`, workers or PWA** (medium): only `swiftwui build` copies
  `swiftwui-boot.js`/`swiftwui-worker.js` and generates `sw-assets.js`. The
  image should run the CLI instead of hand-assembling `dist/`.
- **SPA navigation to `path#fragment`.** The fix above falls back to a document
  load for cross-page anchors; a full solution keeps the fragment through
  `navigate` and scrolls after commit in `DOMBackend`.
- `Rule` bodies and element rule modifiers silently drop nested `.media { }` /
  `.container { }` blocks; `Rule(media:container:)` drops the media condition.
- Router guard and route builder closures run outside observation tracking
  (an `@Observable` session change does not re-run a guard until navigation).
- Observation `onChange` is willSet-time: a synchronous `scheduleMicrotask`
  renders the old value. Harmless with the shipped schedulers; SE-0506
  `.didSet` would remove it by construction.
- L10n: a placeholder named `locale`, or a key mapping to `supportedLocales`,
  generates Swift that does not compile.
- `.indexed` link validation rejects links to non-page assets (`/feed.xml`).
- `LocalePath.externalize` with an empty routes table emits `/ru/?q` where a
  table produces `/ru?q` (kept: the empty-table path is byte-stable by design).
- `DragPayload.dragContentType` for generic payload types contains spaces and
  breaks the accepts grammar; `Source(srcset:)` skips `sanitizeSrcset`;
  `cssNumber` renders NaN as `nan`; `OrderedStyle(parsing:)` splits inside
  quoted strings.

## Swift 6.4 opportunities

- **SE-0506 continuous observation** (`withContinuousObservationTracking`,
  `.didSet`, cancellable `~Copyable` token) is the one 6.4 feature with a clear
  payoff: it would replace the generation gate in `_ObservationTrackingGate`
  and remove the willSet ordering hazard. Start with cheap per-key reads
  (`EnvironmentSignals`, `StorageStore.Box`, `MediaMatchStore`) behind
  `#if compiler(>=6.4)`, after the CI probe passes, and measure against the
  current gate.
- Raising the manifest to `swift-tools-version: 6.4` is only worth it together
  with an API that needs it; today it would only drop 6.3.3 users.
