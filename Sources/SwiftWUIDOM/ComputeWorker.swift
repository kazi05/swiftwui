#if arch(wasm32)
import JavaScriptKit
import JavaScriptFoundationCompat
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum ComputeWorkerError: Error {
    case unavailable, closed, transferredBuffer, remote(String), invalidResponse
}

/// Explicitly consumed by `ComputeWorker.call(transferring:)`. The original JS
/// ArrayBuffer is detached after postMessage; do not retain aliases for reuse.
@MainActor public final class WorkerBuffer {
    private var storage: JSObject?
    public init(takingArrayBuffer buffer: JSObject) { storage = buffer }
    public var isTransferred: Bool { storage == nil }
    public var arrayBuffer: JSObject? { storage }
    fileprivate func reference() throws -> JSObject {
        guard let value = storage else { throw ComputeWorkerError.transferredBuffer }
        return value
    }
    fileprivate func didTransfer() { storage = nil }
}

@MainActor public struct WorkerReply<Value> {
    public let value: Value
    public let buffers: [WorkerBuffer]
}

/// A module worker serving the swiftwui-worker.js request protocol. Its worker
/// module owns computation and may instantiate a shared compiled WebAssembly.Module.
/// Call close() from onDisappear to release the worker and every pending request.
@MainActor public final class ComputeWorker<Request: Encodable & Sendable, Reply: Decodable & Sendable> {
    private let worker: JSObject
    private var sequence = 0
    private var closed = false
    private var waits: [Int: CheckedContinuation<WorkerReply<Reply>, any Error>] = [:]
    private var message: JSClosure?
    private var failure: JSClosure?
    private var messageFailure: JSClosure?
    public init(moduleURL: String, compiledModule: JSObject? = nil) throws {
        guard let constructor = JSObject.global.Worker.function else { throw ComputeWorkerError.unavailable }
        let options = JSObject.global.Object.function!.new(); options.type = .string("module")
        worker = try constructor.throws.new(moduleURL, options)
        message = JSClosure { [weak self] args in self?.receive(args.first?.object?.data.object); return .undefined }
        failure = JSClosure { [weak self] args in
            self?.terminate(ComputeWorkerError.remote(args.first?.object?.message.string ?? "Worker failed"))
            return .undefined
        }
        messageFailure = JSClosure { [weak self] _ in
            self?.finishAll(ComputeWorkerError.invalidResponse)
            return .undefined
        }
        worker.onmessage = message!.jsValue
        worker.onerror = failure!.jsValue
        worker.onmessageerror = messageFailure!.jsValue
        if let compiledModule {
            let envelope = JSObject.global.Object.function!.new()
            envelope.type = .string("initialize"); envelope.module = .object(compiledModule)
            do {
                _ = try worker.postMessage.function!.throws.callAsFunction(this: worker, arguments: [envelope.jsValue])
            } catch { terminate(error); throw error }
        }
    }
    public func call(_ request: Request, transferring buffers: [WorkerBuffer] = []) async throws -> WorkerReply<Reply> {
        guard !closed else { throw ComputeWorkerError.closed }
        try Task.checkCancellation()
        let encoded = try JSONEncoder().encode(request)
        guard let json = String(data: encoded, encoding: .utf8) else { throw ComputeWorkerError.invalidResponse }
        guard !buffers.contains(where: \.isTransferred) else { throw ComputeWorkerError.transferredBuffer }
        sequence += 1; let id = sequence
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                let envelope = JSObject.global.Object.function!.new()
                envelope.type = .string("request"); envelope.id = .number(Double(id)); envelope.json = .string(json)
                let transfers = JSObject.global.Array.function!.new()
                do {
                    for buffer in buffers { _ = transfers.push?(try buffer.reference()) }
                    envelope.buffers = .object(transfers)
                    waits[id] = continuation
                    // throwing call converts synchronous DataCloneError into a Swift error.
                    _ = try worker.postMessage.function!.throws.callAsFunction(this: worker, arguments: [envelope.jsValue, transfers.jsValue])
                    for buffer in buffers { buffer.didTransfer() }
                } catch { waits[id] = nil; continuation.resume(throwing: error) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id) }
        }
    }
    public func close() {
        terminate(ComputeWorkerError.closed)
    }
    private func terminate(_ error: any Error) {
        guard !closed else { return }; closed = true
        // Keep a currently executing callback alive until teardown returns.
        let callbacks = (message, failure, messageFailure)
        defer { withExtendedLifetime(callbacks) {} }
        _ = worker.terminate?()
        worker.onmessage = .null; worker.onerror = .null; worker.onmessageerror = .null
        message = nil; failure = nil; messageFailure = nil
        finishAll(error)
    }
    private func cancel(_ id: Int) {
        guard let continuation = waits.removeValue(forKey: id) else { return }
        let message = JSObject.global.Object.function!.new()
        message.type = .string("cancel"); message.id = .number(Double(id))
        _ = worker.postMessage?(message)
        continuation.resume(throwing: CancellationError())
    }
    private func receive(_ data: JSObject?) {
        guard let data, let rawID = data.id.number, let waiter = waits.removeValue(forKey: Int(rawID)) else { return }
        if data.type.string == "error" { waiter.resume(throwing: ComputeWorkerError.remote(data.error.string ?? "Worker failed")); return }
        do {
            guard let json = data.json.string else { throw ComputeWorkerError.invalidResponse }
            let value = try JSONDecoder().decode(Reply.self, from: Data(json.utf8))
            var buffers: [WorkerBuffer] = []
            if let array = data.buffers.object {
                for index in 0..<Int(array.length.number ?? 0) {
                    if let buffer = array[index].object { buffers.append(WorkerBuffer(takingArrayBuffer: buffer)) }
                }
            }
            waiter.resume(returning: WorkerReply(value: value, buffers: buffers))
        } catch { waiter.resume(throwing: error) }
    }
    private func finishAll(_ error: any Error) {
        let pending = waits; waits.removeAll()
        for waiter in pending.values { waiter.resume(throwing: error) }
    }
}
#endif
