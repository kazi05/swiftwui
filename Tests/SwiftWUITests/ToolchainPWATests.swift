import Foundation
import Testing
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
        #expect(throws: (any Error).self) {
            try PWAAssets.generateManifest(distDir: dir)
        }
    }
}
