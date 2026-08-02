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

    @Test func emptyTableIsTodaysBehaviour() {
        let r = LocalePath.internalize("/ru/about", supported: supported)
        #expect(r.path == "/about")
        #expect(r.locale == LocaleID("ru")!)
        let u = LocalePath.internalize("/xx/about", supported: supported)
        #expect(u.path == "/xx/about")
        #expect(u.locale == nil)
    }
}
