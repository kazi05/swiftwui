import Foundation
import SwiftWUI

public enum BootShellRunner {
    private struct Payload: Decodable {
        let html: String
        let css: String
        let delayMS: Int
        let tag: Int
        enum CodingKeys: String, CodingKey {
            case html, css, delayMS
            case tag = "swiftwui-boot-shell"
        }
    }

    /// The payload shares stdout with author `print`s and `\.logger`, so take
    /// the last non-empty line and require the tag. Never splice stdout that
    /// did not parse.
    public static func parse(stdout: String) -> BootShell? {
        guard let line = stdout.split(whereSeparator: \.isNewline)
                .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              let payload = try? JSONDecoder().decode(Payload.self, from: Data(line.utf8)),
              payload.tag == 1
        else { return nil }
        return BootShell(html: payload.html, css: payload.css, delayMS: payload.delayMS)
    }

    /// Runs the project's native binary. Returns nil when the project has no
    /// boot UI (empty html) or has no such subcommand — both are ordinary,
    /// non-fatal outcomes and neither may splice anything.
    ///
    /// This is a HOST build: nothing else in the CLI compiles for the host, so
    /// the first invocation pays one cold compile of the whole graph into
    /// `.build`. Callers skip it entirely when the project declares no boot UI.
    public static func run(projectDir: String, runner: ProcessRunner) throws -> BootShell? {
        let product = try PackageInfo.executableProduct(in: projectDir, runner: runner)
        let result = try runner.run("swift", ["run", product, "boot-shell"],
                                    cwd: projectDir, streamOutput: false)
        guard result.exitCode == 0, let shell = parse(stdout: result.stdout) else {
            print("""
            note: \(product) has no 'boot-shell' subcommand — regenerate Sources/Entry.swift; \
            building without boot UI
            """)
            return nil
        }
        return shell.html.isEmpty ? nil : shell
    }
}
