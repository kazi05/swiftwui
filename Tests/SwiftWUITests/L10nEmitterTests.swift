import Testing
@testable import SwiftWUIToolchain

@Suite struct L10nEmitterTests {
    private func emit(_ catalogs: [String: String]) throws -> String {
        var parsed: [String: [String: L10nTemplate]] = [:]
        for (locale, json) in catalogs { parsed[locale] = try L10nCatalog.parse(json: json, locale: locale) }
        return try L10nEmitter.file(catalogs: parsed)
    }

    @Test func emitsLocaleConstantsAndCatalogConformance() throws {
        let out = try emit(["en": #"{"a":"A"}"#, "ru": #"{"a":"А"}"#])
        // The file compiles inside the app's target, so it imports the framework itself.
        #expect(out.contains("\nimport SwiftWUI\n"))
        #expect(out.contains(#"public static let en = LocaleID("en")!"#))
        #expect(out.contains(#"public static let ru = LocaleID("ru")!"#))
        #expect(out.contains("extension L10n: LocalizationCatalog"))
        #expect(out.contains("supportedLocales: [LocaleID] = [.en, .ru]"))
    }

    @Test func emitsPlaceholderParameters() throws {
        let out = try emit(["en": #"{"welcome.title":"Hi, {name}!"}"#])
        #expect(out.contains("public static func welcomeTitle(name: String) -> LocalizedText"))
        #expect(out.contains(#"return "Hi, " + name + "!""#))
    }

    @Test func emitsPluralSwitch() throws {
        let out = try emit(["ru": #"{"n":"{count, plural, one {# товар} few {# товара} many {# товаров} other {# товара}}"}"#])
        #expect(out.contains("public static func n(count: Int) -> LocalizedText"))
        #expect(out.contains("switch _SWUIPlural.ru(count)"))
        #expect(out.contains("case .few:"))
        #expect(out.contains("static func ru(_ value: Int) -> _PluralCategory"))
    }

    @Test func escapesHostileValues() throws {
        // The catalog value is `x";import Foundation//` — a closing quote plus a
        // statement. Emitted raw it would end the literal and inject code.
        let out = try emit(["en": #"{"k":"x\";import Foundation//"}"#])
        #expect(out.contains(#""x";import Foundation//"#) == false)
        #expect(out.contains(#"return "x\";import Foundation//""#))
        #expect(!out.contains("\nimport Foundation//"))
    }

    @Test func escapesEveryControlCharacter() {
        let hostile = "a\\b\"c\nd\re\tf\u{0}g\u{2028}h\u{2029}i\u{1B}j\u{7F}k\u{85}l"
        let literal = SwiftLiteralEscaping.literal(hostile)
        #expect(literal == #""a\\b\"c\nd\re\tf\0g\u{2028}h\u{2029}i\u{001B}j\u{007F}k\u{0085}l""#)
        // Nothing that could terminate the line or hide from review survives.
        #expect(!literal.contains("\n"))
        #expect(!literal.contains("\r"))
        #expect(literal.unicodeScalars.allSatisfy { $0.value >= 0x20 && !(0x7F...0x9F).contains($0.value) })
    }

    @Test func rejectsSymbolCollisions() {
        #expect(throws: L10nError.self) {
            var parsed: [String: [String: L10nTemplate]] = [:]
            parsed["en"] = try L10nCatalog.parse(json: #"{"a.b":"1","a-b":"2"}"#, locale: "en")
            _ = try L10nEmitter.file(catalogs: parsed)
        }
    }

    @Test func handlesWhatTheParserDefers() throws {
        // The parser (Task 3) validates keys and placeholder names as ASCII shapes
        // only; these four cases reach the emitter and must not produce broken Swift.
        let keywords = try emit(["en": #"{"k":"{class} {func}"}"#])
        #expect(keywords.contains("public static func k(`class`: String, `func`: String)"))
        #expect(keywords.contains("`class` + \" \" + `func`"))

        #expect(throws: L10nError.self) { _ = try emit(["en": #"{"k":"{_}"}"#]) }
        #expect(throws: L10nError.self) { _ = try emit(["en": #"{"123":"x"}"#]) }
        #expect(throws: L10nError.self) { _ = try emit(["en": #"{"-":"x"}"#]) }
        #expect(throws: L10nError.self) {
            _ = try emit(["en": #"{"k":"{n, plural, other {a} other {b}}"}"#])
        }
    }

    @Test func rejectsPluralInALanguageWithoutRules() {
        // Emitting `_SWUIPlural.vi(...)` for a language the generator has no CLDR
        // rule for would produce Swift that does not compile.
        #expect(throws: L10nError.self) {
            _ = try emit(["vi": #"{"n":"{count, plural, other {# mục}}"}"#])
        }
    }

    @Test func outputIsDeterministic() throws {
        let a = try emit(["ru": #"{"b":"Б","a":"А"}"#, "en": #"{"a":"A","b":"B"}"#])
        let b = try emit(["en": #"{"b":"B","a":"A"}"#, "ru": #"{"a":"А","b":"Б"}"#])
        #expect(a == b)
    }

    @Test func pluralRulesCoverRussian() {
        #expect(PluralRules.supported.contains("ru"))
        #expect(PluralRules.swiftBody(language: "xx") == nil)
    }
}
