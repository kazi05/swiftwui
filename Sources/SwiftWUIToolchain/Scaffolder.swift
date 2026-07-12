import Foundation

public enum Scaffolder {
    public static let templates = ["basic", "mvvm", "tca"]

    public static func scaffold(template: String, name: String, swiftwuiPath: String?, into dir: String) throws {
        let fm = FileManager.default
        guard name.range(of: "^[A-Za-z][A-Za-z0-9_]*$", options: .regularExpression) != nil else {
            throw ToolchainError.invalidName(name)
        }
        if let contents = try? fm.contentsOfDirectory(atPath: dir), !contents.isEmpty {
            throw ToolchainError.targetExists(dir)
        }
        let templateRoot = ToolchainResources.url("templates/\(template)")
        guard fm.fileExists(atPath: templateRoot.path) else {
            throw ToolchainError.io("unknown template '\(template)' (available: \(templates.joined(separator: ", ")))")
        }
        let swiftwuiDependency: String
        if let swiftwuiPath {
            let swiftwuiAbs = URL(fileURLWithPath: swiftwuiPath).standardizedFileURL.path
            guard fm.fileExists(atPath: swiftwuiAbs + "/Package.swift") else {
                throw ToolchainError.notAProject(swiftwuiAbs)
            }
            swiftwuiDependency = ".package(path: \"\(swiftwuiAbs)\")"
        } else {
            swiftwuiDependency = ".package(url: \"https://github.com/kazi05/swiftwui.git\", from: \"\(SwiftWUIVersion.current)\")"
        }
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let junk: Set<String> = [".swiftpm", "dist", "node_modules"]
        let e = fm.enumerator(atPath: templateRoot.path)!
        for case let rel as String in e {
            let components = rel.split(separator: "/").map(String.init)
            if components.contains(where: { junk.contains($0) || $0.hasPrefix(".build") }) { continue }
            let src = templateRoot.appendingPathComponent(rel)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: src.path, isDirectory: &isDir)
            let dst = dir + "/" + rel
            if isDir.boolValue {
                try fm.createDirectory(atPath: dst, withIntermediateDirectories: true)
            } else if let raw = fm.contents(atPath: src.path) {
                if let text = String(data: raw, encoding: .utf8) {
                    let substituted = text
                        .replacingOccurrences(of: "{{NAME}}", with: name)
                        .replacingOccurrences(of: "{{SWIFTWUI_DEPENDENCY}}", with: swiftwuiDependency)
                    try substituted.write(toFile: dst, atomically: true, encoding: .utf8)
                } else {
                    try raw.write(to: URL(fileURLWithPath: dst))   // binary passthrough
                }
            }
        }
        // Check the shim into the project: containers and offline builds need it (spec §9 amendment).
        try fm.createDirectory(atPath: dir + "/vendor", withIntermediateDirectories: true)
        try fm.copyItem(atPath: ToolchainResources.url("vendor/wasi-shim").path,
                        toPath: dir + "/vendor/wasi-shim")
    }

    /// Lines inserted into index.html <head> by scaffoldPWA. The last meta is
    /// the marker DOMBackend checks before registering the service worker.
    static let pwaHeadLines = """
      <link rel="manifest" href="/manifest.webmanifest">
      <link rel="apple-touch-icon" href="/icons/apple-touch-icon.png">
      <meta name="theme-color" content="#111111">
      <meta name="swiftwui:serviceworker" content="/sw.js">

    """

    /// PWA artifact set (spec 2026-07-12): copied into the project's public/
    /// (user-owned), plus link/marker lines inserted into index.html.
    /// Idempotent: existing files are never overwritten.
    public static func scaffoldPWA(into dir: String, name: String) throws -> (created: [String], skipped: [String]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir + "/index.html") else {
            throw ToolchainError.io("'\(dir)' has no index.html — run from a SwiftWUI project root")
        }
        var created: [String] = [], skipped: [String] = []
        let root = ToolchainResources.url("pwa")
        let files: [(dest: String, src: String, text: Bool)] = [
            ("public/manifest.webmanifest", "manifest.webmanifest", true),
            ("public/sw.js", "sw.js", true),
            ("public/icons/icon-192.png", "icons/icon-192.png", false),
            ("public/icons/icon-512.png", "icons/icon-512.png", false),
            ("public/icons/icon-512-maskable.png", "icons/icon-512-maskable.png", false),
            ("public/icons/apple-touch-icon.png", "icons/apple-touch-icon.png", false),
        ]
        for f in files {
            let dest = dir + "/" + f.dest
            if fm.fileExists(atPath: dest) { skipped.append(f.dest); continue }
            try fm.createDirectory(atPath: (dest as NSString).deletingLastPathComponent,
                                   withIntermediateDirectories: true)
            let raw = try Data(contentsOf: root.appendingPathComponent(f.src))
            if f.text, var text = String(data: raw, encoding: .utf8) {
                text = text.replacingOccurrences(of: "{{NAME}}", with: name)
                try text.write(toFile: dest, atomically: true, encoding: .utf8)
            } else {
                try raw.write(to: URL(fileURLWithPath: dest))
            }
            created.append(f.dest)
        }
        let indexPath = dir + "/index.html"
        var html = try String(contentsOfFile: indexPath, encoding: .utf8)
        if html.contains("swiftwui:serviceworker") {
            skipped.append("index.html (marker present)")
        } else if let r = html.range(of: "</head>", options: .caseInsensitive) {
            html.insert(contentsOf: pwaHeadLines, at: r.lowerBound)
            try html.write(toFile: indexPath, atomically: true, encoding: .utf8)
            created.append("index.html (head links)")
        } else {
            throw ToolchainError.io("index.html has no </head> — add the PWA head lines manually")
        }
        return (created, skipped)
    }
}
