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

    /// The splice marker is a magic string repeated in three templates that
    /// nothing compiles, so this is the only thing standing between a head
    /// reorder and a site that boots nowhere: `build` writes modulepreloads
    /// into the region, and a modulepreload ABOVE the import map makes Firefox
    /// reject the map outright.
    @Test func everyTemplateHasTheBootMarkerBelowTheImportMap() throws {
        for template in Scaffolder.templates {
            let path = ToolchainResources.url("templates/\(template)/index.html")
            let html = try String(contentsOf: path, encoding: .utf8)
            let open = try #require(html.range(of: "<!--swiftwui:boot-->"),
                                    "template \(template): no boot marker")
            #expect(html.range(of: "<!--/swiftwui:boot-->") != nil,
                    "template \(template): boot marker never closed")
            let map = try #require(html.range(of: "importmap"),
                                   "template \(template): no import map")
            #expect(map.lowerBound < open.lowerBound,
                    "template \(template): import map must come BEFORE the boot marker")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func concurrentDrainSurvivesLargeStderr() throws {
        // 200KB to BOTH pipes — deadlocks under a sequential drain (stderr pipe fills
        // while the parent blocks on stdout EOF).
        let runner = FoundationProcessRunner()
        let script = "dd if=/dev/zero bs=1024 count=200 2>/dev/null | tr '\\0' 'e' >&2; dd if=/dev/zero bs=1024 count=200 2>/dev/null | tr '\\0' 'o'"
        let r = try runner.run("sh", ["-c", script], cwd: nil, streamOutput: false)
        #expect(r.exitCode == 0)
        #expect(r.stdout.utf8.count == 200 * 1024)
        #expect(r.stderr.utf8.count == 200 * 1024)
    }
}
