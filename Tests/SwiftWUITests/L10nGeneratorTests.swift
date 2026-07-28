import Foundation
import Testing
import SwiftWUI
@testable import SwiftWUIToolchain

@Suite struct L10nGeneratorTests {
    private func makeProject(_ catalogs: [String: String]) throws -> String {
        let root = NSTemporaryDirectory() + "swiftwui-l10n-" + UUID().uuidString
        let locales = root + "/Sources/App/Locales"
        try FileManager.default.createDirectory(atPath: locales, withIntermediateDirectories: true)
        for (tag, json) in catalogs {
            try json.write(toFile: locales + "/\(tag).json", atomically: true, encoding: .utf8)
        }
        return root
    }

    @Test func generatesCommittedFile() throws {
        let root = try makeProject(["en": #"{"a":"A"}"#, "ru": #"{"a":"А"}"#])
        let outcome = try #require(try L10nGenerator.generate(projectDir: root))
        #expect(outcome.path == root + "/Sources/App/Generated/L10n.swift")
        #expect(outcome.changed)
        let text = try String(contentsOfFile: outcome.path, encoding: .utf8)
        #expect(text.contains("public enum L10n"))
    }

    @Test func secondRunIsANoOp() throws {
        let root = try makeProject(["en": #"{"a":"A"}"#])
        _ = try L10nGenerator.generate(projectDir: root)
        let again = try #require(try L10nGenerator.generate(projectDir: root))
        #expect(!again.changed)
        #expect(try L10nGenerator.generate(projectDir: root, check: true) != nil)   // does not throw
    }

    @Test func checkFailsOnStaleFile() throws {
        let root = try makeProject(["en": #"{"a":"A"}"#])
        _ = try L10nGenerator.generate(projectDir: root)
        try #"{"a":"CHANGED"}"#.write(toFile: root + "/Sources/App/Locales/en.json",
                                      atomically: true, encoding: .utf8)
        #expect(throws: L10nGeneratorError.self) {
            _ = try L10nGenerator.generate(projectDir: root, check: true)
        }
    }

    /// `--check` is a CI gate: it must never write, or a green CI run would be
    /// green because it fixed the tree behind the reviewer's back.
    @Test func checkNeverWrites() throws {
        let root = try makeProject(["en": #"{"a":"A"}"#])
        #expect(throws: L10nGeneratorError.self) {
            _ = try L10nGenerator.generate(projectDir: root, check: true)
        }
        #expect(!FileManager.default.fileExists(atPath: root + "/Sources/App/Generated/L10n.swift"))
    }

    @Test func inertWithoutLocalesDirectory() throws {
        let root = NSTemporaryDirectory() + "swiftwui-plain-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: root + "/Sources/App",
                                                withIntermediateDirectories: true)
        #expect(try L10nGenerator.generate(projectDir: root) == nil)
    }

    @Test func addLocaleSeedsTodoValues() throws {
        let root = try makeProject(["en": #"{"a.b":"Hello","n":"{count, plural, one {# x} other {# xs}}"}"#])
        let path = try L10nGenerator.addLocale(projectDir: root, tag: "de", target: nil)
        let text = try String(contentsOfFile: path, encoding: .utf8)
        #expect(text.contains("\"a.b\""))
        #expect(text.contains("TODO"))
        #expect(throws: L10nGeneratorError.self) {
            _ = try L10nGenerator.addLocale(projectDir: root, tag: "de", target: nil)
        }
        #expect(throws: L10nGeneratorError.self) {
            _ = try L10nGenerator.addLocale(projectDir: root, tag: "../evil", target: nil)
        }
    }

    /// The seeded catalog keeps every placeholder, so it passes `validate`'s
    /// signature check the moment it is written — before anyone translates it.
    @Test func seededCatalogGenerates() throws {
        let root = try makeProject(["en": #"{"a.b":"Hi, {name}!","n":"{count, plural, one {# x} other {# xs}}"}"#])
        _ = try L10nGenerator.addLocale(projectDir: root, tag: "de", target: nil)
        let outcome = try #require(try L10nGenerator.generate(projectDir: root))
        let text = try String(contentsOfFile: outcome.path, encoding: .utf8)
        #expect(text.contains(#"case "de": return _l_de()"#))
    }

    @Test func tagValidationMatchesLocaleID() {
        // Drift guard: the emitter writes `LocaleID("<tag>")!`, so a tag this
        // accepts but LocaleID rejects is a force-unwrap trap at app boot.
        // The test target can see both modules; the toolchain cannot.
        for tag in ["en", "ru", "en-US", "zh-Hans-CN", "es-419", "fil",
                    "foo-bar", "e", "toolong", "en-", "-en", "en_US", "EN",
                    "en-usa", "en-US-extra", "", "../etc"] {
            #expect(L10nGenerator.isValidTag(tag) == (LocaleID(tag) != nil),
                    "disagreement on '\(tag)'")
        }
    }

    @Test func missingKeyIsFatalUnlessAllowed() throws {
        let root = try makeProject(["en": #"{"a":"A","b":"B"}"#, "ru": #"{"a":"А"}"#])
        #expect(throws: L10nError.self) { _ = try L10nGenerator.generate(projectDir: root) }
        let outcome = try #require(try L10nGenerator.generate(projectDir: root, allowMissing: true))
        #expect(outcome.warnings.contains { $0.contains("'b'") })
    }

    /// `Locales/` is discovered by walking `Sources/`, so a catalog edit has to
    /// wake `swiftwui dev` exactly like a `.swift` edit does.
    @Test func watcherSeesCatalogEdits() throws {
        let root = try makeProject(["en": #"{"a":"A"}"#])
        let watcher = FileWatcher(root: root)
        #expect(!watcher.changed())
        // A new file, not a touch: this asserts the scan reaches Locales/*.json
        // at all, without depending on filesystem mtime granularity.
        try #"{"a":"B"}"#.write(toFile: root + "/Sources/App/Locales/de.json",
                                atomically: true, encoding: .utf8)
        #expect(watcher.changed())
    }
}
