import Testing
@testable import SwiftWUI

@Suite struct LocaleIDTests {
    @Test func parsesAndNormalizes() {
        #expect(LocaleID("ru")?.identifier == "ru")
        #expect(LocaleID("EN")?.identifier == "en")
        #expect(LocaleID("en_us")?.identifier == "en-US")
        #expect(LocaleID("zh-hans-cn")?.identifier == "zh-Hans-CN")
        #expect(LocaleID("es-419")?.identifier == "es-419")
    }

    @Test func exposesSubtags() {
        let l = LocaleID("zh-Hans-CN")!
        #expect(l.language == "zh")
        #expect(l.script == "Hans")
        #expect(l.region == "CN")
        #expect(LocaleID("ru")?.region == nil)
    }

    @Test func rejectsEverythingElse() {
        for bad in ["", "e", "toolong", "en-", "-en", "ru/RU", "../etc", "en-USA",
                    "en US", "%2e%2e", "en-US-extra", "ру", "en--US", "_en_"] {
            #expect(LocaleID(bad) == nil, "expected nil for \(bad)")
        }
    }

    @Test func rtlTable() {
        #expect(LocaleID("ar")!.isRTL)
        #expect(LocaleID("he-IL")!.isRTL)
        #expect(!LocaleID("en")!.isRTL)
        #expect(LocaleID("ar")!.direction == .rightToLeft)
        #expect(LocaleID("en")!.direction == .leftToRight)
    }
}
