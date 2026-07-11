#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Backend-injected reader: DOM wraps the JS File; tests serve memory bytes.
public protocol _FileReading: AnyObject {
    func data() async throws -> _FoundationData
    func text() async throws -> String
}

/// A user-picked file. TRUST: `name`/`mimeType`/`size`/`lastModified` are
/// client claims — attacker-controlled. Never make a security/content decision
/// on `mimeType` (validate bytes); never build a filesystem path from `name`;
/// `data()`/`text()` buffer the ENTIRE file — check `size` before reading.
public struct WebFile {
    public let name: String
    public let size: Int
    public let mimeType: String
    public let lastModified: Date
    private let reader: any _FileReading

    public init(name: String, size: Int, mimeType: String, lastModified: Date,
                reader: any _FileReading) {
        self.name = name; self.size = size; self.mimeType = mimeType
        self.lastModified = lastModified; self.reader = reader
    }
    public func data() async throws -> _FoundationData { try await reader.data() }
    public func text() async throws -> String { try await reader.text() }
}

/// `change` payload for input[type=file]. The backend emits THIS instead of
/// ChangeEvent for file inputs — a plain ChangeEvent handler on a file input
/// never fires (documented; payload cast drops it).
public struct FilesEvent {
    public let files: [WebFile]
    public init(files: [WebFile]) { self.files = files }
}

extension Input {
    /// Selected files on change. Only meaningful on `Input(type: .file)`.
    public func onFileSelection(_ action: @escaping ([WebFile]) -> Void) -> Self {
        var copy = self
        copy._attributes.addHandler(.change, payload: FilesEvent.self) { e in
            action(e.files)
        }
        return copy
    }
}
