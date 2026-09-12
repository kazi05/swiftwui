# Modernization results — 12 September 2026

Implementation branch: `codex/library-modernization`; audit baseline: `2937f82`.
The runtime, build, static-delivery and JavaScript interop work was split between
specialists, then independently reviewed and exercised together. No library
or global toolchain upgrade is required. Swift 6.3.3 remains the supported default.

## Delivered capabilities

| Area | Result | API and details |
| --- | --- | --- |
| Rendering | Ancestor-based dirty cover, indexed batched tree replacement, batched teardown, terminal unmount | [Runtime](RuntimeModernization.md) |
| Diagnostics | Render reasons, duration, component tree, lifetime counts and adoption fallback; optional debug browser bridge | [Diagnostics](ModernWebAPIs.md#diagnostics) |
| Large collections | Fixed-height `VirtualForEach`, stable keys, overscan, bounded initial HTML and complete mode | [Collections](RuntimeModernization.md) |
| State registration | Stable component and named state IDs, old snapshot compatibility, optional same-file source generator | [Registration](RuntimeModernization.md#explicit-component-registration) |
| Build and size | Host/compiler/SDK validation, executable paths, raw/gzip/Brotli reports, WASM sections/imports, fixture budgets and CI | [Build](BuildAndAssets.md) |
| SEO and HTTP | Indexed-page validation, canonical/metadata/JSON-LD/local-link checks, actual redirects and 404 behavior, nginx rules | [Static delivery](StaticDelivery.md) |
| Navigation | Post-commit focus, polite title announcement, back/forward scroll restoration and overrides | [Navigation](ModernWebAPIs.md#navigation-accessibility) |
| Async data and forms | Bounded GET cache, deduplication, TTL, cancellation, invalidation and explicit seeds; async state and enhanced forms | [Resources/forms](ModernWebAPIs.md) |
| Assets | Host-side responsive variants, intrinsic dimensions, srcset/sizes, configurable font processing | [Assets](BuildAndAssets.md#responsive-assets) |
| Selective activation | Static documents without client runtime; idle/visible/interaction activation and disposable leaf islands | [Activation](ModernWebAPIs.md#deferred-activation-and-islands) |
| Worker computation | Typed Sendable requests/replies, explicit buffer ownership, cancellation, compiled-module reuse and teardown | [Workers](ModernWebAPIs.md#compute-workers) |
| Application JavaScript | Opt-in BridgeJS package scaffold, public facade, AOT generation, module load order, promises/errors/callback disposal | [BridgeJS](BridgeJSInterop.md) |

## Measured results

Serialized native debug measurements with Swift 6.3.3 on arm64 macOS:

| Coalesced row updates | Before | After |
| ---: | ---: | ---: |
| 50 | 10.91 ms | 3.24 ms |
| 100 | 35.50 ms | 6.22 ms |
| 500 | 739.92 ms | 31.59 ms |

The 500-row flush improved about **23.4 times** in this fixture. This includes
resolution, diffing, commands applied to MockBackend and cleanup. It is not a
browser, release-mode or Core Web Vitals speedup claim. The original quadratic
algorithm is retained only inside the opt-in comparison benchmark:

```sh
SWIFTWUI_BENCHMARKS=1 swift test --filter RuntimeDirtyCoverBenchmarkTests
```

The benchmark is excluded from the normal concurrent suite because its legacy
comparison can occupy MainActor for seconds and starve unrelated gesture timers.
Browser checks prove that scrolling a 10,000-row list retains fewer than 30 row
DOM elements, while state, forms, navigation and island activation keep working.

A separate [browser performance run](Measurements/browser-performance-2026-09-12.json)
used Chromium 149 on the existing WASM fixture. Across 144 scroll steps it
observed 9–13 live rows, a 9.7 ms p95 frame interval and a 10.4 ms maximum.
Identical CPU work took 68.5 ms on the main thread and 68.9 ms via the module
worker, with matching checksums. The zero-delay heartbeat was delayed by
68.6 ms on the main thread versus 0.2 ms during worker execution. This supports
offloading responsiveness, not faster arithmetic. The report explicitly records
concurrent host load; these are local observations, not device-independent limits.
The runnable [script](../Sites/Tutorial/tools/screenshots/modern-performance.mjs)
checks correctness without asserting machine-specific timing thresholds.

Counter's full delivery measurement includes its existing fetch, storage,
animation and conditionally rendered content. It is not a minimal counter:

| Counter release | Raw bytes | gzip -n9 | Brotli 11 |
| --- | ---: | ---: | ---: |
| Audit baseline | 9,407,550 | 3,353,472 | 2,415,062 |
| Modernized | 9,611,359 | 3,433,088 | 2,497,701 |

The default Counter binary is about **2.2% larger raw** after adding this
infrastructure. A reduction in the full WASM binary has **not** been demonstrated.
Static-only pages avoid runtime delivery, and opt-in registration provides a
future seam for a smaller profile; neither justifies a claim that the current
shared module became smaller. The release uses Swift/SDK 6.3.3 and wasm-opt 130.
The [machine-readable report](Measurements/counter-release-2026-09-12.json)
records exact composition and SHA-256 `686db29e69a496a45467931653095df8b3d14a41ac1e4b7e1c515e65cfd96c4b`. Reports describe their exact
artifacts; independent builds may differ in bytes even with the same tool versions.

The Counter [budget](../Examples/Counter/wasm-budget.json) permits 10,000,000 raw,
3,600,000 gzip and 2,650,000 Brotli bytes. It is explicitly selected in CI so a
normal example build does not acquire an unexpected fixture-name requirement:

```sh
# From Examples/Counter with the matching swift/swiftc selected:
swiftwui build -c release --fixture counter --budget wasm-budget.json
```

Fresh release measurements also cover the larger examples, using the same
Swift/SDK 6.3.3, wasm-opt 130 and compression settings:

| Fixture | Raw bytes | gzip -n9 | Brotli 11 |
| --- | ---: | ---: | ---: |
| [Counter](Measurements/counter-release-2026-09-12.json) | 9,611,359 | 3,433,088 | 2,497,701 |
| [TodoMVC](Measurements/todomvc-release-2026-09-12.json) | 9,639,563 | 3,443,236 | 2,505,084 |
| [Tutorial](Measurements/tutorial-release-2026-09-12.json) | 10,074,221 | 3,587,821 | 2,583,615 |

TodoMVC and Tutorial have separate measured budgets with approximately 5%
headroom. The CI matrix builds and publishes a report for each of the three
fixtures; it runs the browser matrix once. The list workload is covered by the
browser DOM/frame measurements above rather than pretending the large regression
fixture is a minimal list application's release size.

## Verification

- Native suite: **1,385 tests in 200 suites passed**; expensive comparison
  benchmarks are separately enabled. The full suite includes the Foundation
  import and isolated-deinit guards, state/hydration compatibility, lifecycle,
  HTTP, SEO, cache, forms, assets and compiler-selection regressions.
- Native release CLI and release Counter WASM builds passed. The complete
  `swiftwui build` path assembled dist, compressed artifacts, wrote the report
  and enforced the Counter budget. Existing storage/dependency compiler
  warnings remain; this is not a warning-free-build claim.
- Chromium regression matrix: **52 passed**. After tightening worker message
  Sendable constraints and exercising opt-in diagnostics plus explicit island
  registration, the affected modern browser group was rerun: **3 passed**.
- Boot and worker JavaScript regressions: **8 passed**, including stalled
  pre-header fetch, stalled interop, delayed activation, cancellation, compiled
  module reuse and transfer detachment.
- Registration generator: **3 passed**, including real Swift type checking of
  a generated public component with private wrappers and escaping/idempotency.
- BridgeJS public facade compiled for host and WASM and passed headless Chromium:
  sync result, async Promise, thrown JS exception, callback delivery and disposal.
- An independent review found and fixed output-path traversal/symlinks,
  escaped/percent-encoded SEO links, unbounded legacy interop readiness,
  incorrect import-map order and target-name detection. Integration also fixed
  failed worker lifetime, atomic buffer transfer, malformed hash scrolling,
  stale image variants and previous build reports entering PWA integrity data.
- GitHub Actions now defines matching native/release/WASM/browser gates,
  verified SDK/Binaryen archives, compression and published budget reports.
  The workflow has not been executed on GitHub during this local task.

## Swift 6.4 and the reference repository

The [SE-0506 probe](../Experiments/Swift64/ContinuousObservation.swift) follows
[the published continuous Observation API](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0506-advanced-observation-tracking.md):
a single tracking/event closure and a consuming cancellation token. It checks
initial delivery, a mutation and cancellation. Swift 6.4 is not installed here,
so no successful 6.4 compile or performance gain is asserted. The runner requires
explicit matching 6.4 binaries. A separate script supports paired type-check timing.

The [Embedded experiment](../Experiments/README.md) builds the **same** tiny
stateful exported counter with ordinary and Embedded Swift 6.3.3. Both passed
Node WASI export/state checks: 7,086,080 versus 20,115 bytes. This fixture has no
DOM or SwiftWUI runtime; those figures cannot be compared with the Counter app.
A complete Embedded SwiftWUI profile remains unavailable because reflection,
AnyHashable, Observation, serialization, Foundation and the browser ABI still
need compatible replacements. Swift 6.4's
[Embedded improvements](https://www.swift.org/blog/embedded-swift-improvements-coming-in-swift-6.4/)
make this worth investigating, but do not remove those requirements automatically.

From [light-web-app](https://github.com/purpln/light-web-app/tree/6b7a980dbc881acf0598f4eb734711e734e9a8f9)
we adapted ideas: explicit worker/transfer ownership, reuse of compiled modules,
and an isolated minimal-runtime experiment. No source was copied. We did not
adopt its freestanding ABI or shared-memory threading as a hidden requirement.

## Current boundaries

- Islands own dedicated containers outside a reconciled root and support leaf
  widgets. Router stays at the document root. Activation replaces static child
  HTML; it does not yet adopt each island's own serialized tree. Islands share
  one module and do not implement automatic WASM code splitting.
- Virtual collections require fixed row heights. For fully indexed collection
  content, use complete/static rendering; variable heights and automatic focus
  retention across virtualized-out rows are not part of this API.
- Resource snapshots are explicit and caller-selected. Mutations and the native
  form endpoint remain application-owned; binary form inputs use WebSession upload.
- BridgeJS remains pinned experimental glue for 0.56.1. The scaffold demonstrates
  app-owned wrapper JS and typed imports, not automatic support for every npm
  package. TS2Swift's dependency installation has no upstream npm lockfile.
- `-Osize` is not exposed as a misleading CLI switch: PackageToJS 0.56.1 rejects
  `-Xswiftc -Osize`. No unsafe package-manifest rewrite or global reflection
  stripping was introduced to simulate support.
