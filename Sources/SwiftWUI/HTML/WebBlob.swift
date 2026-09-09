#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum WebBlobError: Error, Equatable {
    /// The requested byte range falls outside the receiver.
    case invalidRange
}

@MainActor
package protocol _WebBlobStorage: AnyObject {
    var size: Int { get }
    var mimeType: String { get }
    func slice(_ range: Range<Int>) throws -> any _WebBlobStorage
    func data() async throws -> _FoundationData
    func makeObjectURL() throws -> WebObjectURL
}

package extension _WebBlobStorage {
    func data() async throws -> _FoundationData {
        throw WebFetchError.unsupported
    }

    func makeObjectURL() throws -> WebObjectURL {
        throw WebFetchError.unsupported
    }
}

@MainActor
private final class _DataWebBlobStorage: _WebBlobStorage {
    nonisolated deinit { }

    let bytes: _FoundationData
    let byteRange: Range<Int>
    let mimeType: String

    var size: Int { byteRange.count }

    init(bytes: _FoundationData, byteRange: Range<Int>, mimeType: String) {
        self.bytes = bytes
        self.byteRange = byteRange
        self.mimeType = mimeType
    }

    func slice(_ range: Range<Int>) throws -> any _WebBlobStorage {
        let lower = byteRange.lowerBound + range.lowerBound
        let upper = byteRange.lowerBound + range.upperBound
        return _DataWebBlobStorage(bytes: bytes, byteRange: lower..<upper, mimeType: mimeType)
    }

    func data() async throws -> _FoundationData {
        _FoundationData(bytes[byteRange])
    }

    var selectedData: _FoundationData {
        _FoundationData(bytes[byteRange])
    }
}

@MainActor
/// Immutable binary content backed by portable bytes or a platform resource.
public final class WebBlob {
    nonisolated deinit { }

    public let size: Int
    public let mimeType: String
    package let storage: any _WebBlobStorage

    /// Creates an immutable byte-backed blob. The MIME type follows browser Blob normalization.
    public init(data: _FoundationData, mimeType: String = "") {
        let normalized = Self.normalizeMIMEType(mimeType)
        let storage = _DataWebBlobStorage(
            bytes: data,
            byteRange: data.startIndex..<data.endIndex,
            mimeType: normalized
        )
        self.storage = storage
        self.size = storage.size
        self.mimeType = storage.mimeType
    }

    package init(storage: any _WebBlobStorage) {
        self.storage = storage
        self.size = storage.size
        self.mimeType = storage.mimeType
    }

    /// Returns a blob for the strict byte range relative to this blob.
    public func slice(_ range: Range<Int>) throws -> WebBlob {
        guard range.lowerBound >= 0, range.upperBound <= size else {
            throw WebBlobError.invalidRange
        }
        return WebBlob(storage: try storage.slice(range))
    }

    /// Explicitly materializes this blob's selected bytes in Swift memory.
    public func data() async throws -> _FoundationData {
        try await storage.data()
    }

    /// Creates a temporary URL when the backing storage supports object URLs.
    public func makeObjectURL() throws -> WebObjectURL {
        try storage.makeObjectURL()
    }

    package var uploadData: _FoundationData? {
        (storage as? _DataWebBlobStorage)?.selectedData
    }

    private static func normalizeMIMEType(_ value: String) -> String {
        guard value.unicodeScalars.allSatisfy({ (0x20...0x7E).contains($0.value) }) else {
            return ""
        }
        return value.lowercased()
    }
}
