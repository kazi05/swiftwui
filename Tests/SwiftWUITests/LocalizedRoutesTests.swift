import Testing
@testable import SwiftWUI

@Suite struct LocalizedRoutesTests {
    @Test func emptyByDefault() {
        #expect(LocalizedRoutes.none.isEmpty)
        #expect(LocalizedRoutes().isEmpty)
    }

    @Test func builderKeepsDeclarationOrder() {
        let table = LocalizedRoutes {
            LocalizedRoute("/blog/:slug", ["ru": "/novosti/:slug"])
            LocalizedRoute("/about", ["ru": "/o-nas"])
        }
        #expect(table.entries.count == 2)
        #expect(table.entries[0].canonical.raw == "/blog/:slug")
        #expect(table.entries[1].canonical.raw == "/about")
    }

    @Test func invalidLocaleTagIsCollectedNotTrapped() {
        let entry = LocalizedRoute("/about", ["not a tag": "/x", "ru": "/o-nas"])
        #expect(entry.invalidTags == ["not a tag"])
        #expect(entry.localized[LocaleID("ru")!]?.raw == "/o-nas")
    }

    // The whole point of the raw matcher: RoutePattern.match would return "a/b".
    @Test func matchRawNeverDecodes() {
        let p = RoutePattern("/delivery/:from/:to")
        let params = LocalizedRoutes.matchRaw("/delivery/a%2Fb/x", p)
        #expect(params?["from"] == "a%2Fb")
        #expect(params?["to"] == "x")
        #expect(RoutePattern("/delivery/:from/:to").match("/delivery/a%2Fb/x")?["from"] == "a/b")
    }

    @Test func matchRawRejectsWrongArity() {
        #expect(LocalizedRoutes.matchRaw("/delivery/a", RoutePattern("/delivery/:from/:to")) == nil)
        #expect(LocalizedRoutes.matchRaw("/delivery/a/b/c", RoutePattern("/delivery/:from/:to")) == nil)
    }

    @Test func substituteRawRebuildsByName() {
        let out = LocalizedRoutes.substituteRaw(["from": "a%2Fb", "to": "x"],
                                                into: RoutePattern("/dostavka/:from/:to"))
        #expect(out == "/dostavka/a%2Fb/x")
    }

    @Test func catchAllTailSplicesVerbatim() {
        let params = LocalizedRoutes.matchRaw("/docs/a/b%2Fc", RoutePattern("/docs/*"))
        #expect(params?["*"] == "a/b%2Fc")
        #expect(LocalizedRoutes.substituteRaw(params!, into: RoutePattern("/dokumenty/*"))
                == "/dokumenty/a/b%2Fc")
    }

    @Test func emptyCatchAllTailDropsTheSegment() {
        let params = LocalizedRoutes.matchRaw("/docs", RoutePattern("/docs/*"))
        #expect(params?["*"] == "")
        #expect(LocalizedRoutes.substituteRaw(params!, into: RoutePattern("/dokumenty/*"))
                == "/dokumenty")
    }

    @Test func rootSubstitutionStaysRoot() {
        #expect(LocalizedRoutes.substituteRaw([:], into: RoutePattern("/")) == "/")
    }
}

@Suite struct ExternalizeWithTableTests {
    private let en = LocaleID("en")!
    private let ru = LocaleID("ru")!
    private let de = LocaleID("de")!
    private let table = LocalizedRoutes {
        LocalizedRoute("/delivery/:from/:to", ["ru": "/dostavka/:from/:to"])
        LocalizedRoute("/about", ["ru": "/o-nas"])
    }

    @Test func translatedRouteGetsSlugAndNoPrefix() {
        #expect(LocalePath.externalize("/delivery/moscow/paris", locale: ru, default: en,
                                       routes: table) == "/dostavka/moscow/paris")
    }

    @Test func untranslatedRouteFallsBackToPrefix() {
        #expect(LocalePath.externalize("/contact", locale: ru, default: en,
                                       routes: table) == "/ru/contact")
    }

    @Test func defaultLocaleIsUnaffected() {
        #expect(LocalePath.externalize("/about", locale: en, default: en,
                                       routes: table) == "/about")
    }

    @Test func emptyTableIsCharacterForCharacterTodaysBehaviour() {
        #expect(LocalePath.externalize("/about", locale: ru, default: en) == "/ru/about")
        #expect(LocalePath.externalize("/", locale: ru, default: en) == "/ru")
        #expect(LocalePath.externalize("/about", locale: ru, default: en,
                                       routes: .none) == "/ru/about")
    }

    // Link hands its whole destination in, query and all (Link.swift:30).
    @Test func querySurvivesTranslation() {
        #expect(LocalePath.externalize("/about?tab=2", locale: ru, default: en,
                                       routes: table) == "/o-nas?tab=2")
    }

    @Test func fragmentSurvivesTranslation() {
        #expect(LocalePath.externalize("/about#top", locale: ru, default: en,
                                       routes: table) == "/o-nas#top")
    }

    @Test func queryAlsoSurvivesTheFallbackPath() {
        #expect(LocalePath.externalize("/contact?x=1", locale: ru, default: en,
                                       routes: table) == "/ru/contact?x=1")
    }

    /// Both halves of the lookup guard, one fixture. Entry 1 matches "/about"
    /// but is silent about `ru`: the scan must CONTINUE (stopping at the first
    /// pattern match would fall through to "/ru/about"). Entry 1 also declares
    /// `de`, as does entry 2 — the earlier one wins, like `Router`.
    ///
    /// The table is INTENTIONALLY V5-invalid (two entries, one canonical) — a
    /// legal table can never reach the keep-scanning branch, because V5 and V6
    /// together let at most one entry match a path. This pins the degraded
    /// path, so `_validate` must stay a reporting pass and never trap.
    @Test func silentEntryKeepsScanningAndTheFirstMatchWins() {
        let mixed = LocalizedRoutes {
            LocalizedRoute("/about", ["de": "/ueber-uns"])
            LocalizedRoute("/about", ["ru": "/o-nas", "de": "/about-de"])
        }
        #expect(LocalePath.externalize("/about", locale: ru, default: en, routes: mixed) == "/o-nas")
        #expect(LocalePath.externalize("/about", locale: de, default: en, routes: mixed) == "/ueber-uns")
    }
}

@Suite struct InternalizeWithTableTests {
    private let supported = [LocaleID("en")!, LocaleID("de")!, LocaleID("ru")!]
    private let table = LocalizedRoutes {
        LocalizedRoute("/delivery/:from/:to", ["ru": "/dostavka/:from/:to"])
        LocalizedRoute("/about", ["ru": "/o-nas"])
    }

    @Test func slugYieldsCanonicalPathAndItsLocale() {
        let r = LocalePath.internalize("/dostavka/moscow/paris", supported: supported, routes: table)
        #expect(r.path == "/delivery/moscow/paris")
        #expect(r.locale == LocaleID("ru")!)
    }

    @Test func prefixStillWorksForUntranslatedRoutes() {
        let r = LocalePath.internalize("/ru/contact", supported: supported, routes: table)
        #expect(r.path == "/contact")
        #expect(r.locale == LocaleID("ru")!)
    }

    @Test func roundTripIsExactForEncodedSegments() {
        let external = LocalePath.externalize("/delivery/a%2Fb/x", locale: LocaleID("ru")!,
                                              default: LocaleID("en")!, routes: table)
        let back = LocalePath.internalize(external, supported: supported, routes: table)
        #expect(external == "/dostavka/a%2Fb/x")
        #expect(back.path == "/delivery/a%2Fb/x")
        #expect(back.locale == LocaleID("ru")!)
    }

    /// `externalize` consults the table BEFORE the `locale != defaultLocale`
    /// check, so an entry that declares the default locale really does yield a
    /// slug. `internalize` must recognise it, or the round-trip breaks for
    /// exactly the configuration that opts into it.
    @Test func slugDeclaredForTheDefaultLocaleRoundTrips() {
        let t = LocalizedRoutes { LocalizedRoute("/about", ["en": "/x"]) }
        let external = LocalePath.externalize("/about", locale: LocaleID("en")!,
                                              default: LocaleID("en")!, routes: t)
        let back = LocalePath.internalize(external, supported: supported, routes: t)
        #expect(external == "/x")
        #expect(back.path == "/about")
        #expect(back.locale == LocaleID("en")!)
    }

    // Step 2: a declared canonical path must never be eaten by the prefix split.
    // Without it, "/de/history" in a de-enabled app internalizes to "/history"
    // and the SSG writes a meta-refresh stub pointing at itself.
    @Test func declaredCanonicalBeatsThePrefixSplit() {
        let t = LocalizedRoutes { LocalizedRoute("/de/history", ["ru": "/istoriya"]) }
        let r = LocalePath.internalize("/de/history", supported: supported, routes: t)
        #expect(r.path == "/de/history")
        #expect(r.locale == nil)
    }

    /// Step 2 may only claim canonicals whose FIRST SEGMENT IS A LITERAL.
    /// `/:slug` matches `/de` by segment count alone — and `/de` is exactly what
    /// `externalize("/", de)` just produced, so claiming it there strands the
    /// German home page with no locale. Same for `/:a/:b` and `/ru/contact`.
    @Test func parametricCanonicalDoesNotEatThePrefix() {
        let de = LocaleID("de")!
        let t = LocalizedRoutes {
            LocalizedRoute("/:category/:product", ["ru": "/tovar/:category/:product"])
            LocalizedRoute("/:slug", ["ru": "/stranitsa/:slug"])
        }
        let external = LocalePath.externalize("/", locale: de, default: LocaleID("en")!, routes: t)
        let home = LocalePath.internalize(external, supported: supported, routes: t)
        #expect(external == "/de")
        #expect(home.path == "/")
        #expect(home.locale == de)

        let two = LocalePath.internalize("/ru/contact", supported: supported, routes: t)
        #expect(two.path == "/contact")
        #expect(two.locale == LocaleID("ru")!)
    }

    /// Steps 1–2 reattach the suffix, exactly as `externalize` splits and
    /// reattaches it. Unreachable from today's callers (all three hand over a
    /// path from `RouteURL.split`), but Task 11's `StaticSite.resolve` takes a
    /// browser-visible URL, query and all.
    @Test func suffixSurvivesWhicheverStepAnswers() {
        #expect(LocalePath.internalize("/o-nas?x=1", supported: supported,
                                       routes: table).path == "/about?x=1")
        #expect(LocalePath.internalize("/ru/contact?x=1", supported: supported,
                                       routes: table).path == "/contact?x=1")
        let t = LocalizedRoutes { LocalizedRoute("/de/history", ["ru": "/istoriya"]) }
        #expect(LocalePath.internalize("/de/history#top", supported: supported,
                                       routes: t).path == "/de/history#top")
    }

    @Test func emptyTableIsTodaysBehaviour() {
        let r = LocalePath.internalize("/ru/about", supported: supported)
        #expect(r.path == "/about")
        #expect(r.locale == LocaleID("ru")!)
        let u = LocalePath.internalize("/xx/about", supported: supported)
        #expect(u.path == "/xx/about")
        #expect(u.locale == nil)
    }
}

@Suite struct LocalizedRoutesValidationTests {
    private let en = LocaleID("en")!, ru = LocaleID("ru")!, de = LocaleID("de")!

    private func l10n(_ strategy: LocaleStrategy = .pathPrefix(),
                      _ table: LocalizedRoutes) -> Localization {
        Localization(supported: [en, ru, de], default: en, strategy: strategy, routePaths: table)
    }

    private func problems(_ strategy: LocaleStrategy = .pathPrefix(),
                          _ table: LocalizedRoutes) -> [String] {
        table._validate(localization: l10n(strategy, table))
    }

    @Test func validTableHasNoProblems() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/delivery/:from/:to", ["ru": "/dostavka/:from/:to"])
            LocalizedRoute("/about", ["ru": "/o-nas", "de": "/ueber-uns"])
        }).isEmpty)
    }

    /// A catch-all only claims paths that reach it: `/docs/*` and `/about`
    /// share nothing. Counting `min(count) - 1` positions instead would call
    /// every short pattern an overlap and refuse this table.
    @Test func aCatchAllDoesNotOverlapEveryShorterPattern() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["ru": "/o-nas"])
            LocalizedRoute("/docs/*", ["ru": "/dokumenty/*"])
        }).isEmpty)
    }

    @Test func aRootCatchAllStillOverlapsEverything() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["ru": "/o-nas"])
            LocalizedRoute("/*", ["ru": "/vse/*"])
        }).contains { $0.contains("overlap") })
    }

    @Test func emptyTableIsAlwaysValidEvenUnderNegotiated() {
        #expect(problems(.negotiated, .none).isEmpty)
    }

    @Test func v1RejectsNonPathPrefixStrategies() {
        let t = LocalizedRoutes { LocalizedRoute("/about", ["ru": "/o-nas"]) }
        #expect(problems(.negotiated, t).contains { $0.contains(".pathPrefix") })
        #expect(problems(.client, t).contains { $0.contains(".pathPrefix") })
    }

    @Test func v2RejectsTheDefaultLocale() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["en": "/about-us"])
        }).contains { $0.contains("default locale") })
    }

    @Test func v3RejectsUnknownAndUnparseableTags() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["fr": "/a-propos"])
        }).contains { $0.contains("fr") })
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["not a tag": "/x"])
        }).contains { $0.contains("not a tag") })
    }

    /// Why V3 is not cosmetic: `internalize` step 1 hands back whatever locale
    /// the table names, WITHOUT filtering it through `supported` — every other
    /// exit does. An unsupported tag in the table therefore reaches `<html
    /// lang>` and the persisted locale.
    @Test func anUnsupportedTableLocaleReachesInternalizeUnfiltered() {
        let t = LocalizedRoutes { LocalizedRoute("/about", ["fr": "/a-propos"]) }
        let r = LocalePath.internalize("/a-propos", supported: [en, ru, de], routes: t)
        #expect(r.path == "/about")
        #expect(r.locale == LocaleID("fr")!)
    }

    /// The table matches locales EXACTLY; `Localization.validated` falls back
    /// region→language. An app on `ru-RU` with a table written `"ru"` gets a
    /// table that never fires, so the diagnostic must name both spellings.
    @Test func v3RejectsALocaleThatOnlyMatchesByFallback() {
        let ruRU = LocaleID("ru-RU")!
        let t = LocalizedRoutes { LocalizedRoute("/about", ["ru": "/o-nas"]) }
        let out = t._validate(localization: Localization(supported: [en, ruRU], default: en,
                                                         routePaths: t))
        #expect(out.contains { $0.contains("'ru'") && $0.contains("'ru-RU'") })
        // and the reason it matters: the entry is dead for the only ru locale there is.
        #expect(LocalePath.externalize("/about", locale: ruRU, default: en, routes: t) == "/ru-RU/about")
    }

    @Test func v4RejectsTwoLocalesSharingOneSlug() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/contact", ["ru": "/kontakt", "de": "/kontakt"])
        }).contains { $0.contains("declared for both") && $0.contains("/kontakt") })
    }

    @Test func v5RejectsDuplicateCanonicalPatterns() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["ru": "/o-nas"])
            LocalizedRoute("/about", ["de": "/ueber-uns"])
        }).contains { $0.contains("twice") && $0.contains("/about") })
    }

    @Test func v6RejectsOverlappingCanonicalPatterns() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/blog/:slug", ["ru": "/novosti/:slug"])
            LocalizedRoute("/blog/archive", ["ru": "/arkhiv"])
        }).contains { $0.contains("overlap") })
    }

    /// The normal table V6 was too strict about: `Router` resolves this pair by
    /// declaration order and so does the table, so the author is allowed to say
    /// so — on the LATER entry, the shadowed one.
    @Test func v6OptOutAllowsAShadowedLaterCanonical() {
        let t = LocalizedRoutes {
            LocalizedRoute("/blog/archive", ["ru": "/arkhiv"])
            LocalizedRoute("/blog/:slug", ["ru": "/novosti/:slug"], overlapsEarlierEntry: true)
        }
        #expect(problems(.pathPrefix(), t).isEmpty)
        // and the resolution it buys — first match in declaration order, so
        // "/arkhiv" and not "/novosti/archive". Reordering the two lines above
        // rewrites this URL, silently: that is the trade the flag makes.
        #expect(LocalePath.externalize("/blog/archive", locale: ru, default: en, routes: t) == "/arkhiv")
        #expect(LocalePath.externalize("/blog/hello", locale: ru, default: en, routes: t) == "/novosti/hello")
    }

    /// Without the flag the same table is refused — the check itself is intact.
    @Test func v6StillRejectsThatTableWithoutTheOptOut() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/blog/archive", ["ru": "/arkhiv"])
            LocalizedRoute("/blog/:slug", ["ru": "/novosti/:slug"])
        }).contains { $0.contains("overlap") })
    }

    /// The flag is about being shadowed, not about shadowing: on the EARLIER
    /// entry it says nothing about the pair, so the report stands.
    @Test func v6OptOutOnTheEarlierEntryDoesNotSuppressTheReport() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/blog/archive", ["ru": "/arkhiv"], overlapsEarlierEntry: true)
            LocalizedRoute("/blog/:slug", ["ru": "/novosti/:slug"])
        }).contains { $0.contains("overlap") })
    }

    /// The flag never reaches a pair involving a slug (V7). Here the canonicals
    /// do not overlap at all — the collision is entry 1's slug against entry 0's
    /// canonical, which makes `/history` unreachable no matter how the two lines
    /// are ordered. Not something declaration order can express, so still reported.
    @Test func v6OptOutDoesNotSuppressV7() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/history", ["ru": "/istoriya"])
            LocalizedRoute("/team", ["ru": "/history"], overlapsEarlierEntry: true)
        }).contains { $0.contains("/history") && $0.contains("overlap") })
    }

    /// V5 is a duplicate, not an ordering choice: the second entry is dead
    /// whatever the author intended, so the flag must not reach it.
    @Test func v6OptOutDoesNotSuppressV5() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["ru": "/o-nas"])
            LocalizedRoute("/about", ["de": "/ueber-uns"], overlapsEarlierEntry: true)
        }).contains { $0.contains("twice") && $0.contains("/about") })
    }

    @Test func v11RejectsParamNameMismatch() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/delivery/:from/:to", ["ru": "/dostavka/:from"])
        }).contains { $0.contains("has parameters") && $0.contains("\"to\"") })
    }

    /// The specific mismatch V11 exists to make unreachable: a slug naming a
    /// param the canonical never captures. Paired with the test below, which
    /// pins what it would emit if it ever shipped.
    @Test func v11RejectsASlugNamingAParamTheCanonicalDoesNotHave() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/delivery/:from", ["ru": "/dostavka/:via/:from"])
        }).contains { $0.contains("has parameters") && $0.contains("\"via\"") })
    }

    /// Documented, not folklore: with a param missing, `substituteRaw` splices
    /// in an empty segment and `normalizePath` does not repair it — only a
    /// TRAILING slash is stripped. This "/" would reach hrefs, redirect
    /// targets and `<link rel=canonical>`. V11 above is the only guard.
    @Test func substituteRawWithAMissingParamProducesADoubleSlash() {
        #expect(LocalizedRoutes.substituteRaw(["from": "a"],
                                              into: RoutePattern("/dostavka/:via/:from")) == "/dostavka//a")
    }

    @Test func v11RejectsCatchAllMismatch() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/docs/*", ["ru": "/dokumenty/:page"])
        }).contains { $0.contains("catch-all") })
    }

    @Test func v12RejectsNonASCIIAndUnsafeCharacters() {
        let cyrillic = problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["ru": "/о-нас"])
        })
        #expect(cyrillic.contains { $0.contains("ASCII") })
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/about", ["ru": "/o-nas?x=1"])
        }).contains { $0.contains("ASCII") })
    }

    @Test func v10RoundTripFailureIsReported() {
        // A localized pattern that repeats a param cannot round-trip: the
        // canonical rebuild has no way to know which copy was authoritative.
        // V11 also fires on this fixture, so the assertion names V10's own
        // message — `!out.isEmpty` would stay green with V10 deleted.
        let out = problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/x/:a/:b", ["ru": "/y/:a/:a"])
        })
        #expect(out.contains { $0.contains("round-trip") })
    }

    /// V15: `LocaleID` lowercases the language and treats "_" like "-", so
    /// these three tags are ONE key and only the last survives. Both offending
    /// spellings must appear, or the author cannot find the line.
    @Test func v15RejectsRawTagsThatNormalizeToTheSameLocale() {
        let t = LocalizedRoutes { LocalizedRoute("/about", ["ru": "/a", "RU": "/b"]) }
        #expect(t.entries[0].localized.count == 1)          // the collapse itself
        let out = t._validate(localization: l10n(.pathPrefix(), t))
        #expect(out.contains { $0.contains("\"ru\"") && $0.contains("\"RU\"") })
    }

    @Test func v15AlsoCatchesTheRegionAndSeparatorSpellings() {
        let t = LocalizedRoutes { LocalizedRoute("/about", ["pt_br": "/a", "pt-BR": "/b"]) }
        #expect(t._validate(localization: l10n(.pathPrefix(), t))
                 .contains { $0.contains("\"pt-BR\"") && $0.contains("\"pt_br\"") })
    }

    /// Degenerate table (a): the slug IS its own canonical. `externalize`
    /// returns the canonical unchanged while `internalize` claims that URL for
    /// the locale — the default-locale page becomes the localized one.
    @Test func v7RejectsASlugEqualToItsOwnCanonical() {
        let t = LocalizedRoutes { LocalizedRoute("/about", ["ru": "/about"]) }
        #expect(t._validate(localization: l10n(.pathPrefix(), t)).contains { $0.contains("overlap") })
        // the behaviour it prevents:
        #expect(LocalePath.internalize("/about", supported: [en, ru, de], routes: t).locale == ru)
    }

    /// Degenerate table (b): one entry's slug is spelled as another entry's
    /// canonical. Step 1 beats step 2, so that second entry is unreachable.
    @Test func v7RejectsASlugSpelledAsAnotherEntrysCanonical() {
        let t = LocalizedRoutes {
            LocalizedRoute("/history", ["ru": "/istoriya"])
            LocalizedRoute("/team", ["ru": "/history"])
        }
        #expect(t._validate(localization: l10n(.pathPrefix(), t))
                 .contains { $0.contains("/history") && $0.contains("overlap") })
        #expect(LocalePath.internalize("/history", supported: [en, ru, de], routes: t).path == "/team")
    }

    /// Two entries whose SLUGS can match one path: same first-match-wins hazard
    /// as V6, one step earlier.
    @Test func v7RejectsTwoSlugsThatMatchOnePath() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/blog/:slug", ["ru": "/n/:slug"])
            LocalizedRoute("/news/:slug", ["ru": "/n/:slug"])
        }).contains { $0.contains("overlap") })
    }

    /// A slug whose first segment is a `:param` matches "/de" by segment count
    /// alone — the exact URL `externalize("/", de)` produces — so step 1 would
    /// answer every prefixed home page with this entry's canonical.
    @Test func v16RejectsASlugStartingWithAParam() {
        let t = LocalizedRoutes { LocalizedRoute("/products/:slug", ["ru": "/:slug"]) }
        #expect(t._validate(localization: l10n(.pathPrefix(), t))
                 .contains { $0.contains("literal segment") })
        // the behaviour it prevents:
        let hijacked = LocalePath.internalize("/de", supported: [en, ru, de], routes: t)
        #expect(hijacked.path == "/products/de")
        #expect(hijacked.locale == ru)
    }

    @Test func v16RejectsASlugStartingWithACatchAll() {
        #expect(problems(.pathPrefix(), LocalizedRoutes {
            LocalizedRoute("/docs/*", ["ru": "/*"])
        }).contains { $0.contains("literal segment") })
    }
}
