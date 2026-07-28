import Testing
@testable import SwiftWUIToolchain

@Suite struct L10nCatalogTests {
    @Test func parsesLiteralsAndPlaceholders() throws {
        let t = try L10nCatalog.parse(json: #"{"a.b":"Hi, {name}!"}"#, locale: "en")["a.b"]!
        #expect(t.parts.count == 3)
        if case .literal(let s) = t.parts[0] { #expect(s == "Hi, ") } else { Issue.record("literal") }
        if case .placeholder(let n) = t.parts[1] { #expect(n == "name") } else { Issue.record("placeholder") }
    }

    @Test func parsesPlural() throws {
        let json = #"{"n":"{count, plural, one {# item} other {# items}}"}"#
        let t = try L10nCatalog.parse(json: json, locale: "en")["n"]!
        guard case .plural(let variable, let branches) = t.parts[0] else { Issue.record("plural"); return }
        #expect(variable == "count")
        #expect(branches.map(\.category) == ["one", "other"])
        if case .number = branches[0].parts[0] {} else { Issue.record("# should parse to .number") }
    }

    @Test func signatureIsOrderIndependent() throws {
        let a = try L10nCatalog.parse(json: #"{"k":"{x} {y}"}"#, locale: "en")["k"]!
        let b = try L10nCatalog.parse(json: #"{"k":"{y}—{x}"}"#, locale: "ru")["k"]!
        #expect(L10nCatalog.signature(a) == L10nCatalog.signature(b))
    }

    @Test func rejectsBadInput() {
        #expect(throws: L10nError.self) { try L10nCatalog.parse(json: #"{"bad key":"x"}"#, locale: "en") }
        #expect(throws: L10nError.self) { try L10nCatalog.parse(json: #"{"k":{"nested":"x"}}"#, locale: "en") }
        #expect(throws: L10nError.self) { try L10nCatalog.parse(json: #"{"k":"{1bad}"}"#, locale: "en") }
        #expect(throws: L10nError.self) { try L10nCatalog.parse(json: #"{"k":"{n, plural, one {a}}"}"#, locale: "en") }
        #expect(throws: L10nError.self) { try L10nCatalog.parse(json: #"{"k":"{n, plural, xx {a} other {b}}"}"#, locale: "en") }
        #expect(throws: L10nError.self) { try L10nCatalog.parse(json: #"{"k":"{a, plural, other {{b, plural, other {x}}}}"}"#, locale: "en") }
        #expect(throws: L10nError.self) { try L10nCatalog.parse(json: #"{"k":"unclosed {name"}"#, locale: "en") }
    }

    @Test func validateCatchesMissingAndMismatched() throws {
        let en = try L10nCatalog.parse(json: #"{"a":"A {x}","b":"B"}"#, locale: "en")
        let ru = try L10nCatalog.parse(json: #"{"a":"А {y}"}"#, locale: "ru")
        #expect(throws: L10nError.self) {
            try L10nCatalog.validate(catalogs: ["en": en, "ru": ru], allowMissing: false)
        }
        let en2 = try L10nCatalog.parse(json: #"{"a":"A","b":"B"}"#, locale: "en")
        let ru2 = try L10nCatalog.parse(json: #"{"a":"А"}"#, locale: "ru")
        let warnings = try L10nCatalog.validate(catalogs: ["en": en2, "ru": ru2], allowMissing: true)
        #expect(warnings.contains { $0.contains("b") && $0.contains("ru") })
    }
}
