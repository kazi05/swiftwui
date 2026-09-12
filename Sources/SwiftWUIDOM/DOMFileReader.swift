#if arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop
import SwiftWUI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Wraps a JS `File`. Retains the JSObject; reads via its promise APIs.
final class DOMFileReader: _FileBlobProviding {
    private let file: JSObject
    init(file: JSObject) { self.file = file }

    func blob() async throws -> WebBlob {
        WebBlob(storage: DOMBlobStorage(blob: file))
    }

    func data() async throws -> _FoundationData {
        guard let promise = JSPromise((file.arrayBuffer!()).object ?? JSObject()) else {
            throw WebFetchError.network("File.arrayBuffer did not return a promise")
        }
        // .value() (not the `.value` property) inherits this closure's isolation
        // instead of hopping to a nonisolated executor — same reasoning as
        // FetchJSTransport.perform.
        let buf = try await promise.value()
        return _dataFromArrayBuffer(buf)
    }
    func text() async throws -> String {
        guard let promise = JSPromise((file.text!()).object ?? JSObject()) else {
            throw WebFetchError.network("File.text did not return a promise")
        }
        return try await promise.value().string ?? ""
    }
}
#endif
