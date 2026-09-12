import Testing
import Foundation
@testable import SwiftWUIToolchain

@Suite struct WasmMetricsAndAssetTests {
    @Test func metricsReportAndBudgetAreDeterministic() throws {
        let root = NSTemporaryDirectory() + "swiftwui-metrics-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/app", withIntermediateDirectories: true)
        // Magic/version plus an empty custom section: enough for the structural parser.
        try Data([0, 97, 115, 109, 1, 0, 0, 0, 0, 0]).write(to: URL(fileURLWithPath: root + "/app/a.wasm"))
        let preflight = WasmSDK.Preflight(sdk: "swift-6.3.3-RELEASE_wasm", hostVersion: "6.3.3", sdkVersion: "6.3.3", compilerVersion: "6.3.3")
        let report = try WasmMetrics.report(distDir: root, fixture: "fixture", configuration: "release", preflight: preflight, runner: MockRunner(results: [:]))
        #expect(report.rawBytes == 10)
        #expect(report.sections["custom"] == 0)
        let reportPath = root + "/swiftwui-build-report.json"
        try Data("stale report".utf8).write(to: URL(fileURLWithPath: reportPath + ".gz"))
        try Data("stale report".utf8).write(to: URL(fileURLWithPath: reportPath + ".br"))
        try WasmMetrics.write(report, to: reportPath)
        #expect(!FileManager.default.fileExists(atPath: reportPath + ".gz"))
        #expect(!FileManager.default.fileExists(atPath: reportPath + ".br"))
        try WasmMetrics.enforce(.init(fixture: "fixture", configuration: "release", maximum: .init(rawBytes: 10)), against: report)
        #expect(throws: ToolchainError.self) { try WasmMetrics.enforce(.init(fixture: "fixture", configuration: "release", maximum: .init(rawBytes: 9)), against: report) }
        #expect(throws: ToolchainError.self) { try WasmMetrics.enforce(.init(fixture: "fixture", configuration: "release", maximum: .init(gzipBytes: 1)), against: report) }
    }

    @Test func preflightRejectsKnownMismatchedOverrideButAllowsMatchingFutureRelease() throws {
        let matching = MockRunner(results: [
            "swift sdk list": .init(exitCode: 0, stdout: "swift-7.1-RELEASE_wasm\n", stderr: ""),
            "swift --version": .init(exitCode: 0, stdout: "Swift version 7.1", stderr: ""),
            (ProcessInfo.processInfo.environment["SWIFT_EXEC"] ?? "swiftc") + " --version": .init(exitCode: 0, stdout: "Swift version 7.1", stderr: "")
        ])
        #expect(try WasmSDK.preflight(selectedSDK: "swift-7.1-RELEASE_wasm", runner: matching, cwd: "/tmp").sdk == "swift-7.1-RELEASE_wasm")
        let wrong = MockRunner(results: [
            "swift sdk list": .init(exitCode: 0, stdout: "swift-7.0-RELEASE_wasm\n", stderr: ""),
            "swift --version": .init(exitCode: 0, stdout: "Swift version 7.1", stderr: ""),
            (ProcessInfo.processInfo.environment["SWIFT_EXEC"] ?? "swiftc") + " --version": .init(exitCode: 0, stdout: "Swift version 7.1", stderr: "")
        ])
        #expect(throws: ToolchainError.self) { try WasmSDK.preflight(selectedSDK: "swift-7.0-RELEASE_wasm", runner: wrong, cwd: "/tmp") }
    }

    @Test func preflightRejectsFailedOrUnparseableVersionCommands() {
        let failed = MockRunner(results: [
            "swift sdk list": .init(exitCode: 0, stdout: "swift-7.1-RELEASE_wasm\n", stderr: ""),
            "swift --version": .init(exitCode: 1, stdout: "", stderr: "missing toolchain")
        ])
        #expect(throws: ToolchainError.self) { try WasmSDK.preflight(selectedSDK: "swift-7.1-RELEASE_wasm", runner: failed, cwd: "/tmp") }
        let unparseable = MockRunner(results: [
            "swift sdk list": .init(exitCode: 0, stdout: "swift-7.1-RELEASE_wasm\n", stderr: ""),
            "swift --version": .init(exitCode: 0, stdout: "not swift", stderr: ""),
            (ProcessInfo.processInfo.environment["SWIFT_EXEC"] ?? "swiftc") + " --version": .init(exitCode: 0, stdout: "not swift", stderr: "")
        ])
        #expect(throws: ToolchainError.self) { try WasmSDK.preflight(selectedSDK: "swift-7.1-RELEASE_wasm", runner: unparseable, cwd: "/tmp") }
    }

    @Test func assetPipelineWritesSrcsetManifestAndRejectsTraversal() throws {
        let root = NSTemporaryDirectory() + "swiftwui-assets-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: root) }
        try FileManager.default.createDirectory(atPath: root + "/public/images", withIntermediateDirectories: true)
        // 2x3 PNG header; payload is sufficient because dimension inspection is header-only.
        let png = Data([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,2,0,0,0,3])
        try png.write(to: URL(fileURLWithPath: root + "/public/images/hero.png"))
        let config = AssetPipeline.Configuration(images: [.init(id: "hero", variants: ["images/hero.png"], sizes: "100vw")])
        try JSONEncoder().encode(config).write(to: URL(fileURLWithPath: root + "/swiftwui-assets.json"))
        let generated = try AssetPipeline.generate(projectDir: root, outDir: root, runner: MockRunner(results: [:]))
        let manifest = try #require(generated)
        #expect(manifest.images == [.init(id: "hero", width: 2, height: 3, src: "/images/hero.png", srcset: "/images/hero.png 2w", sizes: "100vw")])
        #expect(manifest.fonts.isEmpty)
        let bad = AssetPipeline.Configuration(images: [.init(id: "bad", variants: ["../secret.png"])])
        try JSONEncoder().encode(bad).write(to: URL(fileURLWithPath: root + "/swiftwui-assets.json"))
        #expect(throws: ToolchainError.self) { try AssetPipeline.generate(projectDir: root, outDir: root, runner: MockRunner(results: [:])) }
    }
}
