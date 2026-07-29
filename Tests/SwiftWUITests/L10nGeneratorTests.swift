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

    /// `swiftwui init` templates set `path: "Sources"`, so a scaffolded project
    /// has no `Sources/<Target>/` level at all and its catalogs sit at
    /// `Sources/Locales`. The generated file has to land at
    /// `Sources/Generated/L10n.swift` — inside that target, or the templates
    /// would not compile it.
    @Test func flatLayoutGeneratesIntoTheSourcesTarget() throws {
        let root = NSTemporaryDirectory() + "swiftwui-flat-" + UUID().uuidString
        let locales = root + "/Sources/Locales"
        try FileManager.default.createDirectory(atPath: locales, withIntermediateDirectories: true)
        try #"{"a":"A"}"#.write(toFile: locales + "/en.json", atomically: true, encoding: .utf8)

        #expect(L10nGenerator.localesOwner(projectDir: root, target: nil) == root + "/Sources")
        let outcome = try #require(try L10nGenerator.generate(projectDir: root))
        #expect(outcome.path == root + "/Sources/Generated/L10n.swift")
        #expect(try String(contentsOfFile: outcome.path, encoding: .utf8).contains("public enum L10n"))
    }

    /// The nested layout still wins, so no existing project changes owner.
    @Test func nestedLayoutBeatsAStrayFlatOne() throws {
        let root = try makeProject(["en": #"{"a":"A"}"#])
        try FileManager.default.createDirectory(atPath: root + "/Sources/Locales",
                                                withIntermediateDirectories: true)
        #expect(L10nGenerator.localesOwner(projectDir: root, target: nil) == root + "/Sources/App")
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
        // `--target` reaches the same path join, so it is the same trust boundary.
        // The escape target has to EXIST for the assertion to mean anything:
        // without the guard, `root/Sources/../elsewhere/Locales` resolves and
        // `addLocale` writes a catalog outside the project.
        try FileManager.default.createDirectory(atPath: root + "/elsewhere/Locales",
                                                withIntermediateDirectories: true)
        #expect(L10nGenerator.localesOwner(projectDir: root, target: "../elsewhere") == nil)
        #expect(throws: L10nGeneratorError.self) {
            _ = try L10nGenerator.addLocale(projectDir: root, tag: "fr", target: "../elsewhere")
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

    /// The dev loop, both halves of it. `Generated/L10n.swift` is itself a watched
    /// `.swift` file, so the generator's own write must not start a second cycle
    /// (a visible double reload) — and the absorb that achieves that must not
    /// extend over `rebuild`, which in production is a wasm build lasting tens of
    /// seconds during which the user keeps saving files.
    ///
    /// Every write here creates a new file rather than touching an existing one,
    /// so the assertions do not depend on filesystem mtime granularity.
    @Test func devLoopAbsorbsItsOwnWriteButNotConcurrentEdits() throws {
        let root = try makeProject(["en": #"{"a":"A"}"#])
        let watcher = FileWatcher(root: root)
        var rebuilds = 0
        let quiet = { rebuilds += 1 }
        // A rebuild takes a while, and the user saves a source file while it runs.
        let interrupted = {
            rebuilds += 1
            try? "// edit".write(toFile: root + "/Sources/App/edit\(rebuilds).swift",
                                 atomically: true, encoding: .utf8)
        }

        try #"{"a":"A"}"#.write(toFile: root + "/Sources/App/Locales/de.json",
                                atomically: true, encoding: .utf8)
        watcher.pollAndRebuild(projectDir: root, debounce: {}, rebuild: quiet)
        #expect(rebuilds == 1)
        #expect(FileManager.default.fileExists(atPath: root + "/Sources/App/Generated/L10n.swift"))
        watcher.pollAndRebuild(projectDir: root, debounce: {}, rebuild: quiet)
        #expect(rebuilds == 1)          // the generated file's write was absorbed

        try #"{"a":"A"}"#.write(toFile: root + "/Sources/App/Locales/fr.json",
                                atomically: true, encoding: .utf8)
        watcher.pollAndRebuild(projectDir: root, debounce: {}, rebuild: interrupted)
        #expect(rebuilds == 2)
        watcher.pollAndRebuild(projectDir: root, debounce: {}, rebuild: quiet)
        #expect(rebuilds == 3)          // the edit made during the rebuild still builds
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

    /// The flat layout every `swiftwui init` scaffold uses. The enumerator yields
    /// paths relative to `Sources`, so this catalog arrives as `Locales/en.json`
    /// with no leading slash — a `contains("/Locales/")` filter misses it and
    /// `swiftwui dev` then ignores every translation edit.
    @Test func watcherSeesFlatLayoutCatalogEdits() throws {
        let root = NSTemporaryDirectory() + "swiftwui-flatwatch-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/Sources/Locales",
                                                withIntermediateDirectories: true)
        try "// app".write(toFile: root + "/Sources/Entry.swift", atomically: true, encoding: .utf8)
        try #"{"a":"A"}"#.write(toFile: root + "/Sources/Locales/en.json",
                                atomically: true, encoding: .utf8)
        let watcher = FileWatcher(root: root)
        #expect(!watcher.changed())
        try #"{"a":"B"}"#.write(toFile: root + "/Sources/Locales/de.json",
                                atomically: true, encoding: .utf8)
        #expect(watcher.changed())
    }
}
