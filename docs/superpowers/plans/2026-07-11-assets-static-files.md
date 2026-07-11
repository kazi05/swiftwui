# Assets & Static Files Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `public/` static-asset convention served identically by dev/build/ssg/serve, plus the framework APIs to use assets: `<link rel>` head links, `@font-face` via `App.fontFaces`, typed `Img` attributes, MIME + HTTP Range fixes.

**Architecture:** Toolchain side extends the existing handler chain (`DevSession`), `DistLayout`, and `Scaffolder` — no new subsystems. Framework side mirrors two existing patterns exactly: `LinkTag` copies the `MetaTag`/`setMetaTags` pipeline (type → `Page` → `PageHead` → `RendererBackend` → Mock/DOM/serializer), and `FontFace` copies the `themes` plumbing (`App` static → `Runtime.mount` → `StyleRegistry.registerRaw`).

**Tech Stack:** Swift 6.3.3, Swift Testing (`@Suite`/`@Test`/`#expect`), no new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-11-assets-static-files-design.md`

## Global Constraints

- Toolchain: Swift 6.3.3 host + `swift-6.3.3-RELEASE_wasm` SDK; never pass `-disable-reflection-metadata`.
- No new package dependencies.
- JS interop only inside `Sources/SwiftWUIDOM` under `#if arch(wasm32)` (never `canImport(JavaScriptKit)`).
- Every URL that reaches markup/CSS goes through `HTMLEscaping.sanitizeURL`.
- Primary gate is native `swift test`; DOM changes must also compile for wasm (final task).
- Testing workflow (user preference): write all of a task's tests and implementation first, then ONE `swift test` run at the end of the task. No intermediate red/green runs.
- Reserved top-level names in `public/`: `app`, `vendor`, `index.html`, `__swiftwui`.
- Commit after every task; messages in English, conventional-commit style.

---

### Task 1: MIME table + HTTP Range in HTTPServer

**Files:**
- Modify: `Sources/SwiftWUIToolchain/HTTPServer.swift` (MIME table at :37-44; range logic in `handle` at :156-166)
- Test: `Tests/SwiftWUITests/ToolchainHTTPTests.swift` (append tests)

**Interfaces:**
- Consumes: existing `HTTPResponse`, `MIME.types`, `HTTPServer.handle`.
- Produces: `MIME.types` covering the new extensions; automatic single-range support for every non-hijack 200 response with a body; `Accept-Ranges: bytes` on those responses; internal `static func rangedResponse(_ response: HTTPResponse, rangeHeader: String?) -> HTTPResponse` (internal, testable via `@testable import`).

- [ ] **Step 1: Extend the MIME table**

In `MIME.types` (HTTPServer.swift:37-44) add entries (keep existing ones untouched):

```swift
        "gif": "image/gif", "webp": "image/webp", "avif": "image/avif",
        "woff": "font/woff", "woff2": "font/woff2",
        "ttf": "font/ttf", "otf": "font/otf",
        "mp4": "video/mp4", "webm": "video/webm",
        "mp3": "audio/mpeg", "ogg": "audio/ogg", "wav": "audio/wav",
        "xml": "application/xml", "webmanifest": "application/manifest+json",
        "pdf": "application/pdf",
```

- [ ] **Step 2: Range support**

Add to `HTTPServer` (below `findHeaderEnd`, same `private static` section):

```swift
    /// Single-range slicing for static bodies (spec §3). Multi-range and
    /// malformed headers are ignored (full 200); out-of-bounds → 416.
    /// Applied only to non-hijack 200 responses with a body.
    static func rangedResponse(_ response: HTTPResponse, rangeHeader: String?) -> HTTPResponse {
        guard response.status == 200, response.hijack == nil, !response.body.isEmpty else { return response }
        var r = response
        r.headers["Accept-Ranges"] = "bytes"
        guard let header = rangeHeader, header.hasPrefix("bytes="), !header.contains(",") else { return r }
        let spec = header.dropFirst("bytes=".count)
        guard let dash = spec.firstIndex(of: "-") else { return r }
        let startStr = spec[..<dash], endStr = spec[spec.index(after: dash)...]
        let len = r.body.count
        var start: Int, end: Int
        if startStr.isEmpty {                       // suffix form bytes=-n
            guard let n = Int(endStr), n > 0 else { return r }
            start = max(0, len - n); end = len - 1
        } else {
            guard let s = Int(startStr) else { return r }
            start = s
            if endStr.isEmpty { end = len - 1 }     // open form bytes=s-
            else { guard let e = Int(endStr) else { return r }; end = min(e, len - 1) }
        }
        guard start < len, start >= 0, start <= end else {
            return HTTPResponse(status: 416,
                headers: ["Content-Range": "bytes */\(len)", "Accept-Ranges": "bytes"], body: [])
        }
        r.status = 206
        r.headers["Content-Range"] = "bytes \(start)-\(end)/\(len)"
        r.body = Array(r.body[start...end])
        return r
    }
```

In `handle` (HTTPServer.swift:156-166), after the handler loop picks `response` and before the hijack check, insert:

```swift
        response = rangedResponse(response, rangeHeader: headers["range"])
```

(Headers dict already has lowercased keys — :151. The 206 status line renders as `HTTP/1.1 206 X` via `sendHead` — clients only parse the code; no change needed there.)

- [ ] **Step 3: Tests**

Append to `ToolchainHTTPTests` (the suite's `get` helper follows redirects but does not add Range; add a variant):

```swift
    func getRange(_ port: UInt16, _ path: String, _ range: String?) async throws -> (Int, [UInt8], [AnyHashable: Any]) {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        if let range { req.setValue(range, forHTTPHeaderField: "Range") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as! HTTPURLResponse
        return (http.statusCode, Array(data), http.allHeaderFields)
    }

    @Test func mimeTableCoversAssetTypes() {
        #expect(MIME.type(forPath: "a/f.woff2") == "font/woff2")
        #expect(MIME.type(forPath: "f.webp") == "image/webp")
        #expect(MIME.type(forPath: "f.mp4") == "video/mp4")
        #expect(MIME.type(forPath: "f.webmanifest") == "application/manifest+json")
        #expect(MIME.type(forPath: "f.unknownext") == "application/octet-stream")
    }

    @Test func rangeRequestsSliceBody() async throws {
        let dir = try tempSite()
        try Data(Array(0..<100 as Range<UInt8>)).write(to: URL(fileURLWithPath: dir + "/blob.bin"))
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir)])
        try server.start(port: 0); defer { server.stop() }
        let p = server.boundPort

        let (s1, b1, h1) = try await getRange(p, "/blob.bin", "bytes=0-9")
        #expect(s1 == 206 && b1 == Array(0..<10))
        #expect(h1["Content-Range"] as? String == "bytes 0-9/100")

        let (s2, b2, _) = try await getRange(p, "/blob.bin", "bytes=90-")
        #expect(s2 == 206 && b2 == Array(90..<100))

        let (s3, b3, _) = try await getRange(p, "/blob.bin", "bytes=-10")
        #expect(s3 == 206 && b3 == Array(90..<100))

        let (s4, _, _) = try await getRange(p, "/blob.bin", "bytes=200-")
        #expect(s4 == 416)

        let (s5, b5, _) = try await getRange(p, "/blob.bin", "bytes=0-9,20-29")
        #expect(s5 == 200 && b5.count == 100)          // multi-range ignored

        let (s6, _, h6) = try await getRange(p, "/blob.bin", nil)
        #expect(s6 == 200)
        #expect(h6["Accept-Ranges"] as? String == "bytes")
    }
```

Also unit-test the pure function directly (no sockets):

```swift
    @Test func rangedResponseEdgeCases() {
        let full = HTTPResponse(status: 200, headers: [:], body: Array(0..<10 as Range<UInt8>))
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=3-5").body == [3, 4, 5])
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=3-999").body == Array(3..<10))
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "garbage").status == 200)
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=-0").status == 200)
        #expect(HTTPServer.rangedResponse(full, rangeHeader: "bytes=5-3").status == 416)
        let sse = HTTPResponse(status: 200, headers: [:], body: [1], hijack: { _ in })
        #expect(HTTPServer.rangedResponse(sse, rangeHeader: "bytes=0-0").headers["Accept-Ranges"] == nil)
    }
```

Note: `bytes=5-3` (start>end with both present) hits the `start <= end` guard → 416; RFC says ignore, but 416 is also acceptable and simpler — keep the test asserting current behavior.

- [ ] **Step 4: Run the suite once**

Run: `swift test 2>&1 | tail -5`
Expected: all tests pass (294 existing + new).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUIToolchain/HTTPServer.swift Tests/SwiftWUITests/ToolchainHTTPTests.swift
git commit -m "feat(toolchain): asset MIME types + single-range HTTP support"
```

---

### Task 2: dev server serves public/

**Files:**
- Modify: `Sources/SwiftWUIToolchain/DevSession.swift` (`handlers(projectDir:bundleDir:)` at :34-64)
- Test: `Tests/SwiftWUITests/ToolchainDevTests.swift` (append)

**Interfaces:**
- Consumes: `StaticFiles.handler(urlPrefix:root:spaFallback:)` (HTTPServer.swift:196).
- Produces: dev handler chain where dotted paths resolve against `<projectDir>/public` before 404; extensionless paths untouched (SPA fallback keeps winning).

- [ ] **Step 1: Add the public handler**

In `DevSession.handlers`, before the `return` (DevSession.swift:56), add:

```swift
        // public/ assets (spec §2): dotted paths only — extensionless paths
        // must keep falling through to the SPA index handler below.
        let publicFiles = StaticFiles.handler(urlPrefix: "/", root: projectDir + "/public")
        let publicHandler: HTTPHandler = { request in
            guard request.path.split(separator: "/").last?.contains(".") == true else { return nil }
            return publicFiles(request)
        }
```

and insert `publicHandler,` into the returned array between the `/app/` handler and `indexHandler`:

```swift
        return [
            hub.handler(lastError: { [weak self] in self?.lastError }),
            devClient,
            StaticFiles.handler(urlPrefix: "/__swiftwui/vendor/wasi-shim/", root: shimRoot),
            StaticFiles.handler(urlPrefix: "/vendor/wasi-shim/", root: shimRoot),
            StaticFiles.handler(urlPrefix: "/app/", root: bundleDir),
            publicHandler,
            indexHandler,
        ]
```

(Ordering keeps reserved routes authoritative: a `public/app/…` file can never shadow the bundle because `/app/` matches first. The reserved-name *warning* is Task 3's `DistLayout.reservedCollisions` wired into `DevCommand`.)

- [ ] **Step 2: Tests**

Handlers are plain closures over `HTTPRequest` — test without sockets. Append to `ToolchainDevTests` (follow the suite's existing temp-dir idiom):

```swift
    @Test func devServesPublicAssets() throws {
        let dir = NSTemporaryDirectory() + "swiftwui-pub-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir + "/public/images", withIntermediateDirectories: true)
        try "<html>".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        try "png-bytes".write(toFile: dir + "/public/images/logo.png", atomically: true, encoding: .utf8)
        try "sitemap".write(toFile: dir + "/public/robots.txt", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let session = DevSession(
            builder: WasmBuilder(runner: FoundationProcessRunner(), projectDir: dir, sdk: "x"),
            hub: SSEHub())
        let handlers = session.handlers(projectDir: dir, bundleDir: dir + "/.bundle")
        func serve(_ path: String) -> HTTPResponse? {
            let req = HTTPRequest(method: "GET", path: path, headers: [:])
            for h in handlers { if let r = h(req) { return r } }
            return nil
        }

        let hit = serve("/images/logo.png")
        #expect(hit?.status == 200)
        #expect(hit.map { String(decoding: $0.body, as: UTF8.self) } == "png-bytes")
        #expect(hit?.headers["Content-Type"] == "image/png")
        #expect(serve("/robots.txt")?.status == 200)
        #expect(serve("/missing.png") == nil)                    // falls to server-level 404
        // extensionless path → SPA index (routes win), not public lookup
        let spa = serve("/about")
        #expect(spa.map { String(decoding: $0.body, as: UTF8.self).contains("<html>") } == true)
    }

    @Test func devWithoutPublicDirUnchanged() throws {
        let dir = NSTemporaryDirectory() + "swiftwui-nopub-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "<html>".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let session = DevSession(
            builder: WasmBuilder(runner: FoundationProcessRunner(), projectDir: dir, sdk: "x"),
            hub: SSEHub())
        let handlers = session.handlers(projectDir: dir, bundleDir: dir + "/.bundle")
        let req = HTTPRequest(method: "GET", path: "/anything.png", headers: [:])
        #expect(handlers.compactMap { $0(req) }.first == nil)
    }
```

If `ToolchainDevTests` already defines a `FoundationProcessRunner`-free fake runner or a session factory helper, reuse it instead of the literal above — check the file before writing (`WasmBuilder` is never invoked by `handlers`, so any runner value works).

`HTTPResponse` has no `Equatable`; the `== nil` checks compare `Optional` — if the compiler objects, use `#expect(... == nil)` on `serve(...)?.status` instead.

- [ ] **Step 3: Run the suite once**

Run: `swift test 2>&1 | tail -5` — expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUIToolchain/DevSession.swift Tests/SwiftWUITests/ToolchainDevTests.swift
git commit -m "feat(toolchain): dev server serves public/ at the URL root"
```

---

### Task 3: public/ copy in build + ssg, reserved-name guard

**Files:**
- Modify: `Sources/SwiftWUIToolchain/WasmBuild.swift` (`DistLayout`, :45-67)
- Modify: `Sources/SwiftWUICLI/Commands/SSGCommand.swift` (:13-19)
- Modify: `Sources/SwiftWUICLI/Commands/DevCommand.swift` (print warning near startup)
- Test: `Tests/SwiftWUITests/ToolchainBuildTests.swift` (append)

**Interfaces:**
- Consumes: `DistLayout.assemble(projectDir:bundleDir:outDir:)` (WasmBuild.swift:49), `ToolchainError.io`.
- Produces:
  - `DistLayout.reservedNames: Set<String>` — `["app", "vendor", "index.html", "__swiftwui"]`
  - `DistLayout.reservedCollisions(projectDir: String) -> [String]` (sorted; empty when no `public/`)
  - `DistLayout.copyPublic(projectDir: String, outDir: String) throws` — throws `ToolchainError.io` on collisions; no-op without `public/`. Called by `assemble` and by the ssg command.

- [ ] **Step 1: Implement in DistLayout**

Append inside `enum DistLayout` (WasmBuild.swift):

```swift
    public static let reservedNames: Set<String> = ["app", "vendor", "index.html", "__swiftwui"]

    /// Top-level public/ entries that would shadow the framework's dist layout (spec §1).
    public static func reservedCollisions(projectDir: String) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: projectDir + "/public")) ?? []
        return entries.filter { reservedNames.contains($0) }.sorted()
    }

    /// Copy every top-level child of public/ into outDir (spec §4). Replaces
    /// each target child; never wipes outDir itself (it holds app/ + vendor/).
    public static func copyPublic(projectDir: String, outDir: String) throws {
        let fm = FileManager.default
        let publicDir = projectDir + "/public"
        guard fm.fileExists(atPath: publicDir) else { return }
        let collisions = reservedCollisions(projectDir: projectDir)
        guard collisions.isEmpty else {
            throw ToolchainError.io("public/ contains reserved name(s) \(collisions.joined(separator: ", ")) — these collide with the framework's dist layout (reserved: \(reservedNames.sorted().joined(separator: ", ")))")
        }
        try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        for entry in try fm.contentsOfDirectory(atPath: publicDir).sorted() {
            try? fm.removeItem(atPath: outDir + "/" + entry)
            try fm.copyItem(atPath: publicDir + "/" + entry, toPath: outDir + "/" + entry)
        }
    }
```

At the end of `assemble` (after the shim copy, WasmBuild.swift:65), add:

```swift
        try copyPublic(projectDir: projectDir, outDir: outDir)
```

- [ ] **Step 2: ssg command copies public/ too**

In `SSGCommand.run()` (SSGCommand.swift:13-19), after the `guard r.exitCode == 0` line:

```swift
        try DistLayout.copyPublic(projectDir: cwd, outDir: cwd + "/" + out)
```

- [ ] **Step 3: dev warning**

Read `Sources/SwiftWUICLI/Commands/DevCommand.swift` first. Near startup (right before the server starts / first "serving" print), add:

```swift
        let collisions = DistLayout.reservedCollisions(projectDir: cwd)
        if !collisions.isEmpty {
            print("warning: public/ contains reserved name(s) \(collisions.joined(separator: ", ")) — they will be shadowed in dev and rejected by `swiftwui build`")
        }
```

(Use whatever the command's project-dir variable is named — the survey shows the commands use `cwd = FileManager.default.currentDirectoryPath`.)

- [ ] **Step 4: Tests**

Append to `ToolchainBuildTests` (mirror the existing `distLayoutAssembles` temp-dir setup — read it first and reuse its helper if one exists):

```swift
    @Test func distLayoutCopiesPublic() throws {
        let root = NSTemporaryDirectory() + "swiftwui-dist-\(UUID().uuidString)"
        let fm = FileManager.default
        try fm.createDirectory(atPath: root + "/public/images", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: root + "/bundle", withIntermediateDirectories: true)
        try "html".write(toFile: root + "/index.html", atomically: true, encoding: .utf8)
        try "js".write(toFile: root + "/bundle/index.js", atomically: true, encoding: .utf8)
        try "ico".write(toFile: root + "/public/favicon.ico", atomically: true, encoding: .utf8)
        try "img".write(toFile: root + "/public/images/a.png", atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(atPath: root) }

        try DistLayout.assemble(projectDir: root, bundleDir: root + "/bundle", outDir: root + "/dist")
        #expect(fm.fileExists(atPath: root + "/dist/favicon.ico"))
        #expect(fm.fileExists(atPath: root + "/dist/images/a.png"))
        #expect(fm.fileExists(atPath: root + "/dist/app/index.js"))   // dist not wiped

        // idempotent re-run after source change
        try "img2".write(toFile: root + "/public/images/a.png", atomically: true, encoding: .utf8)
        try DistLayout.copyPublic(projectDir: root, outDir: root + "/dist")
        #expect(try String(contentsOfFile: root + "/dist/images/a.png", encoding: .utf8) == "img2")
    }

    @Test func distLayoutRejectsReservedPublicNames() throws {
        let root = NSTemporaryDirectory() + "swiftwui-resv-\(UUID().uuidString)"
        let fm = FileManager.default
        try fm.createDirectory(atPath: root + "/public/app", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: root + "/public/vendor", withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: root) }
        #expect(DistLayout.reservedCollisions(projectDir: root) == ["app", "vendor"])
        #expect(throws: ToolchainError.self) {
            try DistLayout.copyPublic(projectDir: root, outDir: root + "/dist")
        }
    }

    @Test func copyPublicWithoutPublicDirIsNoop() throws {
        let root = NSTemporaryDirectory() + "swiftwui-nop-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }
        try DistLayout.copyPublic(projectDir: root, outDir: root + "/dist")
        #expect(!FileManager.default.fileExists(atPath: root + "/dist"))
    }
```

Note the no-op test asserts `dist` is NOT created when `public/` is absent — the `createDirectory` call sits after the `guard`.

- [ ] **Step 5: Run the suite once**

Run: `swift test 2>&1 | tail -5` — expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUIToolchain/WasmBuild.swift Sources/SwiftWUICLI/Commands/SSGCommand.swift Sources/SwiftWUICLI/Commands/DevCommand.swift Tests/SwiftWUITests/ToolchainBuildTests.swift
git commit -m "feat(toolchain): copy public/ into dist on build+ssg, reserved-name guard"
```

---

### Task 4: templates scaffold public/ + favicon

**Files:**
- Create: `Sources/SwiftWUIToolchain/Resources/templates/basic/public/favicon.svg` (same file into `mvvm/` and `tca/`)
- Modify: `Sources/SwiftWUIToolchain/Resources/templates/basic/index.html` (and `mvvm`, `tca` variants)
- Test: `Tests/SwiftWUITests/ToolchainScaffoldTests.swift` (append)

**Interfaces:**
- Consumes: `Scaffolder.scaffold` (copies the whole template tree recursively — Scaffolder.swift:30-52 — so a `public/` dir inside a template needs zero scaffolder code changes).
- Produces: scaffolded projects containing `public/favicon.svg`, referenced from `index.html`.

- [ ] **Step 1: favicon asset**

Create `Sources/SwiftWUIToolchain/Resources/templates/basic/public/favicon.svg` with:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="7" fill="#F05138"/><text x="16" y="22" font-family="system-ui,sans-serif" font-size="16" font-weight="700" fill="#fff" text-anchor="middle">W</text></svg>
```

Copy the identical file to `templates/mvvm/public/favicon.svg` and `templates/tca/public/favicon.svg`. (Plain text SVG survives the scaffolder's UTF-8 substitution path — it contains no `{{` placeholders.)

- [ ] **Step 2: reference it in each template index.html**

In all three `templates/*/index.html`, inside `<head>` after `<title>{{NAME}}</title>`:

```html
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
```

Each template also has a `README.md` — add one line to its project-layout
listing: `public/` — static assets served from the site root (favicon,
images, fonts). Match each README's existing list formatting.

- [ ] **Step 3: Test**

Append to `ToolchainScaffoldTests` (reuse its existing temp-dir/scaffold helper — read the file first):

```swift
    @Test func templatesScaffoldPublicDir() throws {
        for template in Scaffolder.templates {
            let dir = NSTemporaryDirectory() + "swiftwui-scaffold-pub-\(UUID().uuidString)"
            defer { try? FileManager.default.removeItem(atPath: dir) }
            try Scaffolder.scaffold(template: template, name: "Demo", swiftwuiPath: nil, into: dir)
            #expect(FileManager.default.fileExists(atPath: dir + "/public/favicon.svg"),
                    "template \(template) missing public/favicon.svg")
            let html = try String(contentsOfFile: dir + "/index.html", encoding: .utf8)
            #expect(html.contains("rel=\"icon\""), "template \(template) index.html missing favicon link")
        }
    }
```

- [ ] **Step 4: Run the suite once**

Run: `swift test 2>&1 | tail -5` — expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUIToolchain/Resources/templates Tests/SwiftWUITests/ToolchainScaffoldTests.swift
git commit -m "feat(toolchain): templates scaffold public/ with favicon"
```

---

### Task 5: LinkTag + Page.links + PageHead.links

**Files:**
- Modify: `Sources/SwiftWUI/Routing/Page.swift` (add `LinkTag` + `PreloadKind` below `MetaTag`; extend `Page` and `PageHead`)
- Modify: `Sources/SwiftWUI/Routing/Router.swift:34` (capture links)
- Test: `Tests/SwiftWUITests/PageTests.swift` (append)

**Interfaces:**
- Consumes: `_AttributeBag.isValidName`, `HTMLEscaping.sanitizeURL`, `MetaTag` idiom (Page.swift:3-36).
- Produces (used by Task 6):
  - `public struct LinkTag: Equatable { public let attributes: [String: String] }`
  - statics: `icon(_:type:)`, `stylesheet(_:)`, `preload(_:as:type:)`, `canonical(_:)`
  - `public enum PreloadKind: String { case font, image, style, script, fetch }`
  - `Page.links: [LinkTag]` (default `[]`); `PageHead.links: [LinkTag]`; `PageHead.init(title:meta:links:)` with `links: [LinkTag] = []` default so existing call sites compile.

- [ ] **Step 1: LinkTag type**

Add to `Page.swift` after `MetaTag`:

```swift
/// A managed `<link>` tag description (assets spec §6). Mirrors `MetaTag`:
/// names validated against `_AttributeBag` rules; `href` sanitized at
/// construction (same policy as `A`/`Img`).
public struct LinkTag: Equatable {
    public let attributes: [String: String]
    public init(attributes: [String: String]) {
        var valid: [String: String] = [:]
        for (name, value) in attributes {
            guard _AttributeBag.isValidName(name) else {
                assertionFailure("LinkTag: invalid attribute name '\(name)'")
                continue
            }
            valid[name] = value
        }
        if let href = valid["href"] { valid["href"] = HTMLEscaping.sanitizeURL(href) }
        self.attributes = valid
    }
    /// `<link rel="icon" href="..." [type="..."]>`
    public static func icon(_ href: String, type: String? = nil) -> LinkTag {
        var attrs = ["rel": "icon", "href": href]
        if let type { attrs["type"] = type }
        return LinkTag(attributes: attrs)
    }
    /// `<link rel="stylesheet" href="...">`
    public static func stylesheet(_ href: String) -> LinkTag {
        LinkTag(attributes: ["rel": "stylesheet", "href": href])
    }
    /// `<link rel="preload" href="..." as="..."> ` — font preloads get `crossorigin`.
    public static func preload(_ href: String, as kind: PreloadKind, type: String? = nil) -> LinkTag {
        var attrs = ["rel": "preload", "href": href, "as": kind.rawValue]
        if kind == .font { attrs["crossorigin"] = "anonymous" }
        if let type { attrs["type"] = type }
        return LinkTag(attributes: attrs)
    }
    /// `<link rel="canonical" href="...">`
    public static func canonical(_ href: String) -> LinkTag {
        LinkTag(attributes: ["rel": "canonical", "href": href])
    }
}

/// `as` values for `LinkTag.preload` (assets spec §6).
public enum PreloadKind: String, Equatable {
    case font, image, style, script, fetch
}
```

- [ ] **Step 2: Page + PageHead**

In the `Page` protocol (Page.swift:41-52), after `var meta: [MetaTag] { get }`:

```swift
    /// Managed `<link>` set (replaces only tags marked data-swiftwui).
    var links: [LinkTag] { get }
```

and in the extension:

```swift
extension Page {
    public var meta: [MetaTag] { [] }
    public var links: [LinkTag] { [] }
}
```

`PageHead` (Page.swift:59-63) becomes:

```swift
public struct PageHead: Equatable {
    public var title: String
    public var meta: [MetaTag]
    public var links: [LinkTag]
    public init(title: String, meta: [MetaTag], links: [LinkTag] = []) {
        self.title = title; self.meta = meta; self.links = links
    }
}
```

- [ ] **Step 3: Router captures links**

`Router.swift:34`:

```swift
                ctx.pageHead = PageHead(title: page.title, meta: page.meta, links: page.links)
```

- [ ] **Step 4: Tests**

Append to `PageTests.swift`:

```swift
    @Test func linkTagStatics() {
        #expect(LinkTag.icon("/favicon.svg", type: "image/svg+xml").attributes
            == ["rel": "icon", "href": "/favicon.svg", "type": "image/svg+xml"])
        #expect(LinkTag.stylesheet("/a.css").attributes == ["rel": "stylesheet", "href": "/a.css"])
        #expect(LinkTag.preload("/f.woff2", as: .font).attributes
            == ["rel": "preload", "href": "/f.woff2", "as": "font", "crossorigin": "anonymous"])
        #expect(LinkTag.preload("/h.jpg", as: .image).attributes["crossorigin"] == nil)
        #expect(LinkTag.canonical("https://x.y/p").attributes == ["rel": "canonical", "href": "https://x.y/p"])
    }

    @Test func linkTagSanitizesHref() {
        #expect(LinkTag.icon("javascript:alert(1)").attributes["href"] == "#")
        #expect(LinkTag(attributes: ["rel": "icon", "href": "data:text/html,x"]).attributes["href"] == "#")
    }

    @Test func pageDefaultLinksEmpty() {
        struct P: Page { var title: String { "t" }; var body: some Tag { Div() } }
        #expect(P().links.isEmpty)
    }
```

(Invalid-attribute-name behavior is `assertionFailure` — debug test runs would trap; the drop path is already covered by the identical `MetaTag` machinery. Do not add a trap-triggering test.)

- [ ] **Step 5: Run the suite once**

Run: `swift test 2>&1 | tail -5` — expected: PASS (PageHead's defaulted `links:` keeps existing call sites compiling; if any test constructs `PageHead` and compares with `==`, the default `[]` keeps equality semantics).

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUI/Routing/Page.swift Sources/SwiftWUI/Routing/Router.swift Tests/SwiftWUITests/PageTests.swift
git commit -m "feat(core): LinkTag head links on Page/PageHead"
```

---

### Task 6: setLinks across backends + serializer

**Files:**
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift` (after `setMetaTags`, :29)
- Modify: `Sources/SwiftWUI/Render/MockBackend.swift` (next to `metaTags`, :64-71)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift:198-202` (apply links)
- Modify: `Sources/SwiftWUIDOM/DOMBackend.swift` (mirror `setMetaTags`, :147-…)
- Modify: `Sources/SwiftWUIStatic/DocumentSerializer.swift` (emit `<link>` after metas)
- Test: `Tests/SwiftWUITests/RouterTests.swift` or `PageTests.swift` (mock application), `Tests/SwiftWUITests/DocumentSerializerTests.swift`

**Interfaces:**
- Consumes: `LinkTag` (Task 5), `PageHead.links`.
- Produces: `RendererBackend.setLinks(_: [LinkTag])`; `MockBackend.links: [LinkTag]` (recorded); `<link … data-swiftwui>` in SSG documents.

Before editing, run `grep -rn "func setMetaTags" Sources/` — every conformer found must gain `setLinks` (expected: MockBackend, DOMBackend only).

- [ ] **Step 1: protocol**

`RendererBackend.swift`, after `setMetaTags` (:29):

```swift
    /// Replaces the document's MANAGED link set (marked data-swiftwui);
    /// hand-written <link> in the host HTML is never touched.
    func setLinks(_ links: [LinkTag])
```

- [ ] **Step 2: MockBackend**

After the `metaTags` pair (MockBackend.swift:65,71):

```swift
    public private(set) var links: [LinkTag] = []
```
```swift
    public func setLinks(_ links: [LinkTag]) { bump("setLinks"); self.links = links }
```

- [ ] **Step 3: Runtime applies**

`Runtime.swift:198-202` — extend the head block:

```swift
        if let head = ctx.pageHead, head != lastPageHead {
            lastPageHead = head
            applier.backend.setTitle(head.title)
            applier.backend.setMetaTags(head.meta)
            applier.backend.setLinks(head.links)
        }
```

- [ ] **Step 4: DOMBackend**

After `setMetaTags` in `DOMBackend.swift` (mirror its exact idiom — v1-audited style, do not modernize):

```swift
    public func setLinks(_ links: [LinkTag]) {
        // Replace ONLY the managed set (assets spec §6): marked data-swiftwui.
        let old = document.querySelectorAll("link[data-swiftwui]").object
        let n = Int(old?.length.number ?? 0)
        for i in (0..<n).reversed() {
            if let el = old?[i].object {
                _ = el.parentNode.object?.removeChild?(el)
            }
        }
        guard let head = document.head.object else { return }
        for link in links {
            let el = document.createElement("link").object!
            for name in link.attributes.keys.sorted() {
                _ = el.setAttribute?(name, link.attributes[name]!)
            }
            _ = el.setAttribute?("data-swiftwui", "")
            _ = head.appendChild?(el)
        }
    }
```

(Copy the trailing lines of `setMetaTags` first — the `data-swiftwui` marker + `appendChild` calls must match its exact form; the block above is modeled on :147-160 but the file tail beyond :160 wasn't excerpted. Match whatever `setMetaTags` actually does.)

- [ ] **Step 5: DocumentSerializer**

In `render`, after the meta loop and before the `cssHref` block:

```swift
        for link in input.head?.links ?? [] {
            out += "<link"
            for name in link.attributes.keys.sorted() {
                out += " \(name)=\"\(HTMLEscaping.text(link.attributes[name]!))\""
            }
            out += " data-swiftwui>\n"       // managed set marker (same as meta)
        }
```

- [ ] **Step 6: Tests**

Mock recording — extend `PageTests.mockBackendRecordsRoutingCalls` (PageTests.swift:21-30): add

```swift
        b.setLinks([.icon("/favicon.svg")])
```
after the `setMetaTags` call and
```swift
        #expect(b.links == [.icon("/favicon.svg")])
```
to its assertions.

End-to-end application — `GuardAndPageTests.swift` already drives Pages through mount/navigation with its `make()` harness and asserts `backend.title`/`backend.metaTags` (:79-90). Add `var links: [LinkTag] { [.icon("/favicon.svg")] }` to its `GHome` page struct, then extend `pageHeadAppliedAtMount` (:79-82) with:

```swift
        #expect(backend.links == [.icon("/favicon.svg")])
```

and extend `headSwapsOnNavigationAndNonPageLeavesTitle` (:84-90) with an assertion that after navigating to the admin page (which declares no links) the managed set is replaced:

```swift
        #expect(backend.links.isEmpty)                 // default links replace old set
```

Serializer — append to `DocumentSerializerTests.swift`:

```swift
    @Test func rendersManagedLinks() {
        let head = PageHead(title: "T", meta: [], links: [
            .icon("/favicon.svg", type: "image/svg+xml"),
            .preload("/f.woff2", as: .font),
        ])
        let html = DocumentSerializer.render(.init(bodyHTML: "<p>x</p>", head: head))
        #expect(html.contains("<link as=\"font\" crossorigin=\"anonymous\" href=\"/f.woff2\" rel=\"preload\" data-swiftwui>"))
        #expect(html.contains("<link href=\"/favicon.svg\" rel=\"icon\" type=\"image/svg+xml\" data-swiftwui>"))
    }

    @Test func linkHrefIsSanitizedInDocument() {
        let head = PageHead(title: "T", meta: [], links: [.icon("javascript:alert(1)")])
        let html = DocumentSerializer.render(.init(bodyHTML: "", head: head))
        #expect(html.contains("href=\"#\""))
        #expect(!html.contains("javascript:"))
    }
```

- [ ] **Step 7: Run the suite once**

Run: `swift test 2>&1 | tail -5` — expected: PASS. (`SwiftWUIDOM` does not compile natively — its wasm compile check is the final task.)

- [ ] **Step 8: Commit**

```bash
git add Sources/SwiftWUI/Render/RendererBackend.swift Sources/SwiftWUI/Render/MockBackend.swift Sources/SwiftWUI/Runtime/Runtime.swift Sources/SwiftWUIDOM/DOMBackend.swift Sources/SwiftWUIStatic/DocumentSerializer.swift Tests/SwiftWUITests/
git commit -m "feat: setLinks backend pipeline — mock, DOM, runtime, SSG serializer"
```

---

### Task 7: FontFace via App.fontFaces

**Files:**
- Create: `Sources/SwiftWUI/Styles/FontFace.swift`
- Modify: `Sources/SwiftWUI/App/App.swift` (:11,:16 — add `fontFaces` next to `themes`)
- Modify: `Sources/SwiftWUI/Runtime/Runtime.swift` (:24,:56-65,:83 — store/register)
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (:42,:45,:91,:111,:144,:153 — plumb through every `themes:` site)
- Modify: `Sources/SwiftWUIStatic/StaticSite.swift` (:59,:161 — same)
- Test: `Tests/SwiftWUITests/FontFaceTests.swift` (new)

**Interfaces:**
- Consumes: `StyleRegistry.registerRaw` (StyleRegistry.swift:70), `HTMLEscaping.sanitizeURL`, the `themes` plumbing (Runtime.swift:83).
- Produces:
  - `public struct FontFace` with `init(family: String, src: String, format: FontFormat? = nil, weight: ClosedRange<Int>? = nil, style: FontFaceStyle = .normal, display: FontDisplay = .swap)` + convenience `init(..., weight: Int, ...)`
  - nested enums: `FontFace.FontFormat: String { woff2, woff, truetype, opentype }`, `FontFace.FontFaceStyle: String { normal, italic }`, `FontFace.FontDisplay: String { auto, block, swap, fallback, optional }` (callers write `.woff2` etc. via inference)
  - `var ruleText: String` (internal)
  - `App.fontFaces: [FontFace]` static (default `[]`); `Runtime.init(... themes: [ThemeDefinition] = [], fontFaces: [FontFace] = [])`.

- [ ] **Step 1: FontFace.swift**

```swift
/// A typed `@font-face` declaration (assets spec §7), registered app-wide via
/// `App.fontFaces` — the exact plumbing `App.themes` uses. `family` and `src`
/// are emitted inside CSS quoted strings with `\` and `"` escaped, and `src`
/// passes `HTMLEscaping.sanitizeURL` first: invalid input degrades to a
/// harmless string, never a CSS breakout.
public struct FontFace: Equatable {
    public enum FontFormat: String, Equatable { case woff2, woff, truetype, opentype }
    public enum FontFaceStyle: String, Equatable { case normal, italic }
    public enum FontDisplay: String, Equatable { case auto, block, swap, fallback, optional }

    public var family: String
    public var src: String
    public var format: FontFormat?
    public var weight: ClosedRange<Int>?
    public var style: FontFaceStyle
    public var display: FontDisplay

    public init(family: String, src: String, format: FontFormat? = nil,
                weight: ClosedRange<Int>? = nil, style: FontFaceStyle = .normal,
                display: FontDisplay = .swap) {
        self.family = family; self.src = src; self.format = format
        self.weight = weight; self.style = style; self.display = display
    }
    public init(family: String, src: String, format: FontFormat? = nil,
                weight: Int, style: FontFaceStyle = .normal,
                display: FontDisplay = .swap) {
        self.init(family: family, src: src, format: format,
                  weight: weight...weight, style: style, display: display)
    }

    static func cssString(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    var ruleText: String {
        var decls = ["font-family: \(Self.cssString(family))"]
        var srcValue = "url(\(Self.cssString(HTMLEscaping.sanitizeURL(src))))"
        if let format { srcValue += " format(\(Self.cssString(format.rawValue)))" }
        decls.append("src: \(srcValue)")
        if let weight {
            decls.append(weight.lowerBound == weight.upperBound
                ? "font-weight: \(weight.lowerBound)"
                : "font-weight: \(weight.lowerBound) \(weight.upperBound)")
        }
        decls.append("font-style: \(style.rawValue)")
        decls.append("font-display: \(display.rawValue)")
        return "@font-face { \(decls.joined(separator: "; ")) }"
    }
}
```

(`FontFace.swift` needs no imports — `HTMLEscaping` is same-module. `replacingOccurrences` is Foundation: check whether the Styles module files import Foundation; if the core avoids Foundation, replace with a manual scalar loop:)

```swift
    static func cssString(_ s: String) -> String {
        var out = "\""
        for ch in s {
            if ch == "\\" || ch == "\"" { out.append("\\") }
            out.append(ch)
        }
        return out + "\""
    }
```

Use the manual-loop version — `Sources/SwiftWUI` is zero-dep and several files deliberately avoid Foundation (see HTMLEscaping's "without pulling in Foundation" note).

- [ ] **Step 2: App protocol**

`App.swift` — next to `themes` (:11,:16):

```swift
    static var fontFaces: [FontFace] { get }
```
```swift
    public static var fontFaces: [FontFace] { [] }
```

- [ ] **Step 3: Runtime**

- `Runtime.swift:24`: add `private let fontFaces: [FontFace]` next to `themes`.
- init (:53-65): parameter `fontFaces: [FontFace] = []` after `themes`, assign it.
- `mount()` (:82-86):

```swift
    public func mount() {
        for face in fontFaces { styleRegistry.registerRaw(face.ruleText) }
        for theme in themes { styleRegistry.registerRaw(theme.ruleText) }
        for rule in globalStyles { rule.register(into: styleRegistry, scope: nil) }
        renderPass()
    }
```

- [ ] **Step 4: plumb DOMRuntime + StaticSite**

Every site that currently passes `themes:` gains `fontFaces:` immediately after, sourced the same way:

- `DOMRuntime.swift:42`: `globalStyles: [Rule], themes: [ThemeDefinition], fontFaces: [FontFace]` (and :45 pass-through to `Runtime`).
- `DOMRuntime.swift:91,111,144`: add `fontFaces: [FontFace] = []` params + pass-through.
- `DOMRuntime.swift:153`: `DOMRuntime.mount(Self().body, globalStyles: Self.globalStyles, themes: Self.themes, fontFaces: Self.fontFaces)`.
- `StaticSite.swift:59,161`: append `, fontFaces: A.fontFaces` to the `Runtime(...)` constructions.

(DOMRuntime edits won't compile natively — verify by reading carefully; wasm compile check is the final task.)

- [ ] **Step 5: Tests**

New `Tests/SwiftWUITests/FontFaceTests.swift`:

```swift
import Testing
@testable import SwiftWUI

@Suite struct FontFaceTests {
    @Test func fullRuleText() {
        let f = FontFace(family: "Inter", src: "/fonts/Inter.woff2", format: .woff2,
                         weight: 400...700, style: .normal, display: .swap)
        #expect(f.ruleText == "@font-face { font-family: \"Inter\"; src: url(\"/fonts/Inter.woff2\") format(\"woff2\"); font-weight: 400 700; font-style: normal; font-display: swap }")
    }

    @Test func singleWeightAndDefaults() {
        let f = FontFace(family: "Mono", src: "/m.woff2", weight: 500)
        #expect(f.ruleText.contains("font-weight: 500"))
        #expect(f.ruleText.contains("font-display: swap"))
        #expect(!f.ruleText.contains("format("))
        let noWeight = FontFace(family: "Mono", src: "/m.woff2")
        #expect(!noWeight.ruleText.contains("font-weight"))
    }

    @Test func escapingAndSanitizing() {
        let evil = FontFace(family: "x\") } body { background: url(\"p", src: "javascript:alert(1)")
        #expect(evil.ruleText.contains("url(\"#\")"))                 // sanitizeURL dropped the scheme
        #expect(!evil.ruleText.contains("\") }"))                     // quote escaped, no breakout
        #expect(evil.ruleText.contains("font-family: \"x\\\") } body { background: url(\\\"p\""))
    }

    @Test func mountRegistersFontFaces() {
        let mock = MockBackend()
        let sched = TestScheduler()
        let runtime = Runtime(backend: mock, container: mock.container, root: Div(),
                              scheduleMicrotask: sched.schedule,
                              fontFaces: [FontFace(family: "Inter", src: "/i.woff2")])
        runtime.mount()
        sched.pump()
        #expect(mock.stylesheetText?.contains("@font-face") == true)
        #expect(mock.stylesheetText?.contains("\"Inter\"") == true)
    }
}
```

(Harness verified against `RuntimeE2ETests.swift:41-77`: `TestScheduler` exposes `schedule`/`pump`, and `makeRuntime` constructs `Runtime(backend:container:root:scheduleMicrotask:)` then calls `runtime.mount()` — the snippet matches; `mount()` runs a synchronous render pass, so `stylesheetText` is populated without pumping, and the `sched.pump()` is harmless insurance.)

- [ ] **Step 6: Run the suite once**

Run: `swift test 2>&1 | tail -5` — expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SwiftWUI/Styles/FontFace.swift Sources/SwiftWUI/App/App.swift Sources/SwiftWUI/Runtime/Runtime.swift Sources/SwiftWUIDOM/DOMRuntime.swift Sources/SwiftWUIStatic/StaticSite.swift Tests/SwiftWUITests/FontFaceTests.swift
git commit -m "feat(styles): FontFace @font-face declarations via App.fontFaces"
```

---

### Task 8: Img typed attributes

**Files:**
- Modify: `Sources/SwiftWUI/HTML/Tags.swift` (`Img`, :543-552)
- Test: `Tests/SwiftWUITests/HTMLRendererTests.swift` (append)

**Interfaces:**
- Consumes: `_AttributeBag.set`, `HTMLEscaping.sanitizeURL`.
- Produces: `Img(src:alt:width:height:srcset:sizes:loading:decoding:id:class:)`; `public enum ImgLoading: String { case lazy, eager }`; `public enum ImgDecoding: String { case async, sync, auto }`.

- [ ] **Step 1: extend Img**

Replace the `Img` struct (Tags.swift:543-552) with:

```swift
public enum ImgLoading: String { case `lazy`, eager }
public enum ImgDecoding: String { case async, sync, auto }

public struct Img: _HTMLVoidTag {
    public static var tagName: String { "img" }
    public var _attributes: _AttributeBag
    /// `srcset` is sanitized as one string: a disallowed scheme anywhere in the
    /// list drops the whole value to "#" (coarse but safe — see sanitizeURL).
    public init(src: String, alt: String,
                width: Int? = nil, height: Int? = nil,
                srcset: String? = nil, sizes: String? = nil,
                loading: ImgLoading? = nil, decoding: ImgDecoding? = nil,
                id: String? = nil, class classes: String? = nil) {
        _attributes = _AttributeBag(id: id, class: classes)
        _attributes.set("src", HTMLEscaping.sanitizeURL(src))
        _attributes.set("alt", alt)
        if let width { _attributes.set("width", String(width)) }
        if let height { _attributes.set("height", String(height)) }
        if let srcset { _attributes.set("srcset", HTMLEscaping.sanitizeURL(srcset)) }
        if let sizes { _attributes.set("sizes", sizes) }
        if let loading { _attributes.set("loading", loading.rawValue) }
        if let decoding { _attributes.set("decoding", decoding.rawValue) }
    }
}
```

(`lazy` is a declaration keyword — backticks required in the case declaration; usage stays clean: `.lazy`. `async` is contextual — backticks not needed, add them only if the compiler objects.)

- [ ] **Step 2: Tests**

Append to `HTMLRendererTests.swift` (reuse the file's existing render-to-string helper — read it first; assume `renderHTML(_:)`-style helper exists from neighboring tests):

```swift
    @Test func imgTypedAttributes() {
        let img = Img(src: "/hero.webp", alt: "Hero", width: 1200, height: 630,
                      srcset: "/hero.webp 1x, /hero@2x.webp 2x", sizes: "100vw",
                      loading: .lazy, decoding: .async)
        let html = render(img)   // ← use the suite's actual helper name
        #expect(html.contains("width=\"1200\""))
        #expect(html.contains("height=\"630\""))
        #expect(html.contains("loading=\"lazy\""))
        #expect(html.contains("decoding=\"async\""))
        #expect(html.contains("srcset=\"/hero.webp 1x, /hero@2x.webp 2x\""))
        #expect(html.contains("sizes=\"100vw\""))
    }

    @Test func imgOmittedAttributesAbsent() {
        let html = render(Img(src: "/a.png", alt: "a"))
        #expect(!html.contains("width="))
        #expect(!html.contains("loading="))
        #expect(!html.contains("srcset="))
    }

    @Test func imgSrcsetSanitized() {
        let html = render(Img(src: "/a.png", alt: "a", srcset: "javascript:x 1x"))
        #expect(html.contains("srcset=\"#\""))
    }
```

- [ ] **Step 3: Run the suite once**

Run: `swift test 2>&1 | tail -5` — expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/SwiftWUI/HTML/Tags.swift Tests/SwiftWUITests/HTMLRendererTests.swift
git commit -m "feat(html): Img width/height/srcset/sizes/loading/decoding"
```

---

### Task 9: Tutorial migration + docs

**Files:**
- Move: `Sites/Tutorial/Assets/` → `Sites/Tutorial/public/assets/` (`git mv`)
- Modify: `Sites/Tutorial/build-site.sh` (drop the manual `cp -R Assets/. dist/assets/` at :6)
- Modify: `Sites/Tutorial/README.md` (:68-69 — replace the "dev does not serve /assets/*" caveat with the public/ convention)
- Modify: `Sources/SwiftWUI/SwiftWUI.docc/GettingStarted.md` (add a "Static assets" section)
- Modify: the Tutorial chapter covering project layout (grep `Sites/Tutorial/Sources -rn "index.html"` / chapter files for the layout chapter — likely `Ch0*` content models)

**Interfaces:**
- Consumes: Tasks 2-3 behavior (dev + build/ssg both handle `public/`).
- Produces: Tutorial site builds with zero manual asset copying; docs describe the convention.

- [ ] **Step 1: move assets**

```bash
cd Sites/Tutorial
mkdir -p public
git mv Assets public/assets
```

URLs in Swift stay `/assets/...` (PanelView.swift:80, ContentModel.swift:44-45) — with `public/assets/…` copied to `dist/assets/…`, nothing else changes. Verify with `grep -rn '"/assets/' Sources/`.

- [ ] **Step 2: build script + README**

- `build-site.sh`: delete the `cp -R Assets/. dist/assets/` line (and any mkdir for it).
- `README.md:68-69`: replace the caveat with: assets live in `public/`; dev serves them at `/`; build/ssg copy them into `dist/`.

- [ ] **Step 3: docs**

`GettingStarted.md` — add a short section after the project-layout part:

```markdown
## Static assets

Files in `public/` are served from the site root: `public/favicon.svg`
is `/favicon.svg`, `public/fonts/Inter.woff2` is `/fonts/Inter.woff2`.
`swiftwui dev` serves them directly; `swiftwui build` and `swiftwui ssg`
copy them into `dist/`. The names `app`, `vendor`, `index.html`, and
`__swiftwui` are reserved at the top level of `public/`.

Reference assets with plain URLs — `Img(src: "/images/hero.webp", alt: "…",
width: 1200, height: 630)` — declare fonts with
`static var fontFaces: [FontFace]` on your `App`, and page-level `<link>`
tags (favicon, preload) with `var links: [LinkTag]` on a `Page`.
```

Tutorial chapter: find the chapter that documents project layout (`grep -rln "index.html" Sites/Tutorial/Sources/TutorialKit/Chapters/ | head`) and add one sentence + the `public/` line to its layout listing. Keep the edit minimal — one panel/paragraph, following the chapter's existing content-model style.

- [ ] **Step 4: verify Tutorial builds natively**

Run: `cd Sites/Tutorial && swift test 2>&1 | tail -3` (50 tests) and `swift run TutorialSite ssg --out /tmp/tut-dist 2>&1 | tail -3` if the ssg entry exists (check `Package.swift` for the product name; the phase-7 status memo says ssg output worked via `swift run`).
Expected: tests pass; ssg emits pages; `/tmp/tut-dist/assets/` NOT expected from the native run (the copy lives in the CLI command) — assets land via `swiftwui ssg`/`build`. Confirm `build-site.sh` still produces a complete site if it drives the CLI (read the script; if it calls `swift run … ssg` directly rather than `swiftwui ssg`, keep ONE `cp -R public/. dist/` line in the script instead of deleting — adjust to whichever binary the script actually invokes).

- [ ] **Step 5: root suite once more**

Run: `swift test 2>&1 | tail -3` — expected: PASS (docs/site changes shouldn't affect it; cheap insurance).

- [ ] **Step 6: Commit**

```bash
git add -A Sites/Tutorial Sources/SwiftWUI/SwiftWUI.docc/GettingStarted.md
git commit -m "docs+site: migrate Tutorial to public/ convention, document static assets"
```

---

### Task 10: wasm gate + full verification

**Files:** none new — verification only (fix-forward anything it surfaces).

- [ ] **Step 1: native suite**

Run: `swift test 2>&1 | tail -5`
Expected: PASS, count ≥ 294 + new tests.

- [ ] **Step 2: wasm compile of the whole library**

Run: `swift build --swift-sdk swift-6.3.3-RELEASE_wasm --scratch-path .build-wasm-check 2>&1 | tail -5`
Expected: `Build complete!` — this compiles `SwiftWUIDOM` (setLinks, DOMRuntime fontFaces plumbing) which native `swift test` never touches. If the SDK id differs on this machine, get it from `swift sdk list` (must match host 6.3.3 exactly — CLAUDE.md).

- [ ] **Step 3: end-to-end smoke via CLI**

```bash
cd /tmp && rm -rf swui-assets-smoke && mkdir swui-assets-smoke && cd swui-assets-smoke
swift run --package-path <repo> swiftwui init Demo --template basic --swiftwui-path <repo>
cd Demo
echo "hello-asset" > public/hello.txt
swift run --package-path <repo> swiftwui build
test -f dist/hello.txt && test -f dist/favicon.svg && echo SMOKE-OK
```

Expected: `SMOKE-OK`. (Requires the wasm SDK; if the environment can't run the full wasm build, note it in the report and rely on Steps 1-2 + Task 3's unit tests.)

- [ ] **Step 4: Commit (only if fixes were needed)**

```bash
git add -A && git commit -m "fix: post-verification fixes for assets pipeline"
```

---

## Self-Review Notes

- Spec §1-§9 → Tasks: §1 (Task 3 guard + Task 2 ordering), §2 (Task 2), §3 (Task 1), §4 (Task 3), §5 (Task 4 + Task 9 docs), §6 (Tasks 5-6), §7 (Task 7, per amended spec — App.fontFaces), §8 (Task 8), §9 tests distributed per task. Out-of-scope items untouched.
- Line numbers reference the tree at commit b9312f3 — re-locate by content if drifted.
- Known intentional deviations from RFC/spec: `bytes=5-3` → 416 (documented in Task 1); srcset coarse sanitize (documented in Task 8).
