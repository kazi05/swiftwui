#if arch(wasm32)
import JavaScriptKit
import JavaScriptEventLoop
import SwiftWUI

/// The original File/Blob stays in JavaScript. Only explicit data() copies its
/// bytes into WASM; slicing and upload keep browser-owned Blob references.
@MainActor
final class DOMBlobStorage: _WebBlobStorage {
    nonisolated deinit { }

    /// Module-private bridge consumed by FetchJSTransport. Never exposed by the
    /// core WebBlob API or converted to bytes for upload.
    let blob: JSObject
    let size: Int
    let mimeType: String

    init(blob: JSObject) {
        self.blob = blob
        self.size = Int(blob.size.number ?? 0)
        self.mimeType = blob.type.string ?? ""
    }

    func slice(_ range: Range<Int>) throws -> any _WebBlobStorage {
        guard let sliced = blob.slice?(range.lowerBound, range.upperBound, mimeType).object else {
            throw WebFetchError.unsupported
        }
        return DOMBlobStorage(blob: sliced)
    }

    func data() async throws -> _FoundationData {
        guard let value = blob.arrayBuffer?().object, let promise = JSPromise(value) else {
            throw WebFetchError.network("Blob.arrayBuffer did not return a promise")
        }
        return _dataFromArrayBuffer(try await promise.value())
    }

    func makeObjectURL() throws -> WebObjectURL {
        guard let urlAPI = JSObject.global.URL.object,
              let url = urlAPI.createObjectURL?(blob).string else {
            throw WebFetchError.unsupported
        }
        // Capture only the string. The browser's URL mapping owns its Blob;
        // retaining this storage in the closure would pin it after revoke().
        return WebObjectURL(url: url) {
            _ = JSObject.global.URL.object?.revokeObjectURL?(url)
        }
    }
}
#endif
