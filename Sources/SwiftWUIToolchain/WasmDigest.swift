import Foundation
import SwiftWUI

/// One SHA-256 per (path, size, mtime) per process. The wasm is ~9.6 MB and the
/// PWA precache manifest hashes it too; without the memo the build reads that
/// file twice.
///
/// Deliberately NOT shared with `SwiftWUIStatic.BootStamp`, which computes the
/// same token for the prerendered documents: `SwiftWUIStatic` cannot depend on
/// `SwiftWUIToolchain`, and a `FileManager` build helper does not belong in the
/// core that compiles into every wasm binary. Both route through the one
/// `SHA256` in the core, and `WasmDigestAgreementTests` pins them to the same
/// answer — the `?v=` in a build-spliced `index.html` and the one in an
/// ssg-prerendered document must be the same string or the immutable cache
/// header over the wasm is a lie.
public enum WasmDigest {
    public struct Stamp: Equatable {
        public var sizeBytes: Int
        public var digest: [UInt8]
    }

    // Single-threaded CLI; `nonisolated(unsafe)` rather than a lock for the same
    // reason the rest of the toolchain has none.
    private nonisolated(unsafe) static var memo: [String: Stamp] = [:]

    public static func stamp(path: String) -> Stamp? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int,
              let mtime = attrs[.modificationDate] as? Date else { return nil }
        // mtime is part of the key, not just the path: `swiftwui dev` rebuilds
        // in-process and a path-only memo would serve the previous binary's
        // digest for the rest of the session.
        let key = "\(path)|\(size)|\(mtime.timeIntervalSince1970)"
        if let hit = memo[key] { return hit }
        guard let data = fm.contents(atPath: path) else { return nil }
        let stamp = Stamp(sizeBytes: size, digest: SHA256.digest([UInt8](data)))
        memo[key] = stamp
        return stamp
    }

    /// The `?v=` token: first 8 hex of the digest, exactly as `BootStamp` takes it.
    public static func version(_ stamp: Stamp) -> String {
        String(SHA256.hex(stamp.digest).prefix(8))
    }

    /// The bundle's wasm, by the same rule `BootStamp.read` uses (first `.wasm`
    /// in name order). Returns the file NAME, which is what the URL needs.
    public static func wasmName(inAppDir appDir: String) -> String? {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: appDir) else { return nil }
        return entries.filter { $0.hasSuffix(".wasm") }.sorted().first
    }
}
