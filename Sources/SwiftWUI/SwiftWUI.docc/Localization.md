# Localization

Translated strings from JSON catalogs, type-safe through generated Swift, and
three ways to decide which language a visitor gets.

## Overview

A localized SwiftWUI app keeps its translations in `Locales/*.json`, one file
per language. `swiftwui l10n generate` turns those files into a Swift `L10n`
enum — one function per key, parameters typed from the placeholders — which
you commit alongside the catalogs. Nothing is looked up by string at runtime:
a renamed key is a compile error, and a missing translation degrades to the
app's default language rather than to a blank.

The whole feature is opt-in through one static property. An app that never
declares ``App/localization`` pays nothing: every branch described here is
inert, `LocalePath` is the identity function, and SSG output is byte-for-byte
what it was before.

```swift
@main
struct MyApp: App {
    static var localization: Localization? {
        Localization(catalog: L10n.self, default: .en, strategy: .pathPrefix())
    }
    var body: some Tag { Router { Route("/") { Home() } } }
}
```

A complete worked example — language switcher, plurals, RTL — lives in
`Examples/Localized`.

## Catalogs

Catalogs live in a `Locales/` folder inside the target that owns them — either
`Sources/<Target>/Locales/<tag>.json` for the default SwiftPM layout, or
`Sources/Locales/<tag>.json` for a target declared with `path: "Sources"`,
which is what every `swiftwui init` template does. Generation writes
`Generated/L10n.swift` next to `Locales/` either way, so it always lands
inside the target that will compile it. The set of files **is** the set of
declared locales — there is no config file and no list to keep in sync.

```json
{
  "add.item": "Add item",
  "items.count": "{count, plural, one {# item} other {# items}}",
  "welcome.title": "Hello, {name}!"
}
```

Keys match `[A-Za-z0-9._-]+` and the top level must be a flat object of
strings. Three things can appear in a value:

- `{name}` — a named placeholder. Becomes a `String` parameter.
- `{n, plural, one {…} other {…}}` — an ICU cardinal plural over CLDR
  categories `zero/one/two/few/many/other`. Becomes an `Int` parameter.
- `#` inside a plural branch — the plural variable rendered as bare digits.

Not supported: `select`, gender, nested plurals, more than one plural per
key, and any number or date formatting. Every locale of a given key must
agree on its placeholder set and its plural variable name, or generation
fails with `signatureMismatch`.

### Creating the first catalog by hand

`swiftwui l10n add <tag>` seeds a new catalog from an existing one, so it
cannot create the first. Write `Locales/en.json` yourself:

```bash
mkdir -p Sources/MyApp/Locales
$EDITOR Sources/MyApp/Locales/en.json      # the first one is manual
swiftwui l10n add ru                       # every later one is seeded
```

`add` copies the alphabetically-first catalog's keys and prefixes each value
with `TODO `, so the seed already passes validation and the translator sees
every key instead of copying them by hand.

### Exclude `Locales` from the target

The catalogs are codegen input, not a bundled resource. SwiftPM does not know
that, and warns about "unhandled" files unless you say so:

```swift
.executableTarget(name: "MyApp", dependencies: [/* … */],
                  exclude: ["Locales"],
                  swiftSettings: [.defaultIsolation(MainActor.self)])
```

`Generated/L10n.swift`, which lands next to `Locales/`, is a Swift file and
is compiled normally.

In a scaffolded project the same line reads `exclude: ["Locales"]` too — the
target's path is `Sources`, so the catalogs are at `Sources/Locales` and the
generated file at `Sources/Generated/L10n.swift`.

### There is no escape for a literal `{` or `#`

`{` always opens a placeholder, everywhere, and nothing quotes it. A
translator who writes `"Press {Ctrl}"` gets a key with a `Ctrl: String`
parameter, silently; `"Press {Ctrl+C}"` at least fails loudly, because
`Ctrl+C` is not an identifier. Inside a plural branch `#` is always the
number. Both are known gaps — if a string must contain a brace, the current
answer is to pass it in as a placeholder value from Swift.

### The mandatory `other` branch is dead code in several languages

ICU requires an `other` branch and so does the parser. For the integer-only
rules SwiftWUI ships, `ru`, `uk` and `pl` never *produce* `other` — CLDR
assigns it to fractional values only, and the generated rule returns
`one`/`few`/`many` for every `Int`. With those three present, the `other`
branch is unreachable:

```json
"items.count": "{count, plural, one {# элемент} few {# элемента} many {# элементов} other {# элемента}}"
```

A translator who edits only the `other` text of a Russian plural will see no
change at any count. Keep it as a copy of `many` and edit `many`.

Plural rules exist for `en de it es nl sv da nb fi el hu tr fr pt ru uk pl cs
sk ar ja zh ko`. A plural in a catalog for any other language fails
generation with `unsupportedPluralLanguage` rather than emitting code that
would not compile.

## Code generation

```bash
swiftwui l10n generate                     # rewrite Generated/L10n.swift
swiftwui l10n generate --check             # CI gate: fail if it is out of date
swiftwui l10n generate --allow-missing     # missing keys warn instead of failing
swiftwui l10n add <tag> [--target <name>]
```

**Commit `Generated/L10n.swift`.** It is ordinary source: it compiles without
a plugin, it is what makes a stale translation visible in a diff, and
`--check` is the CI gate that keeps it honest — it regenerates in memory and
compares byte-for-byte, writing nothing.

`swiftwui build` and `swiftwui ssg` run generation first, and `swiftwui dev`
watches `Locales/*.json` alongside your Swift files, so editing a translation
triggers the same regenerate → rebuild → reload path as editing code.

### Target detection

With no `--target`, the generator scans `Sources/*` in alphabetical order and
takes the **first** directory that owns a `Locales/` folder, and only if none
does, falls back to a flat `Sources/Locales`. That is silent and it is a
first-match, not a uniqueness check — a package with two such targets always
picks the same one and never mentions the other. `--target <name>` is the
escape hatch. It takes a single path component (no separators, no `..`) and
selects `Sources/<name>/Locales`, so it addresses the nested layout only; a
flat project has no target directory to name and does not need one.

### The generated file needs `MainActor` default isolation

`SwiftWUI` is built with `.defaultIsolation(MainActor.self)`, which makes
`LocaleID` and `LocalizedText` main-actor-isolated types. The generated file
touches both, so the target that compiles it must use the same setting:

```swift
swiftSettings: [.defaultIsolation(MainActor.self)]
```

Every `swiftwui init` template already does. Without it the build fails
inside the generated file with `main actor-isolated default value in a
nonisolated context` and `call to main actor-isolated initializer
'init(key:render:)' in a synchronous nonisolated context` — errors that point
at generated code and read as a codegen bug when they are a package setting.

### What the generator emits

For each key, one function returning ``LocalizedText`` — never `String`,
because the language is not known until the value reaches a render:

```swift
public enum L10n {
    public static func addItem() -> LocalizedText
    public static func itemsCount(count: Int) -> LocalizedText
    public static func welcomeTitle(name: String) -> LocalizedText
}

extension L10n: LocalizationCatalog {
    public static let supportedLocales: [LocaleID] = [.ar, .en, .ru]
}

extension LocaleID {
    public static let ar = LocaleID("ar")!
    public static let en = LocaleID("en")!
    public static let ru = LocaleID("ru")!
}
```

`supportedLocales` is ordered by canonical tag — alphabetically, not by any
declaration order — and that is the order ``EnvironmentValues/availableLocales``
hands to a switcher.

## Declaring localization

```swift
static var localization: Localization? {
    Localization(catalog: L10n.self, default: .en, strategy: .pathPrefix())
}
```

`default` must be one of `supported`: it traps in debug and falls back to
`supported.first` in release. `strategy` defaults to `.pathPrefix()`.

## Using translations

``Text`` takes a `LocalizedText` directly, and the sinks where an attribute
carries user-visible text have localized twins:

```swift
Main {
    H1 { Text(L10n.welcomeTitle(name: "SwiftWUI")) }
    P { Text(count == 0 ? L10n.cartEmpty() : L10n.itemsCount(count: count)) }
    Button(L10n.addItem()) { count += 1 }
    Img(src: "/logo.svg", alt: L10n.logoAlt())
    Input(value: $query, placeholder: L10n.searchPlaceholder())
}
.pageMeta(title: L10n.welcomeTitle(name: "SwiftWUI"))
```

The full localized set is `Text`, `Button`, `Img(alt:)`, `Input(placeholder:)`
(both the plain and the `Binding` form), `Textarea(text:placeholder:)`,
`.attribute(_:_:)` and `.pageMeta(title:)`. Note that `Page.title` is **not**
in it: `Page` is a plain `String` snapshotted before the locale is known, so
a localized document title goes through `.pageMeta(title:)`.

Container tags take no `LocalizedText` — `H1(L10n.x())` does not compile.
Wrap the text: `H1 { Text(L10n.x()) }`.

Anywhere else, resolve it yourself:

```swift
struct Note: Tag {
    @Environment(\.locale) private var locale
    var body: some Tag {
        P { Text("\(locale.identifier): \(L10n.directionNote().resolved(for: locale))") }
    }
}
```

Resolved strings go through the same serializer-only `HTMLEscaping` choke
point as any other value. Translations get no extra trust: URL-bearing
attributes are still scheme-sanitized, and `.attribute(_:_:)` is still a raw
escape hatch with no URL validation.

### A localized attribute always wins

`.attribute(_:_:)` with a `LocalizedText` does not write the attribute
immediately; it parks it and resolves it during `_resolve`, once the locale
is known. Resolution appends it *after* every plain attribute, and attribute
flattening is last-wins. So this renders the localized title, and swapping
the two lines changes nothing:

```swift
Span { "?" }
    .attribute("title", L10n.directionNote())   // wins
    .attribute("title", "fallback")             // ignored
```

That is the opposite of the usual "later modifier wins" reading. If you need
a plain value to win, don't set a localized one on the same attribute.

## Switching language at runtime

```swift
struct LocaleSwitcher: Tag {
    @Environment(\.availableLocales) private var locales
    @Environment(\.locale) private var current
    @Environment(\.setLocale) private var setLocale

    var body: some Tag {
        Nav {
            ForEach(locales, id: \.identifier) { locale in
                Button(locale.identifier, disabled: locale == current) { setLocale(locale) }
            }
        }
    }
}
```

Four environment keys:

| Key | Type | Notes |
| --- | --- | --- |
| `\.locale` | ``LocaleID`` | the active locale |
| `\.layoutDirection` | ``LayoutDirection`` | `.leftToRight` / `.rightToLeft`, derived from the locale's language |
| `\.availableLocales` | `[LocaleID]` | the declared set, so a switcher needs no `import` of `L10n` |
| `\.setLocale` | ``SetLocaleAction`` | call it: `setLocale(.ru)` |

``Runtime/setLocale(_:)`` validates against the declared set (an unknown
locale is a no-op plus a DEBUG warning), writes the signal, persists to
`localStorage["__swiftwui.locale"]`, sets `<html lang>` and `<html dir>`,
writes the negotiation cookie under `.negotiated`, rewrites the URL under
`.pathPrefix`, and then invalidates the whole tree. It does not arm a view
transition on its own — wrap the call in `withViewTransition` if you want one.

RTL needs no work of its own: switching to an RTL locale sets
`<html dir="rtl">` and switching back removes the attribute, so logical CSS
properties mirror the document by themselves. `\.layoutDirection` is there for
the cases where you have to branch in Swift.

## Resolution order

A `LocalizedText` resolves in this order, and stops at the first hit:

1. the exact tag (`ru-RU` matches a `ru-RU` catalog),
2. the primary language, but **only against region-less supported locales**,
3. the app's default locale,
4. the key itself.

Step 3 is why a key missing from one catalog degrades to the default language
rather than disappearing. Step 4 is the last resort — with
`--allow-missing`, a key absent from *both* the requested and the default
catalog renders as the literal `items.count`, which is loud enough to spot in
review. Without that flag a missing key fails generation instead.

Step 2 is asymmetric, and it surprises people. Matching is
`supported.first { $0.identifier == requested.language }`, so:

- app supports `["pt"]`, request `pt-BR` → **matches `pt`**;
- app supports `["pt-BR"]`, request `pt` → **no match**, falls to the default.

A bare `pt` does not find `pt-BR`. If you support only regional variants, a
visitor whose browser reports the bare language gets the default locale.
Declaring a region-less catalog is the fix.

`Localization.validated(_:)` applies the same exact-then-language rule to
every untrusted locale *string* — the URL prefix, `localStorage`, the cookie,
`navigator.languages` — before any of them can reach a filesystem path, a URL
or `<html lang>`. It fails closed: an unparseable or undeclared tag returns
`nil` and the chain moves on, never out.

## Choosing a strategy

| | `.pathPrefix()` | `.negotiated` | `.client` |
| --- | --- | --- | --- |
| **URL** | `/about/` and `/ru/about/` | `/about/` for every language | `/about/` for every language |
| **dist layout** | one folder per locale per page | one folder per locale, clean URLs inside | one tree, default locale only |
| **First frame** | already in the right language | already in the right language | default locale, then switches |
| **hreflang** | emitted, plus `x-default` | nothing to point at | nothing to point at |
| **Host** | any static host | must rewrite by cookie / `Accept-Language` | any static host |
| **SEO** | strongest: one indexable URL per language | Google's "dynamic serving"; needs `Vary` | weakest: one language indexed |

`.pathPrefix()` is the default and the right answer for most public sites.
`.client` is for apps where SEO does not apply — a dashboard behind a login.
`.negotiated` buys clean URLs at the price of a host requirement; read the
next two sections before choosing it.

### `.pathPrefix` detection and the one-frame flash

The default locale lives at the site root (`/about/`), every other locale
under its tag (`/ru/about/`). `LocalePath` is the only place prefixes exist:
the runtime's `currentPath` is always locale-free, so route matching,
``RouteParam``, guards and `.prerender` policies never see one.

`.pathPrefix(detection: .full)` — the default — also consults
`localStorage` and `navigator.languages`, but **only when the URL named no
locale**. A URL that does name one always wins, under both detection modes:
it is either a link somebody deliberately shared or a history entry the
runtime wrote itself.

The cost: a returning Russian-speaking visitor who deep-links to `/about/`
(the *default locale's* canonical URL, which names nothing) gets the
prerendered English frame, and then detection switches the page to Russian
and `replaceState`s to `/ru/about/`. One flash, once, at boot.

`.pathPrefix(detection: .urlOnly)` is the one-line opt-out: the URL decides
and nothing else is even read.

### `navigate` takes the internal path

``NavigateAction`` and `Runtime.navigate(to:)` take the **locale-free** path.
Prefixes are added on output, never consumed on input:

```swift
navigate("/about")        // correct in every locale
navigate("/ru/about")     // wrong: becomes /ru/ru/about, matches nothing
```

The wrong form produces a blank page with no error: `/ru/about` is not a
route, and the prefix gets applied on top of it. DEBUG builds print
`navigate('/ru/about') carries a locale prefix — pass the locale-free path`;
release builds are silent. ``Link`` handles this for you — its `href` carries
the prefix while its click still navigates to the internal path.

## Deploying `.negotiated`

`.negotiated` serves real localized HTML at a clean URL. Every language of
`/about/` is prerendered to its own folder (`dist/ru/about/index.html`), and
the *edge* decides which folder answers a request: cookie `swiftwui_locale`
first, then `Accept-Language`, then the default.

`swiftwui ssg` writes `dist/swiftwui-site.json` — a small descriptor, since
the toolchain does not depend on SwiftWUI and cannot read your Swift statics
— then generates `dist/nginx.conf` from it and prints:

```
NOTE: this site uses the .negotiated locale strategy — clean URLs with
per-locale folders. It requires a host that can rewrite by cookie/Accept-Language.
Wrote dist/nginx.conf; on GitHub Pages or bare S3 only 'en' will be reachable.
```

That warning is literal. **On GitHub Pages, bare S3, or any host that only
maps paths to files, only the default locale is reachable** — nothing
rewrites `/about/` to `/ru/about/index.html`, and the other folders are dead
weight. `.negotiated` needs nginx, Caddy, Netlify, Vercel, Cloudflare or an
equivalent.

The generated rule is:

```nginx
add_header Vary "Accept-Language, Cookie";
location / { try_files $uri /$swui_locale$uri/index.html /$swui_locale/index.html /index.html; }
```

`$uri` is tried first, so root-level assets (`main.wasm`, `styles.css`,
anything from `public/`) are never locale-prefixed — locale folders hold
documents only. `$swui_locale` comes from two `map` blocks written above it:
the cookie wins, then the first matching tag of `Accept-Language`, then the
default. nginx `map` regexes are first-match, which approximates `q`-value
ordering; the cookie, written after any explicit user choice, is exact.

`Vary: Cookie` measurably reduces CDN cache efficiency. That is the cost of
one URL per page.

`swiftwui serve dist` reads the same descriptor and applies the same order,
so you can check the behaviour locally before deploying. `swiftwui dev`
does not: it serves the SPA shell with no per-locale prerenders, and the
locale is resolved client-side — which is the intended dev behaviour.

### A `build`-only dist does not negotiate yet

`swiftwui build -c release` also writes `dist/nginx.conf`, but the descriptor
is written by `ssg`. Until you have run `swiftwui ssg`, `dist/` has no
`swiftwui-site.json`, so that `nginx.conf` is the plain SPA config with no
negotiation block in it. Run `ssg` — and re-run it after any `build` that
overwrites the file — before deploying a `.negotiated` site.

A service worker could in principle do the same rewrite without an edge, but
it covers neither a first visit nor a crawler. Out of scope.

## Prerendering a localized site

`StaticSite.generate` enumerates routes exactly once — patterns and
`.paths { }` providers are locale-free and run a single time — and then
renders the page set once per locale. `StaticSiteReport` gains `locales` and
`writtenFiles`; `pages` keeps meaning URL paths.

Per document: `<html lang>` and `dir` come from the locale the page settled
on, canonical synthesis uses that locale's external path, and under
`.pathPrefix` the head also carries `<link rel="alternate" hreflang>` for
every locale plus `x-default` pointing at the default. Like canonical
synthesis, hreflang requires `StaticSiteConfig.siteURL` — relative hreflang
is ignored by search engines, so without an origin none is emitted.

Policies are per pattern, not per locale: `.prerender(.never)` suppresses
every language of that route, and `skippedPatterns`/`onDemandPatterns` stay
pattern-keyed rather than multiplying by locale count.

`report.pages` and the sitemap are keyed on the browser-visible URL and
deduplicated. Under `.pathPrefix` that means one sitemap entry per locale per
page — the URLs differ. Under `.negotiated` every locale of a page shares one
URL, so it is listed once, no matter how many folders were written.

**Every locale renders from a fresh `Runtime`.** That means `.staticTask`
loaders run once *per locale*: a three-language site makes three times the
build-time fetches. If a loader is expensive or rate-limited, cache it
outside the render — the framework does not deduplicate across locales, and
cannot, because a loader may legitimately fetch localized content.

`StaticSite.render(_:path:config:locale:)` takes the locale explicitly and
returns a `RenderedPage` that already knows where it goes:

```swift
let page = try await StaticSite.render(MyApp.self, path: "/about",
                                       config: config, locale: .ru)
try StaticSite.writeDocument(page.html, path: page.path, outDir: out, subdir: page.subdir)
```

Use `page.path` and `page.subdir`, not the path you asked for: `path` is the
browser-visible URL (prefix included) and `subdir` is the output folder,
which differ under `.negotiated` and can differ from the request whenever a
`.staticTask` called `setLocale`.

## Accepted limits

1. **No number, date or relative-time formatting.** `#` renders as bare
   digits.
2. **Every locale's strings are compiled into the binary** — tens of KB per
   locale. Lazy per-locale loading stays possible later; nothing here blocks
   it.
3. **`.pathPrefix(.full)` can flash the language once after hydration.**
   `.urlOnly` opts out.
4. **A locale change re-renders the whole tree** (`markDirty(.root)`).
   `Text` resolves the locale inside `_resolve`, outside the Observation
   window, so a targeted invalidation would miss exactly the components
   displaying translated text. Acceptable for a user-rare action.
5. **`.negotiated` needs host configuration** and is weaker for multilingual
   SEO than `.pathPrefix`.
