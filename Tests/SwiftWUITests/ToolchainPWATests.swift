import Foundation
import Testing
import SwiftWUI          // SHA256 lives in the core now
@testable import SwiftWUIToolchain

@Suite struct SHA256Tests {
    // Official FIPS 180-4 test vectors.
    @Test func emptyInput() {
        #expect(SHA256.hex(SHA256.digest([])) ==
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
    @Test func abc() {
        #expect(SHA256.hex(SHA256.digest(Array("abc".utf8))) ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    @Test func twoBlockMessage() {
        let msg = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(SHA256.hex(SHA256.digest(Array(msg.utf8))) ==
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }
    @Test func millionA() {
        let msg = [UInt8](repeating: UInt8(ascii: "a"), count: 1_000_000)
        #expect(SHA256.hex(SHA256.digest(msg)) ==
            "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }
    @Test func base64MatchesIntegrityFormat() {
        // "abc" digest, base64 — the form fetch()'s integrity option needs.
        #expect(SHA256.base64(SHA256.digest(Array("abc".utf8))) ==
            "ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=")
    }
}

@Suite struct PWAAssetsTests {
    private func makeDist(withSW: Bool) throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-pwa-\(UUID().uuidString)"
        let fm = FileManager.default
        try fm.createDirectory(atPath: dir + "/app", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: dir + "/about", withIntermediateDirectories: true)
        try "shell".write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        try "wasm-bytes".write(toFile: dir + "/app/App.wasm", atomically: true, encoding: .utf8)
        try "glue".write(toFile: dir + "/app/index.js", atomically: true, encoding: .utf8)
        try "prerendered".write(toFile: dir + "/about/index.html", atomically: true, encoding: .utf8)
        try "junk".write(toFile: dir + "/.DS_Store", atomically: true, encoding: .utf8)
        if withSW {
            try "importScripts('/sw-assets.js');".write(toFile: dir + "/sw.js", atomically: true, encoding: .utf8)
        }
        return dir
    }

    @Test func noSWMeansNoManifest() throws {
        let dir = try makeDist(withSW: false)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(try PWAAssets.generateManifest(distDir: dir) == false)
        #expect(!FileManager.default.fileExists(atPath: dir + "/sw-assets.js"))
    }

    @Test func generatesSortedDeterministicManifest() throws {
        let dir = try makeDist(withSW: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(try PWAAssets.generateManifest(distDir: dir) == true)
        let first = try String(contentsOfFile: dir + "/sw-assets.js", encoding: .utf8)
        // exclusions
        #expect(!first.contains("/about/index.html"))
        #expect(!first.contains(".DS_Store"))
        #expect(!first.contains("\"/sw.js\""))
        #expect(!first.contains("\"/sw-assets.js\""))
        // root shell + bundle present, with the integrity our own SHA256 computes
        #expect(first.contains("\"/index.html\""))
        let expected = "sha256-" + SHA256.base64(SHA256.digest(Array("wasm-bytes".utf8)))
        #expect(first.contains("{ \"url\": \"/app/App.wasm\", \"integrity\": \"\(expected)\" }"))
        // sorted by URL
        let appRange = first.range(of: "\"/app/App.wasm\"")!
        let idxRange = first.range(of: "\"/index.html\"")!
        #expect(appRange.lowerBound < idxRange.lowerBound)
        // deterministic across runs
        try PWAAssets.generateManifest(distDir: dir)
        let second = try String(contentsOfFile: dir + "/sw-assets.js", encoding: .utf8)
        #expect(first == second)
    }

    @Test func versionTracksContent() throws {
        let dir = try makeDist(withSW: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try PWAAssets.generateManifest(distDir: dir)
        let v1 = try String(contentsOfFile: dir + "/sw-assets.js", encoding: .utf8)
        try "wasm-bytes-CHANGED".write(toFile: dir + "/app/App.wasm", atomically: true, encoding: .utf8)
        try PWAAssets.generateManifest(distDir: dir)
        let v2 = try String(contentsOfFile: dir + "/sw-assets.js", encoding: .utf8)
        #expect(v1 != v2)
    }

    @Test func buildDescriptorIsNeverPrecached() {
        #expect(PWAAssets.isExcluded(relPath: "swiftwui-site.json"))
    }

    @Test func swAssetsIsReservedPublicName() {
        #expect(DistLayout.reservedNames.contains("sw-assets.js"))
        #expect(!DistLayout.reservedNames.contains("sw.js"))   // user-owned, must stay allowed
    }

    @Test func symlinkedDirectoryThrows() throws {
        let dir = try makeDist(withSW: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let fm = FileManager.default
        let real = dir + "-real-assets"
        try fm.createDirectory(atPath: real, withIntermediateDirectories: true)
        try "hidden".write(toFile: real + "/asset.txt", atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(atPath: real) }
        try fm.createSymbolicLink(atPath: dir + "/linked", withDestinationPath: real)
        #expect(throws: ToolchainError.self) {
            try PWAAssets.generateManifest(distDir: dir)
        }
    }

    @Test func rejectsUnsafeURLCharactersInFilename() throws {
        let dir = try makeDist(withSW: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "junk".write(toFile: dir + "/bad?.txt", atomically: true, encoding: .utf8)
        #expect(throws: ToolchainError.self) {
            try PWAAssets.generateManifest(distDir: dir)
        }
    }

    @Test func symlinkedFileIsPrecached() throws {
        let dir = try makeDist(withSW: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let fm = FileManager.default
        let externalDir = NSTemporaryDirectory() + "swiftwui-external-\(UUID().uuidString)"
        try fm.createDirectory(atPath: externalDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: externalDir) }

        let logoContent = "logo-content"
        try logoContent.write(toFile: externalDir + "/logo.txt", atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(atPath: dir + "/logo.txt", withDestinationPath: externalDir + "/logo.txt")

        #expect(try PWAAssets.generateManifest(distDir: dir) == true)
        let manifest = try String(contentsOfFile: dir + "/sw-assets.js", encoding: .utf8)

        let expectedIntegrity = "sha256-" + SHA256.base64(SHA256.digest(Array(logoContent.utf8)))
        #expect(manifest.contains("\"/logo.txt\""))
        #expect(manifest.contains("\"integrity\": \"\(expectedIntegrity)\""))
    }
}

@Suite struct ScaffoldPWATests {
    private func scratchProject() throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-pwa-scaffold-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let html = "<!doctype html>\n<html>\n<head>\n  <title>X</title>\n</head>\n<body></body>\n</html>\n"
        try html.write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        return dir
    }

    @Test func createsFullArtifactSet() throws {
        let dir = try scratchProject()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let r = try Scaffolder.scaffoldPWA(into: dir, name: "MyApp")
        let fm = FileManager.default
        for f in ["public/manifest.webmanifest", "public/sw.js",
                  "public/icons/icon-192.png", "public/icons/icon-512.png",
                  "public/icons/icon-512-maskable.png", "public/icons/apple-touch-icon.png"] {
            #expect(fm.fileExists(atPath: dir + "/" + f), "missing \(f)")
        }
        #expect(r.created.count == 7)   // 6 files + index.html head links
        let manifest = try String(contentsOfFile: dir + "/public/manifest.webmanifest", encoding: .utf8)
        #expect(manifest.contains("\"name\": \"MyApp\""))
        #expect(!manifest.contains("{{"))
        let html = try String(contentsOfFile: dir + "/index.html", encoding: .utf8)
        #expect(html.contains("swiftwui:serviceworker"))
        #expect(html.contains("rel=\"manifest\""))
        // inserted before </head>
        #expect(html.range(of: "swiftwui:serviceworker")!.lowerBound
              < html.range(of: "</head>")!.lowerBound)
    }

    @Test func idempotentSecondRun() throws {
        let dir = try scratchProject()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        _ = try Scaffolder.scaffoldPWA(into: dir, name: "MyApp")
        let htmlBefore = try String(contentsOfFile: dir + "/index.html", encoding: .utf8)
        try "user-edited".write(toFile: dir + "/public/sw.js", atomically: true, encoding: .utf8)
        let r = try Scaffolder.scaffoldPWA(into: dir, name: "MyApp")
        #expect(r.created.isEmpty)
        #expect(r.skipped.count == 7)
        // user edits survive; index.html untouched
        #expect(try String(contentsOfFile: dir + "/public/sw.js", encoding: .utf8) == "user-edited")
        #expect(try String(contentsOfFile: dir + "/index.html", encoding: .utf8) == htmlBefore)
    }

    @Test func missingIndexHTMLThrows() {
        let dir = NSTemporaryDirectory() + "swiftwui-pwa-empty-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        #expect(throws: (any Error).self) {
            try Scaffolder.scaffoldPWA(into: dir, name: "X")
        }
    }

    // sw.js cannot execute natively — structural validation per spec §Testing.
    @Test func swTemplateStructure() throws {
        let js = try String(contentsOf: ToolchainResources.url("pwa/sw.js"), encoding: .utf8)
        #expect(js.contains("importScripts('/sw-assets.js')"))
        #expect(js.contains("SKIP_WAITING"))
        #expect(js.contains("swiftwui-precache-"))
        #expect(js.contains("url.origin !== self.location.origin"))   // same-origin guard
        #expect(!js.contains("https://"))                              // no cross-origin fetches
        // "skipWaiting()" alone also matches the file's own comment warning against
        // calling it unconditionally — count the actual call form instead.
        #expect(js.components(separatedBy: "self.skipWaiting()").count - 1 == 1)   // exactly one call site
        #expect(js.contains("event.data.type === 'SKIP_WAITING'"))
    }
}

@Suite struct PWABuildIntegrationTests {
    /// Mimics BuildCommand.run(): assemble dist from a fixture bundle, then generate.
    /// Covers the BuildCommand shape only; SSG-shaped dist tested separately.
    private func makeProject(withPWA: Bool) throws -> (proj: String, bundle: String) {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-pwa-build-\(UUID().uuidString)"
        let bundle = proj + "/fake-bundle"
        try fm.createDirectory(atPath: bundle, withIntermediateDirectories: true)
        try "glue".write(toFile: bundle + "/index.js", atomically: true, encoding: .utf8)
        try "<html><head></head><body></body></html>"
            .write(toFile: proj + "/index.html", atomically: true, encoding: .utf8)
        if withPWA {
            try fm.createDirectory(atPath: proj + "/public", withIntermediateDirectories: true)
            try "importScripts('/sw-assets.js');"
                .write(toFile: proj + "/public/sw.js", atomically: true, encoding: .utf8)
        }
        return (proj, bundle)
    }

    @Test func pwaProjectGetsManifestInDist() throws {
        let (proj, bundle) = try makeProject(withPWA: true)
        defer { try? FileManager.default.removeItem(atPath: proj) }
        let out = proj + "/dist"
        try DistLayout.assemble(projectDir: proj, bundleDir: bundle, outDir: out)
        #expect(try PWAAssets.generateManifest(distDir: out) == true)
        #expect(FileManager.default.fileExists(atPath: out + "/sw-assets.js"))
        let js = try String(contentsOfFile: out + "/sw-assets.js", encoding: .utf8)
        #expect(js.contains("\"/sw.js\"") == false)      // worker never precaches itself
        #expect(js.contains("\"/app/index.js\""))         // bundle is precached
    }

    @Test func plainSPAIsUntouched() throws {
        let (proj, bundle) = try makeProject(withPWA: false)
        defer { try? FileManager.default.removeItem(atPath: proj) }
        let out = proj + "/dist"
        try DistLayout.assemble(projectDir: proj, bundleDir: bundle, outDir: out)
        #expect(try PWAAssets.generateManifest(distDir: out) == false)
        #expect(!FileManager.default.fileExists(atPath: out + "/sw-assets.js"))
    }

    /// Mimics SSGCommand.run(): SSG renderer already wrote per-route pages,
    /// then copyPublic brings sw.js in, then the manifest is generated.
    @Test func ssgShapedDistGetsManifestWithoutRoutePages() throws {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-pwa-ssg-\(UUID().uuidString)"
        let out = proj + "/dist"
        defer { try? fm.removeItem(atPath: proj) }
        try fm.createDirectory(atPath: out + "/about", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: out + "/app", withIntermediateDirectories: true)
        try "shell".write(toFile: out + "/index.html", atomically: true, encoding: .utf8)
        try "prerendered".write(toFile: out + "/about/index.html", atomically: true, encoding: .utf8)
        try "wasm".write(toFile: out + "/app/App.wasm", atomically: true, encoding: .utf8)
        try fm.createDirectory(atPath: proj + "/public", withIntermediateDirectories: true)
        try "importScripts('/sw-assets.js');"
            .write(toFile: proj + "/public/sw.js", atomically: true, encoding: .utf8)
        try DistLayout.copyPublic(projectDir: proj, outDir: out)
        #expect(try PWAAssets.generateManifest(distDir: out) == true)
        let js = try String(contentsOfFile: out + "/sw-assets.js", encoding: .utf8)
        #expect(js.contains("\"/index.html\""))          // root shell precached
        #expect(!js.contains("/about/index.html"))        // route prerender excluded
        #expect(js.contains("\"/app/App.wasm\""))
    }

    // final-review #2: a generated sitemap set is the same "HTTP-layer SEO
    // artifact, not offline artifact" category as per-route prerenders — it
    // must not silently bloat every visitor's precache.
    @Test func generatedSitemapsAreExcludedFromManifest() throws {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-pwa-sitemap-\(UUID().uuidString)"
        let out = proj + "/dist"
        defer { try? fm.removeItem(atPath: proj) }
        try fm.createDirectory(atPath: out, withIntermediateDirectories: true)
        try "shell".write(toFile: out + "/index.html", atomically: true, encoding: .utf8)
        try "<urlset></urlset>".write(toFile: out + "/sitemap.xml", atomically: true, encoding: .utf8)
        try "<urlset></urlset>".write(toFile: out + "/sitemap-1.xml", atomically: true, encoding: .utf8)
        try fm.createDirectory(atPath: proj + "/public", withIntermediateDirectories: true)
        try "importScripts('/sw-assets.js');"
            .write(toFile: proj + "/public/sw.js", atomically: true, encoding: .utf8)
        try DistLayout.copyPublic(projectDir: proj, outDir: out)
        #expect(try PWAAssets.generateManifest(distDir: out) == true)
        let js = try String(contentsOfFile: out + "/sw-assets.js", encoding: .utf8)
        #expect(js.contains("\"/index.html\""))
        #expect(!js.contains("sitemap"))
    }
}

@Suite struct PWAServingPolicyTests {
    @Test func nginxTemplatesSendNoCache() throws {
        for template in Scaffolder.templates {
            let path = ToolchainResources.url("templates/\(template)/nginx.conf").path
            let conf = try String(contentsOfFile: path, encoding: .utf8)
            #expect(conf.contains("add_header Cache-Control \"no-cache\";"), "template \(template)")
        }
    }
    @Test func devClientUnregistersServiceWorkers() throws {
        let js = try String(contentsOf: ToolchainResources.url("dev-client.js"), encoding: .utf8)
        #expect(js.contains("getRegistrations"))
        #expect(js.contains("unregister"))
    }
}
