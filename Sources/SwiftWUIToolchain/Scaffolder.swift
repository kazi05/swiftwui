import Foundation

public enum Scaffolder {
    public static let templates = ["basic", "mvvm", "tca"]

    public static func scaffold(template: String, name: String, swiftwuiPath: String, into dir: String) throws {
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
        let swiftwuiAbs = URL(fileURLWithPath: swiftwuiPath).standardizedFileURL.path
        guard fm.fileExists(atPath: swiftwuiAbs + "/Package.swift") else {
            throw ToolchainError.notAProject(swiftwuiAbs)
        }
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let e = fm.enumerator(atPath: templateRoot.path)!
        for case let rel as String in e {
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
                        .replacingOccurrences(of: "{{SWIFTWUI_PATH}}", with: swiftwuiAbs)
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
}
