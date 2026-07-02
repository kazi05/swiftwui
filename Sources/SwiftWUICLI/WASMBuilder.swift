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

        // Release builds get the full size-and-speed pass: whole-module
        // optimisation (-wmo), size-tuned optimisation (-Osize), no debug
        // info (-gnone), no reflection metadata (saves 5–15% binary size for
        // pure-Swift code that does not introspect at runtime), and a
        // post-link strip of all symbols. Debug builds keep DWARF intact so
        // Chrome's C/C++ DevTools extension can step through Swift sources.
        var args: [String] = [
            "swift", "package",
            "--swift-sdk", sdk,
        ]
        if configuration == "release" {
            args += [
                "-Xswiftc", "-Osize",
                "-Xswiftc", "-wmo",
                "-Xswiftc", "-gnone",
                "-Xswiftc", "-disable-reflection-metadata",
                "-Xlinker", "--strip-all",
            ]
        }
        args += [
            "js",
            "-c", configuration,
            "--product", target,
        ]
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return BuildResult(success: false, output: "Failed to start build: \(error)", duration: Date().timeIntervalSince(start))
        }

        // Drain the pipe on a background queue while the process runs. A pipe
        // buffer is ~64KB; a verbose or failing `swift package js` easily emits
        // more, at which point the child blocks writing while the parent blocks
        // in waitUntilExit() — a deadlock that froze the dev-server rebuild loop.
        // Reading only after run() succeeds guarantees the child's write end
        // closes (delivering EOF) when it exits.
        nonisolated(unsafe) var collected = Data()
        let handle = pipe.fileHandleForReading
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            collected = handle.readDataToEndOfFile()
            group.leave()
        }
        process.waitUntilExit()
        group.wait()

        let output = String(data: collected, encoding: .utf8) ?? ""
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
