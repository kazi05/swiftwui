import Foundation
import Testing
@testable import SwiftWUIToolchain

private final class VariantWriter: ProcessRunner {
    var calls = 0
    func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult {
        calls += 1
        let output = arguments[0]
        let width = Int(arguments[1])!
        let header = "<svg viewBox=\"0 0 \(width) \(width / 2)\"><!-- generation \(calls) --></svg>"
        try header.write(toFile: output, atomically: true, encoding: .utf8)
        return ProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
}

@Suite struct AssetPipelineRegressionTests {
    @Test func sourceOnlyJSONGeneratesRefreshesAndPublishesWithoutSecondEncoding() throws {
        let root = NSTemporaryDirectory() + "swiftwui-variants-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/public", withIntermediateDirectories: true)
        try "<svg viewBox=\"0 0 64 32\"></svg>".write(toFile: root + "/public/hero.svg", atomically: true, encoding: .utf8)
        try #"{"images":[{"id":"hero","source":"hero.svg","widths":[16,32],"command":["encoder","{output}","{width}"]}]}"#
            .write(toFile: root + "/swiftwui-assets.json", atomically: true, encoding: .utf8)
        let runner = VariantWriter()
        #expect(try AssetPipeline.prepare(projectDir: root, runner: runner))
        #expect(runner.calls == 2)
        let manifest = try #require(try AssetPipeline.writePreparedManifest(projectDir: root, outDir: root))
        #expect(manifest.images.first?.srcset == "/hero-16w.svg 16w, /hero-32w.svg 32w")
        #expect(runner.calls == 2)
        _ = try AssetPipeline.prepare(projectDir: root, runner: runner)
        #expect(runner.calls == 4)
        #expect(try String(contentsOfFile: root + "/public/hero-16w.svg", encoding: .utf8).contains("generation 3"))
    }

    @Test func generatedVariantCannotOverwriteAnExternalSymlink() throws {
        let root = NSTemporaryDirectory() + "swiftwui-variant-containment-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/public", withIntermediateDirectories: true)
        try "<svg viewBox=\"0 0 64 32\"></svg>".write(toFile: root + "/public/hero.svg", atomically: true, encoding: .utf8)
        try "keep".write(toFile: root + "/outside.svg", atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(atPath: root + "/public/hero-16w.svg", withDestinationPath: root + "/outside.svg")
        try #"{"images":[{"id":"hero","source":"hero.svg","widths":[16],"command":["encoder","{output}","{width}"]}]}"#
            .write(toFile: root + "/swiftwui-assets.json", atomically: true, encoding: .utf8)
        let runner = VariantWriter()
        #expect(throws: ToolchainError.self) { try AssetPipeline.prepare(projectDir: root, runner: runner) }
        #expect(runner.calls == 0)
        #expect(try String(contentsOfFile: root + "/outside.svg", encoding: .utf8) == "keep")
    }
}
