# Phase 6: Toolchain & CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `swiftwui` CLI (init/dev/build/ssg/serve) with a pure-Swift POSIX dev server, SSE-driven hot reload that preserves `@State` through the phase-5 snapshot machinery, three project templates (basic/mvvm/tca), build+deploy Dockerfiles — plus the phase-5 carry list as Task 1.

**Architecture:** New library target `SwiftWUIToolchain` holds all logic (HTTP server, SSE hub, mtime watcher, scaffolder, subprocess orchestration) so the native suite tests everything; the `swiftwui` executable is a thin swift-argument-parser shell. The CLI is a thin orchestrator (spec D7): builds go through the proven `swift package --swift-sdk … js` PackageToJS plugin, SSG through `swift run <App> ssg`. The dev server resolves the bundle's single bare import (`@bjorn3/browser_wasi_shim`) via a browser import map + a vendored shim — zero npm (spec D2/D10). Hot reload: watcher → rebuild → SSE `reload` → injected dev client asks the wasm runtime to write a snapshot to sessionStorage → `location.reload()` → `DOMRuntime` seeds `StateStore` from it (spec D4, §7).

**Tech Stack:** Swift 6.3.3, swift-testing (`@Test`/`#expect`), swift-argument-parser (new dep, approved D3), Foundation (Toolchain only), POSIX sockets, JavaScriptKit PackageToJS plugin, wasm SDK `swift-6.3.3-RELEASE_wasm`.

**Spec:** `docs/superpowers/specs/2026-07-05-phase6-toolchain-design.md` — read it before starting any task.

## Global Constraints

- Branch: `feature/fable-new-vision`.
- **New dependency (only one, approved):** `swift-argument-parser` `from: "1.3.0"`. Nothing else. No SwiftNIO.
- **Module rules:** `Sources/SwiftWUI` stays Foundation-free and keeps the absolute `Sendable` ban (`_InvalidateBox` exception stands). `Sources/SwiftWUIToolchain` is a NEW, separate domain: it may `import Foundation`, it does **not** set `defaultIsolation(MainActor.self)`, it uses blocking threads (no async/await), and `@unchecked Sendable` is permitted **there only**, each use carrying a one-line justification comment. `SwiftWUIDOM` changes (Task 9) follow all existing framework rules.
- Everything in framework targets `@MainActor` via target default isolation, as before.
- Testing workflow (user preference, overrides RED/GREEN stepping): write ALL of a task's code first, run `swift test` ONCE at the end, fix, commit. Every commit message ends with:

  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  ```
- Native gate: `swift test` from repo root. 260 `@Test` markers / 259 passing cases at plan start; every task leaves the suite green (ZERO failures — per-task counts are estimates).
- Wasm gates (Tasks 9 and 12): `cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug`, same from `Examples/TodoMVC`. Toolchain/CLI tasks (2–8, 10–11) never touch wasm-visible code; Task 9 does.
- CLI UX: errors to stderr via `FileHandle.standardError`, non-zero exit on failure, subprocess exit codes surface verbatim.
- Dev server binds `127.0.0.1` ONLY. Static handlers MUST guard path traversal (resolve + prefix check) — this is a trust boundary even on localhost.
- Templates and vendored shim live as SwiftPM resources of `SwiftWUIToolchain` (`.copy("Resources")`, accessed via `Bundle.module`).
- Reserved URL namespace: `/__swiftwui/*`. sessionStorage key: `__swiftwui_dev_snapshot`. Dev flag global: `window.__swiftwui_dev`.

## File Structure

New:

| File | Target | Task | Responsibility |
|---|---|---|---|
| `Sources/SwiftWUIToolchain/ProcessRunner.swift` | SwiftWUIToolchain (new) | 2 | subprocess protocol + Foundation impl + errors |
| `Sources/SwiftWUIToolchain/ToolchainResources.swift` | SwiftWUIToolchain | 2 | Bundle.module resource access |
| `Sources/SwiftWUIToolchain/Resources/vendor/wasi-shim/*` | resources | 2 | vendored browser_wasi_shim 0.3.0 (7 js + 2 licenses) |
| `Sources/SwiftWUIToolchain/HTTPServer.swift` | SwiftWUIToolchain | 3 | POSIX HTTP/1.1 server, MIME, static files |
| `Sources/SwiftWUIToolchain/SSEHub.swift` | SwiftWUIToolchain | 4 | SSE client registry + broadcast |
| `Sources/SwiftWUIToolchain/DevInjection.swift` | SwiftWUIToolchain | 4 | dev-client + flag injection into index.html |
| `Sources/SwiftWUIToolchain/Resources/dev-client.js` | resources | 4 | EventSource client, overlay, snapshot request |
| `Sources/SwiftWUIToolchain/FileWatcher.swift` | SwiftWUIToolchain | 5 | mtime polling + debounce |
| `Sources/SwiftWUIToolchain/WasmBuild.swift` | SwiftWUIToolchain | 6 | SDK detect, PackageToJS invocation, dist layout |
| `Sources/SwiftWUIToolchain/DevSession.swift` | SwiftWUIToolchain | 7 | rebuild-and-notify glue, last-error memory |
| `Sources/SwiftWUIToolchain/PackageInfo.swift` | SwiftWUIToolchain | 8 | `swift package describe` product resolution |
| `Sources/SwiftWUIToolchain/Scaffolder.swift` | SwiftWUIToolchain | 10 | template copy + {{NAME}} substitution |
| `Sources/SwiftWUIToolchain/Resources/templates/{basic,mvvm,tca}/*` | resources | 10, 11 | project templates |
| `Sources/swiftwui/SwiftWUICommand.swift` | swiftwui (new) | 2 | root command; subcommands added per task |
| `Sources/swiftwui/Commands/*.swift` | swiftwui | 6–10 | one file per subcommand |
| `Sources/SwiftWUIDOM/DevReload.swift` | SwiftWUIDOM | 9 | dev snapshot save + assemble (wasm-only) |
| `Tests/SwiftWUITests/Toolchain*.swift` | tests | 3–10 | server/watcher/scaffold/build tests |

Modified: `Package.swift` (Task 2); carry-list files per Task 1 (`Sources/SwiftWUIStatic/StaticSite.swift`, `Sources/SwiftWUIStatic/DocumentSerializer.swift`, `Sources/SwiftWUIDOM/SnapshotBoot.swift`, `Sources/SwiftWUI/Render/AdoptingBackend.swift`, `Sources/SwiftWUI/Render/RendererBackend.swift` + `MockBackend.swift` + `Sources/SwiftWUIDOM/DOMBackend.swift`, `Sources/SwiftWUI/State/StateStore.swift`, `Sources/SwiftWUI/Effects/EffectStore.swift`, `Sources/SwiftWUI/HTML/Tags*.swift`, `Sources/SwiftWUI/Routing/Page.swift`); `Sources/SwiftWUIDOM/DOMRuntime.swift` + `SnapshotBoot.swift` (Task 9); spec file (Task 10 amendments).

---

### Task 1: Phase-5 carry list

Twelve items from `.superpowers/sdd/progress.md`. All native; no wasm gate needed except the SnapshotBoot edit compiles only under `#if arch(wasm32)` (Task 12's wasm gate covers it).

**Files:**
- Modify: `Sources/SwiftWUIStatic/StaticSite.swift` (items 1, 2, 8)
- Modify: `Sources/SwiftWUIStatic/DocumentSerializer.swift` (item 2)
- Modify: `Sources/SwiftWUIDOM/SnapshotBoot.swift` (item 3)
- Modify: `Sources/SwiftWUI/Core/Primitives.swift` + `Sources/SwiftWUI/HTML/Tags*.swift` (item 4)
- Modify: `Sources/SwiftWUI/Render/AdoptingBackend.swift` (item 7)
- Modify: `Sources/SwiftWUI/State/StateStore.swift`, `Sources/SwiftWUI/Effects/EffectStore.swift` (item 8)
- Modify: `Sources/SwiftWUI/HTML/Tags+Table.swift` (items 5, 9), `Sources/SwiftWUI/Routing/Page.swift` (item 10), `Sources/SwiftWUI/Routing/RoutePattern.swift` + `Sources/SwiftWUI/Render/AdoptingBackend.swift` + `Sources/SwiftWUI/Effects/EffectStore.swift` (item 6 doc comments)
- Modify: `Sources/SwiftWUI/Render/RendererBackend.swift`, `Sources/SwiftWUI/Render/MockBackend.swift`, `Sources/SwiftWUI/Render/AdoptingBackend.swift`, `Sources/SwiftWUIDOM/DOMBackend.swift` (item 11 removal)
- Test: `Tests/SwiftWUITests/StaticSiteTests.swift`, `Tests/SwiftWUITests/HTMLRendererTests.swift`, `Tests/SwiftWUITests/AdoptionTests.swift` (append), new `Tests/SwiftWUITests/ExitTests.swift` (item 12)

**Interfaces:**
- Produces: `StaticSiteReport.unmatchedPaths: [String]`; `StateStore._writeObserver: ((NodeIdentity) -> Void)?`; `EffectStore._buildWrites: [String: Set<String>]` (task key → canonical identity strings written during that task's drain). Later tasks don't consume these; templates (Task 10) rely on the unchanged `StaticSite.generate` signature.

- [ ] **Step 1: `unmatchedPaths` + static-pattern claiming** — rework the enumeration loop (`StaticSite.swift:59-71`). Static patterns claim their own path so a redundant `config.paths` listing no longer double-renders; unclaimed paths surface in the report:

```swift
var claimed = Set<String>()
var pagePaths: [String] = []
var skipped: [String] = []
for pattern in patterns {
    if pattern.isStatic {
        pagePaths.append(pattern.raw)
        claimed.insert(RoutePattern.normalizePath(pattern.raw))   // M3: static pattern claims its exact path
    } else {
        let matching = config.paths.filter {
            pattern.match($0) != nil && !claimed.contains(RoutePattern.normalizePath($0))
        }
        if matching.isEmpty { skipped.append(pattern.raw) }
        else {
            pagePaths.append(contentsOf: matching)
            claimed.formUnion(matching.map(RoutePattern.normalizePath))
        }
    }
}
let unmatched = config.paths.filter { !claimed.contains(RoutePattern.normalizePath($0)) }   // M2
```

Add to `StaticSiteReport` (declaration default keeps existing call sites compiling):

```swift
/// config.paths entries no pattern claimed — typos or dead config (final-review M2).
public var unmatchedPaths: [String] = []
```

and set it in `generate`. If `normalizePath` is internal to `RoutePattern`, it already is `static` (phase-5 Task 1) — call as shown.

- [ ] **Step 2: `cssFile` relative href** — `StaticSite.swift:212` hard-codes `cssHref: "/styles.css"` (root-absolute; breaks subdirectory deploys). Compute per page from the emitted file's directory depth. Locate the page-write site (the loop writing `<page>/index.html` under `outDir`) and pass the page's relative file path into a helper:

```swift
/// "styles.css" for the root page, "../../styles.css" for /todo/1/index.html, etc.
static func cssHref(forPageFile relPath: String) -> String {
    let dirDepth = relPath.split(separator: "/").dropLast().count
    return String(repeating: "../", count: dirDepth) + "styles.css"
}
```

Use the SAME relative path string the writer builds for the output file. `DocumentSerializer` (lines 42-43) is unchanged — it already emits whatever href it is given.

- [ ] **Step 3: UInt64 > 2^53 snapshot degrade** — `SnapshotBoot.swift` `JSONValue` decodes `Int64` then falls to `Double` (lines 49-52); values in `(Int64.max, UInt64.max]` lose precision. Add a `UInt64` branch between them:

```swift
case uint(UInt64)          // new enum case
// in init(from:): after the Int64 attempt, before Double:
} else if let u = try? c.decode(UInt64.self) {
    self = .uint(u)
// in `serialized`:
case .uint(let u): return String(u)
```

- [ ] **Step 4: EmptyTag convenience sweep** — `Div` already has the no-child convenience (`Tags.swift:11-14`, `Content == EmptyTag`). Grep `Sources/SwiftWUI/HTML/Tags*.swift` for container tags whose only init requires a `@TagBuilder content:` closure and add the same-shaped convenience for each (same attribute parameters, body `self.init(... ) { EmptyTag() }`). Expected set includes at least `Ul`, `Ol`, `Section`, `Main`, `Header`, `Footer`, `Nav`, `Article`, `Aside`, `Span`, `P` — the compiler and grep are the source of truth. Pattern (copy Div's):

```swift
extension Ul where Content == EmptyTag {
    public init(id: String? = nil, class: String? = nil) {
        self.init(id: id, class: `class`) { EmptyTag() }
    }
}
```

- [ ] **Step 5: Progress/Meter golden** — no production change (attributes already emit via `String(value)`, `Tags+Table.swift:237-268`); pin the format in `HTMLRendererTests.swift`:

```swift
@Test func progressAndMeterDoubleAttributes() {
    #expect(render(Progress(value: 0.5, max: 2)) == #"<progress value="0.5" max="2.0"></progress>"#)
    #expect(render(Meter(value: 0.7, min: 0, max: 1)) == #"<meter value="0.7" min="0.0" max="1.0"></meter>"#)
}
```

(Adjust expected strings to the helper `render` used by neighboring tests in that file; the pinned fact is `String(Double)` formatting, e.g. `"2.0"`.)

- [ ] **Step 6: public-name convention decision** — decision: `RoutePattern`, `AdoptingBackend`, `EffectStore` STAY public with clean names; they are real integration surface (SSG drivers, custom backends, effect SPI). Record it as doc comments on each type declaration:

```swift
/// Public API by decision (phase-6): part of the SSG/backend integration surface,
/// not an underscored SPI. Members prefixed `_` remain SPI.
```

- [ ] **Step 7: hydration-mismatch diagnostic (parser normalization)** — the "traps" are `AdoptingBackend.fail()`'s bare `assertionFailure` firing on browser parser normalization. Make the diagnostic explanatory and non-trapping in release. Change `fail()` (AdoptingBackend.swift:52-60) to take context and always print before the debug assert:

```swift
func fail(expected: String = "?", found: String = "?") {
    guard !failed else { return }
    failed = true
    let msg = """
    SwiftWUI hydration mismatch at stream index \(cursor)/\(stream.count): \
    expected <\(expected)>, found <\(found)>. Common causes (browser parser \
    normalization): <table> without explicit Tbody (parser auto-inserts tbody); \
    text nodes split across component boundaries; children inside Iframe \
    (parser drops them). Falling back to a cold render.
    """
    print("[SwiftWUI] " + msg)                        // non-trapping diagnostic, all builds
    if _assertOnMismatch { assertionFailure(msg) }    // debug trap preserved
    // existing deactivation logic unchanged
}
```

Update the call sites (`nextAdopted` mismatch, cursor overrun, wrong-parent insert, leftover finish) to pass what they know (tag names / "end of stream" / "leftover nodes"). Add the three normalization cases to the type's doc comment. Update any test asserting the old message text.

- [ ] **Step 8: I3 residual — row-diff write-tracking** — replace the path-prefix heuristic (`StaticSite.swift:182-205`) with real write attribution. Three seams:

`StateStore` — an observer tap on state writes (the didSet-invalidation path already flows through `link`'s invalidate wrapper; call the observer alongside it):

```swift
/// SSG build-task write attribution (phase-6 I3): set during _drainBuildTasks only.
public var _writeObserver: ((NodeIdentity) -> Void)? = nil
```

In `link(...)`, where the store wraps/installs the invalidate closure for identity `id`, also invoke `_writeObserver?(id)` inside that wrapper (one line — writes during build-task drain get attributed; nil observer is free).

`EffectStore._drainBuildTasks` — record writes per task key around each awaited task:

```swift
public private(set) var _buildWrites: [String: Set<String>] = [:]
// inside the drain loop, for task with canonical key `key`:
var written = Set<String>()
store._writeObserver = { id in if let k = id._canonicalString { written.insert(k) } }
await task()                     // existing await
store._writeObserver = nil
_buildWrites[key, default: []].formUnion(written)
```

(`EffectStore` needs the store reference at drain time — pass it as a parameter to `_drainBuildTasks` if it doesn't already have it; follow the existing drain signature.)

`StaticSite` — replace `hasMatchingRow` filtering with:

```swift
let encoded = Set(rows.keys)   // canonical strings of rows that made the snapshot
let tasks = runtime._effects._completedBuildKeys.filter { key in
    let writes = runtime._effects._buildWrites[key] ?? []
    let ok = writes.isSubset(of: encoded)   // every written row survived encoding
    #if DEBUG
    if !ok { print("SwiftWUI SSG: loader result at '\(key)' not serializable — client will re-run it") }
    #endif
    return ok
}
```

Keep the existing warning text. Delete `rowPaths`/`hasMatchingRow`.

- [ ] **Step 9: docs — Select(value:) inertness + Page.title × staticTask** — append to the `Select(value:)` doc comment (`Tags+Table.swift:169-170`):

```swift
/// PRERENDER NOTE: in SSG output the selection lives in the DOM `value`
/// property, which serializes to nothing — a prerendered page shows the
/// browser-default option until hydration seeds the binding.
```

Append to `Page.title` doc (`Page.swift:43-45` block):

```swift
/// STATIC-SITE NOTE: `title` is captured when the route resolves — before
/// `.staticTask` loaders run — so a title computed from loader-filled @State
/// renders its initial value in SSG output (ledgered phase-6 ticket).
```

- [ ] **Step 10: remove unused `textContent` read-API** — delete `func textContent(of node: HostNode) -> String` from `RendererBackend.swift:37` and its three conformances (`MockBackend.swift:76`, `AdoptingBackend.swift:125`, `DOMBackend.swift:186-187`). Grep confirmed zero protocol callers (`SnapshotBoot` reads `.textContent` off JSObject directly, not via the protocol). Note the spec deviation in the commit message (phase-5 spec mandated it; phase-6 decision: trim).

- [ ] **Step 11: two-Router exit test** — new `Tests/SwiftWUITests/ExitTests.swift` using swift-testing exit tests (toolchain 6.3.3 supports them on macOS):

```swift
import Testing
@testable import SwiftWUI

@Suite struct ExitTests {
    @Test func twoRoutersTrapInDebug() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                struct TwoRouters: Tag {
                    var body: some Tag {
                        Router { Route("/") { P { "a" } } }
                        Router { Route("/") { P { "b" } } }
                    }
                }
                let backend = MockBackend()
                let runtime = Runtime(app: TwoRouters(), backend: backend)
                runtime.mount()   // ctx.routerCount == 2 → assert (Router.swift:23)
            }
        }
    }
}
```

Adapt the mount incantation to whatever `RuntimeE2ETests.swift` uses to boot a runtime (do NOT invent a new harness — copy its setup lines). If exit tests prove unrunnable in this configuration (e.g. process-spawn restriction), delete the file and instead extend the Router.swift comment: `// exit-test infra evaluated phase-6: not viable in-suite; release both-resolve degrade stays documented` — that closes item 12 as a decision either way.

- [ ] **Step 12: run the whole suite once** — `swift test` from repo root. Expected: zero failures (~265+ passing — new tests from steps 1, 5, 7, 8, 11 add to 259).

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "fix(phase6): phase-5 carry list — unmatchedPaths, relative cssFile href, UInt64 snapshot, EmptyTag sweep, mismatch diagnostic, I3 write-tracking, docs, textContent trim, exit test"
```

---

### Task 2: Package targets, ProcessRunner, CLI skeleton, vendored shim

**Files:**
- Modify: `Package.swift`
- Create: `Sources/SwiftWUIToolchain/ProcessRunner.swift`
- Create: `Sources/SwiftWUIToolchain/ToolchainResources.swift`
- Create: `Sources/SwiftWUIToolchain/Resources/vendor/wasi-shim/` (copied files)
- Create: `Sources/swiftwui/SwiftWUICommand.swift`
- Test: `Tests/SwiftWUITests/ToolchainResourceTests.swift`

**Interfaces:**
- Produces: `protocol ProcessRunner { func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult }`; `struct ProcessResult { var exitCode: Int32; var stdout: String; var stderr: String }`; `struct FoundationProcessRunner: ProcessRunner`; `enum ToolchainError: Error, CustomStringConvertible` (cases below); `enum ToolchainResources { static var root: URL; static func url(_ rel: String) -> URL }`. All later Toolchain tasks consume these.

- [ ] **Step 1: Package.swift** — add the dependency and both targets; wire tests:

```swift
dependencies: [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
],
// products: add
.executable(name: "swiftwui", targets: ["swiftwui"]),
// targets: add
.target(name: "SwiftWUIToolchain",
        resources: [.copy("Resources")]),
.executableTarget(name: "swiftwui", dependencies: [
    "SwiftWUIToolchain",
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
]),
// testTarget dependencies: append "SwiftWUIToolchain"
```

Note: NO `defaultIsolation(MainActor.self)` on either new target (Global Constraints).

- [ ] **Step 2: vendor the shim** — copy from the existing checkout (version 0.3.0, matches spec D10):

```bash
mkdir -p Sources/SwiftWUIToolchain/Resources/vendor/wasi-shim
cp Examples/Counter/node_modules/@bjorn3/browser_wasi_shim/dist/*.js Sources/SwiftWUIToolchain/Resources/vendor/wasi-shim/
cp Examples/Counter/node_modules/@bjorn3/browser_wasi_shim/LICENSE-MIT Sources/SwiftWUIToolchain/Resources/vendor/wasi-shim/
cp Examples/Counter/node_modules/@bjorn3/browser_wasi_shim/LICENSE-APACHE Sources/SwiftWUIToolchain/Resources/vendor/wasi-shim/
```

Expect 7 `.js` files (`index.js`, `wasi.js`, `wasi_defs.js`, `fd.js`, `fs_mem.js`, `fs_opfs.js`, `strace.js`, `debug.js` — 8 if debug.js counted) + 2 licenses. Do NOT copy `tsconfig.tsbuildinfo`. `index.js` is the ESM entry the import map targets; its relative sibling imports are why the whole dist ships.

- [ ] **Step 3: ProcessRunner.swift**

```swift
import Foundation

public struct ProcessResult {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String
    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode; self.stdout = stdout; self.stderr = stderr
    }
}

public protocol ProcessRunner {
    /// Runs `executable` (resolved via /usr/bin/env) with `arguments` in `cwd`.
    /// streamOutput: echo child output to our stdout/stderr as it completes.
    @discardableResult
    func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult
}

public struct FoundationProcessRunner: ProcessRunner {
    public init() {}
    public func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = [executable] + arguments
        if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe
        try p.run()
        // ponytail: capture-then-print, no live streaming — dev rebuilds are seconds long
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(decoding: outData, as: UTF8.self)
        let err = String(decoding: errData, as: UTF8.self)
        if streamOutput {
            if !out.isEmpty { print(out, terminator: "") }
            if !err.isEmpty { FileHandle.standardError.write(Data(err.utf8)) }
        }
        return ProcessResult(exitCode: p.terminationStatus, stdout: out, stderr: err)
    }
}

public enum ToolchainError: Error, CustomStringConvertible {
    case noWasmSDK(hint: String)
    case buildFailed(output: String)
    case portInUse(UInt16)
    case notAProject(String)
    case targetExists(String)
    case invalidName(String)
    case productNotFound(String)
    case io(String)

    public var description: String {
        switch self {
        case .noWasmSDK(let hint): "no wasm Swift SDK installed. \(hint)"
        case .buildFailed(let output): "wasm build failed:\n\(output)"
        case .portInUse(let p): "port \(p) is already in use — pass --port to pick another"
        case .notAProject(let d): "'\(d)' does not look like a SwiftWUI project (no Package.swift)"
        case .targetExists(let d): "'\(d)' already exists and is not empty"
        case .invalidName(let n): "'\(n)' is not a valid project name (expected [A-Za-z][A-Za-z0-9_]*)"
        case .productNotFound(let d): "no executable product found in '\(d)' — pass --product"
        case .io(let m): m
        }
    }
}
```

- [ ] **Step 4: ToolchainResources.swift**

```swift
import Foundation

public enum ToolchainResources {
    public static var root: URL {
        guard let url = Bundle.module.url(forResource: "Resources", withExtension: nil) else {
            fatalError("SwiftWUIToolchain resources missing from bundle")
        }
        return url
    }
    public static func url(_ rel: String) -> URL {
        root.appendingPathComponent(rel)
    }
}
```

- [ ] **Step 5: SwiftWUICommand.swift** — root command only; subcommands land in their tasks:

```swift
import ArgumentParser

@main
struct SwiftWUICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftwui",
        abstract: "SwiftWUI toolchain: scaffold, develop, build and prerender SwiftWUI sites.",
        version: "0.6.0",
        subcommands: [])
}
```

- [ ] **Step 6: resource test** — `Tests/SwiftWUITests/ToolchainResourceTests.swift`:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainResourceTests {
    @Test func vendoredShimShipsESMEntryAndLicenses() throws {
        let dir = ToolchainResources.url("vendor/wasi-shim")
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names.contains("index.js"))
        #expect(names.contains("wasi.js"))          // sibling import of index.js
        #expect(names.contains("LICENSE-MIT"))
        #expect(names.contains("LICENSE-APACHE"))
        #expect(!names.contains("tsconfig.tsbuildinfo"))
        let entry = try String(contentsOf: dir.appendingPathComponent("index.js"), encoding: .utf8)
        #expect(entry.contains("./wasi.js"))        // relative sibling imports = must ship whole dist
    }
}
```

- [ ] **Step 7: run gates** — `swift build && swift test` (zero failures), then `swift run swiftwui --version` → prints `0.6.0`, `swift run swiftwui --help` → usage text.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(phase6): SwiftWUIToolchain + swiftwui targets, ProcessRunner, vendored wasi-shim resources"
```

---

### Task 3: HTTP server core

**Files:**
- Create: `Sources/SwiftWUIToolchain/HTTPServer.swift`
- Test: `Tests/SwiftWUITests/ToolchainHTTPTests.swift`

**Interfaces:**
- Produces: `struct HTTPRequest { var method: String; var path: String; var headers: [String: String] }` (path percent-decoded, query stripped; header keys lowercased); `struct HTTPResponse { var status: Int; var headers: [String: String]; var body: [UInt8]; var hijack: ((Int32) -> Void)? }` + statics `.text(_:status:contentType:)`, `.notFound()`, `.file(bytes:mime:)`; `typealias HTTPHandler = @Sendable (HTTPRequest) -> HTTPResponse?` (nil = fall through); `final class HTTPServer` with `init(handlers: [HTTPHandler])`, `func start(port: UInt16) throws` (0 = ephemeral), `var boundPort: UInt16`, `func stop()`; `enum MIME { static func type(forPath: String) -> String }`; `enum StaticFiles { static func handler(urlPrefix: String, root: String, spaFallback: Bool) -> HTTPHandler }`; `func writeAll(_ fd: Int32, _ bytes: [UInt8])` (SIGPIPE-safe).

- [ ] **Step 1: HTTPServer.swift** — full implementation:

```swift
import Foundation

public struct HTTPRequest {
    public var method: String
    public var path: String                    // percent-decoded, no query
    public var headers: [String: String]       // lowercased keys
}

public struct HTTPResponse {
    public var status: Int
    public var headers: [String: String]
    public var body: [UInt8]
    /// When set, the server writes status+headers, hands the socket over, and
    /// never closes it. Used by SSE (Task 4).
    public var hijack: ((Int32) -> Void)?

    public init(status: Int = 200, headers: [String: String] = [:], body: [UInt8] = [], hijack: ((Int32) -> Void)? = nil) {
        self.status = status; self.headers = headers; self.body = body; self.hijack = hijack
    }
    public static func text(_ s: String, status: Int = 200, contentType: String = "text/plain; charset=utf-8") -> HTTPResponse {
        HTTPResponse(status: status, headers: ["Content-Type": contentType], body: Array(s.utf8))
    }
    public static func notFound() -> HTTPResponse { .text("404 not found", status: 404) }
    public static func file(bytes: [UInt8], mime: String) -> HTTPResponse {
        HTTPResponse(status: 200, headers: ["Content-Type": mime], body: bytes)
    }
}

public typealias HTTPHandler = @Sendable (HTTPRequest) -> HTTPResponse?

public enum MIME {
    static let types: [String: String] = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8",
        "mjs": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
        "wasm": "application/wasm",              // load-bearing: streaming instantiation
        "json": "application/json", "map": "application/json",
        "svg": "image/svg+xml", "png": "image/png", "jpg": "image/jpeg",
        "jpeg": "image/jpeg", "ico": "image/x-icon", "txt": "text/plain; charset=utf-8",
    ]
    public static func type(forPath p: String) -> String {
        let ext = (p as NSString).pathExtension.lowercased()
        return types[ext] ?? "application/octet-stream"
    }
}

/// EPIPE-safe full write. macOS: SO_NOSIGPIPE is set per-socket at accept;
/// Linux would need MSG_NOSIGNAL — dev tool targets macOS/Linux, guard both.
public func writeAll(_ fd: Int32, _ bytes: [UInt8]) {
    var off = 0
    bytes.withUnsafeBufferPointer { buf in
        while off < buf.count {
            #if canImport(Glibc)
            let n = send(fd, buf.baseAddress! + off, buf.count - off, Int32(MSG_NOSIGNAL))
            #else
            let n = write(fd, buf.baseAddress! + off, buf.count - off)
            #endif
            if n <= 0 { return }
            off += n
        }
    }
}

/// Hand-rolled HTTP/1.1 server for the dev loop: 127.0.0.1 only, GET/HEAD only,
/// Connection: close, per-connection thread. ponytail: fine for one developer;
/// swap for NIO if this ever serves anything but localhost.
public final class HTTPServer: @unchecked Sendable {   // guarded by `lock`
    private let handlers: [HTTPHandler]
    private var listenFD: Int32 = -1
    private var running = false
    private let lock = NSLock()
    public private(set) var boundPort: UInt16 = 0

    public init(handlers: [HTTPHandler]) { self.handlers = handlers }

    public func start(port: UInt16) throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ToolchainError.io("socket() failed: errno \(errno)") }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))   // localhost ONLY
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0 else {
            close(fd)
            if errno == EADDRINUSE { throw ToolchainError.portInUse(port) }
            throw ToolchainError.io("bind() failed: errno \(errno)")
        }
        guard listen(fd, 16) == 0 else { close(fd); throw ToolchainError.io("listen() failed: errno \(errno)") }
        var bound = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &bound) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = getsockname(fd, $0, &len) }
        }
        lock.lock(); listenFD = fd; running = true; boundPort = UInt16(bigEndian: bound.sin_port); lock.unlock()
        let t = Thread { [weak self] in self?.acceptLoop(fd) }
        t.name = "swiftwui-http-accept"
        t.start()
    }

    public func stop() {
        lock.lock(); running = false; let fd = listenFD; listenFD = -1; lock.unlock()
        if fd >= 0 { close(fd) }
    }

    private var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }

    private func acceptLoop(_ fd: Int32) {
        while isRunning {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { continue }
            #if canImport(Darwin)
            var yes: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            #endif
            let t = Thread { [handlers] in Self.handle(client, handlers: handlers) }
            t.start()
        }
    }

    private static func handle(_ fd: Int32, handlers: [HTTPHandler]) {
        // Read until end of headers (16 KB cap — dev requests carry no bodies we care about).
        var raw: [UInt8] = []
        var buf = [UInt8](repeating: 0, count: 4096)
        while raw.count < 16_384 {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { break }
            raw.append(contentsOf: buf[0..<n])
            if raw.count >= 4, findHeaderEnd(raw) != nil { break }
        }
        guard let headerEnd = findHeaderEnd(raw) else { close(fd); return }
        let head = String(decoding: raw[..<headerEnd], as: UTF8.self)
        var lines = head.split(separator: "\r\n", omittingEmptySubsequences: false)[...]
        guard let requestLine = lines.popFirst() else { close(fd); return }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { close(fd); return }
        let method = String(parts[0])
        var target = String(parts[1])
        if let q = target.firstIndex(of: "?") { target = String(target[..<q]) }
        let path = target.removingPercentEncoding ?? target
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard method == "GET" || method == "HEAD" else {
            send(HTTPResponse.text("405 method not allowed", status: 405), to: fd, headOnly: false); close(fd); return
        }
        let request = HTTPRequest(method: method, path: path, headers: headers)
        var response: HTTPResponse = .notFound()
        for h in handlers { if let r = h(request) { response = r; break } }
        if let hijack = response.hijack {
            sendHead(response, to: fd, contentLength: nil)
            hijack(fd)                 // hijacker owns the fd now (SSE)
            return
        }
        send(response, to: fd, headOnly: method == "HEAD")
        close(fd)
    }

    private static func findHeaderEnd(_ raw: [UInt8]) -> Int? {
        let sep: [UInt8] = [13, 10, 13, 10]
        guard raw.count >= 4 else { return nil }
        for i in 0...(raw.count - 4) where Array(raw[i..<i+4]) == sep { return i }
        return nil
    }

    private static func sendHead(_ r: HTTPResponse, to fd: Int32, contentLength: Int?) {
        var head = "HTTP/1.1 \(r.status) \(r.status == 200 ? "OK" : "X")\r\n"
        var headers = r.headers
        if let contentLength { headers["Content-Length"] = String(contentLength) }
        headers["Connection"] = headers["Connection"] ?? (contentLength == nil ? "keep-alive" : "close")
        for (k, v) in headers { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        writeAll(fd, Array(head.utf8))
    }

    private static func send(_ r: HTTPResponse, to fd: Int32, headOnly: Bool) {
        sendHead(r, to: fd, contentLength: r.body.count)
        if !headOnly { writeAll(fd, r.body) }
    }
}

public enum StaticFiles {
    /// Serve files under `root` for URLs starting with `urlPrefix`.
    /// Directory / extensionless resolution: exact file → `<path>/index.html` →
    /// (spaFallback) `<root>/index.html` → nil (fall through).
    public static func handler(urlPrefix: String, root: String, spaFallback: Bool = false) -> HTTPHandler {
        let rootResolved = URL(fileURLWithPath: root).standardizedFileURL.path
        return { request in
            guard request.path.hasPrefix(urlPrefix) else { return nil }
            let rel = String(request.path.dropFirst(urlPrefix.count))
            func fileResponse(_ fsPath: String) -> HTTPResponse? {
                let resolved = URL(fileURLWithPath: fsPath).standardizedFileURL.path
                guard resolved.hasPrefix(rootResolved) else { return nil }   // traversal guard
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir) else { return nil }
                if isDir.boolValue { return fileResponse(resolved + "/index.html") }
                guard let data = FileManager.default.contents(atPath: resolved) else { return nil }
                return .file(bytes: Array(data), mime: MIME.type(forPath: resolved))
            }
            let candidate = rootResolved + "/" + rel
            if let r = fileResponse(candidate) { return r }
            if !rel.contains(".") , let r = fileResponse(candidate + "/index.html") { return r }
            if spaFallback, !rel.contains("."), let r = fileResponse(rootResolved + "/index.html") { return r }
            return nil
        }
    }
}
```

- [ ] **Step 2: tests** — `Tests/SwiftWUITests/ToolchainHTTPTests.swift`. Use `URLSession` against an ephemeral port; write fixture files into a temp dir:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainHTTPTests {
    func tempSite() throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-http-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir + "/sub", withIntermediateDirectories: true)
        try "<h1>home</h1>".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        try "body{}".write(toFile: dir + "/app.css", atomically: true, encoding: .utf8)
        try Data([0, 97, 115, 109]).write(to: URL(fileURLWithPath: dir + "/sub/app.wasm"))
        return dir
    }
    func get(_ port: UInt16, _ path: String) async throws -> (Int, [UInt8], [AnyHashable: Any]) {
        let (data, resp) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)\(path)")!)
        let http = resp as! HTTPURLResponse
        return (http.statusCode, Array(data), http.allHeaderFields)
    }

    @Test func servesFilesWithCorrectMIME() async throws {
        let dir = try tempSite()
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir)])
        try server.start(port: 0)
        defer { server.stop() }
        let (s1, b1, h1) = try await get(server.boundPort, "/index.html")
        #expect(s1 == 200 && String(decoding: b1, as: UTF8.self) == "<h1>home</h1>")
        #expect((h1["Content-Type"] as? String)?.hasPrefix("text/html") == true)
        let (_, _, h2) = try await get(server.boundPort, "/sub/app.wasm")
        #expect(h2["Content-Type"] as? String == "application/wasm")
        let (s3, _, _) = try await get(server.boundPort, "/nope.js")
        #expect(s3 == 404)
    }

    @Test func extensionlessResolvesDirectoryIndex() async throws {
        let dir = try tempSite()
        try FileManager.default.createDirectory(atPath: dir + "/about", withIntermediateDirectories: true)
        try "<h1>about</h1>".write(toFile: dir + "/about/index.html", atomically: true, encoding: .utf8)
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir)])
        try server.start(port: 0); defer { server.stop() }
        let (s, b, _) = try await get(server.boundPort, "/about")
        #expect(s == 200 && String(decoding: b, as: UTF8.self) == "<h1>about</h1>")
    }

    @Test func traversalIsBlocked() async throws {
        let dir = try tempSite()
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: dir + "/sub")])
        try server.start(port: 0); defer { server.stop() }
        let (s, _, _) = try await get(server.boundPort, "/%2e%2e/index.html")
        #expect(s == 404)   // ../index.html escapes root → guarded
    }

    @Test func portInUseThrows() throws {
        let a = HTTPServer(handlers: []); try a.start(port: 0); defer { a.stop() }
        let b = HTTPServer(handlers: [])
        #expect(throws: ToolchainError.self) { try b.start(port: a.boundPort) }
    }
}
```

- [ ] **Step 3: run suite once** — `swift test`. Zero failures.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(phase6): POSIX HTTP/1.1 dev server — static files, MIME, traversal guard, hijack seam"
```

---

### Task 4: SSE hub, dev client, index.html injection

**Files:**
- Create: `Sources/SwiftWUIToolchain/SSEHub.swift`
- Create: `Sources/SwiftWUIToolchain/DevInjection.swift`
- Create: `Sources/SwiftWUIToolchain/Resources/dev-client.js`
- Test: `Tests/SwiftWUITests/ToolchainSSETests.swift`

**Interfaces:**
- Consumes: `HTTPHandler`, `HTTPResponse.hijack`, `writeAll` (Task 3).
- Produces: `final class SSEHub { init(); func handler(lastError: @escaping () -> String?) -> HTTPHandler; func broadcast(event: String, data: String); var clientCount: Int }`; `enum DevInjection { static func inject(into html: String) -> String; static func jsonStringLiteral(_ s: String) -> String }`. Task 7 wires both.

- [ ] **Step 1: SSEHub.swift**

```swift
import Foundation

/// SSE over the hijack seam: plain HTTP stream, no upgrade handshake, and the
/// browser EventSource auto-reconnects after CLI restarts (spec D8).
public final class SSEHub: @unchecked Sendable {   // guarded by `lock`
    private let lock = NSLock()
    private var clients: [Int32] = []
    public init() {}

    public var clientCount: Int { lock.lock(); defer { lock.unlock() }; return clients.count }

    /// `lastError`: current build error, replayed to clients that connect mid-breakage.
    public func handler(lastError: @escaping @Sendable () -> String? = { nil }) -> HTTPHandler {
        { [self] request in
            guard request.path == "/__swiftwui/events" else { return nil }
            return HTTPResponse(
                status: 200,
                headers: ["Content-Type": "text/event-stream",
                          "Cache-Control": "no-cache",
                          "Connection": "keep-alive"],
                hijack: { fd in
                    if let err = lastError() {
                        writeAll(fd, Array("event: build-error\ndata: \(err)\n\n".utf8))
                    }
                    self.lock.lock(); self.clients.append(fd); self.lock.unlock()
                })
        }
    }

    /// data MUST be a single line (JSON-encode multiline payloads first).
    public func broadcast(event: String, data: String) {
        lock.lock(); let fds = clients; lock.unlock()
        let frame = Array("event: \(event)\ndata: \(data)\n\n".utf8)
        var dead: [Int32] = []
        for fd in fds {
            // writeAll swallows EPIPE; detect a closed peer via a non-blocking peek.
            writeAll(fd, frame)
            var one = [UInt8](repeating: 0, count: 1)
            let n = recv(fd, &one, 1, Int32(MSG_PEEK | MSG_DONTWAIT))
            if n == 0 { dead.append(fd) }              // orderly close by the browser
        }
        if !dead.isEmpty {
            lock.lock()
            clients.removeAll { dead.contains($0) }
            lock.unlock()
            for fd in dead { close(fd) }
        }
    }
}
```

- [ ] **Step 2: Resources/dev-client.js** — complete file:

```js
// SwiftWUI dev client — injected by `swiftwui dev`. Never shipped to production.
(() => {
  const es = new EventSource("/__swiftwui/events");
  es.addEventListener("reload", () => {
    try {
      // Synchronous: the wasm runtime writes the @State snapshot to
      // sessionStorage inside this dispatch (DevReload, spec §7).
      window.dispatchEvent(new CustomEvent("swiftwui:dev-snapshot-request"));
    } catch (e) { /* never block the reload */ }
    location.reload();
  });
  es.addEventListener("build-error", (e) => {
    let text = e.data;
    try { text = JSON.parse(e.data); } catch (_) {}
    showOverlay(text);
  });
  function showOverlay(text) {
    let el = document.getElementById("__swiftwui-error-overlay");
    if (!el) {
      el = document.createElement("pre");
      el.id = "__swiftwui-error-overlay";
      el.style.cssText =
        "position:fixed;inset:0;z-index:2147483647;margin:0;padding:24px;" +
        "overflow:auto;background:rgba(20,0,0,.92);color:#ff8080;" +
        "font:12px/1.5 ui-monospace,SFMono-Regular,monospace;white-space:pre-wrap";
      document.documentElement.appendChild(el);
    }
    el.textContent = "swiftwui build failed\n\n" + text;
  }
})();
```

- [ ] **Step 3: DevInjection.swift**

```swift
import Foundation

public enum DevInjection {
    /// The flag script MUST run before the app module loads — injection right
    /// after <head> guarantees it (module scripts are deferred by spec).
    static let snippet =
        #"<script>window.__swiftwui_dev = true;</script><script src="/__swiftwui/dev-client.js"></script>"#

    public static func inject(into html: String) -> String {
        if let range = html.range(of: "<head>", options: .caseInsensitive) {
            var out = html
            out.insert(contentsOf: snippet, at: range.upperBound)
            return out
        }
        return snippet + html   // headless documents: prepend (spec §6)
    }

    /// Single-line JSON string literal for SSE data frames.
    public static func jsonStringLiteral(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [s])
        guard let data, var text = String(data: data, encoding: .utf8) else { return "\"\"" }
        text.removeFirst()   // strip the array brackets: ["..."] → "..."
        text.removeLast()
        return text
    }
}
```

- [ ] **Step 4: tests** — `Tests/SwiftWUITests/ToolchainSSETests.swift`:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainSSETests {
    @Test func injectionAfterHeadAndHeadlessPrepend() {
        let doc = "<!doctype html>\n<html>\n<HEAD><title>x</title></HEAD><body></body></html>"
        let out = DevInjection.inject(into: doc)
        #expect(out.contains("<HEAD><script>window.__swiftwui_dev = true;"))
        let headless = "<p>hi</p>"
        #expect(DevInjection.inject(into: headless).hasPrefix("<script>window.__swiftwui_dev"))
    }

    @Test func jsonStringLiteralEscapes() {
        #expect(DevInjection.jsonStringLiteral("a\"b\nc") == #""a\"b\nc""#)
    }

    @Test func sseStreamDeliversBroadcast() async throws {
        let hub = SSEHub()
        let server = HTTPServer(handlers: [hub.handler()])
        try server.start(port: 0); defer { server.stop() }
        // Raw-socket client: URLSession buffers SSE; a plain socket shows frames as written.
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = server.boundPort.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        _ = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        writeAll(fd, Array("GET /__swiftwui/events HTTP/1.1\r\nHost: x\r\n\r\n".utf8))
        // Wait for the hub to register the client, then broadcast.
        for _ in 0..<100 where hub.clientCount == 0 { try await Task.sleep(nanoseconds: 10_000_000) }
        #expect(hub.clientCount == 1)
        hub.broadcast(event: "reload", data: "{}")
        var buf = [UInt8](repeating: 0, count: 4096)
        var received = ""
        for _ in 0..<100 {
            let n = recv(fd, &buf, buf.count, Int32(MSG_DONTWAIT))
            if n > 0 { received += String(decoding: buf[0..<n], as: UTF8.self) }
            if received.contains("event: reload\ndata: {}\n\n") { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        close(fd)
        #expect(received.contains("event: reload\ndata: {}\n\n"))
    }
}
```

- [ ] **Step 5: run suite once** — `swift test`. Zero failures.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase6): SSE hub, dev-client.js, index.html dev injection"
```

---

### Task 5: File watcher

**Files:**
- Create: `Sources/SwiftWUIToolchain/FileWatcher.swift`
- Test: `Tests/SwiftWUITests/ToolchainWatcherTests.swift`

**Interfaces:**
- Produces: `final class FileWatcher { init(root: String); func changed() -> Bool }` — scans `Sources/**/*.swift` + `Package.swift` + `index.html` under `root`, compares mtimes+file-set to the previous scan, updates the baseline. Threading/debounce live in the dev loop (Task 7), not here — the watcher stays synchronously testable.

- [ ] **Step 1: FileWatcher.swift**

```swift
import Foundation

/// mtime polling — cross-platform by construction, no FSEvents/inotify forks (spec D9).
public final class FileWatcher {
    private let root: String
    private var baseline: [String: Date] = [:]
    public init(root: String) {
        self.root = root
        baseline = scan()
    }

    func scan() -> [String: Date] {
        var result: [String: Date] = [:]
        let fm = FileManager.default
        func stat(_ path: String) {
            if let mtime = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date {
                result[path] = mtime
            }
        }
        stat(root + "/Package.swift")
        stat(root + "/index.html")
        if let e = fm.enumerator(atPath: root + "/Sources") {
            for case let rel as String in e where rel.hasSuffix(".swift") {
                stat(root + "/Sources/" + rel)
            }
        }
        return result
    }

    /// True when anything changed since the last call (file edited, added, or removed).
    public func changed() -> Bool {
        let now = scan()
        defer { baseline = now }
        return now != baseline
    }
}
```

- [ ] **Step 2: tests** — `Tests/SwiftWUITests/ToolchainWatcherTests.swift`:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainWatcherTests {
    func tempProject() throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-watch-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir + "/Sources", withIntermediateDirectories: true)
        try "// v1".write(toFile: dir + "/Sources/main.swift", atomically: true, encoding: .utf8)
        try "// pkg".write(toFile: dir + "/Package.swift", atomically: true, encoding: .utf8)
        return dir
    }

    @Test func detectsEditAddRemoveOnce() throws {
        let dir = try tempProject()
        let w = FileWatcher(root: dir)
        #expect(!w.changed())                                     // quiescent
        try "// v2".write(toFile: dir + "/Sources/main.swift", atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(2)],
                                              ofItemAtPath: dir + "/Sources/main.swift")
        #expect(w.changed())                                      // edit seen
        #expect(!w.changed())                                     // consumed
        try "// new".write(toFile: dir + "/Sources/extra.swift", atomically: true, encoding: .utf8)
        #expect(w.changed())                                      // add seen
        try FileManager.default.removeItem(atPath: dir + "/Sources/extra.swift")
        #expect(w.changed())                                      // remove seen
    }

    @Test func ignoresNonSwiftNoise() throws {
        let dir = try tempProject()
        let w = FileWatcher(root: dir)
        try "x".write(toFile: dir + "/Sources/notes.txt", atomically: true, encoding: .utf8)
        #expect(!w.changed())
    }
}
```

(The explicit `setAttributes` mtime bump dodges filesystem mtime granularity — do the same anywhere a test edits and immediately expects detection.)

- [ ] **Step 3: run suite once** — `swift test`. Zero failures.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(phase6): mtime-polling file watcher"
```

---

### Task 6: SDK detection, wasm build orchestration, `swiftwui build`

**Files:**
- Create: `Sources/SwiftWUIToolchain/WasmBuild.swift`
- Create: `Sources/swiftwui/Commands/BuildCommand.swift`
- Modify: `Sources/swiftwui/SwiftWUICommand.swift` (register subcommand)
- Test: `Tests/SwiftWUITests/ToolchainBuildTests.swift`

**Interfaces:**
- Consumes: `ProcessRunner`, `ToolchainError`, `ToolchainResources` (Task 2).
- Produces: `enum WasmSDK { static let pinned = "swift-6.3.3-RELEASE_wasm"; static func detect(runner: ProcessRunner) throws -> String }`; `struct WasmBuilder { var runner: ProcessRunner; var projectDir: String; var sdk: String; func build(configuration: String) throws -> String }` (returns bundle dir); `enum DistLayout { static func assemble(projectDir: String, bundleDir: String, outDir: String) throws }`. Tasks 7–8 consume all three.

- [ ] **Step 1: WasmBuild.swift**

```swift
import Foundation

public enum WasmSDK {
    /// Repo pin (CLAUDE.md): host toolchain and SDK versions must match exactly.
    public static let pinned = "swift-6.3.3-RELEASE_wasm"

    public static func detect(runner: ProcessRunner) throws -> String {
        let r = try runner.run("swift", ["sdk", "list"], cwd: nil, streamOutput: false)
        let ids = r.stdout.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        if ids.contains(pinned) { return pinned }
        if let id = ids.first(where: { $0.contains("wasm") && !$0.contains("embedded") }) { return id }
        throw ToolchainError.noWasmSDK(hint:
            "Install the Swift.org WASM SDK matching your toolchain exactly (expected \(pinned)): " +
            "see the Swift SDK bundles on swift.org/download, then `swift sdk install <artifactbundle url>`.")
    }
}

public struct WasmBuilder {
    public var runner: ProcessRunner
    public var projectDir: String
    public var sdk: String
    public init(runner: ProcessRunner, projectDir: String, sdk: String) {
        self.runner = runner; self.projectDir = projectDir; self.sdk = sdk
    }

    /// Runs the JavaScriptKit PackageToJS plugin; returns the bundle directory.
    public func build(configuration: String) throws -> String {
        let r = try runner.run("swift", ["package", "--swift-sdk", sdk, "js", "-c", configuration],
                               cwd: projectDir, streamOutput: true)
        guard r.exitCode == 0 else { throw ToolchainError.buildFailed(output: r.stdout + r.stderr) }
        return projectDir + "/.build/plugins/PackageToJS/outputs/Package"
    }
}

public enum DistLayout {
    /// dist/index.html + dist/app/ (bundle verbatim) + dist/vendor/wasi-shim/ (spec §4).
    /// Shim source: the project's checked-in vendor/ dir (scaffolded by init, Task 10),
    /// falling back to the CLI's bundled resources for non-scaffolded projects.
    public static func assemble(projectDir: String, bundleDir: String, outDir: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectDir + "/index.html") else {
            throw ToolchainError.notAProject(projectDir)
        }
        try? fm.removeItem(atPath: outDir + "/app")
        try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try fm.copyItem(atPath: bundleDir, toPath: outDir + "/app")
        try? fm.removeItem(atPath: outDir + "/index.html")
        try fm.copyItem(atPath: projectDir + "/index.html", toPath: outDir + "/index.html")
        let projectShim = projectDir + "/vendor/wasi-shim"
        let shimSource = fm.fileExists(atPath: projectShim)
            ? projectShim
            : ToolchainResources.url("vendor/wasi-shim").path
        try? fm.removeItem(atPath: outDir + "/vendor/wasi-shim")
        try fm.createDirectory(atPath: outDir + "/vendor", withIntermediateDirectories: true)
        try fm.copyItem(atPath: shimSource, toPath: outDir + "/vendor/wasi-shim")
    }
}
```

- [ ] **Step 2: BuildCommand.swift**

```swift
import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build the wasm bundle and assemble dist/ (index.html + app/ + vendor/).")

    // `configuration` collides with ParsableCommand's static — store under `config`,
    // expose the conventional -c/--configuration surface via custom names.
    @Option(name: [.customShort("c"), .customLong("configuration")], help: "Build configuration.")
    var config: String = "release"
    @Option(name: .long, help: "Output directory.") var out: String = "dist"
    @Option(name: .long, help: "Swift SDK id (default: auto-detect).") var swiftSdk: String?

    func run() throws {
        let runner = FoundationProcessRunner()
        let cwd = FileManager.default.currentDirectoryPath
        let sdk = try swiftSdk ?? WasmSDK.detect(runner: runner)
        let bundle = try WasmBuilder(runner: runner, projectDir: cwd, sdk: sdk)
            .build(configuration: config)
        try DistLayout.assemble(projectDir: cwd, bundleDir: bundle, outDir: cwd + "/" + out)
        print("built \(out)/ (app bundle + vendor shim + index.html)")
    }
}
```

Register in `SwiftWUICommand.configuration`: `subcommands: [Build.self]`. (Each later task appends its subcommand to this array.)

- [ ] **Step 3: tests** — `Tests/SwiftWUITests/ToolchainBuildTests.swift` with a mock runner:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

struct MockRunner: ProcessRunner {
    var results: [String: ProcessResult]   // key: executable + " " + joined args prefix
    var recorded: (([String]) -> Void)? = nil
    func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult {
        recorded?([executable] + arguments)
        for (prefix, result) in results where ([executable] + arguments).joined(separator: " ").hasPrefix(prefix) {
            return result
        }
        return ProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
}

@Suite struct ToolchainBuildTests {
    @Test func sdkDetectPrefersPinnedAndSkipsEmbedded() throws {
        let both = MockRunner(results: ["swift sdk list": .init(
            exitCode: 0, stdout: "swift-6.3.3-RELEASE_wasm\nswift-6.3.3-RELEASE_wasm-embedded\n", stderr: "")])
        #expect(try WasmSDK.detect(runner: both) == "swift-6.3.3-RELEASE_wasm")
        let other = MockRunner(results: ["swift sdk list": .init(
            exitCode: 0, stdout: "swift-7.0-RELEASE_wasm-embedded\nswift-7.0-RELEASE_wasm\n", stderr: "")])
        #expect(try WasmSDK.detect(runner: other) == "swift-7.0-RELEASE_wasm")
        let none = MockRunner(results: ["swift sdk list": .init(exitCode: 0, stdout: "\n", stderr: "")])
        #expect(throws: ToolchainError.self) { try WasmSDK.detect(runner: none) }
    }

    @Test func buildFailurePropagatesCompilerOutput() {
        let runner = MockRunner(results: ["swift package": .init(exitCode: 1, stdout: "", stderr: "error: kaputt")])
        let builder = WasmBuilder(runner: runner, projectDir: "/tmp/x", sdk: WasmSDK.pinned)
        do { _ = try builder.build(configuration: "debug"); Issue.record("expected throw") }
        catch let e as ToolchainError {
            guard case .buildFailed(let out) = e else { return Issue.record("wrong case") }
            #expect(out.contains("error: kaputt"))
        } catch { Issue.record("wrong error") }
    }

    @Test func distLayoutAssembles() throws {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-dist-\(UUID().uuidString)"
        let bundle = proj + "/fakebundle"
        try fm.createDirectory(atPath: bundle, withIntermediateDirectories: true)
        try "<head></head>".write(toFile: proj + "/index.html", atomically: true, encoding: .utf8)
        try "js".write(toFile: bundle + "/index.js", atomically: true, encoding: .utf8)
        try DistLayout.assemble(projectDir: proj, bundleDir: bundle, outDir: proj + "/dist")
        #expect(fm.fileExists(atPath: proj + "/dist/index.html"))
        #expect(fm.fileExists(atPath: proj + "/dist/app/index.js"))
        #expect(fm.fileExists(atPath: proj + "/dist/vendor/wasi-shim/index.js"))   // resource fallback
    }
}
```

- [ ] **Step 4: run suite once** — `swift test`. Zero failures. Then smoke the CLI surface: `swift run swiftwui build --help` prints options.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(phase6): SDK detection, PackageToJS orchestration, dist layout, swiftwui build"
```

---

### Task 7: `swiftwui dev` — the reload loop

**Files:**
- Create: `Sources/SwiftWUIToolchain/DevSession.swift`
- Create: `Sources/swiftwui/Commands/DevCommand.swift`
- Modify: `Sources/swiftwui/SwiftWUICommand.swift` (register)
- Test: `Tests/SwiftWUITests/ToolchainDevTests.swift`

**Interfaces:**
- Consumes: `HTTPServer`, `StaticFiles`, `SSEHub`, `DevInjection`, `FileWatcher`, `WasmBuilder`, `ToolchainResources`.
- Produces: `final class DevSession { init(builder: WasmBuilder, hub: SSEHub); func rebuildAndNotify(); var lastError: String? ; func handlers(projectDir: String, bundleDir: String) -> [HTTPHandler] }`. The Dev command is the only consumer.

- [ ] **Step 1: DevSession.swift**

```swift
import Foundation

public final class DevSession: @unchecked Sendable {   // lastError guarded by `lock`
    private let builder: WasmBuilder
    private let hub: SSEHub
    private let lock = NSLock()
    private var _lastError: String?
    public var lastError: String? { lock.lock(); defer { lock.unlock() }; return _lastError }

    public init(builder: WasmBuilder, hub: SSEHub) {
        self.builder = builder; self.hub = hub
    }

    /// One watcher-triggered cycle: rebuild, then `reload` or `build-error` (spec §6).
    public func rebuildAndNotify() {
        do {
            _ = try builder.build(configuration: "debug")
            lock.lock(); _lastError = nil; lock.unlock()
            hub.broadcast(event: "reload", data: "{}")
        } catch let e as ToolchainError {
            let output: String
            if case .buildFailed(let out) = e { output = out } else { output = e.description }
            let encoded = DevInjection.jsonStringLiteral(output)
            lock.lock(); _lastError = encoded; lock.unlock()
            hub.broadcast(event: "build-error", data: encoded)
        } catch {
            let encoded = DevInjection.jsonStringLiteral("\(error)")
            lock.lock(); _lastError = encoded; lock.unlock()
            hub.broadcast(event: "build-error", data: encoded)
        }
    }

    /// The dev URL space (spec §4/§5): SSE + dev client + vendor + /app/* + injected index.html.
    public func handlers(projectDir: String, bundleDir: String) -> [HTTPHandler] {
        let resources = ToolchainResources.root.path
        let projectShim = projectDir + "/vendor/wasi-shim"
        let shimRoot = FileManager.default.fileExists(atPath: projectShim)
            ? projectShim : resources + "/vendor/wasi-shim"
        let indexHandler: HTTPHandler = { request in
            // "/", "/index.html", and any extensionless route (SPA dev routing) → injected index.
            guard request.path == "/" || request.path == "/index.html"
                || !request.path.dropFirst().contains(".") else { return nil }
            guard let html = try? String(contentsOfFile: projectDir + "/index.html", encoding: .utf8)
            else { return nil }
            return .text(DevInjection.inject(into: html), contentType: "text/html; charset=utf-8")
        }
        return [
            hub.handler(lastError: { [weak self] in self?.lastError }),
            StaticFiles.handler(urlPrefix: "/__swiftwui/dev-client.js", root: resources),  // maps to <resources>/dev-client.js
            StaticFiles.handler(urlPrefix: "/__swiftwui/vendor/wasi-shim/", root: shimRoot),
            StaticFiles.handler(urlPrefix: "/vendor/wasi-shim/", root: shimRoot),
            StaticFiles.handler(urlPrefix: "/app/", root: bundleDir),
            indexHandler,
        ]
    }
}
```

Note on `/__swiftwui/dev-client.js`: `StaticFiles.handler(urlPrefix:root:)` maps the REMAINDER after the prefix — an exact-match prefix leaves an empty remainder. Handle it with a tiny dedicated closure instead if the empty-remainder case is awkward:

```swift
let devClient: HTTPHandler = { request in
    guard request.path == "/__swiftwui/dev-client.js",
          let data = FileManager.default.contents(atPath: resources + "/dev-client.js")
    else { return nil }
    return .file(bytes: Array(data), mime: "text/javascript; charset=utf-8")
}
```

Use whichever compiles cleanly; the URL contract is what matters.

- [ ] **Step 2: DevCommand.swift**

```swift
import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Dev: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build, serve and hot-reload the current project.")

    @Option(name: .long, help: "Port to serve on.") var port: UInt16 = 8080
    @Option(name: .long, help: "Swift SDK id (default: auto-detect).") var swiftSdk: String?

    func run() throws {
        let runner = FoundationProcessRunner()
        let cwd = FileManager.default.currentDirectoryPath
        guard FileManager.default.fileExists(atPath: cwd + "/Package.swift") else {
            throw ToolchainError.notAProject(cwd)
        }
        let sdk = try swiftSdk ?? WasmSDK.detect(runner: runner)
        let builder = WasmBuilder(runner: runner, projectDir: cwd, sdk: sdk)
        let hub = SSEHub()
        let session = DevSession(builder: builder, hub: hub)

        print("building (\(sdk))…")
        session.rebuildAndNotify()   // first build; on failure the overlay shows it on connect
        let bundleDir = cwd + "/.build/plugins/PackageToJS/outputs/Package"

        let server = HTTPServer(handlers: session.handlers(projectDir: cwd, bundleDir: bundleDir))
        try server.start(port: port)
        print("serving http://127.0.0.1:\(server.boundPort) — watching Sources/ (Ctrl-C to stop)")

        let watcher = FileWatcher(root: cwd)
        while true {                                    // main thread IS the watch loop
            Thread.sleep(forTimeInterval: 0.5)          // poll interval (spec §6)
            if watcher.changed() {
                Thread.sleep(forTimeInterval: 0.2)      // debounce: let the editor finish writing
                _ = watcher.changed()                   // absorb the debounce window
                print("change detected — rebuilding…")
                session.rebuildAndNotify()
            }
        }
    }
}
```

Register `Dev.self` in the root subcommands array.

- [ ] **Step 3: integration test (mocked build)** — `Tests/SwiftWUITests/ToolchainDevTests.swift`:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainDevTests {
    @Test func devURLSpaceServesInjectedIndexBundleAndShim() async throws {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-dev-\(UUID().uuidString)"
        let bundle = proj + "/bundle"
        try fm.createDirectory(atPath: bundle, withIntermediateDirectories: true)
        try "<head><title>t</title></head>".write(toFile: proj + "/index.html", atomically: true, encoding: .utf8)
        try "export const x = 1;".write(toFile: bundle + "/index.js", atomically: true, encoding: .utf8)

        let hub = SSEHub()
        let runner = MockRunner(results: [:])   // reuse Task 6's MockRunner (same test module)
        let session = DevSession(builder: WasmBuilder(runner: runner, projectDir: proj, sdk: "x"), hub: hub)
        let server = HTTPServer(handlers: session.handlers(projectDir: proj, bundleDir: bundle))
        try server.start(port: 0); defer { server.stop() }

        func get(_ path: String) async throws -> (Int, String) {
            let (data, resp) = try await URLSession.shared.data(
                from: URL(string: "http://127.0.0.1:\(server.boundPort)\(path)")!)
            return ((resp as! HTTPURLResponse).statusCode, String(decoding: data, as: UTF8.self))
        }
        let (s1, b1) = try await get("/")
        #expect(s1 == 200 && b1.contains("window.__swiftwui_dev = true"))
        let (s2, b2) = try await get("/about")          // SPA dev routing
        #expect(s2 == 200 && b2.contains("__swiftwui_dev"))
        let (s3, b3) = try await get("/app/index.js")
        #expect(s3 == 200 && b3 == "export const x = 1;")
        let (s4, _) = try await get("/vendor/wasi-shim/index.js")   // resource fallback
        #expect(s4 == 200)
        let (s5, _) = try await get("/__swiftwui/dev-client.js")
        #expect(s5 == 200)
    }

    @Test func buildErrorBroadcastsAndReplaysOnConnect() {
        let hub = SSEHub()
        let runner = MockRunner(results: ["swift package": .init(exitCode: 1, stdout: "", stderr: "error: boom")])
        let session = DevSession(builder: WasmBuilder(runner: runner, projectDir: "/tmp/x", sdk: "s"), hub: hub)
        session.rebuildAndNotify()
        #expect(session.lastError?.contains("boom") == true)   // replayed to late connectors
    }
}
```

- [ ] **Step 4: run suite once** — `swift test`. Zero failures.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(phase6): swiftwui dev — watch/rebuild/SSE loop with error replay"
```

---

### Task 8: `swiftwui ssg` + `swiftwui serve`

**Files:**
- Create: `Sources/SwiftWUIToolchain/PackageInfo.swift`
- Create: `Sources/swiftwui/Commands/SSGCommand.swift`
- Create: `Sources/swiftwui/Commands/ServeCommand.swift`
- Modify: `Sources/swiftwui/SwiftWUICommand.swift` (register both)
- Test: `Tests/SwiftWUITests/ToolchainPackageInfoTests.swift`

**Interfaces:**
- Consumes: `ProcessRunner`, `HTTPServer`, `StaticFiles`.
- Produces: `enum PackageInfo { static func executableProduct(in dir: String, runner: ProcessRunner) throws -> String }`.

- [ ] **Step 1: PackageInfo.swift**

```swift
import Foundation

public enum PackageInfo {
    /// First executable product per `swift package describe --type json`.
    public static func executableProduct(in dir: String, runner: ProcessRunner) throws -> String {
        let r = try runner.run("swift", ["package", "describe", "--type", "json"], cwd: dir, streamOutput: false)
        guard r.exitCode == 0,
              let data = r.stdout.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ToolchainError.productNotFound(dir) }
        // products: [{"name": "...", "type": {"executable": null}}, ...]
        if let products = obj["products"] as? [[String: Any]] {
            for p in products {
                if let type = p["type"] as? [String: Any], type.keys.contains("executable"),
                   let name = p["name"] as? String { return name }
            }
        }
        // fallback: targets: [{"name": "...", "type": "executable"}, ...]
        if let targets = obj["targets"] as? [[String: Any]] {
            for t in targets where (t["type"] as? String) == "executable" {
                if let name = t["name"] as? String { return name }
            }
        }
        throw ToolchainError.productNotFound(dir)
    }
}
```

- [ ] **Step 2: SSGCommand.swift**

```swift
import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct SSG: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ssg",
        abstract: "Prerender the site: runs the project's native `<App> ssg` entry (dual-entry pattern).")

    @Option(name: .long, help: "Output directory.") var out: String = "dist"
    @Option(name: .long, help: "Executable product (default: auto-detect).") var product: String?

    func run() throws {
        let runner = FoundationProcessRunner()
        let cwd = FileManager.default.currentDirectoryPath
        let name = try product ?? PackageInfo.executableProduct(in: cwd, runner: runner)
        let r = try runner.run("swift", ["run", name, "ssg", "--out", out], cwd: cwd, streamOutput: true)
        guard r.exitCode == 0 else { throw ExitCode(r.exitCode) }
    }
}
```

- [ ] **Step 3: ServeCommand.swift**

```swift
import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Serve: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Statically preview a built site (no watcher, no dev injection).")

    @Argument(help: "Directory to serve.") var dir: String = "dist"
    @Option(name: .long, help: "Port to serve on.") var port: UInt16 = 8080

    func run() throws {
        let root = URL(fileURLWithPath: dir, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path
        guard FileManager.default.fileExists(atPath: root) else { throw ToolchainError.io("'\(dir)' not found — run swiftwui build/ssg first") }
        let server = HTTPServer(handlers: [StaticFiles.handler(urlPrefix: "/", root: root, spaFallback: true)])
        try server.start(port: port)
        print("serving \(dir)/ at http://127.0.0.1:\(server.boundPort) (Ctrl-C to stop)")
        while true { Thread.sleep(forTimeInterval: 60) }
    }
}
```

Register `SSG.self, Serve.self` in the root subcommands.

- [ ] **Step 4: tests** — `Tests/SwiftWUITests/ToolchainPackageInfoTests.swift`:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainPackageInfoTests {
    @Test func picksExecutableProduct() throws {
        let json = #"{"products":[{"name":"Lib","type":{"library":["automatic"]}},{"name":"MySite","type":{"executable":null}}]}"#
        let runner = MockRunner(results: ["swift package describe": .init(exitCode: 0, stdout: json, stderr: "")])
        #expect(try PackageInfo.executableProduct(in: "/x", runner: runner) == "MySite")
    }
    @Test func fallsBackToExecutableTarget() throws {
        let json = #"{"products":[],"targets":[{"name":"MySite","type":"executable"}]}"#
        let runner = MockRunner(results: ["swift package describe": .init(exitCode: 0, stdout: json, stderr: "")])
        #expect(try PackageInfo.executableProduct(in: "/x", runner: runner) == "MySite")
    }
    @Test func throwsWhenNone() {
        let runner = MockRunner(results: ["swift package describe": .init(exitCode: 0, stdout: #"{"products":[]}"#, stderr: "")])
        #expect(throws: ToolchainError.self) { _ = try PackageInfo.executableProduct(in: "/x", runner: runner) }
    }
}
```

- [ ] **Step 5: run suite once + real-world smoke** — `swift test` (zero failures). Smoke against the real TodoMVC example: `cd Examples/TodoMVC && swift run --package-path ../.. swiftwui ssg --out /tmp/todomvc-dist` → expect "generated 6 pages"; then `swift run --package-path ../.. swiftwui serve /tmp/todomvc-dist --port 0` starts (Ctrl-C).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase6): swiftwui ssg (describe-driven) and swiftwui serve"
```

---

### Task 9: Framework dev hooks — state-preserving reload (SwiftWUIDOM)

The ONLY framework change of the phase (spec §7). Production behavior without `window.__swiftwui_dev` is byte-identical.

**Files:**
- Create: `Sources/SwiftWUIDOM/DevReload.swift`
- Modify: `Sources/SwiftWUIDOM/SnapshotBoot.swift` (split `read` → `parse` + `read`; `jsonString` becomes internal)
- Modify: `Sources/SwiftWUIDOM/DOMRuntime.swift` (dev seed branch in `mount`, dev save listener in `finishMount`)

**Interfaces:**
- Consumes: `StateStore._encodeSnapshotRows(_:)`, `SnapshotEncode`, `SnapshotBoot.Payload`/`decodeSlot`/`jsonString`, `DOMRuntime.seed`/`retained`, `EffectStore._skipBuildTaskKeys`.
- Produces: `SnapshotBoot.parse(_ text: String, currentPath: String) -> Payload?`; `DevReload.save(store:skipTasks:)` (wasm-only; no new public API).

- [ ] **Step 1: SnapshotBoot split** — extract the pure parse from the DOM read (both keep existing semantics):

```swift
static func parse(_ text: String, currentPath: String) -> Payload? {
    guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(text.utf8)),
          payload.v == 1,
          RouteURL._normalize(payload.path) == RouteURL._normalize(currentPath)
    else { return nil }
    return payload
}

static func read(currentPath: String) -> Payload? {
    let document = JSObject.global.document
    let el = document.querySelector("script[type=\"application/swiftwui-state\"]")
    guard let obj = el.object, let text = obj.textContent.string else { return nil }
    return parse(text, currentPath: currentPath)
}
```

Change `private func jsonString` to `static func jsonString` (internal) — DevReload reuses it.

- [ ] **Step 2: DevReload.swift**

```swift
#if arch(wasm32)
import JavaScriptKit
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Dev-mode state-preserving reload (phase-6 spec §7). Every entry point is
/// gated on `window.__swiftwui_dev`, which only the dev server injects —
/// production pages never execute this path.
@MainActor enum DevReload {
    static let storageKey = "__swiftwui_dev_snapshot"

    static var isDevPage: Bool { JSObject.global.__swiftwui_dev.boolean == true }

    private struct AnyEnc: Encodable {
        let base: any Encodable
        func encode(to encoder: Encoder) throws { try base.encode(to: encoder) }
    }
    /// Wasm mirror of SwiftWUIStatic.SnapshotJSON.encodeSlot (single-element-array
    /// convention) — SwiftWUIDOM deliberately doesn't depend on SwiftWUIStatic.
    static let encodeSlot: SnapshotEncode = { value in
        guard let data = try? JSONEncoder().encode([AnyEnc(base: value)]) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// sessionStorage carries an opaque JS string: layer-1 JSON escaping only,
    /// no HTMLEscaping.scriptJSON (that layer exists solely for <script> embedding).
    static func assemble(path: String, rows: [String: [String]], tasks: [String]) -> String {
        var out = "{\"v\":1,\"path\":" + SnapshotBoot.jsonString(path) + ",\"rows\":{"
        var first = true
        for key in rows.keys.sorted() {
            if !first { out += "," }
            first = false
            out += SnapshotBoot.jsonString(key) + ":[" + rows[key]!.joined(separator: ",") + "]"
        }
        out += "},\"tasks\":["
        out += tasks.sorted().map(SnapshotBoot.jsonString).joined(separator: ",")
        out += "]}"
        return out
    }

    static func save(store: StateStore, skipTasks: [String]) {
        let rows = store._encodeSnapshotRows(encodeSlot)
        let path = JSObject.global.location.pathname.string ?? "/"
        let json = assemble(path: path, rows: rows, tasks: skipTasks)
        _ = JSObject.global.sessionStorage.object?.setItem?(storageKey, json)
    }

    /// Consume-once read; malformed/mismatched content degrades to nil (cold render).
    static func takeStoredPayload(currentPath: String) -> SnapshotBoot.Payload? {
        guard isDevPage,
              let stored = JSObject.global.sessionStorage.object?.getItem?(storageKey).string
        else { return nil }
        _ = JSObject.global.sessionStorage.object?.removeItem?(storageKey)
        guard let payload = SnapshotBoot.parse(stored, currentPath: currentPath) else {
            print("[SwiftWUI] dev snapshot unreadable or path-mismatched — cold render")
            return nil
        }
        return payload
    }
}
#endif
```

- [ ] **Step 3: DOMRuntime.mount dev-seed branch** — the embedded-snapshot branches stay untouched; the dev branch only feeds the EXISTING cold-mount `fallbackPayload` mechanism. In `mount`, where the cold path runs with `fallbackPayload` (currently only set by the adoption-mismatch branch), add before the cold mount:

```swift
// Dev reload (phase-6 §7): no embedded snapshot on dev pages — sessionStorage
// may carry the pre-reload state. Consume-once; nil on any mismatch.
if fallbackPayload == nil {
    fallbackPayload = DevReload.takeStoredPayload(currentPath: location.pathname.string ?? "/")
}
```

Placement: after the `if let payload = SnapshotBoot.read…` / `else if SnapshotBoot.hasScriptTag()` chain, immediately before the cold `DOMBackend` runtime is created (currently lines ~125-131). The existing `seed(runtime, with: payload)` call then does everything (rows + decodeSlot + skip keys).

- [ ] **Step 4: dev save listener in `finishMount`** — after the popstate wiring (its exact idiom), add:

```swift
if DevReload.isDevPage {
    let devSave = JSClosure { [weak runtime] _ in
        if let runtime {
            DevReload.save(store: runtime._store,
                           skipTasks: Array(runtime._effects._skipBuildTaskKeys))
        }
        return .undefined
    }
    _ = JSObject.global.window.object?.addEventListener?("swiftwui:dev-snapshot-request", devSave)
    retained.append(devSave)   // JSClosure must outlive the page (v1 lesson)
}
```

`finishMount` is generic over the backend — `runtime._store` / `runtime._effects` are the public SPI already used by SwiftWUIStatic. If `_skipBuildTaskKeys` turns out not to be readable cross-module, make it `public private(set)` with a one-line SPI comment (same convention as `_completedBuildKeys`).

- [ ] **Step 5: gates** — native first: `swift test` (zero failures — wasm-only code compiles out natively, nothing to add to the native suite; the seed path through `_pendingRows` is already covered by phase-5 tests). Then the wasm gate:

```bash
cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
cd ../TodoMVC && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
```

Expected: both build clean. This is the task's real compile check for DevReload.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase6): dev-gated state-preserving reload hooks in SwiftWUIDOM"
```

---

### Task 10: Scaffolder, basic template, `swiftwui init` (+ spec amendments)

**Files:**
- Create: `Sources/SwiftWUIToolchain/Scaffolder.swift`
- Create: `Sources/SwiftWUIToolchain/Resources/templates/basic/` (all files below)
- Create: `Sources/swiftwui/Commands/InitCommand.swift`
- Modify: `Sources/swiftwui/SwiftWUICommand.swift` (register)
- Modify: `docs/superpowers/specs/2026-07-05-phase6-toolchain-design.md` (two amendments)
- Test: `Tests/SwiftWUITests/ToolchainScaffoldTests.swift`

**Interfaces:**
- Consumes: `ToolchainResources`, `ToolchainError`.
- Produces: `enum Scaffolder { static func scaffold(template: String, name: String, swiftwuiPath: String, into dir: String) throws }`. Substitutions: `{{NAME}}` (project/target name), `{{SWIFTWUI_PATH}}` (absolute path to the SwiftWUI checkout). Task 11 adds templates to the same resource layout; Task 12 exercises the output end-to-end.

- [ ] **Step 1: two spec amendments** (reality diverged; record it) — in `docs/superpowers/specs/2026-07-05-phase6-toolchain-design.md`:
  - §8, the Package.swift line: replace "SwiftWUI via git URL + branch; `--swiftwui-path` → path dependency" with "SwiftWUI via path dependency; `--swiftwui-path` is REQUIRED until the repo has a public git remote (none exists yet — amended during implementation)".
  - §4 layout contract: replace "uses **relative** URLs" with "uses **root-absolute** URLs (`/app/index.js`, `/vendor/wasi-shim/index.js`) — relative URLs break module resolution on nested dev routes like `/about` (amended during implementation)". Also update the two HTML snippet paths in that section, and note that `init` checks the shim into the project (`vendor/wasi-shim/`) so container builds don't need the CLI.

- [ ] **Step 2: Scaffolder.swift**

```swift
import Foundation

public enum Scaffolder {
    public static let templates = ["basic", "mvvm", "tca"]

    public static func scaffold(template: String, name: String, swiftwuiPath: String, into dir: String) throws {
        let fm = FileManager.default
        guard name.range(of: "^[A-Za-z][A-Za-z0-9_]*$", options: .regularExpression) != nil else {
            throw ToolchainError.invalidName(name)
        }
        if let contents = try? fm.contentsOfDirectory(atPath: dir), !contents.isEmpty {
            throw ToolchainError.targetExists(dir)
        }
        let templateRoot = ToolchainResources.url("templates/\(template)")
        guard fm.fileExists(atPath: templateRoot.path) else {
            throw ToolchainError.io("unknown template '\(template)' (available: \(templates.joined(separator: ", ")))")
        }
        let swiftwuiAbs = URL(fileURLWithPath: swiftwuiPath).standardizedFileURL.path
        guard fm.fileExists(atPath: swiftwuiAbs + "/Package.swift") else {
            throw ToolchainError.notAProject(swiftwuiAbs)
        }
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let e = fm.enumerator(atPath: templateRoot.path)!
        for case let rel as String in e {
            let src = templateRoot.appendingPathComponent(rel)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: src.path, isDirectory: &isDir)
            let dst = dir + "/" + rel
            if isDir.boolValue {
                try fm.createDirectory(atPath: dst, withIntermediateDirectories: true)
            } else if let raw = fm.contents(atPath: src.path) {
                if let text = String(data: raw, encoding: .utf8) {
                    let substituted = text
                        .replacingOccurrences(of: "{{NAME}}", with: name)
                        .replacingOccurrences(of: "{{SWIFTWUI_PATH}}", with: swiftwuiAbs)
                    try substituted.write(toFile: dst, atomically: true, encoding: .utf8)
                } else {
                    try raw.write(to: URL(fileURLWithPath: dst))   // binary passthrough
                }
            }
        }
        // Check the shim into the project: containers and offline builds need it (spec §9 amendment).
        try fm.createDirectory(atPath: dir + "/vendor", withIntermediateDirectories: true)
        try fm.copyItem(atPath: ToolchainResources.url("vendor/wasi-shim").path,
                        toPath: dir + "/vendor/wasi-shim")
    }
}
```

- [ ] **Step 3: basic template files** — under `Sources/SwiftWUIToolchain/Resources/templates/basic/`:

`Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "{{NAME}}",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "{{SWIFTWUI_PATH}}"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.22.0"),
    ],
    targets: [
        .executableTarget(name: "{{NAME}}", dependencies: [
            .product(name: "SwiftWUI", package: "SwiftWUI"),
            .product(name: "SwiftWUIDOM", package: "SwiftWUI"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            .product(name: "SwiftWUIStatic", package: "SwiftWUI",
                     condition: .when(platforms: [.macOS, .linux])),
        ], path: "Sources", swiftSettings: [.defaultIsolation(MainActor.self)]),
    ]
)
```

`Sources/main.swift` (dual entry, proven TodoMVC pattern; counter + About page so all templates present the identical app):

```swift
import SwiftWUI
import SwiftWUIDOM

struct Counter: Tag {
    @State private var count = 0
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(count)")
            Button("−") { count -= 1 }
            Button("+") { count += 1 }
        }
    }
}

struct HomePage: Tag, Page {
    var title: String { "{{NAME}}" }
    var body: some Tag {
        Main {
            H1("{{NAME}}")
            Counter()
            Link("/about") { Span { "About" } }
        }
    }
}

struct AboutPage: Tag, Page {
    @State var builtAt = "not prerendered"
    var title: String { "About — {{NAME}}" }
    var body: some Tag {
        Main {
            H2("About")
            P { Text(builtAt) }
            Link("/") { Span { "Home" } }
        }
        .staticTask { builtAt = "prerendered at build time" }
    }
}

struct RootApp: Tag {
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
    }
}

struct {{NAME}}App: App {
    var body: some Tag { RootApp() }
}

#if canImport(SwiftWUIStatic)
import SwiftWUIStatic

@main enum Entry {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        guard args.first == "ssg" else {
            print("usage: {{NAME}} ssg --out <dir> [--static]")
            return
        }
        args.removeFirst()
        var out = "dist"
        var mode = StaticSiteMode.hydrate(wasmScriptPath: "/app/index.js")
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--out":
                guard i + 1 < args.count else { print("--out needs a value"); return }
                i += 1; out = args[i]
            case "--static": mode = .staticOnly
            default: print("unknown arg \(args[i])")
            }
            i += 1
        }
        let report = try await StaticSite.generate({{NAME}}App.self,
                                                   config: .init(outDir: out, mode: mode))
        print("generated \(report.pages.count) pages")
    }
}
#else
@main enum Entry {
    static func main() { {{NAME}}App.main() }
}
#endif
```

`index.html` (root-absolute URLs per the amended spec §4):

```html
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>{{NAME}}</title>
  <script type="importmap">
  {"imports": {"@bjorn3/browser_wasi_shim": "/vendor/wasi-shim/index.js"}}
  </script>
</head>
<body>
  <script type="module">
    import { init } from "/app/index.js";
    await init();
  </script>
</body>
</html>
```

`.gitignore`:

```
.build/
dist/
.swiftpm/
```

`Dockerfile` (build container; BuildKit local output — final layer is dist/ only):

```dockerfile
# Reproducible wasm build (spec §9). Requires the Swift.org WASM SDK artifactbundle
# URL for the EXACT toolchain in the base image:
#   docker build --build-arg WASM_SDK_URL=<artifactbundle url> --output type=local,dest=dist-docker .
# NOTE: works once the SwiftWUI dependency in Package.swift is a git URL or is
# vendored inside this directory — a path dependency outside the build context
# is invisible to docker (README, "Docker" section).
FROM swift:6.3.3 AS build
ARG WASM_SDK_URL
WORKDIR /src
COPY . .
RUN swift sdk install "$WASM_SDK_URL"
RUN swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c release
RUN swift run {{NAME}} ssg --out dist \
 && mkdir -p dist/app dist/vendor \
 && cp -r .build/plugins/PackageToJS/outputs/Package/. dist/app/ \
 && cp -r vendor/. dist/vendor/ \
 && cp index.html dist/index.html

FROM scratch AS export
COPY --from=build /src/dist /
```

`Dockerfile.deploy`:

```dockerfile
# Serve a locally built dist/ (run `swiftwui build && swiftwui ssg` first):
#   docker build -f Dockerfile.deploy -t {{NAME}} . && docker run -p 8080:80 {{NAME}}
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/
```

`nginx.conf`:

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;
    # application/wasm is in modern nginx mime.types; pinned here regardless —
    # wrong MIME silently disables streaming instantiation.
    types { application/wasm wasm; }
    include /etc/nginx/mime.types;
    location / { try_files $uri $uri/index.html /index.html; }
}
```

`README.md`:

```markdown
# {{NAME}}

A [SwiftWUI](https://github.com/swiftwasm) project. Pure Swift → WebAssembly.

## Develop

    swiftwui dev            # build, serve at http://127.0.0.1:8080, hot-reload with state preserved

## Build & prerender

    swiftwui build          # wasm bundle + index.html + vendored shim → dist/
    swiftwui ssg            # prerender pages into dist/ (hydrated on load)
    swiftwui serve dist     # preview the production output

## Docker

`Dockerfile` builds dist/ inside a pinned toolchain container (host and wasm SDK
versions must match exactly). It requires the SwiftWUI dependency to be
reachable inside the build context — with the default path dependency pointing
outside this directory, build locally instead. `Dockerfile.deploy` serves a
locally built dist/ via nginx.

## Layout

- `Sources/main.swift` — the app; dual entry (wasm mount / native `ssg` subcommand)
- `index.html` — dev/prod entry; import map resolves the vendored WASI shim
- `vendor/wasi-shim/` — @bjorn3/browser_wasi_shim 0.3.0 (MIT/Apache-2.0), checked in
```

- [ ] **Step 4: InitCommand.swift**

```swift
import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scaffold a new SwiftWUI project.")

    @Argument(help: "Project name ([A-Za-z][A-Za-z0-9_]*).") var name: String
    @Option(name: .long, help: "Template: basic, mvvm, or tca.") var template: String = "basic"
    @Option(name: .long, help: "Path to a SwiftWUI checkout (required until SwiftWUI is published).")
    var swiftwuiPath: String

    func run() throws {
        let dir = FileManager.default.currentDirectoryPath + "/" + name
        try Scaffolder.scaffold(template: template, name: name, swiftwuiPath: swiftwuiPath, into: dir)
        print("""
        created \(name)/ (template: \(template))
          cd \(name)
          swiftwui dev
        """)
    }
}
```

Register `Init.self` first in the subcommands array.

- [ ] **Step 5: tests** — `Tests/SwiftWUITests/ToolchainScaffoldTests.swift`:

```swift
import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainScaffoldTests {
    func scratch() -> String { NSTemporaryDirectory() + "swiftwui-init-\(UUID().uuidString)" }
    /// The repo root is a valid --swiftwui-path for tests.
    var repoRoot: String {
        // Tests run from the package dir; Package.swift sits at the root.
        FileManager.default.currentDirectoryPath
    }

    @Test func scaffoldBasicProducesFullProject() throws {
        let dir = scratch()
        try Scaffolder.scaffold(template: "basic", name: "MySite", swiftwuiPath: repoRoot, into: dir)
        let fm = FileManager.default
        for f in ["Package.swift", "Sources/main.swift", "index.html", ".gitignore",
                  "Dockerfile", "Dockerfile.deploy", "nginx.conf", "README.md",
                  "vendor/wasi-shim/index.js", "vendor/wasi-shim/LICENSE-MIT"] {
            #expect(fm.fileExists(atPath: dir + "/" + f), "missing \(f)")
        }
        let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
        #expect(pkg.contains("name: \"MySite\""))
        #expect(!pkg.contains("{{"))                       // no unsubstituted placeholders
        let main = try String(contentsOfFile: dir + "/Sources/main.swift", encoding: .utf8)
        #expect(main.contains("struct MySiteApp: App"))
        #expect(!main.contains("{{"))
    }

    @Test func refusesNonEmptyDirAndBadNames() throws {
        let dir = scratch()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "x".write(toFile: dir + "/junk", atomically: true, encoding: .utf8)
        #expect(throws: ToolchainError.self) {
            try Scaffolder.scaffold(template: "basic", name: "A", swiftwuiPath: repoRoot, into: dir)
        }
        #expect(throws: ToolchainError.self) {
            try Scaffolder.scaffold(template: "basic", name: "9lives", swiftwuiPath: repoRoot, into: scratch())
        }
        #expect(throws: ToolchainError.self) {
            try Scaffolder.scaffold(template: "nope", name: "Ok", swiftwuiPath: repoRoot, into: scratch())
        }
    }
}
```

- [ ] **Step 6: run suite once + heavy smoke** — `swift test` (zero failures). Then the real thing (slow, fetches deps — run once here, per-template matrix happens in Task 12):

```bash
cd /tmp && rm -rf HelloWUI
swift run --package-path ~/dev/SwiftWUI swiftwui init HelloWUI --swiftwui-path ~/dev/SwiftWUI
cd HelloWUI && swift build
```

Expected: scaffold + clean native build of the generated project.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(phase6): scaffolder, basic template with Dockerfiles, swiftwui init; spec amendments (path dep, root-absolute URLs)"
```

---

### Task 11: mvvm + tca templates

Same file set as basic — ONLY `Sources/main.swift` differs (Package.swift, index.html, Dockerfiles, nginx.conf, .gitignore identical; README gets one extra architecture paragraph). Copy basic's files into `templates/mvvm/` and `templates/tca/`, then replace `Sources/main.swift`. The user-visible app is identical across the three (counter + About) so the architectures are directly comparable.

**Files:**
- Create: `Sources/SwiftWUIToolchain/Resources/templates/mvvm/*` (basic's files + main.swift below)
- Create: `Sources/SwiftWUIToolchain/Resources/templates/tca/*` (basic's files + main.swift below)
- Test: `Tests/SwiftWUITests/ToolchainScaffoldTests.swift` (append)

**Interfaces:**
- Consumes: `Scaffolder` (Task 10) — templates resolve by directory name, no code change.

- [ ] **Step 1: mvvm `Sources/main.swift`** — observable ViewModel owns state and intent; views are logic-free (the `@Observable` + EnvironmentKey pattern proven by TodoMVC):

```swift
import SwiftWUI
import SwiftWUIDOM
import Observation

// MARK: ViewModel — owns state and intent; views below contain zero logic.

@Observable final class CounterViewModel {
    private(set) var count = 0
    func increment() { count += 1 }
    func decrement() { count -= 1 }
}

private struct CounterVMKey: EnvironmentKey { static let defaultValue = CounterViewModel() }
extension EnvironmentValues {
    var counterVM: CounterViewModel {
        get { self[CounterVMKey.self] } set { self[CounterVMKey.self] = newValue }
    }
}

// MARK: Views

struct CounterView: Tag {
    @Environment(\.counterVM) var vm
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(vm.count)")
            Button("−") { vm.decrement() }
            Button("+") { vm.increment() }
        }
    }
}

struct HomePage: Tag, Page {
    var title: String { "{{NAME}}" }
    var body: some Tag {
        Main {
            H1("{{NAME}}")
            CounterView()
            Link("/about") { Span { "About" } }
        }
    }
}

struct AboutPage: Tag, Page {
    @State var builtAt = "not prerendered"
    var title: String { "About — {{NAME}}" }
    var body: some Tag {
        Main {
            H2("About")
            P { Text(builtAt) }
            Link("/") { Span { "Home" } }
        }
        .staticTask { builtAt = "prerendered at build time" }
    }
}

struct RootApp: Tag {
    @State var vm = CounterViewModel()
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
        .environment(\.counterVM, vm)
    }
}

struct {{NAME}}App: App {
    var body: some Tag { RootApp() }
}
```

…followed by the IDENTICAL `#if canImport(SwiftWUIStatic)` dual-entry block from the basic template (Task 10 Step 3), verbatim.

- [ ] **Step 2: tca `Sources/main.swift`** — hand-rolled unidirectional store; README states this is TCA-*style*, not pointfree TCA (which does not build on wasm):

```swift
import SwiftWUI
import SwiftWUIDOM
import Observation

// MARK: TCA-style core — State, Action, reducer, Store. No external package:
// pointfree TCA does not build on wasm; this is the same shape on SwiftWUI reactivity.

struct AppState: Equatable {
    var count = 0
}

enum AppAction {
    case increment
    case decrement
}

func appReducer(_ state: inout AppState, _ action: AppAction) {
    switch action {
    case .increment: state.count += 1
    case .decrement: state.count -= 1
    }
}

@Observable final class Store {
    private(set) var state = AppState()
    func send(_ action: AppAction) { appReducer(&state, action) }
}

private struct StoreKey: EnvironmentKey { static let defaultValue = Store() }
extension EnvironmentValues {
    var store: Store { get { self[StoreKey.self] } set { self[StoreKey.self] = newValue } }
}

// MARK: Views — read state, send actions.

struct CounterView: Tag {
    @Environment(\.store) var store
    var body: some Tag {
        Div(class: "counter") {
            H1("Count: \(store.state.count)")
            Button("−") { store.send(.decrement) }
            Button("+") { store.send(.increment) }
        }
    }
}

struct HomePage: Tag, Page {
    var title: String { "{{NAME}}" }
    var body: some Tag {
        Main {
            H1("{{NAME}}")
            CounterView()
            Link("/about") { Span { "About" } }
        }
    }
}

struct AboutPage: Tag, Page {
    @State var builtAt = "not prerendered"
    var title: String { "About — {{NAME}}" }
    var body: some Tag {
        Main {
            H2("About")
            P { Text(builtAt) }
            Link("/") { Span { "Home" } }
        }
        .staticTask { builtAt = "prerendered at build time" }
    }
}

struct RootApp: Tag {
    @State var store = Store()
    var body: some Tag {
        Router(notFound: { Main { H1("404"); Link("/") { Span { "home" } } } }) {
            Route("/") { HomePage() }
            Route("/about") { AboutPage() }
        }
        .environment(\.store, store)
    }
}

struct {{NAME}}App: App {
    var body: some Tag { RootApp() }
}
```

…followed by the same dual-entry block, verbatim.

- [ ] **Step 3: README architecture paragraphs** — in mvvm's README, after the intro line:

```markdown
This project uses the **MVVM** template: `CounterViewModel` (an `@Observable`
class injected through the environment) owns all state and intent; Tag views
render it and forward user actions. Views contain no logic.
```

In tca's README:

```markdown
This project uses the **TCA-style** template: a single `Store` holds `AppState`,
views `store.send(_:)` actions, and a pure `appReducer` computes the next state.
This is TCA-*style* on SwiftWUI reactivity — not pointfree swift-composable-architecture,
which does not build on wasm.
```

- [ ] **Step 4: tests** — append to `ToolchainScaffoldTests.swift`:

```swift
@Test(arguments: ["mvvm", "tca"]) func scaffoldArchitectureTemplates(template: String) throws {
    let dir = scratch()
    try Scaffolder.scaffold(template: template, name: "Arch", swiftwuiPath: repoRoot, into: dir)
    let main = try String(contentsOfFile: dir + "/Sources/main.swift", encoding: .utf8)
    #expect(!main.contains("{{"))
    #expect(main.contains("struct ArchApp: App"))
    #expect(main.contains(template == "mvvm" ? "CounterViewModel" : "func appReducer"))
    let readme = try String(contentsOfFile: dir + "/README.md", encoding: .utf8)
    #expect(readme.contains(template == "mvvm" ? "MVVM" : "TCA-style"))
}
```

- [ ] **Step 5: run suite once** — `swift test`. Zero failures.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(phase6): mvvm and tca-style templates"
```

---

### Task 12: Acceptance matrix, wasm gates, ledger

The heavy end-to-end pass (spec §12 heavy gates) + progress ledger. No new production code; fixes discovered here get their own commits.

**Files:**
- Modify: `.superpowers/sdd/progress.md` (phase-6 section + phase-7 carry list)
- Test: none new (matrix is command-driven)

- [ ] **Step 1: full native gate** — `swift test` from repo root: zero failures.

- [ ] **Step 2: examples wasm gate** —

```bash
cd Examples/Counter && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
cd ../TodoMVC && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug
cd .. && swift run TodoMVC ssg --out /tmp/p6-todomvc-dist
```

Expected: both bundles build; SSG prints "generated 6 pages", zero warnings.

- [ ] **Step 3: template matrix** — for each of basic/mvvm/tca (slow — each fetches and builds the full dep graph):

```bash
cd /tmp && rm -rf P6_<T> && swift run --package-path ~/dev/SwiftWUI swiftwui init P6_<T> --template <T> --swiftwui-path ~/dev/SwiftWUI
cd P6_<T>
swift build                                                          # native gate
swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug       # wasm gate
swift run P6_<T> ssg --out dist                                      # ssg gate — expect "generated 2 pages"
swift run --package-path ~/dev/SwiftWUI swiftwui build --out dist    # dist layout on top
test -f dist/index.html && test -f dist/app/index.js && test -f dist/vendor/wasi-shim/index.js && echo LAYOUT-OK
```

All three templates must pass all four gates. A failure here is a template bug — fix the template resource, re-run the matrix for that template, commit the fix separately.

- [ ] **Step 4: docker spot-check (build daemon required; skip with a ledger note if unavailable)** —

```bash
cd /tmp/P6_basic && docker build -f Dockerfile.deploy -t p6-basic . && docker run --rm -d -p 8081:80 --name p6b p6-basic
curl -s http://127.0.0.1:8081/ | grep -q P6_basic && echo DEPLOY-OK
docker rm -f p6b
```

(The build Dockerfile needs a published SwiftWUI or vendored checkout — documented limitation, not tested here.)

- [ ] **Step 5: ledger** — append the phase-6 section to `.superpowers/sdd/progress.md`: task list with commits, gates run, decisions (naming convention kept public; textContent trimmed; exit-test outcome from Task 1 Step 11; path-dep + root-absolute spec amendments), and the **phase-7 carry list**, seeded with at least: brew/mint distribution + templates switching to git-URL dependency (needs public remote); Dockerfile end-to-end once published; live streaming ProcessRunner output; SSE keep-alive pings if long dev sessions drop; watcher ignore-list config if projects grow non-Sources swift dirs.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(phase6): acceptance matrix green — ledger, phase-7 carry list"
```

---

### MANUAL BROWSER ACCEPTANCE (with the user — mandatory this phase, spec §12)

Not an agent task — run together with the user at the end. One session covers the phase-5 debt AND the phase-6 features:

```bash
cd /tmp/P6_basic && swift run --package-path ~/dev/SwiftWUI swiftwui dev
```

- [ ] Phase-5 debt (on `swiftwui serve` of an ssg'd TodoMVC dist): `data-swui-hydrated` set; two distinct buttons dispatch correctly; snapshot script removed after boot; About page shows "prerendered at build time"; MPA nav works in `--static` output; viewport meta survives hydration.
- [ ] Dev cycle: page loads at 127.0.0.1:8080; click `+` three times (Count: 3); edit `Sources/main.swift` (change the H1 text); auto rebuild + reload; **Count: 3 survives**, new H1 text shows.
- [ ] Build error: introduce a syntax error → red overlay with compiler output, page still alive; fix → overlay clears on reload.
- [ ] `swiftwui serve dist` works with no dev client (view-source: no `__swiftwui_dev`).

---

## Self-review notes (already applied)

- Spec §4 relative-URL contract and §8 git-URL dependency contradicted reality (nested-route module resolution; no git remote) — Task 10 Step 1 amends the spec rather than shipping a broken layout.
- `swiftwui build` default `-c release` vs dev's hard-coded debug is intentional (spec §4 table).
- Task 1 Step 8's `_drainBuildTasks` signature may need the store parameter — the implementer follows the existing signature; the produced surface (`_buildWrites`) is what Task 1's StaticSite change consumes, same task, no cross-task drift.
