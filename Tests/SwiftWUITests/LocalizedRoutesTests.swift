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
