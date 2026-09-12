# Library modernization

Approved scope: the 12 September 2026 library audit, including bounded rewrites where evidence supports them. Baseline revision: `2937f82`; working branch: `codex/library-modernization`. The preceding audit fixes remain part of this change. Public APIs remain source compatible unless an explicit migration is documented. English code/docs; Swift 6.3.3 remains the supported default.

## Design and acceptance

1. Build/delivery: validate the selected compiler and WASM SDK together, including user overrides; produce deterministic size/composition reports and configurable regression budgets; record boot phases; add native/release/WASM/browser CI gates. Budgets must compare the same fixture and configuration.
2. Runtime: replace quadratic dirty-cover selection with ancestor lookup; measure 50/100/500 sibling bursts; batch registry cleanup without changing lifecycle order. Add opt-in render diagnostics with no production bridge by default.
3. SEO/deployment: opt-in indexed-site validation of origins, metadata, structured data and local links; export real redirect/status/trailing-slash metadata, support preview HTTP behavior and hosting adapters. Private apps are valid without SEO mode.
4. Navigation: coordinated focus, announcements and history scroll restoration with overrides, preserving native links and modified clicks.
5. App interop: opt-in BridgeJS scaffold, app-owned wrapper/declarations/generated imports, deterministic resource loading and documentation for errors/promises/callback disposal. Respect the pinned JavaScriptKit API.
6. Resources/forms: keyed GET resource cache with deduplication, TTL, invalidation, consumer cancellation and hydration seeds; recoverable async state and progressively enhanced forms with field errors and retry.
7. Assets: build-time responsive image metadata/variants and configurable font preparation/preload; dependencies remain outside the core library.
8. Registration/Swift: optional explicit/generated stable registration alongside Mirror; compare state/hydration behavior. Add isolated Swift 6.4 Observation and Embedded compatibility experiments without claiming unsupported targets work.
9. Selective runtime: static-only pages that ship no WASM boot; delayed page and island activation policies with documented shared-module byte costs.
10. Collections/workers: fixed-height virtual collection with stable keys, overscan and SSR fallback; typed compute-worker service with cancellation, explicit transfer ownership and teardown.

Each workstream needs behavioral tests, a runnable example or fixture where browser behavior matters, user documentation, and recorded verification. Changes must preserve the Foundation import and nonisolated-deinit guards. Native builds sharing `.build` are serialized by the coordinator. Performance claims require measurements.

## Execution ledger

| Workstream | Owner | Status | Evidence |
| --- | --- | --- | --- |
| Audit correctness fixes | Prior team | Implemented and verified | 1333 native tests, release CLI, clean Counter WASM, browser smoke; audit report |
| Toolchain, budgets and CI | Build agent + coordinator | Implemented | Matching host/SDK preflight, section/import/compressed reports, checked Counter budget; native/release/WASM/browser workflow |
| Runtime burst optimization and diagnostics | Runtime agent | Implemented and measured | 500-row native debug flush: 739.92 → 31.59 ms; lifecycle and scoped-equivalence regressions |
| SEO and deployment contract | Static agent + reviewer | Implemented | Indexed metadata/link checks, HTTP 301/302/308 and 404 policies, nginx adapter, containment regressions |
| BridgeJS app integration | Build agent | Implemented and browser-verified | Public facade: sync, async, throws, retained callbacks and disposal; import-map-aware loader |
| Navigation accessibility | Coordinator | Implemented and browser-verified | Focus, live announcements, history scroll, malformed-fragment regression |
| Resources and enhanced forms | Coordinator | Implemented | Deduplication, TTL, bounded storage, cancellation, snapshot seed, async form state; native/browser tests |
| Image/font pipeline | Build agent + coordinator | Implemented | Source-to-variant commands, dimensions, srcset, regeneration and symlink containment |
| Explicit registration | Runtime agent + coordinator | Implemented | Stable component/state IDs, legacy snapshots, generator and actual Swift typecheck |
| Swift 6.4 and Embedded | Static agent + coordinator | Isolated experiments | Embedded counter ABI test passed; SE-0506 probe follows published API but cannot run without Swift 6.4 |
| Static-only and selective activation | Static agent + coordinator | Implemented | No-runtime static documents, gated WASM requests, disposable leaf islands |
| Virtual collection | Runtime agent | Implemented and browser-verified | 10,000-row fixture stays below 30 DOM rows; fixed-height contract |
| Compute workers | Coordinator | Implemented and browser-verified | Typed Sendable messages, cancellation, module reuse, atomic buffer transfer, terminal failure/teardown |

See [ModernizationResults](Documentation/ModernizationResults.md) for final evidence,
measured size changes, source references, and supported boundaries.

## Integration gates

- Targeted behavioral tests as features land; full native suite after integration.
- Native release CLI, JavaScript syntax/unit tests, clean release WASM with matching host/SDK.
- Browser checks for mount/state/events, routing focus/history, delayed activation, resource cancellation and interop.
- Reproducible final size report and burst benchmark. Report actual limitations and unavailable experiments separately from completed features.
- Independent final correctness review; address blocking findings; `git diff --check`.
