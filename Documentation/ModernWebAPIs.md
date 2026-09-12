# Resources, navigation, islands and workers

## Read resources and async UI

Create one `WebResourceCache(session:)` per application/session. Concurrent GETs
with the same URL, headers and transport timeout share a request. Cancelling a
consumer cancels only its wait; the last consumer aborts the transport. A late
response after invalidation cannot overwrite a fresh entry. Successful results
expire after `ttl` seconds; failures and `Cache-Control: no-store/no-cache`
responses are not cached. The default capacity is 128 entries. Mutations stay
on `WebSession`; call `invalidate(url:)` after a successful mutation.

```swift
let cache = WebResourceCache(session: session)
let messages: [Message] = try await cache.json(from: "/api/messages", ttl: 20)
cache.invalidate(url: "/api/messages")
```

`snapshot()` exports unexpired, headerless results explicitly; `seed(_:)`
restores them. Select public data before embedding a snapshot in static HTML.
Use the existing JSON script escaping when transporting it. Snapshots do not
automatically serialize session/authenticated data or enter `@State` payloads.

`AsyncResource<Value>` exposes `.idle`, `.pending`, `.success(value)` and
`.failure(message)`. `load()` retries, `reset()` prevents late publication, and
caller task cancellation returns to idle. `AsyncBoundary(resource) { state in
... }` supplies the state to a TagBuilder and runs the loader in a lifecycle
task. The application owns loading, error and retry presentation.

## Progressively enhanced forms

`EnhancedForm(action:method:submission:onSubmit:content:)` emits an ordinary
GET/POST form. Before hydration the browser submits named controls to the
action URL. After hydration it passes textual successful controls, including
the submitter and repeated names, in `SubmitEvent.fields`. The async handler
returns `FormResult<Value>` with optional value, field errors and a message.
`FormSubmission` exposes pending/error state, cancels an older submission when
replaced, and rejects late completions. Unmount cancels the pending operation.

The host endpoint must implement the same operation for native form submission
and the application's enhanced handler. Add associated labels, field-error
IDs/`aria-describedby`, and a visible result region in the content closure.
File uploads use `WebSession.upload`; binary files are not converted to strings.

## Navigation accessibility

The DOM backend moves focus after the route's DOM commit, announces the page
title in a polite live region, scrolls new navigation to the top and restores
back/forward positions. The default focus target is the first matching
`[data-swui-route-focus], main, h1`. A generated `tabindex="-1"` allows
programmatic focus without adding a keyboard tab stop. Native/modified links
retain their existing browser behavior.

Set `DOMRuntime.navigationOptions` before mounting to customize the selector,
announcements and scrolling, or use `.disabled` for application-owned behavior.
Focus and scrolling wait for guard redirects to settle.

## Deferred activation and islands

`StaticSiteConfig(activation: .idle/.visible/.interaction)` defers the WASM
request and startup. Visible/interaction policies can use `activationSelector`;
a missing target falls back to eager startup. Native form/link events are never
cancelled or synthesized while waiting. Idle has a 2-second fallback deadline.
Use `.staticOnly` when a page should ship no client runtime at all.

`DOMRuntime.mountIsland({ Widget() }, selector: "#widget", activation: .visible)`
returns a `DOMIsland` handle. Retain it and call `dispose()` to cancel activation
or unmount its tasks, listeners and state. `activate()` overrides any policy.
Static child HTML remains until activation, when this first implementation
replaces it. Check `failure` for an unsupported routing tree.

An island must own a dedicated container outside another runtime's reconciled
tree. Islands are leaf widgets; keep `Router` in the document root. Global
`@Dependency` services continue to belong to that document; `@Environment`
provides runtime-local values. Islands share one downloaded module. Delaying
them reduces initial work, not the bytes of that shared module.

## Compute workers

Create `ComputeWorker<Request: Encodable & Sendable, Reply: Decodable & Sendable>(moduleURL:)` in
`SwiftWUIDOM`, then call `await worker.call(request)`. The result has typed
`value` and optional transferred `buffers`. Close the worker on teardown;
`close()` terminates it and resumes every pending call with an error.

In a package with default MainActor isolation, declare message models
`nonisolated struct Input: Codable, Sendable { ... }` so their Codable
conformances are also available outside an actor.

The application module worker imports the helper copied by the build:

```javascript
import { serveWorker, workerResult } from '/app/swiftwui-worker.js';
serveWorker(async (input, { signal, buffers, compiledModule }) => {
  // Chunk long work and yield so cancellation messages can be received.
  if (signal.aborted) throw new Error('cancelled');
  return workerResult({ answer: input.value * 2 }, buffers);
});
```

`WorkerBuffer(takingArrayBuffer:)` makes ownership explicit. A successful
`call(transferring:)` detaches the sender's ArrayBuffer; aliases must not be
reused. A failed synchronous postMessage retains ownership. Responses can
transfer buffers back. `compiledModule:` can pass an already compiled
WebAssembly.Module to the worker for reuse. The default protocol uses ordinary
workers and needs no shared memory or cross-origin isolation. DOM manipulation
remains on the main thread. A synchronous CPU loop cannot process cancellation
until it yields; `close()` provides hard termination.

## Diagnostics

Pass `RuntimeDiagnostics` to a Runtime or set `DOMRuntime.diagnostics` before
mounting. Timing/tree collection is skipped when no sink is present. In debug
WASM builds, `DOMRuntime.enableDevTools()` installs a bounded metadata ring at
`window.__swiftwui_diagnostics`, including render reasons, component identities,
lifetimes and adoption failures. This bridge is excluded from release builds.
Boot marks named `swiftwui:network-start`, `response`, `download-end`,
`init-start` and `ready` are available through the browser Performance API;
network download and streaming compilation overlap.

Runnable browser examples and regression checks live in
`Tests/BrowserEvents/Sources/ModernWebFixture.swift` and
`Sites/Tutorial/tools/screenshots/browser-modern.spec.mjs`.
