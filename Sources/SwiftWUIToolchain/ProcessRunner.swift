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
        // Drain both pipes concurrently — sequential reads deadlock when the
        // child fills one pipe (~64KB) while we're blocked on the other.
        let errBox = DataBox()
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) {
            errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile())
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        p.waitUntilExit()
        let errData = errBox.get()
        let out = String(decoding: outData, as: UTF8.self)
        let err = String(decoding: errData, as: UTF8.self)
        if streamOutput {
            if !out.isEmpty { print(out, terminator: "") }
            if !err.isEmpty { FileHandle.standardError.write(Data(err.utf8)) }
        }
        return ProcessResult(exitCode: p.terminationStatus, stdout: out, stderr: err)
    }
}

/// Cross-thread Data handoff for the concurrent pipe drain. @unchecked Sendable: all access guarded by `lock`.
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func set(_ d: Data) { lock.lock(); data = d; lock.unlock() }
    func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
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
