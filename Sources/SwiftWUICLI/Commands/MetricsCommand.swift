import ArgumentParser
import Foundation
import SwiftWUIToolchain

struct Metrics: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Inspect a built WASM artifact and validate an optional size budget.")
    @Option(name: .long, help: "Distribution directory.") var out: String = "dist"
    @Option(name: .long, help: "Fixture name used for comparisons.") var fixture: String = "app"
    @Option(name: [.customShort("c"), .customLong("configuration")]) var config: String = "release"
    @Option(name: .long, help: "Swift SDK id used to produce the artifact.") var swiftSdk: String?
    @Option(name: .long, help: "Optional JSON size budget.") var budget: String?

    func run() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let runner = FoundationProcessRunner()
        let preflight = try WasmSDK.preflight(selectedSDK: swiftSdk, runner: runner, cwd: cwd)
        let dist = out.hasPrefix("/") ? out : cwd + "/" + out
        let report = try WasmMetrics.report(distDir: dist, fixture: fixture, configuration: config, preflight: preflight, runner: runner)
        try WasmMetrics.write(report, to: dist + "/swiftwui-build-report.json")
        if let budget {
            let path = budget.hasPrefix("/") ? budget : cwd + "/" + budget
            guard let configured = try WasmMetrics.readBudget(path: path) else { throw ToolchainError.io("budget file does not exist: \(path)") }
            try WasmMetrics.enforce(configured, against: report)
        }
        print("WASM: \(report.rawBytes) raw, \(report.gzipBytes.map(String.init) ?? "n/a") gzip, \(report.brotliBytes.map(String.init) ?? "n/a") brotli")
    }
}
