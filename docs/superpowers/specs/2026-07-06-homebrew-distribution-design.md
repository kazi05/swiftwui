# Homebrew Distribution for SwiftWUI

**Date:** 2026-07-06
**Status:** Approved
**Goal:** Install the `swiftwui` CLI via `brew tap kazi05/swiftwui && brew install swiftwui`, while keeping the manual build-from-checkout path documented and working.

## Scope

Homebrew distributes only the CLI binary. The `SwiftWUI` / `SwiftWUIDOM` /
`SwiftWUIStatic` libraries are consumed as a SwiftPM dependency from the
public repository — Homebrew is not involved in library resolution.

Three deliverables:

1. CLI changes in this repository so a brew-installed `swiftwui init` works
   without a local SwiftWUI checkout.
2. A tap repository `kazi05/homebrew-swiftwui` with a source-build formula.
3. A one-time release process: publish `kazi05/swiftwui`, tag `v0.1.0`.

Out of scope: homebrew-core submission (requires project notability; revisit
later), prebuilt binary bottles / CI release pipeline (revisit when install
time becomes a complaint), Linuxbrew, publishing the v1 `master` branch.

## 1. CLI changes (this repository)

### Default dependency: git URL instead of required local path

Today `swiftwui init` requires `--swiftwui-path` and the three templates
hardcode `.package(path: "{{SWIFTWUI_PATH}}")`. After this change:

- Templates (`basic`, `mvvm`, `tca` — `Package.swift` in each) replace the
  line `.package(path: "{{SWIFTWUI_PATH}}"),` with the placeholder
  `{{SWIFTWUI_DEPENDENCY}},`.
- `Scaffolder.scaffold` takes `swiftwuiPath: String?`:
  - path given → substitute `.package(path: "<absolute path>")` and keep the
    existing `notAProject` validation (unchanged behavior);
  - path nil → substitute
    `.package(url: "https://github.com/kazi05/swiftwui.git", from: "<SwiftWUIVersion.current>")`
    with no filesystem validation.
- `InitCommand`: `--swiftwui-path` becomes an optional override for local
  development; help text updated accordingly (drop the "required until
  SwiftWUI is published" note).

### Single version constant

New `SwiftWUIVersion.current` (a `public enum` with a static `String`) in
`SwiftWUIToolchain`, set to `"0.1.0"`. Consumed by:

- `SwiftWUICommand` `version:` (currently hardcoded `"0.6.0"`),
- `Scaffolder` for the `from:` requirement in the URL dependency.

A release bumps exactly one constant plus a git tag.

### Tests

- Update existing scaffolder/init tests for the new optional-path signature.
- New test: scaffold without a path → generated `Package.swift` contains the
  GitHub URL and `from: SwiftWUIVersion.current`, and no `{{` placeholders
  remain.
- New test: scaffold with a path → `.package(path:)` preserved (existing
  behavior locked in).

### Documentation

- `README.md` Installation: Homebrew as the primary method
  (`brew tap kazi05/swiftwui && brew install swiftwui`), manual
  build-from-checkout kept as the alternative; quick start drops
  `--swiftwui-path`; remove "repo is not published yet" notes and use the
  real clone URL `https://github.com/kazi05/swiftwui.git`.
- `Sources/SwiftWUI/SwiftWUI.docc/GettingStarted.md`: same updates.
- `Sites/Tutorial` `Ch02_InstallToolchain.swift`: replace the
  repo-not-published placeholder with the real URL and brew instructions.

## 2. Tap repository `kazi05/homebrew-swiftwui`

Single file `Formula/swiftwui.rb`, source-build formula:

```ruby
class Swiftwui < Formula
  desc "CLI for SwiftWUI — SwiftUI-inspired web framework compiled to WebAssembly"
  homepage "https://github.com/kazi05/swiftwui"
  url "https://github.com/kazi05/swiftwui/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "<computed after tagging>"
  license "MIT"

  depends_on macos: :sonoma            # Package.swift: platforms .macOS(.v14)
  depends_on xcode: ["<min>", :build]  # any Xcode shipping Swift >= 6.2; pin at implementation

  def install
    system "swift", "build", "-c", "release", "--product", "swiftwui"
    libexec.install ".build/release/swiftwui",
                    ".build/release/SwiftWUI_SwiftWUIToolchain.bundle"
    bin.write_exec_script libexec/"swiftwui"
  end

  def caveats
    <<~EOS
      Building SwiftWUI apps requires the Swift 6.3.3 toolchain and the
      matching WASM SDK (versions must match exactly):
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

Key decisions:

- **`bin.write_exec_script`, not `install_symlink`.** The CLI locates its
  resource bundle via `Bundle.module`, which resolves relative to the running
  executable. A symlink can break that lookup; an exec wrapper script keeps
  the real binary and the bundle side by side in `libexec` deterministically.
- **Source build is acceptable in a custom tap.** SwiftPM fetches
  dependencies (ArgumentParser, JavaScriptKit — pinned by the committed
  `Package.resolved`) during `brew install`; network-during-build is only
  forbidden by homebrew-core policy, not in taps. Install time ~1–2 min.
- **`test do` runs offline.** `init` without `--swiftwui-path` only writes
  files; dependency resolution is not part of the formula test.

After tapping, the user-facing command is plain `brew install swiftwui`
(and `brew upgrade swiftwui` for updates).

## 3. Release process (one-time, ordered)

1. On `feature/fable-new-vision`: add `LICENSE` (MIT, 2026 Kazim Gadzhiev),
   commit the currently untracked `README.md` + `SwiftWUI.docc/`, implement
   the CLI changes above, `swift test` green.
2. Merge `feature/fable-new-vision` → `main`; add remote
   `git@github.com:kazi05/swiftwui.git`; push `main`.
3. Tag `v0.1.0` on the merge commit; push the tag. (Scaffolded projects
   reference `from: "0.1.0"` — resolvable the moment the tag is public.)
4. Compute `sha256` of the tag tarball; finalize the formula; create and
   push `kazi05/homebrew-swiftwui`.
5. Acceptance on this machine (has Swift 6.3.3 + WASM SDK):
   - `brew tap kazi05/swiftwui && brew install swiftwui`
   - `swiftwui --version` → `0.1.0`
   - `swiftwui init Demo` (no flag) → resolves SwiftWUI from GitHub
   - `cd Demo && swiftwui build` → wasm bundle in `dist/`
   - manual path still works: `swiftwui init Local --swiftwui-path <checkout>`

The v1 `master` branch stays local (reference material, not published).

## Error handling

- `init` with `--swiftwui-path` keeps today's validation errors.
- `init` without the flag cannot fail on network — failure surfaces later at
  `swift build` inside the scaffolded project with SwiftPM's own error; no
  new error paths in the CLI.
- Formula build failures surface as standard brew errors; the `test do`
  block catches a missing resource bundle (init would throw).

## Future work (explicitly deferred)

- homebrew-core submission once the project has public traction.
- Bottles via GitHub Actions release pipeline if source-build install time
  becomes a problem.
- `swiftwui doctor` command to verify toolchain/WASM SDK pairing.
