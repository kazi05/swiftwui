# Swift 6.4 and Embedded experiments

These experiments are isolated from the library's supported Swift 6.3.3/WASI
build. They are evidence gathering, not feature flags and not a new deployment
profile.

## SE-0506 continuous observation

`Swift64/ContinuousObservation.swift` records the [SE-0506 Swift 6.4 API](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0506-advanced-observation-tracking.md):
`withContinuousObservationTracking(options: [.didSet])`, a borrowing event
callback, and a `~Copyable` cancellation token. Run it only with explicitly
matched 6.4 `swift` and `swiftc` binaries:

```sh
cd Experiments/Swift64
SWIFT64=/path/to/swift SWIFTC64=/path/to/swiftc ./run-se0506.sh
```

The host at audit time has Swift 6.3.3 and no Swift 6.4 toolchain, so this probe
has not been compiled or reported as passing. The script rejects older or
mismatched compilers before compilation. The continuous API uses a single
closure that both reads dependencies and receives an event; it does not use
the separate `onChange` closure from one-shot tracking. The probe checks
initial delivery, a subsequent mutation, and explicit token cancellation.
After this passes under 6.4, the next experiment is an
adapter behind a compiler availability check, measured against the existing
generation gate in `StateStore`, not a replacement by declaration alone.

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

On this host, the installed 6.3.3 SDKs built and passed the Node export/state
smoke test on 12 September 2026. The regular WASI fixture was 7,086,080 bytes
(SHA-256 `649f84446bd2493181a5fa3f92ad630bf67b9c65a4c5d42f974db1e333921e3c`);
the Embedded-flag fixture was 20,115 bytes (SHA-256
`ecc1c0a14b11d7ff8de67354ffad0cddeb6309b0e8df5150bdd93b3197b03aad`).
SwiftPM placed both under a `wasm32-unknown-wasip1` scratch subdirectory. The
comparison demonstrates the runtime cost of this one fixture; it is not proof
of a `wasm32-unknown-none-wasm` browser ABI or a library size comparison.

The full SwiftWUI graph cannot be moved to Embedded today. `StateStore.link`
uses `Mirror` (`Sources/SwiftWUI/State/StateStore.swift`), node keys and effect
identities use `AnyHashable` (`Identity/Identity.swift`, `Effects/EffectStore.swift`),
and the renderer depends on Observation, Codable snapshots, Foundation
essentials, WASI, and JavaScriptKit. The explicit registration seam in
`State/ExplicitComponentRegistration.swift` is a compatibility experiment, but
does not remove those other runtime requirements. A future browser profile
would need an explicit allocator/interop ABI, a supported state serialization
format, and browser tests before it could be offered to users.
