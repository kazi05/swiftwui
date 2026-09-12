# Runtime modernization

## Render diagnostics

`RuntimeDiagnostics` is an opt-in Swift event sink. With no diagnostics value,
the runtime does not read a clock, traverse the rendered tree, allocate events,
or call JavaScript. Enable it at runtime construction when profiling a fixture:

```swift
let diagnostics = RuntimeDiagnostics(
    includeTreeStatistics: true,
    includeComponentTree: true
) { event in
    print(event)
}

let runtime = Runtime(
    backend: backend,
    container: container,
    root: Root(),
    scheduleMicrotask: schedule,
    diagnostics: diagnostics
)
```

Render events report coalesced reasons, the number of dirty identities, the
minimal-cover root count, pass duration, and live state/listener/effect counts.
Tree statistics are separately configurable because they require a full tree
walk. The optional component tree is a pre-order list of component type names,
identities, and parent identities; it excludes text and attributes so enabling
it does not copy rendered content. `AdoptingBackend` accepts the same diagnostics value and reports success,
tolerated top-level extension nodes, or a cold-render fallback mismatch.

The dirty-cover benchmark is runnable with:

```sh
SWIFTWUI_BENCHMARKS=1 swift test --filter RuntimeDirtyCoverBenchmarkTests
```

It records 100 selections for 50, 100, and 500 dirty siblings and reports the
legacy cover scan beside the ancestor-lookup implementation. Compare results
on the same compiler, build configuration, and machine. The benchmark has no
wall-time threshold because scheduler and debug-build noise make such a gate
unreliable; its behavioral assertion still verifies every sibling remains in
the cover.

The 12 September 2026 serialized debug run on arm64 macOS with Swift 6.3.3
recorded the following 100-selection totals. These are local diagnostic
measurements rather than release-build guarantees:

| Dirty siblings | Legacy cover scan | Ancestor lookup | Relative reduction |
| ---: | ---: | ---: | ---: |
| 50 | 102.91 ms | 2.93 ms | 35x |
| 100 | 407.97 ms | 6.32 ms | 65x |
| 500 | 11.195 s | 29.75 ms | 376x |

The initial end-to-end run measured complete coalesced sibling updates at
10.91 ms, 35.50 ms, and 739.92 ms for 50, 100, and 500 rows. Profiling the code
path exposed a second quadratic cost: every scoped pass independently searched
and copy-on-write spliced the virtual tree. One pre-pass index and one batched
splice reduced the same measurements to 3.24 ms, 6.22 ms, and 31.59 ms. This
number includes component resolution, diffing, renderer commands applied to
MockBackend, and registry cleanup. It is debug native evidence only; release and browser/WASM profiling
remain environment-specific gates.

## Explicit component registration

Components can opt out of Mirror-based wrapper discovery and choose a stable
cross-binary hydration name:

```swift
struct Counter: Tag, ExplicitComponentRegistration {
    @State private var count = 0
    @Environment(\.routeInfo) private var route

    static let componentIdentifier = "com.example.counter.v1"

    func registerProperties(_ properties: inout ComponentProperties) {
        properties.state(_count, stableID: "count")
        properties.environment(_route)
    }

    var body: some Tag { Text("\(route.path): \(count)") }
}
```

Give every state property a unique `stableID` to preserve it when declarations
are reordered or a later version adds or removes another slot. The encoded row
stores these names while still accepting older positional snapshots. The
unnamed `properties.state(_count)` form keeps declaration-order behavior for a
gradual migration, but named and unnamed registrations cannot be mixed in one
component. Keep `componentIdentifier` stable across the native SSG and
WebAssembly builds, and version it only when intentionally abandoning old
snapshots. Components without this conformance continue to use Mirror and keep
their current behavior. A macro or source generator can emit the registration
method without changing the runtime contract. The repository includes the
dependency-free `Scripts/generate-component-registration.mjs` prototype. Its
JSON configuration names each component source file, type, stable component
identifier, state slots, and environment properties; run it with
`node Scripts/generate-component-registration.mjs components.json`:

```json
{
  "components": [{
    "file": "Sources/App/Counter.swift",
    "type": "Counter",
    "access": "public",
    "identifier": "com.example.counter.v1",
    "state": [{ "property": "count", "id": "count" }],
    "environment": ["route"]
  }]
}
```

`access` defaults to `internal`; set it to `public` when the conformance
witnesses must be public. A state entry may use the shorthand `"count"` when
the property name is also its stable ID. The generator writes the conformance
into the component's own source file so it can access private wrapper storage.
Repeat runs are byte-for-byte idempotent. Duplicate component types, component
identifiers, state IDs, property registrations, or generated markers fail
validation before any source file changes.
This registration removes reflection from component linking; it does not yet
make the complete package compatible with Embedded Swift because other runtime
features still use `Any`, `AnyHashable`, Codable, and dynamic type metadata.

## Fixed-height virtual collections

`VirtualForEach` owns a vertical scrollport and renders only the visible rows,
plus a configurable overscan window. Every row is keyed with the supplied ID.
The initial server and client render includes `initialItemCount` leading rows,
so static HTML remains useful and hydration sees the same shape.

```swift
VirtualForEach(messages,
               rowHeight: 44,
               viewportHeight: 528,
               overscan: 4,
               initialItemCount: 24,
               accessibilityLabel: "Messages") { message in
    MessageRow(message: message)
}
```

Rows must actually fit the declared fixed height. Dynamic-height content will
produce incorrect spacer geometry. Virtualization also removes off-window rows
from browser find-in-page and the accessibility tree. Use `.complete` for a
small collection where full traversal is more important than DOM size, provide
an accessible label for the focusable scrollport, and do not move keyboard
focus into a row that may be evicted without first defining focus restoration.
The initial fallback is a bounded preview rather than full SEO indexing of a
large dataset; publish distinct static pages when every item must be crawlable.
