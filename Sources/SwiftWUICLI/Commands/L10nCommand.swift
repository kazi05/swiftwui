import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct L10n: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "l10n",
        abstract: "Generate type-safe localization from Locales/*.json.",
        subcommands: [Generate.self, Add.self],
        defaultSubcommand: Generate.self)

    struct Generate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Regenerate Sources/<Target>/Generated/L10n.swift.")

        @Option(name: .long, help: "Target owning Locales/ (default: auto-detect).") var target: String?
        @Flag(name: .long, help: "Downgrade missing keys from error to warning.") var allowMissing = false
        @Flag(name: .long, help: "Fail if the committed file is out of date (CI).") var check = false

        func run() throws {
            let cwd = FileManager.default.currentDirectoryPath
            guard let outcome = try L10nGenerator.generate(projectDir: cwd, target: target,
                                                           allowMissing: allowMissing, check: check) else {
                print("no Locales/ directory — nothing to generate")
                return
            }
            for warning in outcome.warnings { print("warning: \(warning)") }
            if check { print("\(outcome.path) is up to date") }
            else { print(outcome.changed ? "wrote \(outcome.path)" : "\(outcome.path) already up to date") }
        }
    }

    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create Locales/<tag>.json seeded with every key, values marked TODO.")

        @Argument(help: "Locale tag, e.g. 'de' or 'pt-BR'.") var tag: String
        @Option(name: .long, help: "Target owning Locales/ (default: auto-detect).") var target: String?

        func run() throws {
            let cwd = FileManager.default.currentDirectoryPath
            let path = try L10nGenerator.addLocale(projectDir: cwd, tag: tag, target: target)
            print("wrote \(path) — translate the TODO values, then run `swiftwui l10n generate`")
        }
    }
}
