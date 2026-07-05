import Foundation

public struct ProcessResult {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String
    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode; self.stdout = stdout; self.stderr = stderr
    }
}

public protocol ProcessRunner {
    /// Runs `executable` (resolved via /usr/bin/env) with `arguments` in `cwd`.
    /// streamOutput: echo child output to our stdout/stderr as it completes.
    @discardableResult
    func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult
}

public struct FoundationProcessRunner: ProcessRunner {
    public init() {}
    public func run(_ executable: String, _ arguments: [String], cwd: String?, streamOutput: Bool) throws -> ProcessResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = [executable] + arguments
        if let cwd { p.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        let outPipe = Pipe(), errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe
        try p.run()
        // ponytail: capture-then-print, no live streaming — dev rebuilds are seconds long
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(decoding: outData, as: UTF8.self)
        let err = String(decoding: errData, as: UTF8.self)
        if streamOutput {
            if !out.isEmpty { print(out, terminator: "") }
            if !err.isEmpty { FileHandle.standardError.write(Data(err.utf8)) }
        }
        return ProcessResult(exitCode: p.terminationStatus, stdout: out, stderr: err)
    }
}

public enum ToolchainError: Error, CustomStringConvertible {
    case noWasmSDK(hint: String)
    case buildFailed(output: String)
    case portInUse(UInt16)
    case notAProject(String)
    case targetExists(String)
    case invalidName(String)
    case productNotFound(String)
    case io(String)

    public var description: String {
        switch self {
        case .noWasmSDK(let hint): "no wasm Swift SDK installed. \(hint)"
        case .buildFailed(let output): "wasm build failed:\n\(output)"
        case .portInUse(let p): "port \(p) is already in use — pass --port to pick another"
        case .notAProject(let d): "'\(d)' does not look like a SwiftWUI project (no Package.swift)"
        case .targetExists(let d): "'\(d)' already exists and is not empty"
        case .invalidName(let n): "'\(n)' is not a valid project name (expected [A-Za-z][A-Za-z0-9_]*)"
        case .productNotFound(let d): "no executable product found in '\(d)' — pass --product"
        case .io(let m): m
        }
    }
}
