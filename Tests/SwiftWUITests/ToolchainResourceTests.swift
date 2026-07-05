import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct ToolchainResourceTests {
    @Test func vendoredShimShipsESMEntryAndLicenses() throws {
        let dir = ToolchainResources.url("vendor/wasi-shim")
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(names.contains("index.js"))
        #expect(names.contains("wasi.js"))          // sibling import of index.js
        #expect(names.contains("LICENSE-MIT"))
        #expect(names.contains("LICENSE-APACHE"))
        #expect(!names.contains("tsconfig.tsbuildinfo"))
        let entry = try String(contentsOf: dir.appendingPathComponent("index.js"), encoding: .utf8)
        #expect(entry.contains("./wasi.js"))        // relative sibling imports = must ship whole dist
    }
}
