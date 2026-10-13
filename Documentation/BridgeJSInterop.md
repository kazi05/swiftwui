# App-owned BridgeJS interop

SwiftWUI keeps its DOM bridge internal. For application JavaScript, install a
separate target instead:

```sh
swiftwui interop init --target App
```

The command creates `Interop/`, adds a local package dependency and an
`AppInterop` product to the named existing target, copies a small wrapper into
`public/interop/`, and inserts an early module loader in `index.html`. It then
generates BridgeJS glue. Re-run generation after changing any declaration:

```sh
swiftwui interop generate
```

Commit `Interop/Sources/AppInterop/Generated/`; it is generated ABI glue for the
JavaScriptKit 0.59.0 release and must not be edited. `Interop` pins that release
because BridgeJS remains experimental and its ABI changes between minor releases.
SwiftWUI itself requires JavaScriptKit 0.59.x, so the app's existing
`from: 0.22.0` dependency resolves to the same version. The scaffold needs
Swift 6.4, the pinned toolchain: Swift 6.3 cannot tell apart the two closure
initializers BridgeJS generates for its `(String) -> Void` callback and its
`Promise<string>` resolver, so `AppInterop` does not compile there, natively or
for wasm. After upgrading from a SwiftWUI release that pinned an older
JavaScriptKit, set `exact: "0.59.0"` in `Interop/Package.swift`, then update the
copied sources, because the scaffolder never overwrites them: move every
`export function` line from `bridge-js.d.ts` to `bridge-js.global.d.ts` except
`interopSubscribe`, which you delete; keep `bridge-js.d.ts` itself, comment-only;
take the new `Interop.swift`; and run `swiftwui interop generate`.

The public Swift facade is `AppInterop`: use `try AppInterop.greet("Ada")`,
`try await AppInterop.greeting("Ada")`, and
`try AppInterop.subscribe { message in ... }`. It rejects an empty name,
demonstrates a Promise, and returns a `Subscription`. Call `dispose()` on each
subscription: it unregisters the token in JavaScript, then releases the
callback, a `JSTypedClosure`, and drops it, so whatever the callback captured
is freed. A later call from JavaScript throws instead of running Swift. Pass new callbacks the same way: a `JSClosure` is never freed in
default JavaScriptKit builds, and neither is anything it captures. The generated
declarations beneath `Generated/` remain internal implementation details.

The loader stores its dynamic import in `window.__swiftwui_interop_ready`. The
SwiftWUI boot loader waits for it before instantiating WASM, so generated imports
are defined before their first call. A failed wrapper import fails boot visibly;
do not catch and hide it, because WASM imports would otherwise fail later with a
less useful error.

Declare imports in `bridge-js.global.d.ts`, which BridgeJS reads from
`globalThis`. Functions declared in `bridge-js.d.ts` are read from
`init({ getImports })`, which SwiftWUI's boot never passes, so the app would fail
to boot. Keep that file comment-only rather than deleting it: without it,
`swiftwui interop generate` fails, because the BridgeJS command plugin passes
`--project tsconfig.json` only when `bridge-js.d.ts` exists. Declare an import that takes a callback in
Swift instead, with `@JSFunction(from: .global)`, as `Interop.swift` does for
`interopSubscribe`: TS2Swift lowers a TypeScript function type to `JSObject`,
and only a `JSTypedClosure` can be released.

The command runs `npm install --ignore-scripts --no-audit --no-fund` inside the
resolved JavaScriptKit TS2Swift tool directory, followed by the BridgeJS command
plugin. TS2Swift currently has `package.json` but no lockfile, so `npm ci` cannot
run there. Pin/verify Node and the package checkout in CI when reproducibility
across machines is required.
