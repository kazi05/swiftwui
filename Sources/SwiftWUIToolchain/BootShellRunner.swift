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
    /// an uncached invocation pays one compile of the whole graph into `.build`
    /// on top of the wasm one. Hence the two skips below — a project that never
    /// declared a `bootUI` never pays it at all, and one that has stopped
    /// editing pays it once.
    public static func run(projectDir: String, runner: ProcessRunner) throws -> BootShell? {
        let probe = fingerprint(projectDir: projectDir)
        // No source spells the token, so no override of `App.bootUI` (default
        // `.none`) or `Page.bootUI` (default `.inherit`) can exist and the
        // answer is `.none` without asking. Sound, not a heuristic: a false
        // positive costs one compile, a false negative cannot happen. The
        // cache does not rescue this case on its own — its key is the sources,
        // so every build that edits one would recompile to re-learn `.none`.
        if let probe, !probe.declaresBootUI { return nil }
        let key = probe?.key
        if let key, let hit = cached(projectDir: projectDir, key: key) { return hit.shell }
        let product = try PackageInfo.executableProduct(in: projectDir, runner: runner)
        // A multi-second step with no output is how this compile stayed
        // invisible in the first place (`streamOutput: false` swallows it).
        print("resolving boot UI (host build of \(product))…")
        let result = try runner.run("swift", ["run", product, "boot-shell"],
                                    cwd: projectDir, streamOutput: false)
        guard result.exitCode == 0, let shell = parse(stdout: result.stdout) else {
            // Deliberately not "has no 'boot-shell' subcommand": a project that
            // fails to COMPILE exits non-zero too, and `streamOutput: false`
            // swallowed its diagnostics. Name the remedy, not a cause this
            // cannot tell apart — the build step surfaces the real error next.
            print("""
            note: could not run '\(product) boot-shell' — if this project predates boot UI, \
            regenerate Sources/Entry.swift; building without boot UI
            """)
            return nil
        }
        // Empty html === the app declared `.none`, and that answer is cached
        // like any other: it is the one that skips the compile for every project
        // that never opted in. A FAILED run is never cached — a project that
        // does not compile must ask again next build, not inherit "no boot UI".
        let answer = shell.html.isEmpty ? nil : shell
        if let key { store(Cache(key: key, shell: answer), projectDir: projectDir) }
        return answer
    }

    // MARK: - Cache

    private struct Cache: Codable {
        var key: String
        var shell: BootShell?      // nil === the app declared no boot UI
    }

    /// Lives next to the wasm scratch dir, which is already gitignored and
    /// already this build's throwaway state.
    private static func path(projectDir: String) -> String {
        projectDir + "/.build-wasm/boot-shell.json"
    }

    private static func cached(projectDir: String, key: String) -> Cache? {
        guard let data = FileManager.default.contents(atPath: path(projectDir: projectDir)),
              let cache = try? JSONDecoder().decode(Cache.self, from: data),
              cache.key == key
        else { return nil }   // unreadable, corrupt or stale → run the subcommand
        return cache
    }

    private static func store(_ cache: Cache, projectDir: String) {
        let file = path(projectDir: projectDir)
        try? FileManager.default.createDirectory(atPath: (file as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: URL(fileURLWithPath: file), options: .atomic)
    }

    private struct Fingerprint {
        var key: String
        /// Some file under `Sources/` spells `bootUI`.
        var declaresBootUI: Bool
    }

    /// One pass over the project: the cache key, and whether asking is worth it
    /// at all. Everything that can change the rendered shell goes into the key:
    ///
    /// - `Sources/` content — the `bootUI` declaration and everything it reads
    ///   (the generated L10n and the locale catalogs live there too).
    /// - `Package.swift` + `Package.resolved` — which SwiftWUI the app renders
    ///   against, for a project that depends on a released version.
    /// - the CLI binary's own size and mtime — a cheap over-invalidation that
    ///   catches an upgraded or rebuilt `swiftwui`. It is NOT a framework
    ///   version input in general: a Homebrew-installed CLI neither relinks
    ///   when the user edits a path-dependency checkout nor on a toolchain
    ///   upgrade. Known residual, deliberately not chased — a path dependency
    ///   edited in a different checkout touches none of the three inputs and
    ///   can go stale until any project source is, which is bounded to
    ///   framework authors.
    ///
    /// The boot shim is deliberately NOT an input: it is copied into dist at
    /// build time and has no bearing on what the app renders.
    ///
    /// nil = we could not read enough to be sure, so never claim a hit and
    /// never claim the skip.
    private static func fingerprint(projectDir: String) -> Fingerprint? {
        let fm = FileManager.default
        var input = ""
        var declares = false
        guard let en = fm.enumerator(atPath: projectDir + "/Sources") else { return nil }
        var files: [String] = []
        while let rel = en.nextObject() as? String { files.append(rel) }
        for rel in files.sorted() {
            guard let data = fm.contents(atPath: projectDir + "/Sources/" + rel) else { continue }
            input += rel + "|" + SHA256.hex(SHA256.digest([UInt8](data))) + "\n"
            if !declares, String(decoding: data, as: UTF8.self).contains("bootUI") { declares = true }
        }
        for name in ["Package.swift", "Package.resolved"] {
            guard let data = fm.contents(atPath: projectDir + "/" + name) else { continue }
            input += name + "|" + SHA256.hex(SHA256.digest([UInt8](data))) + "\n"
        }
        guard let cli = Bundle.main.executablePath,
              let attrs = try? fm.attributesOfItem(atPath: cli),
              let size = attrs[.size] as? Int,
              let mtime = attrs[.modificationDate] as? Date else { return nil }
        input += "cli|\(size)|\(mtime.timeIntervalSince1970)\n"
        return Fingerprint(key: SHA256.hex(SHA256.digest(Array(input.utf8))), declaresBootUI: declares)
    }
}
