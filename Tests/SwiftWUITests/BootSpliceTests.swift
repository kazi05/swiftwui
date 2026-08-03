import Foundation
import Testing
@testable import SwiftWUI
@testable import SwiftWUIStatic
@testable import SwiftWUIToolchain

private let shell = BootShell(html: "<template data-swui-boot-ui><b>L</b></template>",
                              css: ".b{}", delayMS: 300)
private let cfg = BootConfig(wasmURL: "/app/App.wasm?v=abc12345",
                             entryURL: "/app/index.js",
                             shimURL: "/app/swiftwui-boot.js",
                             sizeBytes: 42, delayMS: 300)
private let head = "<head><script type=\"importmap\">{}</script>"

@Suite struct BootSpliceTests {
    @Test func replacesThePairedRegionAndIsIdempotent() throws {
        let html = head + "<!--swiftwui:boot--><!--/swiftwui:boot--></head><body></body>"
        let once = try #require(BootSplice.apply(html: html, shell: shell, config: cfg))
        let twice = try #require(BootSplice.apply(html: once, shell: shell, config: cfg))
        #expect(once == twice, "a rebuild must not stack a second boot block")
        #expect(once.components(separatedBy: "data-swui-boot-config").count - 1 == 1)
    }

    /// A stale `?v=` surviving a rebuild would be an immutable cache header
    /// pointing at the previous binary.
    @Test func aRebuildReplacesTheVersionRatherThanKeepingIt() throws {
        let html = head + "<!--swiftwui:boot--><!--/swiftwui:boot--></head><body></body>"
        let old = try #require(BootSplice.apply(html: html, shell: shell, config: cfg))
        var next = cfg
        next.wasmURL = "/app/App.wasm?v=99999999"
        let new = try #require(BootSplice.apply(html: old, shell: shell, config: next))
        #expect(!new.contains("abc12345"))
        #expect(new.contains("v=99999999"))
    }

    @Test func importMapStillPrecedesEveryModulepreload() throws {
        let html = head + "<!--swiftwui:boot--><!--/swiftwui:boot--></head><body></body>"
        let out = try #require(BootSplice.apply(html: html, shell: shell, config: cfg))
        let map = try #require(out.range(of: "type=\"importmap\""))
        let pre = try #require(out.range(of: "rel=\"modulepreload\""))
        #expect(map.lowerBound < pre.lowerBound)
    }

    @Test func fallsBackToTheHeadAnchorForOlderProjects() throws {
        let html = head + "</head><body></body>"
        let out = try #require(BootSplice.apply(html: html, shell: shell, config: cfg))
        #expect(out.contains("<!--swiftwui:boot-->"))
        #expect(out.contains("data-swui-boot-config"))
    }

    @Test func returnsNilWhenThereIsNowhereSafeToPutIt() {
        #expect(BootSplice.apply(html: "<p>no head here</p>", shell: shell, config: cfg) == nil)
    }

    /// The templates no longer inline the module script, so a project that
    /// declared no boot UI boots ONLY because the splice still writes one.
    @Test func aProjectWithoutBootUIStillGetsAnEntryScript() throws {
        let html = head + "<!--swiftwui:boot--><!--/swiftwui:boot--></head><body></body>"
        let out = try #require(BootSplice.apply(html: html, shell: nil, config: nil))
        #expect(out.contains("import { init } from \"/app/index.js\""))
        #expect(out.contains("await init()"))
        #expect(!out.contains("data-swui-boot-config"), "no shim without a boot shell")
        #expect(!out.contains("data-swui-boot-ui"))
    }

    @Test func escapesTheURLsItStampsIntoAttributes() throws {
        var evil = cfg
        evil.wasmURL = "/app/\"onload=x.wasm"
        let html = head + "<!--swiftwui:boot--><!--/swiftwui:boot--></head><body></body>"
        let out = try #require(BootSplice.apply(html: html, shell: shell, config: evil))
        #expect(!out.contains("\"onload=x"))
        #expect(out.contains("&quot;onload=x"))
    }
}

@Suite struct BootSpliceWriteTests {
    /// A fake assembled dist: index.html with the marker + app/ holding a wasm.
    private func makeDist() throws -> String {
        let dir = NSTemporaryDirectory() + "swiftwui-splice-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir + "/app", withIntermediateDirectories: true)
        try Data("wasm bytes, not a real module".utf8).write(to: URL(fileURLWithPath: dir + "/app/Probe.wasm"))
        try (head + "<!--swiftwui:boot--><!--/swiftwui:boot--></head><body></body>")
            .write(toFile: dir + "/index.html", atomically: true, encoding: .utf8)
        return dir
    }

    @Test func stampsTheDigest_copiesTheShim_andRepeatsByteForByte() throws {
        let dist = try makeDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }

        #expect(try BootSplice.write(outDir: dist, shell: shell))
        let once = try String(contentsOfFile: dist + "/index.html", encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: dist + "/app/swiftwui-boot.js"),
                "the shim the spliced tag names must be in dist")
        let stamp = try #require(WasmDigest.stamp(path: dist + "/app/Probe.wasm"))
        #expect(once.contains("data-wasm=\"/app/Probe.wasm?v=" + WasmDigest.version(stamp) + "\""))
        #expect(once.contains("data-size=\"\(stamp.sizeBytes)\""))
        #expect(once.contains("src=\"/app/swiftwui-boot.js\""))

        #expect(try BootSplice.write(outDir: dist, shell: shell))
        let twice = try String(contentsOfFile: dist + "/index.html", encoding: .utf8)
        #expect(once == twice, "two builds must produce byte-identical index.html")
    }

    /// `WasmDigest` (the build's `?v=`) and `BootStamp` (every prerendered
    /// document's `?v=`) are separate implementations by design. If they ever
    /// disagree, the root index.html and the per-route documents name two
    /// different cache entries for one binary.
    @Test func theBuildsVersionTokenMatchesTheSSGs() throws {
        let dist = try makeDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        let ssg = try #require(BootStamp.read(outDir: dist))
        let build = try #require(WasmDigest.stamp(path: dist + "/app/Probe.wasm"))
        #expect(ssg.version == WasmDigest.version(build))
        #expect(ssg.sizeBytes == build.sizeBytes)
        #expect(ssg.fileName == "Probe.wasm")
    }

    @Test func aProjectWithoutBootUIGetsNoShimAndNoVersion() throws {
        let dist = try makeDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        #expect(try BootSplice.write(outDir: dist, shell: nil) == false,
                "no ?v= in the document means no immutable header over the wasm")
        #expect(!FileManager.default.fileExists(atPath: dist + "/app/swiftwui-boot.js"))
        let html = try String(contentsOfFile: dist + "/index.html", encoding: .utf8)
        #expect(html.contains("await init()"))
    }

    @Test func anIndexWithNowhereToSpliceIsLeftUntouched() throws {
        let dist = try makeDist()
        defer { try? FileManager.default.removeItem(atPath: dist) }
        try "<p>hand-written, no head</p>".write(toFile: dist + "/index.html",
                                                 atomically: true, encoding: .utf8)
        #expect(try BootSplice.write(outDir: dist, shell: shell) == false)
        #expect(try String(contentsOfFile: dist + "/index.html", encoding: .utf8)
                == "<p>hand-written, no head</p>")
    }
}
