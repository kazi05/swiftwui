# Swift 6.4 and Embedded experiments

These experiments are isolated from the library's supported Swift 6.4.0/WASI
build. They are evidence gathering, not feature flags and not a new deployment
profile.

## SE-0506 continuous observation

A probe of the [SE-0506 API](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0506-advanced-observation-tracking.md)
used to live in `Swift64/`. Under the shipped name,
`withContinuousObservation(options:apply:)`, it compiled and passed on Swift
6.4.0: initial delivery, a later mutation, and token cancellation. The probe
and its CI step were then deleted, because what it showed rules the API out
for the render core:

- `.initial` and every later event arrive asynchronously, from a runner that
  `Task.detached` starts, never inside the call or the setter. So the API
  cannot wrap a synchronous body evaluation or replace the generation gate,
  `_ObservationTrackingGate` in `Sources/SwiftWUI/State/StateStore.swift`.
- Its `~Copyable` `Token` cancels in `deinit`, so keeping one per tracking
  window would need a class box per window.

Where SE-0506 exists, the render core uses one-shot
`withObservationTracking(options: .didSet)` instead (`_trackInvalidation` in
`Sources/SwiftWUI/Runtime/Resolver.swift`).

`compare-typecheck.sh` accepts two user-selected host/compiler/SDK triples and
uses `/usr/bin/time -p` for a local comparison. It intentionally does not make
a cross-machine or cross-SDK performance claim.

## Embedded counter

`EmbeddedCounter` contains a tiny reflection-free executable with explicit
mutable state and exported `counterIncrement`, `counterReset`, and
`counterValue` Wasm functions. It has no DOM, allocator, C shim, threading
model, or copied source. The script compiles the exact same fixture against
the ordinary and Embedded SDKs, then invokes both exports through Node's WASI
imports:

```sh
cd Experiments/EmbeddedCounter
./build.sh
```

It is only meaningful to compare its output with another equally tiny,
self-contained counter built from the same toolchain and optimization level.
It must never be compared to SwiftWUI's Counter example, which includes the
WASI/JavaScriptKit/browser runtime and application features.

On this host, the installed 6.4.0 SDKs built and passed the Node export/state
smoke test on 13 October 2026. The regular WASI fixture was 7,160,951 bytes;
the Embedded-flag fixture was 43,606 bytes. Exact sizes depend on the build
paths (other build paths gave 7,160,803 and 43,680 bytes), and the SHA-256
changes on every run because the random scratch path ends up in the binary.
Swift Build placed both under `out/Products/Release-webassembly-wasm32` in the
scratch path. The comparison demonstrates the runtime cost of this one
fixture; it is not proof of a `wasm32-unknown-none-wasm` browser ABI or a
library size comparison.

The full SwiftWUI graph cannot be moved to Embedded today. `StateStore.link`
uses `Mirror` (`Sources/SwiftWUI/State/StateStore.swift`), node keys and effect
identities use `AnyHashable` (`Identity/Identity.swift`, `Effects/EffectStore.swift`),
and the renderer depends on Observation, Codable snapshots, Foundation
essentials, WASI, and JavaScriptKit. The explicit registration seam in
`State/ExplicitComponentRegistration.swift` is a compatibility experiment, but
does not remove those other runtime requirements. A future browser profile
would need an explicit allocator/interop ABI, a supported state serialization
format, and browser tests before it could be offered to users.
