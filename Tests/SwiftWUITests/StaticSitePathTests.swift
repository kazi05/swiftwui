import Foundation
import Testing
@testable import SwiftWUIStatic

#if canImport(Darwin)
@Suite struct StaticSitePathTests {
    /// `NSTemporaryDirectory()` is spelled `/var/folders/…`; the same directory
    /// spelled physically (what `getcwd` returns after `cd` into it) starts with `/private`.
    @Test func writeDocumentAcceptsPhysicalPrivateOutputDirectory() throws {
        let base = NSTemporaryDirectory() + "swiftwui-private-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: base) }
        let physical = "/private" + base
        try StaticSite.writeDocument("a", path: "/a", outDir: physical)      // outDir created here
        try StaticSite.writeDocument("b", path: "/b/c", outDir: physical)    // outDir now exists
        try StaticSite.writeDocument("a2", path: "/a", outDir: physical)     // a rerun overwrites
        #expect(try String(contentsOfFile: base + "/a/index.html", encoding: .utf8) == "a2")
        #expect(FileManager.default.fileExists(atPath: base + "/b/c/index.html"))

        // The other direction: spelled through the `/tmp` → `/private/tmp` symlink.
        let tmp = "/tmp/swiftwui-tmp-" + UUID().uuidString
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try StaticSite.writeDocument("c", path: "/c", outDir: tmp)
        #expect(FileManager.default.fileExists(atPath: tmp + "/c/index.html"))
    }
}
#endif

@Suite struct StaticSiteOutputSymlinkTests {
    /// `--out` is the developer's choice, so a symlinked output directory writes into its
    /// target; page paths still cannot leave it (`writeDocumentRejectsSymlinkedOutputDirectory`).
    @Test func writeDocumentFollowsASymlinkedOutputDirectory() throws {
        let fm = FileManager.default
        let base = NSTemporaryDirectory() + "swiftwui-outlink-" + UUID().uuidString
        defer { try? fm.removeItem(atPath: base) }
        try fm.createDirectory(atPath: base + "/real", withIntermediateDirectories: true)
        try fm.createSymbolicLink(atPath: base + "/out", withDestinationPath: base + "/real")
        try StaticSite.writeDocument("a", path: "/a", outDir: base + "/out")
        #expect(fm.fileExists(atPath: base + "/real/a/index.html"))
    }
}
