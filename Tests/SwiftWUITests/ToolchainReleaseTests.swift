import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainReleaseTests {
    private func scratchDist() throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-release-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    /// ≥ 1 KB of compressible content; below-1 KB content for the skip case.
    private func write(_ path: String, bytes: Int) throws {
        try String(repeating: "a", count: bytes).write(toFile: path, atomically: true, encoding: .utf8)
    }

    // 1. real gzip integration: eligible ≥ 1 KB → .gz; < 1 KB skipped; .png skipped.
    @Test func compressGzipsEligibleFilesOnly() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        let fm = FileManager.default
        try write(dist + "/big.css", bytes: 2048)
        try write(dist + "/small.css", bytes: 100)
        try write(dist + "/image.png", bytes: 2048)   // ≥ minSize but ext ∉ set

        let runner = FoundationProcessRunner()
        let s = try ReleaseArtifacts.compress(distDir: dist, runner: runner)

        #expect(fm.fileExists(atPath: dist + "/big.css.gz"))
        #expect(fm.fileExists(atPath: dist + "/big.css"))          // -k keeps original
        #expect(!fm.fileExists(atPath: dist + "/small.css.gz"))
        #expect(!fm.fileExists(atPath: dist + "/image.png.gz"))
        #expect(s.gzipped == 1)
        // brotli is optional on the host — only assert when actually installed.
        if ReleaseArtifacts.toolAvailable("brotli", runner: runner) {
            #expect(fm.fileExists(atPath: dist + "/big.css.br"))
            #expect(s.brotlied == 1)
        }
    }

    // 2. orphan .gz removed; user foo.tar.gz never touched.
    @Test func compressRemovesOwnedOrphanKeepsUserTarball() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        let fm = FileManager.default
        try write(dist + "/gone.css.gz", bytes: 50)    // owned, base missing → orphan
        try write(dist + "/foo.tar.gz", bytes: 50)     // tar ∉ set → user asset, kept

        _ = try ReleaseArtifacts.compress(distDir: dist, runner: MockRunner(results: [:]))

        #expect(!fm.fileExists(atPath: dist + "/gone.css.gz"))
        #expect(fm.fileExists(atPath: dist + "/foo.tar.gz"))
    }

    // 3. exact gzip/brotli argument construction.
    @Test func compressBuildsExactCompressorArgs() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try write(dist + "/app.js", bytes: 2048)

        var calls: [[String]] = []
        let runner = MockRunner(results: [:], recorded: { calls.append($0) })
        _ = try ReleaseArtifacts.compress(distDir: dist, runner: runner)

        let full = dist + "/app.js"
        #expect(calls.contains(["gzip", "-kfn9", full]))
        #expect(calls.contains(["brotli", "-f", "-q", "11", full]))
    }

    // 4. brotli unavailable → no .br, brotliAvailable == false, build not failed.
    @Test func compressWithoutBrotliShipsGzipOnly() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try write(dist + "/app.js", bytes: 2048)

        // gzip present (default exit 0), brotli absent (exit 1).
        let runner = MockRunner(results: ["which brotli": .init(exitCode: 1, stdout: "", stderr: "")])
        let s = try ReleaseArtifacts.compress(distDir: dist, runner: runner)

        #expect(s.brotliAvailable == false)
        #expect(s.brotlied == 0)
        #expect(s.gzipped == 1)
        #expect(!FileManager.default.fileExists(atPath: dist + "/app.js.br"))
    }

    // 5. clean drops owned .gz/.br, keeps foo.tar.gz.
    @Test func cleanRemovesOwnedArtifactsKeepsUserTarball() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        let fm = FileManager.default
        try write(dist + "/a.css.gz", bytes: 50)
        try write(dist + "/a.js.br", bytes: 50)
        try write(dist + "/foo.tar.gz", bytes: 50)

        try ReleaseArtifacts.clean(distDir: dist)

        #expect(!fm.fileExists(atPath: dist + "/a.css.gz"))
        #expect(!fm.fileExists(atPath: dist + "/a.js.br"))
        #expect(fm.fileExists(atPath: dist + "/foo.tar.gz"))
    }

    // 6. writeNginxConf: content present; second call overwrites.
    @Test func writeNginxConfIsPresentAndOverwrites() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try ReleaseArtifacts.writeNginxConf(distDir: dist)
        let conf = try String(contentsOfFile: dist + "/nginx.conf", encoding: .utf8)
        #expect(conf.contains("gzip_static on"))
        #expect(conf.contains("try_files"))
        #expect(conf.contains("application/wasm"))
        // idempotent overwrite (no append/duplication)
        try ReleaseArtifacts.writeNginxConf(distDir: dist)
        let again = try String(contentsOfFile: dist + "/nginx.conf", encoding: .utf8)
        #expect(again == conf)
    }

    // 7. nginx.conf reserved; public/nginx.conf collides.
    @Test func nginxConfIsReservedPublicName() throws {
        #expect(DistLayout.reservedNames.contains("nginx.conf"))
        #expect(DistLayout.reservedNames.contains("swiftwui-site.json"))   // SSG writes it into dist
        let root = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/public", withIntermediateDirectories: true)
        try write(root + "/public/nginx.conf", bytes: 10)
        #expect(throws: ToolchainError.self) {
            try DistLayout.copyPublic(projectDir: root, outDir: root + "/dist")
        }
    }

    // 8. PWA manifest excludes owned .gz/.br + nginx.conf; keeps user foo.tar.gz.
    @Test func pwaManifestExcludesReleaseArtifacts() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        let fm = FileManager.default
        try fm.createDirectory(atPath: dist + "/app", withIntermediateDirectories: true)
        try "importScripts('/sw-assets.js');".write(toFile: dist + "/sw.js", atomically: true, encoding: .utf8)
        try "shell".write(toFile: dist + "/index.html", atomically: true, encoding: .utf8)
        try "wasm".write(toFile: dist + "/app/x.wasm", atomically: true, encoding: .utf8)
        try "gz".write(toFile: dist + "/app/x.wasm.gz", atomically: true, encoding: .utf8)   // owned → excluded
        try "br".write(toFile: dist + "/app/x.wasm.br", atomically: true, encoding: .utf8)   // owned → excluded
        try ReleaseArtifacts.writeNginxConf(distDir: dist)                                    // nginx.conf → excluded
        try "tar".write(toFile: dist + "/foo.tar.gz", atomically: true, encoding: .utf8)      // user asset → included

        #expect(try PWAAssets.generateManifest(distDir: dist) == true)
        let js = try String(contentsOfFile: dist + "/sw-assets.js", encoding: .utf8)
        #expect(!js.contains("x.wasm.gz"))
        #expect(!js.contains("x.wasm.br"))
        #expect(!js.contains("nginx.conf"))
        #expect(js.contains("\"/foo.tar.gz\""))
        #expect(js.contains("\"/app/x.wasm\""))   // base file still precached
    }

    // 9. hasCompressedArtifacts true/false.
    @Test func hasCompressedArtifactsReflectsOwnedSiblings() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try write(dist + "/foo.tar.gz", bytes: 50)   // user asset only
        #expect(ReleaseArtifacts.hasCompressedArtifacts(distDir: dist) == false)
        try write(dist + "/index.html.gz", bytes: 50)  // framework-owned
        #expect(ReleaseArtifacts.hasCompressedArtifacts(distDir: dist) == true)
    }

    // 10. The cache header must sit in the FIRST wasm regex.
    //
    // nginx serves the first matching regex location and a regex beats any
    // prefix location, so a second wasm block — or a `location /app/` prefix
    // block — is dead code and the caching feature silently does nothing. A
    // plain text golden cannot catch that: the header would be *present in the
    // file* and never reached, and an acceptance check still sees a correct
    // 304, because the unreached block leaves the server-level `no-cache` in
    // force. Only the relative order proves it.
    @Test func theCacheHeaderLivesInTheFirstWasmRegex() throws {
        let conf = ReleaseArtifacts.nginxConfText(wasmVersioned: true)
        let appBlock = try #require(conf.range(of: "location ~ ^/app/.*\\.wasm$"))
        let genericBlock = try #require(conf.range(of: "location ~ \\.wasm$"))
        #expect(appBlock.lowerBound < genericBlock.lowerBound)
        #expect(conf.contains("add_header Cache-Control $swui_wasm_cc;"))
        #expect(!conf.contains("location /app/"))
        #expect(conf.components(separatedBy: "^/app/.*\\.wasm$").count - 1 == 1)
        // `map` is only legal in the http block — above `server {`, like the
        // negotiation maps, or nginx refuses to load the file.
        let map = try #require(conf.range(of: "map $arg_v $swui_wasm_cc"))
        #expect(map.upperBound < conf.range(of: "server {")!.lowerBound)
        #expect(conf.contains("public, max-age=31536000, immutable"))
    }

    // 11. Unversioned dist: today's config, byte for byte.
    //
    // $swui_wasm_cc is defined by the map, so emitting the location half without
    // it makes nginx refuse to start on an unknown variable — the two are one
    // decision, and the whole block reverts rather than losing one line.
    @Test func unversionedBuildsGetTheOldWasmBlockAndNoImmutable() {
        let conf = ReleaseArtifacts.nginxConfText(wasmVersioned: false)
        #expect(!conf.contains("immutable"))
        #expect(!conf.contains("$swui_wasm_cc"))
        #expect(!conf.contains("^/app/"))
        #expect(conf.contains("""
                location ~ \\.wasm$ {
                    types {}
                    default_type application/wasm;
                }
            """))
    }

    // 12. A `.negotiated` site keeps both maps, and the wasm block deliberately
    // drops the inherited Vary: a location-level add_header REPLACES every
    // inherited one, and /app/ is the same bytes for every locale.
    @Test func negotiationAndWasmCachingCoexist() {
        let site = LocaleNegotiation.Site(strategy: "negotiated", locales: ["en", "ru"], defaultLocale: "en")
        let conf = ReleaseArtifacts.nginxConfText(site: site, wasmVersioned: true)
        #expect(conf.contains("map $http_cookie"))
        #expect(conf.contains("map $arg_v $swui_wasm_cc"))
        #expect(conf.range(of: "map $arg_v")!.upperBound < conf.range(of: "server {")!.lowerBound)
        // The server-level Vary is emitted below the wasm block, so bound the
        // search to the block's own braces rather than to end-of-file.
        let open = conf.range(of: "location ~ ^/app/.*\\.wasm$")!.upperBound
        let close = conf.range(of: "}", range: open..<conf.endIndex)!.lowerBound
        #expect(conf.range(of: "Vary", range: open..<close) == nil)
        #expect(conf.contains("add_header Vary"))   // still present at server level
        #expect(!conf.contains("__SWIFTWUI"))
    }

    // 13. Freshness: a prerender left over from an older binary vetoes the year.
    //
    // `swiftwui build` rewrites only the root index.html. A stale sub-page keeps
    // asking for the old ?v= forever, so pinning that URL is unrecoverable — no
    // later deploy changes the document that requests it.
    @Test func aStalePrerenderVetoesImmutableCaching() throws {
        let dist = try scratchDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        let fm = FileManager.default
        try fm.createDirectory(atPath: dist + "/app", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: dist + "/about", withIntermediateDirectories: true)
        try "wasm bytes".write(toFile: dist + "/app/App.wasm", atomically: true, encoding: .utf8)
        let token = WasmDigest.version(WasmDigest.stamp(path: dist + "/app/App.wasm")!)

        // Nothing versioned at all → no claim to make.
        try "<script data-wasm=\"/app/App.wasm\"></script>".write(
            toFile: dist + "/index.html", atomically: true, encoding: .utf8)
        #expect(ReleaseArtifacts.auditWasmVersions(distDir: dist) == (false, []))

        // Root current, sub-page from an older build.
        try "<script data-wasm=\"/app/App.wasm?v=\(token)\"></script>".write(
            toFile: dist + "/index.html", atomically: true, encoding: .utf8)
        try "<script data-wasm=\"/app/App.wasm?v=deadbeef\"></script>".write(
            toFile: dist + "/about/index.html", atomically: true, encoding: .utf8)
        let stale = ReleaseArtifacts.auditWasmVersions(distDir: dist)
        #expect(stale.versioned == false)
        #expect(stale.stale == ["about/index.html"])
        #expect(!ReleaseArtifacts.nginxConfText(wasmVersioned: stale.versioned).contains("immutable"))

        // Refreshed by `swiftwui ssg` → the year is safe.
        try "<script data-wasm=\"/app/App.wasm?v=\(token)\"></script>".write(
            toFile: dist + "/about/index.html", atomically: true, encoding: .utf8)
        #expect(ReleaseArtifacts.auditWasmVersions(distDir: dist) == (true, []))
    }
}
