/// Optional per-locale path patterns (spec 2026-08-02 §2).
///
/// Empty by default: an app that declares none pays nothing, and `LocalePath`
/// short-circuits to its pre-existing behaviour character for character.
///
/// The canonical pattern is written exactly as the corresponding `Route(...)`
/// pattern — it is the identity key that ties the two together.
public struct LocalizedRoutes {
    public struct Entry {
        public let canonical: RoutePattern
        let localized: [LocaleID: RoutePattern]
        /// Locale tags `LocaleID(_:)` rejected. Collected, never trapped: this
        /// value is built during `static let` initialization, where a trap kills
        /// the process before any diagnostic can print. Surfaced by validation.
        let invalidTags: [String]
        /// Raw tags that NORMALIZED to the same `LocaleID` — `["ru", "RU"]`.
        /// `localized` keeps only the last of them, so the author silently gets
        /// a mapping they did not write. Collected here for the same reason as
        /// `invalidTags`, and reported by `_validate` (V15).
        let collidingTags: [LocaleID: [String]]
        /// The author's V6 opt-out: an EARLIER entry's canonical pattern also
        /// matches some of these paths, and that is intended.
        let overlapsEarlierEntry: Bool
    }

    /// Declaration order is load-bearing — resolution is first-match-wins,
    /// exactly like `Router`.
    let entries: [Entry]

    public var isEmpty: Bool { entries.isEmpty }
    public static let none = LocalizedRoutes()

    public init(@LocalizedRoutesBuilder _ build: () -> [Entry] = { [] }) {
        self.entries = build()
    }
}

/// The name entries are written under: `LocalizedRoute("/about", ["ru": "/o-nas"])`.
///
/// Spelled as an initializer, not the spec's `.path(...)` factory: two
/// leading-dot lines in a row parse as ONE chained expression, so
/// `.path("/a")` / `.path("/b")` on consecutive lines fails to compile with
/// "static member 'path' cannot be used on instance of type". A statement that
/// starts with an identifier has no such trap — which is why `Route(...)` in
/// `RouteBuilder` reads the way it does.
public typealias LocalizedRoute = LocalizedRoutes.Entry

extension LocalizedRoutes.Entry {
    /// Locale keys are `String`, not `LocaleID`: `LocaleID`'s only initializer
    /// is failable, so a typed key would force `[LocaleID("ru")!: …]` at every
    /// declaration. The raw tags pass through that same validating initializer
    /// here — one choke point, as everywhere else locale strings arrive.
    ///
    /// - Parameter overlapsEarlierEntry: opts this entry out of the overlap
    ///   check, which otherwise rejects two patterns that some path matches
    ///   both of. Set it on the LATER of the pair — the shadowed one — to say
    ///   "an earlier entry also claims these paths; resolve me by declaration
    ///   order, like `Router` does":
    ///
    ///   ```swift
    ///   LocalizedRoute("/blog/archive", ["ru": "/novosti/arkhiv"])
    ///   LocalizedRoute("/blog/:slug", ["ru": "/novosti/:slug"], overlapsEarlierEntry: true)
    ///   ```
    ///
    ///   The trade: declaration order now decides this site's URLs, and the
    ///   build stops watching that pair. Swapping the two lines above is
    ///   caught — the flag travels with its line, so it lands on the EARLIER
    ///   entry and the overlap is reported again. The hazard is the step after
    ///   that: move the flag onto the new later entry to silence the build, and
    ///   `/blog/archive` now externalizes as `/novosti/archive` instead of
    ///   `/novosti/arkhiv`, with nothing left to say so.
    ///
    ///   Suppression is per ORDERED PAIR of entries and only between patterns
    ///   of the same kind — canonical against canonical, slug against slug.
    ///   Everything else still reports:
    ///
    ///   - two patterns of ONE entry, such as a slug colliding with its own
    ///     canonical — there is no declaration order to appeal to;
    ///   - one entry's slug against another's canonical: `internalize` tries
    ///     slugs before declared canonicals, so the slug wins whatever the
    ///     entry order is, and that canonical is unreachable at its own URL;
    ///   - V5, the same canonical pattern declared twice, which is checked
    ///     per entry and never consults the flag at all.
    ///
    /// A malformed LOCALE TAG is collected (`invalidTags`) and reported; a
    /// malformed PATTERN — a mid-pattern `*`, an empty `:` name — traps in
    /// debug inside `RoutePattern.init`, in this same declaration. The
    /// asymmetry is deliberate but inherited: `RoutePattern` predates this type
    /// and every `Route(...)` in the app is built the same way, so a pattern
    /// trap is a failure mode the author already has. The tags are the part
    /// this type could keep out of it, and does.
    public init(_ canonical: String, _ localized: [String: String],
                overlapsEarlierEntry: Bool = false) {
        var parsed: [LocaleID: RoutePattern] = [:]
        var invalid: [String] = []
        var rawTags: [LocaleID: [String]] = [:]
        for tag in localized.keys.sorted() {           // sorted: deterministic invalidTags
            if let id = LocaleID(tag) {
                parsed[id] = RoutePattern(localized[tag]!)
                rawTags[id, default: []].append(tag)
            }
            else { invalid.append(tag) }
        }
        self.canonical = RoutePattern(canonical)
        self.localized = parsed
        self.invalidTags = invalid
        self.collidingTags = rawTags.filter { $0.value.count > 1 }
        self.overlapsEarlierEntry = overlapsEarlierEntry
    }
}

// Mirrors RouteBuilder (Routing/Route.swift:61): variadic buildBlock also covers
// the empty block — do NOT add a zero-arg overload (ambiguity).
@resultBuilder
public enum LocalizedRoutesBuilder {
    public static func buildBlock(_ parts: [LocalizedRoutes.Entry]...) -> [LocalizedRoutes.Entry] {
        parts.flatMap { $0 }
    }
    public static func buildExpression(_ e: LocalizedRoutes.Entry) -> [LocalizedRoutes.Entry] { [e] }
    public static func buildOptional(_ e: [LocalizedRoutes.Entry]?) -> [LocalizedRoutes.Entry] { e ?? [] }
    public static func buildEither(first: [LocalizedRoutes.Entry]) -> [LocalizedRoutes.Entry] { first }
    public static func buildEither(second: [LocalizedRoutes.Entry]) -> [LocalizedRoutes.Entry] { second }
    public static func buildArray(_ parts: [[LocalizedRoutes.Entry]]) -> [LocalizedRoutes.Entry] {
        parts.flatMap { $0 }
    }
}

extension LocalizedRoutes {
    /// Canonical path → this locale's slug, or nil when the table says nothing.
    /// First entry whose canonical pattern matches AND that declares `locale`;
    /// validation (V5/V6) guarantees at most one entry can match at all, unless
    /// a later entry opted out with `overlapsEarlierEntry` — then first-match
    /// in declaration order is the answer the author asked for.
    func _localizedPath(for path: String, locale: LocaleID) -> String? {
        for entry in entries {
            guard let pattern = entry.localized[locale],
                  let params = entry.canonical._matchRaw(path) else { continue }
            return Self.substituteRaw(params, into: pattern)
        }
        return nil
    }

    /// A localized slug → its canonical path plus the locale that owns it.
    /// Locales are visited in identifier order so the result cannot depend on
    /// Dictionary seeding; validation (V4) makes at most one of them match.
    func _canonicalPath(for path: String) -> (path: String, locale: LocaleID)? {
        for entry in entries {
            for locale in entry.localized.keys.sorted(by: { $0.identifier < $1.identifier }) {
                guard let params = entry.localized[locale]!._matchRaw(path) else { continue }
                return (Self.substituteRaw(params, into: entry.canonical), locale)
            }
        }
        return nil
    }

    /// The prefix-form URLs this table RETIRED, each paired with the URL that
    /// replaced it: `/ru/about` → `/o-nas`, and `/ru` → `/glavnaya` when the
    /// home page itself is slugged (trimming a URL down to the bare locale is
    /// the commonest manual edit there is, and no build ever writes `/ru`).
    ///
    /// Adding a slug to a live site stops writing a URL that is already
    /// indexed, linked and bookmarked, so the SSG leaves a redirect behind at
    /// every one of these. The location is what the prefix rule WOULD have
    /// produced — this table disabled — and the target is what it produces now.
    ///
    /// Static canonicals only: a parameterised pattern has no single retired
    /// URL, one per parameter combination instead, and which of those a build
    /// ever wrote is not something the table knows.
    ///
    /// `canonical` comes back with the pair so the caller can check that this
    /// build actually rendered the page: a stub is worth nothing if it points
    /// at a URL no one wrote.
    public func _retiredPrefixPaths(default defaultLocale: LocaleID)
        -> [(canonical: String, retired: String, current: String)] {
        entries.filter(\.canonical.isStatic).flatMap { entry in
            entry.localized.keys.sorted { $0.identifier < $1.identifier }
                .compactMap { locale -> (canonical: String, retired: String, current: String)? in
                    let retired = LocalePath.externalize(entry.canonical.raw, locale: locale,
                                                         default: defaultLocale)          // no table
                    let current = LocalePath.externalize(entry.canonical.raw, locale: locale,
                                                         default: defaultLocale, routes: self)
                    guard retired != current else { return nil }
                    return (RouteURL._normalize(entry.canonical.raw), retired, current)
                }
        }
    }

    /// Is this path one of the table's own canonical patterns, and does that
    /// pattern START WITH A LITERAL? Such a path is locale-free by definition
    /// and must not reach the prefix split, which would eat a leading segment
    /// that merely looks like a locale tag (`/de/history`).
    ///
    /// The literal check is the whole guard: `/:slug` matches `/de` — the very
    /// URL `externalize("/", de)` produces — and `/:a/:b` matches `/ru/contact`,
    /// by segment count alone. Without it, localizing an ordinary parametric
    /// route (the feature's headline use case) would swallow every prefixed URL
    /// and report no locale; `/*` would disable prefixes app-wide.
    func _declaresCanonical(_ path: String) -> Bool {
        entries.contains { entry in
            guard case .literal = entry.canonical.segments.first else { return false }
            return entry.canonical._matchRaw(path) != nil
        }
    }

    /// The inverse: raw segments spliced into another pattern, by NAME.
    ///
    /// A name the caller did not supply splices in as EMPTY — `/dostavka//x`,
    /// which `normalizePath` does not repair (it strips a trailing slash only).
    /// V11 is what makes that unreachable; there is deliberately no guard here,
    /// because a silent repair would hide the misdeclaration from the build.
    static func substituteRaw(_ params: [String: String], into pattern: RoutePattern) -> String {
        var out = ""
        for seg in pattern.segments {
            switch seg {
            case .literal(let lit): out += "/" + lit
            case .param(let name):  out += "/" + (params[name] ?? "")
            case .catchAll:
                let tail = params["*"] ?? ""
                if !tail.isEmpty { out += "/" + tail }
            }
        }
        return out.isEmpty ? "/" : out
    }
}

extension LocalizedRoutes {
    /// Table-only checks (spec §4: V1–V6, V10–V12, V15, plus the table half of
    /// V7). Every one of these fails SILENTLY at runtime and looks like a
    /// working site, so they are rejected at build time instead.
    ///
    /// A REPORTING pass, never a trap: the table is built during `static let`
    /// initialization, where a trap kills the process before any diagnostic can
    /// print — the same reason `invalidTags` is collected rather than asserted.
    /// Task 9 wraps the result in a thrown error and adds the checks that need
    /// the collected route set (V7's other half, V8, V9, V14) and `config`
    /// (V13 — `siteURL` lives in SwiftWUIStatic and is not reachable here).
    ///
    /// Empty table → no checks, ever.
    public func _validate(localization: Localization) -> [String] {
        guard !isEmpty else { return [] }
        var out: [String] = []

        // V1 — under any other strategy the table is not an error, it is a
        // total no-op: `usesURLPrefix` short-circuits before it is ever read.
        if !localization.strategy.usesURLPrefix {
            out.append("routePaths requires strategy .pathPrefix — under the declared strategy the table is silently ignored")
        }

        var seenCanonical: Set<String> = []
        for entry in entries {
            let canon = entry.canonical.raw

            // V5
            if !seenCanonical.insert(canon).inserted {
                out.append("routePaths declares '\(canon)' twice — merge the locales into one entry")
            }

            // V3 (unparseable)
            for tag in entry.invalidTags {
                out.append("routePaths entry '\(canon)': '\(tag)' is not a locale tag")
            }

            // V15 — normalization collision. `localized` kept only the last of
            // these, so the entry means something the author did not write.
            for id in entry.collidingTags.keys.sorted(by: { $0.identifier < $1.identifier }) {
                out.append("routePaths entry '\(canon)': locale tags \(entry.collidingTags[id]!) all normalize to '\(id.identifier)' — only one of them survives, keep a single spelling")
            }

            var seenSlug: [String: LocaleID] = [:]
            for locale in entry.localized.keys.sorted(by: { $0.identifier < $1.identifier }) {
                let pattern = entry.localized[locale]!

                // V2
                if locale == localization.default {
                    out.append("routePaths entry '\(canon)' declares the default locale '\(locale.identifier)' — the canonical pattern already is that locale's path")
                }
                // V3 (unsupported). The table matches locales EXACTLY, while
                // `Localization.validated` falls back region→language, so a
                // near miss degrades silently: name both spellings.
                if !localization.supported.contains(locale) {
                    var message = "routePaths entry '\(canon)': locale '\(locale.identifier)' is not in supported \(localization.supported.map(\.identifier))"
                    if let near = localization.supported.first(where: { $0.language == locale.language }) {
                        message += " — the table matches locales exactly, so write it as '\(near.identifier)'"
                    }
                    out.append(message)
                }
                // V4
                if let other = seenSlug.updateValue(locale, forKey: pattern.raw) {
                    out.append("routePaths entry '\(canon)': '\(pattern.raw)' is declared for both '\(other.identifier)' and '\(locale.identifier)'")
                }
                // V12
                if !pattern.raw.allSatisfy(Self.isSlugCharacter) {
                    out.append("routePaths entry '\(canon)': localized slug '\(pattern.raw)' must be ASCII [A-Za-z0-9-._~/:*] — transliterate it")
                }
                // V11
                let cn = Self.paramNames(entry.canonical), ln = Self.paramNames(pattern)
                if cn != ln {
                    out.append("routePaths entry '\(canon)': localized slug '\(pattern.raw)' has parameters \(ln.sorted()), expected \(cn.sorted())")
                }
                if Self.hasCatchAll(entry.canonical) != Self.hasCatchAll(pattern) {
                    out.append("routePaths entry '\(canon)': localized slug '\(pattern.raw)' disagrees about the catch-all '*'")
                }
                // V16 — a slug starting with ':' or '*' matches a bare locale
                // prefix by segment count alone, so internalize step 1 claims
                // '/de' — the very URL externalize("/", de) produces — and
                // answers with this entry's canonical. Step 1 cannot be
                // narrowed the way step 2 was (LocalePath.swift:28) without
                // breaking root-level canonical slugs, so the pattern is
                // rejected here instead.
                switch pattern.segments.first {
                case .none, .some(.literal): break
                case .some(.param), .some(.catchAll):
                    out.append("routePaths entry '\(canon)': localized slug '\(pattern.raw)' must start with a literal segment — one starting with ':' or '*' also matches the locale prefix '/\(locale.identifier)'")
                }
                // V10 — a backstop, not the broad check the spec bills it as:
                // given V11, it cannot fail for any table `RoutePattern` can
                // represent (see `roundTripFailure`). Kept because it asserts
                // the §3.3 invariant directly, so a future change to
                // `RoutePattern._matchRaw` breaks a test rather than URLs.
                if let failure = Self.roundTripFailure(entry: entry, locale: locale) {
                    out.append("routePaths entry '\(canon)': \(failure)")
                }
            }
        }

        // V6 + the table half of V7 — pairwise overlap over EVERY pattern the
        // table declares, canonical and localized alike. All three degenerate
        // shapes are one relation: a slug equal to its own canonical, a slug
        // spelled as another entry's canonical, and two slugs that can match
        // one path. Resolution is first-match-wins in declaration order, so
        // each of them makes some page unreachable without any diagnostic.
        // Tables are small (tens of entries); O(n²) is free.
        //
        // `owner` is the declaring entry's index, carried by slugs too: the
        // opt-out is about two ENTRIES, and a slug pair of those two entries is
        // resolved in the same declaration order as their canonicals.
        var declared: [(label: String, pattern: RoutePattern, owner: Int, isCanonical: Bool)] = []
        for (index, entry) in entries.enumerated() {
            declared.append(("canonical '\(entry.canonical.raw)'", entry.canonical, index, true))
            for locale in entry.localized.keys.sorted(by: { $0.identifier < $1.identifier }) {
                let pattern = entry.localized[locale]!
                declared.append(("the '\(locale.identifier)' slug '\(pattern.raw)' of '\(entry.canonical.raw)'", pattern, index, false))
            }
        }
        for i in declared.indices {
            for j in declared.indices where j > i {
                // The opt-out. `owner` is non-decreasing (patterns are appended
                // entry by entry), so `<` is exactly "different entries, this
                // one later". Two conditions the author cannot express by
                // ordering are excluded:
                //
                //  - equal owners, two patterns of ONE entry: a slug colliding
                //    with its own canonical is a misdeclaration, not a choice;
                //  - a CROSS-KIND pair, one entry's slug against another's
                //    canonical. `internalize` runs the slug lookup before the
                //    declared-canonical check (LocalePath.swift:27-28), so the
                //    slug wins for either entry order and that canonical is
                //    unreachable at its own URL — nothing to opt into.
                if declared[i].owner < declared[j].owner,
                   declared[i].isCanonical == declared[j].isCanonical,
                   entries[declared[j].owner].overlapsEarlierEntry { continue }
                if Self.overlap(declared[i].pattern, declared[j].pattern) {
                    out.append("routePaths: \(declared[i].label) and \(declared[j].label) overlap — one path would match both and resolution is declaration-order, so a reordering would silently rewrite URLs")
                }
            }
        }
        return out
    }

    /// Checks that need something `_validate(localization:)` cannot see: the
    /// app's real route set (spec §4: V8 and V7's route half) and the SSG's
    /// config (V13, V14). Same REPORTING contract — the caller decides what a
    /// problem costs.
    ///
    /// `reservedNames` is passed in rather than known here: it describes the
    /// dist layout, which lives in SwiftWUIStatic. No `localization:` parameter
    /// — none of these four checks reads one, and V1 already rejects a table
    /// under a strategy that ignores it.
    public func _validate(against collected: [_CollectedRoute], siteURL: String?,
                          reservedNames: Set<String>) -> [String] {
        guard !isEmpty else { return [] }
        var out: [String] = []
        // Normalized on both sides: `RoutePattern.raw` is stored verbatim, so
        // `Route("/about/")` and `LocalizedRoute("/about", …)` are the same
        // route and must not read as an orphan.
        let declared = Set(collected.map { RouteURL._normalize($0.pattern.raw) })

        for entry in entries {
            let canon = entry.canonical.raw
            // V8 — an entry no Route claims is inert. The build succeeds, the
            // page count is right, and the feature silently did nothing; the
            // canonical pattern is the identity key tying the two together, so
            // a typo in it has no other symptom.
            //
            // MATCHES, not equals (spec §4): a table entry is free to name one
            // concrete path of a parametric route, and `Router { Route("/:page") }`
            // with an entry for '/about' is a working configuration. Equality is
            // only the fast path — it is what a literal route set hits, and it
            // is the case where the typo-catching is sharp.
            let canonPath = RouteURL._normalize(canon)
            if !declared.contains(canonPath),
               !collected.contains(where: { $0.pattern._matchRaw(canonPath) != nil }) {
                out.append("routePaths entry '\(canon)' matches no Route — declared patterns are \(declared.sorted())")
            }
            for locale in entry.localized.keys.sorted(by: { $0.identifier < $1.identifier }) {
                let slug = entry.localized[locale]!.raw
                // V7's route half — `internalize` rewrites the slug to its
                // canonical before routing ever sees it, so the shadowed Route
                // is unreachable at its own URL.
                //
                // ponytail: equality, not `overlap`. A slug that merely overlaps
                // a broader pattern is the same hazard, but so is every slug
                // against an app-wide `Route("/*")` — `_validate(enumerated:)`
                // catches the concrete instances instead.
                if declared.contains(RouteURL._normalize(slug)) {
                    out.append("routePaths entry '\(canon)' declares slug '\(slug)' for '\(locale.identifier)', which is also a real Route pattern")
                }
                // V14 — a slug's first segment IS a top-level directory in
                // dist/, and the toolchain's own reserved-name check only ever
                // scans public/. Lowercased: dist lands on a case-insensitive
                // filesystem on both macOS and Windows, where '/Vendor'
                // overwrites 'vendor' exactly as '/vendor' would.
                let head = String(RouteURL._normalize(slug).dropFirst().prefix { $0 != "/" })
                if reservedNames.contains(head.lowercased()) {
                    out.append("routePaths entry '\(canon)': slug '\(slug)' for '\(locale.identifier)' starts with '\(head)', a reserved dist name (\(reservedNames.sorted().joined(separator: ", ")))")
                }
            }
        }
        // V13 — with a table this is not a mild omission. `/about` and `/o-nas`
        // share no substring, so hreflang is the ONLY thing pairing them up;
        // without an origin neither it nor the canonical is emitted, and the
        // whole language cluster is lost. The message names where the value
        // goes, spelled out: a scaffolded project's StaticSiteConfig sets no
        // siteURL, so the author who trips this has nothing to search for.
        if siteURL?.isEmpty != false {
            out.append("""
                routePaths requires a siteURL — without it neither the canonical nor any hreflang \
                alternate is emitted, and a localized slug shares no substring with its canonical \
                for a crawler to pair them up. Every scaffolded project has the line to edit in its \
                Sources/Entry.swift: let siteURL: String? = "https://example.com"
                """)
        }
        return out
    }

    /// The paths the SSG is about to render, checked against the table.
    ///
    /// Separate from the pass above because `.paths` providers are part of the
    /// input: their output is only known after enumeration has run them.
    ///
    /// The SSG enumerates INTERNAL, locale-free paths. One that a slug pattern
    /// claims is therefore already wrong, and it fails in a way nothing else
    /// reports: `internalize` maps it back to its canonical AND to the locale
    /// that owns the slug, whichever locale the build asked for. The page
    /// either self-redirects forever or lands in the alternates map under a
    /// locale that already has an entry — `alternates[canonical][locale]` is
    /// last-write-wins, so a two-locale cluster silently collapses to one and
    /// hreflang disappears from both pages.
    public func _validate(enumerated paths: [String]) -> [String] {
        guard !isEmpty else { return [] }
        return paths.compactMap { path in
            guard let hit = _canonicalPath(for: path) else { return nil }
            return "SSG page path '\(path)' is a '\(hit.locale.identifier)' localized slug — enumerate its canonical path '\(hit.path)' instead and let the build produce every locale's URL"
        }
    }

    static func isSlugCharacter(_ c: Character) -> Bool {
        guard c.isASCII else { return false }
        return c.isLetter || c.isNumber || "-._~/:*".contains(c)
    }

    static func paramNames(_ p: RoutePattern) -> Set<String> {
        var names: Set<String> = []
        for seg in p.segments { if case .param(let n) = seg { names.insert(n) } }
        return names
    }

    static func hasCatchAll(_ p: RoutePattern) -> Bool {
        p.segments.contains { if case .catchAll = $0 { return true } else { return false } }
    }

    /// Two patterns overlap when some path could match both.
    ///
    /// A catch-all is always the last segment, so it sits at index `count - 1`
    /// and matches every path with AT LEAST that many segments — the count is
    /// free from there on, but the literals BEFORE it still have to agree.
    /// Comparing only `min(count) - 1` positions instead would call `/about`
    /// and `/docs/*` an overlap and refuse a perfectly legal table.
    static func overlap(_ a: RoutePattern, _ b: RoutePattern) -> Bool {
        let ka = hasCatchAll(a) ? a.segments.count - 1 : nil
        let kb = hasCatchAll(b) ? b.segments.count - 1 : nil
        switch (ka, kb) {
        case (nil, nil):        guard a.segments.count == b.segments.count else { return false }
        case (.some(let k), nil): guard b.segments.count >= k else { return false }
        case (nil, .some(let k)): guard a.segments.count >= k else { return false }
        case (.some, .some):    break
        }
        let fixed = min(ka ?? a.segments.count, kb ?? b.segments.count)
        return (0..<fixed).allSatisfy { compatible(a.segments[$0], b.segments[$0]) }
    }

    private static func compatible(_ x: RoutePattern.Segment, _ y: RoutePattern.Segment) -> Bool {
        switch (x, y) {
        case (.literal(let l), .literal(let r)): return l == r
        default: return true                      // a param or catch-all matches any literal
        }
    }

    /// Spec §3.3: internalize(externalize(p)) == p, asserted directly on one
    /// sample rather than argued from the other checks.
    ///
    /// Honest about its reach: V11 already forces the two patterns to name the
    /// same params, and `_matchRaw` recovers substituted segments verbatim, so
    /// once V11 passes this cannot fail for any table `RoutePattern` can
    /// represent. The sample values are opaque tokens to every code path they
    /// touch — nothing here percent-decodes — so they buy no extra coverage
    /// either. What it does buy is a direct assertion of the invariant: change
    /// `_matchRaw` to decode, or `substituteRaw` to re-encode, and this fails
    /// before any URL does. The set is FIXED for that reason — a validation
    /// that fails on a different build than it passed on is worse than none.
    static func roundTripFailure(entry: Entry, locale: LocaleID) -> String? {
        let poison = ["a%2Fb", "%25", "x y", "a+b"]
        var params: [String: String] = [:]
        var i = 0
        for seg in entry.canonical.segments {
            switch seg {
            case .param(let name): params[name] = poison[i % poison.count]; i += 1
            case .catchAll:        params["*"] = poison[i % poison.count]; i += 1
            case .literal:         break
            }
        }
        let canonicalPath = substituteRaw(params, into: entry.canonical)
        let slug = substituteRaw(params, into: entry.localized[locale]!)
        guard let back = entry.localized[locale]!._matchRaw(slug) else {
            return "'\(slug)' does not match its own pattern '\(entry.localized[locale]!.raw)'"
        }
        let rebuilt = substituteRaw(back, into: entry.canonical)
        guard rebuilt == canonicalPath else {
            return "round-trip lost information: '\(canonicalPath)' → '\(slug)' → '\(rebuilt)'"
        }
        return nil
    }
}
