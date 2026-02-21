import Foundation

struct BuildResult {
    let success: Bool
    let output: String
    let duration: TimeInterval
}

class WASMBuilder {
    let target: String
    let sdk: String
    let configuration: String

    init(target: String, sdk: String, configuration: String = "debug") {
        self.target = target
        self.sdk = sdk
        self.configuration = configuration
    }

    func build() -> BuildResult {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "package",
            "--swift-sdk", sdk,
            "js",
            "-c", configuration,
            "--product", target
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return BuildResult(success: false, output: "Failed to start build: \(error)", duration: Date().timeIntervalSince(start))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let success = process.terminationStatus == 0

        return BuildResult(success: success, output: output, duration: Date().timeIntervalSince(start))
    }

    static func detectSDK() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "sdk", "list"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.contains("wasm") && !$0.contains("embedded") && !$0.isEmpty }
    }

    var outputDirectory: String {
        ".build/plugins/PackageToJS/outputs/Package"
    }
}
