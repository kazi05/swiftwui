#if arch(wasm32)
import JavaScriptKit
import JavaScriptFoundationCompat
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// Sendable adapter for the AbortController captured by the @Sendable
// onCancel handler — safe: wasm32 is single-threaded, controller is only ever
// touched from the main JS thread (mirrors _InvalidateBox in Resolver.swift).
private struct _AbortControllerBox: @unchecked Sendable { let controller: JSObject }

/// fetch()-backed transport. Security invariants (spec 8a): credentials
/// "same-origin"; scheme/header validation already ran in WebSession.
final class FetchJSTransport: _BlobUploadingTransport {
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        try await execute(request, body: request.body?.jsValue)
    }

    func upload(_ request: WebRequest, from blob: WebBlob) async throws -> (_FoundationData, WebResponse) {
        // Retain the source through success, cancellation and response reading.
        defer { withExtendedLifetime(blob) {} }
        if let storage = blob.storage as? DOMBlobStorage {
            return try await execute(request, body: .object(storage.blob))
        }
        guard let bytes = blob.uploadData else { throw WebFetchError.unsupported }
        return try await execute(request, body: bytes.jsValue)
    }

    private func execute(_ request: WebRequest, body: JSValue?) async throws -> (_FoundationData, WebResponse) {
        let options = JSObject.global.Object.function!.new()
        options.method = .string(request.method.rawValue)
        options.credentials = .string("same-origin")
        if !request.headers.isEmpty {
            let headers = JSObject.global.Object.function!.new()
            for (k, v) in request.headers { headers[k] = .string(v) }
            options.headers = .object(headers)
        }
        if let body { options.body = body }
        guard let controller = JSObject.global.AbortController.function?.new() else {
            throw WebFetchError.unsupported
        }
        options.signal = controller.signal

        final class TimeoutFlag { var fired = false }
        let timedOut = TimeoutFlag()
        var timeoutHandle: JSValue?
        var timeoutClosure: JSOneshotClosure?
        if let timeout = request.timeout {
            let ms = Double(timeout.components.seconds) * 1000
                   + Double(timeout.components.attoseconds) / 1e15
            let closure = JSOneshotClosure { _ in
                timedOut.fired = true
                _ = controller.abort?()
                return .undefined
            }
            timeoutClosure = closure
            timeoutHandle = JSObject.global.setTimeout!(closure, ms)
        }
        defer {
            if let t = timeoutHandle { _ = JSObject.global.clearTimeout?(t) }
            // An unfired oneshot otherwise remains registered forever. release
            // is idempotent if the timer already invoked and released itself.
            timeoutClosure?.release()
        }

        do {
            let controllerBox = _AbortControllerBox(controller: controller)
            // One handler over the WHOLE fetch+read sequence: abort() rejects
            // both the response promise AND the in-flight arrayBuffer() body
            // read, so cancellation mid-download unblocks too (one controller
            // covers both).
            return try await withTaskCancellationHandler {
                // BridgeJS's generated `fetch` is a plain nonisolated async global
                // function (always hops off-actor); wasm32 is single-threaded, so
                // sharing this JSValue across that hop is safe in practice — same
                // escape hatch as _AbortControllerBox above.
                nonisolated(unsafe) let optionsValue: JSValue = .object(options)
                let resp = try await fetch(request.url, optionsValue)
                let status = Int(try resp.status)
                final class HeaderBox { var dict: [String: String] = [:] }
                let box = HeaderBox()
                let collect = JSClosure { args in
                    // Headers.forEach already yields lowercase keys per spec; lowercase
                    // again anyway — WebResponse.headers keys are lowercase-normalized
                    // across transports (invariant, not a fetch() implementation detail).
                    if let v = args.first?.string, args.count > 1, let k = args[1].string {
                        box.dict[k.lowercased()] = v
                    }
                    return .undefined
                }
                // Headers aren't part of the bridged SWResponse surface (spec §1.2
                // hybrid boundary) — reach the raw JSObject via .jsObject for this
                // one dynamic call.
                _ = resp.jsObject.headers.object?.forEach?(collect)   // synchronous iteration
                let buf = try await resp.arrayBuffer()
                return (_dataFromArrayBuffer(buf), WebResponse(status: status, headers: box.dict))
            } onCancel: {
                // nonisolated @Sendable — safe on single-threaded wasm.
                MainActor.assumeIsolated { _ = controllerBox.controller.abort?() }
            }
        } catch let e as WebFetchError {
            throw e
        } catch {
            if timedOut.fired { throw WebFetchError.timeout }
            if Task.isCancelled { throw WebFetchError.cancelled }
            throw WebFetchError.network(String(describing: error))
        }
    }
}
#endif
