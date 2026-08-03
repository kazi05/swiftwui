import Foundation
import SwiftWUI

/// Byte length, version token and file name of the wasm a document will name.
///
/// Deliberately NOT the toolchain's `WasmDigest`: `SwiftWUIStatic` cannot depend
/// on `SwiftWUIToolchain`, and a `FileManager` build helper does not belong in
/// the core that compiles into every wasm binary. Both route through the one
/// `SHA256` in the core; only the directory walk is duplicated.
public struct BootStamp: Sendable, Equatable {
    public var sizeBytes: Int
    /// First 8 hex of the SHA-256 — the `?v=` token.
    public var version: String
    /// The wasm's own name. Only the read knows it, and `serialize` needs it to
    /// build the URL.
    public var fileName: String

    public init(sizeBytes: Int, version: String, fileName: String) {
        self.sizeBytes = sizeBytes; self.version = version; self.fileName = fileName
    }

    /// Reads `<outDir>/app/*.wasm`. Returns nil when no wasm has been built yet
    /// — a bare `swift run App ssg` must still produce a document (it falls back
    /// to the legacy inline boot), never fail.
    public static func read(outDir: String) -> BootStamp? {
        let fm = FileManager.default
        let appDir = outDir + "/app"
        guard let entries = try? fm.contentsOfDirectory(atPath: appDir),
              let name = entries.filter({ $0.hasSuffix(".wasm") }).sorted().first,
              let data = fm.contents(atPath: appDir + "/" + name)
        else { return nil }
        let hex = SHA256.hex(SHA256.digest([UInt8](data)))
        return BootStamp(sizeBytes: data.count, version: String(hex.prefix(8)), fileName: name)
    }
}
