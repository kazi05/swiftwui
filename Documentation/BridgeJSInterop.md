# App-owned BridgeJS interop

SwiftWUI keeps its DOM bridge internal. For application JavaScript, install a
separate target instead:

```sh
swiftwui interop init --target App
```

The command creates `Interop/`, adds a local package dependency and an
`AppInterop` product to the named existing target, copies a small wrapper into
`public/interop/`, and inserts an early module loader in `index.html`. It then
generates BridgeJS glue. Re-run generation after changing either declaration:

```sh
swiftwui interop generate
```

Commit `Interop/Sources/AppInterop/Generated/`; it is generated ABI glue for the
resolved JavaScriptKit 0.56.1 release and must not be edited. `Interop` pins that
release because BridgeJS remains experimental. The app's existing `from: 0.22.0`
dependency resolves to the same compatible 0.56.1 version.

The public Swift facade is `AppInterop`: use `try AppInterop.greet("Ada")`,
`try await AppInterop.greeting("Ada")`, and
`try AppInterop.subscribe { message in ... }`. It rejects an empty name,
demonstrates a Promise, and returns a `Subscription`. Call `dispose()` on each
subscription; the facade retains its `JSClosure` until disposal and releases it
after JavaScript unregisters the token. The generated declarations beneath
`Generated/` remain internal implementation details.

The loader stores its dynamic import in `window.__swiftwui_interop_ready`. The
SwiftWUI boot loader waits for it before instantiating WASM, so generated imports
are defined before their first call. A failed wrapper import fails boot visibly;
do not catch and hide it, because WASM imports would otherwise fail later with a
less useful error.

The command runs `npm install --ignore-scripts --no-audit --no-fund` inside the
resolved JavaScriptKit TS2Swift tool directory, followed by the BridgeJS command
plugin. TS2Swift currently has `package.json` but no lockfile, so `npm ci` cannot
run there. Pin/verify Node and the package checkout in CI when reproducibility
across machines is required.
