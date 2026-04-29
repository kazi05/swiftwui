# SwiftWUI Infrastructure & DevOps Audit

Date: 2026-04-28. Source-grounded; references `Sources/SwiftWUIDevServer/*`, `Sources/SwiftWUIInit/*`, `Package.swift`, `Examples/Counter/*`.

Severity: **P0** = blocks v0.1.0; **P1** = needed for v0.2.0; **P2** = polish.

---

## 1. Build pipeline (P0)

**Current.** `WASMBuilder.swift:24-30` shells out to `swift package --swift-sdk … js -c <debug|release> --product <target>`. `ProductionBuilder.optimizeWASM` calls `wasm-opt -Oz --strip-debug` only on `--optimize size|aggressive`. No `-wmo`, `-disable-reflection-metadata`, `-gnone`, no brotli (only gzip), no source map emission, no SRI hashing.

**Recommend.** Codify a single canonical release pipeline. Add to `WASMBuilder.swift` for `release` config; expose `Makefile` for non-Swift devs.

```makefile
# /Makefile
SDK ?= swift-6.2.3-RELEASE_wasm
TARGET ?= Counter
OUT ?= dist

.PHONY: dev build release test clean
dev:
	swift run swiftwui-dev dev --target $(TARGET) --port 8080

release:
	swift package --swift-sdk $(SDK) -c release \
	  -Xswiftc -Osize -Xswiftc -wmo \
	  -Xswiftc -gnone -Xswiftc -disable-reflection-metadata \
	  -Xlinker --strip-all \
	  js --product $(TARGET)
	wasm-opt -Oz --strip-debug --strip-producers --converge \
	  .build/plugins/PackageToJS/outputs/Package/$(TARGET).wasm \
	  -o $(OUT)/$(TARGET).wasm
	brotli -q 11 -k $(OUT)/$(TARGET).wasm
	gzip -9 -k $(OUT)/$(TARGET).wasm
	openssl dgst -sha384 -binary $(OUT)/$(TARGET).wasm | openssl base64 -A > $(OUT)/$(TARGET).wasm.sri

test:
	swift test --parallel
	swift test --enable-code-coverage

clean:
	rm -rf .build dist node_modules
```

Action: extend `ProductionBuilder.optimizeWASM` to always pass `-Xswiftc -wmo -Xswiftc -disable-reflection-metadata` in release; add brotli (`brotli -q 11`); emit `.sri` files.

---

## 2. Dev server architecture (P0)

**Current.** Worktree adds `swiftwui-dev` (Vapor 4) at `Sources/SwiftWUIDevServer/`. `DevServer.swift:36-43` serves index, `:47-74` serves PackageToJS output, `:77-83` opens `/_dev` WebSocket. `Examples/Counter/package.json` still uses Vite. Two stacks coexist.

**Recommend.** Remove Vite from new `swiftwui-init` templates (`Templates.packageJSON` line 121-139) — Vapor server replaces it for the framework's own examples and generated apps. Keep Vite as an optional adapter only for users who want HMR with their own JS toolchain. Reasons:

- Vite cannot natively rebuild Swift→WASM; it's just a static server with HMR. `swiftwui-dev` already does both.
- Vapor server gets us SSR-ready (Vapor backend can run the same `Tag` tree server-side later).
- Eliminates Node toolchain requirement.

Concrete steps:
1. Update `Templates.packageJSON` → drop, replace `Templates.indexHTML` with the dev server's auto-generated HTML.
2. `swiftwui-init` should print "swiftwui dev" instead of "npm run dev".
3. Document Vite as `--mode vite` opt-in for advanced users.

---

## 3. CLI tooling (P0)

**Current.** Two separate executables: `swiftwui-init` (scaffolding) and `swiftwui-dev` (dev/build). Inconsistent UX.

**Recommend.** Unify under single `swiftwui` binary with subcommands using `swift-argument-parser`.

```swift
// Sources/SwiftWUICLI/SwiftWUI.swift
import ArgumentParser

@main struct SwiftWUI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftwui",
        subcommands: [Init.self, Dev.self, Build.self, Test.self, Deploy.self, Doctor.self]
    )
}
```

Subcommands:
- `swiftwui init <name>` — current `SwiftWUIInit.main`
- `swiftwui dev [--target] [--port] [--open]` — current `swiftwui-dev dev`
- `swiftwui build [--target] [--optimize size|aggressive] [--out dist]`
- `swiftwui test` — `swift test --parallel` + headless WASM browser tests via Playwright
- `swiftwui deploy [--provider cloudflare|netlify|vercel|fly]`
- `swiftwui doctor` — checks SDK, fswatch, wasm-opt, brotli, JS runtime, prints diagnostic

Add `Package.swift` dependency `.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")`. Replace hand-rolled `parseArguments()` in `CLI.swift:29-81`.

Distribute pre-built binaries via Homebrew + GitHub Releases (see §5).

---

## 4. CI/CD (P0)

**Current.** No `.github/` directory. Zero CI.

**Recommend.** Three workflows.

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        os: [macos-15, ubuntu-24.04]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: SwiftyLab/setup-swift@latest
        with: { swift-version: "6.2.3" }
      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            .build
            ~/Library/Developer/Xcode/DerivedData
            ~/.cache/org.swift.swiftpm
          key: spm-${{ matrix.os }}-${{ hashFiles('Package.resolved') }}
      - run: swift test --parallel --enable-code-coverage
      - uses: codecov/codecov-action@v4

  wasm-build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Cache SwiftWasm SDK
        uses: actions/cache@v4
        with:
          path: ~/.swiftpm/swift-sdks
          key: wasm-sdk-6.2.3
      - run: |
          swift sdk install \
            https://github.com/swiftwasm/swift/releases/download/swift-6.2.3-RELEASE/swift-6.2.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip
      - name: Build all examples
        run: make -C Examples/Counter release
      - name: Size budget
        run: |
          SIZE=$(stat -c%s dist/Counter.wasm.br)
          [ $SIZE -lt 512000 ] || exit 1

  lint:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: swift format lint --recursive --strict Sources Tests
```

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ["v*"]
jobs:
  release:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: swift build -c release --product swiftwui --arch arm64 --arch x86_64
      - uses: softprops/action-gh-release@v2
        with:
          files: .build/apple/Products/Release/swiftwui
```

```yaml
# .github/workflows/docs.yml — DocC + guides → GitHub Pages
name: Docs
on: { push: { branches: [main] } }
jobs:
  docs:
    runs-on: macos-15
    permissions: { pages: write, id-token: write }
    steps:
      - uses: actions/checkout@v4
      - run: swift package generate-documentation --target SwiftWUI --output-path ./docs-build
      - uses: actions/deploy-pages@v4
```

---

## 5. Distribution (P1)

**Current.** SPM only. Local-path dep in generated `Package.swift` (`Templates.swift:23`).

**Recommend.**
- **Homebrew tap** `homebrew-swiftwui/swiftwui.rb` — installs prebuilt `swiftwui` binary from GitHub Releases.
- **Docker image** `ghcr.io/<org>/swiftwui-builder:6.2.3` — Swift + SwiftWasm SDK + wasm-opt + brotli, used by users' CI without setup overhead.
- **npm wrapper** `@swiftwui/cli` — postinstall downloads correct binary; lets JS-first teams `npx swiftwui dev`.
- **SDK pin file** `.swift-sdk-version` in repo root (`swift-6.2.3-RELEASE_wasm`); `swiftwui doctor` validates.

```ruby
# Formula/swiftwui.rb
class Swiftwui < Formula
  desc "Swift web UI framework CLI"
  homepage "https://github.com/AkhtarGadique/SwiftWUI"
  version "0.1.0"
  if Hardware::CPU.arm?
    url "https://github.com/.../v0.1.0/swiftwui-macos-arm64.tar.gz"
    sha256 "..."
  end
  depends_on "binaryen"
  depends_on "brotli"
  def install; bin.install "swiftwui"; end
end
```

---

## 6. Caching (P1)

**Current.** None.

**Recommend.**
- CI: cache `.build/`, `~/.swiftpm/swift-sdks`, `~/.cache/org.swift.swiftpm`, `node_modules` (key: `Package.resolved` hash).
- Local: `sccache` for Swift compiler; doc in `swiftwui doctor`.
- WASM SDK cache key: `swift-${VERSION}-RELEASE_wasm` — never re-download.
- Vite cache (if kept): `.vite` directory in `.gitignore`.

```yaml
- uses: actions/cache@v4
  with:
    path: |
      .build
      ~/.swiftpm/swift-sdks
      Examples/*/node_modules
    key: build-${{ runner.os }}-${{ hashFiles('Package.resolved', '**/package-lock.json') }}
    restore-keys: build-${{ runner.os }}-
```

---

## 7. Hot reload (P0)

**Current.** `FileWatcher.swift:28-55` (fswatch) → `DevServer.rebuild()` (DevServer.swift:105-123) → full `swift package js` rebuild → WebSocket `{"type":"reload"}` → `location.reload()` (HTMLTemplate.swift:62-65). Full page reload, state lost, build is multi-second.

**Recommend.** Three-stage upgrade:

1. **Better protocol now** (P0). Send manifest with hashes; client compares and only reloads if `.wasm` actually changed (not just `.js` glue):
```js
// HTMLTemplate.devClientScript
ws.onmessage = e => {
  const {type, files} = JSON.parse(e.data);
  if (type === 'reload') location.reload();
  if (type === 'css') applyCSSPatch(files);  // future
};
```
2. **Incremental rebuilds** (P1). `swift package js` already incremental via SPM. Measure: warm rebuild after touching one file in `Counter` should be < 2s. If not, root-cause in PackageToJS plugin.
3. **State preservation** (P2). Store `@State` snapshots in `sessionStorage` keyed by component path before reload; rehydrate on mount. Requires `Codable` constraint on `StateStorage` values. Ship behind `--preserve-state` flag.

Add file-change debounce window already exists (`FileWatcher.swift:10` — 0.3s). Increase to 0.5s after first reload to coalesce save bursts.

---

## 8. Source maps (P1)

**Current.** `-c debug` produces DWARF in `.wasm`; `ProductionBuilder` strips it. No browser-debuggable source map exposed.

**Recommend.** SwiftWasm 6.x supports DWARF in WebAssembly. Chrome with the C/C++ DevTools extension can step through Swift sources.

- Dev mode: keep DWARF (`-c debug` already does), don't strip. Verify in `WASMBuilder` — currently fine.
- Add `--source-map` flag to `swiftwui build`: copy `Sources/` into `dist/_sources/`, emit `Counter.wasm.map` referencing them.
- Document Chrome extension install in `swiftwui doctor`.
- For `wasm-opt`: pass `-g` in dev path (currently only release uses opt). Don't run wasm-opt in dev.

---

## 9. Error overlay (P1)

**Current.** `HTMLTemplate.swift:85-93` already injects an overlay for build errors. Good. Does NOT capture runtime Swift fatal errors.

**Recommend.** Extend dev client script to catch:
1. `window.onerror` / `unhandledrejection` → overlay.
2. WASM trap (`RuntimeError`): patched stack trace through DWARF.
3. SwiftWasm-specific: `wasi.proc_exit` non-zero exit → overlay with stderr.

```js
window.addEventListener('error', e => showErrorOverlay(`${e.message}\n${e.error?.stack||''}`));
window.addEventListener('unhandledrejection', e => showErrorOverlay(`Promise: ${e.reason}`));
```

Build-error overlay already styled (HTMLTemplate.swift:89). Add "Dismiss" button + click-to-copy stack trace.

---

## 10. Production hosting (P1)

**Current.** No deployment story.

**Recommend.** Static hosting matrix:

| Provider | Why | Config |
|---|---|---|
| Cloudflare Pages | Brotli native, free, edge cache, easy preview deploys | `wrangler.toml` + `_headers` |
| Netlify | Branch deploys, forms | `netlify.toml` |
| Vercel | Edge functions if going hybrid | `vercel.json` |
| Fastly Compute@Edge | If serving SSR'd SwiftWUI from edge later | `fastly.toml` |

Critical headers:

```
# dist/_headers (Cloudflare/Netlify format)
/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=31536000, immutable
  Cross-Origin-Resource-Policy: same-origin
/*.js
  Content-Type: application/javascript
  Cache-Control: public, max-age=31536000, immutable
/*
  Cache-Control: public, max-age=0, must-revalidate
  Strict-Transport-Security: max-age=63072000
  Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'
```

Hash-fingerprint output filenames in production (`Counter.${sha256:8}.wasm`) so `immutable` is safe. Add to `ProductionBuilder.build()`.

`swiftwui deploy --provider cloudflare` should run `wrangler pages deploy dist`.

---

## 11. Vapor SSR deployment (P2)

**Current.** Vapor only used as dev server. No SSR yet.

**Recommend.** Pick **Fly.io** as default for v1: native Linux Swift, regional edge, no Docker registry friction. Backup: AWS App Runner / Railway. Avoid Heroku (deprecated stack).

```toml
# fly.toml
app = "swiftwui-app"
[build]
  dockerfile = "Dockerfile"
[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  min_machines_running = 0
[[vm]]
  memory = "512mb"
  cpu_kind = "shared"
```

`swiftwui deploy --provider fly` wraps `flyctl deploy`.

---

## 12. Docker (P2)

**Current.** None.

**Recommend.** Multi-stage: build WASM client + Linux Vapor binary; runtime stage serves both.

```dockerfile
# Stage 1: WASM client
FROM swift:6.2.3-jammy AS wasm-builder
RUN apt-get update && apt-get install -y curl ca-certificates binaryen brotli
RUN swift sdk install https://github.com/swiftwasm/swift/releases/download/swift-6.2.3-RELEASE/swift-6.2.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip
WORKDIR /src
COPY . .
RUN swift package --swift-sdk swift-6.2.3-RELEASE_wasm \
    -c release -Xswiftc -Osize -Xswiftc -wmo \
    -Xswiftc -disable-reflection-metadata js --product Counter
RUN wasm-opt -Oz --strip-debug \
    .build/plugins/PackageToJS/outputs/Package/Counter.wasm -o /dist/Counter.wasm \
    && brotli -q 11 /dist/Counter.wasm

# Stage 2: Vapor server
FROM swift:6.2.3-jammy AS server-builder
WORKDIR /src
COPY . .
RUN swift build -c release --product SwiftWUIServer --static-swift-stdlib

# Stage 3: runtime
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
COPY --from=server-builder /src/.build/release/SwiftWUIServer /usr/local/bin/
COPY --from=wasm-builder /dist /app/Public
WORKDIR /app
EXPOSE 8080
CMD ["SwiftWUIServer", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
```

Image size target: <150 MB.

---

## 13. Performance budgets (P1)

**Current.** None. Performance audit (consilium 03) shows debug WASM at 61 MB.

**Recommend.** Lighthouse CI as PR gate, plus raw size budget.

```yml
# .lighthouserc.json
{
  "ci": {
    "collect": { "url": ["http://localhost:8080"], "numberOfRuns": 3 },
    "assert": {
      "assertions": {
        "first-contentful-paint": ["error", {"maxNumericValue": 1500}],
        "interactive": ["error", {"maxNumericValue": 3000}],
        "total-byte-weight": ["error", {"maxNumericValue": 614400}]
      }
    }
  }
}
```

CI step:
```yaml
- run: |
    swiftwui build --target Counter --optimize aggressive
    npx -y serve dist -l 8080 &
    npx -y @lhci/cli autorun
- name: WASM size budget
  run: test $(stat -c%s dist/Counter.wasm.br) -lt 512000
```

Track size over time: post bundle-size diff on PRs (`pkgsize`).

---

## 14. Observability (P2)

**Current.** None.

**Recommend.**

Client (production):
- Sentry SDK loaded at HTML head; capture WASM traps via `window.onerror`. Source maps uploaded by `swiftwui deploy`.
- Web Vitals → CF Analytics or Sentry Performance.

Server (Vapor SSR):
- OpenTelemetry: `swift-otel` package, OTLP/HTTP to a free Honeycomb/Grafana Cloud tier.
- Structured logging via Vapor's `Logger` → JSON to stdout.
- `/health` and `/metrics` (Prometheus) endpoints.

Sentry init snippet (P2 stub for `Templates.indexHTML`):
```html
<script src="https://js.sentry-cdn.com/.../bundle.min.js"
  integrity="sha384-..." crossorigin="anonymous"></script>
```

---

## 15. Versioning (P1)

**Current.** No tags. 9 modules in single `Package.swift` with no version metadata.

**Recommend.** **Single semver across all modules** (lockstep) for v0.x and v1.x. Splitting versions adds compatibility-matrix overhead and these modules tightly couple (`SwiftWUIRuntime` depends on every other). Reconsider only at v2 if the umbrella becomes a heavy dep.

- `0.x` = pre-stable; minor bumps allowed to break.
- Tag `v0.1.0`, `v0.2.0`, … on main.
- `Package.swift` users: `.package(url: …, from: "0.1.0")` semver-compatible.
- ABI stability: not a concern (source-only Swift, no XCFrameworks).

---

## 16. Documentation pipeline (P1)

**Current.** Docs live in `docs/plans/` (design notes). No public site.

**Recommend.**
- API reference: **DocC** generated from sources. `swift package generate-documentation --target SwiftWUI`. Hosted on GitHub Pages.
- Guides + tutorials: **Docusaurus** (Markdown, search built-in, MDX for live examples). Hosted on Cloudflare Pages.
- Combined site: `docs.swiftwui.dev` with subdomains `api.docs.swiftwui.dev` (DocC).
- Auto-deploy from `main` (workflow in §4).

```bash
# scripts/build-docs.sh
swift package generate-documentation \
  --target SwiftWUI \
  --output-path ./docs-site/static/api \
  --transform-for-static-hosting \
  --hosting-base-path /api
cd docs-site && npm run build
```

---

## 17. Examples gallery (P2)

**Current.** Only `Examples/Counter`. In monorepo.

**Recommend.** Keep in monorepo (single PR can touch framework + example). Add:
- `Examples/Counter` (existing) — minimal
- `Examples/Todo` — list reconciler stress
- `Examples/Blog` — routing, async data
- `Examples/Dashboard` — charts, large lists, demonstrates perf

Each example: own `Package.swift`, README with screenshot, deployed to `examples.swiftwui.dev/<name>` via CF Pages preview-per-PR.

CI matrix builds all examples in parallel.

---

## 18. Release automation (P1)

**Current.** Manual.

**Recommend.** **release-please** (Google) — works with Swift via custom config; generates `CHANGELOG.md`, GitHub releases, version bumps from Conventional Commits.

```yaml
# .github/workflows/release-please.yml
on: { push: { branches: [main] } }
jobs:
  release-please:
    runs-on: ubuntu-24.04
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          release-type: simple
          package-name: swiftwui
```

Convention: PRs labeled `feat:` / `fix:` / `chore:` / `BREAKING CHANGE:`. release-please opens a "Release PR" that, when merged, tags + publishes.

Couple with §4 release.yml to upload binaries on tag.

---

## 19. Security (P1)

**Current.** No SDK pin, no SBOM, no SRI on served WASM.

**Recommend.**

- Pin SwiftWasm SDK URL + SHA in `.swift-sdk-version` and verify in CI before install.
- `swift package show-dependencies` snapshot in CI; alert on Vapor/JavaScriptKit major bumps.
- **Dependabot** for `Package.resolved` and Actions versions.
- **Subresource Integrity**: `ProductionBuilder` already needs SRI emission (§1). Inject into `HTMLTemplate.productionHTML`:
  ```html
  <script type="module" src="./Counter.js" integrity="sha384-..." crossorigin="anonymous"></script>
  ```
- **GHSA scanning**: enable GitHub Advanced Security on the repo.
- **OSV-Scanner** in CI.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - { package-ecosystem: swift, directory: "/", schedule: { interval: weekly } }
  - { package-ecosystem: github-actions, directory: "/", schedule: { interval: weekly } }
```

---

## 20. Telemetry opt-in (P2)

**Current.** None.

**Recommend.** Mirror Next.js model. `swiftwui-init` on first run prompts:

```
SwiftWUI collects anonymous usage data to help us improve. Opt out:
  swiftwui telemetry disable
Read more: https://swiftwui.dev/telemetry
```

Implementation:
- Random UUID stored at `~/.config/swiftwui/telemetry.json`.
- Events: `cli.invocation` with `{cmd, duration, success, swift_version, os}` only. No paths, no source.
- Endpoint: Cloudflare Worker → ClickHouse Cloud free tier.
- Easy opt-out: `swiftwui telemetry disable` writes `enabled:false`.
- Respect `DO_NOT_TRACK=1` env var.

```swift
// Sources/SwiftWUICLI/Telemetry.swift
struct Telemetry {
    static func track(_ event: String, _ props: [String: String]) {
        guard isEnabled, ProcessInfo.processInfo.environment["DO_NOT_TRACK"] != "1" else { return }
        // fire-and-forget POST, 200ms timeout, never block CLI
    }
}
```

Disabled by default for v0.x; enable post-1.0 with prominent disclosure.

---

## Priority summary

**P0 (block v0.1.0):** §1 build pipeline, §2 unify dev server, §3 unified CLI, §4 CI, §7 hot-reload protocol.

**P1 (v0.2.0):** §5 distribution (Homebrew + Docker), §6 caching, §8 source maps, §9 runtime error overlay, §10 hosting, §13 perf budgets, §15 versioning, §16 docs, §18 release automation, §19 security.

**P2 (polish):** §11 Vapor SSR deploy, §12 multi-stage Docker, §14 observability, §17 examples gallery, §20 telemetry.

## Top three actions this week

1. Add `Makefile` + finalize `ProductionBuilder` flags (`-wmo`, `-disable-reflection-metadata`, brotli, SRI). Unblocks the perf wins from consilium 03.
2. Land `.github/workflows/ci.yml` with macOS+Linux matrix, SPM cache, WASM SDK cache, Lighthouse budget. Catches regressions before they land.
3. Replace hand-rolled CLI (`CLI.swift:29-81`) with `swift-argument-parser` and merge `swiftwui-init` + `swiftwui-dev` into one `swiftwui` binary. Enables Homebrew + npm distribution.
