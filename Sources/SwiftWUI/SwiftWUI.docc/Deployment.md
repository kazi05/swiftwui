# Deployment

What `swiftwui build` puts in `dist/`, what a release build adds on top, and
what a server has to do to serve the result.

## Overview

A built SwiftWUI site is a directory of static files. There is no runtime
server component — `dist/` holds the wasm bundle, the entry `index.html`, the
vendored WASI shim, your `public/` assets, and whatever `swiftwui ssg`
prerendered. Any host that serves files with the right MIME types and a
directory index can serve it.

Two commands produce that directory, and the order matters:

```sh
swiftwui build        # wasm bundle + dist/ layout (release by default)
swiftwui ssg          # prerender routes into the same dist/
swiftwui serve dist   # preview it locally on 127.0.0.1:8080
```

### What `swiftwui build` assembles

`swiftwui build` runs the JavaScriptKit PackageToJS plugin against the
detected WASM SDK, then lays out `dist/`:

- `dist/app/` — the PackageToJS bundle, copied verbatim (`index.js` plus the
  `.wasm` module).
- `dist/index.html` — a copy of the project's own `index.html`. The build
  fails if the project root has none; that file is the entry document, not a
  generated one.
- `dist/vendor/wasi-shim/` — the project's checked-in `vendor/wasi-shim` when
  it exists, otherwise the copy bundled with the CLI. Scaffolded projects
  check it in so they build offline and inside containers.
- every top-level entry of `public/`, copied to the `dist/` root.

The SDK is auto-detected: the pinned `swift-6.3.3-RELEASE_wasm` if
`swift sdk list` reports it, otherwise the first non-embedded id containing
`wasm`. `--swift-sdk <id>` overrides. `--out <dir>` moves the output
directory; `-c debug` builds unoptimized.

The wasm build uses its own `.build-wasm` scratch directory rather than the
`.build` that `swift build`, `swift test`, and `swift run` use. Mixing a
native build and a wasm build under one `.build` corrupts SwiftPM's
`.build/debug` triple symlink, and the next native `swift run` fails with
"No target named …-debug.exe". Keep using the CLI and you never see it.

### Build first, then prerender

`swiftwui ssg` runs your app's native `ssg` entry point (`swift run <product>
ssg --out dist`), which writes `dist/index.html` for `/` and
`dist/<route>/index.html` for every other prerendered path. Then it re-copies
`public/`, regenerates `dist/sw-assets.js` if the project opted into PWA
mode, and refreshes the precompressed siblings if the directory already has
any.

Run it after `swiftwui build`, never before. `build` overwrites
`dist/index.html` with the project's plain entry document, so a prerendered
root page produced first is thrown away. The compression refresh has the same
dependency in reverse: `ssg` only re-runs compression when framework-owned
`.gz`/`.br` files are already present, which is what a release `build` leaves
behind. Out of order you get a stale `index.html.gz` shadowing fresh markup
under `gzip_static`.

The CLI's `ssg` subcommand passes only `--out` and `--product`. The other
flags in the scaffolded entry point — `--static`, `--path`, `--no-prerender`
— belong to your app, so invoke it directly for those: `swift run MyApp ssg
--path /about`. See <doc:Prerendering>.

Set `siteURL` in that entry point when you know the deployed origin — it
gates both sitemap generation and absolute canonical synthesis:

```swift
let report = try await StaticSite.generate(MyApp.self,
    config: .init(outDir: out, mode: mode, siteURL: "https://example.com"))
print("generated \(report.pages.count) pages, \(report.sitemapFiles.count) sitemap file(s)")
```

### Release artifacts

`swiftwui build` defaults to `-c release`, and a release build adds two
things to `dist/`.

**Precompressed siblings.** Every file whose extension is in the allowlist
(`wasm`, `js`, `mjs`, `css`, `html`, `json`, `svg`, `txt`, `xml`, `map`,
`ts`, `webmanifest`) and is at least 1 KB gets a `.gz` sibling (`gzip -9`,
no name/timestamp header, so output is byte-identical across runs) and, when
brotli is installed, a `.br` sibling (`brotli -q 11`). They are regenerated
unconditionally on every release build — a few wasted seconds beats a stale
sibling served in place of a fresh file.

Compression never fails a build. No `gzip` on `PATH` prints a warning and
ships uncompressed; no `brotli` prints a hint and ships gzip only.

Ownership is decided by the base name's extension: `index.html.gz` is
framework-owned, a `foo.tar.gz` you copied from `public/` is not (`tar` is
not in the allowlist) and is never touched. Framework-owned siblings whose
base file disappeared are deleted, and a debug build removes all of them so a
leftover release `.gz` can't shadow a fresh debug file.

**`dist/nginx.conf`.** A ready-to-deploy `conf.d`-style server block with
`gzip_static on`, a commented `brotli_static on` (it needs the `ngx_brotli`
module), a runtime `gzip` fallback, `Cache-Control: no-cache`, an explicit
`application/wasm` type for `.wasm`, `try_files $uri $uri/ /index.html`, and
`location = /nginx.conf { return 404; }` so the file doesn't serve itself out
of the deployed root. Its `root` is a placeholder (`/var/www/app`) — set it
before deploying.

A localized site using `.negotiated` gets a different location block —
`map` blocks that read the cookie and `Accept-Language`, a `Vary` header, and a
`try_files` chain that looks inside the locale folders. See <doc:Localization>.

`dist/` is build output. `dist/nginx.conf` is rewritten on every release
build, so edits to it are lost; keep a customized copy outside `dist/`.

**The wasm-opt warning.** Release builds probe for `wasm-opt` (binaryen) and
print a warning block when it's missing, then build anyway. Without it
PackageToJS ships a roughly 2.5× larger module (≈22 MB against ≈9 MB). It is
a warning, never a build failure — install `binaryen` before measuring
anything about bundle size.

### Reserved names in `public/`

Top-level entries of `public/` land at the `dist/` root, so a handful of
names would shadow the framework's own layout. These are rejected:

`app`, `vendor`, `index.html`, `styles.css`, `__swiftwui`, `sw-assets.js`,
`nginx.conf`, `swiftwui-site.json`

A collision is a hard error from both `build` and `ssg`, with the offending
names listed — it fails rather than silently overwriting the bundle
directory. The check is top-level only: `public/assets/index.html` or
`public/legacy/app/` are fine, since only the first path component competes
with the dist layout.

### Docker

`swiftwui init` scaffolds two Dockerfiles.

`Dockerfile` builds `dist/` in a pinned toolchain container and exports it
with a `scratch` stage, so the output is the directory itself rather than an
image:

```sh
docker build --build-arg WASM_SDK_URL=<artifactbundle url> \
             --output type=local,dest=dist-docker .
```

The SDK URL must match the toolchain in the base image exactly — the build
stage installs it with `swift sdk install`, builds the wasm bundle, copies
`app/`, `vendor/`, and `index.html` into `dist/`, then runs `swift run <App>
ssg --out dist`.

Two constraints on it. The SwiftWUI dependency has to be reachable from
inside the build context. The scaffold's default is the published git URL,
which the container fetches like any other package, so this works out of the
box; a project created with `swiftwui init --swiftwui-path <dir>` instead
carries an absolute path dependency pointing outside the build context,
which Docker cannot see — switch it to a git URL or vendor the framework
before building that way. And this Dockerfile
drives SwiftPM directly rather than going through the CLI — it builds into
the default `.build`, and it produces no precompressed siblings and no
`dist/nginx.conf`, because those are `swiftwui build -c release` steps.
Treat it as a reproducible wasm build, not as a substitute for the release
pipeline.

`Dockerfile.deploy` serves a locally built `dist/` from `nginx:alpine`:

```sh
swiftwui build && swiftwui ssg
docker build -f Dockerfile.deploy -t myapp . && docker run -p 8080:80 myapp
```

It copies the **project-root** `nginx.conf` — the scaffolded, user-owned one
— to `/etc/nginx/conf.d/default.conf`, not the generated `dist/nginx.conf`.
That root config pins the wasm MIME type and `Cache-Control: no-cache` and
falls back with `try_files $uri $uri/index.html /index.html`, but it has no
`gzip_static`, so the `.gz`/`.br` files a release build produced go unused,
and it has no rule hiding `/nginx.conf`, so the generated config is reachable
under that path in the served root. It also has no `/app/` wasm block, so a
build that stamps `?v=` on the binary gets none of the immutable caching that
buys — the root config still assumes every asset must revalidate. If you want
the release serving behavior, copy `dist/nginx.conf` in instead:

```dockerfile
COPY dist/nginx.conf /etc/nginx/conf.d/default.conf
```

Both files are yours to edit. The scaffold points at the project-root one
because `dist/nginx.conf` is build output, rewritten on every release build.

### Hosting on a static host or CDN

The requirements are short, and every one of them is a real failure mode:

- **`application/wasm` for `.wasm`.** `WebAssembly.instantiateStreaming`
  rejects any other content type, and distro `mime.types` before nginx
  1.21.4 have no entry for it. This is why the generated config sets the type
  explicitly instead of trusting the defaults.
- **Directory indexes.** Prerendered pages are written as
  `dist/about/index.html`, so `/about` has to resolve to that file. A host
  that serves directories only at `/about/` sends every prerendered page
  through a redirect.
- **SPA fallback to `/index.html`.** Routes that were never prerendered
  (anything under `.prerender(.never)`, or the whole site with prerendering
  off) exist only after the wasm app boots, so an unknown path must return
  the entry document rather than a 404 page. The cost is that genuinely
  missing URLs answer 200 with the shell; if soft 404s matter for your
  indexing, prerender a real 404 document and route the fallback to it.
- **Content encoding.** Precompressed siblings are only used by servers that
  look for them — nginx `gzip_static`/`brotli_static`, Caddy's
  `precompressed`. Hosts that compress responses themselves ignore the files
  entirely; they are inert extra bytes in the upload, and `-c debug` (or
  deleting them) drops them.
- **Cache headers.** Bundle filenames are not content-hashed. A long
  `max-age` on `/app/index.js` or the `.wasm` serves the previous deploy
  until it expires. Revalidate (`no-cache` plus ETag) or deploy under
  versioned paths and set `immutable` there. A build that emits boot UI is
  the one exception: it names the wasm `?v=<hash>` and the generated config
  pins only versioned requests. A CDN that strips query strings turns that
  back into plain revalidation — see <doc:BootLoading>.
- **Root-path deploys only.** The scaffolded `index.html` resolves the shim
  and the bundle through absolute URLs (`/vendor/wasi-shim/index.js`,
  `/app/index.js`), and hydrate mode's default `wasmScriptPath` is
  `/app/index.js`. Serving the site from a subdirectory means editing
  `index.html` and passing a matching
  `StaticSiteMode.hydrate(wasmScriptPath:)`. Prerendered pages already
  reference `styles.css` relatively, so that part survives the move on its
  own.

Nothing above needs cross-origin isolation headers — SwiftWUI's wasm module
uses no `SharedArrayBuffer`.

### PWA precache and the deployed files

When a project opted into PWA mode, `build` and `ssg` regenerate
`dist/sw-assets.js` — a SHA-256 precache manifest of the deployed files. It
deliberately excludes `sw.js` and `sw-assets.js` themselves, `nginx.conf`,
`swiftwui-site.json`,
generated `sitemap.xml` / `sitemap-N.xml`, dotfiles, framework-owned
`.gz`/`.br` siblings, and every `index.html` below the root. Per-route
prerenders are an SEO artifact served over HTTP, not an offline artifact, and
compressed siblings belong to the serving layer. See <doc:PWA>.

A file name containing `?`, `#`, or `%` is a hard error during manifest
generation: those characters can't survive the round trip into a precache
URL. Rename the asset.
