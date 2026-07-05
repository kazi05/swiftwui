import Testing
import Foundation
@testable import SwiftWUIToolchain

struct MockRunner: ProcessRunner {
    var results: [String: ProcessResult]   // key: executable + " " + joined args prefix
    var recorded: (([String]) -> Void)? = nil
    func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult {
        recorded?([executable] + arguments)
        for (prefix, result) in results where ([executable] + arguments).joined(separator: " ").hasPrefix(prefix) {
            return result
        }
        return ProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
}

@Suite struct ToolchainBuildTests {
    @Test func sdkDetectPrefersPinnedAndSkipsEmbedded() throws {
        let both = MockRunner(results: ["swift sdk list": .init(
            exitCode: 0, stdout: "swift-6.3.3-RELEASE_wasm\nswift-6.3.3-RELEASE_wasm-embedded\n", stderr: "")])
        #expect(try WasmSDK.detect(runner: both) == "swift-6.3.3-RELEASE_wasm")
        let other = MockRunner(results: ["swift sdk list": .init(
            exitCode: 0, stdout: "swift-7.0-RELEASE_wasm-embedded\nswift-7.0-RELEASE_wasm\n", stderr: "")])
        #expect(try WasmSDK.detect(runner: other) == "swift-7.0-RELEASE_wasm")
        let none = MockRunner(results: ["swift sdk list": .init(exitCode: 0, stdout: "\n", stderr: "")])
        #expect(throws: ToolchainError.self) { try WasmSDK.detect(runner: none) }
    }

    @Test func buildFailurePropagatesCompilerOutput() {
        let runner = MockRunner(results: ["swift package": .init(exitCode: 1, stdout: "", stderr: "error: kaputt")])
        let builder = WasmBuilder(runner: runner, projectDir: "/tmp/x", sdk: WasmSDK.pinned)
        do { _ = try builder.build(configuration: "debug"); Issue.record("expected throw") }
        catch let e as ToolchainError {
            guard case .buildFailed(let out) = e else { Issue.record("wrong case"); return }
            #expect(out.contains("error: kaputt"))
        } catch { Issue.record("wrong error") }
    }

    @Test func buildIsolatesScratchPathFromNativeBuild() throws {
        var recordedArgs: [String] = []
        let runner = MockRunner(results: [:], recorded: { recordedArgs = $0 })
        let builder = WasmBuilder(runner: runner, projectDir: "/tmp/x", sdk: WasmSDK.pinned)
        let bundle = try builder.build(configuration: "debug")
        #expect(recordedArgs.contains("--scratch-path"))
        let idx = try #require(recordedArgs.firstIndex(of: "--scratch-path"))
        #expect(recordedArgs[idx + 1] == "/tmp/x/.build-wasm")
        #expect(bundle.contains(".build-wasm"))
    }

    @Test func distLayoutAssembles() throws {
        let fm = FileManager.default
        let proj = NSTemporaryDirectory() + "swiftwui-dist-\(UUID().uuidString)"
        let bundle = proj + "/fakebundle"
        try fm.createDirectory(atPath: bundle, withIntermediateDirectories: true)
        try "<head></head>".write(toFile: proj + "/index.html", atomically: true, encoding: .utf8)
        try "js".write(toFile: bundle + "/index.js", atomically: true, encoding: .utf8)
        try DistLayout.assemble(projectDir: proj, bundleDir: bundle, outDir: proj + "/dist")
        #expect(fm.fileExists(atPath: proj + "/dist/index.html"))
        #expect(fm.fileExists(atPath: proj + "/dist/app/index.js"))
        #expect(fm.fileExists(atPath: proj + "/dist/vendor/wasi-shim/index.js"))   // resource fallback
    }
}
