# Static delivery and public indexing

`StaticSiteMode.staticOnly` emits the rendered HTML and CSS only. It does not
emit an import map, module script, boot loader, WASM URL, state snapshot, or
module preload. Use it for documents whose interaction is not needed after the
initial response.

For a public site, opt into the generated-output checks rather than applying
them to private applications:

```swift
let config = StaticSiteConfig(
    outDir: "dist",
    mode: .staticOnly,
    siteURL: "https://example.com",
    indexing: .indexed,
    delivery: .init(
        redirects: [.init(from: "/old-pricing", to: "/pricing", status: .movedPermanently)],
        trailingSlash: .never
    )
)
```

Indexed builds require an absolute `http` or `https` origin, a non-empty title
and description, an absolute self-canonical for every rendered page, valid
JSON-LD, and local links that resolve to a generated page or declared redirect.
This verifies the artifact. It cannot verify robots directives from a CDN,
Search Console coverage, rendered crawler output, or rankings; check those
after deployment.

When redirects or a slash policy are configured, SSG writes
`swiftwui-delivery.json` with exact redirects, generated routes, and the
trailing-slash policy. `swiftwui serve` reads it and returns real 301,
302, or 308 responses before looking up files. A release writes
`swiftwui-redirects.conf` and embeds the same exact rules in `nginx.conf`.
The manifest and generated include are hidden from HTTP and excluded from PWA precache.

`always` and `never` trailing-slash policies apply only to generated document
routes. Assets are left alone. Indexed builds default to a real 404 for an
unknown clean URL; an optional root `404.html` supplies its body while retaining
status 404. Private applications retain the historical SPA fallback unless
`delivery.fallback` is set to `.notFound`; set it explicitly to `.spa` for a
public SPA that intentionally owns unknown paths. The host adapter must be
regenerated after each SSG run.

Delayed client activation and islands are separate from static delivery. They
can defer startup work, but share a module unless an app supplies separately
compiled bundles; they do not by themselves reduce downloaded WASM bytes.
For a hydrated site, set `activation: .idle`, `.visible`, or `.interaction`
and supply `activationSelector` for the latter two. A static-only build ignores
those values and remains free of boot resources.

If an app uses generated BridgeJS bindings, set `interopScriptURL` to its
app-owned wrapper module. The document records `import(url)` in
`window.__swiftwui_interop_ready`; both the streamed boot loader and the
legacy module path await it before Swift imports the application entry.
