# Homebrew Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `brew tap kazi05/swiftwui && brew install swiftwui` installs a working CLI whose `init` scaffolds projects against the public GitHub repo, while the manual checkout path keeps working.

**Architecture:** Three parts: (1) CLI changes so `--swiftwui-path` becomes an optional override and the default scaffold depends on `https://github.com/kazi05/swiftwui.git`; (2) one-time release — merge `feature/fable-new-vision` → `main`, push to the new public repo, tag `v0.1.0`; (3) a tap repo `kazi05/homebrew-swiftwui` with a source-build formula that installs the binary + its SPM resource bundle into `libexec` behind an exec-script wrapper.

**Tech Stack:** Swift 6.3.3 / SwiftPM, Swift Testing (`@Test`/`#expect`), Homebrew formula (Ruby), `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-07-06-homebrew-distribution-design.md`

## Global Constraints

- Public repo: `https://github.com/kazi05/swiftwui.git`; tap repo: `kazi05/homebrew-swiftwui`; first tag: `v0.1.0`.
- License: MIT, copyright 2026 Kazim Gadzhiev.
- Single version source: `SwiftWUIVersion.current == "0.1.0"` in `SwiftWUIToolchain`; no other hardcoded version strings in CLI code.
- No new package dependencies.
- Per-task testing workflow (user preference): write all task code first, run `swift test` once at the end of the task, then commit. No intermediate RED/GREEN runs.
- Native gate: `swift test` from repo root must stay green (~291 tests).
- v1 `master` branch is never pushed to the public repo.
- Prose in code/commits/docs: English.

---

### Task 1: `SwiftWUIVersion` constant wired into CLI `--version`

**Files:**
- Create: `Sources/SwiftWUIToolchain/SwiftWUIVersion.swift`
- Modify: `Sources/SwiftWUICLI/SwiftWUICommand.swift` (currently `version: "0.6.0"` on line 8)
- Test: `Tests/SwiftWUITests/ToolchainScaffoldTests.swift`

**Interfaces:**
- Produces: `public enum SwiftWUIVersion { public static let current: String }` in module `SwiftWUIToolchain` — Task 2 interpolates it into the scaffolded dependency line; the formula's `test do` (Task 5) asserts `swiftwui --version` prints it.

- [ ] **Step 1: Create the constant**

`Sources/SwiftWUIToolchain/SwiftWUIVersion.swift`:

```swift
/// Single source of truth for the released version.
/// A release bumps this constant and pushes a matching `v<current>` git tag.
public enum SwiftWUIVersion {
    public static let current = "0.1.0"
}
```

- [ ] **Step 2: Use it for `--version`**

In `Sources/SwiftWUICLI/SwiftWUICommand.swift`, add `import SwiftWUIToolchain` under `import ArgumentParser`, and replace `version: "0.6.0",` with:

```swift
        version: SwiftWUIVersion.current,
```

- [ ] **Step 3: Add a format test**

Append to the `ToolchainScaffoldTests` suite in `Tests/SwiftWUITests/ToolchainScaffoldTests.swift`:

```swift
    @Test func versionIsSemver() {
        #expect(SwiftWUIVersion.current.range(
            of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil)
    }
```

- [ ] **Step 4: Run tests once**

Run: `swift test`
Expected: all pass (existing count + 1).

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWUIToolchain/SwiftWUIVersion.swift Sources/SwiftWUICLI/SwiftWUICommand.swift Tests/SwiftWUITests/ToolchainScaffoldTests.swift
git commit -m "feat(cli): single SwiftWUIVersion constant, drive --version from it"
```

---

### Task 2: Optional `--swiftwui-path`, GitHub URL as default dependency

**Files:**
- Modify: `Sources/SwiftWUIToolchain/Scaffolder.swift`
- Modify: `Sources/SwiftWUIToolchain/Resources/templates/basic/Package.swift` (line 8)
- Modify: `Sources/SwiftWUIToolchain/Resources/templates/mvvm/Package.swift` (line 8)
- Modify: `Sources/SwiftWUIToolchain/Resources/templates/tca/Package.swift` (line 8)
- Modify: `Sources/SwiftWUICLI/Commands/InitCommand.swift`
- Test: `Tests/SwiftWUITests/ToolchainScaffoldTests.swift`

**Interfaces:**
- Consumes: `SwiftWUIVersion.current` (Task 1).
- Produces: `Scaffolder.scaffold(template:name:swiftwuiPath:into:)` where `swiftwuiPath` is now `String?` — `nil` → `.package(url: "https://github.com/kazi05/swiftwui.git", from: SwiftWUIVersion.current)` in the scaffolded `Package.swift`; non-nil → `.package(path:)` with the existing `notAProject` validation. Tasks 3–6 rely on `swiftwui init <name>` working with no flag.

Note: the scaffolded `.product(name: "SwiftWUI", package: "SwiftWUI")` lines keep working for the URL dependency — SPM package identity is case-insensitive and derives to `swiftwui` for both the path (`SwiftWUI/` dir) and the URL (`swiftwui.git`) forms.

- [ ] **Step 1: Switch the three template manifests to one placeholder**

In each of the three files
`Sources/SwiftWUIToolchain/Resources/templates/{basic,mvvm,tca}/Package.swift`
(they are byte-identical), replace the line:

```swift
        .package(path: "{{SWIFTWUI_PATH}}"),
```

with:

```swift
        {{SWIFTWUI_DEPENDENCY}},
```

- [ ] **Step 2: Make the path optional in `Scaffolder`**

In `Sources/SwiftWUIToolchain/Scaffolder.swift`, change the signature (line 6):

```swift
    public static func scaffold(template: String, name: String, swiftwuiPath: String?, into dir: String) throws {
```

Replace the validation block (current lines 18–21):

```swift
        let swiftwuiAbs = URL(fileURLWithPath: swiftwuiPath).standardizedFileURL.path
        guard fm.fileExists(atPath: swiftwuiAbs + "/Package.swift") else {
            throw ToolchainError.notAProject(swiftwuiAbs)
        }
```

with:

```swift
        let swiftwuiDependency: String
        if let swiftwuiPath {
            let swiftwuiAbs = URL(fileURLWithPath: swiftwuiPath).standardizedFileURL.path
            guard fm.fileExists(atPath: swiftwuiAbs + "/Package.swift") else {
                throw ToolchainError.notAProject(swiftwuiAbs)
            }
            swiftwuiDependency = ".package(path: \"\(swiftwuiAbs)\")"
        } else {
            swiftwuiDependency = ".package(url: \"https://github.com/kazi05/swiftwui.git\", from: \"\(SwiftWUIVersion.current)\")"
        }
```

And replace the substitution line (current line 38):

```swift
                        .replacingOccurrences(of: "{{SWIFTWUI_PATH}}", with: swiftwuiAbs)
```

with:

```swift
                        .replacingOccurrences(of: "{{SWIFTWUI_DEPENDENCY}}", with: swiftwuiDependency)
```

- [ ] **Step 3: Make the CLI option optional**

In `Sources/SwiftWUICLI/Commands/InitCommand.swift`, replace (current lines 11–12):

```swift
    @Option(name: .long, help: "Path to a SwiftWUI checkout (required until SwiftWUI is published).")
    var swiftwuiPath: String
```

with:

```swift
    @Option(name: .long, help: "Path to a local SwiftWUI checkout (default: fetch from GitHub).")
    var swiftwuiPath: String?
```

The `run()` body is unchanged — it already forwards `swiftwuiPath` to `Scaffolder.scaffold`, which now accepts the optional.

- [ ] **Step 4: Add tests for both dependency forms**

Append to `ToolchainScaffoldTests`:

```swift
    @Test func scaffoldWithoutPathUsesGitHubDependency() throws {
        let dir = scratch()
        try Scaffolder.scaffold(template: "basic", name: "Remote", swiftwuiPath: nil, into: dir)
        let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
        #expect(pkg.contains(
            ".package(url: \"https://github.com/kazi05/swiftwui.git\", from: \"\(SwiftWUIVersion.current)\")"))
        #expect(!pkg.contains("{{"))
    }

    @Test func scaffoldWithPathKeepsLocalDependency() throws {
        let dir = scratch()
        try Scaffolder.scaffold(template: "basic", name: "Local", swiftwuiPath: repoRoot, into: dir)
        let pkg = try String(contentsOfFile: dir + "/Package.swift", encoding: .utf8)
        #expect(pkg.contains(".package(path: \""))
        #expect(!pkg.contains("github.com/kazi05/swiftwui"))
        #expect(!pkg.contains("{{"))
    }
```

Existing tests pass a non-optional `repoRoot` into the now-optional parameter — no edits needed there.

- [ ] **Step 5: Run tests once**

Run: `swift test`
Expected: all pass (count + 2). The pre-existing tests `scaffoldBasicProducesFullProject`, `refusesNonEmptyDirAndBadNames`, `scaffoldArchitectureTemplates` must stay green — they exercise the path form.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWUIToolchain/Scaffolder.swift Sources/SwiftWUIToolchain/Resources/templates Sources/SwiftWUICLI/Commands/InitCommand.swift Tests/SwiftWUITests/ToolchainScaffoldTests.swift
git commit -m "feat(cli): init defaults to GitHub dependency, --swiftwui-path becomes a local override"
```

---

### Task 3: Documentation — README, DocC, tutorial Ch02, LICENSE

**Files:**
- Modify: `README.md` (untracked — this commit adds it)
- Modify: `Sources/SwiftWUI/SwiftWUI.docc/GettingStarted.md` (untracked — this commit adds the whole `SwiftWUI.docc/` catalog)
- Modify: `Sites/Tutorial/Sources/TutorialKit/Content/Ch02_InstallToolchain.swift` (the `03 · CLI` section, lines ~38–52)
- Create: `LICENSE`

**Interfaces:**
- Consumes: install commands defined by Task 5's tap (`brew tap kazi05/swiftwui`, `brew install swiftwui`) and Task 2's flagless `swiftwui init`.

- [ ] **Step 1: Create `LICENSE`** (standard MIT text)

```text
MIT License

Copyright (c) 2026 Kazim Gadzhiev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Rewrite the README Installation section**

In `README.md`, replace the current `## Installation` block (lines 39–56) with:

````markdown
## Installation

```sh
# 1. Swift toolchain
swiftly install 6.3.3
swiftly use 6.3.3
swift --version        # → Swift version 6.3.3 (swift-6.3.3-RELEASE)

# 2. WASM SDK (bundle URL from swift.org/download)
swift sdk install <swift-6.3.3-RELEASE_wasm bundle URL>
swift sdk list         # → swift-6.3.3-RELEASE_wasm

# 3. The `swiftwui` CLI — via Homebrew
brew tap kazi05/swiftwui
brew install swiftwui
```

<details>
<summary>Manual CLI install (from a checkout)</summary>

```sh
git clone https://github.com/kazi05/swiftwui.git
cd swiftwui
swift build -c release --product swiftwui
export PATH="$PWD/.build/release:$PATH"
```

</details>
````

Then in the Quick start block (line 61), replace:

```sh
swiftwui init MyApp --swiftwui-path /path/to/SwiftWUI
```

with:

```sh
swiftwui init MyApp
```

And in the CLI commands table (line 78), replace the `init` row's command cell with:

```
`swiftwui init <name> [--template basic\|mvvm\|tca] [--swiftwui-path <path>]`
```

and append to that row's description: `--swiftwui-path` points the scaffold at a local checkout instead of the GitHub release.

- [ ] **Step 3: Update `GettingStarted.md`**

In `Sources/SwiftWUI/SwiftWUI.docc/GettingStarted.md`, replace the `### Build the CLI` block (lines ~22–28):

````markdown
### Install the CLI

```sh
brew tap kazi05/swiftwui
brew install swiftwui
```

Or build from a checkout: `git clone https://github.com/kazi05/swiftwui.git && cd swiftwui && swift build -c release --product swiftwui`.
````

and on line ~33 replace `swiftwui init MyApp --swiftwui-path /path/to/SwiftWUI` with `swiftwui init MyApp`.

- [ ] **Step 4: Update tutorial chapter 02**

In `Sites/Tutorial/Sources/TutorialKit/Content/Ch02_InstallToolchain.swift`, replace the `03 · CLI` section's `steps:` and `panel:` (current lines ~41–52):

```swift
                    steps: [
                        Step("brew tap kazi05/swiftwui && brew install swiftwui installs the CLI.",
                             detail: "Homebrew builds it from the tagged source release."),
                        Step("Building from a checkout works too: swift build -c release --product swiftwui.",
                             detail: "Or run it in place: swift run swiftwui <command>."),
                        Step("Verify with swiftwui --version."),
                    ],
                    panel: .terminal(title: "zsh", lines: [
                        TermLine(.command, "brew tap kazi05/swiftwui"),
                        TermLine(.command, "brew install swiftwui"),
                        TermLine(.command, "swiftwui --version"),
                        TermLine(.note, "> 0.1.0"),
                    ])),
```

- [ ] **Step 5: Verify builds**

Run: `swift test` — expected: green (docs don't affect it, cheap sanity).
Run: `swift build --package-path Sites/Tutorial` — expected: `Build complete!` (Ch02 edit compiles).

- [ ] **Step 6: Commit**

```bash
git add LICENSE README.md Sources/SwiftWUI/SwiftWUI.docc Sites/Tutorial/Sources/TutorialKit/Content/Ch02_InstallToolchain.swift
git commit -m "docs: Homebrew install path, MIT license, real repo URLs"
```

---

### Task 4: Release — merge to main, push, tag v0.1.0

Manual/orchestrator task (no subagent): outward-facing git operations.

**Files:** none (git operations only).

**Interfaces:**
- Produces: public `main` at `github.com/kazi05/swiftwui` and tag `v0.1.0` — Task 5's formula tarball URL and Task 2's scaffolded `from: "0.1.0"` resolve against it.

- [ ] **Step 1: Full gate on the feature branch**

Run: `swift test`
Expected: all green. Working tree clean (`git status` — nothing unstaged).

- [ ] **Step 2: Merge into main**

```bash
git checkout main
git merge --no-ff feature/fable-new-vision -m "Merge feature/fable-new-vision: SwiftWUI v2 (phases 1-7)"
```

- [ ] **Step 3: Point origin at the public repo and push**

```bash
git remote -v   # inspect first: add origin if absent, otherwise set-url
git remote add origin git@github.com:kazi05/swiftwui.git   # or: git remote set-url origin ...
git push -u origin main
```

Do NOT push `master` (v1 stays local).

- [ ] **Step 4: Tag and push the tag**

```bash
git tag -a v0.1.0 -m "SwiftWUI 0.1.0 — first public release"
git push origin v0.1.0
```

- [ ] **Step 5: Sanity-check the tarball resolves**

Run: `curl -sIL https://github.com/kazi05/swiftwui/archive/refs/tags/v0.1.0.tar.gz | grep -i "^HTTP" | tail -1`
Expected: `HTTP/2 200`.

---

### Task 5: Tap repo `kazi05/homebrew-swiftwui` with the formula

Manual/orchestrator task (creates and pushes a new public repo).

**Files:**
- Create: `/Users/gadzhievkt/dev/homebrew-swiftwui/Formula/swiftwui.rb`
- Create: `/Users/gadzhievkt/dev/homebrew-swiftwui/README.md`

**Interfaces:**
- Consumes: tag `v0.1.0` tarball (Task 4); `swiftwui --version` → `0.1.0` (Task 1); flagless `swiftwui init` (Task 2).

- [ ] **Step 1: Compute the tarball checksum**

```bash
curl -sL https://github.com/kazi05/swiftwui/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
```

- [ ] **Step 2: Determine the Xcode floor**

Run `xcodebuild -version` and `xcrun swift --version` locally. The formula needs the oldest Xcode whose Swift is ≥ 6.2 (the manifest's tools-version). Use that version in `depends_on xcode:` below; if `xcrun swift --version` on this machine is ≥ 6.2, pin to this machine's Xcode major (e.g. `"26.0"`).

- [ ] **Step 3: Write the formula**

`/Users/gadzhievkt/dev/homebrew-swiftwui/Formula/swiftwui.rb`:

```ruby
class Swiftwui < Formula
  desc "CLI for SwiftWUI - SwiftUI-inspired web framework compiled to WebAssembly"
  homepage "https://github.com/kazi05/swiftwui"
  url "https://github.com/kazi05/swiftwui/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<sha256 from Step 1>"
  license "MIT"
  head "https://github.com/kazi05/swiftwui.git", branch: "main"

  depends_on macos: :sonoma                     # Package.swift: .macOS(.v14)
  depends_on xcode: ["<from Step 2>", :build]   # needs Swift >= 6.2

  def install
    system "swift", "build", "-c", "release", "--product", "swiftwui"
    libexec.install ".build/release/swiftwui",
                    ".build/release/SwiftWUI_SwiftWUIToolchain.bundle"
    # Exec script, not a symlink: the CLI locates its resource bundle via
    # Bundle.module next to the real executable.
    bin.write_exec_script libexec/"swiftwui"
  end

  def caveats
    <<~EOS
      Building SwiftWUI apps additionally requires the Swift 6.3.3 toolchain
      and the matching WASM SDK (versions must match exactly):
        swiftly install 6.3.3 && swiftly use 6.3.3
        swift sdk install <swift-6.3.3-RELEASE_wasm bundle URL from swift.org/download>
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/swiftwui --version")
    system bin/"swiftwui", "init", "Smoke"
    assert_match "github.com/kazi05/swiftwui", (testpath/"Smoke/Package.swift").read
  end
end
```

- [ ] **Step 4: Tap README**

`/Users/gadzhievkt/dev/homebrew-swiftwui/README.md`:

````markdown
# homebrew-swiftwui

Homebrew tap for [SwiftWUI](https://github.com/kazi05/swiftwui).

```sh
brew tap kazi05/swiftwui
brew install swiftwui
```
````

- [ ] **Step 5: Create and push the tap repo**

```bash
cd /Users/gadzhievkt/dev/homebrew-swiftwui
git init -b main && git add -A && git commit -m "swiftwui 0.1.0 formula"
gh repo create kazi05/homebrew-swiftwui --public --source . --push
```

- [ ] **Step 6: Install from the tap and run the formula test**

```bash
brew tap kazi05/swiftwui
brew install --build-from-source swiftwui
brew test swiftwui
brew audit --strict kazi05/swiftwui/swiftwui   # style/metadata lint; fix findings
```

Expected: install succeeds (~1–2 min compile), `brew test` passes. If `swiftwui init` inside `brew test` fails with a resource-bundle error, the bundle name changed — check `ls $(brew --prefix)/opt/swiftwui/libexec/` and fix the `libexec.install` line.

---

### Task 6: End-to-end acceptance on this machine

Manual/orchestrator task.

**Files:** none (scratch dirs only — use the session scratchpad).

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Version and help**

```bash
swiftwui --version   # → 0.1.0 (the brew-installed one: `which swiftwui` → .../bin/swiftwui under brew prefix)
swiftwui --help
```

- [ ] **Step 2: Flagless init resolves SwiftWUI from GitHub**

```bash
cd <scratchpad> && swiftwui init Demo && cd Demo
grep "kazi05/swiftwui" Package.swift   # URL dependency present
swiftwui build                          # fetches the tagged release, builds wasm → dist/
```

Expected: `dist/` contains the wasm bundle; no `--swiftwui-path` anywhere.

- [ ] **Step 3: Local-path override still works**

```bash
cd <scratchpad> && swiftwui init Local --swiftwui-path /Users/gadzhievkt/dev/SwiftWUI
grep ".package(path:" Local/Package.swift
```

- [ ] **Step 4: Report results to the user** — install output, build result, any caveats.
