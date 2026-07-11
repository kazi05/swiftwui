#if arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop
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
final class FetchJSTransport: FetchTransport {
    func perform(_ request: WebRequest) async throws -> (_FoundationData, WebResponse) {
        let options = JSObject.global.Object.function!.new()
        options.method = .string(request.method.rawValue)
        options.credentials = .string("same-origin")
        if !request.headers.isEmpty {
            let headers = JSObject.global.Object.function!.new()
            for (k, v) in request.headers { headers[k] = .string(v) }
            options.headers = .object(headers)
        }
        if let body = request.body {
            options.body = body.jsValue
        }
        guard let controller = JSObject.global.AbortController.function?.new() else {
            throw WebFetchError.unsupported
        }
        options.signal = controller.signal

        final class TimeoutFlag { var fired = false }
        let timedOut = TimeoutFlag()
        var timeoutHandle: JSValue?
        if let timeout = request.timeout {
            let ms = Double(timeout.components.seconds) * 1000
                   + Double(timeout.components.attoseconds) / 1e15
            timeoutHandle = JSObject.global.setTimeout!(JSOneshotClosure { _ in
                timedOut.fired = true
                _ = controller.abort?()
                return .undefined
            }, ms)
        }
        defer { if let t = timeoutHandle { _ = JSObject.global.clearTimeout?(t) } }

        do {
            let fetched = JSObject.global.fetch!(request.url, options)
            guard let promise = JSPromise(fetched.object ?? JSObject()) else {
                throw WebFetchError.network("fetch did not return a promise")
            }
            let controllerBox = _AbortControllerBox(controller: controller)
            // One handler over the WHOLE fetch+read sequence: abort() rejects
            // both the response promise AND the in-flight arrayBuffer() body
            // read, so cancellation mid-download unblocks too (one controller
            // covers both). .value() (not the `.value` property) inherits this
            // closure's isolation instead of hopping to a nonisolated executor —
            // required so the non-Sendable JSPromise/JSValue never cross an
            // actor boundary (JavaScriptEventLoop.swift:210).
            return try await withTaskCancellationHandler {
                let respValue = try await promise.value()
                guard let resp = respValue.object else {
                    throw WebFetchError.network("no response object")
                }
                let status = Int(resp.status.number ?? 0)
                final class HeaderBox { var dict: [String: String] = [:] }
                let box = HeaderBox()
                let collect = JSClosure { args in
                    if let v = args.first?.string, args.count > 1, let k = args[1].string {
                        box.dict[k] = v
                    }
                    return .undefined
                }
                _ = resp.headers.object?.forEach?(collect)   // synchronous iteration
                guard let bufPromise = JSPromise((resp.arrayBuffer!()).object ?? JSObject()) else {
                    throw WebFetchError.network("arrayBuffer did not return a promise")
                }
                let buf = try await bufPromise.value()
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
