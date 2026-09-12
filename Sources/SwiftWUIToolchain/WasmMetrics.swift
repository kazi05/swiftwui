import Foundation

/// Deterministic, dependency-free description of the shipped WASM artifact.
/// It is intentionally structural rather than a symbol profiler: optimized Swift
/// binaries often omit names, but section/import changes remain comparable.
public enum WasmMetrics {
    public struct Report: Codable, Equatable {
        public var schemaVersion = 1
        public var fixture: String
        public var configuration: String
        public var wasmPath: String
        public var rawBytes: Int
        public var gzipBytes: Int?
        public var brotliBytes: Int?
        public var sections: [String: Int]
        public var imports: [String: Int]
        public var toolchain: Toolchain
    }

    public struct Toolchain: Codable, Equatable {
        public var sdk: String
        public var hostSwift: String?
        public var compilerSwift: String?
        public var hostExecutable: String?
        public var compilerExecutable: String?
        public var wasmOpt: String?
    }

    public struct Budget: Codable, Equatable {
        public var fixture: String
        public var configuration: String
        public var maximum: Limits
        public init(fixture: String, configuration: String, maximum: Limits) {
            self.fixture = fixture; self.configuration = configuration; self.maximum = maximum
        }
    }
    public struct Limits: Codable, Equatable {
        public var rawBytes: Int?
        public var gzipBytes: Int?
        public var brotliBytes: Int?
        public init(rawBytes: Int? = nil, gzipBytes: Int? = nil, brotliBytes: Int? = nil) {
            self.rawBytes = rawBytes; self.gzipBytes = gzipBytes; self.brotliBytes = brotliBytes
        }
    }

    public static func report(distDir: String, fixture: String, configuration: String,
                              preflight: WasmSDK.Preflight, runner: ProcessRunner) throws -> Report {
        guard let name = WasmDigest.wasmName(inAppDir: distDir + "/app") else {
            throw ToolchainError.io("no .wasm artifact under \(distDir)/app")
        }
        let path = distDir + "/app/" + name
        guard let data = FileManager.default.contents(atPath: path) else { throw ToolchainError.io("cannot read \(path)") }
        let composition = try parse(data)
        return Report(fixture: fixture, configuration: configuration, wasmPath: "app/" + name,
                      rawBytes: data.count, gzipBytes: verifiedCompressedSize(path + ".gz", source: data, tool: "gzip", arguments: ["-cd"], runner: runner),
                      brotliBytes: verifiedCompressedSize(path + ".br", source: data, tool: "brotli", arguments: ["-d", "-c"], runner: runner),
                      sections: composition.sections, imports: composition.imports,
                      toolchain: Toolchain(sdk: preflight.sdk, hostSwift: preflight.hostVersion,
                                           compilerSwift: preflight.compilerVersion,
                                           hostExecutable: preflight.hostExecutable,
                                           compilerExecutable: preflight.compilerExecutable,
                                           wasmOpt: toolVersion("wasm-opt", runner: runner)))
    }

    public static func write(_ report: Report, to path: String) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(report).write(to: URL(fileURLWithPath: path), options: .atomic)
        // Build writes reports after compression. A previous build's sibling
        // must not shadow this report in a gzip_static/brotli_static server.
        for suffix in [".gz", ".br"] {
            let sibling = path + suffix
            if FileManager.default.fileExists(atPath: sibling) {
                try FileManager.default.removeItem(atPath: sibling)
            }
        }
    }

    public static func readBudget(path: String) throws -> Budget? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return try JSONDecoder().decode(Budget.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }

    public static func enforce(_ budget: Budget, against report: Report) throws {
        guard budget.fixture == report.fixture, budget.configuration == report.configuration else {
            throw ToolchainError.budgetExceeded("budget is for \(budget.fixture)/\(budget.configuration), artifact is \(report.fixture)/\(report.configuration); compare the same fixture and configuration")
        }
        var failures: [String] = []
        func check(_ label: String, _ actual: Int?, _ max: Int?) {
            guard let max else { return }
            guard let actual else { failures.append("\(label) is unavailable (a verified compressed sibling is required for this budget)"); return }
            if actual > max { failures.append("\(label) \(actual) > \(max)") }
        }
        check("rawBytes", report.rawBytes, budget.maximum.rawBytes)
        check("gzipBytes", report.gzipBytes, budget.maximum.gzipBytes)
        check("brotliBytes", report.brotliBytes, budget.maximum.brotliBytes)
        if !failures.isEmpty { throw ToolchainError.budgetExceeded(failures.joined(separator: ", ")) }
    }

    private static func verifiedCompressedSize(_ path: String, source: Data, tool: String, arguments: [String], runner: ProcessRunner) -> Int? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        // Keep the runner call observable in command tests, then compare actual
        // decompressed bytes. A valid but stale `.gz`/`.br` must never satisfy a
        // size budget for a newer wasm artifact.
        guard let result = try? runner.run(tool, arguments + [path], cwd: nil, streamOutput: false), result.exitCode == 0,
              let decoded = decompressed(path: path, tool: tool, arguments: arguments), decoded == source else { return nil }
        return attributes[.size] as? Int
    }

    private static func decompressed(path: String, tool: String, arguments: [String]) -> Data? {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + arguments + [path]
        let output = Pipe(), error = Pipe(); process.standardOutput = output; process.standardError = error
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        _ = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
    private static func toolVersion(_ tool: String, runner: ProcessRunner) -> String? {
        guard let result = try? runner.run(tool, ["--version"], cwd: nil, streamOutput: false), result.exitCode == 0 else { return nil }
        return result.stdout.split(whereSeparator: \.isNewline).first.map(String.init)
    }

    private struct Composition { var sections: [String: Int]; var imports: [String: Int] }
    private static func parse(_ data: Data) throws -> Composition {
        let bytes = [UInt8](data)
        guard bytes.count >= 8, Array(bytes[0..<4]) == [0, 97, 115, 109], Array(bytes[4..<8]) == [1, 0, 0, 0] else { throw ToolchainError.io("artifact is not a supported WASM v1 binary") }
        let names = [0:"custom", 1:"type", 2:"import", 3:"function", 4:"table", 5:"memory", 6:"global", 7:"export", 8:"start", 9:"element", 10:"code", 11:"data", 12:"dataCount", 13:"tag"]
        var at = 8, sections: [String: Int] = [:], imports: [String: Int] = [:]
        while at < bytes.count {
            let id = Int(bytes[at]); at += 1
            guard let (size, next) = uleb(bytes, at), next + size <= bytes.count else { throw ToolchainError.io("malformed WASM section") }
            let start = next; at = next + size
            sections[names[id] ?? "section\(id)", default: 0] += size
            if id == 2 { parseImports(Array(bytes[start..<at]), into: &imports) }
        }
        return Composition(sections: sections, imports: imports)
    }
    private static func parseImports(_ payload: [UInt8], into imports: inout [String: Int]) {
        guard let (count, first) = uleb(payload, 0) else { return }; var at = first
        for _ in 0..<count {
            guard let (module, afterModule) = wasmString(payload, at), let (field, afterField) = wasmString(payload, afterModule), afterField < payload.count else { return }
            let kind = payload[afterField]; at = afterField + 1
            imports[module + "." + field, default: 0] += 1
            switch kind { case 0: guard let (_, n) = uleb(payload, at) else { return }; at = n
            case 1: guard at < payload.count else { return }; at += 1; guard let (_, n) = limits(payload, at) else { return }; at = n
            case 2: guard let (_, n) = limits(payload, at) else { return }; at = n
            case 3: guard at < payload.count else { return }; at += 2
            case 4: guard at < payload.count else { return }; at += 1; guard let (_, n) = uleb(payload, at) else { return }; at = n
            default: return }
        }
    }
    private static func wasmString(_ bytes: [UInt8], _ at: Int) -> (String, Int)? { guard let (n, p) = uleb(bytes, at), p + n <= bytes.count else { return nil }; return (String(decoding: bytes[p..<p+n], as: UTF8.self), p+n) }
    private static func limits(_ b: [UInt8], _ at: Int) -> (Int, Int)? {
        guard at < b.count, b[at] <= 3, let (_, afterFlags) = uleb(b, at),
              let (_, afterMinimum) = uleb(b, afterFlags) else { return nil }
        if b[at] == 1 || b[at] == 3 { return uleb(b, afterMinimum) }
        return (0, afterMinimum)
    }
    private static func uleb(_ b: [UInt8], _ start: Int) -> (Int, Int)? {
        var value = 0, shift = 0, at = start
        while at < b.count && shift <= 28 {
            let byte = b[at]; at += 1
            if shift == 28 && byte & 0xF0 != 0 { return nil }
            value |= Int(byte & 127) << shift
            if byte & 128 == 0 { return (value, at) }
            shift += 7
        }
        return nil
    }
}
