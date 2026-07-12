import Foundation

/// Generates dist/sw-assets.js — the precache manifest consumed by the
/// scaffolded service worker (spec 2026-07-12-pwa-mode-design.md §Build pipeline).
public enum PWAAssets {
    /// Never precached: the worker + its manifest, dotfiles (.DS_Store & co),
    /// and any index.html NOT at the dist root — ssg per-route prerenders are
    /// an HTTP-layer SEO artifact, not an offline artifact (spec §SSG).
    static func isExcluded(relPath: String) -> Bool {
        if relPath == "sw.js" || relPath == "sw-assets.js" { return true }
        if relPath.hasSuffix("/index.html") { return true }
        if ((relPath as NSString).lastPathComponent).hasPrefix(".") { return true }
        return false
    }

    /// Writes dist/sw-assets.js when dist/sw.js exists. Returns false when the
    /// dist has no sw.js (project did not opt into PWA).
    @discardableResult
    public static func generateManifest(distDir: String) throws -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: distDir + "/sw.js") else { return false }
        guard let en = fm.enumerator(atPath: distDir) else {
            throw ToolchainError.io("cannot enumerate \(distDir) for sw-assets.js")
        }
        var entries: [(url: String, integrity: String)] = []
        while let rel = en.nextObject() as? String {
            let full = distDir + "/" + rel
            // Check for symlinked directories (silently broken manifest → loud error)
            if let attrs = try fm.attributesOfItem(atPath: full) as [FileAttributeKey: Any]?,
               attrs[.type] as? FileAttributeType == .typeSymbolicLink {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: full, isDirectory: &isDir)
                if isDir.boolValue {
                    throw ToolchainError.io("symlinked directory in dist/ is not supported by the PWA precache generator: \(rel) — copy real files into public/ instead")
                }
                // Symlink to a regular file: continue (fine to precache)
            }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue else { continue }
            if isExcluded(relPath: rel) { continue }
            guard let data = fm.contents(atPath: full) else {
                throw ToolchainError.io("cannot read \(full) while generating sw-assets.js")
            }
            let digest = SHA256.digest([UInt8](data))
            entries.append((url: "/" + rel, integrity: "sha256-" + SHA256.base64(digest)))
        }
        entries.sort { $0.url < $1.url }
        let versionInput = entries.map { $0.url + "|" + $0.integrity }.joined(separator: "\n")
        let version = SHA256.hex(SHA256.digest(Array(versionInput.utf8)))
        var js = "self.__SWIFTWUI_ASSETS = {\n  \"version\": \"\(version)\",\n  \"assets\": [\n"
        js += entries
            .map { "    { \"url\": \(jsonString($0.url)), \"integrity\": \"\($0.integrity)\" }" }
            .joined(separator: ",\n")
        js += "\n  ]\n};\n"
        try js.write(toFile: distDir + "/sw-assets.js", atomically: true, encoding: .utf8)
        return true
    }

    /// Minimal JSON string escaping (URLs are the only dynamic content).
    static func jsonString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            default:
                if scalar.value < 0x20 { out += String(format: "\\u%04x", scalar.value) }
                else { out.unicodeScalars.append(scalar) }
            }
        }
        return out + "\""
    }
}
